# Genera scripts/aplicar-mapa-ubicacion-cortada-panel.ps1: en el mapa del panel, una persona que corto su ubicacion con el ojo dice "Dejo de compartir su ubicacion" (antes aparecia simplemente sin ubicacion).
import re
R = '/home/user/Murray/scripts/'
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
A1 = '      pausado: Boolean(p.paused),\n'
B1 = A1 + '      // Cortada con el ojo (permisos): el servidor ya no manda la ubicacion; asi se dice por que no hay.\n      cortado: Boolean(p.locCut),\n'
A2 = '  if (equipo.pausado) return { clase: "off", texto: "Ubicación pausada" };\n'
B2 = A2 + '  if (equipo.cortado) return { clase: "off", texto: "Dejó de compartir su ubicación" };\n'
filas = [('src\\panel-mapa.txt', 'mapa: la persona trae si corto su ubicacion', A1, B1), ('src\\panel-mapa.txt', 'mapa: texto "Dejo de compartir su ubicacion"', A2, B2)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-mapa-ubicacion-cortada-panel.ps1 - Ojo Guard MS: en el mapa, quien corto su ubicacion con el ojo dice "Dejo de compartir su ubicacion".
# Luciano (09/11/2026): que el panel muestre como se identifica cada persona y por que no se ve su ubicacion. El servidor (aplicar-permisos-ojo-panel.ps1) ya manda locCut en cada persona.
# Requiere aplicar-permisos-ojo-panel.ps1. Cambia SOLO src\\panel-mapa.txt (respaldo .bak-ubicortada). Va en la carpeta del PANEL (la que tiene wrangler.toml). No necesita build. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\panel-mapa.txt"))) { Mal "No encuentro src\\panel-mapa.txt en esta carpeta."; return }
$mapaTexto = (Leer (Join-Path $raiz "src\\panel-mapa.txt")).texto
if ((Contar $mapaTexto 'equipo.cortado') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-ubicortada')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: el mapa dice cuando alguien dejo de compartir su ubicacion (recarga la pagina con Ctrl+F5)."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + tpl[i:j] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›✓']
assert not bad, set(bad)
open(R + 'aplicar-mapa-ubicacion-cortada-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
t = open(S + 'panel-mapa-cerrar4.txt', encoding='utf-8').read()
for f in filas:
    assert t.count(f[2]) == 1, (f[1], t.count(f[2]))
    t = t.replace(f[2], f[3])
open(S + 'panel-mapa-ubicortada.txt', 'w', encoding='utf-8').write(t)
print('ok', len(total))
