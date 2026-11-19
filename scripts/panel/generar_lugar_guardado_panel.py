# Genera scripts/aplicar-lugar-guardado-panel.ps1 (panel, pestana Dispositivos: src\panel-app.txt). Solo texto en la tarjeta del equipo.
# Luciano (19/11/2026): el 18/11 el Android estaba en la pileta de su casa; el panel mostro la direccion de la calle mas cercana ("Cervino") y no decia que estaba EN CASA; corrio al supermercado.
# Los 6 ultimos puntos del telefono estaban dentro del lugar guardado "Casa" (radio 200 m, a 30-91 m del centro). Ahora, si la ultima ubicacion cae dentro de un lugar guardado, la tarjeta dice "En Casa · <direccion>".
# Los lugares se leen de /api/remote/family (los mismos del mapa), una vez cada 5 minutos. Sin SMS ni mails. No cambia nada del telefono.
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
F = 'src\\panel-app.txt'
E1_A = 'const gridAddress = withApprox(device.lastLocation?.address)'
E1_B = 'const gridAddress = lugarYDireccion(device.lastLocation, withApprox(device.lastLocation?.address))'
E2_A = 'formatBuenosAiresDate(device.lastLocationAt) : "recibida"}${location.address ? ` · ${withApprox(location.address)}` : ""}.`;'
E2_B = 'formatBuenosAiresDate(device.lastLocationAt) : "recibida"}${lugarYDireccion(location, location.address ? withApprox(location.address) : "") ? ` · ${lugarYDireccion(location, location.address ? withApprox(location.address) : "")}` : ""}.`;'
E3_A = 'function nearbySummary(entries) {'
E3_B = '''// Lugares guardados (Casa, Trabajo...): si la ultima ubicacion de un equipo cae dentro de uno, la tarjeta dice "En Casa" y no solo la calle mas cercana
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

''' + E3_A
filas = [(F, 'lugar guardado: la grilla de la tarjeta usa el lugar', E1_A, E1_B),
         (F, 'lugar guardado: el resumen de ultima ubicacion usa el lugar', E2_A, E2_B),
         (F, 'lugar guardado: las funciones que lo calculan', E3_A, E3_B)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
i0 = tpl.index('$ErrorActionPreference'); j0 = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-lugarguardado')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
MENSAJE = 'LISTO: si la ultima ubicacion de un equipo cae dentro de un lugar guardado, la tarjeta dice "En Casa" y la calle. Solo texto.'
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "%s"\n' % MENSAJE, cola)
assert MENSAJE in cola
cabeza = '''# aplicar-lugar-guardado-panel.ps1 - Ojo Guard MS (panel, pestana Dispositivos): si la ultima ubicacion de un equipo cae dentro de un lugar guardado (Casa, Trabajo...), la tarjeta dice "En Casa · <calle>" y no solo la calle mas cercana.
# Luciano (19/11/2026): el 18/11 el panel mostro "Cervino" con el telefono en la pileta de su casa y salio corriendo al supermercado. Los lugares se leen de /api/remote/family (los mismos del mapa), una vez cada 5 minutos.
# SOLO texto en el panel (sin SMS ni mails). Cambia src\\panel-app.txt (respaldo .bak-lugarguardado). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
'''
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\panel-app.txt"))) { Mal "No encuentro src\\panel-app.txt en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-app.txt")).texto 'lugarYDireccion') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
total = cabeza + tpl[i0:j0] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕‹›']
assert not bad, set(bad)
open(R + 'aplicar-lugar-guardado-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
open('/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/filas_lugar.json', 'w', encoding='utf-8').write(__import__('json').dumps(filas))
print('ok', len(total))
