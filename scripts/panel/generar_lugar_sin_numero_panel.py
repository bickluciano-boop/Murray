# Genera scripts/aplicar-lugar-sin-numero-panel.ps1 (panel, src\panel-app.txt + 1 dato en D1). Requiere aplicar-lugar-guardado-panel.ps1.
# Luciano (19/11/2026): el panel decia "Ugarteche 3154" y su casa es Ugarteche 3157 (impar): el sistema de direcciones elige el numero mas cercano, que cruza de vereda con 10-20 m de error.
# 1) Dentro de un lugar guardado la tarjeta ya NO muestra el numero que adivina el sistema: dice solo "En <nombre del lugar>".
# 2) El lugar "Casa" pasa a llamarse "Casa · Ugarteche 3157" (UPDATE en D1, solo si todavia se llama exactamente "Casa"), asi la tarjeta dice "En Casa · Ugarteche 3157". Los avisos de llegada/salida de la familia usan ese nombre.
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
F = 'src\\panel-app.txt'
# el texto que dejo el instalador anterior se LEE de su generador (no se copia a mano)
g = open(R + 'panel/generar_lugar_guardado_panel.py', encoding='utf-8').read()
L_A = '  return `En ${mejor.nombre}${direccion ? ` · ${direccion}` : ""}`;'
assert g.count(L_A) == 1, g.count(L_A)
L_B = '  // Dentro de un lugar guardado no se muestra el numero de calle que adivina el sistema de direcciones (cruza de vereda con 10-20 m de error): el nombre del lugar ya dice donde es (puede llevar la direccion real, ej. "Casa · Ugarteche 3157").\n  return `En ${mejor.nombre}`;'
filas = [(F, 'lugar sin numero: dentro de un lugar guardado solo se muestra el nombre del lugar', L_A, L_B)]
def cambios_ps(fs):
    # Con UNA sola fila, PowerShell aplana @(@(...)) y $c[0] pasa a ser la primera letra: hay que anteponer una coma (,@(...)).
    pref = "    ," if len(fs) == 1 else "    "
    return "$cambios = @(\n" + ',\n'.join(pref + "@(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in fs) + "\n)\n"
i0 = tpl.index('$ErrorActionPreference'); j0 = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-lugarsinnumero')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
DEPLOY = 'if ($LASTEXITCODE -ne 0) { Mal "No se pudo publicar el panel. Mandame esta pantalla."; return }\n'
assert cola.count(DEPLOY) == 1
D1 = '''Write-Host ""
Ok "Panel publicado. Ahora le pongo la direccion al lugar Casa..."
& npx.cmd wrangler d1 execute ojo-guard-ms --remote --command "UPDATE family_places SET name='Casa ' || char(183) || ' Ugarteche 3157' WHERE id='lugar_28eb6810517f456c9214e44640662676' AND name='Casa'"
if ($LASTEXITCODE -ne 0) { Mal "El panel quedo publicado, pero no pude cambiar el nombre del lugar. Mandame esta pantalla."; return }
'''
cola = cola.replace(DEPLOY, DEPLOY + D1)
MENSAJE = 'LISTO: dentro de un lugar guardado el panel ya no muestra el numero que adivina el sistema; tu lugar se llama Casa - Ugarteche 3157.'
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "%s"\n' % MENSAJE, cola)
assert MENSAJE in cola
cabeza = '''# aplicar-lugar-sin-numero-panel.ps1 - Ojo Guard MS (panel, tarjeta de Dispositivos + 1 dato): dentro de un lugar guardado ya no se muestra el numero de calle que adivina el sistema; el lugar Casa pasa a llamarse "Casa · Ugarteche 3157".
# Luciano (19/11/2026): el panel decia Ugarteche 3154 y su casa es 3157 (vereda de enfrente). Requiere aplicar-lugar-guardado-panel.ps1. Cambia src\\panel-app.txt (respaldo .bak-lugarsinnumero) y el nombre del lugar en D1 (solo si todavia se llama "Casa"). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
'''
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\panel-app.txt"))) { Mal "No encuentro src\\panel-app.txt en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-app.txt")).texto 'function lugarYDireccion') -eq 0) { Mal "Falta aplicar primero aplicar-lugar-guardado-panel.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-app.txt")).texto 'return `En ${mejor.nombre}`;') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
total = cabeza + tpl[i0:j0] + guardas + cambios_ps(filas) + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕‹›']
assert not bad, set(bad)
open(R + 'aplicar-lugar-sin-numero-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
open('/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/filas_sin_numero.json', 'w', encoding='utf-8').write(__import__('json').dumps(filas))
print('ok', len(total))
