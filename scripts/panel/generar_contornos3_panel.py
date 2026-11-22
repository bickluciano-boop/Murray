# Genera scripts/aplicar-contornos3-panel.ps1: la ruta GET /api/rvi/buildings consulta VARIOS servidores de OpenStreetMap (Overpass) A LA VEZ y se queda con el primero que devuelve edificios.
# Luciano (22/11/2026): el panel dijo "overpass-api.de 521; overpass.private.coffee tardo demasiado; overpass.kumi.systems tardo demasiado": servidor principal caido y los otros lentos; en fila (3 x 14 s) se agotaba el tiempo.
# Requiere aplicar-contornos-panel.ps1 y aplicar-contornos2-panel.ps1. No toca el secreto RVI_TOKEN.
import re, ast
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-raiz-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')


def psq(s):
    return "'" + s.replace("'", "''") + "'"


# El codigo como queda instalado (contornos + contornos2): se lee del generador original evaluando el literal para respetar los escapes.
g1 = open(R + 'panel/generar_contornos_panel.py', encoding='utf-8').read()
a = g1.index("N_FN = '''") + len("N_FN = '''"); b = g1.index("''' + A_FN")
codigo = ast.literal_eval("'''" + g1[a:b] + "'''")
g2 = open(R + 'panel/generar_contornos2_panel.py', encoding='utf-8').read()
ns = {}
exec(g2[g2.index("A1 = "):g2.index("filas = [")], ns)
assert codigo.count(ns['A1']) == 1 and codigo.count(ns['A2']) == 1
codigo = codigo.replace(ns['A1'], ns['N1']).replace(ns['A2'], ns['N2'])

A_SERV = codigo[codigo.index('const RVI_SERVIDORES = ['):codigo.index('\n', codigo.index('const RVI_SERVIDORES = ['))]
N_SERV = 'const RVI_SERVIDORES = ["https://overpass-api.de/api/interpreter", "https://lz4.overpass-api.de/api/interpreter", "https://z.overpass-api.de/api/interpreter", "https://overpass.private.coffee/api/interpreter", "https://overpass.kumi.systems/api/interpreter"];'
i0 = codigo.index('  const motivos: string[] = [];\n  for (const servidor of RVI_SERVIDORES) {')
marca = '  return rviRespuesta({ error: "overpass_busy", detail: motivos.join("; ") }, 503);'
i1 = codigo.index(marca) + len(marca)
A_BUC = codigo[i0:i1]
N_BUC = '''  // Se consulta a TODOS los servidores a la vez y gana el primero que devuelve edificios (los publicos se caen o se saturan por turnos). Una respuesta vacia o con aviso cuenta como fallo.
  const pedirA = async (servidor: string) => {
    const host = servidor.split("/")[2];
    const ctl = new AbortController();
    const reloj = setTimeout(() => ctl.abort(), 22000);
    try {
      const r = await fetch(servidor, { method: "POST", headers: { "content-type": "application/x-www-form-urlencoded", "user-agent": "OjoGuardPanel/1.0 (contornos de edificios, uso interno)" }, body: "data=" + encodeURIComponent(consulta), signal: ctl.signal });
      if (!r.ok) throw new Error(host + " " + r.status);
      const datos = await r.json<{ remark?: string; elements?: Array<{ id?: number; tags?: Record<string, string>; geometry?: Array<{ lat: number; lon: number }> }> }>();
      const permitidos = ["building", "building:levels", "height", "name", "addr:housename"];
      const elements = (datos.elements ?? []).filter((e) => e.geometry && e.geometry.length >= 3).map((e) => ({
        id: e.id,
        tags: Object.fromEntries(Object.entries(e.tags ?? {}).filter(([k]) => permitidos.includes(k))),
        geometry: e.geometry,
      }));
      if (datos.remark || elements.length === 0) throw new Error(host + (datos.remark ? " con aviso: " + String(datos.remark).slice(0, 80) : " sin edificios"));
      return elements;
    } catch (e) {
      throw new Error(e instanceof Error && e.name === "AbortError" ? host + " tardo demasiado" : e instanceof Error && e.message.startsWith(host) ? e.message : host + " no respondio");
    } finally {
      clearTimeout(reloj);
    }
  };
  const motivos: string[] = [];
  const ganador = await new Promise<Array<unknown> | null>((resolver) => {
    let pendientes = RVI_SERVIDORES.length;
    for (const servidor of RVI_SERVIDORES) {
      pedirA(servidor).then(
        (elements) => resolver(elements),
        (e) => { motivos.push(e instanceof Error ? e.message : String(e)); pendientes -= 1; if (pendientes === 0) resolver(null); },
      );
    }
  });
  if (ganador) {
    const cuerpo = { elements: ganador };
    await cache.put(llave, new Response(JSON.stringify(cuerpo), { headers: { "content-type": "application/json", "cache-control": "public, max-age=2592000" } }));
    return rviRespuesta(cuerpo, 200, { "x-rvi-cache": "miss" });
  }
  return rviRespuesta({ error: "overpass_busy", detail: motivos.join("; ") }, 503);'''
filas = [('src\\index.ts', 'contornos: mas servidores de respaldo', A_SERV, N_SERV),
         ('src\\index.ts', 'contornos: consulta a todos los servidores a la vez', A_BUC, N_BUC)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-contornos3-panel.ps1 - Ojo Guard MS (panel): la ruta de contornos de edificios (GET /api/rvi/buildings) consulta VARIOS servidores de OpenStreetMap a la vez y usa el primero que responde bien.
# El servidor principal estaba caido (521) y los otros tardaban; en fila se agotaba el tiempo. Ahora son 5 servidores en paralelo con 22 s cada uno; lo conseguido sigue guardandose 30 dias.
# Requiere aplicar-contornos-panel.ps1 y aplicar-contornos2-panel.ps1. No toca el codigo RVI_TOKEN. Cambia SOLO src\\index.ts (respaldo .bak-contornos3). Va en la carpeta del PANEL. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'rvi/contornos2') -eq 0) { Mal "Falta aplicar primero aplicar-contornos-panel.ps1 y aplicar-contornos2-panel.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'const pedirA = async') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-raiz', '.bak-contornos3')
cola = re.sub(r'Ok "LISTO: el panel se abre en.*"\n', 'Ok "LISTO: el panel ahora prueba 5 servidores de OpenStreetMap a la vez. Abri el visor y toca Buscar el edificio de nuevo."\n', cola)
assert 'bak-raiz' not in cola and 'LISTO: el panel ahora prueba' in cola
total = cabeza + tpl[i:j] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕‹›±']
assert not bad, set(bad)
open(R + 'aplicar-contornos3-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
# codigo final para probar en node
final = codigo.replace(A_SERV, N_SERV).replace(A_BUC, N_BUC)
open('/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/wk/worker3.ts', 'w', encoding='utf-8').write('type Env = Record<string, unknown>;\n' + final + '\nexport { rviContornos };\n')
print('ok', len(total))
