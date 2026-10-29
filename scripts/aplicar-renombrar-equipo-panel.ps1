# aplicar-renombrar-equipo-panel.ps1 - Ojo Guard MS: desde la tarjeta del mapa, el boton de la foto del equipo abre "Foto y nombre": se puede cambiar el nombre del equipo (por ejemplo "Celu chapas") o la foto.
# Idea de Luciano (29/10/2026): evitar la confusion cuando hay equipos con el mismo nombre. El servidor no deja repetir el nombre de otro equipo del mismo titular.
# Cambia src\index.ts, src\panel-mapa.txt y src\panel-index.html (solo sube a v=4 el numero del script; respaldo .bak-renombrar). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
$ErrorActionPreference = "Continue"
function Ok($t)  { Write-Host ("OK    " + $t) -ForegroundColor Green }
function Mal($t) { Write-Host ("MAL   " + $t) -ForegroundColor Red }
function Avi($t) { Write-Host ("AVISO " + $t) -ForegroundColor Yellow }
$raiz = (Get-Location).Path
function Contar([string]$donde, [string]$que) {
    if ([string]::IsNullOrEmpty($que)) { return 0 }
    $n = 0; $i = 0
    while ($true) { $i = $donde.IndexOf($que, $i, [System.StringComparison]::Ordinal); if ($i -lt 0) { break }; $n = $n + 1; $i = $i + $que.Length }
    return $n
}
function Leer([string]$ruta) {
    $bytes = [System.IO.File]::ReadAllBytes($ruta)
    $bom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    $texto = [System.IO.File]::ReadAllText($ruta, [System.Text.Encoding]::UTF8)
    return @{ texto = $texto; bom = $bom; crlf = $texto.Contains("`r`n") }
}
function Ajustar([string]$t, [bool]$crlf) { $x = ($t -replace "`r`n", "`n"); if ($crlf) { $x = $x -replace "`n", "`r`n" }; return $x }
function Sha([string]$ruta) { return (Get-FileHash -Algorithm SHA256 -LiteralPath $ruta).Hash.ToLower() }

