# Genera scripts/aplicar-mapa-otro-dia-panel.ps1: en el mapa, un cuarto boton "Otro dia" con calendario y flechas para ver el recorrido y TODAS las paradas de un dia puntual.
# Pedido de las mamas (31/10/2026): "si quiero buscar un dia en especial, ¿se podria? Porque la semana entera ves rayas por todos lados".
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"

# --- servidor (src\index.ts): el historial acepta un tramo (from / to) ---
s1a = '''  const result = await env.DB.prepare(
    "SELECT latitude,longitude,accuracy,altitude,heading,address,captured_at AS capturedAt FROM location_history WHERE device_id=? ORDER BY captured_at DESC LIMIT ?",
  ).bind(deviceId, limit).all();
  return json({ points: result.results });
'''
s1b = '''  // "Otro dia" del mapa: los puntos de un tramo (from / to, en ISO) del mas viejo al mas nuevo, hasta 1500. El tramo no puede pasar de dos dias.
  const desdeTramo = Date.parse(url.searchParams.get("from") ?? ""), hastaTramo = Date.parse(url.searchParams.get("to") ?? "");
  if (Number.isFinite(desdeTramo) && Number.isFinite(hastaTramo) && hastaTramo > desdeTramo && hastaTramo - desdeTramo <= 2 * 86_400_000) {
    const tope = Number.isFinite(limitParam) ? Math.max(1, Math.min(1500, Math.trunc(limitParam))) : 1500;
    const tramo = await env.DB.prepare(
      "SELECT latitude,longitude,accuracy,altitude,heading,address,captured_at AS capturedAt FROM location_history WHERE device_id=? AND captured_at>=? AND captured_at<? ORDER BY captured_at ASC LIMIT ?",
    ).bind(deviceId, new Date(desdeTramo).toISOString(), new Date(hastaTramo).toISOString(), tope).all();
    return json({ points: tramo.results });
  }
''' + s1a

# --- mapa (src\panel-mapa.txt) ---
CSS = ('#og-mapa .ogm-dia{position:absolute;z-index:3;top:72px;left:18px;display:flex;align-items:center;gap:4px;padding:5px;background:var(--ogm-panel);border:1px solid var(--ogm-linea);border-radius:14px;box-shadow:var(--ogm-sombra)}'
       '#og-mapa .ogm-dia.hidden{display:none}'
       '#og-mapa .ogm-dia button{width:38px;height:38px;border-radius:10px;font-size:1.3rem;color:var(--ogm-oro-vivo)}'
       '#og-mapa .ogm-dia input{height:38px;padding:0 8px;border-radius:10px;border:1px solid var(--ogm-linea);background:transparent;color:var(--ogm-texto);font:inherit;font-size:.9rem;color-scheme:dark light}'
       '#og-mapa .ogm-dia-txt{font-size:.78rem;color:var(--ogm-suave);padding:0 6px;white-space:nowrap}'
       '@media (max-width:899px){#og-mapa .ogm-dia{top:calc(max(12px, env(safe-area-inset-top)) + 56px);left:12px}#og-mapa .ogm-seg button{padding:8px 9px;font-size:.8rem}}')
m1a = '        <button type="button" data-rango="semana">7 días</button>\n      </div>\n'
m1b = ('        <button type="button" data-rango="semana">7 días</button>\n'
       '        <button type="button" data-rango="dia">Otro día</button>\n'
       '      </div>\n'
       '      <style id="ogm-dia-css">' + CSS + '</style>\n'
       '      <div class="ogm-dia hidden" data-ogm="dia-barra">\n'
       '        <button type="button" data-accion="dia-ant" aria-label="Día anterior">‹</button>\n'
       '        <input type="date" data-ogm="dia-fecha" aria-label="Elegir el día">\n'
       '        <button type="button" data-accion="dia-sig" aria-label="Día siguiente">›</button>\n'
       '        <span class="ogm-dia-txt" data-ogm="dia-txt"></span>\n'
       '      </div>\n')
m2a = '  raiz.addEventListener("click", (evento) => {\n    // Si se mantuvo el dedo sobre un botón'
m2b = ('  raiz.addEventListener("change", (evento) => {\n'
       '    const campo = evento.target.closest?.(\'[data-ogm="dia-fecha"]\');\n'
       '    if (campo && /^\\d{4}-\\d{2}-\\d{2}$/.test(campo.value) && campo.value <= hoyTexto()) cambiarDia(campo.value);\n'
       '  });\n') + m2a
m3a = '    if (boton.dataset.rango) return elegirRango(boton.dataset.rango);\n'
m3b = (m3a + '    if (boton.dataset.accion === "dia-ant") return moverDia(-1);\n'
             '    if (boton.dataset.accion === "dia-sig") return moverDia(1);\n')
