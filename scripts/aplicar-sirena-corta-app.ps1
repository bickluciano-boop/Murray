# aplicar-sirena-corta-app.ps1 - Hacer sonar en iPhone: que no suenen dos alarmas a la vez y que la sirena del aviso dure menos.
# Lo que conto Luciano (16/10/2026) probando "Hacer sonar" en el iPhone:
#  - Con la app abierta sonaban DOS alarmas a la vez: la sirena del aviso (que no se puede cortar) y la alarma de la propia app (la que se corta con
#    "Detener sonido"). Ahora, con la app abierta, el aviso de "Hacer sonar" no suena: queda solo la alarma de la app, que si se puede detener.
#  - Con la app cerrada el aviso suena y NO se puede cortar (iPhone no lo permite: un sonido de aviso sigue hasta el final). Por eso se suma una sirena
#    corta de 10 segundos (la de 28 sigue para el SOS). El servidor la usa recien cuando la build nueva este instalada (otro paso, mas adelante).
# Suma assets\sounds\ojo_sirena_corta.wav y toca App.tsx y app.json. Va en la carpeta de la APP (la que tiene app.json). Respaldo .bak-sirenacorta.
# Es un sonido nuevo dentro de la app: hace falta una BUILD NUEVA (Android e iPhone).
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
if ((Contar (Leer (Join-Path $raiz "app.json")).texto 'ojo_sirena_corta') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "app.json")).texto 'ojo_sirena.wav') -eq 0) { Mal "Falta la sirena de 28 segundos (aplicar-build23.ps1). No toco nada."; return }
if (-not (Test-Path (Join-Path $raiz "assets\sounds"))) { Mal "No encuentro la carpeta assets\sounds. No toco nada."; return }
$cambios = @(
    @('App.tsx', 'app abierta: el aviso de Hacer sonar no suena (ya suena la propia alarma de la app)', '        handleNotification: async () => ({
          shouldPlaySound: true,', '        handleNotification: async (notificacion) => ({
          // "Hacer sonar" con la app abierta: la propia app ya hace sonar su alarma (la que se puede detener con "Detener sonido"). Sin esto sonaba
          // tambien la sirena del aviso, eran dos a la vez, y esa no se puede cortar.
          shouldPlaySound: notificacion.request.content.data?.kind !== "ring",'),
    @('app.json', 'sirena corta en las notificaciones', '"sounds": ["./assets/sounds/ojo_sirena.wav"]', '"sounds": ["./assets/sounds/ojo_sirena.wav", "./assets/sounds/ojo_sirena_corta.wav"]')
)
$descargas = @(
    ,@("https://raw.githubusercontent.com/bickluciano-boop/Murray/bc56d442c5cfb7eccfc2acef2bdfd8cdda3d8012/scripts/sonidos/ojo_sirena_corta.wav", "assets\sounds\ojo_sirena_corta.wav", "d56019e6d490b763743234acc05ec1bbf2e242ed0a25f7dc1344e75bc046c0a7")
)

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
    if (Test-Path ($ruta + ".bak-sirenacorta")) { Mal ("Ya existe " + $t + ".bak-sirenacorta. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-sirenacorta"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-sirenacorta): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-sirenacorta") -Destination $ruta -Force }
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
Ok "LISTO: la app compila bien. Hace falta una BUILD NUEVA (suma un sonido)."
Write-Host ""
