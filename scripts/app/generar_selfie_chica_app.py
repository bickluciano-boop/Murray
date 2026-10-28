# Genera scripts/aplicar-selfie-chica-app.ps1: la selfie se achica antes de mandarla a Didit (necesita expo-image-manipulator).
import re, subprocess
R = '/home/user/Murray/scripts/'
COMMIT_ARCHIVOS = 'fab263d9aa8b6036eff085493f07d0c04b45e911'
SHA = subprocess.check_output(['sha256sum', R + 'app/src/VerificarIdentidad.tsx']).decode().split()[0]
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
url = 'https://raw.githubusercontent.com/bickluciano-boop/Murray/%s/scripts/app/src/VerificarIdentidad.tsx' % COMMIT_ARCHIVOS
# Un solo archivo: la coma de adelante evita que PowerShell aplane la fila.
descargas = "$descargas = @(\n    ,@(%s, %s, %s)\n)\n" % (psq(url), psq('src\\VerificarIdentidad.tsx'), psq(SHA))
cambios = "$cambios = @(\n)\n"
cabeza = '''# aplicar-selfie-chica-app.ps1 - App (PROXIMA build): la selfie de la verificacion de identidad se achica a 600 px antes de mandarla.
# Con "wrangler tail" se midio que Didit corta la conexion con pedidos de 300 KB o mas (100 KB pasa) y la selfie de la camara pesaba ~600 KB: por eso siempre fallaba con "El servicio de verificacion no esta disponible".
# Reemplaza src\VerificarIdentidad.tsx (descarga con huella, respaldo .bak-selfie-chica). REQUIERE instalar antes expo-image-manipulator: npx.cmd expo install expo-image-manipulator. Va en la carpeta de la APP. Sale en la PROXIMA build.
'''
i = base.index('$ErrorActionPreference'); j = base.index('Ok "Carpeta correcta"')
motor_ini = base[i:j]
guardas = '''Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\VerificarIdentidad.tsx"))) { Mal "No encuentro src\VerificarIdentidad.tsx. Falta aplicar aplicar-identidad-app.ps1."; return }
if (-not (Test-Path (Join-Path $raiz "node_modules\expo-image-manipulator"))) { Mal "Falta instalar expo-image-manipulator. Corre primero: npx.cmd expo install expo-image-manipulator"; return }
if ((Contar (Leer (Join-Path $raiz "src\VerificarIdentidad.tsx")).texto 'reducirSelfie') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('$descargas = @()\n', descargas, 1).replace('.bak-version', '.bak-selfie-chica')
v = 'if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-selfie-chica") -Destination $ruta -Force } }'
assert cola.count(v) == 1, cola.count(v)
cola = cola.replace(v, 'if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-selfie-chica") -Destination $ruta -Force } elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force } }')
msg = 'Mal "Restaurado. Mandame esta pantalla."'
assert cola.count(msg) == 2
cola = cola.replace(msg, 'foreach ($t in $respaldados) { Remove-Item -LiteralPath ((Join-Path $raiz $t) + ".bak-selfie-chica") -Force -ErrorAction SilentlyContinue }\n' + msg)
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "LISTO: la app compila bien. Sale en la PROXIMA build."', cola)
total = cabeza + motor_ini + guardas + cambios + cola
open(R + 'aplicar-selfie-chica-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
