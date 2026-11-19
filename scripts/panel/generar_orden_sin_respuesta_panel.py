# Genera scripts/aplicar-orden-sin-respuesta-panel.ps1 (panel, pestana Dispositivos: src\panel-app.txt).
# Luciano (19/11/2026), tras dejar el Android dormido ~5 h (la orden de Modo Perdido espero hasta que alguien desbloqueo el telefono): "hacelo, pero sin textos ni mails".
# Hoy el panel prometia "La orden ya quedo guardada... se va a ejecutar sola apenas se conecte" (Modo Perdido) o "El telefono no confirmo la orden en 60 segundos" sin mas ayuda.
# Ahora, si pasan ~12 s y el telefono todavia no tomo la orden (estado "pending"), el panel dice la verdad y que hacer: ultima conexion, que suele ser Android durmiendo la app, y que si alguien lo tiene cerca lo desbloquee.
# SOLO texto en la tarjeta del equipo: no manda SMS ni mails. Si el telefono ya la recibio ("received") o la ejecuto, los textos de siempre.
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
F = 'src\\panel-app.txt'
A_A = 'async function pollCommand(commandId, card, type, deviceId) {\n  const status = $(".command-status", card);\n  for (let attempt = 0; attempt < 20; attempt += 1) {'
A_B = 'async function pollCommand(commandId, card, type, deviceId) {\n  const status = $(".command-status", card);\n  let ultimo = ""; // estado de la orden en la ultima consulta (si el telefono todavia no la tomo, "pending")\n  for (let attempt = 0; attempt < 20; attempt += 1) {'
B_A = '    const location = command.location;\n    if (command.status === "executed" && Number.isFinite(Number(location?.latitude))'
B_B = '    ultimo = command.status;\n    if (command.status === "pending" && attempt >= 4) status.textContent = sinRespuestaTexto(card, false);\n' + B_A
C_A = 'La orden no se considera ejecutada.";\n}\n\nfunction nearbySummary(entries) {'
C_B = '''La orden no se considera ejecutada.";
  if (ultimo === "pending") status.textContent = sinRespuestaTexto(card, true);
}

// El telefono todavia no tomo la orden: no se promete que "se va a ejecutar sola". Con la app dormida puede tardar horas (18/11/2026: ~5 h) hasta que alguien desbloquea el telefono. Solo texto en la tarjeta.
function sinRespuestaTexto(card, final) {
  const visto = (($(".device-last-seen", card) || {}).textContent || "").replace("Actualizado ", "").split(" · ")[0].trim();
  const cuando = visto && !visto.startsWith("Esperando") ? ` Última conexión: ${visto}.` : "";
  return `El teléfono todavía no tomó la orden.${cuando} Suele pasar cuando Android duerme la app. Si alguien lo tiene cerca, que desbloquee la pantalla: la orden se ejecuta en segundos.${final ? " La orden queda guardada y se ejecuta apenas el teléfono la tome." : ""}`;
}

function nearbySummary(entries) {'''
filas = [(F, 'orden sin respuesta: guardar el ultimo estado de la orden', A_A, A_B),
         (F, 'orden sin respuesta: a los ~12 s sin respuesta, el texto honesto', B_A, B_B),
         (F, 'orden sin respuesta: al cumplirse el tiempo, el texto honesto y la funcion', C_A, C_B)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
i0 = tpl.index('$ErrorActionPreference'); j0 = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-sinrespuesta')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
MENSAJE = 'LISTO: si el telefono no toma la orden, el panel dice la ultima conexion y que hacer (desbloquear el telefono). Solo texto, sin SMS ni mails.'
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "%s"\n' % MENSAJE, cola)
assert MENSAJE in cola
cabeza = '''# aplicar-orden-sin-respuesta-panel.ps1 - Ojo Guard MS (panel, pestana Dispositivos): si el telefono no toma la orden (Modo Perdido, evidencia, alarma...), el panel dice la verdad en la tarjeta del equipo:
# ultima conexion + "suele pasar cuando Android duerme la app; si alguien lo tiene cerca, que desbloquee la pantalla". Antes prometia que el Modo Perdido "se va a ejecutar sola apenas se conecte".
# Luciano (19/11/2026): "hacelo, pero sin textos ni mails": SOLO texto dentro del panel. Cambia src\\panel-app.txt (respaldo .bak-sinrespuesta). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
'''
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\panel-app.txt"))) { Mal "No encuentro src\\panel-app.txt en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-app.txt")).texto 'sinRespuestaTexto') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
total = cabeza + tpl[i0:j0] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕‹›']
assert not bad, set(bad)
open(R + 'aplicar-orden-sin-respuesta-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
open('/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/filas_sin_respuesta.json', 'w', encoding='utf-8').write(__import__('json').dumps(filas))
print('ok', len(total))