if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
foreach ($f in @("src\index.ts", "src\panel-mapa.txt", "src\panel-index.html")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'renameDevice') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\panel-index.html")).texto '/mapa-v1.js?v=3') -ne 1) { Mal "Falta aplicar primero aplicar-foto-perfil-mapa2-panel.ps1 (el mapa tiene que estar en v=3). No toco nada."; return }
$cambios = @(
    @('src\index.ts', 'servidor: funcion para renombrar un equipo', 'async function saveDevicePhoto(request: Request, env: Env) {
', '// Cambiar el nombre de un equipo propio ("Celu chapas"). Solo el titular, sin acceso de emergencia, y no puede repetir el nombre de otro equipo suyo.
async function renameDevice(request: Request, env: Env) {
  const sessionInfo = await readSessionInfo(request, env.SESSION_SECRET);
  if (!sessionInfo) return json({ error: "unauthorized" }, 401);
  if (sessionInfo.method === "emergency") return json({ error: "not_allowed_in_emergency" }, 403);
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const deviceId = String(body.deviceId ?? "");
  const name = String(body.name ?? "").replace(/[\u0000-\u001f\u007f]/g, " ").replace(/\s+/g, " ").trim();
  if (name.length < 1 || name.length > 40) return json({ error: "invalid_name" }, 400);
  const owns = await env.DB.prepare("SELECT id FROM devices WHERE id=? AND owner_email=?").bind(deviceId, sessionInfo.email).first();
  if (!owns) return json({ error: "device_not_found" }, 404);
  const others = await env.DB.prepare("SELECT name FROM devices WHERE owner_email=? AND id<>? AND approval_status<>''revoked''").bind(sessionInfo.email, deviceId).all<{ name: string | null }>();
  const clave = (texto: string) => texto.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
  if (others.results.some((otro) => clave(String(otro.name ?? "")) === clave(name))) return json({ error: "name_in_use" }, 409);
  await env.DB.prepare("UPDATE devices SET name=? WHERE id=? AND owner_email=?").bind(name, deviceId, sessionInfo.email).run();
  return json({ saved: true, name });
}

async function saveDevicePhoto(request: Request, env: Env) {
'),
    @('src\index.ts', 'servidor: ruta para renombrar un equipo', '      if (route === "POST /api/remote/devices/photo") return saveDevicePhoto(request, env);
', '      if (route === "POST /api/remote/devices/photo") return saveDevicePhoto(request, env);
      if (route === "POST /api/remote/devices/rename") return renameDevice(request, env);
'),
    @('src\panel-mapa.txt', 'mapa: el boton de la foto abre Foto y nombre', '    if (accion === "foto") return $(''[data-ogm="archivo"]'', raiz).click();
', '    if (accion === "foto") return abrirEquipo(equipoElegido());
    if (accion === "foto-elegir") { estado.dialogo = null; dibujarDialogo(); return $(''[data-ogm="archivo"]'', raiz).click(); }
    if (accion === "nombre-guardar") return guardarNombre(boton);
'),
    @('src\panel-mapa.txt', 'mapa: cuadro Foto y nombre', '  if (d.paso === "salir") {
', '  if (d.paso === "equipo") {
    caja.setAttribute("aria-label", "Foto y nombre del equipo");
    caja.innerHTML = `<div class="ogm-dlg">
      <p class="ogm-ceja">TU EQUIPO</p>
      <h3>Foto y nombre</h3>
      <label class="ogm-campo">Nombre del equipo<input data-ogm="nombre-equipo" maxlength="40" autocomplete="off" value="${esc(d.valor)}"></label>
      <p class="ogm-dlg-txt">Así aparece en tu mapa, en tu lista de equipos y en los avisos que te llegan. No puede repetir el nombre de otro equipo tuyo.</p>
      ${d.error ? `<p class="ogm-aviso-vivo">${esc(d.error)}</p>` : ""}
      <div class="ogm-dlg-botones"><button type="button" class="oro" data-accion="nombre-guardar">Guardar nombre</button><button type="button" data-accion="foto-elegir">Cambiar foto</button><button type="button" data-accion="cerrar-dialogo">Cancelar</button></div>
    </div>`;
    const campo = caja.querySelector(''[data-ogm="nombre-equipo"]'');
    campo?.addEventListener("input", () => { d.valor = campo.value; });
    campo?.addEventListener("keydown", (e) => { if (e.key === "Enter") caja.querySelector(''[data-accion="nombre-guardar"]'')?.click(); });
    return;
  }
  if (d.paso === "salir") {
'),
    @('src\panel-mapa.txt', 'mapa: funciones para abrir y guardar el nombre', '// Administrar a alguien de tu familia (solo el titular): cambiarle el rol o quitarlo.
', '// Foto y nombre de un equipo tuyo: el boton de la foto en la tarjeta abre este cuadro.
function abrirEquipo(equipo) {
  if (!equipo || equipo.tipo !== "telefono" || DEMO) return;
  estado.dialogo = { paso: "equipo", equipoId: equipo.id, valor: equipo.nombre, error: "" };
  dibujarDialogo();
}

async function guardarNombre(boton) {
  const d = estado.dialogo;
  if (!d || d.paso !== "equipo") return;
  const nombre = String(d.valor || "").replace(/\s+/g, " ").trim();
  if (!nombre) { d.error = "Escribí un nombre para el equipo."; return dibujarDialogo(); }
  boton.disabled = true;
  boton.textContent = "Guardando…";
  try {
    await pedir("/api/remote/devices/rename", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ deviceId: d.equipoId, name: nombre }) });
    estado.dialogo = null;
    dibujarDialogo();
    estado.elementosMarcador.delete(d.equipoId);
    return refrescar();
  } catch (error) {
    d.error = error.status === 409 ? "Ya tenés otro equipo con ese nombre. Elegí uno distinto." : error.status === 403 ? "Para esto, entrá al panel con tu acceso normal (no con el de emergencia)." : "No se pudo cambiar el nombre. Probá de nuevo.";
    dibujarDialogo();
  }
}

// Administrar a alguien de tu familia (solo el titular): cambiarle el rol o quitarlo.
'),
    @('src\panel-index.html', 'recargar el mapa nuevo (v=4)', '<script type="module" src="/mapa-v1.js?v=3"></script>', '<script type="module" src="/mapa-v1.js?v=4"></script>')
)
$descargas = @()

# --- Revisar que todas las anclas esten exactamente una vez, en todos los archivos ---
$archivos = @{}
foreach ($c in $cambios) {
    $ruta = Join-Path $raiz $c[0]
    if (-not (Test-Path $ruta)) { Mal ("No encuentro " + $c[0]); return }
    if (-not $archivos.ContainsKey($c[0])) { $archivos[$c[0]] = Leer $ruta }
}
$ok = $true
foreach ($c in $cambios) {
    $f = $archivos[$c[0]]
    $ancla = Ajustar $c[2] $f.crlf
    $cuantos = Contar $f.texto $ancla
    if ($cuantos -eq 1) { Ok ($c[0] + ": " + $c[1] + ": 1") } else { Mal ($c[0] + ": " + $c[1] + ": " + $cuantos + " (esperaba 1)"); $ok = $false }
}
if (-not $ok) { Mal "Alguna ancla no coincide. No toco nada. Mandame esta pantalla."; return }

# --- Descargar archivos nuevos y verificar que llegaron completos ---
foreach ($d in $descargas) {
    $tmp = (Join-Path $raiz $d[1]) + ".descarga"
    try { Invoke-WebRequest -UseBasicParsing $d[0] -OutFile $tmp } catch { }
    if (-not (Test-Path $tmp) -or (Sha $tmp) -ne $d[2]) {
        foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }
        Mal ("No se pudo descargar bien " + $d[1] + ". No toque nada."); return
    }
    Ok ("Descargado y verificado: " + $d[1])
}

# --- Respaldos ---
$tocados = @($archivos.Keys) + @($descargas | ForEach-Object { $_[1] })
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path ($ruta + ".bak-renombrar")) { Mal ("Ya existe " + $t + ".bak-renombrar. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-renombrar"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-renombrar): " + ($respaldados -join ", "))

# --- Aplicar ---
$esperado = @{}
foreach ($k in $archivos.Keys) { $esperado[$k] = $archivos[$k].texto.Length }
$nuevos = @{}
foreach ($k in $archivos.Keys) { $nuevos[$k] = $archivos[$k].texto }
foreach ($c in $cambios) {
    $f = $archivos[$c[0]]
    $ancla = Ajustar $c[2] $f.crlf; $reemplazo = Ajustar $c[3] $f.crlf
    $nuevos[$c[0]] = $nuevos[$c[0]].Replace($ancla, $reemplazo)
    $esperado[$c[0]] = $esperado[$c[0]] + ($reemplazo.Length - $ancla.Length)
}
foreach ($k in $archivos.Keys) { [System.IO.File]::WriteAllText((Join-Path $raiz $k), $nuevos[$k], (New-Object System.Text.UTF8Encoding($archivos[$k].bom))) }
foreach ($d in $descargas) { Move-Item -LiteralPath ((Join-Path $raiz $d[1]) + ".descarga") -Destination (Join-Path $raiz $d[1]) -Force }

# --- Verificar ---
$todoBien = $true
function Chk([string]$que, [bool]$cond) { if ($cond) { Ok $que } else { Mal $que; $script:todoBien = $false } }
foreach ($c in $cambios) {
    $v = (Leer (Join-Path $raiz $c[0]))
    Chk ($c[0] + ": " + $c[1] + " aplicado") ((Contar $v.texto (Ajustar $c[3] $v.crlf)) -eq 1)
}
foreach ($k in $archivos.Keys) {
    $largo = (Leer (Join-Path $raiz $k)).texto.Length
    Chk ($k + ": largo " + $largo + " (esperado " + $esperado[$k] + ")") ($largo -eq $esperado[$k])
}
foreach ($d in $descargas) { Chk ($d[1] + ": verificado") ((Sha (Join-Path $raiz $d[1])) -eq $d[2]) }

if (-not $todoBien) {
    Mal "Algo no salio bien. Restauro todo desde los respaldos."
    foreach ($t in $tocados) {
        $ruta = Join-Path $raiz $t
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-renombrar") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "Archivos listos. Ahora publico el panel..."
& npx.cmd wrangler deploy
if ($LASTEXITCODE -ne 0) { Mal "No se pudo publicar el panel. Mandame esta pantalla."; return }
Write-Host ""
Ok "LISTO: en el mapa, tocá la foto de tu equipo para cambiar su nombre. Recargá la pagina del mapa."
Write-Host ""
