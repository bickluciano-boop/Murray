# Genera scripts/aplicar-raiz-panel.ps1: el panel tambien se abre en ojoguard.app (sin "ms"), que pasa a ser la direccion principal.
# La direccion vieja (workers.dev) y ms.ojoguard.app siguen funcionando.
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
filas = [
    ('wrangler.toml', 'passkeys: dominio principal', 'PASSKEY_RP_ID = "ms.ojoguard.app"', 'PASSKEY_RP_ID = "ojoguard.app"'),
    ('wrangler.toml', 'passkeys y links: direccion principal', 'PASSKEY_ORIGIN = "https://ms.ojoguard.app"', 'PASSKEY_ORIGIN = "https://ojoguard.app"'),
    ('wrangler.toml', 'ruta del dominio ojoguard.app (se suma a ms.ojoguard.app)', 'pattern = "ms.ojoguard.app"\ncustom_domain = true',
     'pattern = "ms.ojoguard.app"\ncustom_domain = true\n\n# Direccion principal, corta y facil de recordar (se conecto el 22/10/2026).\n[[routes]]\npattern = "ojoguard.app"\ncustom_domain = true'),
    ('src\\index.ts', 'direccion del panel en mails y SMS (ojoguard.app)', 'const DEFAULT_PANEL_URL = "https://ms.ojoguard.app/";', 'const DEFAULT_PANEL_URL = "https://ojoguard.app/";'),
]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-raiz-panel.ps1 - Ojo Guard MS: el panel se abre tambien en https://ojoguard.app (sin "ms"), que pasa a ser la direccion principal.
# Luciano (22/10/2026): "que el usuario escriba solamente ojoguard.app, porque el MS es muy probable que se lo olviden".
#  - Siguen funcionando igual: ms.ojoguard.app y la direccion vieja (ojo-guard-ms-api.bickluciano.workers.dev).
#  - Los links y el pie de los mails y de los SMS pasan a ojoguard.app.
#  - Las passkeys (huella / Face ID) quedan de ojoguard.app: se registran UNA vez. El codigo de 6 numeros por correo funciona en las tres direcciones.
# Antes hay que borrar en Cloudflare (DNS de ojoguard.app) los registros A y AAAA de GitHub del dominio raiz; si no, Cloudflare no deja conectar el panel ahi.
# Cambia SOLO wrangler.toml y src\\index.ts (respaldos .bak-raiz). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "wrangler.toml")).texto 'pattern = "ojoguard.app"') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):]
cola = cola.replace('.bak-audioandroid', '.bak-raiz')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: el panel se abre en https://ojoguard.app (y sigue en ms.ojoguard.app y en la direccion vieja). Registra la huella o Face ID una vez en ojoguard.app."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127]
assert not bad, set(bad)
open(R + 'aplicar-raiz-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
