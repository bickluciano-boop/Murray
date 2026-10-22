# Genera scripts/aplicar-dominio-panel.ps1: el panel pasa a usar ms.ojoguard.app (SMS, mails, passkeys).
# Cambia SOLO wrangler.toml: PASSKEY_RP_ID, PASSKEY_ORIGIN y agrega la ruta del dominio personalizado (para que quede fijo en el archivo y no dependa del panel de Cloudflare).
import re, sys
MODO = sys.argv[1] if len(sys.argv) > 1 else 'completo'
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')

def psq(s):
    return "'" + s.replace("'", "''") + "'"

VIEJO_RP = 'PASSKEY_RP_ID = "ojo-guard-ms-api.bickluciano.workers.dev"'
NUEVO_RP = 'PASSKEY_RP_ID = "ms.ojoguard.app"'
VIEJO_OR = 'PASSKEY_ORIGIN = "https://ojo-guard-ms-api.bickluciano.workers.dev"'
NUEVO_OR = ('PASSKEY_ORIGIN = "https://ms.ojoguard.app"\n'
            '\n'
            '# Direccion propia del panel (se conecto en Cloudflare el 22/10/2026). La direccion vieja de workers.dev sigue funcionando.\n'
            '[[routes]]\n'
            'pattern = "ms.ojoguard.app"\n'
            'custom_domain = true')

ANCLA_FECHA = 'compatibility_date = "2026-07-31"'
NUEVA_FECHA = ('compatibility_date = "2026-07-31"\n'
               '\n'
               '# La direccion vieja (workers.dev) tiene que seguir activa: la app del telefono todavia la usa. Sin estas dos lineas, wrangler la apaga.\n'
               'workers_dev = true\n'
               'preview_urls = true')
fila_rp = "    @('wrangler.toml', 'passkeys: dominio de las passkeys', %s, %s),\n" % (psq(VIEJO_RP), psq(NUEVO_RP))
fila_or = "    @('wrangler.toml', 'passkeys y links: direccion del panel, y ruta del dominio propio', %s, %s),\n" % (psq(VIEJO_OR), psq(NUEVO_OR))
fila_wd = "    @('wrangler.toml', 'mantener activa la direccion workers.dev', %s, %s)\n" % (psq(ANCLA_FECHA), psq(NUEVA_FECHA))
if MODO == 'workersdev':
    cambios = "$cambios = @(\n" + fila_wd.replace("    @(", "    ,@(", 1) + ")\n"
    MARCA = 'workers_dev = true'
    SALIDA = 'aplicar-dominio2-panel.ps1'
    MSG = 'LISTO: la direccion vieja (workers.dev) quedo activa otra vez junto a ms.ojoguard.app. La app del telefono vuelve a conectar.'
else:
    cambios = "$cambios = @(\n" + fila_rp + fila_or + fila_wd + ")\n"
    MARCA = 'custom_domain = true'
    SALIDA = 'aplicar-dominio-panel.ps1'
    MSG = 'LISTO: el panel ya usa https://ms.ojoguard.app y sigue activa la direccion vieja. Ahora hay que volver a registrar la huella o Face ID (una sola vez).'
cabeza = '''# aplicar-dominio-panel.ps1 - Ojo Guard MS: el panel pasa a usar su direccion propia, ms.ojoguard.app.
# Luciano (22/10/2026): "queda muy desprolijo que este mi nombre" en el link del SMS.
#  - Los links de los SMS, de los mails y de las paginas (Tu proteccion, camino, referente) pasan a https://ms.ojoguard.app/...
#  - Las passkeys (huella / Face ID) pasan a ser de ms.ojoguard.app: hay que volver a registrarlas UNA vez (el codigo de 6 numeros por correo sigue andando igual).
#  - La direccion vieja (ojo-guard-ms-api.bickluciano.workers.dev) sigue funcionando para entrar con el codigo por correo.
# Cambia SOLO wrangler.toml (respaldo wrangler.toml.bak-dominio; el arreglo de workers.dev usa .bak-dominio2). No toca la base, el codigo ni la consola.
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if ((Contar (Leer (Join-Path $raiz "wrangler.toml")).texto '%s') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
''' % MARCA
cola = tpl[tpl.index('$descargas = @()'):]
cola = cola.replace('.bak-audioandroid', '.bak-dominio2' if MODO == 'workersdev' else '.bak-dominio')
# este instalador cambia un archivo cuya huella no conocemos: no se compara la huella, solo las anclas y el largo
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "' + MSG + '"\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola, 'revisar la cola'
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127]
assert not bad, set(bad)
open(R + SALIDA, 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
