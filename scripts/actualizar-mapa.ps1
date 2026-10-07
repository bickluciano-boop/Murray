# actualizar-mapa.ps1 - Actualiza la pantalla Mapa del panel (src\panel-mapa.txt y src\panel-mapa.css) a la ultima version
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Respaldos: *.bak-f8ea07b. Si algo falla, se restaura.
$ErrorActionPreference = "Continue"
function Ok($t)  { Write-Host ("OK    " + $t) -ForegroundColor Green }
function Mal($t) { Write-Host ("MAL   " + $t) -ForegroundColor Red }
function Avi($t) { Write-Host ("AVISO " + $t) -ForegroundColor Yellow }
$raiz = (Get-Location).Path
if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
function Sha([string]$ruta) { return (Get-FileHash -Algorithm SHA256 -LiteralPath $ruta).Hash.ToLower() }
$archivos = @(@("panel-mapa.txt", "cccfa6ca377f954b5e7a209c26942f125beb1e59a229401edf8380d5ff59a78b"), @("panel-mapa.css", "46395213338f9e7ea9bfd00cab96ae85ba40f8a5f42d4ae73cbdca975373140e"))
foreach ($a in $archivos) { if (-not (Test-Path (Join-Path $raiz ("src\" + $a[0])))) { Mal ("No encuentro src\" + $a[0] + ": primero corre aplicar-mapa.ps1."); return } }
$pendientes = @($archivos | Where-Object { (Sha (Join-Path $raiz ("src\" + $_[0]))) -ne $_[1] })
if ($pendientes.Count -eq 0) { Avi "El mapa ya estaba actualizado. No toco nada."; return }
foreach ($a in $pendientes) {
    $tmp = Join-Path $raiz ("src\" + $a[0] + ".descarga")
    try { Invoke-WebRequest -UseBasicParsing ("https://raw.githubusercontent.com/bickluciano-boop/Murray/f8ea07b/scripts/mapa/" + $a[0]) -OutFile $tmp } catch { }
    if (-not (Test-Path $tmp) -or (Sha $tmp) -ne $a[1]) {
        foreach ($b in $pendientes) { $x = Join-Path $raiz ("src\" + $b[0] + ".descarga"); if (Test-Path $x) { Remove-Item -LiteralPath $x -Force } }
        Mal ("No se pudo descargar bien " + $a[0] + ". No toque nada."); return
    }
    Ok ("Descargado y verificado: " + $a[0])
}
$todoBien = $true
foreach ($a in $pendientes) {
    $arch = Join-Path $raiz ("src\" + $a[0])
    Copy-Item -LiteralPath $arch -Destination ($arch + ".bak-f8ea07b") -Force
    Move-Item -LiteralPath ($arch + ".descarga") -Destination $arch -Force
    if ((Sha $arch) -eq $a[1]) { Ok ("Actualizado: src\" + $a[0] + " (respaldo .bak-f8ea07b)") } else { $todoBien = $false }
}
if (-not $todoBien) {
    foreach ($a in $pendientes) { $arch = Join-Path $raiz ("src\" + $a[0]); if (Test-Path ($arch + ".bak-f8ea07b")) { Copy-Item -LiteralPath ($arch + ".bak-f8ea07b") -Destination $arch -Force } }
    Mal "Algo no salio bien. Restaure la version anterior. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "TODO BIEN en los archivos. Falta PUBLICAR: powershell -ExecutionPolicy Bypass -Command ""npx wrangler deploy"""
Write-Host ""
