# aplicar-pantalla-carga.ps1 - Pantalla de carga de la app: fondo #050505 con el ojo dorado en el centro
# Va en la carpeta de la APP (la que tiene app.json). Respaldo app.json.bak-carga; si algo falla, se restaura.
# No hace build: la pantalla nueva sale en la proxima build.
$ErrorActionPreference = "Continue"
function Ok($t)  { Write-Host ("OK    " + $t) -ForegroundColor Green }
function Mal($t) { Write-Host ("MAL   " + $t) -ForegroundColor Red }
function Avi($t) { Write-Host ("AVISO " + $t) -ForegroundColor Yellow }
$raiz = (Get-Location).Path
$archJson = Join-Path $raiz "app.json"
$archPkg = Join-Path $raiz "package.json"
if (-not (Test-Path $archJson) -or -not (Test-Path $archPkg) -or (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta de la APP (la que tiene app.json), no la del panel."; return }
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
function Ajustar([string]$t, [bool]$crlf) {
    $x = ($t -replace "`r`n", "`n")
    if ($crlf) { $x = $x -replace "`n", "`r`n" }
    return $x
}
$bytes = [System.IO.File]::ReadAllBytes($archJson)
$bom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
$texto = [System.IO.File]::ReadAllText($archJson, [System.Text.Encoding]::UTF8)
$crlf = $texto.Contains("`r`n")
if ((Contar $texto 'expo-splash-screen') -ne 0) { Avi "La pantalla de carga ya estaba configurada. No toco nada."; return }
if (-not (Test-Path (Join-Path $raiz "assets\adaptive-icon-ojo-pin.png"))) { Mal "Falta assets\adaptive-icon-ojo-pin.png: primero corre aplicar-icono-app.ps1."; return }
Ok "Imagen del ojo encontrada (assets\adaptive-icon-ojo-pin.png)"

$A1 = '    "plugins": ['
$N1 = Ajustar ($A1 + "`n" + @'
      [
        "expo-splash-screen",
        {
          "backgroundColor": "#050505",
          "image": "./assets/adaptive-icon-ojo-pin.png",
          "imageWidth": 200,
          "resizeMode": "contain"
        }
      ],
'@.TrimEnd("`r", "`n")) $crlf
if ((Contar $texto $A1) -ne 1) { Mal ("app.json: lista de plugins: " + (Contar $texto $A1) + " (esperaba 1). No toco nada."); return }
Ok "app.json: lista de plugins: 1"

$pkg = [System.IO.File]::ReadAllText($archPkg, [System.Text.Encoding]::UTF8)
if ((Contar $pkg '"expo-splash-screen"') -eq 0) {
    Avi "Falta el paquete expo-splash-screen. Lo instalo con la version que corresponde a tu Expo (tarda un minuto)..."
    & npx expo install expo-splash-screen
    $pkg = [System.IO.File]::ReadAllText($archPkg, [System.Text.Encoding]::UTF8)
    if ((Contar $pkg '"expo-splash-screen"') -eq 0) { Mal "No se pudo instalar expo-splash-screen. No toque app.json. Mandame esta pantalla."; return }
    Ok "expo-splash-screen instalado"
} else { Ok "expo-splash-screen ya estaba en package.json" }

$bak = $archJson + ".bak-carga"
if (Test-Path $bak) { Mal ("Ya existe " + $bak + ". No toco nada."); return }
Copy-Item -LiteralPath $archJson -Destination $bak
Ok "Respaldo creado (app.json.bak-carga)"
$nuevo = $texto.Replace($A1, $N1)
[System.IO.File]::WriteAllText($archJson, $nuevo, (New-Object System.Text.UTF8Encoding($bom)))

$v = [System.IO.File]::ReadAllText($archJson, [System.Text.Encoding]::UTF8)
$todoBien = $true
function Chk([string]$que, [bool]$cond) { if ($cond) { Ok $que } else { Mal $que; $script:todoBien = $false } }
$json = $null
try { $json = $v | ConvertFrom-Json } catch { }
Chk "app.json: sigue siendo valido" ($json -ne $null)
if ($json -ne $null) {
    $p0 = $json.expo.plugins[0]
    Chk "app.json: pantalla de carga agregada" (($p0[0] -eq "expo-splash-screen") -and ($p0[1].backgroundColor -eq "#050505") -and ($p0[1].image -eq "./assets/adaptive-icon-ojo-pin.png"))
    Chk "app.json: icono nuevo y paquete intactos" (($json.expo.icon -eq "./assets/icon-ojo-pin.png") -and ($json.expo.android.package -eq "app.ojoguard.mobile"))
    Chk ("app.json: plugins " + ($json.expo.plugins.Count)) ($json.expo.plugins.Count -ge 2)
}
Chk ("app.json: largo +" + ($v.Length - $texto.Length) + " (esperado +" + ($N1.Length - $A1.Length) + ")") (($v.Length - $texto.Length) -eq ($N1.Length - $A1.Length))
if (-not $todoBien) {
    Mal "Algo no salio bien. Restauro app.json desde el respaldo."
    Copy-Item -LiteralPath $bak -Destination $archJson -Force
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "TODO BIEN. La pantalla de carga nueva sale en la PROXIMA build de Android (no hace falta hacer una solo por esto)."
Write-Host ""
