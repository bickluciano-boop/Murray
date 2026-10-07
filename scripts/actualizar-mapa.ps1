# actualizar-mapa.ps1 - Actualiza la pantalla Mapa del panel (src\panel-mapa.txt) a la version nueva
# Cambios: zoom limitado al encuadrar, direcciones cortas, textos de estado mas cortos, margen para la tarjeta.
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Respaldo: src\panel-mapa.txt.bak-39b7870. Si algo falla, se restaura.
$ErrorActionPreference = "Continue"
function Ok($t)  { Write-Host ("OK    " + $t) -ForegroundColor Green }
function Mal($t) { Write-Host ("MAL   " + $t) -ForegroundColor Red }
function Avi($t) { Write-Host ("AVISO " + $t) -ForegroundColor Yellow }
$raiz = (Get-Location).Path
if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
$arch = Join-Path $raiz "src\panel-mapa.txt"
if (-not (Test-Path $arch)) { Mal "No encuentro src\panel-mapa.txt: primero corre aplicar-mapa.ps1."; return }
function Sha([string]$ruta) { return (Get-FileHash -Algorithm SHA256 -LiteralPath $ruta).Hash.ToLower() }
$esperado = "387a57665046dc184591c4e3467cf21694955d123f2ad09a9af2b4ad9d61af4e"
if ((Sha $arch) -eq $esperado) { Avi "El mapa ya estaba actualizado. No toco nada."; return }
$tmp = $arch + ".descarga"
try { Invoke-WebRequest -UseBasicParsing "https://raw.githubusercontent.com/bickluciano-boop/Murray/39b7870/scripts/mapa/panel-mapa.txt" -OutFile $tmp } catch { }
if (-not (Test-Path $tmp) -or (Sha $tmp) -ne $esperado) { if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Force }; Mal "No se pudo descargar bien la version nueva. No toque nada."; return }
Ok "Version nueva descargada y verificada"
$bak = $arch + ".bak-39b7870"
Copy-Item -LiteralPath $arch -Destination $bak -Force
Ok "Respaldo creado (src\panel-mapa.txt.bak-39b7870)"
Move-Item -LiteralPath $tmp -Destination $arch -Force
if ((Sha $arch) -eq $esperado) {
    Write-Host ""
    Ok "TODO BIEN en los archivos. Falta PUBLICAR: powershell -ExecutionPolicy Bypass -Command ""npx wrangler deploy"""
    Write-Host ""
} else {
    Copy-Item -LiteralPath $bak -Destination $arch -Force
    Mal "Algo no salio bien. Restaure la version anterior. Mandame esta pantalla."
}
