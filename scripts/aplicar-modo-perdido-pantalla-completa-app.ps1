# aplicar-modo-perdido-pantalla-completa-app.ps1 - Android: Modo perdido toma la pantalla bloqueada aunque la orden la reciba la propia app.
# Diagnostico (24/10/2026): cuando el aviso del servidor llega y la app sigue viva en memoria, la orden "lost-mode" la ejecuta App.tsx, que activaba
# Modo perdido y mostraba una notificacion comun pero NO pedia la pantalla completa (dependia de un vigilante que Android congela con la app atras).
# Ahora, si la app no esta al frente, esa misma orden pide tambien la pantalla completa con fijado (lo que ya hacia el camino de segundo plano)
# y lo anota en el historial de Registros tecnicos. No cambia nada si la app esta abierta, ni en iPhone.
# Toca App.tsx. Va en la carpeta de la APP (la que tiene app.json). Respaldo .bak-pantallacompleta.
# Es solo codigo de la app (nada nativo): sale en la PROXIMA build de Android.
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
if (-not (Test-Path (Join-Path $raiz "App.tsx"))) { Mal "No encuentro App.tsx en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "App.tsx")).texto 'orden recibida por App.tsx con la app atras') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
$cambios = @(
    ,@('App.tsx', 'pedir la pantalla completa en la orden Modo perdido con la app atras', ('        setPinVisible(false);
        startScreenPinning();
        const notifications = await loadNativeNotifications();
        await notifications?.scheduleNotificationAsync({
          content: {
            title: "Ojo Guard ' + [char]0x2014 + ' Modo perdido",'), ('        setPinVisible(false);
        startScreenPinning();
        // Con la app atras (telefono bloqueado) la orden la ejecuta este camino y antes no pedia la pantalla completa:
        // la notificacion comun llegaba pero la pantalla de Modo perdido no tomaba el telefono. Se pide igual que en segundo plano.
        if (AppState.currentState !== "active") {
          try {
            const cuerpoDelAvisoAtras = [
              settings.recoveryMessage || "Este tel\u00e9fono est\u00e1 perdido.",
              settings.recoveryContact ? `Comun\u00edquese a ${settings.recoveryContact}.` : null,
              formatRecoveryReward(settings.recoveryReward),
            ]
              .filter(Boolean)
              .join(" ");
            const posteadoAtras = showFullScreenAlert("Ojo Guard ' + [char]0x2014 + ' Modo perdido", cuerpoDelAvisoAtras, true);
            await recordFullScreenAlertAttempt({
              reason: "lost-mode",
              moduleFound: fullScreenAlertModuleAvailable(),
              result: posteadoAtras,
              error: "orden recibida por App.tsx con la app atras: se pidio la pantalla completa con fijado",
            });
          } catch (error) {
            await recordFullScreenAlertAttempt({
              reason: "lost-mode",
              moduleFound: false,
              result: false,
              error: "orden recibida por App.tsx con la app atras: " + String(error),
            });
          }
        }
        const notifications = await loadNativeNotifications();
        await notifications?.scheduleNotificationAsync({
          content: {
            title: "Ojo Guard ' + [char]0x2014 + ' Modo perdido",'))
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
    if (Test-Path ($ruta + ".bak-pantallacompleta")) { Mal ("Ya existe " + $t + ".bak-pantallacompleta. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-pantallacompleta"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-pantallacompleta): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-pantallacompleta") -Destination $ruta -Force }
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
Ok "LISTO: la app compila bien. Sale en la PROXIMA build de Android."
Write-Host ""
