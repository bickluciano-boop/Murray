# aplicar-mapa-otro-dia-panel.ps1 - Ojo Guard MS: en el mapa, un cuarto boton "Otro dia" (calendario y flechas) para ver el recorrido y TODAS las paradas de un dia puntual.
# Pedido de las mamas (31/10/2026): "si quiero buscar un dia en especial, se podria? Porque la semana entera ves rayas por todos lados". Les gusto mucho ver las paradas con cuanto tiempo estuvo.
# Cambia src\index.ts (el historial acepta from / to), src\panel-mapa.txt y src\panel-index.html (sube a v=5 el numero del script; respaldo .bak-otrodia). Va en la carpeta del PANEL (la que tiene wrangler.toml). No necesita build. Al final publica el panel solo.
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
foreach ($f in @("src\index.ts", "src\panel-mapa.txt", "src\panel-index.html")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\panel-mapa.txt")).texto 'cargarRecorridoDia') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\panel-index.html")).texto '/mapa-v1.js?v=4') -ne 1) { Mal "El mapa no esta en v=4 (falta aplicar primero aplicar-renombrar-equipo-panel.ps1). No toco nada."; return }
$cambios = @(
    @('src\index.ts', 'servidor: el historial acepta un tramo (from / to)', '  const result = await env.DB.prepare(
    "SELECT latitude,longitude,accuracy,altitude,heading,address,captured_at AS capturedAt FROM location_history WHERE device_id=? ORDER BY captured_at DESC LIMIT ?",
  ).bind(deviceId, limit).all();
  return json({ points: result.results });
', '  // "Otro dia" del mapa: los puntos de un tramo (from / to, en ISO) del mas viejo al mas nuevo, hasta 1500. El tramo no puede pasar de dos dias.
  const desdeTramo = Date.parse(url.searchParams.get("from") ?? ""), hastaTramo = Date.parse(url.searchParams.get("to") ?? "");
  if (Number.isFinite(desdeTramo) && Number.isFinite(hastaTramo) && hastaTramo > desdeTramo && hastaTramo - desdeTramo <= 2 * 86_400_000) {
    const tope = Number.isFinite(limitParam) ? Math.max(1, Math.min(1500, Math.trunc(limitParam))) : 1500;
    const tramo = await env.DB.prepare(
      "SELECT latitude,longitude,accuracy,altitude,heading,address,captured_at AS capturedAt FROM location_history WHERE device_id=? AND captured_at>=? AND captured_at<? ORDER BY captured_at ASC LIMIT ?",
    ).bind(deviceId, new Date(desdeTramo).toISOString(), new Date(hastaTramo).toISOString(), tope).all();
    return json({ points: tramo.results });
  }
  const result = await env.DB.prepare(
    "SELECT latitude,longitude,accuracy,altitude,heading,address,captured_at AS capturedAt FROM location_history WHERE device_id=? ORDER BY captured_at DESC LIMIT ?",
  ).bind(deviceId, limit).all();
  return json({ points: result.results });
'),
    @('src\panel-mapa.txt', 'mapa: boton Otro dia y barra del dia', '        <button type="button" data-rango="semana">7 días</button>
      </div>
', '        <button type="button" data-rango="semana">7 días</button>
        <button type="button" data-rango="dia">Otro día</button>
      </div>
      <style id="ogm-dia-css">#og-mapa .ogm-dia{position:absolute;z-index:3;top:72px;left:18px;display:flex;align-items:center;gap:4px;padding:5px;background:var(--ogm-panel);border:1px solid var(--ogm-linea);border-radius:14px;box-shadow:var(--ogm-sombra)}#og-mapa .ogm-dia.hidden{display:none}#og-mapa .ogm-dia button{width:38px;height:38px;border-radius:10px;font-size:1.3rem;color:var(--ogm-oro-vivo)}#og-mapa .ogm-dia input{height:38px;padding:0 8px;border-radius:10px;border:1px solid var(--ogm-linea);background:transparent;color:var(--ogm-texto);font:inherit;font-size:.9rem;color-scheme:dark light}#og-mapa .ogm-dia-txt{font-size:.78rem;color:var(--ogm-suave);padding:0 6px;white-space:nowrap}@media (max-width:899px){#og-mapa .ogm-dia{top:calc(max(12px, env(safe-area-inset-top)) + 56px);left:12px}#og-mapa .ogm-seg button{padding:8px 9px;font-size:.8rem}}</style>
      <div class="ogm-dia hidden" data-ogm="dia-barra">
        <button type="button" data-accion="dia-ant" aria-label="Día anterior">‹</button>
        <input type="date" data-ogm="dia-fecha" aria-label="Elegir el día">
        <button type="button" data-accion="dia-sig" aria-label="Día siguiente">›</button>
        <span class="ogm-dia-txt" data-ogm="dia-txt"></span>
      </div>
'),
    @('src\panel-mapa.txt', 'mapa: calendario (cambio de fecha)', '  raiz.addEventListener("click", (evento) => {
    // Si se mantuvo el dedo sobre un botón', '  raiz.addEventListener("change", (evento) => {
    const campo = evento.target.closest?.(''[data-ogm="dia-fecha"]'');
    if (campo && /^\d{4}-\d{2}-\d{2}$/.test(campo.value) && campo.value <= hoyTexto()) cambiarDia(campo.value);
  });
  raiz.addEventListener("click", (evento) => {
    // Si se mantuvo el dedo sobre un botón'),
    @('src\panel-mapa.txt', 'mapa: flechas del dia', '    if (boton.dataset.rango) return elegirRango(boton.dataset.rango);
', '    if (boton.dataset.rango) return elegirRango(boton.dataset.rango);
    if (boton.dataset.accion === "dia-ant") return moverDia(-1);
    if (boton.dataset.accion === "dia-sig") return moverDia(1);
'),
    @('src\panel-mapa.txt', 'mapa: pedir los puntos de un dia', 'async function enviarOrden(equipo, tipo) {
', '// Todos los puntos de UN dia (hora de Argentina) para "Otro dia": el servidor devuelve hasta 1500 de ese dia.
async function cargarRecorridoDia(equipo, dia) {
  if (!equipo.conRecorrido || DEMO) return [];
  const desde = new Date(`${dia}T00:00:00-03:00`);
  const hasta = new Date(desde.getTime() + 86_400_000);
  const datos = await pedir(`/api/remote/location-history?deviceId=${encodeURIComponent(equipo.id)}&from=${encodeURIComponent(desde.toISOString())}&to=${encodeURIComponent(hasta.toISOString())}&limit=1500`);
  return (datos.points || [])
    .map((p) => ({ lat: numero(p.latitude), lng: numero(p.longitude), precision: numero(p.accuracy), direccion: direccionCorta(p.address), en: p.capturedAt }))
    .filter((p) => p.lat !== null && p.lng !== null && p.en)
    .sort((a, b) => new Date(a.en) - new Date(b.en));
}

async function enviarOrden(equipo, tipo) {
'),
    @('src\panel-mapa.txt', 'mapa: elegir el rango Otro dia', 'function elegirRango(rango) {
  estado.rango = rango;
  document.querySelectorAll("#og-mapa [data-rango]").forEach((b) => b.classList.toggle("on", b.dataset.rango === rango));
  dibujar();
', '// "Otro dia": el recorrido y todas las paradas de un dia puntual (con la semana entera el mapa se llena de rayas).
const hoyTexto = () => new Intl.DateTimeFormat("en-CA", { timeZone: CONFIG.zona, year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date());

/** Los puntos que se muestran ahora: los del dia elegido, o los del rango (En vivo / Hoy / 7 dias). */
function puntosDelRango() {
  return estado.rango === "dia" ? (estado.recorridoDia || []) : filtrarPorRango(estado.recorrido, estado.rango);
}

function textoDia(puntos, lista) {
  const el = document.querySelector(''#og-mapa [data-ogm="dia-txt"]'');
  if (!el) return;
  if (estado.cargandoDia) { el.textContent = "Cargando…"; return; }
  if (!puntos.length) { el.textContent = "Sin recorrido ese día"; return; }
  const km = kilometros(puntos);
  el.textContent = `${lista.length} ${lista.length === 1 ? "parada" : "paradas"} · ${km >= 0.05 ? km.toFixed(1).replace(".", ",") : "0"} km`;
}

async function cambiarDia(dia) {
  estado.dia = dia;
  const campo = document.querySelector(''#og-mapa [data-ogm="dia-fecha"]'');
  if (campo) { campo.value = dia; campo.max = hoyTexto(); }
  const pedido = (estado.pedidoDia = (estado.pedidoDia || 0) + 1);
  estado.recorridoDia = [];
  estado.cargandoDia = true;
  dibujar();
  const equipo = equipoElegido();
  try {
    const puntos = equipo ? await cargarRecorridoDia(equipo, dia) : [];
    if (pedido !== estado.pedidoDia) return;
    estado.recorridoDia = puntos;
  } catch {
    if (pedido !== estado.pedidoDia) return;
    estado.recorridoDia = [];
  }
  estado.cargandoDia = false;
  dibujar();
  if (estado.recorridoDia.length > 1) estado.proveedor?.encuadrar(estado.recorridoDia, margenMapa());
}

function moverDia(delta) {
  const base = new Date(`${estado.dia || hoyTexto()}T12:00:00-03:00`);
  base.setTime(base.getTime() + delta * 86_400_000);
  const nuevo = new Intl.DateTimeFormat("en-CA", { timeZone: CONFIG.zona, year: "numeric", month: "2-digit", day: "2-digit" }).format(base);
  if (nuevo > hoyTexto()) return;
  return cambiarDia(nuevo);
}

function elegirRango(rango) {
  estado.rango = rango;
  document.querySelectorAll("#og-mapa [data-rango]").forEach((b) => b.classList.toggle("on", b.dataset.rango === rango));
  document.querySelector(''#og-mapa [data-ogm="dia-barra"]'')?.classList.toggle("hidden", rango !== "dia");
  if (rango === "dia") return cambiarDia(estado.dia || hoyTexto());
  dibujar();
'),
    @('src\panel-mapa.txt', 'mapa: usar los puntos del dia en el trazo', '    const puntos = elegido ? filtrarPorRango(estado.recorrido, estado.rango) : [];
    const trazo = elegido && elegido.lat !== null && puntos.length ? [...puntos, { lat: elegido.lat, lng: elegido.lng }] : puntos;
', '    const puntos = elegido ? puntosDelRango() : [];
    const trazo = elegido && elegido.lat !== null && puntos.length && estado.rango !== "dia" ? [...puntos, { lat: elegido.lat, lng: elegido.lng }] : puntos;
'),
    @('src\panel-mapa.txt', 'mapa: todas las paradas del dia', '  const lista = paradas(filtrarPorRango(estado.recorrido, estado.rango)).slice(-3).reverse();
', '  // Un dia puntual muestra TODAS sus paradas, en orden; los otros rangos, las tres ultimas.
  const lista = estado.rango === "dia" ? paradas(puntosDelRango()) : paradas(puntosDelRango()).slice(-3).reverse();
  if (estado.rango === "dia") textoDia(puntosDelRango(), lista);
'),
    @('src\panel-mapa.txt', 'mapa: al cambiar de equipo recarga el dia', '    estado.recorrido = [];
    // En la app la tarjeta empieza en una sola fila', '    estado.recorrido = [];
    estado.recorridoDia = [];
    if (estado.rango === "dia") void cambiarDia(estado.dia || hoyTexto());
    // En la app la tarjeta empieza en una sola fila'),
    @('src\panel-index.html', 'recargar el mapa nuevo (v=5)', '<script type="module" src="/mapa-v1.js?v=4"></script>', '<script type="module" src="/mapa-v1.js?v=5"></script>')
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
    if (Test-Path ($ruta + ".bak-otrodia")) { Mal ("Ya existe " + $t + ".bak-otrodia. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-otrodia"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-otrodia): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-otrodia") -Destination $ruta -Force }
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
Ok "LISTO: en el mapa hay un boton nuevo, Otro dia, con calendario y flechas. Cerra y abri la app (o recarga la pagina del mapa)."
Write-Host ""
