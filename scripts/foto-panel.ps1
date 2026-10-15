# foto-panel.ps1 - "Foto" de la consola (el panel Ojo Guard MS) antes de reordenarla. No cambia nada del panel. Hace tres cosas:
#  1) Guarda una copia comprimida de la carpeta del panel (sin node_modules ni carpetas de compilacion) en la carpeta de arriba, con la
#     fecha y la hora en el nombre. Es la marcha atras si algo sale mal.
#  2) Junta los archivos de la pantalla de la consola (html, css y los .txt de src) en una carpeta nueva, FOTO-PANEL-PARA-CLAUDE-<fecha>,
#     con ".txt" al final del nombre para poder subirlos a Google Drive y que yo los lea. No incluye claves: ni .dev.vars ni wrangler.toml.
#  3) Anota en INVENTARIO.txt el tamano y la huella (sha256) de cada archivo de src, para comparar mas adelante.
# Va en la carpeta del PANEL (la que tiene wrangler.toml).
$ErrorActionPreference = "Continue"
function Ok($t)  { Write-Host ("OK    " + $t) -ForegroundColor Green }
function Mal($t) { Write-Host ("MAL   " + $t) -ForegroundColor Red }
function Avi($t) { Write-Host ("AVISO " + $t) -ForegroundColor Yellow }
$raiz = (Get-Location).Path
if (-not (Test-Path (Join-Path $raiz "wrangler.toml")) -or -not (Test-Path (Join-Path $raiz "src"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml y la carpeta src), no la de la app."; return }
Ok "Carpeta correcta"
$fecha = Get-Date -Format "yyyy-MM-dd_HHmm"
$padre = Split-Path $raiz -Parent

# --- 1) Copia comprimida ---
$zip = Join-Path $padre ("FOTO-OJO-GUARD-PANEL-" + $fecha + ".zip")
$tmp = Join-Path $env:TEMP ("ojo-foto-panel-" + $fecha)
if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
& robocopy $raiz $tmp /E /XD node_modules .git .wrangler dist /XF *.zip .dev.vars /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { Mal "No pude copiar los archivos para la foto. Mandame esta pantalla."; return }
try { Compress-Archive -Path (Join-Path $tmp "*") -DestinationPath $zip -Force -ErrorAction Stop } catch { Mal ("No pude armar el .zip: " + $_.Exception.Message); Remove-Item -Recurse -Force $tmp; return }
Remove-Item -Recurse -Force $tmp
$mb = [math]::Round((Get-Item $zip).Length / 1MB, 1)
Ok ("Copia guardada (" + $mb + " MB): " + $zip)

# --- 2) y 3) Archivos de la consola para Drive e inventario ---
$destino = Join-Path $padre ("FOTO-PANEL-PARA-CLAUDE-" + $fecha)
New-Item -ItemType Directory -Force $destino | Out-Null
function HashTexto([string]$ruta) {
    $t = [System.IO.File]::ReadAllText($ruta, [System.Text.Encoding]::UTF8)
    $t = $t -replace "`r`n", "`n"
    $sha = [System.Security.Cryptography.SHA256]::Create()
    return ([BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($t)))).Replace("-", "").ToLower()
}
$lineas = @(("Inventario de src de la consola - " + $fecha), "nombre | bytes | sha256 (con saltos de linea normalizados)", "")
$copiados = 0; $bytesCopiados = 0
foreach ($a in (Get-ChildItem (Join-Path $raiz "src") -File | Sort-Object Name)) {
    $lineas += ($a.Name + " | " + $a.Length + " | " + (HashTexto $a.FullName))
    $esPantalla = @(".html", ".css", ".txt") -contains $a.Extension.ToLower()
    if ($esPantalla) {
        $nombre = $a.Name
        if ($a.Extension.ToLower() -ne ".txt") { $nombre = $a.Name + ".txt" }
        Copy-Item -LiteralPath $a.FullName -Destination (Join-Path $destino $nombre) -Force
        $copiados = $copiados + 1; $bytesCopiados = $bytesCopiados + $a.Length
    }
}
$lineas | Set-Content -Path (Join-Path $destino "INVENTARIO.txt") -Encoding UTF8
Ok ("Archivos de la pantalla de la consola: " + $copiados + " (" + [math]::Round($bytesCopiados / 1KB) + " KB) en: " + $destino)
Write-Host ""
Write-Host "Ahora subi la carpeta FOTO-PANEL-PARA-CLAUDE-... a tu Google Drive (arrastrala al navegador) y avisame." -ForegroundColor Cyan
Write-Host ""
Ok "LISTO. No se cambio nada del panel."
Write-Host ""
