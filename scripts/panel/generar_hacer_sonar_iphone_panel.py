# Genera scripts/aplicar-hacer-sonar-iphone-panel.ps1: prueba para que el aviso de Hacer sonar a un iPhone salga como el del SOS (envio aparte, sin tag). Android no cambia.

import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
A_HANDLER1 = 'async scheduled(_controller: ScheduledController, env: Env, ctx: ExecutionContext) {\n'
B_HANDLER1 = A_HANDLER1 + '    ENV_PUSH = env;\n'
A_HANDLER2 = 'async fetch(request: Request, env: Env) {\n'
B_HANDLER2 = A_HANDLER2 + '    ENV_PUSH = env;\n'
A_FUN = 'async function sendExpoCommandPush(\n'
B_FUN = ('// La base de datos del pedido en curso, para que sendExpoCommandPush pueda saber si el token es de un iPhone sin cambiar las 12 llamadas.\n'
         'let ENV_PUSH: Env | null = null;\n\n') + A_FUN
A_MSG = '  const message = content[type];\n  const commandData = { commandId, kind: message.kind, deviceName };\n'
B_MSG = A_MSG + ('  // PRUEBA (30/10/2026): en iPhone, "Hacer sonar" con la llave en silencio no sonaba y el SOS si. El SOS sale como un aviso solo y sin "tag"; este tambien lo hace asi para iPhone.\n'
  '  const esIphone = type === "alarm" && ENV_PUSH\n'
  '    ? await ENV_PUSH.DB.prepare("SELECT platform FROM devices WHERE push_token=? LIMIT 1").bind(pushToken).first<{ platform: string | null }>().then((fila) => fila?.platform === "ios").catch(() => false)\n'
  '    : false;\n')
A_TAG = '      tag: `ojo-guard-${message.kind}`,\n'
B_TAG = '      ...(esIphone ? {} : { tag: `ojo-guard-${message.kind}` }),\n'
A_SEND = '  const response = await fetch("https://exp.host/--/api/v2/push/send", {\n    method: "POST",\n    headers: { "content-type": "application/json", accept: "application/json" },\n    body: JSON.stringify(messages),\n'
B_SEND = ('  if (esIphone) {\n'
  '    // Un envio por aviso, primero el visible (el que suena) y despues el que despierta la app, como sale el SOS.\n'
  '    let alguno = false;\n'
  '    for (const mensaje of [...messages].reverse()) {\n'
  '      const r = await fetch("https://exp.host/--/api/v2/push/send", {\n'
  '        method: "POST",\n'
  '        headers: { "content-type": "application/json", accept: "application/json" },\n'
  '        body: JSON.stringify([mensaje]),\n'
  '      });\n'
  '      if (!r.ok) throw new Error(`expo_push_${r.status}`);\n'
  '      const res = await r.json<{ data?: Array<{ status?: string }> }>();\n'
  '      if (Array.isArray(res.data) && res.data.some((ticket) => ticket.status === "ok")) alguno = true;\n'
  '    }\n'
  '    return alguno;\n'
  '  }\n') + A_SEND
filas = [('src\\index.ts', 'hacer sonar iPhone: guarda el pedido en curso', A_FUN, B_FUN),
         ('src\\index.ts', 'hacer sonar iPhone: pedido en curso (programado)', A_HANDLER1, B_HANDLER1),
         ('src\\index.ts', 'hacer sonar iPhone: pedido en curso (fetch)', A_HANDLER2, B_HANDLER2),
         ('src\\index.ts', 'hacer sonar iPhone: detectar iPhone', A_MSG, B_MSG),
         ('src\\index.ts', 'hacer sonar iPhone: sin tag en iPhone', A_TAG, B_TAG),
         ('src\\index.ts', 'hacer sonar iPhone: envios separados', A_SEND, B_SEND)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-hacer-sonar-iphone-panel.ps1 - Ojo Guard MS (solo servidor, sin build): PRUEBA para "Hacer sonar" a un iPhone.
# Motivo (30/10/2026): con el iPhone bloqueado, la app cerrada y la llave lateral en silencio, el SOS suena y "Hacer sonar" no, aunque usan la misma sirena. Para iPhone, el aviso de Hacer sonar sale ahora como el del SOS: un envio aparte para el aviso visible, sin el campo "tag" (Android no cambia).
# Cambia SOLO src\\index.ts (respaldo .bak-sonar-iphone). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'let ENV_PUSH') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-sonar-iphone')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: el aviso de Hacer sonar a un iPhone sale como el del SOS (prueba)."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127]
assert not bad, set(bad)
open(R + 'aplicar-hacer-sonar-iphone-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
