# Genera scripts/aplicar-ingreso-sin-aviso-panel.ps1.
# Luciano (13/11/2026): "si alguien entro con su clave esta bien; en todo caso tendria que mandar cuando alguien quiso entrar y tres veces puso mal".
# 1) El aviso "Ingreso desde la app del telefono" ya no se manda (ni SMS ni correo): quien abre el mapa/consola desde su propia app entro bien.
# 2) Nuevo aviso: a la 3.a vez seguida que alguien pone mal el codigo de una cuenta que existe, le llega "Intentaron entrar a tu cuenta".
# 3) Se corrige el contador de intentos fallidos: se reiniciaba en 1 cada vez y el bloqueo de 15 minutos (8 intentos) nunca llegaba a activarse.
import re
R = '/home/user/Murray/scripts/'
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
A1 = 'const CODE_LOCKOUT_THRESHOLD = 8;\n'
B1 = ('// A la 3.a vez seguida que alguien pone mal el codigo de una cuenta que existe, a su dueno le llega un aviso (1 vez por tanda de intentos).\n'
      'const CODE_AVISO_INTENTOS = 3;\n'
      '// El aviso "Ingreso desde la app del telefono" (abrir el mapa o la consola desde la app) esta apagado: quien entra con su propia app entro bien. Para volver a recibirlo: true.\n'
      'const AVISAR_INGRESO_DESDE_APP = false;\n') + A1
A2 = '  if (avisar) await sendSecurityNotice(\n    env,\n    fila.ownerEmail,\n'
B2 = '  if (AVISAR_INGRESO_DESDE_APP && avisar) await sendSecurityNotice(\n    env,\n    fila.ownerEmail,\n'
A3 = ('    "SELECT failed_attempts AS failedAttempts, locked_until AS lockedUntil FROM access_rate_limits WHERE email=?",\n'
      '  ).bind(email).first<{ failedAttempts: number; lockedUntil: string | null }>();\n'
      '  // Un bloqueo vencido arranca una ventana nueva; uno vigente sigue sumando.\n'
      '  const expired = !row?.lockedUntil || Date.parse(row.lockedUntil) <= Date.now();\n'
      '  const failedAttempts = (expired ? 0 : row!.failedAttempts) + 1;\n'
      '  const lockedUntil = failedAttempts >= CODE_LOCKOUT_THRESHOLD\n'
      '    ? plusMinutes(CODE_LOCKOUT_MINUTES)\n'
      '    : (expired ? null : row!.lockedUntil);\n')
B3 = ('    "SELECT failed_attempts AS failedAttempts, locked_until AS lockedUntil, last_attempt_at AS lastAttemptAt FROM access_rate_limits WHERE email=?",\n'
      '  ).bind(email).first<{ failedAttempts: number; lockedUntil: string | null; lastAttemptAt: string | null }>();\n'
      '  // Los intentos suman mientras el ultimo haya sido hace menos de CODE_LOCKOUT_MINUTES; pasado ese tiempo arranca una tanda nueva.\n'
      '  // (Antes se reiniciaba en 1 en cada intento y el bloqueo nunca llegaba a activarse.)\n'
      '  const tandaViva = Boolean(row?.lastAttemptAt) && Date.now() - Date.parse(row!.lastAttemptAt!) < CODE_LOCKOUT_MINUTES * 60_000;\n'
      '  const failedAttempts = (tandaViva ? row!.failedAttempts : 0) + 1;\n'
      '  const lockedUntil = failedAttempts >= CODE_LOCKOUT_THRESHOLD\n'
      '    ? plusMinutes(CODE_LOCKOUT_MINUTES)\n'
      '    : (row?.lockedUntil && Date.parse(row.lockedUntil) > Date.now() ? row.lockedUntil : null);\n')
A4 = '  ).bind(email, failedAttempts, lockedUntil, now()).run();\n}\n'
B4 = ('  ).bind(email, failedAttempts, lockedUntil, now()).run();\n'
      '  // Aviso al dueno: solo si la cuenta existe (no se le escribe a cualquier direccion que alguien tipee) y una sola vez por tanda.\n'
      '  if (failedAttempts === CODE_AVISO_INTENTOS) {\n'
      '    const cuenta = await env.DB.prepare("SELECT 1 AS existe FROM devices WHERE owner_email=? LIMIT 1").bind(email).first<{ existe: number }>().catch(() => null);\n'
      '    if (cuenta) {\n'
      '      await sendSecurityNotice(\n'
      '        env,\n'
      '        email,\n'
      '        "Intentaron entrar a tu cuenta",\n'
      '        `Alguien puso mal el c\\u00f3digo para entrar a Ojo Guard MS ${CODE_AVISO_INTENTOS} veces seguidas con tu correo. Si fuiste vos, no pasa nada. Si no fuiste vos, revis\\u00e1 los dispositivos del panel. Con ${CODE_LOCKOUT_THRESHOLD} intentos fallidos el acceso se bloquea ${CODE_LOCKOUT_MINUTES} minutos.`,\n'
      '      ).catch(() => undefined);\n'
      '    }\n'
      '  }\n}\n')
pares = [(A1, B1), (A2, B2), (A3, B3), (A4, B4)]
nombres = ['acceso: constantes (aviso a los 3 intentos y aviso de ingreso apagado)', 'acceso: aviso "Ingreso desde la app del telefono" apagado',
           'acceso: el contador de intentos fallidos suma de verdad', 'acceso: aviso al dueno a los 3 intentos fallidos']
filas = [('src\\index.ts', n, a, b) for n, (a, b) in zip(nombres, pares)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-ingreso-sin-aviso-panel.ps1 - Ojo Guard MS: (1) ya no se avisa cuando alguien entra con su propia app (el aviso "Ingreso desde la app del telefono", ni SMS ni correo); (2) SI se avisa cuando alguien puso mal el codigo 3 veces seguidas.
# Luciano (13/11/2026): "si alguien entro con su clave esta bien; en todo caso tendria que mandar cuando alguien quiso entrar y tres veces puso mal". Tambien corrige el contador de intentos fallidos, que se reiniciaba en 1 en cada intento (el bloqueo de 15 minutos a los 8 intentos nunca se activaba).
# Funciona haya o no aplicado antes aplicar-sin-sms-ingreso-panel.ps1. Cambia src\\index.ts (respaldo .bak-ingreso-sin-aviso). Va en la carpeta del PANEL (la que tiene wrangler.toml). Sin build. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'AVISAR_INGRESO_DESDE_APP') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-ingreso-sin-aviso')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: ya no avisa cuando alguien entra bien; avisa a los 3 intentos fallidos."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + tpl[i:j] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›✓']
assert not bad, set(bad)
open(R + 'aplicar-ingreso-sin-aviso-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
for origen, destino in (('index-remedios2.ts', 'index-ingreso.ts'), ('index-sinsms.ts', 'index-ingreso-b.ts')):
    t = open(S + origen, encoding='utf-8').read()
    for a, _ in pares:
        assert t.count(a) == 1, (origen, t.count(a), a[:80])
    for a, b in pares:
        t = t.replace(a, b)
    open(S + destino, 'w', encoding='utf-8').write(t)
print('ok', len(total))
