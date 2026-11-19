# Genera scripts/aplicar-tarjeta-calendario-panel.ps1 (panel, pestana MAPA: src\panel-mapa.txt). Solo estilo.
# Luciano (19/11/2026): "volvio a pasar que la tarjeta tapa el calendario; no puedo ver busquedas por dia".
# Causa: el selector de dia (.ogm-dia) esta fijo en top:72px y mide ~50 px (72 a 122 px); la tarjeta del equipo (.ogm-tarjeta) esta anclada abajo (bottom:104px) con max-height: calc(100% - 190px), asi que cuando tiene mucho contenido
# (evidencia, botones) su borde de arriba llega a 86 px del borde de arriba del mapa y tapa el calendario (z-index 4 contra 3). Ahora, en pantallas de computadora (>= 900 px), la tarjeta deja libre esa franja: max-height: calc(100% - 240px);
# la tarjeta ya tiene scroll propio, asi que no pierde nada. El estilo se agrega DENTRO del script del mapa (como el del selector de dia), que se recarga solo con cada version del panel: no depende del cache del archivo .css.
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
F = 'src\\panel-mapa.txt'
A_A = '<style id="ogm-dia-css">'
A_B = '<style id="ogm-tarjeta-css">@media (min-width:900px){#og-mapa .ogm-tarjeta{box-sizing:border-box;max-height:calc(100% - 240px)}}</style>\n      ' + A_A
# la etiqueta del selector de dia la dejan aplicar-mapa-otro-dia-panel.ps1 y aplicar-mapa-otro-dia-compacto-panel.ps1
for nombre in ('aplicar-mapa-otro-dia-panel.ps1', 'aplicar-mapa-otro-dia-compacto-panel.ps1'):
    assert open(R + nombre, encoding='utf-8-sig').read().count(A_A) >= 1, nombre
filas = [(F, 'tarjeta: deja libre la franja del selector de dia en computadora', A_A, A_B)]
def cambios_ps(fs):
    # Con UNA sola fila, PowerShell aplana @(@(...)) y $c[0] pasa a ser la primera letra: hay que anteponer una coma (,@(...)).
    pref = "    ," if len(fs) == 1 else "    "
    return "$cambios = @(\n" + ',\n'.join(pref + "@(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in fs) + "\n)\n"
i0 = tpl.index('$ErrorActionPreference'); j0 = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-tarjetacal')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
MENSAJE = 'LISTO: en el Mapa, la tarjeta del equipo ya no tapa el calendario de "Un dia" en la computadora.'
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "%s"\n' % MENSAJE, cola)
assert MENSAJE in cola
cabeza = '''# aplicar-tarjeta-calendario-panel.ps1 - Ojo Guard MS (panel, pestana MAPA): la tarjeta del equipo ya no tapa el calendario / selector de "Un dia" en la computadora.
# Luciano (19/11/2026): "volvio a pasar que la tarjeta tapa el calendario; no puedo ver busquedas por dia". En pantallas de 900 px o mas, la tarjeta deja libre la franja del selector (max-height: calc(100% - 240px)); tiene scroll propio.
# SOLO estilo, dentro del script del mapa (src\\panel-mapa.txt, respaldo .bak-tarjetacal). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
'''
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\panel-mapa.txt"))) { Mal "No encuentro src\\panel-mapa.txt en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-mapa.txt")).texto 'ogm-tarjeta-css') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-mapa.txt")).texto 'ogm-dia-css') -eq 0) { Mal "Falta el selector de Un dia (aplicar-mapa-otro-dia-panel.ps1). No toco nada."; return }
'''
total = cabeza + tpl[i0:j0] + guardas + cambios_ps(filas) + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕‹›']
assert not bad, set(bad)
open(R + 'aplicar-tarjeta-calendario-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
