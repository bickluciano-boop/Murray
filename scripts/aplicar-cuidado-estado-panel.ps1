# aplicar-cuidado-estado-panel.ps1 - Ojo Guard MS: en la tarjeta de cada persona (mapa del panel, tambien dentro de la app) se ve como va lo suyo de Cuidado: SOS prendido o apagado, bateria baja / sin senal y el "Buen dia" de hoy.
# Luciano (10/11/2026): "prepara lo del panel". Solo lo ve quien recibe el SOS de esa persona (los mismos a quienes ella les avisa); lo prende o apaga cada persona desde su app. Solo lee: no cambia nada de lo que ya manda avisos.
# Requiere aplicar-cuidado-panel.ps1, aplicar-sos-apagar-panel.ps1 y aplicar-mapa-ubicacion-cortada-panel.ps1. Cambia src\index.ts y src\panel-mapa.txt (respaldo .bak-cuidado-estado). Va en la carpeta del PANEL (la que tiene wrangler.toml). No necesita build. Al final publica el panel solo.
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
foreach ($f in @("src\index.ts", "src\panel-mapa.txt")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
$indexTexto = (Leer (Join-Path $raiz "src\index.ts")).texto
$mapaTexto = (Leer (Join-Path $raiz "src\panel-mapa.txt")).texto
if ((Contar $indexTexto 'async function cuidadoVista') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $indexTexto 'async function cuidadoCron') -eq 0) { Mal "Falta aplicar primero aplicar-cuidado-panel.ps1. No toco nada."; return }
if ((Contar $indexTexto 'async function sosApagado') -eq 0) { Mal "Falta aplicar primero aplicar-sos-apagar-panel.ps1. No toco nada."; return }
if ((Contar $mapaTexto 'cortado: Boolean(p.locCut)') -eq 0) { Mal "Falta aplicar primero aplicar-mapa-ubicacion-cortada-panel.ps1. No toco nada."; return }
$cambios = @(
    @('src\index.ts', 'cuidado: como esta la persona (funcion)', '/** GET /api/native/care: lo que la persona tiene prendido,', '/**
 * Como esta la persona en lo de "Cuidado", para quien recibe su SOS (la lista de personas del panel y de la app). Solo lee.
 * buenDiaHoy: null (apagado) | "programado" (todavia no es la hora) | "esperando" (saludo enviado, sin respuesta) | "contesto" | "sin_respuesta" (ya se aviso) | "manana" (hoy no salio).
 */
async function cuidadoVista(env: Env, email: string, bateria: number | null) {
  await cuidadoTabla(env);
  const prefs = await cuidadoPrefs(env, email), e = await cuidadoEstado(env, email);
  const loc = cuidadoLocal(Date.now(), prefs.tz);
  const minutosHora = Number(prefs.hora.slice(0, 2)) * 60 + Number(prefs.hora.slice(3, 5));
  const minutosAhora = Number(loc.hhmm.slice(0, 2)) * 60 + Number(loc.hhmm.slice(3, 5));
  let buenDiaHoy: string | null = null;
  if (prefs.buenDia) {
    if (e.bd_day === loc.dia && e.bd_sent_at) buenDiaHoy = e.bd_ok_at ? "contesto" : e.bd_alert_at ? "sin_respuesta" : "esperando";
    else buenDiaHoy = minutosAhora < minutosHora + CUIDADO_VENTANA_MIN ? "programado" : "manana";
  }
  return {
    sosApagado: await sosApagado(env, email),
    bateria: prefs.bateria,
    bateriaBaja: prefs.bateria && Boolean(e.bat_low) && typeof bateria === "number",
    sinSenal: prefs.bateria && Boolean(e.silence_at),
    buenDia: prefs.buenDia,
    buenDiaHora: prefs.hora,
    buenDiaHoy,
  };
}

/** GET /api/native/care: lo que la persona tiene prendido,'),
    @('src\index.ts', 'cuidado: se calcula para quien recibe su SOS', '    people.push({
      id: p.id,
', '    // Cuidado de esa persona: solo lo ve quien recibe su SOS (a esos mismos se les avisa), y no en las consultas livianas.
    const cuidado = !liviano && permisos.recibisSuSos.elegible && personas.size <= 12 ? await cuidadoVista(env, p.email, device?.battery ?? null).catch(() => null) : null;
    people.push({
      id: p.id,
'),
    @('src\index.ts', 'cuidado: viaja en cada persona', '      permisos,
      // Solo para quien administra a esa persona', '      permisos,
      cuidado,
      // Solo para quien administra a esa persona'),
    @('src\panel-mapa.txt', 'mapa: la persona trae su cuidado', '      cortado: Boolean(p.locCut),
', '      cortado: Boolean(p.locCut),
      // Estado de Cuidado (SOS apagado, bateria y senal, Buen dia): solo viene si quien mira recibe el SOS de esa persona.
      cuidado: p.cuidado || null,
'),
    @('src\panel-mapa.txt', 'mapa: bloque "Cuidado de ..." de la tarjeta', '/** En la tarjeta de una persona: el botón para avisarte y los avisos que ya armaste sobre ella. */
function htmlAvisos(persona) {
', '/**
 * En la tarjeta de una persona: como esta lo suyo de "Cuidado" (lo prende o apaga ella desde su app): SOS, bateria y senal, y el "Buen dia" de hoy.
 * Rojo = hay que mirar; verde = bien; gris = apagado.
 */
function htmlCuidadoPersona(persona) {
  const c = persona.cuidado;
  if (!c) return "";
  const filas = [];
  filas.push(c.sosApagado ? ["off", "Apagó su SOS: si lo toca, no avisa a nadie."] : ["ok", "SOS prendido"]);
  if (!c.bateria) filas.push(["suave", "Aviso de batería y señal: apagado"]);
  else {
    if (c.bateriaBaja) filas.push(["off", `Batería baja${persona.bateria === null ? "" : ` (${Math.round(persona.bateria)} %)`}`]);
    if (c.sinSenal) filas.push(["off", persona.vistoEn ? `Sin señal desde ${haceCuanto(persona.vistoEn)}` : "Sin señal"]);
    if (!c.bateriaBaja && !c.sinSenal) filas.push(["ok", "Batería y señal: bien"]);
  }
  const hora = c.buenDiaHora || "";
  if (!c.buenDia) filas.push(["suave", "Buen día: apagado"]);
  else if (c.buenDiaHoy === "contesto") filas.push(["ok", "Buen día: contestó hoy"]);
  else if (c.buenDiaHoy === "sin_respuesta") filas.push(["off", `Buen día: no contestó el de las ${hora}`]);
  else if (c.buenDiaHoy === "esperando") filas.push(["suave", `Buen día: esperando que conteste (saludo de las ${hora})`]);
  else if (c.buenDiaHoy === "manana") filas.push(["suave", `Buen día: hoy no salió; mañana a las ${hora}`]);
  else filas.push(["suave", `Buen día: hoy a las ${hora}`]);
  const color = { ok: "var(--ogm-vivo)", off: "var(--ogm-off)", suave: "var(--ogm-suave)" };
  return `<div class="ogm-cuidado" style="margin:12px 0 0;padding:10px 12px;border:1px solid var(--ogm-linea);border-radius:12px;display:grid;gap:5px;font-size:0.8rem;line-height:1.35">
    <strong style="font-size:0.68rem;letter-spacing:0.08em;text-transform:uppercase;color:var(--ogm-suave)">Cuidado de ${esc(persona.nombre)}</strong>
    ${filas.map(([clase, texto]) => `<span style="color:${color[clase]}"><b aria-hidden="true">\u25cf </b>${esc(texto)}</span>`).join("")}
  </div>`;
}

/** En la tarjeta de una persona: el botón para avisarte y los avisos que ya armaste sobre ella. */
function htmlAvisos(persona) {
'),
    @('src\panel-mapa.txt', 'mapa: bloque en la tarjeta de la app', '    ${e.tipo === "persona" ? htmlAvisos(e) : ""}
', '    ${e.tipo === "persona" ? htmlCuidadoPersona(e) : ""}
    ${e.tipo === "persona" ? htmlAvisos(e) : ""}
'),
    @('src\panel-mapa.txt', 'mapa: bloque en la tarjeta de la compu', '    ${elegido.tipo === "persona" ? htmlAvisos(elegido) : ""}
', '    ${elegido.tipo === "persona" ? htmlCuidadoPersona(elegido) : ""}
    ${elegido.tipo === "persona" ? htmlAvisos(elegido) : ""}
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
    if (Test-Path ($ruta + ".bak-cuidado-estado")) { Mal ("Ya existe " + $t + ".bak-cuidado-estado. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-cuidado-estado"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-cuidado-estado): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-cuidado-estado") -Destination $ruta -Force }
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
Ok "LISTO: la tarjeta de cada persona muestra su Cuidado (recarga la pagina con Ctrl+F5)."
Write-Host ""
