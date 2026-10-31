# Genera scripts/aplicar-mapa-otro-dia-v5-panel.ps1: los botones de arriba del mapa y la barra del dia se corren un poco a la izquierda en el celular, para que "Un dia" no toque la columna de botones de la derecha.
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
a1 = '#og-mapa .ogm-seg{max-width:calc(100% - 72px);overflow-x:auto;scrollbar-width:none}'
b1 = '#og-mapa .ogm-seg{left:6px;padding:3px;max-width:calc(100% - 66px);overflow-x:auto;scrollbar-width:none}'
a2 = '#og-mapa .ogm-dia{top:calc(max(12px, env(safe-area-inset-top)) + 52px);left:12px;max-width:calc(100% - 112px)}'
b2 = '#og-mapa .ogm-dia{top:calc(max(12px, env(safe-area-inset-top)) + 50px);left:6px;max-width:calc(100% - 106px)}'
h1a = '<script type="module" src="/mapa-v1.js?v=8"></script>'
h1b = '<script type="module" src="/mapa-v1.js?v=9"></script>'
filas = [('src\\panel-mapa.txt', 'mapa: botones de arriba un poco a la izquierda', a1, b1),
         ('src\\panel-mapa.txt', 'mapa: barra del dia un poco a la izquierda', a2, b2),
         ('src\\panel-index.html', 'recargar el mapa nuevo (v=9)', h1a, h1b)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-mapa-otro-dia-v5-panel.ps1 - Ojo Guard MS: los botones de arriba del mapa y la barra del dia se corren un poco a la izquierda en el celular.
# Motivo (31/10/2026, captura de Luciano en el Android): "Un dia" se leia entero pero quedaba pegado a la columna de botones de la derecha ("muy poquito a la izquierda y ya estamos").
# Cambia SOLO el estilo en src\\panel-mapa.txt y src\\panel-index.html (v=9). Respaldo .bak-otrodia5. Va en la carpeta del PANEL. Sin build.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
foreach ($f in @("src\\panel-mapa.txt", "src\\panel-index.html")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\\panel-mapa.txt")).texto '.ogm-seg{left:6px;padding:3px') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-index.html")).texto '/mapa-v1.js?v=8') -ne 1) { Mal "El mapa no esta en v=8 (falta aplicar primero aplicar-mapa-otro-dia-v4-panel.ps1). No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-otrodia5')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: los botones de arriba del mapa quedan un poco mas a la izquierda. Cerra y abri la app (o recarga la pagina del mapa)."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›']
assert not bad, set(bad)
open(R + 'aplicar-mapa-otro-dia-v5-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