m4a = 'async function enviarOrden(equipo, tipo) {\n'
m4b = '''// Todos los puntos de UN dia (hora de Argentina) para "Otro dia": el servidor devuelve hasta 1500 de ese dia.
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

''' + m4a
m5a = '''function elegirRango(rango) {
  estado.rango = rango;
  document.querySelectorAll("#og-mapa [data-rango]").forEach((b) => b.classList.toggle("on", b.dataset.rango === rango));
  dibujar();
'''
m5b = '''// "Otro dia": el recorrido y todas las paradas de un dia puntual (con la semana entera el mapa se llena de rayas).
const hoyTexto = () => new Intl.DateTimeFormat("en-CA", { timeZone: CONFIG.zona, year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date());

/** Los puntos que se muestran ahora: los del dia elegido, o los del rango (En vivo / Hoy / 7 dias). */
function puntosDelRango() {
  return estado.rango === "dia" ? (estado.recorridoDia || []) : filtrarPorRango(estado.recorrido, estado.rango);
}

function textoDia(puntos, lista) {
  const el = document.querySelector('#og-mapa [data-ogm="dia-txt"]');
  if (!el) return;
  if (estado.cargandoDia) { el.textContent = "Cargando…"; return; }
  if (!puntos.length) { el.textContent = "Sin recorrido ese día"; return; }
  const km = kilometros(puntos);
  el.textContent = `${lista.length} ${lista.length === 1 ? "parada" : "paradas"} · ${km >= 0.05 ? km.toFixed(1).replace(".", ",") : "0"} km`;
}

async function cambiarDia(dia) {
  estado.dia = dia;
  const campo = document.querySelector('#og-mapa [data-ogm="dia-fecha"]');
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
  document.querySelector('#og-mapa [data-ogm="dia-barra"]')?.classList.toggle("hidden", rango !== "dia");
  if (rango === "dia") return cambiarDia(estado.dia || hoyTexto());
  dibujar();
'''
m6a = '    const puntos = elegido ? filtrarPorRango(estado.recorrido, estado.rango) : [];\n    const trazo = elegido && elegido.lat !== null && puntos.length ? [...puntos, { lat: elegido.lat, lng: elegido.lng }] : puntos;\n'
m6b = '    const puntos = elegido ? puntosDelRango() : [];\n    const trazo = elegido && elegido.lat !== null && puntos.length && estado.rango !== "dia" ? [...puntos, { lat: elegido.lat, lng: elegido.lng }] : puntos;\n'
m7a = '  const lista = paradas(filtrarPorRango(estado.recorrido, estado.rango)).slice(-3).reverse();\n'
m7b = ('  // Un dia puntual muestra TODAS sus paradas, en orden; los otros rangos, las tres ultimas.\n'
       '  const lista = estado.rango === "dia" ? paradas(puntosDelRango()) : paradas(puntosDelRango()).slice(-3).reverse();\n'
       '  if (estado.rango === "dia") textoDia(puntosDelRango(), lista);\n')
m8a = '    estado.recorrido = [];\n    // En la app la tarjeta empieza en una sola fila'
m8b = '    estado.recorrido = [];\n    estado.recorridoDia = [];\n    if (estado.rango === "dia") void cambiarDia(estado.dia || hoyTexto());\n    // En la app la tarjeta empieza en una sola fila'
h1a = '<script type="module" src="/mapa-v1.js?v=4"></script>'
h1b = '<script type="module" src="/mapa-v1.js?v=5"></script>'

filas = [
    ('src\\index.ts', 'servidor: el historial acepta un tramo (from / to)', s1a, s1b),
    ('src\\panel-mapa.txt', 'mapa: boton Otro dia y barra del dia', m1a, m1b),
    ('src\\panel-mapa.txt', 'mapa: calendario (cambio de fecha)', m2a, m2b),
    ('src\\panel-mapa.txt', 'mapa: flechas del dia', m3a, m3b),
    ('src\\panel-mapa.txt', 'mapa: pedir los puntos de un dia', m4a, m4b),
    ('src\\panel-mapa.txt', 'mapa: elegir el rango Otro dia', m5a, m5b),
    ('src\\panel-mapa.txt', 'mapa: usar los puntos del dia en el trazo', m6a, m6b),
    ('src\\panel-mapa.txt', 'mapa: todas las paradas del dia', m7a, m7b),
    ('src\\panel-mapa.txt', 'mapa: al cambiar de equipo recarga el dia', m8a, m8b),
    ('src\\panel-index.html', 'recargar el mapa nuevo (v=5)', h1a, h1b),
]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-mapa-otro-dia-panel.ps1 - Ojo Guard MS: en el mapa, un cuarto boton "Otro dia" (calendario y flechas) para ver el recorrido y TODAS las paradas de un dia puntual.
# Pedido de las mamas (31/10/2026): "si quiero buscar un dia en especial, se podria? Porque la semana entera ves rayas por todos lados". Les gusto mucho ver las paradas con cuanto tiempo estuvo.
# Cambia src\\index.ts (el historial acepta from / to), src\\panel-mapa.txt y src\\panel-index.html (sube a v=5 el numero del script; respaldo .bak-otrodia). Va en la carpeta del PANEL (la que tiene wrangler.toml). No necesita build. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
foreach ($f in @("src\\index.ts", "src\\panel-mapa.txt", "src\\panel-index.html")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\\panel-mapa.txt")).texto 'cargarRecorridoDia') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-index.html")).texto '/mapa-v1.js?v=4') -ne 1) { Mal "El mapa no esta en v=4 (falta aplicar primero aplicar-renombrar-equipo-panel.ps1). No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-otrodia')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: en el mapa hay un boton nuevo, Otro dia, con calendario y flechas. Cerra y abri la app (o recarga la pagina del mapa)."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›']
assert not bad, set(bad)
open(R + 'aplicar-mapa-otro-dia-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
