# reparar-pantalla-carga.ps1 - Vuelve a poner la pantalla de carga (fondo #050505 + ojo dorado)
# Para cuando se restauro app.json.bak-carga: ese respaldo tiene "expo-splash-screen" sin configurar.
# Saca esa linea suelta y pone la configuracion completa. Respaldo app.json.bak-carga2; si algo falla, se restaura.
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
function EsNuestra($p) { return (($p -is [System.Array]) -and ($p.Count -eq 2) -and ($p[0] -eq "expo-splash-screen") -and ($p[1].backgroundColor -eq "#050505") -and ($p[1].image -eq "./assets/adaptive-icon-ojo-pin.png")) }
function Sueltas($lista) { $c = 0; foreach ($p in $lista) { if (($p -is [string]) -and ($p -eq "expo-splash-screen")) { $c = $c + 1 } }; return $c }

$bytes = [System.IO.File]::ReadAllBytes($archJson)
$bom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
$texto = [System.IO.File]::ReadAllText($archJson, [System.Text.Encoding]::UTF8)
$crlf = $texto.Contains("`r`n")
$antes = $null
try { $antes = $texto | ConvertFrom-Json } catch { }
if ($antes -eq $null) { Mal "app.json no se puede leer como JSON. No toco nada. Mandame esta pantalla."; return }
$plugAntes = @($antes.expo.plugins)
if ((Sueltas $plugAntes) -eq 0 -and (EsNuestra $plugAntes[0])) { Ok "La pantalla de carga ya esta bien configurada. No toco nada."; return }
$sinNada = ((Contar $texto 'expo-splash-screen') -eq 0)
if (-not $sinNada -and ((Contar $texto 'expo-splash-screen') -ne 1 -or (Sueltas $plugAntes) -ne 1)) { Mal ("app.json: expo-splash-screen aparece " + (Contar $texto 'expo-splash-screen') + " veces (esperaba 1 suelta). No toco nada. Mandame esta pantalla."); return }
if ($sinNada) { Ok "app.json: sin pantalla de carga (la agrego)" } else { Ok "app.json: expo-splash-screen sin configurar encontrado" }
if (-not (Test-Path (Join-Path $raiz "assets\adaptive-icon-ojo-pin.png"))) { Mal "Falta assets\adaptive-icon-ojo-pin.png. No toco nada."; return }
Ok "Imagen del ojo encontrada"

# 1) Sacar la linea suelta "expo-splash-screen" (si es la ultima, tambien la coma de antes)
$reUltima = New-Object System.Text.RegularExpressions.Regex (',\r?\n[ \t]*"expo-splash-screen"(?=\r?\n[ \t]*\])')
$reMedio = New-Object System.Text.RegularExpressions.Regex ('\r?\n[ \t]*"expo-splash-screen",(?=\r?\n)')
$cuantasU = $reUltima.Matches($texto).Count
$cuantasM = $reMedio.Matches($texto).Count
if ($sinNada) { $cuantasU = 0; $cuantasM = 0; $sin = $texto }
elseif (($cuantasU + $cuantasM) -ne 1) { Mal ("app.json: no reconozco el formato de la linea (" + $cuantasU + "/" + $cuantasM + "). No toco nada. Mandame esta pantalla."); return }
elseif ($cuantasU -eq 1) { $sin = $reUltima.Replace($texto, "", 1) } else { $sin = $reMedio.Replace($texto, "", 1) }
if ((Contar $sin 'expo-splash-screen') -ne 0) { Mal "No pude sacar la linea suelta. No toco nada."; return }
Ok "Linea suelta lista para sacar"

# 2) Poner la configuracion completa al principio de la lista de plugins
$A1 = '    "plugins": ['
$bloque = Ajustar ($A1 + "`n" + @'
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
if ((Contar $sin $A1) -ne 1) { Mal ("app.json: lista de plugins: " + (Contar $sin $A1) + " (esperaba 1). No toco nada. Mandame esta pantalla."); return }
Ok "app.json: lista de plugins: 1"
$nuevo = $sin.Replace($A1, $bloque)

$bak = $archJson + ".bak-carga2"
if (Test-Path $bak) { Mal ("Ya existe " + $bak + ". No toco nada."); return }
Copy-Item -LiteralPath $archJson -Destination $bak
Ok "Respaldo creado (app.json.bak-carga2)"
[System.IO.File]::WriteAllText($archJson, $nuevo, (New-Object System.Text.UTF8Encoding($bom)))

$v = [System.IO.File]::ReadAllText($archJson, [System.Text.Encoding]::UTF8)
$todoBien = $true
function Chk([string]$que, [bool]$cond) { if ($cond) { Ok $que } else { Mal $que; $script:todoBien = $false } }
$json = $null
try { $json = $v | ConvertFrom-Json } catch { }
Chk "app.json: sigue siendo valido" ($json -ne $null)
if ($json -ne $null) {
    $plugDespues = @($json.expo.plugins)
    Chk "app.json: pantalla de carga configurada" (EsNuestra $plugDespues[0])
    Chk "app.json: sin lineas sueltas" ((Sueltas $plugDespues) -eq 0)
    $esperados = $plugAntes.Count
    if ($sinNada) { $esperados = $esperados + 1 }
    Chk ("app.json: plugins " + $plugDespues.Count + " (esperado " + $esperados + ")") ($plugDespues.Count -eq $esperados)
    Chk "app.json: icono nuevo y paquete intactos" (($json.expo.icon -eq "./assets/icon-ojo-pin.png") -and ($json.expo.android.package -eq "app.ojoguard.mobile"))
}
Chk ("app.json: largo " + ($v.Length - $sin.Length) + " (esperado " + ($bloque.Length - $A1.Length) + ")") (($v.Length - $sin.Length) -eq ($bloque.Length - $A1.Length))
if (-not $todoBien) {
    Mal "Algo no salio bien. Restauro app.json desde el respaldo."
    Copy-Item -LiteralPath $bak -Destination $archJson -Force
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "TODO BIEN. La pantalla de carga sale en la PROXIMA build de Android. No hace falta correr nada mas."
Write-Host ""
