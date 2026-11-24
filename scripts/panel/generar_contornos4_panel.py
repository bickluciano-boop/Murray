# Genera scripts/aplicar-contornos4-panel.ps1: la ruta GET /api/rvi/buildings suma Overture Maps (PMTiles por rango de bytes) como un servidor mas de la carrera con los 5 de Overpass.
# Luciano (24/11/2026): los 5 servidores de Overpass volvieron a caerse (521/502/timeout) para la torre de su zona. Overture cubre Buenos Aires (3 de cada 4 edificios del centro vienen de Google/Microsoft, el resto de OSM) y trae altura/pisos en parte.
# Requiere aplicar-contornos-panel / 2 / 3. No toca el secreto RVI_TOKEN. Cambia solo src\index.ts (respaldo .bak-contornos4).
import re, runpy
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-raiz-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')


def psq(s):
    return "'" + s.replace("'", "''") + "'"


ns = runpy.run_path(R + 'panel/generar_contornos3_panel.py')  # codigo ya instalado tras contornos 1, 2 y 3
instalado = ns['final']
lector = open(R + 'panel/overture_lector.ts.txt', encoding='utf-8').read()

A_FN = 'async function rviContornos(request: Request, env: Env, url: URL) {\n'
N_FN = lector + '\n' + A_FN
A_RET = '      return elements;\n'
N_RET = '      return { elements: elements.map((e) => ({ ...e, src: "OpenStreetMap" })), fuente: "OpenStreetMap (Overpass)" };\n'
i0 = instalado.index('  const motivos: string[] = [];\n  const ganador = await new Promise')
marca = '  return rviRespuesta({ error: "overpass_busy", detail: motivos.join("; ") }, 503);'
i1 = instalado.index(marca) + len(marca)
A_BUC = instalado[i0:i1]
N_BUC = '''  // Los 5 servidores de Overpass Y Overture Maps compiten a la vez: gana el primero que devuelve edificios. Overture no depende de Overpass y trae tambien edificios que OpenStreetMap no tiene.
  const motivos: string[] = [];
  const ganador = await new Promise<{ elements: Array<unknown>; fuente: string } | null>((resolver) => {
    let pendientes = RVI_SERVIDORES.length + 1;
    const falla = (e: unknown) => { motivos.push(e instanceof Error ? e.message : String(e)); pendientes -= 1; if (pendientes === 0) resolver(null); };
    for (const servidor of RVI_SERVIDORES) pedirA(servidor).then((r) => resolver(r), falla);
    rviOverture(la, lo).then((r) => resolver(r), falla);
  });
  if (ganador) {
    const cuerpo = { elements: ganador.elements, fuente: ganador.fuente };
    await cache.put(llave, new Response(JSON.stringify(cuerpo), { headers: { "content-type": "application/json", "cache-control": "public, max-age=2592000" } }));
    return rviRespuesta(cuerpo, 200, { "x-rvi-cache": "miss" });
  }
  return rviRespuesta({ error: "overpass_busy", detail: motivos.join("; ") }, 503);'''
for a in (A_FN, A_RET):
    assert instalado.count(a) == 1, a
filas = [('src\\index.ts', 'contornos: lector de Overture Maps', A_FN, N_FN),
         ('src\\index.ts', 'contornos: Overpass devuelve la fuente', A_RET, N_RET),
         ('src\\index.ts', 'contornos: Overture compite con Overpass', A_BUC, N_BUC)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-contornos4-panel.ps1 - Ojo Guard MS (panel): la ruta de contornos (GET /api/rvi/buildings) suma Overture Maps como una fuente mas, en carrera con los 5 servidores de OpenStreetMap.
# Overture publica los edificios (OpenStreetMap + Google Open Buildings + Microsoft) como un archivo PMTiles; el panel lee solo la tesela que necesita (rango de bytes, nunca el archivo entero de ~180 GB).
# La respuesta ahora trae "fuente" y cada edificio "src" (de quien salio el contorno). Los de Google/Microsoft son estimados por computadora y pueden venir corridos.
# Requiere aplicar-contornos-panel / 2 / 3. No toca el codigo RVI_TOKEN. Cambia SOLO src\\index.ts (respaldo .bak-contornos4). Va en la carpeta del PANEL. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'const pedirA = async') -eq 0) { Mal "Falta aplicar primero aplicar-contornos-panel, contornos2 y contornos3."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'async function rviOverture') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-raiz', '.bak-contornos4')
cola = re.sub(r'Ok "LISTO: el panel se abre en.*"\n', 'Ok "LISTO: el panel ahora tambien lee los edificios de Overture Maps. Abri el visor v21 y toca Buscar el edificio de nuevo."\n', cola)
assert 'bak-raiz' not in cola and 'LISTO: el panel ahora tambien' in cola
total = cabeza + tpl[i:j] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕‹›±']
assert not bad, set(bad)
open(R + 'aplicar-contornos4-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
final = instalado.replace(A_FN, N_FN).replace(A_RET, N_RET).replace(A_BUC, N_BUC)
open('/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/wk/worker4.ts', 'w', encoding='utf-8').write('type Env = Record<string, unknown>;\n' + final + '\nexport { rviContornos };\n')
print('ok', len(total))
