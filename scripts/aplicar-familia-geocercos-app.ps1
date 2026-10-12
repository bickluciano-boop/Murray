# aplicar-familia-geocercos-app.ps1 - Avisos de llegada y salida confiables en iPhone, parte de la app.
# Suma src\familyGeofence.ts: iPhone vigila los lugares de los avisos ("avisame cuando X llegue o salga de Casa") con geocercos
# del sistema y despierta a la app al cruzarlos, aunque este cerrada. Antes el aviso dependia de que el telefono mandara un punto
# justo al llegar, y no pasaba si se pausaba el seguimiento un poco antes de casa. Toca src\familyLocation.ts.
# Va en la carpeta de la APP (la que tiene app.json). Respaldo .bak-geocercos. Sale en la PROXIMA build de iPhone; Android no cambia.
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
if (-not (Test-Path (Join-Path $raiz "src\familyLocation.ts"))) { Mal "Falta la ubicacion de familia para iPhone: primero corre aplicar-familia-iphone.ps1."; return }
if ((Test-Path (Join-Path $raiz "src\familyGeofence.ts")) -or ((Contar (Leer (Join-Path $raiz "src\familyLocation.ts")).texto 'familyGeofence') -ne 0)) { Avi "Los geocercos ya estaban aplicados en la app. No toco nada."; return }
$cambios = @(
    @('src\familyLocation.ts', 'import de los geocercos', 'import { loadNativeEnrollment } from "./remoteStorage";
', 'import { loadNativeEnrollment } from "./remoteStorage";
import { adjustFamilyGeofences, stopFamilyGeofences } from "./familyGeofence";
'),
    @('src\familyLocation.ts', 'al ajustar la ubicacion de familia', '      await Location.stopLocationUpdatesAsync(TAREA_FAMILIA).catch(() => undefined);
    }
    return;
  }
  if (!(await familyLocationAllowed())) return;
  await activar().catch(() => undefined);
}
', '      await Location.stopLocationUpdatesAsync(TAREA_FAMILIA).catch(() => undefined);
    }
    await stopFamilyGeofences().catch(() => undefined);
    return;
  }
  if (!(await familyLocationAllowed())) return;
  await activar().catch(() => undefined);
  // Los lugares de los avisos de llegada y salida (geocercos del sistema, ver familyGeofence.ts).
  await adjustFamilyGeofences(true).catch(() => undefined);
}
'),
    @('src\familyLocation.ts', 'al llegar un punto de movimiento', '    await sendLiveLocation(enrollment, punto).catch(() => undefined);
    if (AppState.currentState !== "active"', '    await sendLiveLocation(enrollment, punto).catch(() => undefined);
    // De paso se renueva la lista de lugares a vigilar (como mucho cada 10 minutos).
    await adjustFamilyGeofences().catch(() => undefined);
    if (AppState.currentState !== "active"')
)
$descargas = @(
    ,@("https://raw.githubusercontent.com/bickluciano-boop/Murray/856539a/scripts/familia/familyGeofence.ts", "src\familyGeofence.ts", "2bd05b4adca3b3c67c1eae66093a8fd96b1283f0c2fea94d048f28d4a2bffc2c")
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
    if (Test-Path ($ruta + ".bak-geocercos")) { Mal ("Ya existe " + $t + ".bak-geocercos. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-geocercos"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-geocercos): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-geocercos") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "TODO BIEN. Para revisar que compile:  powershell -ExecutionPolicy Bypass -Command ""npx tsc --noEmit""  (si no muestra nada, esta perfecto)"
Ok "Sale en la PROXIMA build de iPhone. En Android no cambia nada."
Write-Host ""
