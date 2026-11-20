# Genera scripts/aplicar-video-sin-sonido-panel.ps1 (panel, src\\panel-app.txt). Sin build de la app: solo se publica el panel.
# Luciano (20/11/2026): la presentacion de las pulseras (Configuracion > Equipos y pulseras > Ver presentacion) tiene musica que no le gusta: que arranque SIN volumen.
# El video sigue siendo el mismo (https://watch.ojoguard.app/...mp4) y el reproductor conserva sus controles: con el boton del parlante se le puede dar volumen. Cada vez que se abre arranca sin sonido.
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
F = 'src\\panel-app.txt'
V_A = 'videoModalPlayer.src = WATCH_PRESENTATION_VIDEO_URL;'
V_B = 'videoModalPlayer.muted = true; // Luciano (20/11/2026): la presentacion arranca SIN volumen (la musica no le gusta); con el parlante del reproductor se puede activar.\n  videoModalPlayer.src = WATCH_PRESENTATION_VIDEO_URL;'
filas = [(F, 'presentacion de las pulseras: arranca sin volumen', V_A, V_B)]
def cambios_ps(fs):
    # Con UNA sola fila, PowerShell aplana @(@(...)) y $c[0] pasa a ser la primera letra: hay que anteponer una coma (,@(...)).
    pref = "    ," if len(fs) == 1 else "    "
    return "$cambios = @(\n" + ',\n'.join(pref + "@(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in fs) + "\n)\n"
i0 = tpl.index('$ErrorActionPreference'); j0 = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-videosinsonido')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
DEPLOY = 'if ($LASTEXITCODE -ne 0) { Mal "No se pudo publicar el panel. Mandame esta pantalla."; return }\n'
assert cola.count(DEPLOY) == 1
MENSAJE = 'LISTO: la presentacion de las pulseras ahora arranca sin volumen (con el parlante del reproductor se le puede dar sonido).'
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "%s"\n' % MENSAJE, cola)
assert MENSAJE in cola
cabeza = '''# aplicar-video-sin-sonido-panel.ps1 - Ojo Guard MS (panel, src\\panel-app.txt): la presentacion de las pulseras (Configuracion > Equipos y pulseras > Ver presentacion) arranca SIN volumen.
# Luciano (20/11/2026): no le gusta la musica del video. El video no cambia; el reproductor conserva sus controles. Cambia src\\panel-app.txt (respaldo .bak-videosinsonido) y publica el panel. No hace falta build de la app. Va en la carpeta del PANEL (la que tiene wrangler.toml).
'''
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\panel-app.txt"))) { Mal "No encuentro src\\panel-app.txt en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-app.txt")).texto 'WATCH_PRESENTATION_VIDEO_URL') -eq 0) { Mal "No encuentro la presentacion de las pulseras en panel-app.txt. Mandame esta pantalla."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-app.txt")).texto 'videoModalPlayer.muted = true') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
total = cabeza + tpl[i0:j0] + guardas + cambios_ps(filas) + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕‹›']
assert not bad, set(bad)
open(R + 'aplicar-video-sin-sonido-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
open('/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/filas_video.json', 'w', encoding='utf-8').write(__import__('json').dumps(filas))
muestra = 'const WATCH_PRESENTATION_VIDEO_URL = "https://watch.ojoguard.app/ojo-guard-presentacion.mp4?v=3";\nfunction openWatchPresentation() {\n  videoModalPlayer.src = WATCH_PRESENTATION_VIDEO_URL;\n  videoModal.hidden = false;\n}\n'
assert muestra.count(V_A) == 1, muestra.count(V_A)
open('/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/muestra_video.js', 'w', encoding='utf-8').write(muestra.replace(V_A, V_B))
print('ok', len(total))
