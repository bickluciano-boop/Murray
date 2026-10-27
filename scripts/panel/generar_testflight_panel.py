# Genera scripts/aplicar-testflight-panel.ps1: boton "Instalar en iPhone" (enlace publico de TestFlight) en ojoguard.app/descargar y en la pagina de invitacion /unirme.
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-raiz-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
LINK = 'https://testflight.apple.com/join/QcWAsHkG'
fx = open('/root/.claude/uploads/459a989e-0585-521a-8ee1-3a385ef7024a/61ee18a5-index.ts', encoding='utf-8').read().replace('\r\n', '\n')
filas = []
def cambio(rotulo, viejo, nuevo):
    assert fx.count(viejo) == 1, (rotulo, fx.count(viejo))
    filas.append(('src\\index.ts', rotulo, viejo, nuevo))

cambio('enlace de TestFlight (una sola vez)',
 'const APK_ESTILO = `<style>',
 'const URL_TESTFLIGHT = "%s";\nconst APK_ESTILO = `<style>' % LINK)
cambio('pagina de descarga: tarjeta para iPhone',
 '<p class="suave">iPhone: esta descarga es solo para Android. En iPhone la app se actualiza desde la App Store o TestFlight.</p>${huella}`;',
 '<div class="tarjeta"><h2>En iPhone</h2><p>Se instala con TestFlight, la app de Apple para probar versiones nuevas. Si no la ten&eacute;s, el enlace te lleva a bajarla.</p><p><a class="boton" href="${URL_TESTFLIGHT}">Instalar en iPhone</a></p></div>${huella}`;')
cambio('pagina de invitacion: tarjeta para iPhone',
 '<p class="suave">Si todav&iacute;a no la ten&eacute;s, en Android la baj&aacute;s desde <a href="/descargar" style="color:var(--azul-link)">ojoguard.app/descargar</a>.</p></main></body></html>`;',
 '<p class="suave">Si todav&iacute;a no la ten&eacute;s, en Android la baj&aacute;s desde <a href="/descargar" style="color:var(--azul-link)">ojoguard.app/descargar</a>.</p>\n<div class="tarjeta"><h2>&iquest;Ten&eacute;s iPhone?</h2><p>Se instala con TestFlight, la app de Apple para probar versiones nuevas.</p><p><a class="boton" href="${URL_TESTFLIGHT}">Instalar en iPhone</a></p></div></main></body></html>`;')

cambio('pagina de descarga: version sin parentesis dobles',
 'const version = info.version ? " (" + apkEscapar(info.version) + ")" : "";',
 'const version = info.version ? " " + apkEscapar(info.version) : "";')

cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-testflight-panel.ps1 - Ojo Guard MS: boton "Instalar en iPhone" (enlace publico de TestFlight) en https://ojoguard.app/descargar y en la pagina de invitacion /unirme.
# Luciano (27/10/2026): "lo de invitacion tambien podemos hacer para iPhone?". Apple aprobo la beta 0.9.1 (35 y 37) en el grupo externo FRIENDS&FAMILY y se creo el enlace publico (abierto, limite 10).
# Cambia SOLO src\\index.ts (respaldo .bak-testflight). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'const URL_TESTFLIGHT') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-raiz', '.bak-testflight')
cola = re.sub(r'Ok "LISTO: el panel se abre en.*"\n', 'Ok "LISTO: ojoguard.app/descargar y la pagina de invitacion ya tienen el boton Instalar en iPhone."\n', cola)
assert 'bak-raiz' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
open(R + 'aplicar-testflight-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total), len(filas))
