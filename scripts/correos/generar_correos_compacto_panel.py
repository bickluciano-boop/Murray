# Genera scripts/aplicar-correos-compacto-panel.ps1: los mails se ven enteros en el celular (mas chicos) y el mail del codigo muestra el numero grande arriba.
# Parte de lo que dejaron aplicar-correos-marca-panel.ps1 (fd9ba5d) + aplicar-correos-pie-panel.ps1 (74f76f3).
import re, ast, subprocess
R = '/home/user/Murray/scripts/'
REV = '74f76f39d7aa29066ecc1abd59892489e7098c5f'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
git = lambda ruta: subprocess.check_output(['git', '-C', R, 'show', REV + ':scripts/' + ruta]).decode()
def valor(fuente, nombre):
    for n in ast.parse(fuente).body:
        if isinstance(n, ast.Assign) and n.targets[0].id == nombre:
            return ast.literal_eval(n.value)
    raise KeyError(nombre)
gen_viejo = git('correos/generar_correos_panel.py')
gen_nuevo = open(R + 'correos/generar_correos_panel.py', encoding='utf-8').read()
A5, A6v = valor(gen_viejo, 'N5'), valor(gen_viejo, 'N6')
N5, N6 = valor(gen_nuevo, 'N5'), valor(gen_nuevo, 'N6')
ts_viejo, ts_nuevo = git('correos/correos-marca.ts'), open(R + 'correos/correos-marca.ts', encoding='utf-8').read()
corte = lambda t: t[t.index('// Los cuerpos de los correos'):].rstrip('\n')
filas = [
    ('mail del codigo: numero grande arriba', A5, N5),
    ('mail del codigo: vencimiento', A6v, N6),
    ('mails: compactos para el celular', corte(ts_viejo), corte(ts_nuevo)),
]
assert all(a != n for _, a, n in filas)
cambios = "$cambios = @(\n" + ',\n'.join("    @('src\\index.ts', %s, %s, %s)" % (psq(l), psq(a), psq(n)) for l, a, n in filas) + "\n)\n"
cabeza = '''# aplicar-correos-compacto-panel.ps1 - Ojo Guard MS: los mails se ven enteros en el celular (sin tener que bajar) y el mail del codigo muestra el numero bien grande arriba.
# Luciano (22/10/2026): "queda muy grande la tarjeta por mail... que se vea de una sola impresion y que el numero sea grande".
#  - Franja azul mas finita; el titulo solo aparece ahi si el mail no trae uno grande abajo.
#  - Margenes y tamanos de letra mas chicos; pie corto con el link del panel.
#  - Mail del codigo: el numero va primero, centrado y grande.
# Cambia SOLO src\\index.ts (respaldo index.ts.bak-correoscompacto). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
$txt = (Leer (Join-Path $raiz "src\\index.ts")).texto
if ((Contar $txt 'text-size-adjust:100%') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $txt 'Tu panel de Ojo Guard:') -ne 1) { Mal "Primero tienen que estar aplicados los instaladores de correos anteriores (marca y pie). No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):]
cola = cola.replace('.bak-audioandroid', '.bak-correoscompacto')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: los mails quedan compactos y el codigo va grande arriba. Pedi otro codigo de ingreso para verlo."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127]
assert not bad, set(bad)
open(R + 'aplicar-correos-compacto-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
