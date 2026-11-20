# Genera scripts/aplicar-sin-push-ubicacion-android-panel.ps1 (panel, src\\index.ts). Sin build de la app: solo se publica el panel.
# Luciano (20/11/2026), a partir del registro tecnico compartido (build 215): el aviso silencioso de prioridad alta que el servidor manda cada 15 min por la ubicacion automatica (96 por dia) probablemente agota el cupo que Android/FCM da a esos avisos cuando la app esta poco usada; desde las 18:15 del 19/11 ningun aviso desperto mas la tarea con el telefono quieto. HIPOTESIS sin verificar.
# En los ANDROID ya no se manda ese aviso (la alarma exacta de la app, cada ~20 min, levanta el pedido; el pedido dura 20 min). En el iPhone SE SIGUE mandando (no tiene alarma exacta: ese aviso es lo que lo despierta). Si no se sabe la plataforma, tambien se manda.
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
V_A = '  await sendExpoCommandPush(device.pushToken, "auto-locate", id, "").catch(() => false);'
V_B = '''  // 20/11/2026: en Android NO se manda el aviso silencioso de prioridad alta (96 por dia): se sospecha que agota el cupo de Android/FCM para avisos sin notificacion visible y despues ninguno despierta al telefono quieto; el pedido lo levanta la alarma exacta de la app (cada ~20 min, el pedido dura 20). En iPhone (sin alarma exacta) y si no se sabe la plataforma, se sigue mandando.
  const plataformaUbicacion = await env.DB.prepare("SELECT platform FROM devices WHERE id=?").bind(device.id).first<{ platform: string | null }>().then((fila) => fila?.platform ?? null).catch(() => null);
  if (plataformaUbicacion === "android") return;
  await sendExpoCommandPush(device.pushToken, "auto-locate", id, "").catch(() => false);'''
F = 'src\\index.ts'
filas = [(F, 'ubicacion automatica: sin aviso silencioso en Android (cupo de avisos)', V_A, V_B)]
def cambios_ps(fs):
    # Con UNA sola fila, PowerShell aplana @(@(...)) y $c[0] pasa a ser la primera letra: hay que anteponer una coma (,@(...)).
    pref = "    ," if len(fs) == 1 else "    "
    return "$cambios = @(\n" + ',\n'.join(pref + "@(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in fs) + "\n)\n"
i0 = tpl.index('$ErrorActionPreference'); j0 = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-sinpushubic')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
DEPLOY = 'if ($LASTEXITCODE -ne 0) { Mal "No se pudo publicar el panel. Mandame esta pantalla."; return }\n'
assert cola.count(DEPLOY) == 1
MENSAJE = 'LISTO: en los Android ya no se manda el aviso silencioso de la ubicacion automatica (lo levanta la alarma de la app). El iPhone sigue igual.'
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "%s"\n' % MENSAJE, cola)
assert MENSAJE in cola
cabeza = '''# aplicar-sin-push-ubicacion-android-panel.ps1 - Ojo Guard MS (panel, src\\index.ts): en los Android el servidor deja de mandar el aviso silencioso de la ubicacion automatica (cada 15 min); lo levanta la alarma exacta de la app. En iPhone sigue igual.
# Luciano (20/11/2026), a partir del registro tecnico (build 215). HIPOTESIS: ese aviso agota el cupo de Android/FCM y despues ninguno despierta al telefono quieto. Cambia solo queueAutoLocateCommand. Respaldo .bak-sinpushubic. Publica el panel (sin build). Va en la carpeta del PANEL (la que tiene wrangler.toml). Para deshacer: restaurar src\\index.ts desde index.ts.bak-sinpushubic y volver a publicar.
'''
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'async function queueAutoLocateCommand') -eq 0) { Mal "No encuentro queueAutoLocateCommand en src\\index.ts. Mandame esta pantalla."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'plataformaUbicacion') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
total = cabeza + tpl[i0:j0] + guardas + cambios_ps(filas) + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕‹›']
assert not bad, set(bad)
open(R + 'aplicar-sin-push-ubicacion-android-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
open('/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/filas_sin_push.json', 'w', encoding='utf-8').write(__import__('json').dumps(filas))
muestra = '''async function queueAutoLocateCommand(
  env: Env,
  device: { id: string; ownerEmail: string; pushToken: string | null },
) {
  const id = randomId("cmd"), createdAt = now();
  await env.DB.prepare("INSERT INTO commands (id,device_id,owner_email,type,status,created_at,expires_at) VALUES (?,?,?,?,?,?,?)")
    .bind(id, device.id, device.ownerEmail, "auto-locate", "pending", createdAt, plusMinutes(20)).run();
  await sendExpoCommandPush(device.pushToken, "auto-locate", id, "").catch(() => false);
}
'''
assert muestra.count(V_A) == 1, muestra.count(V_A)
open('/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/muestra_sin_push.ts', 'w', encoding='utf-8').write(muestra.replace(V_A, V_B))
print('ok', len(total))
