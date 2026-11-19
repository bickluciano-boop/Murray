# aplicar-lugar-guardado-panel.ps1 - Ojo Guard MS (panel, pestana Dispositivos): si la ultima ubicacion de un equipo cae dentro de un lugar guardado (Casa, Trabajo...), la tarjeta dice "En Casa · <calle>" y no solo la calle mas cercana.
# Luciano (19/11/2026): el 18/11 el panel mostro "Cervino" con el telefono en la pileta de su casa y salio corriendo al supermercado. Los lugares se leen de /api/remote/family (los mismos del mapa), una vez cada 5 minutos.
# SOLO texto en el panel (sin SMS ni mails). Cambia src\panel-app.txt (respaldo .bak-lugarguardado). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
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

if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\panel-app.txt"))) { Mal "No encuentro src\panel-app.txt en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\panel-app.txt")).texto 'lugarYDireccion') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
$cambios = @(
    @('src\panel-app.txt', 'lugar guardado: la grilla de la tarjeta usa el lugar', 'const gridAddress = withApprox(device.lastLocation?.address)', 'const gridAddress = lugarYDireccion(device.lastLocation, withApprox(device.lastLocation?.address))'),
    @('src\panel-app.txt', 'lugar guardado: el resumen de ultima ubicacion usa el lugar', 'formatBuenosAiresDate(device.lastLocationAt) : "recibida"}${location.address ? ` · ${withApprox(location.address)}` : ""}.`;', 'formatBuenosAiresDate(device.lastLocationAt) : "recibida"}${lugarYDireccion(location, location.address ? withApprox(location.address) : "") ? ` · ${lugarYDireccion(location, location.address ? withApprox(location.address) : "")}` : ""}.`;'),
    @('src\panel-app.txt', 'lugar guardado: las funciones que lo calculan', 'function nearbySummary(entries) {', '// Lugares guardados (Casa, Trabajo...): si la ultima ubicacion de un equipo cae dentro de uno, la tarjeta dice "En Casa" y no solo la calle mas cercana
// (18/11/2026: el panel mostro "Cervino" y el telefono estaba en la pileta de la casa). Se leen de /api/remote/family, una vez cada 5 minutos. Solo texto.
var lugaresGuardados = null, lugaresGuardadosPedidos = 0;
function distanciaMetros(lat1, lng1, lat2, lng2) {
  const rad = Math.PI / 180, dLat = (lat2 - lat1) * rad, dLng = (lng2 - lng1) * rad;
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(lat1 * rad) * Math.cos(lat2 * rad) * Math.sin(dLng / 2) ** 2;
  return 12742000 * Math.asin(Math.sqrt(h));
}
function cargarLugaresGuardados() {
  lugaresGuardadosPedidos = Date.now();
  api("/api/remote/family", { cache: "no-store" }).then((respuesta) => {
    const antes = JSON.stringify(lugaresGuardados);
    lugaresGuardados = Array.isArray(respuesta?.places) ? respuesta.places : [];
    // Llegaron por primera vez (o cambiaron): se vuelve a dibujar la tarjeta una sola vez.
    if (JSON.stringify(lugaresGuardados) !== antes && typeof loadSession === "function") loadSession();
  }).catch(() => undefined);
}
function lugarYDireccion(location, direccion) {
  const lat = Number(location?.latitude), lng = Number(location?.longitude);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return direccion;
  if (Date.now() - lugaresGuardadosPedidos > (lugaresGuardados ? 5 * 60_000 : 60_000)) cargarLugaresGuardados();
  let mejor = null;
  for (const lugar of lugaresGuardados || []) {
    const lt = Number(lugar.latitude), ln = Number(lugar.longitude), radio = Number(lugar.radius);
    if (!Number.isFinite(lt) || !Number.isFinite(ln) || !Number.isFinite(radio) || !String(lugar.name || "").trim()) continue;
    const metros = distanciaMetros(lat, lng, lt, ln);
    if (metros <= radio && (!mejor || metros < mejor.metros)) mejor = { nombre: String(lugar.name).trim().slice(0, 40), metros };
  }
  if (!mejor) return direccion;
  return `En ${mejor.nombre}${direccion ? ` · ${direccion}` : ""}`;
}

function nearbySummary(entries) {')
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
    if (Test-Path ($ruta + ".bak-lugarguardado")) { Mal ("Ya existe " + $t + ".bak-lugarguardado. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-lugarguardado"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-lugarguardado): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-lugarguardado") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "Archivos listos. Ahora publico el panel..."
& npx.cmd wrangler deploy
if ($LASTEXITCODE -ne 0) { Mal "No se pudo publicar el panel. Mandame esta pantalla."; return }
Write-Host ""
Ok "LISTO: si la ultima ubicacion de un equipo cae dentro de un lugar guardado, la tarjeta dice "En Casa" y la calle. Solo texto."
Write-Host ""
