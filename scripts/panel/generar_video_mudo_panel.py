# Genera scripts/aplicar-video-mudo-panel.ps1 (panel, src\\panel-app.txt + src\\panel-index.html). Sin build de la app: solo se publica el panel. Requiere aplicar-video-sin-sonido-panel.ps1.
# Luciano (20/11/2026): "si apretas la campanita suena": el video de la presentacion de las pulseras queda SIEMPRE sin sonido. Se saca el boton del parlante del reproductor (Chrome/Edge/Safari) y, si de todos modos se activa el sonido (Firefox, teclado), se vuelve a silenciar solo.
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
F = 'src\\panel-app.txt'
F2 = 'src\\panel-index.html'
V_A = 'videoModalPlayer.src = WATCH_PRESENTATION_VIDEO_URL;'
V_B = 'videoModalPlayer.onvolumechange = () => { if (!videoModalPlayer.muted) videoModalPlayer.muted = true; }; // siempre mudo: si alguien activa el sonido, se vuelve a silenciar\n  videoModalPlayer.src = WATCH_PRESENTATION_VIDEO_URL;'
H_A = '<video id="video-modal-player" playsinline controls></video>'
H_B = '<style>#video-modal-player::-webkit-media-controls-mute-button,#video-modal-player::-webkit-media-controls-volume-slider,#video-modal-player::-webkit-media-controls-volume-control-container{display:none!important}</style><video id="video-modal-player" playsinline controls muted></video>'
filas = [(F, 'presentacion de las pulseras: siempre sin sonido (se vuelve a silenciar si lo activan)', V_A, V_B),
         (F2, 'presentacion de las pulseras: sin boton de volumen', H_A, H_B)]
def cambios_ps(fs):
    # Con UNA sola fila, PowerShell aplana @(@(...)) y $c[0] pasa a ser la primera letra: hay que anteponer una coma (,@(...)).
    pref = "    ," if len(fs) == 1 else "    "
    return "$cambios = @(\n" + ',\n'.join(pref + "@(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in fs) + "\n)\n"
i0 = tpl.index('$ErrorActionPreference'); j0 = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-videomudo')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
DEPLOY = 'if ($LASTEXITCODE -ne 0) { Mal "No se pudo publicar el panel. Mandame esta pantalla."; return }\n'
assert cola.count(DEPLOY) == 1
MENSAJE = 'LISTO: la presentacion de las pulseras queda siempre sin sonido (sin boton de volumen).'
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "%s"\n' % MENSAJE, cola)
assert MENSAJE in cola
cabeza = '''# aplicar-video-mudo-panel.ps1 - Ojo Guard MS (panel, src\\panel-app.txt y src\\panel-index.html): la presentacion de las pulseras queda SIEMPRE sin sonido.
# Luciano (20/11/2026): "si apretas la campanita suena". Se saca el boton del parlante del reproductor y, si igual se activa el sonido, se silencia solo. El video no cambia; play, pausa y pantalla completa siguen. Requiere aplicar-video-sin-sonido-panel.ps1. Respaldo .bak-videomudo. Publica el panel (sin build de la app). Va en la carpeta del PANEL (la que tiene wrangler.toml).
'''
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
foreach ($f in @("src\\panel-app.txt", "src\\panel-index.html")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\\panel-app.txt")).texto 'videoModalPlayer.muted = true') -eq 0) { Mal "Falta aplicar primero aplicar-video-sin-sonido-panel.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-app.txt")).texto 'videoModalPlayer.onvolumechange') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
total = cabeza + tpl[i0:j0] + guardas + cambios_ps(filas) + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕‹›']
assert not bad, set(bad)
open(R + 'aplicar-video-mudo-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
open('/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/filas_video_mudo.json', 'w', encoding='utf-8').write(__import__('json').dumps(filas))
muestra = 'const WATCH_PRESENTATION_VIDEO_URL = "https://watch.ojoguard.app/ojo-guard-presentacion.mp4?v=3";\nfunction openWatchPresentation() {\n  videoModalPlayer.muted = true; // Luciano (20/11/2026): la presentacion arranca SIN volumen (la musica no le gusta); con el parlante del reproductor se puede activar.\n  videoModalPlayer.src = WATCH_PRESENTATION_VIDEO_URL;\n  videoModal.hidden = false;\n}\n'
html = '<div class="video-modal-canvas"><video id="video-modal-player" playsinline controls></video></div>'
assert muestra.count(V_A) == 1 and html.count(H_A) == 1
open('/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/muestra_video_mudo.js', 'w', encoding='utf-8').write(muestra.replace(V_A, V_B))
open('/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/muestra_video_mudo.html', 'w', encoding='utf-8').write(html.replace(H_A, H_B))
print('ok', len(total))
