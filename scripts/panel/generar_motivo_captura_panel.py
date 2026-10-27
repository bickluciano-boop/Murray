# Genera scripts/aplicar-motivo-captura-panel.ps1: la consola entiende "remote_capture_timeout:<paso>" (el telefono ahora dice en que paso se trabo) y sigue mostrando el mismo mensaje.
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-raiz-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
A = 'MOTIVOS_CAPTURA[c.error]'
N = 'MOTIVOS_CAPTURA[String(c.error || "").split(":")[0]]'
filas = [('src\\panel-mapa.txt', 'motivos de captura: acepta el sufijo con el paso', A, N)]
cambios = "$cambios = @(\n    ," + ',\n'.join("@(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-motivo-captura-panel.ps1 - Ojo Guard MS: la consola entiende el motivo "remote_capture_timeout:<paso>" que va a mandar la app nueva (dice en que paso se trabo la foto).
# Sin esto, el mensaje de la consola cambiaria a "no pudo sacar la foto" en vez de "no llego a sacar la foto a tiempo". Solo cambia una expresion en src\\panel-mapa.txt (respaldo .bak-motivocaptura).
# Va en la carpeta del PANEL (la que tiene wrangler.toml). No cambia nada si la app todavia manda el motivo viejo. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\panel-mapa.txt"))) { Mal "No encuentro src\\panel-mapa.txt en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-mapa.txt")).texto 'String(c.error || "").split(":")[0]') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-raiz', '.bak-motivocaptura')
cola = re.sub(r'Ok "LISTO: el panel se abre en.*"\n', 'Ok "LISTO: la consola entiende el motivo de la captura con el paso."\n', cola)
assert 'bak-raiz' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
open(R + 'aplicar-motivo-captura-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
