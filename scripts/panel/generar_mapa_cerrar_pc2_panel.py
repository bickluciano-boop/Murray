# Genera scripts/aplicar-mapa-cerrar-pc2-panel.ps1: si se cierra la tarjeta del mapa en la compu, el panel no vuelve a elegir solo a la primera persona.
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"

A1 = 'function soltar() {\n  if (estado.vivo) void detenerVivo();\n  estado.elegido = null;'
B1 = 'function soltar() {\n  if (estado.vivo) void detenerVivo();\n  // En la compu, si la persona cierra la tarjeta a mano, refrescar() no vuelve a elegir sola a la primera (eso era lo que hacia reaparecer a otra persona).\n  estado.cerradoAMano = !EN_APP;\n  estado.elegido = null;'
A2 = '  } else if (!estado.elegido || !estado.equipos.some((e) => e.id === estado.elegido)) {'
B2 = '  } else if (estado.cerradoAMano && !estado.elegido) {\n    // Tarjeta cerrada a mano en la compu: se queda cerrada hasta que se elija alguien.\n  } else if (!estado.elegido || !estado.equipos.some((e) => e.id === estado.elegido)) {'
A3 = '  estado.ultimaEleccion = Date.now();\n  if (estado.elegido !== id) {'
B3 = '  estado.ultimaEleccion = Date.now();\n  estado.cerradoAMano = false;\n  if (estado.elegido !== id) {'
filas = [('src\\panel-mapa.txt', 'mapa: cerrar la tarjeta a mano en la compu', A1, B1),
         ('src\\panel-mapa.txt', 'mapa: no elegir sola a la primera persona si se cerro a mano', A2, B2),
         ('src\\panel-mapa.txt', 'mapa: elegir una persona vuelve a abrir la tarjeta', A3, B3)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-mapa-cerrar-pc2-panel.ps1 - Ojo Guard MS: arregla el cierre de la tarjeta del mapa en la compu (complemento de aplicar-mapa-cerrar-pc-panel.ps1).
# Luciano (03/11/2026): "si pongo la X veo lo de atras, pero cuando lo toco pasa a ser Lucho; no es mas mi papa". Causa: en la compu el panel siempre tiene a alguien elegido y refrescar() (cada pocos segundos) elige solo a la primera persona con ubicacion cuando no hay nadie; la X dejaba "nadie" y el refresco abria otra vez la tarjeta de Lucho.
# Ahora: si la tarjeta se cierra a mano (X, Esc o clic en el mapa vacio) se queda cerrada hasta que se elige una persona o un equipo (un pin o la lista). Requiere aplicar-mapa-cerrar-pc-panel.ps1.
# Cambia SOLO src\\panel-mapa.txt (respaldo .bak-cerrarpc2). Va en la carpeta del PANEL (la que tiene wrangler.toml). No necesita build. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\panel-mapa.txt"))) { Mal "No encuentro src\\panel-mapa.txt en esta carpeta."; return }
$mapaTexto = (Leer (Join-Path $raiz "src\\panel-mapa.txt")).texto
if ((Contar $mapaTexto 'ogm-cerrar-pc') -eq 0) { Mal "Falta aplicar antes aplicar-mapa-cerrar-pc-panel.ps1."; return }
if ((Contar $mapaTexto 'cerradoAMano') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-cerrarpc2')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: la tarjeta cerrada a mano ya no vuelve a abrirse sola (recarga la pagina con Ctrl+F5)."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›✓']
assert not bad, set(bad)
open(R + 'aplicar-mapa-cerrar-pc2-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
t = open(S + 'panel-mapa-cerrar.txt', encoding='utf-8').read()
for f in filas:
    assert t.count(f[2]) == 1, (f[1], t.count(f[2]))
    t = t.replace(f[2], f[3])
open(S + 'panel-mapa-cerrar2.txt', 'w', encoding='utf-8').write(t)
print('ok', len(total))
