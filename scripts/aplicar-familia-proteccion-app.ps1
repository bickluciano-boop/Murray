# aplicar-familia-proteccion-app.ps1 - "Revisar mi proteccion" (despues de aplicar-familia-sos-mejoras-app.ps1):
#  - Boton "Revisar mi proteccion" en Configuracion > Familia, arriba del SOS: muestra un porcentaje y, por cada cosa que falta
#    (avisos, ubicacion "Siempre", gesto de volumen, sirena, bateria, atajo del iPhone), un boton que lleva a donde se arregla.
#  - Android: detecta el gesto de volumen "prendido pero caido" (Android lo muestra activado y no responde) y avisa con una
#    notificacion, al abrir la app y con el trabajo periodico de fondo.
# Crea src\proteccion.ts y src\ProteccionBlock.tsx; cambia src\FamilySection.tsx y src\backgroundFetchTask.ts; reemplaza
# src\sosTask.ts y tres archivos de modules\sos-trigger. Va en la carpeta de la APP (la que tiene app.json). Respaldo .bak-prot.
# Tiene codigo nativo de Android (el servicio avisa si esta conectado), asi que hace falta build de Android; el iPhone la
# recibe en su proxima build.
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
if ((Contar (Leer (Join-Path $raiz "modules\sos-trigger\index.ts")).texto 'openSosChannelSettings') -eq 0) { Mal "Primero corre aplicar-familia-sos-mejoras-app.ps1."; return }
if (Test-Path (Join-Path $raiz "src\proteccion.ts")) {
    if ((Contar (Leer (Join-Path $raiz "src\proteccion.ts")).texto 'volumen de alarma') -ne 0) { Avi "Revisar mi proteccion ya estaba aplicado. No toco nada."; return }
    Mal "Ya tenias aplicada una version anterior de Revisar mi proteccion. No toco nada: avisame y te paso la actualizacion."; return
}
if (-not (Test-Path (Join-Path $raiz "modules\exact-alarm\index.ts")) -or (Contar (Leer (Join-Path $raiz "modules\exact-alarm\index.ts")).texto 'readBatteryUnrestricted') -eq 0) { Mal "Falta la lectura de bateria de la app (modules\exact-alarm). Mandame esta pantalla."; return }
$cambios = @(
    @('src\FamilySection.tsx', 'import del bloque de proteccion', 'import { SosBlock } from "./SosBlock";
', 'import { SosBlock } from "./SosBlock";
import { ProteccionBlock } from "./ProteccionBlock";
'),
    @('src\FamilySection.tsx', 'bloque Revisar mi proteccion arriba del SOS', '      <SosBlock enrollment={enrollment} visible={me.memberships > 0 || people.length > 0} paleta={P} botones={botones} />
', '      <ProteccionBlock enrollment={enrollment} visible={me.memberships > 0 || people.length > 0} paleta={P} botones={botones} />
      <SosBlock enrollment={enrollment} visible={me.memberships > 0 || people.length > 0} paleta={P} botones={botones} />
'),
    @('src\backgroundFetchTask.ts', 'import de la vigilancia del gesto', 'import { runBackgroundCommandSync } from "./backgroundRemoteTask";
', 'import { runBackgroundCommandSync } from "./backgroundRemoteTask";
import { vigilarGesto } from "./sosTask";
'),
    @('src\backgroundFetchTask.ts', 'vigilar el gesto en el trabajo de fondo', '      await runBackgroundCommandSync("background-fetch");
', '      await runBackgroundCommandSync("background-fetch");
      await vigilarGesto().catch(() => undefined);
')
)
$descargas = @(
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/2b1caa184d75874ef2f64a02bc2cebf30ffedb95/scripts/familia/proteccion.ts", "src\proteccion.ts", "57a2c008a68093a72227dc58e35491c134fa6e5180e872a068f3074bee300cf5"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/2b1caa184d75874ef2f64a02bc2cebf30ffedb95/scripts/familia/ProteccionBlock.tsx", "src\ProteccionBlock.tsx", "e21bf5aff34bcef2540e74100fdf9c7097a08b9cfcb331107d958f39af7f9d46"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/2b1caa184d75874ef2f64a02bc2cebf30ffedb95/scripts/familia/sosTask.ts", "src\sosTask.ts", "367c88b9a4f762b57c4c0e81e647ea379af81253a87a162333c015795755b951"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/2b1caa184d75874ef2f64a02bc2cebf30ffedb95/scripts/familia/sos-trigger/index.ts", "modules\sos-trigger\index.ts", "f8234df578fa2ce3fc4e8e4306eac15df7cff886e57fc486f8efc504b14932cc"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/2b1caa184d75874ef2f64a02bc2cebf30ffedb95/scripts/familia/sos-trigger/android/src/main/java/expo/modules/sostrigger/SosAccessibilityService.kt", "modules\sos-trigger\android\src\main\java\expo\modules\sostrigger\SosAccessibilityService.kt", "3a5c9ee2a49048693a9d715e37f2ad229150a48b667823172a139d817b3ed19b"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/2b1caa184d75874ef2f64a02bc2cebf30ffedb95/scripts/familia/sos-trigger/android/src/main/java/expo/modules/sostrigger/SosTriggerModule.kt", "modules\sos-trigger\android\src\main\java\expo\modules\sostrigger\SosTriggerModule.kt", "9a93321508447220616a1ddbefcc1a452e9d41c788f5f3cd919ad397bd3aa5ab")
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
    if (Test-Path ($ruta + ".bak-prot")) { Mal ("Ya existe " + $t + ".bak-prot. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-prot"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-prot): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-prot") -Destination $ruta -Force }
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
Ok "LISTO: la app compila bien. Hace falta una build de Android (tiene codigo nativo nuevo). El iPhone la recibe en su proxima build."
Write-Host ""
