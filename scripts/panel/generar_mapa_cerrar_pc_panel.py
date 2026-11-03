# Genera scripts/aplicar-mapa-cerrar-pc-panel.ps1: en el panel de la compu la tarjeta del equipo/persona se puede cerrar (X, tecla Esc o un clic en el mapa vacio).
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"

A1 = '    </div>\n    <p class="ogm-direc">'
B1 = ('      <button type="button" class="ogm-cerrar-pc" data-accion="soltar" aria-label="Cerrar la tarjeta" title="Cerrar (Esc)" '
      'style="position:absolute;top:8px;right:10px;z-index:2;width:30px;height:30px;border-radius:50%;border:1px solid rgba(128,128,128,.45);background:rgba(128,128,128,.16);color:inherit;font-size:.9rem;line-height:1;cursor:pointer;display:grid;place-items:center">&#10005;</button>\n'
      + A1)
A2 = 'estado.proveedor.alTocarMapa(() => { if (esCelular()) plegar(true); });'
B2 = ('// En la compu la tarjeta se cierra con un clic en el mapa vacio o con Esc (en el celular el clic la pliega). El clic de un pin no la cierra: elegir() anota cuando se eligio.\n'
      '      estado.proveedor.alTocarMapa(() => {\n'
      '        if (esCelular()) return plegar(true);\n'
      '        if (!EN_APP && estado.elegido && !estado.dialogo && !estado.eligiendoLugar && Date.now() - (estado.ultimaEleccion || 0) > 400) soltar();\n'
      '      });\n'
      '      document.addEventListener("keydown", (evento) => {\n'
      '        if (evento.key === "Escape" && !EN_APP && estado.elegido && !estado.dialogo && !estado.eligiendoLugar) soltar();\n'
      '      });')
A3 = 'async function elegir(id, centrar) {\n  if (estado.elegido !== id) {'
B3 = 'async function elegir(id, centrar) {\n  estado.ultimaEleccion = Date.now();\n  if (estado.elegido !== id) {'
filas = [('src\\panel-mapa.txt', 'mapa: boton X para cerrar la tarjeta en la compu', A1, B1),
         ('src\\panel-mapa.txt', 'mapa: clic en el mapa vacio y Esc cierran la tarjeta', A2, B2),
         ('src\\panel-mapa.txt', 'mapa: anotar cuando se eligio un equipo', A3, B3)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-mapa-cerrar-pc-panel.ps1 - Ojo Guard MS: en el panel de la compu la tarjeta del equipo o la persona (la que abre un pin o una fila de la lista) se puede cerrar.
# Luciano (03/11/2026): "me quedo en esta pantalla y no tengo manera de salir; toco en el mapa y no se va, toco en la parte blanca y tampoco". Era cierto: la X de cerrar solo existia en la app; en la compu la tarjeta quedaba abierta para siempre (solo cambiaba al elegir otra).
# Ahora: una X arriba a la derecha de la tarjeta, la tecla Esc y un clic en el mapa vacio. Cerrar la tarjeta deja de seguir en vivo, igual que en la app. No se cierra mientras hay un cuadro abierto (aviso de lugar, invitacion) ni al elegir el punto de un aviso. La app no cambia.
# Cambia SOLO src\\panel-mapa.txt (respaldo .bak-cerrarpc). Va en la carpeta del PANEL (la que tiene wrangler.toml). No necesita build. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\panel-mapa.txt"))) { Mal "No encuentro src\\panel-mapa.txt en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-mapa.txt")).texto 'ogm-cerrar-pc') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-cerrarpc')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: la tarjeta del mapa ya se cierra con la X, con Esc o con un clic en el mapa vacio (recarga la pagina con Ctrl+F5)."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›✓']
assert not bad, set(bad)
open(R + 'aplicar-mapa-cerrar-pc-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
# copia ya cambiada para revisar la sintaxis
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
t = open(S + 'prueba_motivo/panel/src/panel-mapa.txt', encoding='utf-8').read()
for f in filas:
    assert t.count(f[2]) == 1, f[1]
    t = t.replace(f[2], f[3])
open(S + 'panel-mapa-cerrar.txt', 'w', encoding='utf-8').write(t)
print('ok', len(total))
