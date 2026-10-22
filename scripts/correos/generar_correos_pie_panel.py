# Genera scripts/aplicar-correos-pie-panel.ps1: arregla dos cosas del mail nuevo para quien ya aplico la primera version (commit fd9ba5d):
#  - el titulo de la franja azul pasa debajo del logo (en el celular quedaba apretado en 4 renglones),
#  - el pie de todos los mails muestra el link del panel (ms.ojoguard.app) para que no se pierda.
import re, subprocess
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
viejo_ts = subprocess.check_output(['git', '-C', R, 'show', 'fd9ba5da8f04132212ab934ed2dd8ddb51af7c60:scripts/correos/correos-marca.ts']).decode()
nuevo_ts = open(R + 'correos/correos-marca.ts', encoding='utf-8').read()
cortar = lambda t: t[t.index('  const resumen = titulo || equipo'):]
A = cortar(viejo_ts).rstrip('\n')
N = cortar(nuevo_ts).rstrip('\n')
assert A != N and A.endswith('}') and N.endswith('}')
cambios = "$cambios = @(\n    ,@('src\\index.ts', 'mails: titulo debajo del logo y pie con el link del panel', %s, %s)\n)\n" % (psq(A), psq(N))
cabeza = '''# aplicar-correos-pie-panel.ps1 - Ojo Guard MS: arregla dos detalles del mail nuevo (para quien ya aplico aplicar-correos-marca-panel.ps1 version fd9ba5d).
#  - El titulo de la franja azul pasa debajo del logo (en el celular quedaba apretado).
#  - El pie de todos los mails muestra "Tu panel de Ojo Guard: ms.ojoguard.app" (con link), para que quede en la memoria y no se pierda.
# Cambia SOLO src\\index.ts (respaldo index.ts.bak-correospie). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
$txt = (Leer (Join-Path $raiz "src\\index.ts")).texto
if ((Contar $txt 'Tu panel de Ojo Guard:') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $txt 'function conMarcaCorreoNuevo') -ne 1) { Mal "Primero tiene que estar aplicado aplicar-correos-marca-panel.ps1. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):]
cola = cola.replace('.bak-audioandroid', '.bak-correospie')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: el titulo queda debajo del logo y el pie muestra el link del panel. Pedi otro codigo de ingreso para verlo."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127]
assert not bad, set(bad)
open(R + 'aplicar-correos-pie-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
