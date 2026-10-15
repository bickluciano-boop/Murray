# aplicar-acceso-directo-app.ps1 - Acceso directo al panel (consola general) desde la app del propio telefono.
# El boton "Abrir Ojo Guard MS" pide al servidor un enlace de un solo uso y abre la consola con la sesion ya iniciada: sin codigo por
# correo ni passkey, porque ya se entro a la app con la clave de administrador. Si el servidor no puede darlo (sin internet, o el panel
# todavia sin actualizar), abre la entrada de siempre. Al volver del navegador no se pide la clave de la app de nuevo.
# Hace falta antes aplicar-acceso-directo-panel.ps1 en el panel. Toca App.tsx y src\remoteApi.ts. Va en la carpeta de la APP (la que
# tiene app.json). Respaldo .bak-directo. Es solo codigo de la app (nada nativo): sale en la PROXIMA build, en Android y en iPhone.
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

if (-not (Test-Path (Join-Path $raiz "app.json")) -or (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta de la APP (la que tiene app.json), no la del panel."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\remoteApi.ts"))) { Mal "No encuentro src\remoteApi.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\remoteApi.ts")).texto 'requestPanelHandoff') -ne 0) { Avi "El acceso directo ya estaba aplicado en la app. No toco nada."; return }
$cambios = @(
    @('App.tsx', 'importar el acceso directo', '  requestPasskeyBootstrap,
  requestNativeEnrollment,', '  requestPanelHandoff,
  requestPasskeyBootstrap,
  requestNativeEnrollment,'),
    @('App.tsx', 'abrir Ojo Guard MS entrando directo', '  async function openOjoGuardMs() {
    try {
      await Linking.openURL("https://ojo-guard-ms-api.bickluciano.workers.dev/acceso-v7");', '  async function openOjoGuardMs() {
    try {
      // Desde este telefono (ya vinculado y con la clave de administrador) se entra directo, sin pedir codigo ni passkey.
      // Si el servidor no puede darlo (sin internet, panel sin actualizar), se abre la entrada de siempre.
      let destino = "https://ojo-guard-ms-api.bickluciano.workers.dev/acceso-v7";
      if (nativeEnrollment) destino = await requestPanelHandoff(nativeEnrollment).catch(() => destino);
      // Volver del navegador no tiene que mandar la app a la pantalla de bloqueo.
      markPendingSystemActivity();
      await Linking.openURL(destino);'),
    @('src\remoteApi.ts', 'pedir el enlace directo al panel', 'export type RemoteExecutionResult = {', '/**
 * Acceso directo al panel desde este telefono: el servidor da un enlace de un solo uso (vence en 1 minuto) que abre la consola con la
 * sesion ya iniciada, sin pedir codigo ni passkey.
 */
export async function requestPanelHandoff(enrollment: NativeEnrollment) {
  const response = await nativeRequest(enrollment, "/api/native/panel-handoff", {
    method: "POST",
    body: JSON.stringify({ deviceId: enrollment.deviceId }),
  });
  const result = (await response.json()) as { url?: string };
  if (!result.url) throw new Error("panel_handoff_failed");
  return result.url;
}

export type RemoteExecutionResult = {')
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
    if (Test-Path ($ruta + ".bak-directo")) { Mal ("Ya existe " + $t + ".bak-directo. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-directo"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-directo): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-directo") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "Archivos listos. Reviso que la app compile (puede tardar un minuto)..."
& npx.cmd tsc --noEmit
if ($LASTEXITCODE -ne 0) { Mal "La revision de tipos encontro errores (arriba). No hagas la build todavia: mandame esta pantalla."; return }
Write-Host ""
Ok "LISTO: la app compila bien. Sale en la PROXIMA build (Android y iPhone)."
Write-Host ""
