# aplicar-en-vivo-app.ps1 - Modo EN VIVO, parte de la app: el telefono manda su ubicacion cada 5 s mientras el panel lo sigue
# Va en la carpeta de la APP (la que tiene app.json). Toca src\domain.ts, src\remoteApi.ts, src\backgroundRemoteTask.ts, App.tsx y app.json,
# y agrega src\liveLocation.ts. Respaldos .bak-envivo; si algo falla, se restaura todo. Sale en la PROXIMA build.
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
if ((Test-Path (Join-Path $raiz "src\liveLocation.ts")) -and ((Contar (Leer (Join-Path $raiz "src\domain.ts")).texto '"live-location"') -ne 0)) { Avi "El modo en vivo ya estaba aplicado en la app. No toco nada."; return }
if (Test-Path (Join-Path $raiz "src\liveLocation.ts")) { Mal "Ya existe src\liveLocation.ts de un intento anterior. No toco nada. Mandame esta pantalla."; return }
$cambios = @(
    @('src\domain.ts', 'tipo de orden en vivo', '  | "locate"
  | "capture-evidence"', '  | "locate"
  | "live-location"
  | "capture-evidence"'),
    @('src\domain.ts', 'nombre de la orden en vivo', '  if (value === "locate" || value === "location" || value === "auto-locate") return "locate";', '  if (value === "locate" || value === "location" || value === "auto-locate") return "locate";
  // Ubicacion en vivo pedida desde el mapa del panel (ver src/liveLocation.ts).
  if (value === "live" || value === "live-location") return "live-location";'),
    @('src\remoteApi.ts', 'envio de puntos en vivo', 'export async function reportLostModeDeactivated(', 'export type LiveLocationPoint = {
  latitude: number;
  longitude: number;
  accuracy: number;
  capturedAt: string;
  altitude: number | null;
  heading: number | null;
  speed: number | null;
  address: string | null;
  live: true;
};

/** Manda un punto de la ubicacion en vivo. El servidor contesta si hay que seguir y hasta cuando. */
export async function sendLiveLocation(
  enrollment: NativeEnrollment,
  location: LiveLocationPoint,
): Promise<{ live: boolean; until: string | null }> {
  const response = await nativeRequest(enrollment, "/api/native/location", {
    method: "POST",
    body: JSON.stringify({ deviceId: enrollment.deviceId, location }),
  });
  const result = (await response.json().catch(() => ({}))) as { live?: boolean; until?: string | null };
  return { live: result.live === true, until: result.until ?? null };
}

export async function reportLostModeDeactivated('),
    @('src\backgroundRemoteTask.ts', 'importar en vivo', 'import { getBestEffortPosition } from "./locationSampling";', 'import { getBestEffortPosition } from "./locationSampling";
import { startLiveLocation } from "./liveLocation";'),
    @('src\backgroundRemoteTask.ts', 'orden en vivo en segundo plano', '      if (command.kind === "locate") {
        return { location: await backgroundLocation() };
      }', '      if (command.kind === "live-location") {
        // Arranca el seguimiento y vuelve enseguida: los puntos los manda la
        // tarea de ubicacion (src/liveLocation.ts), no esta sincronizacion.
        await startLiveLocation(command.expiresAt);
        return {};
      }
      if (command.kind === "locate") {
        return { location: await backgroundLocation() };
      }'),
    @('App.tsx', 'importar en vivo', 'import { registerBackgroundRemoteTask } from "./src/backgroundRemoteTask";', 'import { registerBackgroundRemoteTask } from "./src/backgroundRemoteTask";
import { startLiveLocation } from "./src/liveLocation";'),
    @('App.tsx', 'orden en vivo con la app abierta', '      if (command.kind === "locate") {
        const location = await captureLocation();', '      if (command.kind === "live-location") {
        await startLiveLocation(command.expiresAt);
        return {};
      }
      if (command.kind === "locate") {
        const location = await captureLocation();'),
    @('app.json', 'modo de fondo de ubicacion en iPhone', '        "UIBackgroundModes": [
          "remote-notification"
        ]', '        "UIBackgroundModes": [
          "remote-notification",
          "location"
        ]'),
    @('app.json', 'permisos de ubicacion en vivo en Android', '        "FOREGROUND_SERVICE_MICROPHONE",', '        "FOREGROUND_SERVICE_MICROPHONE",
        "FOREGROUND_SERVICE_LOCATION",
        "ACCESS_BACKGROUND_LOCATION",'),
    @('app.json', 'ubicacion de fondo en iPhone', '          "isAndroidBackgroundLocationEnabled": true,
          "isAndroidForegroundServiceEnabled": true', '          "isAndroidBackgroundLocationEnabled": true,
          "isAndroidForegroundServiceEnabled": true,
          "isIosBackgroundLocationEnabled": true')
)
$descargas = @(
    ,@("https://raw.githubusercontent.com/bickluciano-boop/Murray/a4264a8/scripts/vivo/liveLocation.ts", "src\liveLocation.ts", "640c4f3578f4eb5ca922b7d32682ce7ebf5b13f83ce81aa509a4765c34808dda")
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
    if (Test-Path ($ruta + ".bak-envivo")) { Mal ("Ya existe " + $t + ".bak-envivo. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-envivo"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-envivo): " + ($respaldados -join ", "))

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
$json = $null
try { $json = (Leer (Join-Path $raiz "app.json")).texto | ConvertFrom-Json } catch { }
Chk "app.json: sigue siendo valido" ($json -ne $null)
if ($json -ne $null) {
    $loc = @($json.expo.plugins | Where-Object { ($_ -is [System.Array]) -and $_[0] -eq "expo-location" })
    Chk "app.json: ubicacion en segundo plano (Android e iPhone)" (($loc.Count -eq 1) -and ($loc[0][1].isAndroidForegroundServiceEnabled -eq $true) -and ($loc[0][1].isIosBackgroundLocationEnabled -eq $true))
    Chk "app.json: permisos de Android" ((@($json.expo.android.permissions) -contains "FOREGROUND_SERVICE_LOCATION") -and (@($json.expo.android.permissions) -contains "ACCESS_BACKGROUND_LOCATION"))
    Chk "app.json: icono y pantalla de carga intactos" (($json.expo.icon -eq "./assets/icon-ojo-pin.png") -and ((@($json.expo.plugins | Where-Object { ($_ -is [System.Array]) -and $_[0] -eq "expo-splash-screen" })).Count -eq 1))
}

if (-not $todoBien) {
    Mal "Algo no salio bien. Restauro todo desde los respaldos."
    foreach ($t in $tocados) {
        $ruta = Join-Path $raiz $t
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-envivo") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "TODO BIEN. El modo en vivo sale en la PROXIMA build (Android y iPhone). No hace falta hacer una solo por esto."
Write-Host ""
