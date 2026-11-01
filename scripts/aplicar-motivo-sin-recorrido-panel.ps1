# aplicar-motivo-sin-recorrido-panel.ps1 - Ojo Guard MS: cuando una persona no muestra recorrido, el mapa dice por que.
# Motivo (01/11/2026, Luciano: "toque a Luli y no hay datos"; su tarjeta decia "Sin conexion, hace 8 h"): el mapa no dibujaba nada y no explicaba nada. Ahora un cartel de 7 segundos dice: ubicacion pausada, sin permiso para ver ese recorrido, o sin recorrido guardado en ese periodo (y si el telefono figura sin conexion), con la ultima ubicacion conocida y hace cuanto.
# Cambia SOLO src\panel-mapa.txt y src\panel-index.html (v=13). Respaldo .bak-motivo. Va en la carpeta del PANEL. Sin build.
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
foreach ($f in @("src\panel-mapa.txt", "src\panel-index.html")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\panel-mapa.txt")).texto 'function avisarSinRecorrido') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\panel-index.html")).texto '/mapa-v1.js?v=12') -ne 1) { Mal "El mapa no esta en v=12 (falta aplicar primero aplicar-paradas-iphone-panel.ps1). No toco nada."; return }
$cambios = @(
    @('src\panel-mapa.txt', 'mapa: avisar el motivo al elegir a una persona', '    try { estado.recorrido = await cargarRecorrido(equipoElegido()); } catch { estado.recorrido = []; }
', '    try { estado.recorrido = await cargarRecorrido(equipoElegido()); } catch { estado.recorrido = []; }
    avisarSinRecorrido();
'),
    @('src\panel-mapa.txt', 'mapa: avisar el motivo al cambiar de rango', '  const puntos = filtrarPorRango(estado.recorrido, rango);
  if (puntos.length > 1) estado.proveedor?.encuadrar(puntos, margenMapa());
}
', '  const puntos = filtrarPorRango(estado.recorrido, rango);
  if (puntos.length > 1) estado.proveedor?.encuadrar(puntos, margenMapa());
  avisarSinRecorrido();
}
'),
    @('src\panel-mapa.txt', 'mapa: avisar el motivo en Un dia', '  if (estado.recorridoDia.length > 1) estado.proveedor?.encuadrar(estado.recorridoDia, margenMapa());
}
', '  if (estado.recorridoDia.length > 1) estado.proveedor?.encuadrar(estado.recorridoDia, margenMapa());
  avisarSinRecorrido();
}
'),
    @('src\panel-mapa.txt', 'mapa: funcion del motivo', '// "Otro dia": el recorrido y todas las paradas de un dia puntual', '// Si una persona no muestra recorrido, el mapa dice por que (y el cartel se va solo a los 7 segundos). En vivo no dice nada.
function avisarSinRecorrido() {
  const e = equipoElegido();
  if (!e || e.tipo !== "persona" || estado.rango === "vivo") return;
  const ultima = e.lat !== null ? ` Última ubicación: ${e.direccion || `${e.lat.toFixed(5)}, ${e.lng.toFixed(5)}`} (${textoHace(e)}).` : "";
  let texto = "";
  if (e.pausado) texto = `${e.nombre} tiene la ubicación pausada: no se ve su recorrido.`;
  else if (!e.conRecorrido) texto = `No podés ver el recorrido de ${e.nombre}. Lo ven el titular y los adultos de la familia, y solo el de los menores (el titular también ve el de los adultos).${ultima}`;
  else if (!puntosDelRango().length && !estado.cargandoDia) texto = `No hay recorrido guardado de ${e.nombre} en este período.${e.enLinea ? "" : " Su teléfono figura sin conexión."}${ultima}`;
  aviso(texto);
  clearTimeout(estado.temporizadorMotivo);
  if (texto) estado.temporizadorMotivo = setTimeout(() => aviso(""), 7000);
}

// "Otro dia": el recorrido y todas las paradas de un dia puntual'),
    @('src\panel-index.html', 'recargar el mapa nuevo (v=13)', '<script type="module" src="/mapa-v1.js?v=12"></script>', '<script type="module" src="/mapa-v1.js?v=13"></script>')
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
    if (Test-Path ($ruta + ".bak-motivo")) { Mal ("Ya existe " + $t + ".bak-motivo. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-motivo"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-motivo): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-motivo") -Destination $ruta -Force }
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
Ok "LISTO: el mapa dice por que una persona no muestra recorrido. Cerra y abri la app (o recarga la pagina del mapa)."
Write-Host ""
