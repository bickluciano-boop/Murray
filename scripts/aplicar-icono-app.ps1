# aplicar-icono-app.ps1 - Pone el logo nuevo (ojo dentro del pin) como icono de la app Android
# Va en la carpeta de la APP (la que tiene app.json). Respaldo app.json.bak-icono; si algo falla, se restaura.
# No hace build: el icono nuevo sale en la proxima build.
$ErrorActionPreference = "Continue"
function Ok($t)  { Write-Host ("OK    " + $t) -ForegroundColor Green }
function Mal($t) { Write-Host ("MAL   " + $t) -ForegroundColor Red }
function Avi($t) { Write-Host ("AVISO " + $t) -ForegroundColor Yellow }
$raiz = (Get-Location).Path
$archJson = Join-Path $raiz "app.json"
if (-not (Test-Path $archJson) -or (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta de la APP (la que tiene app.json), no la del panel."; return }
Ok "Carpeta correcta"
function Contar([string]$donde, [string]$que) {
    $n = 0
    $i = 0
    while ($true) {
        $i = $donde.IndexOf($que, $i, [System.StringComparison]::Ordinal)
        if ($i -lt 0) { break }
        $n = $n + 1
        $i = $i + $que.Length
    }
    return $n
}
$bytes = [System.IO.File]::ReadAllBytes($archJson)
$bom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
$texto = [System.IO.File]::ReadAllText($archJson, [System.Text.Encoding]::UTF8)
if ((Contar $texto 'icon-ojo-pin.png') -ne 0) { Avi "El icono nuevo ya estaba puesto. No toco nada."; return }

$A1 = '"icon": "./assets/icon-build18.png"'
$N1 = '"icon": "./assets/icon-ojo-pin.png"'
$A2 = '"foregroundImage": "./assets/adaptive-icon-build18.png"'
$N2 = '"foregroundImage": "./assets/adaptive-icon-ojo-pin.png"'
$ok = $true
foreach ($c in @(@("app.json: icono", $A1), @("app.json: icono adaptable", $A2))) {
    $n = Contar $texto $c[1]
    if ($n -eq 1) { Ok ($c[0] + ": 1") } else { Mal ($c[0] + ": " + $n + " (esperaba 1)"); $ok = $false }
}
if (-not $ok) { Mal "Alguna ancla no coincide. No toco nada. Mandame esta pantalla."; return }
if (Test-Path (Join-Path $raiz "android\app\src\main\res")) { Avi "Hay una carpeta android\ nativa: la build podria ignorar el icono de app.json. Avisame." }

$assets = Join-Path $raiz "assets"
if (-not (Test-Path $assets)) { Mal "No encuentro la carpeta assets"; return }
$base = "https://raw.githubusercontent.com/bickluciano-boop/Murray/e0e7076/presentacion/logo/"
$archivos = @(@("icon-ojo-pin.png", 520689), @("adaptive-icon-ojo-pin.png", 190142))
foreach ($a in $archivos) {
    $destino = Join-Path $assets $a[0]
    try { Invoke-WebRequest -UseBasicParsing ($base + $a[0]) -OutFile $destino } catch { Mal ("No pude bajar " + $a[0] + ": " + $_.Exception.Message); return }
    $len = (Get-Item $destino).Length
    $sig = [System.IO.File]::ReadAllBytes($destino)[0..3]
    if ($len -eq $a[1] -and $sig[1] -eq 0x50 -and $sig[2] -eq 0x4E -and $sig[3] -eq 0x47) { Ok ("Bajado " + $a[0] + " (" + $len + " bytes)") } else { Mal ("Archivo raro: " + $a[0] + " (" + $len + " bytes)"); return }
}

$bak = $archJson + ".bak-icono"
if (Test-Path $bak) { Mal ("Ya existe " + $bak + ". No toco nada."); return }
Copy-Item -LiteralPath $archJson -Destination $bak
Ok "Respaldo creado (app.json.bak-icono)"
$nuevo = $texto.Replace($A1, $N1).Replace($A2, $N2)
[System.IO.File]::WriteAllText($archJson, $nuevo, (New-Object System.Text.UTF8Encoding($bom)))

$v = [System.IO.File]::ReadAllText($archJson, [System.Text.Encoding]::UTF8)
$todoBien = $true
function Chk([string]$que, [bool]$cond) { if ($cond) { Ok $que } else { Mal $que; $script:todoBien = $false } }
Chk "app.json: icono nuevo" ((Contar $v $N1) -eq 1)
Chk "app.json: icono adaptable nuevo" ((Contar $v $N2) -eq 1)
Chk "app.json: no quedan iconos viejos" (((Contar $v $A1) -eq 0) -and ((Contar $v $A2) -eq 0))
Chk ("app.json: largo igual (" + ($v.Length - $texto.Length) + ")") (($v.Length - $texto.Length) -eq 0)
$json = $null
try { $json = $v | ConvertFrom-Json } catch { }
Chk "app.json: sigue siendo valido" ($json -ne $null)
if ($json -ne $null) {
    Chk "app.json: version y paquete intactos" (($json.expo.android.package -eq "app.ojoguard.mobile") -and ($json.expo.android.adaptiveIcon.backgroundColor -ne $null))
}
if (-not $todoBien) {
    Mal "Algo no salio bien. Restauro desde el respaldo."
    Copy-Item -LiteralPath $bak -Destination $archJson -Force
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "TODO BIEN. El icono nuevo sale en la PROXIMA build de Android (no hace falta hacer una solo por esto)."
Write-Host ""
