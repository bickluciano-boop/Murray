# Genera scripts/aplicar-sos-sirena-app-panel.ps1: el SOS tambien despierta a la app de los Android que lo reciben con el mismo camino de "Hacer sonar" (orden alarm + aviso de datos).
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"

A1 = '    await familySosMail(env, r, nombre, ubicacionObj).catch((error) => console.error("family_sos_mail_failed", error));\n'
B1 = (
'    // Android: ademas del aviso (su sonido lo decide Android: volumen de alarma, No interrumpir, enfriamiento de avisos repetidos) se despierta a la app con el MISMO camino de\n'
'    // "Hacer sonar" (orden "alarm" + aviso de datos que despierta la tarea de la app), que toca la sirena por su cuenta. La orden vence a los 3 minutos: asi el reintento del cron\n'
'    // (retryPendingCommandsCron) no vuelve a mandar la sirena mas tarde. iPhone queda como estaba. Si algo falla aca, el aviso y el mail del SOS ya salieron.\n'
'    try {\n'
'      const androids = await env.DB.prepare("SELECT id, name, push_token AS pushToken FROM devices WHERE owner_email=? AND approval_status=\'approved\' AND push_token IS NOT NULL AND platform=\'android\'")\n'
'        .bind(r).all<{ id: string; name: string; pushToken: string }>();\n'
'      for (const equipo of androids.results) {\n'
'        const idOrden = randomId("cmd");\n'
'        await env.DB.prepare("INSERT INTO commands (id,device_id,owner_email,type,status,created_at,expires_at) VALUES (?,?,?,?,?,?,?)")\n'
'          .bind(idOrden, equipo.id, r, "alarm", "pending", now(), plusMinutes(3)).run();\n'
'        await sendExpoCommandPush(equipo.pushToken, "alarm", idOrden, equipo.name, { title: "SOS", body: `${nombre} pidi\\u00f3 ayuda. Abr\\u00ed el mapa para ver d\\u00f3nde est\\u00e1.` }).catch(() => false);\n'
'      }\n'
'    } catch (error) {\n'
'      console.error("sos_sirena_app_failed", error);\n'
'    }\n'
+ A1)
filas = [('src\\index.ts', 'SOS: despertar a la app de los Android para que toque la sirena (como Hacer sonar)', A1, B1)]
cambios = "$cambios = @(\n" + ',\n'.join(("    ,@(%s, %s, %s, %s)" if len(filas) == 1 else "    @(%s, %s, %s, %s)") % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-sos-sirena-app-panel.ps1 - Ojo Guard MS: el SOS tambien hace sonar la sirena DESDE LA APP en los Android que lo reciben (el mismo camino que "Hacer sonar").
# Luciano (03/11/2026): un SOS del iPhone llego al Android como notificacion pero sin sirena, y "Hacer sonar" desde el panel si sono. "Hacer sonar" manda dos avisos: uno de datos que despierta la app para que toque la sirena ella misma y otro visible; el SOS mandaba solo el visible, cuyo sonido depende de Android.
# Ahora, por cada Android del que recibe el SOS: una orden "alarm" que vence a los 3 minutos + el mismo aviso doble de "Hacer sonar" (con el titulo "SOS"). iPhone no cambia. Si algo falla en esta parte, el aviso, el mail y el SMS del SOS ya salieron.
# Cambia SOLO src\\index.ts (respaldo .bak-sosapp). Va en la carpeta del PANEL (la que tiene wrangler.toml). No necesita build de la app. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'sos_sirena_app_failed') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-sosapp')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: el SOS ya hace sonar la sirena desde la app en los Android que lo reciben."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›✓']
assert not bad, set(bad)
open(R + 'aplicar-sos-sirena-app-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
t = open(S + 'index-consent.ts', encoding='utf-8').read()
assert t.count(A1) == 1, t.count(A1)
open(S + 'index-sosapp.ts', 'w', encoding='utf-8').write(t.replace(A1, B1))
print('ok', len(total))
