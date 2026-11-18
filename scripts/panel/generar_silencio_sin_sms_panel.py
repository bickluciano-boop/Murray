# Genera scripts/aplicar-silencio-sin-sms-panel.ps1 (servidor).
# Luciano (18/11/2026), al ver el SMS "Ojo Guard: Android Luciano (Xiaomi) dejo de responder. Ultima senal: ...": "Esto hay que solucionarlo! Es una maquina traga monedas".
# El aviso "el equipo dejo de responder" (notifyDeviceSilence) mandaba SMS (cuesta plata) ademas del mail cada vez que un telefono pasaba horas sin dar senal (Android lo duerme en segundo plano).
# Ahora el SMS sale SOLO si el equipo dejo de responder justo despues de un intento de entrada (señal de robo, raro). El silencio comun va solo por mail. El SOS y el Modo Cautela no se tocan.
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
V = '  if (prefs.notifySms && prefs.phoneNumber) {\n    // El carrier argentino reemplaza'
N = ('  // El SMS cuesta plata: solo sale si el equipo dejo de responder justo despues de un intento de entrada (posible robo).\n'
     '  // El silencio comun (Android duerme la app, sin senal, bateria) va solo por mail.\n'
     '  if (reason === "after_attempt" && prefs.notifySms && prefs.phoneNumber) {\n    // El carrier argentino reemplaza')
filas = [('src\\index.ts', 'silencio: el SMS de "dejo de responder" solo sale tras un intento de entrada', V, N)]
def cambios_ps(fs):
    # Con UNA sola fila, PowerShell aplana @(@(...)) y $c[0] pasa a ser la primera letra: hay que anteponer una coma (,@(...)).
    pref = "    ," if len(fs) == 1 else "    "
    return "$cambios = @(\n" + ',\n'.join(pref + "@(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in fs) + "\n)\n"
i0 = tpl.index('$ErrorActionPreference'); j0 = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-silenciosms')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
MENSAJE = 'LISTO: el aviso de equipo que dejo de responder ya no manda SMS (solo mail); el SMS queda para un intento de entrada seguido de apagon.'
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "%s"\n' % MENSAJE, cola)
assert MENSAJE in cola
cabeza = '''# aplicar-silencio-sin-sms-panel.ps1 - Ojo Guard MS (servidor): el aviso "el equipo dejo de responder" ya no manda SMS (cuesta plata); va por mail.
# El SMS solo sale si el equipo dejo de responder justo despues de un intento de entrada (posible robo). Luciano (18/11/2026): "es una maquina traga monedas".
# Cambia src\\index.ts, funcion notifyDeviceSilence (respaldo .bak-silenciosms). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
'''
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'reason === "after_attempt" && prefs.notifySms') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
total = cabeza + tpl[i0:j0] + guardas + cambios_ps(filas) + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕‹›']
assert not bad, set(bad)
open(R + 'aplicar-silencio-sin-sms-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
# prueba del ancla sobre el codigo que pego Luciano (UTF-8 leido como ANSI: solo importa la parte ASCII)
muestra = '''    : "x";
  const cuerpo = `y`;

  if (prefs.notifySms && prefs.phoneNumber) {
    // El carrier argentino reemplaza el nÃºmero de origen por un cÃ³digo corto
    await sendSms(env, prefs.phoneNumber, `Ojo Guard: ${titulo}.`);
  }
  if (!prefs.notifyEmail) return;
'''
assert muestra.count(V) == 1
out = muestra.replace(V, N)
assert out.count('after_attempt" && prefs.notifySms') == 1 and 'if (!prefs.notifyEmail) return;' in out
print('ok', len(total))
