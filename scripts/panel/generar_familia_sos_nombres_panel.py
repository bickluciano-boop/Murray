# Genera scripts/aplicar-familia-sos-nombres-panel.ps1: cada persona de la lista de familia trae `sosTo` (true si a esa persona le suena el SOS de quien mira), para que la app diga "tu SOS les llega a ..." sin pantalla nueva.
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"

A1 = 'async function familyPeopleFor(env: Env, viewer: string) {\n'
B1 = (A1 +
'  // A quien le suena el SOS de `viewer` (la misma regla del SOS: titular, y adultos salvo que sea amigo). La app lo usa para decir con nombres a quien le llega su SOS.\n'
'  const destinoSos = new Set(await familySosRecipients(env, viewer).catch(() => [] as string[]));\n')
A2 = '      photo: await fotoVersion(env, p.email),\n      // Solo para quien administra a esa persona'
B2 = '      photo: await fotoVersion(env, p.email),\n      sosTo: destinoSos.has(p.email),\n      // Solo para quien administra a esa persona'
filas = [('src\\index.ts', 'familia: destinatarios del SOS (destinoSos)', A1, B1), ('src\\index.ts', 'familia: sosTo en cada persona', A2, B2)]
cambios = "$cambios = @(\n" + ',\n'.join(("    ,@(%s, %s, %s, %s)" if len(filas) == 1 else "    @(%s, %s, %s, %s)") % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-familia-sos-nombres-panel.ps1 - Ojo Guard MS: la lista de familia dice a quien le suena tu SOS (campo sosTo en cada persona).
# Luciano (04/11/2026): "donde aparece con quien estas compartiendo la ubicacion y a quien le mandas el SOS". La app no tenia como saber a quien le llega el SOS (lo decide el servidor). Cada persona de la lista de familia trae ahora sosTo=true/false con la MISMA regla del SOS (titular; adultos salvo que quien pide sea amigo). No cambia el SOS ni los permisos: solo agrega un dato.
# La app lo muestra en Familia y amigos (instalador aplicar-familia-sos-nombres-app.ps1).
# Cambia SOLO src\\index.ts (respaldo .bak-sosnombres). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'const destinoSos') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-sosnombres')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: la lista de familia ya dice a quien le suena tu SOS."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›✓']
assert not bad, set(bad)
open(R + 'aplicar-familia-sos-nombres-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
t = open(S + 'index-consent.ts', encoding='utf-8').read()
assert t.count(A1) == 1 and t.count(A2) == 1, (t.count(A1), t.count(A2))
open(S + 'index-sosnombres.ts', 'w', encoding='utf-8').write(t.replace(A1, B1).replace(A2, B2))
print('ok', len(total))
