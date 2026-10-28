# Genera scripts/aplicar-perfil-camara-app.ps1: la selfie se achica antes de mandarla a Didit (necesita expo-image-manipulator).
import re, subprocess
R = '/home/user/Murray/scripts/'
COMMIT_ARCHIVOS = subprocess.check_output(['git', '-C', R, 'log', '-1', '--format=%H', '--', 'app/arranque/ArranqueIdentidad.tsx']).decode().strip()
SHA = subprocess.check_output(['sha256sum', R + 'app/arranque/ArranqueIdentidad.tsx']).decode().split()[0]
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
url = 'https://raw.githubusercontent.com/bickluciano-boop/Murray/%s/scripts/app/arranque/ArranqueIdentidad.tsx' % COMMIT_ARCHIVOS
# Un solo archivo: la coma de adelante evita que PowerShell aplane la fila.
descargas = "$descargas = @(\n    ,@(%s, %s, %s)\n)\n" % (psq(url), psq('src\\ArranqueIdentidad.tsx'), psq(SHA))
cambios = "$cambios = @(\n)\n"
cabeza = '''# aplicar-perfil-camara-app.ps1 - App (PROXIMA build): la foto de perfil del arranque se saca con la camara propia de la app (igual que la selfie de identidad).
# En el Xiaomi abrir la camara del sistema mata la app y vuelve a la pantalla del codigo: con la camara propia no pasa. La galeria sigue como estaba.
# Reemplaza src\\ArranqueIdentidad.tsx (descarga con huella, respaldo .bak-perfil-camara). Requiere aplicar-identidad-app.ps1 y expo-camera (ya instalado). Va en la carpeta de la APP. Sale en la PROXIMA build.
'''
i = base.index('$ErrorActionPreference'); j = base.index('Ok "Carpeta correcta"')
motor_ini = base[i:j]
guardas = '''Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\ArranqueIdentidad.tsx"))) { Mal "No encuentro src\\ArranqueIdentidad.tsx. Falta aplicar aplicar-identidad-app.ps1."; return }
if (-not (Test-Path (Join-Path $raiz "node_modules\\expo-camera"))) { Mal "No encuentro expo-camera en node_modules."; return }
if ((Contar (Leer (Join-Path $raiz "src\\ArranqueIdentidad.tsx")).texto 'abrirCamara') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('$descargas = @()\n', descargas, 1).replace('.bak-version', '.bak-perfil-camara')
v = 'if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-perfil-camara") -Destination $ruta -Force } }'
assert cola.count(v) == 1, cola.count(v)
cola = cola.replace(v, 'if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-perfil-camara") -Destination $ruta -Force } elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force } }')
msg = 'Mal "Restaurado. Mandame esta pantalla."'
assert cola.count(msg) == 2
cola = cola.replace(msg, 'foreach ($t in $respaldados) { Remove-Item -LiteralPath ((Join-Path $raiz $t) + ".bak-perfil-camara") -Force -ErrorAction SilentlyContinue }\n' + msg)
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "LISTO: la app compila bien. Sale en la PROXIMA build."', cola)
total = cabeza + motor_ini + guardas + cambios + cola
open(R + 'aplicar-perfil-camara-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
