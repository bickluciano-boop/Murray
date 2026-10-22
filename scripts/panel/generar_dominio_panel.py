# Genera scripts/aplicar-dominio-panel.ps1: el panel pasa a usar ms.ojoguard.app (SMS, mails, passkeys).
# Cambia SOLO wrangler.toml: PASSKEY_RP_ID, PASSKEY_ORIGIN y agrega la ruta del dominio personalizado (para que quede fijo en el archivo y no dependa del panel de Cloudflare).
import re
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

cambios = ("$cambios = @(\n"
           "    @('wrangler.toml', 'passkeys: dominio de las passkeys', %s, %s),\n"
           "    @('wrangler.toml', 'passkeys y links: direccion del panel, y ruta del dominio propio', %s, %s)\n)\n") % (psq(VIEJO_RP), psq(NUEVO_RP), psq(VIEJO_OR), psq(NUEVO_OR))

cabeza = '''# aplicar-dominio-panel.ps1 - Ojo Guard MS: el panel pasa a usar su direccion propia, ms.ojoguard.app.
# Luciano (22/10/2026): "queda muy desprolijo que este mi nombre" en el link del SMS.
#  - Los links de los SMS, de los mails y de las paginas (Tu proteccion, camino, referente) pasan a https://ms.ojoguard.app/...
#  - Las passkeys (huella / Face ID) pasan a ser de ms.ojoguard.app: hay que volver a registrarlas UNA vez (el codigo de 6 numeros por correo sigue andando igual).
#  - La direccion vieja (ojo-guard-ms-api.bickluciano.workers.dev) sigue funcionando para entrar con el codigo por correo.
# Cambia SOLO wrangler.toml (respaldo wrangler.toml.bak-dominio). No toca la base, el codigo ni la consola.
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if ((Contar (Leer (Join-Path $raiz "wrangler.toml")).texto 'custom_domain = true') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):]
cola = cola.replace('.bak-audioandroid', '.bak-dominio')
# este instalador cambia un archivo cuya huella no conocemos: no se compara la huella, solo las anclas y el largo
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: el panel ya usa https://ms.ojoguard.app. Ahora hay que volver a registrar la huella o Face ID (una sola vez)."\n', cola)
assert 'bak-audioandroid' not in cola and 'ms.ojoguard.app' in cola and 'wrangler deploy' in cola, 'revisar la cola'
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127]
assert not bad, set(bad)
open(R + 'aplicar-dominio-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
