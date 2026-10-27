# subir-apk-panel.ps1 - sube el APK de Android al panel para que se baje desde https://ojoguard.app/descargar
# Uso (en la carpeta del PANEL, la que tiene wrangler.toml):
#   .\subir-apk-panel.ps1 -Apk "C:\Users\...\Downloads\archivo.apk" -Version "0.9.2"
# -Version es opcional: es el texto que se muestra en la pagina. Poner el numero de build de Android entre parentesis, ej. "0.9.2 (163)": el boton "Actualizar version" de la app lo usa para saber si hay algo mas nuevo. Se repite en cada build nueva: reemplaza la version anterior.
# Antes hay que haber aplicado aplicar-descarga-panel.ps1 y aplicar-descarga-kv-panel.ps1. No cambia ningun archivo del panel.
# El APK se corta en partes de 16 MB (el KV acepta hasta 25 MB por valor) y se guarda como descargas/<id>/<n>; el dato descargas/version.json
# se sube AL FINAL, asi la pagina nunca entrega un APK a medias ni mezclado con el anterior.
param([string]$Apk = "", [string]$Version = "")
$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"
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
if ($bytes -lt 20MB -or $bytes -gt 400MB) { Mal ("El archivo pesa " + [math]::Round($bytes / 1MB, 1) + " MB. No parece el APK de la app. No subo nada."); return }
$esApk = $false
try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($Apk)
    foreach ($e in $zip.Entries) { if ($e.FullName -eq "AndroidManifest.xml") { $esApk = $true } }
    $zip.Dispose()
} catch { }
if (-not $esApk) { Mal "Ese archivo no es un APK (no tiene AndroidManifest.xml). No subo nada."; return }
$sha = (Get-FileHash -Algorithm SHA256 -LiteralPath $Apk).Hash.ToLower()
$id = $sha.Substring(0, 16)
Ok ("APK valido: " + [math]::Round($bytes / 1MB, 2) + " MB, huella " + $id + "...")

# --- Numero del almacenamiento: el KV EVIDENCE_FILES que ya usa el panel ---
$t = [System.IO.File]::ReadAllText($toml, [System.Text.Encoding]::UTF8)
$kvId = ""
foreach ($bloque in ($t -split "\[\[kv_namespaces\]\]")) {
    if ($bloque -match 'binding\s*=\s*"EVIDENCE_FILES"' -and $bloque -match '\bid\s*=\s*"([^"]+)"') { $kvId = $Matches[1] }
}
if ($kvId -eq "") { Mal "No encuentro el KV EVIDENCE_FILES en wrangler.toml. No subo nada. Mandame esta pantalla."; return }
Ok "Almacenamiento (KV) encontrado"

function PutKv([string]$clave, [string]$archivo) {
    $salida = (& npx.cmd wrangler kv key put $clave --path $archivo --namespace-id $kvId --remote 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0 -and $salida -match "(?i)unknown argument") {
        $salida = (& npx.cmd wrangler kv key put $clave --path $archivo --namespace-id $kvId 2>&1 | Out-String)
    }
    if ($LASTEXITCODE -ne 0) { Write-Host $salida }
    return ($LASTEXITCODE -eq 0)
}
function DelKv([string]$clave) {
    $salida = (& npx.cmd wrangler kv key delete $clave --namespace-id $kvId --remote 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0 -and $salida -match "(?i)unknown argument") {
        $salida = (& npx.cmd wrangler kv key delete $clave --namespace-id $kvId 2>&1 | Out-String)
    }
    return ($LASTEXITCODE -eq 0)
}

# --- Version anterior (para limpiar sus partes al final) ---
$viejoId = ""; $viejoPartes = 0
try {
    $r = Invoke-WebRequest -UseBasicParsing -Uri "https://ojoguard.app/api/app/version"
    $d = $r.Content | ConvertFrom-Json
    if ($d.disponible -and $d.sha256) { $viejoId = ([string]$d.sha256).Substring(0, 16); $viejoPartes = [int]$d.partes }
} catch { }

