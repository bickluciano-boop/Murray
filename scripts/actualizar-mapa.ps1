# actualizar-mapa.ps1 - Actualiza la pantalla Mapa del panel (src\panel-mapa.txt y src\panel-mapa.css) a la ultima version
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Respaldos: *.bak-7da31fa. Si algo falla, se restaura.
$ErrorActionPreference = "Continue"
function Ok($t)  { Write-Host ("OK    " + $t) -ForegroundColor Green }
function Mal($t) { Write-Host ("MAL   " + $t) -ForegroundColor Red }
function Avi($t) { Write-Host ("AVISO " + $t) -ForegroundColor Yellow }
$raiz = (Get-Location).Path
if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
function Sha([string]$ruta) { return (Get-FileHash -Algorithm SHA256 -LiteralPath $ruta).Hash.ToLower() }
$archivos = @(@("panel-mapa.txt", "d5e3431a5eb2fc9f0e910abef3efb2422e206edc39579567aa640e5b6f7a540d"), @("panel-mapa.css", "c2aeeff51b44d40e33d547c050b853a2a7c81d69ac00ff6851f456377f53b074"))
foreach ($a in $archivos) { if (-not (Test-Path (Join-Path $raiz ("src\" + $a[0])))) { Mal ("No encuentro src\" + $a[0] + ": primero corre aplicar-mapa.ps1."); return } }
$pendientes = @($archivos | Where-Object { (Sha (Join-Path $raiz ("src\" + $_[0]))) -ne $_[1] })
if ($pendientes.Count -eq 0) { Avi "El mapa ya estaba actualizado. No toco nada."; return }
foreach ($a in $pendientes) {
    $tmp = Join-Path $raiz ("src\" + $a[0] + ".descarga")
    try { Invoke-WebRequest -UseBasicParsing ("https://raw.githubusercontent.com/bickluciano-boop/Murray/7da31fa/scripts/mapa/" + $a[0]) -OutFile $tmp } catch { }
    if (-not (Test-Path $tmp) -or (Sha $tmp) -ne $a[1]) {
        foreach ($b in $pendientes) { $x = Join-Path $raiz ("src\" + $b[0] + ".descarga"); if (Test-Path $x) { Remove-Item -LiteralPath $x -Force } }
        Mal ("No se pudo descargar bien " + $a[0] + ". No toque nada."); return
    }
    Ok ("Descargado y verificado: " + $a[0])
}
$todoBien = $true
foreach ($a in $pendientes) {
    $arch = Join-Path $raiz ("src\" + $a[0])
    Copy-Item -LiteralPath $arch -Destination ($arch + ".bak-7da31fa") -Force
    Move-Item -LiteralPath ($arch + ".descarga") -Destination $arch -Force
    if ((Sha $arch) -eq $a[1]) { Ok ("Actualizado: src\" + $a[0] + " (respaldo .bak-7da31fa)") } else { $todoBien = $false }
}
if (-not $todoBien) {
    foreach ($a in $pendientes) { $arch = Join-Path $raiz ("src\" + $a[0]); if (Test-Path ($arch + ".bak-7da31fa")) { Copy-Item -LiteralPath ($arch + ".bak-7da31fa") -Destination $arch -Force } }
    Mal "Algo no salio bien. Restaure la version anterior. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "TODO BIEN en los archivos. Falta PUBLICAR: powershell -ExecutionPolicy Bypass -Command ""npx wrangler deploy"""
Write-Host ""
