# aplicar-mi-nombre-panel.ps1 - Ojo Guard MS: "Mi nombre" = como te ven las personas de tu circulo en el mapa y las listas (idea de Luciano, 29/10/2026).
# Hasta ahora cada persona se veia con el nombre que escribio quien la invito. Ahora, si la persona eligio su nombre (desde la app, Perfil > Mi nombre), ese gana; si no, se usa el de la invitacion.
# Cambia SOLO src\index.ts (respaldo .bak-mi-nombre). Requiere aplicar-foto-perfil-panel.ps1 y aplicar-borrar-cuenta-panel.ps1. Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
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
if (-not (Test-Path (Join-Path $raiz "src\index.ts"))) { Mal "No encuentro src\index.ts en esta carpeta."; return }
$txt = (Leer (Join-Path $raiz "src\index.ts")).texto
if ((Contar $txt 'nombrePerfil') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $txt 'nativeAccountDelete') -eq 0 -or (Contar $txt 'nativeProfilePhotoDelete') -eq 0) { Mal "Faltan aplicar primero aplicar-foto-perfil-panel.ps1 y aplicar-borrar-cuenta-panel.ps1. No toco nada."; return }
$cambios = @(
    @('src\index.ts', 'servidor: funciones de Mi nombre', '// ---- Foto de perfil visible para el circulo ----
', '// ---- "Mi nombre": como te ven los demas ----
// Cada persona elige el nombre con el que aparece en el mapa y en las listas de su circulo. Si no eligio ninguno, familyPeopleFor usa el que escribio quien la invito.
let nombreTablaLista = false;
async function nombreTabla(env: Env) {
  if (nombreTablaLista) return;
  await env.DB.prepare("CREATE TABLE IF NOT EXISTS profile_names (email TEXT PRIMARY KEY, name TEXT NOT NULL, updated_at INTEGER NOT NULL)").run();
  nombreTablaLista = true;
}

async function nombrePerfil(env: Env, email: string): Promise<string | null> {
  try {
    await nombreTabla(env);
    const fila = await env.DB.prepare("SELECT name FROM profile_names WHERE email=?").bind(email).first<{ name: string }>();
    return String(fila?.name ?? "").trim() || null;
  } catch {
    return null;
  }
}

async function nativeProfileNameGet(request: Request, env: Env, url: URL) {
  const email = await nativeOwnerEmail(request, env, url.searchParams.get("deviceId") ?? "");
  if (!email) return json({ error: "unauthorized" }, 401);
  return json({ name: await nombrePerfil(env, email) });
}

async function nativeProfileNameSave(request: Request, env: Env) {
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const email = await nativeOwnerEmail(request, env, String(body.deviceId ?? ""));
  if (!email) return json({ error: "unauthorized" }, 401);
  const name = String(body.name ?? "").replace(/[\u0000-\u001f\u007f]/g, " ").replace(/\s+/g, " ").trim();
  if (name.length > 30) return json({ error: "invalid_name" }, 400);
  await nombreTabla(env);
  // Vacio = quitar el nombre: vuelve a verse con el que puso quien la invito.
  if (!name) {
    await env.DB.prepare("DELETE FROM profile_names WHERE email=?").bind(email).run();
    return json({ ok: true, name: null });
  }
  await env.DB.prepare("INSERT INTO profile_names (email,name,updated_at) VALUES (?,?,?) ON CONFLICT(email) DO UPDATE SET name=excluded.name,updated_at=excluded.updated_at")
    .bind(email, name, Date.now()).run();
  return json({ ok: true, name });
}

// ---- Foto de perfil visible para el circulo ----
'),
    @('src\index.ts', 'servidor: la lista del circulo usa Mi nombre', '      name: p.name || (p.owner ? p.email.split("@")[0].replace(/^./, (c) => c.toUpperCase()) : device?.name || p.email.split("@")[0]),
', '      // El nombre que la persona eligio para si (Perfil > Mi nombre) gana; si no puso ninguno, el que escribio quien la invito.
      name: (await nombrePerfil(env, p.email)) || p.name || (p.owner ? p.email.split("@")[0].replace(/^./, (c) => c.toUpperCase()) : device?.name || p.email.split("@")[0]),
'),
    @('src\index.ts', 'servidor: rutas de Mi nombre', '      if (route === "POST /api/native/profile-photo/delete") return nativeProfilePhotoDelete(request, env);
', '      if (route === "POST /api/native/profile-photo/delete") return nativeProfilePhotoDelete(request, env);
      if (route === "GET /api/native/profile-name") return nativeProfileNameGet(request, env, url);
      if (route === "POST /api/native/profile-name") return nativeProfileNameSave(request, env);
'),
    @('src\index.ts', 'servidor: Borrar mi cuenta tambien borra Mi nombre', '  await borrar("profile_photos", "DELETE FROM profile_photos WHERE email=?", 1);
', '  await borrar("profile_photos", "DELETE FROM profile_photos WHERE email=?", 1);
  await nombreTabla(env).catch(() => undefined);
  await borrar("profile_names", "DELETE FROM profile_names WHERE email=?", 1);
')
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
    if (Test-Path ($ruta + ".bak-mi-nombre")) { Mal ("Ya existe " + $t + ".bak-mi-nombre. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-mi-nombre"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-mi-nombre): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-mi-nombre") -Destination $ruta -Force }
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
Ok "LISTO: el servidor ya guarda Mi nombre. Falta la app (aplicar-mi-nombre-app.ps1) para poder elegirlo."
Write-Host ""
