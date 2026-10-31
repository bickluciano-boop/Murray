# Genera scripts/aplicar-historial-familia-panel.ps1: el recorrido del dia / 7 dias / "Un dia" tambien para las personas de la familia (hijos), con la regla de roles:
# el titular y los adultos ven a los menores; el titular ve tambien a los adultos; nadie ve al titular; con la ubicacion pausada no se ve nada.
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"

# --- servidor (src\index.ts) ---
FUNCION = '''// Historial de ubicaciones de una persona de la familia (mismo formato que location-history). Solo lo ve quien puede darle ordenes a esa persona
// (el titular y los adultos ven a los menores; el titular ve tambien a los adultos; nadie ve al titular) y no si tiene la ubicacion pausada.
// Parametros: personId y limit (hasta 200) o from / to (ISO, hasta 2 dias, hasta 1500 puntos).
async function familyLocationHistory(request: Request, env: Env, url: URL) {
  const sessionInfo = await readSessionInfo(request, env.SESSION_SECRET);
  if (!sessionInfo) return json({ error: "unauthorized" }, 401);
  if (sessionInfo.method === "emergency") return json({ error: "not_allowed_in_emergency" }, 403);
  const personId = url.searchParams.get("personId") ?? "";
  const persona = (await familyPeopleFor(env, sessionInfo.email)).find((p) => p.id === personId);
  if (!persona || persona.canCommand !== true) return json({ error: "not_found" }, 404);
  if (persona.paused) return json({ points: [], paused: true });
  const miembro = await env.DB.prepare("SELECT member_email AS email FROM family_members WHERE id=? AND status='activo'").bind(personId).first<{ email: string | null }>();
  if (!miembro?.email) return json({ error: "not_found" }, 404);
  const equipo = await env.DB.prepare(
    "SELECT id FROM devices WHERE owner_email=? AND approval_status='approved' ORDER BY CASE WHEN device_role='primary' THEN 0 ELSE 1 END, COALESCE(last_location_at,'') DESC LIMIT 1",
  ).bind(miembro.email).first<{ id: string }>();
  if (!equipo) return json({ points: [] });
  const limitParamRaw = url.searchParams.get("limit");
  const limitParam = limitParamRaw === null ? NaN : Number(limitParamRaw);
  const desdeTramo = Date.parse(url.searchParams.get("from") ?? ""), hastaTramo = Date.parse(url.searchParams.get("to") ?? "");
  if (Number.isFinite(desdeTramo) && Number.isFinite(hastaTramo) && hastaTramo > desdeTramo && hastaTramo - desdeTramo <= 2 * 86_400_000) {
    const tope = Number.isFinite(limitParam) ? Math.max(1, Math.min(1500, Math.trunc(limitParam))) : 1500;
    const tramo = await env.DB.prepare(
      "SELECT latitude,longitude,accuracy,altitude,heading,address,captured_at AS capturedAt FROM location_history WHERE device_id=? AND captured_at>=? AND captured_at<? ORDER BY captured_at ASC LIMIT ?",
    ).bind(equipo.id, new Date(desdeTramo).toISOString(), new Date(hastaTramo).toISOString(), tope).all();
    return json({ points: tramo.results });
  }
  const limit = Number.isFinite(limitParam) ? Math.max(1, Math.min(200, Math.trunc(limitParam))) : 50;
  const result = await env.DB.prepare(
    "SELECT latitude,longitude,accuracy,altitude,heading,address,captured_at AS capturedAt FROM location_history WHERE device_id=? ORDER BY captured_at DESC LIMIT ?",
  ).bind(equipo.id, limit).all();
  return json({ points: result.results });
}

'''
s1a = 'async function deviceLocationHistory(request: Request, env: Env, url: URL) {\n'
s1b = FUNCION + s1a
s2a = '      if (route === "GET /api/remote/location-history") return deviceLocationHistory(request, env, url);\n'
s2b = s2a + '      if (route === "GET /api/remote/family/location-history") return familyLocationHistory(request, env, url);\n'

