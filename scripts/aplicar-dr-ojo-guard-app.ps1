# aplicar-dr-ojo-guard-app.ps1 - "Mi proteccion" pasa a llamarse Dr. Ojo Guard (despues de aplicar-sos-mapa-configuracion-app.ps1):
#  - Nombre nuevo: "Dr. Ojo Guard", con el boton "Hacer chequeo" (antes "Revisar mi proteccion").
#  - Android: avisa si hay auriculares o parlantes Bluetooth conectados (con uno conectado Android puede mandar la sirena del SOS ahi y que
#    en el telefono no se oiga nada, como paso en la prueba del 13/10) y ofrece abrir el Bluetooth.
#  - Android: boton "Probar la sirena", que hace sonar una alarma de prueba por el mismo canal del SOS.
# Reemplaza src\proteccion.ts, src\ProteccionBlock.tsx, src\sosTask.ts, modules\sos-trigger\index.ts y SosTriggerModule.kt. Va en la carpeta
# de la APP (la que tiene app.json). Respaldo .bak-dr. Tiene codigo nativo de Android (una funcion nueva): hace falta build de Android.
# El iPhone recibe el nombre nuevo en su proxima build.
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
if (-not (Test-Path (Join-Path $raiz "src\Plegable.tsx"))) { Mal "Primero corre aplicar-sos-mapa-configuracion-app.ps1."; return }
if (-not (Test-Path (Join-Path $raiz "src\proteccion.ts"))) { Mal "Falta src\proteccion.ts: primero corre aplicar-familia-proteccion-app.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\proteccion.ts")).texto 'bluetoothAudioConectado') -ne 0) { Avi "Dr. Ojo Guard ya estaba aplicado. No toco nada."; return }
$cambios = @()
$descargas = @(
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/34acac8c041419cdcf8c08f4ce36ff2d5e28b6b1/scripts/familia/proteccion.ts", "src\proteccion.ts", "e9fd877e0b7f8c568b98431f11dee5a4ab31c95fc0048366f39c50eccb9eb31c"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/34acac8c041419cdcf8c08f4ce36ff2d5e28b6b1/scripts/familia/ProteccionBlock.tsx", "src\ProteccionBlock.tsx", "b075926584a98b8e83dc4323389940cf5a1a60f50d510a9976f45542703af9d2"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/34acac8c041419cdcf8c08f4ce36ff2d5e28b6b1/scripts/familia/sosTask.ts", "src\sosTask.ts", "cd4c622ca494d6bc9e46e847e881d39e5c6991671995e511ca5b14a49ec1db17"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/34acac8c041419cdcf8c08f4ce36ff2d5e28b6b1/scripts/familia/sos-trigger/index.ts", "modules\sos-trigger\index.ts", "24750f0e4c950dcfa13857364c0a78b58c73d7a3e1667d05bf0e1e9d54e5ef9f"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/34acac8c041419cdcf8c08f4ce36ff2d5e28b6b1/scripts/familia/sos-trigger/android/src/main/java/expo/modules/sostrigger/SosTriggerModule.kt", "modules\sos-trigger\android\src\main\java\expo\modules\sostrigger\SosTriggerModule.kt", "dfab1d46d4ca06dcf81b2512baa2231423b33a69ec1f24644ab7bdb6b0f9ef20")
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
    if (Test-Path ($ruta + ".bak-dr")) { Mal ("Ya existe " + $t + ".bak-dr. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-dr"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-dr): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-dr") -Destination $ruta -Force }
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
Ok "LISTO: la app compila bien. Hace falta una build de Android (tiene codigo nativo nuevo). El iPhone recibe el nombre nuevo en su proxima build."
Write-Host ""
