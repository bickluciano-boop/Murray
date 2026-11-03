# Genera scripts/aplicar-mapa-cerrar-pc3-panel.ps1: en la compu la X de la tarjeta solo ESCONDE la tarjeta; la persona sigue elegida (recorrido, dia y paradas).
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"

A1 = '  if (!elegido) { tarjeta.classList.add("hidden"); return; }'
B1 = '  if (!elegido || (estado.tarjetaOculta && !EN_APP)) { tarjeta.classList.add("hidden"); return; }'
A2 = 'function soltar() {\n  if (estado.vivo) void detenerVivo();\n  // En la compu, si la persona cierra la tarjeta a mano'
B2 = ('function soltar() {\n'
      '  // En la compu la X, Esc o un clic en el mapa vacio solo ESCONDEN la tarjeta: la persona sigue elegida (su recorrido, el dia y las paradas siguen en el mapa) y\n'
      '  // la tarjeta vuelve al tocar su pin o su fila de la lista. Si se la deselecciona, el selector de dia no sabe de quien traer el recorrido.\n'
      '  if (!EN_APP) { estado.tarjetaOculta = true; return dibujar(); }\n'
      '  if (estado.vivo) void detenerVivo();\n'
      '  // En la compu, si la persona cierra la tarjeta a mano')
A3 = '  estado.cerradoAMano = false;\n  if (estado.elegido !== id) {'
B3 = '  estado.cerradoAMano = false;\n  estado.tarjetaOculta = false;\n  if (estado.elegido !== id) {'
filas = [('src\\panel-mapa.txt', 'mapa: esconder la tarjeta sin deseleccionar (dibujo)', A1, B1),
         ('src\\panel-mapa.txt', 'mapa: la X en la compu solo esconde la tarjeta', A2, B2),
         ('src\\panel-mapa.txt', 'mapa: elegir una persona vuelve a mostrar la tarjeta', A3, B3)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-mapa-cerrar-pc3-panel.ps1 - Ojo Guard MS: en la compu la X (o Esc, o un clic en el mapa vacio) ESCONDE la tarjeta pero la persona sigue elegida.
# Luciano (03/11/2026): "la X se va, pero no sabe, vas cambiando el dia pero no sabe de que persona". Con la persona deseleccionada el selector de dia (Hoy, 7 dias, Un dia) no tenia a quien traerle el recorrido. Ahora la tarjeta se esconde y el recorrido, el dia y las paradas de esa persona siguen en el mapa; la tarjeta vuelve al tocar su pin o su fila de la lista.
# Requiere aplicar-mapa-cerrar-pc-panel.ps1 y aplicar-mapa-cerrar-pc2-panel.ps1. Cambia SOLO src\\panel-mapa.txt (respaldo .bak-cerrarpc3). Va en la carpeta del PANEL (la que tiene wrangler.toml). No necesita build. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\panel-mapa.txt"))) { Mal "No encuentro src\\panel-mapa.txt en esta carpeta."; return }
$mapaTexto = (Leer (Join-Path $raiz "src\\panel-mapa.txt")).texto
if ((Contar $mapaTexto 'cerradoAMano') -eq 0) { Mal "Falta aplicar antes aplicar-mapa-cerrar-pc-panel.ps1 y aplicar-mapa-cerrar-pc2-panel.ps1."; return }
if ((Contar $mapaTexto 'tarjetaOculta') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-cerrarpc3')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: la X esconde la tarjeta y la persona sigue elegida (recarga la pagina con Ctrl+F5)."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›✓']
assert not bad, set(bad)
open(R + 'aplicar-mapa-cerrar-pc3-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
t = open(S + 'panel-mapa-cerrar2.txt', encoding='utf-8').read()
for f in filas:
    assert t.count(f[2]) == 1, (f[1], t.count(f[2]))
    t = t.replace(f[2], f[3])
open(S + 'panel-mapa-cerrar3.txt', 'w', encoding='utf-8').write(t)
print('ok', len(total))
