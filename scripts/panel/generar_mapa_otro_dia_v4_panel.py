# Genera scripts/aplicar-mapa-otro-dia-v4-panel.ps1: los cuatro botones de arriba del mapa (En vivo, Hoy, 7 dias, Un dia) entran enteros en el Android (con letra grande).
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
a1 = '#og-mapa .ogm-seg{max-width:calc(100% - 76px);overflow-x:auto;scrollbar-width:none}'
b1 = '#og-mapa .ogm-seg{max-width:calc(100% - 72px);overflow-x:auto;scrollbar-width:none}'
a2 = '#og-mapa .ogm-seg button{padding:7px 6px;font-size:.74rem;gap:4px;white-space:nowrap;flex:none}'
b2 = '#og-mapa .ogm-seg button{padding:7px 5px;font-size:.7rem;gap:3px;white-space:nowrap;flex:none}'
h1a = '<script type="module" src="/mapa-v1.js?v=7"></script>'
h1b = '<script type="module" src="/mapa-v1.js?v=8"></script>'
filas = [('src\\panel-mapa.txt', 'mapa: ancho de la fila de botones de arriba', a1, b1),
         ('src\\panel-mapa.txt', 'mapa: botones de arriba un poco mas chicos', a2, b2),
         ('src\\panel-index.html', 'recargar el mapa nuevo (v=8)', h1a, h1b)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-mapa-otro-dia-v4-panel.ps1 - Ojo Guard MS: los botones de arriba del mapa (En vivo, Hoy, 7 dias, Un dia) entran enteros en el Android.
# Motivo (31/10/2026, captura de Luciano): en el Android con letra grande el ultimo boton quedaba cortado ("Un di"). Se achican un poco la letra y el aire de los botones y se aprovecha mejor el ancho.
# Cambia SOLO el estilo en src\\panel-mapa.txt y src\\panel-index.html (v=8). Respaldo .bak-otrodia4. Va en la carpeta del PANEL. Sin build.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
foreach ($f in @("src\\panel-mapa.txt", "src\\panel-index.html")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\\panel-mapa.txt")).texto '.ogm-seg button{padding:7px 5px') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-index.html")).texto '/mapa-v1.js?v=7') -ne 1) { Mal "El mapa no esta en v=7 (falta aplicar primero aplicar-mapa-otro-dia-v3-panel.ps1). No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-otrodia4')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: los botones de arriba del mapa entran enteros. Cerra y abri la app (o recarga la pagina del mapa)."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›']
assert not bad, set(bad)
open(R + 'aplicar-mapa-otro-dia-v4-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
