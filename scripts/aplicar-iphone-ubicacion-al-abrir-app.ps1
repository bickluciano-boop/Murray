# aplicar-iphone-ubicacion-al-abrir-app.ps1 - iPhone: la ubicacion se actualiza apenas se abre la app.
# Con el iPhone quieto, iOS pausa el seguimiento de fondo y no manda ningun punto: la consola seguia mostrando la ubicacion de hace horas
# aunque la app estuviera abierta (el aviso de que el telefono esta vivo si llegaba). Ahora, al abrir Ojo Guard o al volver a ella (como mucho
# una vez por minuto), el iPhone manda tambien una ubicacion actual, siempre que comparta su ubicacion con alguien y tenga el permiso "Siempre".
# No cambia nada en Android. Toca src\familyLocation.ts. Va en la carpeta de la APP (la que tiene app.json). Respaldo .bak-puntoabrir.
# Es solo codigo de la app (nada nativo): sale en la PROXIMA build.
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
if (-not (Test-Path (Join-Path $raiz "src\familyLocation.ts"))) { Mal "No encuentro src\familyLocation.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\familyLocation.ts")).texto 'mandarUbicacionActual') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
$cambios = @(
    @('src\familyLocation.ts', 'import del tipo de la inscripcion', 'import { loadNativeEnrollment } from "./remoteStorage";', 'import { loadNativeEnrollment, type NativeEnrollment } from "./remoteStorage";'),
    @('src\familyLocation.ts', 'armar el punto en una sola funcion y mandar uno al abrir', ('/** En iPhone, si la ubicaci' + [char]0x00f3 + 'n est' + [char]0x00e1 + ' permitida "Siempre" (en Android no se usa: devuelve true). */'), ('/** Arma el punto que se manda al servidor a partir de una posici' + [char]0x00f3 + 'n del GPS. */
async function puntoDe(position: Location.LocationObject): Promise<LiveLocationPoint> {
  return {
    latitude: position.coords.latitude,
    longitude: position.coords.longitude,
    accuracy: Math.max(0, Number(position.coords.accuracy) || 0),
    capturedAt: new Date(position.timestamp).toISOString(),
    altitude: position.coords.altitude ?? null,
    heading:
      Number.isFinite(position.coords.heading) && (position.coords.heading as number) >= 0
        ? position.coords.heading
        : null,
    speed:
      Number.isFinite(position.coords.speed) && (position.coords.speed as number) >= 0
        ? position.coords.speed
        : null,
    address: await direccionPara(position),
    live: false,
  };
}

/**
 * Una ubicaci' + [char]0x00f3 + 'n actual apenas se abre la app (o vuelve al frente). Con el iPhone quieto, iPhone pausa el seguimiento y no sale
 * ning' + [char]0x00fa + 'n punto: la consola segu' + [char]0x00ed + 'a mostrando la ubicaci' + [char]0x00f3 + 'n de hace horas aunque la app estuviera abierta y el tel' + [char]0x00e9 + 'fono en uso.
 */
async function mandarUbicacionActual(enrollment: NativeEnrollment) {
  // Con "Seguir en vivo" prendido ya sale un punto cada 5 segundos.
  if (await liveLocationRunning()) return;
  const position = await Promise.race([
    Location.getCurrentPositionAsync({ accuracy: Location.Accuracy.Balanced }).catch(() => null),
    new Promise<null>((resolve) => setTimeout(() => resolve(null), 15_000)),
  ]);
  if (!position) return;
  // Sin red se pierde este punto; el pr' + [char]0x00f3 + 'ximo movimiento o la pr' + [char]0x00f3 + 'xima vez que se abra manda otro.
  await sendLiveLocation(enrollment, await puntoDe(position)).catch(() => undefined);
}

/** En iPhone, si la ubicaci' + [char]0x00f3 + 'n est' + [char]0x00e1 + ' permitida "Siempre" (en Android no se usa: devuelve true). */')),
    @('src\familyLocation.ts', 'al ajustar la ubicacion de la familia: mandar una actual', '  await activar().catch(() => undefined);
  // Los lugares de los avisos', ('  await activar().catch(() => undefined);
  // Una ubicaci' + [char]0x00f3 + 'n actual ahora mismo (quieto, iPhone no manda ninguna por su cuenta).
  if (enrollment) await mandarUbicacionActual(enrollment).catch(() => undefined);
  // Los lugares de los avisos')),
    @('src\familyLocation.ts', 'la tarea de fondo usa la misma funcion para armar el punto', '    const punto: LiveLocationPoint = {
      latitude: position.coords.latitude,
      longitude: position.coords.longitude,
      accuracy: Math.max(0, Number(position.coords.accuracy) || 0),
      capturedAt: new Date(position.timestamp).toISOString(),
      altitude: position.coords.altitude ?? null,
      heading:
        Number.isFinite(position.coords.heading) && (position.coords.heading as number) >= 0
          ? position.coords.heading
          : null,
      speed:
        Number.isFinite(position.coords.speed) && (position.coords.speed as number) >= 0
          ? position.coords.speed
          : null,
      address: await direccionPara(position),
      live: false,
    };', '    const punto = await puntoDe(position);')
)
$descargas = @()

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
    if (Test-Path ($ruta + ".bak-puntoabrir")) { Mal ("Ya existe " + $t + ".bak-puntoabrir. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-puntoabrir"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-puntoabrir): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-puntoabrir") -Destination $ruta -Force }
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
Ok "LISTO: la app compila bien. Sale en la PROXIMA build (iPhone)."
Write-Host ""
