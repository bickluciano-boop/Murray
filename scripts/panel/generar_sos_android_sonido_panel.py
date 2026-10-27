# Genera scripts/aplicar-sos-android-sonido-panel.ps1: el segundo SOS seguido (menos de 40 s) solo llega mudo a los iPhone; en Android suena igual.
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-raiz-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"

A1 = 'async function pushTokensOf(env: Env, email: string) {'
N1 = '''/** Igual que pushTokensOf, pero con la plataforma de cada telefono ("ios" o "android"): el SOS necesita saber a quien mandarlo mudo. */
async function pushTokensConPlataforma(env: Env, email: string) {
  const filas = await env.DB.prepare("SELECT DISTINCT push_token AS pushToken, platform FROM devices WHERE owner_email=? AND approval_status='approved' AND push_token IS NOT NULL")
    .bind(email).all<{ pushToken: string; platform: string | null }>();
  return filas.results;
}

''' + A1
A2 = 'for (const token of await pushTokensOf(env, r)) await sendExpoNoticeLogged(env, token, "SOS", '
N2 = 'for (const dest of await pushTokensConPlataforma(env, r)) await sendExpoNoticeLogged(env, dest.pushToken, "SOS", '
A3 = '{ sinSonido: sirenaAnteriorSonando, sound: "ojo_sirena_corta.wav"'
N3 = '{ sinSonido: sirenaAnteriorSonando && dest.platform === "ios", sound: "ojo_sirena_corta.wav"'

filas = [
    ('src\\index.ts', 'funcion que trae el token y la plataforma de cada telefono', A1, N1),
    ('src\\index.ts', 'SOS: recorre los telefonos con su plataforma', A2, N2),
    ('src\\index.ts', 'SOS: el silencio de los 40 s solo para iPhone', A3, N3),
]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-sos-android-sonido-panel.ps1 - Ojo Guard MS: el segundo SOS pedido a menos de 40 segundos del anterior ya no llega mudo a los Android.
# Antes: si la misma persona pedia otro SOS en menos de 40 s (aunque el primero estuviera cancelado) el aviso nuevo salia SIN sonido para todos. Eso se penso para el iPhone
# (una sirena de aviso no se puede cortar y se superpondria con la anterior). En Android la sirena se corta, y en una emergencia real un segundo pedido no debe llegar mudo.
# Ahora: el silencio de esos 40 s queda solo para los telefonos iPhone; los Android suenan igual. Nada mas cambia (destinatarios, mail, SMS, mapa).
# Cambia SOLO src\\index.ts (respaldo .bak-sosandroid). Va en la carpeta del PANEL (la que tiene wrangler.toml). No necesita build nueva de la app. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'function pushTokensConPlataforma') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-raiz', '.bak-sosandroid')
cola = re.sub(r'Ok "LISTO: el panel se abre en.*"\n', 'Ok "LISTO: el SOS repetido ya suena en Android (en iPhone, el segundo seguido sigue sin sonido a proposito)."\n', cola)
assert 'bak-raiz' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127]
assert not bad, set(bad)
open(R + 'aplicar-sos-android-sonido-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
