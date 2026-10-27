# subir-apk-panel.ps1 - sube el APK de Android al panel para que se baje desde https://ojoguard.app/descargar
# Uso (en la carpeta del PANEL, la que tiene wrangler.toml):
#   .\subir-apk-panel.ps1 -Apk "C:\Users\...\Downloads\Actualizacion 26-10.apk" -Version "0.9.2"
# -Version es opcional (es solo el texto que se muestra en la pagina). Se repite en cada build nueva: reemplaza el archivo anterior.
# Antes hay que haber aplicado aplicar-descarga-panel.ps1. No cambia ningun archivo del panel: solo sube dos objetos al R2 del panel.
param([string]$Apk = "", [string]$Version = "")
$ErrorActionPreference = "Continue"
function Ok($t)  { Write-Host ("OK    " + $t) -ForegroundColor Green }
function Mal($t) { Write-Host ("MAL   " + $t) -ForegroundColor Red }
function Avi($t) { Write-Host ("AVISO " + $t) -ForegroundColor Yellow }
$raiz = (Get-Location).Path
$toml = Join-Path $raiz "wrangler.toml"
if (-not (Test-Path $toml)) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml)."; return }
if ([string]::IsNullOrWhiteSpace($Apk) -or -not (Test-Path -LiteralPath $Apk)) { Mal "Falta el archivo. Usa: .\subir-apk-panel.ps1 -Apk ""ruta\al\archivo.apk"""; return }
$Apk = (Resolve-Path -LiteralPath $Apk).Path
Ok "Carpeta correcta"

# --- El archivo tiene que ser un APK de verdad (un zip con AndroidManifest.xml) y pesar lo que corresponde ---
$bytes = (Get-Item -LiteralPath $Apk).Length
if ($bytes -lt 20MB -or $bytes -gt 280MB) { Mal ("El archivo pesa " + [math]::Round($bytes / 1MB, 1) + " MB. No parece el APK de la app. No subo nada."); return }
$esApk = $false
try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($Apk)
    foreach ($e in $zip.Entries) { if ($e.FullName -eq "AndroidManifest.xml") { $esApk = $true } }
    $zip.Dispose()
} catch { }
if (-not $esApk) { Mal "Ese archivo no es un APK (no tiene AndroidManifest.xml). No subo nada."; return }
$sha = (Get-FileHash -Algorithm SHA256 -LiteralPath $Apk).Hash.ToLower()
Ok ("APK valido: " + [math]::Round($bytes / 1MB, 2) + " MB, huella " + $sha.Substring(0, 16) + "...")

# --- Nombre del almacenamiento: el que ya usa el panel para las fotos (EVIDENCE_FILES) ---
$t = [System.IO.File]::ReadAllText($toml, [System.Text.Encoding]::UTF8)
$bucket = ""
foreach ($bloque in ($t -split "\[\[r2_buckets\]\]")) {
    if ($bloque -match 'binding\s*=\s*"EVIDENCE_FILES"' -and $bloque -match 'bucket_name\s*=\s*"([^"]+)"') { $bucket = $Matches[1] }
}
if ($bucket -eq "") { Mal "No encuentro el bucket EVIDENCE_FILES en wrangler.toml. No subo nada. Mandame esta pantalla."; return }
Ok ("Almacenamiento: " + $bucket)

function SubirR2([string]$clave, [string]$archivo, [string]$tipo) {
    $destino = $bucket + "/" + $clave
    $salida = (& npx.cmd wrangler r2 object put $destino --file $archivo --content-type $tipo --remote 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0 -and $salida -match "(?i)unknown argument|remote") {
        $salida = (& npx.cmd wrangler r2 object put $destino --file $archivo --content-type $tipo 2>&1 | Out-String)
    }
    Write-Host $salida
    return ($LASTEXITCODE -eq 0)
}
Write-Host "Subiendo el APK (son unos 150 MB, puede tardar unos minutos)..."
if (-not (SubirR2 "descargas/ojo-guard.apk" $Apk "application/vnd.android.package-archive")) { Mal "No se pudo subir el APK. Mandame esta pantalla."; return }
Ok "APK subido"

$info = '{"version":"' + ($Version -replace '[^0-9A-Za-z._ -]', '') + '","subido":"' + (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") + '","bytes":' + $bytes + ',"sha256":"' + $sha + '"}'
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("ojo-version-" + [guid]::NewGuid().ToString("N") + ".json")
[System.IO.File]::WriteAllText($tmp, $info, (New-Object System.Text.UTF8Encoding($false)))
$okInfo = SubirR2 "descargas/version.json" $tmp "application/json"
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
if (-not $okInfo) { Mal "El APK quedo subido pero no se pudo subir el dato de la version. Mandame esta pantalla."; return }
Ok "Datos de la version subidos"

# --- Verificar desde afuera, como lo ve cualquier persona ---
$largo = -1
try {
    $r = Invoke-WebRequest -UseBasicParsing -Method Head -Uri "https://ojoguard.app/descargar/ojo-guard.apk"
    $largo = [int64]($r.Headers["Content-Length"] | Select-Object -First 1)
} catch { }
if ($largo -eq $bytes) { Ok ("Verificado: https://ojoguard.app/descargar entrega el APK completo (" + $largo + " bytes)") }
else { Mal ("La pagina entrega " + $largo + " bytes y el archivo tiene " + $bytes + ". Mandame esta pantalla."); return }
Write-Host ""
Ok "LISTO: el link para pasarle a tu familia es https://ojoguard.app/descargar"
Write-Host ""
