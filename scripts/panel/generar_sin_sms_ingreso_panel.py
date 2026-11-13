# Genera scripts/aplicar-sin-sms-ingreso-panel.ps1: el aviso "Ingreso desde la app del telefono" (se abre el mapa o la consola desde la app de un telefono vinculado) sale SOLO por correo, nunca por SMS.
# Luciano (13/11/2026): "me mando un mensaje de texto avisando que entre al sistema, ese hay que suspenderlo". Cada SMS cuesta y es algo de todos los dias. Los demas avisos de seguridad no cambian.
import re
R = '/home/user/Murray/scripts/'
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
A1 = '  sendEmailChannel: () => Promise<void>,\n) {\n'
B1 = '  sendEmailChannel: () => Promise<void>,\n  soloCorreo = false, // true: nunca por SMS (avisos de todos los dias que no valen el costo de un mensaje)\n) {\n'
A2 = '  if (shouldSendSms && prefs.phoneNumber) tasks.push(sendSms(env, prefs.phoneNumber, smsBody));'
B2 = '  if (shouldSendSms && !soloCorreo && prefs.phoneNumber) tasks.push(sendSms(env, prefs.phoneNumber, smsBody));'
A3 = 'async function sendSecurityNotice(env: Env, email: string, title: string, detail: string, deviceName?: string) {'
B3 = 'async function sendSecurityNotice(env: Env, email: string, title: string, detail: string, deviceName?: string, soloCorreo = false) {'
A4 = '        console.error("security_notice_mail_failed", error);\n      }\n    },\n  );\n}'
B4 = '        console.error("security_notice_mail_failed", error);\n      }\n    },\n    soloCorreo,\n  );\n}'
A5 = '    equipo?.name || "Tel\\u00e9fono principal",\n  ).catch(() => undefined);'
B5 = '    equipo?.name || "Tel\\u00e9fono principal",\n    true, // este aviso sale solo por correo: abrir el mapa o la consola desde la app es de todos los dias y cada SMS cuesta\n  ).catch(() => undefined);'
pares = [(A1, B1), (A2, B2), (A3, B3), (A4, B4), (A5, B5)]
nombres = ['aviso: notifyOwner puede salir solo por correo', 'aviso: notifyOwner no manda SMS si es solo correo', 'aviso: sendSecurityNotice acepta solo correo',
           'aviso: sendSecurityNotice pasa solo correo', 'aviso: "Ingreso desde la app del telefono" sale solo por correo']
filas = [('src\\index.ts', n, a, b) for n, (a, b) in zip(nombres, pares)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-sin-sms-ingreso-panel.ps1 - Ojo Guard MS: el aviso "Ingreso desde la app del telefono" (al abrir el mapa o la consola desde la app de un telefono vinculado) sale SOLO por correo, ya no por mensaje de texto.
# Luciano (13/11/2026): "me mando un mensaje de texto avisando que entre al sistema, ese hay que suspenderlo". Es algo de todos los dias y cada SMS cuesta. Los demas avisos de seguridad (nuevo dispositivo, passkey, etc.) no cambian.
# Cambia src\\index.ts (respaldo .bak-sin-sms-ingreso). Va en la carpeta del PANEL (la que tiene wrangler.toml). Sin build. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'soloCorreo = false') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-sin-sms-ingreso')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: el aviso de ingreso desde la app sale solo por correo, sin mensaje de texto."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + tpl[i:j] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›✓']
assert not bad, set(bad)
open(R + 'aplicar-sin-sms-ingreso-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\r\n', '\n').replace('\n', '\r\n'))
t = open(S + 'index-remedios2.ts', encoding='utf-8').read()
for a, _ in pares:
    assert t.count(a) == 1, (t.count(a), a[:80])
for a, b in pares:
    t = t.replace(a, b)
open(S + 'index-sinsms.ts', 'w', encoding='utf-8').write(t)
print('ok', len(total))
