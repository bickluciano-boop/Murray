# Genera scripts/aplicar-contornos2-panel.ps1: corrige la ruta GET /api/rvi/buildings (aplicar-contornos-panel.ps1).
# Luciano (22/11/2026): el visor v14 hablo con el panel pero dijo "No encontre edificios cerca de ese punto" en una zona densa de Buenos Aires.
# Causa probable: Overpass sobrecargado contesta HTTP 200 con la lista vacia y un "remark" (query timed out); el panel lo daba por bueno y lo guardaba 30 dias en la cache.
# Arreglo: una respuesta vacia o con aviso NO se acepta ni se guarda (se prueba el servidor siguiente) y la cache cambia de llave (contornos2) para descartar lo guardado. No toca el secreto RVI_TOKEN.
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-raiz-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')


def psq(s):
    return "'" + s.replace("'", "''") + "'"


A1 = 'new Request("https://cache.ojoguard.app/rvi/contornos?lat="'
N1 = 'new Request("https://cache.ojoguard.app/rvi/contornos2?lat="'
A2 = '''      const cuerpo = { elements };
      await cache.put(llave, new Response(JSON.stringify(cuerpo), { headers: { "content-type": "application/json", "cache-control": "public, max-age=2592000" } }));
      return rviRespuesta(cuerpo, 200, { "x-rvi-cache": "miss" });'''
N2 = '''      // Overpass sobrecargado contesta 200 con la lista vacia y un "remark": eso NO es una respuesta valida y no se guarda.
      const aviso = (datos as unknown as { remark?: string }).remark;
      if (aviso || elements.length === 0) { motivos.push(host + (aviso ? " con aviso: " + String(aviso).slice(0, 80) : " sin edificios")); continue; }
      const cuerpo = { elements };
      await cache.put(llave, new Response(JSON.stringify(cuerpo), { headers: { "content-type": "application/json", "cache-control": "public, max-age=2592000" } }));
      return rviRespuesta(cuerpo, 200, { "x-rvi-cache": "miss" });'''
filas = [('src\\index.ts', 'contornos: nueva llave de cache (descarta lo guardado)', A1, N1),
         ('src\\index.ts', 'contornos: no acepta ni guarda respuestas vacias o con aviso', A2, N2)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-contornos2-panel.ps1 - Ojo Guard MS (panel): corrige la ruta de contornos de edificios (GET /api/rvi/buildings).
# Overpass sobrecargado contesta "bien" pero vacio; el panel lo guardaba 30 dias. Ahora una respuesta vacia o con aviso no se acepta ni se guarda, y la cache empieza de cero.
# No toca el codigo RVI_TOKEN (el del visor sigue valiendo). Cambia SOLO src\\index.ts (respaldo .bak-contornos2). Va en la carpeta del PANEL. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'async function rviContornos') -eq 0) { Mal "Falta aplicar primero aplicar-contornos-panel.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'rvi/contornos2') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-raiz', '.bak-contornos2')
cola = re.sub(r'Ok "LISTO: el panel se abre en.*"\n', 'Ok "LISTO: el panel ya no guarda respuestas vacias de OpenStreetMap. Abri el visor y toca Cargar y mostrar de nuevo."\n', cola)
assert 'bak-raiz' not in cola and 'LISTO: el panel ya no guarda' in cola
total = cabeza + tpl[i:j] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕‹›±']
assert not bad, set(bad)
open(R + 'aplicar-contornos2-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
# --- prueba: se arma el codigo como queda en el panel (aplicando las dos filas al codigo del instalador anterior) y se corre en node
g1 = open(R + 'panel/generar_contornos_panel.py', encoding='utf-8').read()
a = g1.index("N_FN = '''") + len("N_FN = '''"); b = g1.index("''' + A_FN")
codigo = g1[a:b].replace('\\\\"', '\\"')
codigo = codigo.replace('\\"', '"') if False else codigo
assert codigo.count(A1) == 1 and codigo.count(A2) == 1, (codigo.count(A1), codigo.count(A2))
codigo = codigo.replace(A1, N1).replace(A2, N2)
open('/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/wk/worker2.ts', 'w', encoding='utf-8').write('type Env = Record<string, unknown>;\n' + codigo + '\nexport { rviContornos };\n')
print('ok', len(total))
