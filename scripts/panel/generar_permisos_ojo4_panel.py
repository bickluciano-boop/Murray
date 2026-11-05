# Genera scripts/aplicar-permisos-ojo4-panel.ps1: cada llave de SOS dice si "aplica" (un menor no recibe el SOS de los adultos; un amigo tampoco).
import re
R = '/home/user/Murray/scripts/'
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
A1 = 'async function familySosRecipients(env: Env, person: string) {\n'
B1 = 'async function familySosRecipients(env: Env, person: string, aplicarLlaves = true) {\n'
A2 = '  // Permisos: no le suena a quien la persona saco de su SOS ni a quien apago "Recibo su SOS".\n'
B2 = '  // Sin las llaves: quienes lo recibirian por su lugar en la familia (para saber a quien "no aplica", por ejemplo un menor).\n  if (!aplicarLlaves) return [...destinatarios];\n' + A2
A3 = '  const perms = await permsDe(env, viewer).catch(() => new Map<string, PermFila>());\n'
B3 = A3 + '  const baseSos = new Set(liviano ? [] : await familySosRecipients(env, viewer, false).catch(() => [] as string[]));\n'
A4 = 'ultimo: false });\n'
B4 = 'ultimo: false, elegible: true });\n'
A5 = '    permisos.recibeTuSos.ultimo = permisos.recibeTuSos.on && destinoSos.size === 1 && destinoSos.has(p.email);\n'
B5 = ('    // "No aplica": un menor no recibe el SOS de los adultos (y un amigo solo el de su titular). Ahi la llave se muestra apagada y quieta.\n'
      '    if (!liviano) {\n'
      '      permisos.recibeTuSos.elegible = baseSos.has(p.email);\n'
      '      permisos.recibisSuSos.elegible = (await familySosRecipients(env, p.email, false).catch(() => [] as string[])).includes(viewer);\n'
      '      if (!permisos.recibeTuSos.elegible) permisos.recibeTuSos.on = false;\n'
      '      if (!permisos.recibisSuSos.elegible) permisos.recibisSuSos.on = false;\n'
      '    }\n') + A5
pares = [A1, A2, A3, A4, A5]; nuevos = [B1, B2, B3, B4, B5]
nombres = ['permisos4: SOS sin llaves (opcional)', 'permisos4: corte antes de las llaves', 'permisos4: base del SOS de quien mira', 'permisos4: elegible por defecto', 'permisos4: elegible en SOS']
filas = [('src\\index.ts', n, a, b) for n, a, b in zip(nombres, pares, nuevos)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-permisos-ojo4-panel.ps1 - Ojo Guard MS: las llaves de SOS dicen si "aplican".
# Luciano (05/11/2026): "el menor no tiene por que escuchar una alerta y asustarse, el padre si". Ya era asi (el SOS le llega al titular y a los adultos, nunca a un menor ni a un amigo), pero la tarjeta mostraba "Recibe tu SOS: Si" para el menor.
# Ahora cada persona trae permisos.recibeTuSos.elegible y permisos.recibisSuSos.elegible; si es false la app muestra "No aplica". No cambia a quien le llega el SOS. Requiere aplicar-permisos-ojo-panel.ps1 y aplicar-permisos-ojo2-panel.ps1. Cambia SOLO src\\index.ts (respaldo .bak-permisos4). Va en la carpeta del PANEL. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'liviano = false') -eq 0) { Mal "Falta aplicar primero aplicar-permisos-ojo2-panel.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'aplicarLlaves = true') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-permisos4')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: las llaves de SOS ya dicen si aplican."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + tpl[i:j] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›✓']
assert not bad, set(bad)
open(R + 'aplicar-permisos-ojo4-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
t = open(S + 'index-permisos3.ts', encoding='utf-8').read()
for a in pares:
    assert t.count(a) == 1, (t.count(a), a[:60])
for a, b in zip(pares, nuevos):
    t = t.replace(a, b)
open(S + 'index-permisos4.ts', 'w', encoding='utf-8').write(t)
print('ok', len(total))
