# Genera scripts/aplicar-guia-iphone-panel.ps1: agrega la guia de 4 pasos para iPhone (pagina de entrada, /descargar y /unirme) sobre los botones que ya estan instalados.
import re
R = '/home/user/Murray/scripts/'
U = '/root/.claude/uploads/459a989e-0585-521a-8ee1-3a385ef7024a/'
tpl = open(R + 'aplicar-raiz-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
LINK = 'https://testflight.apple.com/join/QcWAsHkG'
fi = open(U + '61ee18a5-index.ts', encoding='utf-8').read().replace('\r\n', '\n')
fi = fi.replace('const APK_ESTILO = `<style>', 'const URL_TESTFLIGHT = "%s";\nconst APK_ESTILO = `<style>' % LINK, 1)
fi = fi.replace('<p class="suave">iPhone: esta descarga es solo para Android. En iPhone la app se actualiza desde la App Store o TestFlight.</p>${huella}`;',
 '<div class="tarjeta"><h2>En iPhone</h2><p>Se instala con TestFlight, la app de Apple para probar versiones nuevas. Si no la ten&eacute;s, el enlace te lleva a bajarla.</p><p><a class="boton" href="${URL_TESTFLIGHT}">Instalar en iPhone</a></p></div>${huella}`;', 1)
fi = fi.replace('<p class="suave">Si todav&iacute;a no la ten&eacute;s, en Android la baj&aacute;s desde <a href="/descargar" style="color:var(--azul-link)">ojoguard.app/descargar</a>.</p></main></body></html>`;',
 '<p class="suave">Si todav&iacute;a no la ten&eacute;s, en Android la baj&aacute;s desde <a href="/descargar" style="color:var(--azul-link)">ojoguard.app/descargar</a>.</p>\n<div class="tarjeta"><h2>&iquest;Ten&eacute;s iPhone?</h2><p>Se instala con TestFlight, la app de Apple para probar versiones nuevas.</p><p><a class="boton" href="${URL_TESTFLIGHT}">Instalar en iPhone</a></p></div></main></body></html>`;', 1)
# panel-index.html tal como quedo con la primera version del instalador de botones (la que ya se aplico).
fh = open(U + '3347fd7c-panel-index-actual.html', encoding='utf-8').read().replace('\r\n', '\n')
ANDROID_SVG = '<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M17.523 15.3414c-.5511 0-.9993-.4486-.9993-.9997s.4482-.9993.9993-.9993c.5511 0 .9993.4482.9993.9993.0004.5511-.4482.9997-.9993.9997m-11.046 0c-.5511 0-.9993-.4486-.9993-.9997s.4482-.9993.9993-.9993c.5511 0 .9993.4482.9993.9993 0 .5511-.4482.9997-.9993.9997m11.4045-6.02l1.9973-3.4592a.416.416 0 00-.1521-.5676.416.416 0 00-.5676.1521l-2.0223 3.503C15.5902 8.2439 13.8533 7.8508 12 7.8508s-3.5902.3931-5.1367 1.0989L4.841 5.4467a.4161.4161 0 00-.5677-.1521.4157.4157 0 00-.1521.5676l1.9973 3.4592C2.6889 11.1867.3432 14.6589 0 18.761h24c-.3432-4.1021-2.6889-7.5743-6.1185-9.4396"/></svg>'
APPLE_SVG = '<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M12.152 6.896c-.948 0-2.415-1.078-3.96-1.04-2.04.027-3.91 1.183-4.961 3.014-2.117 3.675-.546 9.103 1.519 12.09 1.013 1.454 2.208 3.09 3.792 3.039 1.52-.065 2.09-.987 3.935-.987 1.831 0 2.35.987 3.96.948 1.637-.026 2.676-1.48 3.676-2.948 1.156-1.688 1.636-3.325 1.662-3.415-.039-.013-3.182-1.221-3.22-4.857-.026-3.04 2.48-4.494 2.597-4.559-1.429-2.09-3.623-2.324-4.39-2.376-2-.156-3.675 1.09-4.61 1.09zM15.53 3.83c.843-1.012 1.4-2.427 1.245-3.83-1.207.052-2.662.805-3.532 1.818-.78.896-1.454 2.338-1.273 3.714 1.338.104 2.715-.688 3.559-1.701"/></svg>'
CSS_VIEJO = """/* acceso-descargas: botones Android e iPhone en la pagina de entrada */
#access .acceso-apps{margin:22px 0 4px;padding-top:18px;border-top:1px solid var(--e-linea)}
#access .acceso-apps-t{margin:0 0 12px;font-weight:700;text-align:center;color:var(--e-texto) !important}
#access .acceso-apps-fila{display:grid;grid-template-columns:1fr 1fr;gap:10px}
#access a.acceso-app{display:flex;align-items:center;justify-content:center;gap:10px;padding:12px 14px;border-radius:18px;background:var(--e-azul-suave);border:1px solid var(--e-linea);color:var(--e-texto) !important;text-decoration:none;font-weight:700;line-height:1.15;text-align:left}
#access a.acceso-app svg{width:26px;height:26px;flex:none;fill:currentColor}
#access a.acceso-app span{display:block}
#access a.acceso-app small{display:block;font-weight:600;color:var(--e-azul-link) !important}
@media (max-width:420px){#access .acceso-apps-fila{grid-template-columns:1fr}}
"""
BLOQUE_VIEJO = ('<div class="acceso-apps">\n'
 '          <p class="acceso-apps-t">&#191;Todav&#237;a no ten&#233;s la app?</p>\n'
 '          <div class="acceso-apps-fila">\n'
 '            <a class="acceso-app" href="/descargar">' + ANDROID_SVG + '<span>Android<small>Descargar</small></span></a>\n'
 '            <a class="acceso-app" href="' + LINK + '">' + APPLE_SVG + '<span>iPhone<small>Descargar</small></span></a>\n'
 '          </div>\n'
 '        </div>\n        ')
fh = fh.replace('@media (min-width:1280px) and (max-width:1699px){\n  nav.bottom-tabs{left:max(300px, calc(50vw - 300px)) !important;transform:none !important}\n}\n    </style>',
 '@media (min-width:1280px) and (max-width:1699px){\n  nav.bottom-tabs{left:max(300px, calc(50vw - 300px)) !important;transform:none !important}\n}\n' + CSS_VIEJO + '    </style>', 1)
fh = fh.replace('<section id="passkey-setup" class="hidden">', BLOQUE_VIEJO + '<section id="passkey-setup" class="hidden">', 1)
filas = []
def cambio(archivo, fuente, rotulo, viejo, nuevo):
    assert fuente.count(viejo) == 1, (rotulo, fuente.count(viejo))
    filas.append((archivo, rotulo, viejo, nuevo))

def entidades(t):
    out = []
    for ch in t:
        out.append(ch if ord(ch) < 128 else '&#%d;' % ord(ch))
    return ''.join(out)

# Los 4 pasos, escritos para quien nunca uso TestFlight (la primera usuaria real se confundio justo ahi).
PASOS = [
 'Tocá <strong>Instalar en iPhone</strong>. Se abre la App Store con <strong>TestFlight</strong>, la app de Apple para probar versiones nuevas. Es normal: primero se instala esa.',
 'Tocá <strong>Obtener</strong> para instalar TestFlight y después volvé a tocar <strong>Instalar en iPhone</strong>.',
 'Aceptá los términos de TestFlight y tocá <strong>Instalar</strong> en la pantalla de Ojo Guard. Si el botón está gris, esperá unos segundos.',
 'Abrí <strong>Ojo Guard</strong>: es el ícono con un ojo dorado sobre fondo azul. Dejá TestFlight instalada: es la que te avisa cuando hay versiones nuevas.',
]
LISTA = '<ol style="margin:8px 0 14px;padding-left:22px;line-height:1.65">' + ''.join('<li>' + entidades(p) + '</li>' for p in PASOS) + '</ol>'
LISTA_LOGIN = '<ol>' + ''.join('<li>' + entidades(p) + '</li>' for p in PASOS) + '</ol>'


H = 'src\\panel-index.html'
CSS_GUIA = """#access .acceso-guia{margin-top:14px}
#access .acceso-guia ol{margin:0;padding-left:22px;line-height:1.65;color:var(--e-texto2)}
#access .acceso-guia li{margin-bottom:8px}
"""
cambio(H, fh, 'estilo de la guia de iPhone',
 '@media (max-width:420px){#access .acceso-apps-fila{grid-template-columns:1fr}}\n',
 CSS_GUIA + '@media (max-width:420px){#access .acceso-apps-fila{grid-template-columns:1fr}}\n')
cambio(H, fh, 'guia de iPhone en la pagina de entrada',
 '<span>iPhone<small>Descargar</small></span></a>\n          </div>\n        </div>\n        <section id="passkey-setup" class="hidden">',
 '<span>iPhone<small>Descargar</small></span></a>\n          </div>\n          <details class="acceso-guia"><summary>&#191;C&#243;mo se instala en iPhone?</summary>' + LISTA_LOGIN + '</details>\n        </div>\n        <section id="passkey-setup" class="hidden">')
I = 'src\\index.ts'
viejo_desc = '<div class="tarjeta"><h2>En iPhone</h2><p>Se instala con TestFlight, la app de Apple para probar versiones nuevas. Si no la ten&eacute;s, el enlace te lleva a bajarla.</p><p><a class="boton" href="${URL_TESTFLIGHT}">Instalar en iPhone</a></p></div>'
nuevo_desc = '<div class="tarjeta"><h2>En iPhone</h2><p>Se instala en 4 pasos con TestFlight, la app de Apple para probar versiones nuevas.</p>' + LISTA + '<p><a class="boton" href="${URL_TESTFLIGHT}">Instalar en iPhone</a></p></div>'
cambio(I, fi, 'pagina de descarga: guia de 4 pasos para iPhone', viejo_desc, nuevo_desc)
viejo_unir = '<div class="tarjeta"><h2>&iquest;Ten&eacute;s iPhone?</h2><p>Se instala con TestFlight, la app de Apple para probar versiones nuevas.</p><p><a class="boton" href="${URL_TESTFLIGHT}">Instalar en iPhone</a></p></div>'
nuevo_unir = '<div class="tarjeta"><h2>&iquest;Ten&eacute;s iPhone?</h2><p>Se instala en 4 pasos con TestFlight, la app de Apple para probar versiones nuevas.</p>' + LISTA + '<p><a class="boton" href="${URL_TESTFLIGHT}">Instalar en iPhone</a></p></div>'
cambio(I, fi, 'pagina de invitacion: guia de 4 pasos para iPhone', viejo_unir, nuevo_unir)

cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-guia-iphone-panel.ps1 - Ojo Guard MS: guia de 4 pasos para instalar en iPhone (TestFlight) en la pagina de entrada de https://ojoguard.app, en /descargar y en /unirme.
# 28/10/2026: la mama de Luciano (iPhone) se confundio con TestFlight ("se descarga este TestFlight, no se descarga el Ojo Guard"). Se monta sobre los botones de Android e iPhone que ya estan instalados.
# Cambia src\\panel-index.html y src\\index.ts (respaldo .bak-guia-iphone). Va en la carpeta del PANEL (la que tiene wrangler.toml). Requiere aplicar-testflight-panel.ps1 y los botones de la entrada. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
foreach ($f in @("src\\panel-index.html", "src\\index.ts")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\\panel-index.html")).texto 'acceso-guia') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-index.html")).texto 'acceso-apps') -eq 0) { Mal "Faltan los botones de la pagina de entrada. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'const URL_TESTFLIGHT') -eq 0) { Mal "Falta aplicar primero aplicar-testflight-panel.ps1. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-raiz', '.bak-guia-iphone')
cola = re.sub(r'Ok "LISTO: el panel se abre en.*"\n', 'Ok "LISTO: la pagina de entrada, la descarga y la invitacion ya tienen la guia de 4 pasos para iPhone."\n', cola)
assert 'bak-raiz' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
open(R + 'aplicar-guia-iphone-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total), len(filas))