# --- Cortar en partes de 16 MB ---
$tam = 16MB
$dir = Join-Path ([System.IO.Path]::GetTempPath()) ("ojo-apk-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $dir | Out-Null
$partes = 0
$entrada = [System.IO.File]::OpenRead($Apk)
try {
    $buf = New-Object byte[] $tam
    while ($true) {
        $lleno = 0
        while ($lleno -lt $tam) { $n = $entrada.Read($buf, $lleno, $tam - $lleno); if ($n -le 0) { break }; $lleno = $lleno + $n }
        if ($lleno -eq 0) { break }
        $salida = [System.IO.File]::Create((Join-Path $dir ("p" + $partes + ".bin")))
        $salida.Write($buf, 0, $lleno); $salida.Close()
        $partes = $partes + 1
        if ($lleno -lt $tam) { break }
    }
} finally { $entrada.Close() }
Ok ("Cortado en " + $partes + " partes")

function Limpiar { if (Test-Path $dir) { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue } }
for ($i = 0; $i -lt $partes; $i++) {
    Write-Host ("Subiendo parte " + ($i + 1) + " de " + $partes + "...")
    if (-not (PutKv ("descargas/" + $id + "/" + $i) (Join-Path $dir ("p" + $i + ".bin")))) { Mal ("No se pudo subir la parte " + ($i + 1) + ". La pagina sigue con la version anterior. Mandame esta pantalla."); Limpiar; return }
}
Ok "Partes subidas"

$info = '{"version":"' + ($Version -replace '[^0-9A-Za-z._ ()-]', '') + '","subido":"' + (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") + '","bytes":' + $bytes + ',"sha256":"' + $sha + '","partes":' + $partes + '}'
$archivoInfo = Join-Path $dir "version.json"
[System.IO.File]::WriteAllText($archivoInfo, $info, (New-Object System.Text.UTF8Encoding($false)))
if (-not (PutKv "descargas/version.json" $archivoInfo)) { Mal "Las partes quedaron subidas pero no el dato de la version. La pagina sigue con la anterior. Mandame esta pantalla."; Limpiar; return }
Ok "Dato de la version subido"

# --- Verificar desde afuera, como lo ve cualquier persona: bajar el APK completo y comparar la huella ---
$bajado = Join-Path $dir "bajado.apk"
$verificado = $false
for ($intento = 1; $intento -le 4 -and -not $verificado; $intento++) {
    try {
        if (Test-Path $bajado) { Remove-Item -LiteralPath $bajado -Force }
        Invoke-WebRequest -UseBasicParsing -Uri "https://ojoguard.app/descargar/ojo-guard.apk" -OutFile $bajado
        if ((Test-Path $bajado) -and ((Get-FileHash -Algorithm SHA256 -LiteralPath $bajado).Hash.ToLower() -eq $sha)) { $verificado = $true }
    } catch { }
    if (-not $verificado -and $intento -lt 4) { Avi ("Todavia no coincide (intento " + $intento + " de 4). Espero 20 segundos..."); Start-Sleep -Seconds 20 }
}
Limpiar
if (-not $verificado) { Mal "Lo que baja de https://ojoguard.app/descargar no coincide con tu APK. Mandame esta pantalla."; return }
Ok "Verificado: lo que baja la gente desde la pagina es exactamente tu APK (misma huella)"

# --- Borrar las partes de la version anterior ---
if ($viejoId -ne "" -and $viejoId -ne $id) {
    $borradas = 0
    for ($i = 0; $i -lt $viejoPartes; $i++) { if (DelKv ("descargas/" + $viejoId + "/" + $i)) { $borradas = $borradas + 1 } }
    Ok ("Partes de la version anterior borradas: " + $borradas + " de " + $viejoPartes)
}
Write-Host ""
Ok "LISTO: el link para pasarle a tu familia es https://ojoguard.app/descargar"
Write-Host ""
