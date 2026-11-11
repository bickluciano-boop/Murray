# Genera scripts/aplicar-mapa-latido-panel.ps1: el mapa del panel (tambien el que va dentro de la app) trabaja menos y avisa que esta vivo.
#  1) El GPS de quien mira (cada segundo) redibujaba TODO el mapa sin parar: ahora solo si te moviste 25 m o pasaron 15 s.
#  2) Si un dibujo falla, la actualizacion automatica sigue (antes, un solo error la cortaba para siempre).
#  3) Latido: la pagina le avisa a la app cada 5 s que sigue viva. Con la app nueva, si deja de avisar (se cuelga), la app recarga el mapa sola.
import re
R = '/home/user/Murray/scripts/'
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
A1 = '  dibujar();\n  document.documentElement.classList.remove("abriendo");\n  if (!estado.encuadrado && conUbicacion.length) { encuadrarTodo(); estado.encuadrado = true; }\n'
B1 = ('  // Si un dibujo falla, la actualizacion automatica igual sigue (antes un solo error cortaba el reloj para siempre).\n'
      '  try { dibujar(); } catch (error) { console.error("dibujar", error); }\n'
      '  document.documentElement.classList.remove("abriendo");\n'
      '  try { if (!estado.encuadrado && conUbicacion.length) { encuadrarTodo(); estado.encuadrado = true; } } catch (error) { console.error("encuadrar", error); }\n')
A2 = '  if (seguido) estado.proveedor?.centrar(seguido);\n'
B2 = '  try { if (seguido) estado.proveedor?.centrar(seguido); } catch (error) { console.error("centrar", error); }\n'
A3 = '      if (!redibujoPendiente) redibujoPendiente = setTimeout(() => { redibujoPendiente = null; dibujar(); }, 800);\n'
B3 = ('      // El GPS avisa cada segundo: se redibuja solo si te moviste 25 m o pasaron 15 s (antes era sin parar y en celulares modestos trababa el mapa).\n'
      '      const antes = estado.yoDibujado;\n'
      '      const movio = !antes || Math.hypot((pos.coords.latitude - antes.lat) * 111_000, (pos.coords.longitude - antes.lng) * 111_000 * Math.cos((pos.coords.latitude * Math.PI) / 180)) > 25;\n'
      '      if (!redibujoPendiente && (movio || Date.now() - antes.en > 15_000)) {\n'
      '        redibujoPendiente = setTimeout(() => {\n'
      '          redibujoPendiente = null;\n'
      '          estado.yoDibujado = { lat: pos.coords.latitude, lng: pos.coords.longitude, en: Date.now() };\n'
      '          dibujar();\n'
      '        }, 800);\n'
      '      }\n')
A4 = "  activarArrastre(raiz);\n  activarAyudaTactil(raiz);\n"
B4 = A4 + ('  // Latido para la app: cada 5 s avisa que la pagina sigue viva. Si deja de llegar, la app vuelve a cargar el mapa sola.\n'
           '  if (EN_APP && !window.__ogmLatido && window.ReactNativeWebView?.postMessage) {\n'
           '    window.__ogmLatido = setInterval(() => { try { window.ReactNativeWebView.postMessage(JSON.stringify({ tipo: "latido" })); } catch { /* sigue */ } }, 5000);\n'
           '  }\n')
filas = [('src\\panel-mapa.txt', 'mapa: un dibujo que falla no corta la actualizacion', A1, B1),
         ('src\\panel-mapa.txt', 'mapa: centrar en el seguido sin cortar la actualizacion', A2, B2),
         ('src\\panel-mapa.txt', 'mapa: el GPS de quien mira ya no redibuja sin parar', A3, B3),
         ('src\\panel-mapa.txt', 'mapa: latido para la app', A4, B4)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-mapa-latido-panel.ps1 - Ojo Guard MS: el mapa (en el panel y dentro de la app) trabaja menos y avisa que esta vivo.
# Luciano (11/11/2026): "muchas veces el mapa se tilda y no podes hacer nada, ni zoom ni moverlo; tengo que tocar otro boton de abajo para que vuelva".
# 1) El GPS de quien mira redibujaba todo el mapa cada segundo: ahora solo si te moviste 25 m o pasaron 15 s. 2) Un dibujo que falla ya no corta la actualizacion. 3) Latido hacia la app (la app nueva recarga sola un mapa colgado; la vieja lo ignora).
# Cambia SOLO src\\panel-mapa.txt (respaldo .bak-mapa-latido). Va en la carpeta del PANEL (la que tiene wrangler.toml). No necesita build. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\panel-mapa.txt"))) { Mal "No encuentro src\\panel-mapa.txt en esta carpeta."; return }
$mapaTexto = (Leer (Join-Path $raiz "src\\panel-mapa.txt")).texto
if ((Contar $mapaTexto '__ogmLatido') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-mapa-latido')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: el mapa trabaja menos y avisa que esta vivo (recarga la pagina con Ctrl+F5)."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + tpl[i:j] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›✓']
assert not bad, set(bad)
open(R + 'aplicar-mapa-latido-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
m = open(S + 'panel-mapa-estado.txt', encoding='utf-8').read().replace('\r\n', '\n')
for a in (A1, A2, A3, A4):
    assert m.count(a) == 1, (m.count(a), a[:70])
for a, b in ((A1, B1), (A2, B2), (A3, B3), (A4, B4)):
    m = m.replace(a, b)
open(S + 'panel-mapa-latido.txt', 'w', encoding='utf-8').write(m)
print('ok', len(total))
