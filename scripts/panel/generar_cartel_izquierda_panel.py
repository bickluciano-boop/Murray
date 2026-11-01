# Genera scripts/aplicar-cartel-izquierda-panel.ps1: en el celular, el cartel del mapa queda a la izquierda de la columna de botones de la derecha (no se la pisa).
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
a1 = '/*v3*/#og-mapa .ogm-aviso{width:max-content;box-sizing:border-box;max-width:calc(100% - 24px)}'
b1 = '/*v3*/#og-mapa .ogm-aviso{width:max-content;box-sizing:border-box;max-width:calc(100% - 24px)}@media (max-width:899px){#og-mapa .ogm-aviso{left:12px;transform:none;max-width:calc(100% - 124px);text-align:left}}'
h1a = '<script type="module" src="/mapa-v1.js?v=15"></script>'
h1b = '<script type="module" src="/mapa-v1.js?v=16"></script>'
filas = [('src\\panel-mapa.txt', 'mapa: el cartel a la izquierda de los botones (celular)', a1, b1),
         ('src\\panel-index.html', 'recargar el mapa nuevo (v=16)', h1a, h1b)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-cartel-izquierda-panel.ps1 - Ojo Guard MS: en el celular, el cartel del mapa (por ejemplo "No podes ver el recorrido de Luli") queda a la izquierda de la columna de botones de la derecha.
# Motivo (01/11/2026, captura de Luciano en el iPhone): el cartel ya era corto pero la columna de botones de la derecha le pisaba el borde. Cambia SOLO el estilo en src\\panel-mapa.txt y src\\panel-index.html (v=16). Respaldo .bak-cartelizq. Va en la carpeta del PANEL. Sin build.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
foreach ($f in @("src\\panel-mapa.txt", "src\\panel-index.html")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\\panel-mapa.txt")).texto 'ogm-aviso{left:12px;transform:none') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-index.html")).texto '/mapa-v1.js?v=15') -ne 1) { Mal "El mapa no esta en v=15 (falta aplicar primero aplicar-motivo-corto-panel.ps1). No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-cartelizq')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: el cartel del mapa queda a la izquierda de los botones. Cerra y abri la app (o recarga la pagina del mapa)."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›✓']
assert not bad, set(bad)
open(R + 'aplicar-cartel-izquierda-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
