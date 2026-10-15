# aplicar-consola-direcciones-panel.ps1 - Consola (Ojo Guard MS), paso 2c: la calle en vez de las coordenadas, y "activo hace X" cuando la ubicacion es vieja.
#  - Si un telefono manda su ubicacion en vivo solo con coordenadas (sin calle), la consola pide la calle y la altura al servidor (OpenStreetMap)
#    y las muestra apenas llegan, tanto en Mis Equipos como en Mapa y Familia. Se pide de a una por vez y sin repetir el mismo punto.
#  - Si un equipo esta activo pero su ultima ubicacion es vieja (por ejemplo un iPhone quieto con la app abierta), el mapa dice
#    "activo hace 3 min - ubicacion hace 23 h" en vez de solo "hace 23 h", para que no parezca desconectado.
# Ninguna funcion se saca ni cambia. Va en la carpeta del PANEL (la que tiene wrangler.toml). Toca src\panel-app.txt y src\panel-mapa.txt.
# Respaldo .bak-direcciones. Al final publica el panel solo.
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
foreach ($f in @("src\panel-app.txt", "src\panel-mapa.txt")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\panel-app.txt")).texto 'completarDireccionesEquipos') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
$cambios = @(
    @('src\panel-app.txt', 'mis equipos: completar la calle que falta', 'function renderDevices(devices) {
  devicesRoot.replaceChildren();', ('// La ubicaci' + [char]0x00f3 + 'n en vivo llega solo con coordenadas, sin calle. Se pide la calle al servidor (OpenStreetMap), de a una por vez
// y sin repetir el mismo punto, y se muestra apenas llega.
const direccionesEquipos = new Map();
let direccionEquipoEnCurso = false, ultimosEquipos = [];
function completarDireccionesEquipos(devices) {
  if (demoMode) return;
  ultimosEquipos = devices;
  let pendiente = null;
  for (const device of devices) {
    const ubicacion = device.lastLocation;
    const lat = Number(ubicacion?.latitude), lng = Number(ubicacion?.longitude);
    if (!ubicacion || ubicacion.address || !Number.isFinite(lat) || !Number.isFinite(lng)) continue;
    const clave = `${lat.toFixed(4)},${lng.toFixed(4)}`;
    const guardada = direccionesEquipos.get(clave);
    if (guardada) ubicacion.address = guardada;
    else if (guardada === undefined && !pendiente) pendiente = { lat, lng, clave };
  }
  if (!pendiente || direccionEquipoEnCurso) return;
  direccionEquipoEnCurso = true;
  api(`/api/remote/address?lat=${encodeURIComponent(pendiente.lat)}&lng=${encodeURIComponent(pendiente.lng)}`)
    .then((r) => direccionesEquipos.set(pendiente.clave, typeof r?.address === "string" ? r.address : ""))
    .catch(() => { direccionesEquipos.set(pendiente.clave, ""); setTimeout(() => direccionesEquipos.delete(pendiente.clave), 60_000); })
    .finally(() => setTimeout(() => { direccionEquipoEnCurso = false; renderDevices(ultimosEquipos); }, 1200));
}

function renderDevices(devices) {
  completarDireccionesEquipos(devices);
  devicesRoot.replaceChildren();')),
    @('src\panel-mapa.txt', 'mapa: completar la calle que falta y aclarar el activo', 'async function refrescar(forzarRecorrido = false) {', ('// La ubicaci' + [char]0x00f3 + 'n en vivo de un tel' + [char]0x00e9 + 'fono llega solo con coordenadas, sin calle. Se pide la calle al servidor (OpenStreetMap),
// de a una por vez y sin repetir el mismo punto, y se muestra apenas llega.
const direccionesMapa = new Map();
let direccionMapaEnCurso = false;
function completarDirecciones(equipos) {
  if (DEMO) return;
  let pendiente = null;
  for (const e of equipos) {
    if (e.direccion || e.lat === null || e.lng === null) continue;
    const clave = `${e.lat.toFixed(4)},${e.lng.toFixed(4)}`;
    const guardada = direccionesMapa.get(clave);
    if (guardada) e.direccion = guardada;
    else if (guardada === undefined && !pendiente) pendiente = { e, clave };
  }
  if (!pendiente || direccionMapaEnCurso) return;
  direccionMapaEnCurso = true;
  direccionDe({ lat: pendiente.e.lat, lng: pendiente.e.lng })
    .then((texto) => direccionesMapa.set(pendiente.clave, direccionCorta(texto) || ""))
    .catch(() => { direccionesMapa.set(pendiente.clave, ""); setTimeout(() => direccionesMapa.delete(pendiente.clave), 60_000); })
    .finally(() => setTimeout(() => {
      direccionMapaEnCurso = false;
      if (!estado.abierto) return;
      completarDirecciones(estado.equipos);
      dibujar();
    }, 1200));
}

// Si el equipo dio se' + [char]0x00f1 + 'ales de vida mucho despu' + [char]0x00e9 + 's de su ' + [char]0x00fa + 'ltima ubicaci' + [char]0x00f3 + 'n (por ejemplo un iPhone quieto con la app abierta),
// se aclara: as' + [char]0x00ed + ' "hace 23 h" no parece que est' + [char]0x00e9 + ' desconectado.
function textoHace(e, corto = false) {
  const base = haceCuanto(e.ubicadoEn);
  if (e.vistoEn && e.ubicadoEn) {
    const visto = new Date(e.vistoEn).getTime();
    if (visto - new Date(e.ubicadoEn).getTime() > 15 * 60_000 && Date.now() - visto < 10 * 60_000) return corto ? `activo ${haceCuanto(e.vistoEn)}` : `activo ${haceCuanto(e.vistoEn)} ' + [char]0x00b7 + ' ubicaci' + [char]0x00f3 + 'n ${base}`;
  }
  return base;
}

async function refrescar(forzarRecorrido = false) {')),
    @('src\panel-mapa.txt', 'mapa: pedir las calles al actualizar', '    estado.equipos = await cargarEquipos();
    aviso("");', '    estado.equipos = await cargarEquipos();
    completarDirecciones(estado.equipos);
    aviso("");'),
    @('src\panel-mapa.txt', 'mapa: lista con activo hace', '${esc(haceCuanto(e.ubicadoEn))}${bat}', '${esc(textoHace(e, true))}${bat}'),
    @('src\panel-mapa.txt', 'mapa: tarjeta con activo hace', '${esc(haceCuanto(elegido.ubicadoEn))}${distanciaA(elegido)', '${esc(textoHace(elegido))}${distanciaA(elegido)')
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
    if (Test-Path ($ruta + ".bak-direcciones")) { Mal ("Ya existe " + $t + ".bak-direcciones. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-direcciones"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-direcciones): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-direcciones") -Destination $ruta -Force }
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
Ok "LISTO: el panel quedo publicado. Abrilo y mandame fotos (en la compu y en el celular)."
Write-Host ""
