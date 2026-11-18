# Genera scripts/aplicar-medicamentos-alerta-panel.ps1 (servidor): los avisos de medicamentos salen por el canal de Android "ojo-medicamentos-2" (cartel arriba, sonido corto, vibracion larga, luz)
# y en iPhone como "time-sensitive" (suena aunque haya un modo Concentracion). Luciano (18/11/2026): mas notorio pero NO invasivo. Se aplica DESPUES de instalar las builds nuevas de la app
# (un telefono con la app vieja, sin el canal nuevo, lo recibe por el canal de respaldo del sistema, con sonido normal).
import re
R = '/home/user/Murray/scripts/'
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/priv/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
V = 'sendExpoNoticeLogged(env, f.pushToken, titulo, texto, motivo, { channelId: "ojo-medicamentos", data })'
N = 'sendExpoNoticeLogged(env, f.pushToken, titulo, texto, motivo, { channelId: "ojo-medicamentos-2", interruptionLevel: "time-sensitive", data })'
filas = [('src\\index.ts', 'alerta: el aviso de medicamentos usa el canal nuevo y es time-sensitive en iPhone', V, N)]
def cambios_ps(fs):
    # Con UNA sola fila, PowerShell aplana @(@(...)) y $c[0] pasa a ser la primera letra: hay que anteponer una coma (,@(...)).
    pref = "    ," if len(fs) == 1 else "    "
    return "$cambios = @(\n" + ',\n'.join(pref + "@(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in fs) + "\n)\n"
i0 = tpl.index('$ErrorActionPreference'); j0 = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-alerta')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
MENSAJE = 'LISTO: los avisos de medicamentos salen con cartel, vibracion larga y luz en Android, y time-sensitive en iPhone.'
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "%s"\n' % MENSAJE, cola)
assert MENSAJE in cola
cabeza = '''# aplicar-medicamentos-alerta-panel.ps1 - Ojo Guard MS (servidor): los avisos de medicamentos salen por el canal de Android "ojo-medicamentos-2" (cartel arriba, sonido corto, vibracion larga, luz) y en iPhone como "time-sensitive".
# Luciano (18/11/2026): mas notorio pero NO invasivo. APLICAR DESPUES de instalar las builds nuevas de la app (con la app vieja el aviso sale por el canal de respaldo del sistema). Cambia src\\index.ts (respaldo .bak-alerta). Va en la carpeta del PANEL. Al final publica el panel solo.
'''
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'ojo-medicamentos-2') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'async function medAvisarA') -eq 0) { Mal "Falta aplicar primero aplicar-medicamentos-privados-panel.ps1."; return }
'''
total = cabeza + tpl[i0:j0] + guardas + cambios_ps(filas) + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕‹›']
assert not bad, set(bad)
open(R + 'aplicar-medicamentos-alerta-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
t = open(S + 'med-privados.ts', encoding='utf-8').read()
assert t.count(V) == 1, t.count(V)
open(S + 'med-alerta.ts', 'w', encoding='utf-8').write(t.replace(V, N))
print('ok', len(total))
