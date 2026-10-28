# Genera scripts/aplicar-laminas-app.ps1: la bienvenida pasa de 13 a 7 laminas (las mismas explicaciones, de a dos por lamina).
import re, subprocess
R = '/home/user/Murray/scripts/'
COMMIT_ARCHIVOS = 'ec5c8b598ff180791b072ca107fd72a9206e22c4'
SHA = subprocess.check_output(['sha256sum', R + 'app/arranque/Bienvenida.tsx']).decode().split()[0]
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
url = 'https://raw.githubusercontent.com/bickluciano-boop/Murray/%s/scripts/app/arranque/Bienvenida.tsx' % COMMIT_ARCHIVOS
# Un solo archivo: la coma de adelante evita que PowerShell aplane la fila.
descargas = "$descargas = @(\n    ,@(%s, %s, %s)\n)\n" % (psq(url), psq('src\\Bienvenida.tsx'), psq(SHA))
cambios = "$cambios = @(\n)\n"
cabeza = '''# aplicar-laminas-app.ps1 - App (PROXIMA build): la bienvenida pasa de 13 a 7 laminas. Mismas explicaciones y mismos dibujos, juntados de a dos (dos dibujos chicos lado a lado y los dos textos abajo).
# Luciano (28/10/2026): "no es lo mismo 7 que 13"; su mama dijo "son muchos pasos". Reemplaza src\\Bienvenida.tsx (descarga con huella verificada, respaldo .bak-laminas). Requiere aplicar-arranque2-app.ps1. Va en la carpeta de la APP. Sale en la PROXIMA build.
'''
i = base.index('$ErrorActionPreference'); j = base.index('Ok "Carpeta correcta"')
motor_ini = base[i:j]
guardas = '''Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\Bienvenida.tsx"))) { Mal "No encuentro src\\Bienvenida.tsx. Falta aplicar aplicar-arranque2-app.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\\Bienvenida.tsx")).texto 'LaminaBienvenida') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('$descargas = @()\n', descargas, 1).replace('.bak-version', '.bak-laminas')
v = 'if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-laminas") -Destination $ruta -Force } }'
assert cola.count(v) == 1, cola.count(v)
cola = cola.replace(v, 'if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-laminas") -Destination $ruta -Force } elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force } }')
msg = 'Mal "Restaurado. Mandame esta pantalla."'
assert cola.count(msg) == 2
cola = cola.replace(msg, 'foreach ($t in $respaldados) { Remove-Item -LiteralPath ((Join-Path $raiz $t) + ".bak-laminas") -Force -ErrorAction SilentlyContinue }\n' + msg)
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "LISTO: la app compila bien. Sale en la PROXIMA build."', cola)
total = cabeza + motor_ini + guardas + cambios + cola
open(R + 'aplicar-laminas-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
