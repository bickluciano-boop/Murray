# aplicar-familia-sos-mejoras-app.ps1 - SOS de Familia, mejoras de la app (despues de aplicar-familia-sos-app.ps1):
#  - El bloque SOS (boton, "Estoy bien", gesto de volumen) tambien se ve en el telefono del TITULAR: antes solo aparecia en quien se
#    habia unido a una familia, y el titular no tenia como cancelar un SOS.
#  - Android: canal propio "SOS de la familia" con la sirena de Ojo Guard, volumen de alarma y pedido de atravesar "No interrumpir",
#    mas un boton que abre esa pantalla del sistema para activarlo a mano.
#  - iPhone: permiso de aviso "urgente" (Time Sensitive) en app.json, para que el SOS atraviese los modos de concentracion.
# Toca src\FamilySection.tsx y app.json, y reemplaza src\SosBlock.tsx, src\sosTask.ts y dos archivos de modules\sos-trigger.
# Va en la carpeta de la APP (la que tiene app.json). Respaldo .bak-sos2. Sale en la PROXIMA build (Android y iPhone). Tiene codigo
# nativo de Android (una funcion nueva), asi que hace falta build de Android.
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
if (-not (Test-Path (Join-Path $raiz "src\SosBlock.tsx"))) { Mal "Primero corre aplicar-familia-sos-app.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "modules\sos-trigger\index.ts")).texto 'openSosChannelSettings') -ne 0) { Avi "Las mejoras del SOS ya estaban aplicadas. No toco nada."; return }
$cambios = @(
    @('src\FamilySection.tsx', 'el bloque SOS tambien para el titular', '<SosBlock enrollment={enrollment} visible={me.memberships > 0} paleta={P} botones={botones} />', '<SosBlock enrollment={enrollment} visible={me.memberships > 0 || people.length > 0} paleta={P} botones={botones} />'),
    @('app.json', 'aviso urgente en iPhone (Time Sensitive)', '      "requireFullScreen": true,
', '      "requireFullScreen": true,
      "entitlements": {
        "com.apple.developer.usernotifications.time-sensitive": true
      },
')
)
$descargas = @(
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/a3290c7/scripts/familia/SosBlock.tsx", "src\SosBlock.tsx", "c8e3c30359adc9a6e54452d0c569659dfa644b1aac4bfb75960e5ec0cfb7e8bb"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/a3290c7/scripts/familia/sosTask.ts", "src\sosTask.ts", "ea3a6db6452e0a40c3fbd1581c0e3e1e9026b47babc563c98f416059ad5da1e1"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/a3290c7/scripts/familia/sos-trigger/index.ts", "modules\sos-trigger\index.ts", "08c77707d6a5fc0d1d22756c1a87cd41dd63e929cda7de2c171b48f207d2ff51"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/a3290c7/scripts/familia/sos-trigger/android/src/main/java/expo/modules/sostrigger/SosTriggerModule.kt", "modules\sos-trigger\android\src\main\java\expo\modules\sostrigger\SosTriggerModule.kt", "bb024e8569f8d66cb8c88a9f707831b7113be7fccb384e934160bd97266db2ac")
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
    if (Test-Path ($ruta + ".bak-sos2")) { Mal ("Ya existe " + $t + ".bak-sos2. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-sos2"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-sos2): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-sos2") -Destination $ruta -Force }
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
Ok "LISTO: la app compila bien. Las mejoras salen en la PROXIMA build (Android y iPhone)."
Write-Host ""
