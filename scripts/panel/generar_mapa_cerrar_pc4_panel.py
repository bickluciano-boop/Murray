# Genera scripts/aplicar-mapa-cerrar-pc4-panel.ps1: con la tarjeta escondida el texto "N paradas · X km" del dia sigue actualizandose (antes quedaba congelado con el ultimo valor).
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"

A1 = '  if (!elegido || (estado.tarjetaOculta && !EN_APP)) { tarjeta.classList.add("hidden"); return; }'
B1 = ('  if (!elegido || (estado.tarjetaOculta && !EN_APP)) {\n'
      '    tarjeta.classList.add("hidden");\n'
      '    // Con la tarjeta escondida el texto "N paradas · X km" del dia se calcula igual (esta cuenta vivia solo dentro de la tarjeta y quedaba congelada con el ultimo dia visto).\n'
      '    if (elegido && estado.rango === "dia") { const delDia = puntosDelRango(); textoDia(delDia, paradas(delDia)); }\n'
      '    return;\n'
      '  }')
filas = [('src\\panel-mapa.txt', 'mapa: el texto de paradas del dia con la tarjeta escondida', A1, B1)]
cambios = "$cambios = @(\n" + ',\n'.join(("    ,@(%s, %s, %s, %s)" if len(filas) == 1 else "    @(%s, %s, %s, %s)") % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-mapa-cerrar-pc4-panel.ps1 - Ojo Guard MS: con la tarjeta escondida, el texto "N paradas · X km" de "Un dia" se sigue actualizando al cambiar de dia.
# Luciano (03/11/2026, fotos): cambiaba el dia (01/11, 31/10, 30/10) y siempre decia "4 paradas · 1,3 km". Causa: el texto se calculaba dentro de la parte de la tarjeta de dibujar(); con la tarjeta escondida (parche 3) ese tramo se salteaba y el texto quedaba con el valor de hoy. Ahora se calcula tambien con la tarjeta escondida. Si un dia no tiene recorrido va a decir "Sin recorrido ese dia".
# Requiere los parches aplicar-mapa-cerrar-pc-panel.ps1, pc2 y pc3 (y "Otro dia"). Cambia SOLO src\\panel-mapa.txt (respaldo .bak-cerrarpc4). Va en la carpeta del PANEL (la que tiene wrangler.toml). No necesita build. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\panel-mapa.txt"))) { Mal "No encuentro src\\panel-mapa.txt en esta carpeta."; return }
$mapaTexto = (Leer (Join-Path $raiz "src\\panel-mapa.txt")).texto
if ((Contar $mapaTexto 'tarjetaOculta') -eq 0) { Mal "Falta aplicar antes aplicar-mapa-cerrar-pc3-panel.ps1."; return }
if ((Contar $mapaTexto 'function textoDia(') -ne 1 -or (Contar $mapaTexto 'function puntosDelRango(') -ne 1) { Mal "Falta aplicar antes el selector Otro dia (aplicar-mapa-otro-dia-panel.ps1)."; return }
if ((Contar $mapaTexto 'textoDia(delDia, paradas(delDia))') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-cerrarpc4')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: el texto de paradas del dia se actualiza con la tarjeta escondida (recarga la pagina con Ctrl+F5)."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›✓']
assert not bad, set(bad)
open(R + 'aplicar-mapa-cerrar-pc4-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
t = open(S + 'panel-mapa-cerrar3.txt', encoding='utf-8').read()
for f in filas:
    assert t.count(f[2]) == 1, (f[1], t.count(f[2]))
    t = t.replace(f[2], f[3])
# la copia no tiene "Otro dia": se le agregan funciones vacias solo para probar la guarda del instalador
t += '\nfunction textoDia(p, l) {}\nfunction puntosDelRango() { return []; }\n'
open(S + 'panel-mapa-cerrar4.txt', 'w', encoding='utf-8').write(t)
base = open(S + 'panel-mapa-cerrar3.txt', encoding='utf-8').read() + '\nfunction textoDia(p, l) {}\nfunction puntosDelRango() { return []; }\n'
open(S + 'panel-mapa-cerrar3-conotrodia.txt', 'w', encoding='utf-8').write(base)
print('ok', len(total))