# --- mapa (src\panel-mapa.txt) ---
m1a = '      conRecorrido: false,\n      pausado: Boolean(p.paused),\n'
m1b = '      // Con el recorrido: quien puede darle ordenes a esa persona (ver familyLocationHistory) y mientras no tenga la ubicacion pausada.\n      conRecorrido: Boolean(p.canCommand) && !p.paused,\n      pausado: Boolean(p.paused),\n'
m2a = 'async function cargarRecorrido(equipo) {\n'
m2b = ('// De donde se pide el historial: tus telefonos o una persona de tu familia.\n'
       'const rutaHistorial = (equipo) => (esPersona(equipo.id)\n'
       '  ? `/api/remote/family/location-history?personId=${encodeURIComponent(equipo.id.slice(8))}`\n'
       '  : `/api/remote/location-history?deviceId=${encodeURIComponent(equipo.id)}`);\n\n') + m2a
m3a = '  const datos = await pedir(`/api/remote/location-history?deviceId=${encodeURIComponent(equipo.id)}&limit=${CONFIG.puntosRecorrido}`);\n'
m3b = '  const datos = await pedir(`${rutaHistorial(equipo)}&limit=${CONFIG.puntosRecorrido}`);\n'
m4a = '  const datos = await pedir(`/api/remote/location-history?deviceId=${encodeURIComponent(equipo.id)}&from=${encodeURIComponent(desde.toISOString())}&to=${encodeURIComponent(hasta.toISOString())}&limit=1500`);\n'
m4b = '  const datos = await pedir(`${rutaHistorial(equipo)}&from=${encodeURIComponent(desde.toISOString())}&to=${encodeURIComponent(hasta.toISOString())}&limit=1500`);\n'
h1a = '<script type="module" src="/mapa-v1.js?v=9"></script>'
h1b = '<script type="module" src="/mapa-v1.js?v=10"></script>'

filas = [
    ('src\\index.ts', 'servidor: historial de una persona de la familia', s1a, s1b),
    ('src\\index.ts', 'servidor: ruta del historial de la familia', s2a, s2b),
    ('src\\panel-mapa.txt', 'mapa: las personas que puedes ver tienen recorrido', m1a, m1b),
    ('src\\panel-mapa.txt', 'mapa: de donde se pide el historial', m2a, m2b),
    ('src\\panel-mapa.txt', 'mapa: recorrido (En vivo, Hoy, 7 dias)', m3a, m3b),
    ('src\\panel-mapa.txt', 'mapa: recorrido de Un dia', m4a, m4b),
    ('src\\panel-index.html', 'recargar el mapa nuevo (v=10)', h1a, h1b),
]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-historial-familia-panel.ps1 - Ojo Guard MS: el recorrido (En vivo, Hoy, 7 dias y Un dia, con las paradas) tambien para las personas de la familia.
# Pedido de Luciano (31/10/2026): los padres (los dos mayores de la cuenta principal) tienen que poder ver el recorrido de sus hijos, igual que el de sus propios telefonos.
# Regla: la de siempre para dar ordenes. El titular y los adultos ven a los menores; el titular ve tambien a los adultos; nadie ve al titular; con la ubicacion pausada no se ve nada.
# Cambia src\\index.ts (ruta nueva GET /api/remote/family/location-history), src\\panel-mapa.txt y src\\panel-index.html (v=10). Respaldo .bak-histfamilia. Va en la carpeta del PANEL. Sin build. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
foreach ($f in @("src\\index.ts", "src\\panel-mapa.txt", "src\\panel-index.html")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'familyLocationHistory') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-index.html")).texto '/mapa-v1.js?v=9') -ne 1) { Mal "El mapa no esta en v=9 (falta aplicar primero aplicar-mapa-otro-dia-v5-panel.ps1). No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-histfamilia')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: el recorrido tambien para las personas de la familia que podes ver. Cerra y abri la app (o recarga la pagina del mapa)."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›']
assert not bad, set(bad)
open(R + 'aplicar-historial-familia-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
