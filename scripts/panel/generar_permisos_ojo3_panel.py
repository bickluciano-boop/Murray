# Genera scripts/aplicar-permisos-ojo3-panel.ps1: con un menor, el adulto puede cortar lo SUYO (que el menor lo vea y que le suene su SOS); queda fijo ver al menor y recibir su SOS.
import re
R = '/home/user/Murray/scripts/'
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
A1 = '      locked: p.role === "menor" || rows.results.some((r) => r.memberEmail === viewer && r.role === "menor"),\n'
B1 = ('      // Siendo menor no se corta nada. Si la otra persona es un menor, quedan fijas solo las dos llaves que lo cuidan (verlo y recibir su SOS);\n'
      '      // las otras dos (que el menor te vea y que le suene tu SOS) son decision del adulto.\n'
      '      locked: rows.results.some((r) => r.memberEmail === viewer && r.role === "menor"),\n'
      '      fijas: p.role === "menor" ? ["loVes", "recibisSuSos"] : [],\n')
A2 = '  if (soyMenor || persona.role === "menor") return json({ error: "minor_locked" }, 403);\n'
B2 = '  if (soyMenor || (persona.role === "menor" && (col === "loc_view" || col === "sos_recv"))) return json({ error: "minor_locked" }, 403);\n'
pares = [A1, A2]; nuevos = [B1, B2]
nombres = ['permisos3: llaves fijas con un menor', 'permisos3: el adulto puede cortar lo suyo con un menor']
filas = [('src\\index.ts', n, a, b) for n, a, b in zip(nombres, pares, nuevos)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-permisos-ojo3-panel.ps1 - Ojo Guard MS: con un menor, el adulto puede cortar lo SUYO.
# Luciano (05/11/2026, iPhone): "iPhone menor te ve a vos... no me tiene que ver; no anda ninguna llave". Con un menor estaban bloqueadas las 4 llaves. Ahora el adulto puede apagar "Te ve" (que el menor lo vea) y "Recibe tu SOS" (que a el le suene tu SOS).
# Siguen fijas "Lo ves" y "Recibis su SOS" (verlo y recibir su SOS: es lo que cuida al menor), y un menor no puede cortar nada. Requiere aplicar-permisos-ojo-panel.ps1. Cambia SOLO src\\index.ts (respaldo .bak-permisos3). Va en la carpeta del PANEL. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'async function nativeFamilyPerm') -eq 0) { Mal "Falta aplicar primero aplicar-permisos-ojo-panel.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'fijas: p.role') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-permisos3')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: con un menor el adulto puede cortar lo suyo."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + tpl[i:j] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›✓']
assert not bad, set(bad)
open(R + 'aplicar-permisos-ojo3-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
t = open(S + 'index-permisos2.ts', encoding='utf-8').read()
for a in pares:
    assert t.count(a) == 1, (t.count(a), a[:60])
for a, b in zip(pares, nuevos):
    t = t.replace(a, b)
open(S + 'index-permisos3.ts', 'w', encoding='utf-8').write(t)
print('ok', len(total))
