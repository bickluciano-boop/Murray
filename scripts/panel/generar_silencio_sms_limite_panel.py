# Genera scripts/aplicar-silencio-sms-limite-panel.ps1 (servidor). Requiere aplicar-silencio-sin-sms-panel.ps1.
# Luciano (19/11/2026): "si, preparalo". El SMS de "el equipo dejo de responder" vuelve, pero como MAXIMO UNO por telefono cada 24 horas (el mail sale siempre; tras un intento de entrada el SMS sale siempre).
# Motivo: el SMS de las 17:30 del 18/11 era un episodio real (Android dormido 5 horas) y lo habia dejado solo por mail; lo que molestaba era la repeticion ("traga monedas").
# Se anota el ultimo SMS por telefono en la tabla silence_sms (se crea sola). Si el registro falla, NO se manda SMS: mejor callar que gastar de mas.
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
F_A = 'async function notifyDeviceSilence(\n'
F_B = '''/** Un SMS de "dejo de responder" por telefono cada 24 horas como maximo (el mail sale siempre). Si no se puede anotar, no se manda SMS: mejor callar que gastar de mas. */
async function silencioSmsPermitido(env: Env, email: string, deviceName: string) {
  const clave = `${email.toLowerCase()}|${deviceName}`.slice(0, 200);
  try {
    await env.DB.prepare("CREATE TABLE IF NOT EXISTS silence_sms (clave TEXT PRIMARY KEY, at TEXT NOT NULL)").run();
    const ahora = Date.now();
    const fila = await env.DB.prepare("SELECT at FROM silence_sms WHERE clave=?").bind(clave).first<{ at: string }>();
    if (fila && ahora - Date.parse(fila.at) < 24 * 3_600_000) return false;
    await env.DB.prepare("INSERT OR REPLACE INTO silence_sms (clave, at) VALUES (?,?)").bind(clave, new Date(ahora).toISOString()).run();
    return true;
  } catch {
    return false;
  }
}

''' + F_A
S_A = ('  // El SMS cuesta plata: solo sale si el equipo dejo de responder justo despues de un intento de entrada (posible robo).\n'
       '  // El silencio comun (Android duerme la app, sin senal, bateria) va solo por mail.\n'
       '  if (reason === "after_attempt" && prefs.notifySms && prefs.phoneNumber) {\n    // El carrier argentino reemplaza')
S_B = ('  // El SMS cuesta plata: tras un intento de entrada (posible robo) sale siempre; el silencio comun, como maximo un SMS por telefono cada 24 horas.\n'
       '  // El mail sale siempre.\n'
       '  if (prefs.notifySms && prefs.phoneNumber && (reason === "after_attempt" || await silencioSmsPermitido(env, email, deviceName))) {\n    // El carrier argentino reemplaza')
filas = [('src\\index.ts', 'silencio: funcion que limita el SMS a uno por telefono cada 24 h', F_A, F_B),
         ('src\\index.ts', 'silencio: el SMS sale tras un intento de entrada o si no hubo otro en 24 h', S_A, S_B)]
def cambios_ps(fs):
    return "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in fs) + "\n)\n"
i0 = tpl.index('$ErrorActionPreference'); j0 = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-silenciosmslimite')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
MENSAJE = 'LISTO: el SMS de equipo que dejo de responder vuelve, como maximo uno por telefono cada 24 horas (el mail sale siempre).'
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "%s"\n' % MENSAJE, cola)
assert MENSAJE in cola
cabeza = '''# aplicar-silencio-sms-limite-panel.ps1 - Ojo Guard MS (servidor): el SMS de "el equipo dejo de responder" vuelve, con tope de UNO por telefono cada 24 horas (el mail sale siempre; tras un intento de entrada el SMS sale siempre).
# Luciano (19/11/2026): el SMS de las 17:30 del 18/11 era un episodio real; lo que molestaba era la repeticion. Requiere aplicar-silencio-sin-sms-panel.ps1. Crea la tabla silence_sms sola. Cambia src\\index.ts (respaldo .bak-silenciosmslimite). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
'''
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'silencioSmsPermitido') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'reason === "after_attempt" && prefs.notifySms') -eq 0) { Mal "Falta aplicar primero aplicar-silencio-sin-sms-panel.ps1."; return }
'''
total = cabeza + tpl[i0:j0] + guardas + cambios_ps(filas) + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕‹›']
assert not bad, set(bad)
open(R + 'aplicar-silencio-sms-limite-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
# anclajes sobre el codigo que pego Luciano + el parche anterior
# El texto que deja aplicar-silencio-sin-sms-panel.ps1 se LEE de ese instalador (no se copia a mano): asi un error de tipeo no pasa desapercibido.
prev = open(R + 'aplicar-silencio-sin-sms-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
k = prev.index("$cambios = @(\n"); k2 = prev.index("\n)\n", k)
campos = [c.replace("''", "'") for c in re.findall(r"'((?:[^']|'')*)'", prev[k:k2])]
dejado_por_el_anterior = campos[3]   # [archivo, etiqueta, ancla, nuevo]
muestra = ("x\nasync function notifyDeviceSilence(\n  env: Env,\n  options: {\n  },\n) {\n  const visto = 1;\n"
           + dejado_por_el_anterior
           + " el nÃºmero de origen por un cÃ³digo corto\n    await sendSms(env, prefs.phoneNumber, `Ojo Guard: ${titulo}.`);\n  }\n}\n")
for a, n, v, nv in filas:
    assert muestra.count(v) == 1, (n, muestra.count(v))
out = muestra
for a, n, v, nv in filas:
    out = out.replace(v, nv)
open('/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/silencio_muestra.ts', 'w', encoding='utf-8').write(out)
open('/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/silencio_fn.ts', 'w', encoding='utf-8').write(F_B.split('async function notifyDeviceSilence(')[0])
print('ok', len(total))
