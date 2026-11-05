# Genera scripts/aplicar-permisos-ojo2-panel.ps1: acelera el cambio de una llave de permisos (Luciano, 05/11/2026: "demora varios segundos").
import re
R = '/home/user/Murray/scripts/'
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
A1 = 'async function familyPeopleFor(env: Env, viewer: string) {\n'
B1 = 'async function familyPeopleFor(env: Env, viewer: string, liviano = false) {\n'
A2 = '    if (permisos.recibisSuSos.on && personas.size <= 12) {\n'
B2 = '    // `liviano`: el cambio de una llave solo necesita saber si la persona esta en la lista; ahorra las consultas del "ultimo".\n    if (!liviano && permisos.recibisSuSos.on && personas.size <= 12) {\n'
A3 = '  const persona = (await familyPeopleFor(env, email)).find((p) => p.id === personId);\n'
B3 = '  const persona = (await familyPeopleFor(env, email, true)).find((p) => p.id === personId);\n'
A4 = '    const yo = await familyNameSeenBy(env, email, otro);\n'
B4 = '    const [yo, tokens] = await Promise.all([familyNameSeenBy(env, email, otro), pushTokensOf(env, otro)]);\n'
A5 = '    for (const token of await pushTokensOf(env, otro)) await sendExpoNoticeLogged(env, token, "Ojo Guard", texto, "permiso", { channelId: "ojo-familia-aviso" }).catch(() => false);\n'
B5 = '    await Promise.all(tokens.map((token) => sendExpoNoticeLogged(env, token, "Ojo Guard", texto, "permiso", { channelId: "ojo-familia-aviso" }).catch(() => false)));\n'
pares = [A1, A2, A3, A4, A5]; nuevos = [B1, B2, B3, B4, B5]
nombres = ['permisos2: lista liviana', 'permisos2: sin consultas del ultimo en la lista liviana', 'permisos2: el cambio usa la lista liviana', 'permisos2: nombre y equipos en paralelo', 'permisos2: avisos en paralelo']
filas = [('src\\index.ts', n, a, b) for n, a, b in zip(nombres, pares, nuevos)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-permisos-ojo2-panel.ps1 - Ojo Guard MS: el cambio de una llave de permisos responde mas rapido.
# Luciano (05/11/2026): "cada vez que apretas una llave demora varios segundos". El pedido armaba la lista completa de la familia (con las consultas del "ultimo") y esperaba uno por uno el nombre, los equipos y el aviso a la otra persona.
# Ahora usa una lista liviana y hace lo del aviso en paralelo. No cambia ninguna regla. Requiere aplicar-permisos-ojo-panel.ps1. Cambia SOLO src\\index.ts (respaldo .bak-permisos2). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'async function nativeFamilyPerm') -eq 0) { Mal "Falta aplicar primero aplicar-permisos-ojo-panel.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'liviano = false') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-permisos2')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: el cambio de permisos responde mas rapido."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + tpl[i:j] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›✓']
assert not bad, set(bad)
open(R + 'aplicar-permisos-ojo2-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
t = open(S + 'index-permisos.ts', encoding='utf-8').read()
for a in pares:
    assert t.count(a) == 1, (t.count(a), a[:60])
for a, b in zip(pares, nuevos):
    t = t.replace(a, b)
open(S + 'index-permisos2.ts', 'w', encoding='utf-8').write(t)
print('ok', len(total))
