# Genera scripts/aplicar-login-descargas-panel.ps1: en la pagina de entrada de ojoguard.app (donde se escribe el codigo) agrega dos botones: Android (/descargar) e iPhone (TestFlight).
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-raiz-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
LINK = 'https://testflight.apple.com/join/QcWAsHkG'
fx = open('/root/.claude/uploads/459a989e-0585-521a-8ee1-3a385ef7024a/3347fd7c-panel-index-actual.html', encoding='utf-8').read().replace('\r\n', '\n')
filas = []
def cambio(rotulo, viejo, nuevo):
    assert fx.count(viejo) == 1, (rotulo, fx.count(viejo))
    filas.append(('src\\panel-index.html', rotulo, viejo, nuevo))

ANDROID = '<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M17.523 15.3414c-.5511 0-.9993-.4486-.9993-.9997s.4482-.9993.9993-.9993c.5511 0 .9993.4482.9993.9993.0004.5511-.4482.9997-.9993.9997m-11.046 0c-.5511 0-.9993-.4486-.9993-.9997s.4482-.9993.9993-.9993c.5511 0 .9993.4482.9993.9993 0 .5511-.4482.9997-.9993.9997m11.4045-6.02l1.9973-3.4592a.416.416 0 00-.1521-.5676.416.416 0 00-.5676.1521l-2.0223 3.503C15.5902 8.2439 13.8533 7.8508 12 7.8508s-3.5902.3931-5.1367 1.0989L4.841 5.4467a.4161.4161 0 00-.5677-.1521.4157.4157 0 00-.1521.5676l1.9973 3.4592C2.6889 11.1867.3432 14.6589 0 18.761h24c-.3432-4.1021-2.6889-7.5743-6.1185-9.4396"/></svg>'
APPLE = '<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M12.152 6.896c-.948 0-2.415-1.078-3.96-1.04-2.04.027-3.91 1.183-4.961 3.014-2.117 3.675-.546 9.103 1.519 12.09 1.013 1.454 2.208 3.09 3.792 3.039 1.52-.065 2.09-.987 3.935-.987 1.831 0 2.35.987 3.96.948 1.637-.026 2.676-1.48 3.676-2.948 1.156-1.688 1.636-3.325 1.662-3.415-.039-.013-3.182-1.221-3.22-4.857-.026-3.04 2.48-4.494 2.597-4.559-1.429-2.09-3.623-2.324-4.39-2.376-2-.156-3.675 1.09-4.61 1.09zM15.53 3.83c.843-1.012 1.4-2.427 1.245-3.83-1.207.052-2.662.805-3.532 1.818-.78.896-1.454 2.338-1.273 3.714 1.338.104 2.715-.688 3.559-1.701"/></svg>'

CSS = '''/* acceso-descargas: botones Android e iPhone en la pagina de entrada */
#access .acceso-apps{margin:22px 0 4px;padding-top:18px;border-top:1px solid var(--e-linea)}
#access .acceso-apps-t{margin:0 0 12px;font-weight:700;text-align:center;color:var(--e-texto) !important}
#access .acceso-apps-fila{display:grid;grid-template-columns:1fr 1fr;gap:10px}
#access a.acceso-app{display:flex;align-items:center;justify-content:center;gap:10px;padding:12px 14px;border-radius:18px;background:var(--e-azul-suave);border:1px solid var(--e-linea);color:var(--e-texto) !important;text-decoration:none;font-weight:700;line-height:1.15;text-align:left}
#access a.acceso-app svg{width:26px;height:26px;flex:none;fill:currentColor}
#access a.acceso-app span{display:block}
#access a.acceso-app small{display:block;font-weight:600;color:var(--e-azul-link) !important}
@media (max-width:420px){#access .acceso-apps-fila{grid-template-columns:1fr}}
'''
cambio('estilo de los botones de descarga',
 '@media (min-width:1280px) and (max-width:1699px){\n  nav.bottom-tabs{left:max(300px, calc(50vw - 300px)) !important;transform:none !important}\n}\n    </style>',
 '@media (min-width:1280px) and (max-width:1699px){\n  nav.bottom-tabs{left:max(300px, calc(50vw - 300px)) !important;transform:none !important}\n}\n' + CSS + '    </style>')
BLOQUE = ('<div class="acceso-apps">\n'
 '          <p class="acceso-apps-t">&#191;Todav&#237;a no ten&#233;s la app?</p>\n'
 '          <div class="acceso-apps-fila">\n'
 '            <a class="acceso-app" href="/descargar">' + ANDROID + '<span>Android<small>Descargar</small></span></a>\n'
 '            <a class="acceso-app" href="' + LINK + '">' + APPLE + '<span>iPhone<small>Descargar</small></span></a>\n'
 '          </div>\n'
 '        </div>\n        ')
cambio('botones Android e iPhone en la pagina de entrada',
 '<section id="passkey-setup" class="hidden">',
 BLOQUE + '<section id="passkey-setup" class="hidden">')

cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-login-descargas-panel.ps1 - Ojo Guard MS: botones "Android" e "iPhone" (Descargar) en la pagina de entrada de https://ojoguard.app, la que pide el codigo.
# Luciano (27/10/2026): "por que no le ponemos en la pagina de la consola con el icono de Android, icono de Apple y descargar" - "donde se entra con el codigo, porque es la primera que uno ve".
# Android abre https://ojoguard.app/descargar; iPhone abre el enlace publico de TestFlight. Cambia SOLO src\\panel-index.html (respaldo .bak-login-descargas). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\panel-index.html"))) { Mal "No encuentro src\\panel-index.html en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-index.html")).texto 'acceso-apps') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-raiz', '.bak-login-descargas')
cola = re.sub(r'Ok "LISTO: el panel se abre en.*"\n', 'Ok "LISTO: la pagina de entrada de ojoguard.app ya tiene los botones de Android e iPhone."\n', cola)
assert 'bak-raiz' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
open(R + 'aplicar-login-descargas-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
# copia del resultado para probar en navegador
out = fx
for _, _, v, n in filas: out = out.replace(v, n)
open('/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/index-prueba.html', 'w', encoding='utf-8').write(out)
print('ok', len(total), len(filas))
