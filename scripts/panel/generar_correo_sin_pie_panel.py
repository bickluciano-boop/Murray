# Genera scripts/aplicar-correo-sin-pie-panel.ps1: el mail "Tu cuenta de Ojo Guard se borro" ya no lleva el pie
# "Tu panel de Ojo Guard: ... Guarda este link por si perdes el acceso" (no tiene sentido si la cuenta ya no existe).
# Los demas mails siguen igual. Marca: el cuerpo trae data-og-sinpie y el envoltorio de la marca saltea el pie.
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
a1 = '${claroCorreo(html)}<div style="max-width:620px;margin:0 auto;padding:10px 12px 2px;'
b1 = '${claroCorreo(html)}${html.includes("data-og-sinpie") ? "" : `<div style="max-width:620px;margin:0 auto;padding:10px 12px 2px;'
a2 = 'Guard&#225; este link por si perd&#233;s el acceso</div></div>`;'
b2 = 'Guard&#225; este link por si perd&#233;s el acceso</div>`}</div>`;'
a3 = 'margin:auto;padding:24px\\"><h2>Tu cuenta de Ojo Guard se borr\\u00f3</h2>'
b3 = 'margin:auto;padding:24px\\" data-og-sinpie=\\"1\\"><h2>Tu cuenta de Ojo Guard se borr\\u00f3</h2>'
filas = [('src\\index.ts', 'mails: el pie se puede omitir', a1, b1), ('src\\index.ts', 'mails: cierre del pie omitible', a2, b2), ('src\\index.ts', 'mail de cuenta borrada sin pie', a3, b3)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-correo-sin-pie-panel.ps1 - Ojo Guard MS: el mail "Tu cuenta de Ojo Guard se borro" ya no trae el pie "Guarda este link por si perdes el acceso" (la cuenta ya no existe).
# Los demas mails no cambian. Cambia SOLO src\\index.ts (respaldo .bak-sinpie). Va en la carpeta del PANEL (la que tiene wrangler.toml). Requiere aplicar-borrar-cuenta-panel.ps1. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
$txt = (Leer (Join-Path $raiz "src\\index.ts")).texto
if ((Contar $txt 'data-og-sinpie') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $txt 'nativeAccountDelete') -eq 0) { Mal "Falta aplicar primero aplicar-borrar-cuenta-panel.ps1. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-sinpie')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: el mail de cuenta borrada sale sin el pie del link."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127]
assert not bad, set(bad)
open(R + 'aplicar-correo-sin-pie-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
