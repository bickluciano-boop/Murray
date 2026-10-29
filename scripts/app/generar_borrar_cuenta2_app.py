# Genera scripts/aplicar-borrar-cuenta2-app.ps1: la selfie se achica antes de mandarla a Didit (necesita expo-image-manipulator).
import re, subprocess
R = '/home/user/Murray/scripts/'
COMMIT_ARCHIVOS = subprocess.check_output(['git', '-C', R, 'log', '-1', '--format=%H', '--', 'app/src/BorrarCuenta.tsx']).decode().strip()
SHA = subprocess.check_output(['sha256sum', R + 'app/arranque/ArranqueIdentidad.tsx']).decode().split()[0]
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
def url(ruta):
    return 'https://raw.githubusercontent.com/bickluciano-boop/Murray/%s/scripts/app/%s' % (COMMIT_ARCHIVOS, ruta)
def sha(ruta):
    return subprocess.check_output(['sha256sum', R + 'app/' + ruta]).decode().split()[0]
ARCHIVOS = [('src/BorrarCuenta.tsx', 'src\\BorrarCuenta.tsx')]
descargas = "$descargas = @(\n    ," + "@(%s, %s, %s)" % (psq(url(ARCHIVOS[0][0])), psq(ARCHIVOS[0][1]), psq(sha(ARCHIVOS[0][0]))) + "\n)\n"
cambios = "$cambios = @(\n)\n"
cabeza = '''# aplicar-borrar-cuenta2-app.ps1 - App (PROXIMA build): al borrar la cuenta, una pantalla completa avisa "Tu cuenta se borro" y tapa lo demas (antes quedaban a la vista tarjetas viejas hasta reabrir la app).
# En Android agrega el boton "Cerrar Ojo Guard". Reemplaza src\\BorrarCuenta.tsx (descarga con huella, respaldo .bak-borrar-cuenta2). Requiere aplicar-borrar-cuenta-app.ps1. Va en la carpeta de la APP.
'''
i = base.index('$ErrorActionPreference'); j = base.index('Ok "Carpeta correcta"')
motor_ini = base[i:j]
guardas = '''Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\BorrarCuenta.tsx"))) { Mal "No encuentro src\\BorrarCuenta.tsx. Falta aplicar aplicar-borrar-cuenta-app.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\\BorrarCuenta.tsx")).texto 'presentationStyle') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('$descargas = @()\n', descargas, 1).replace('.bak-version', '.bak-borrar-cuenta2')
v = 'if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-borrar-cuenta2") -Destination $ruta -Force } }'
assert cola.count(v) == 1, cola.count(v)
cola = cola.replace(v, 'if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-borrar-cuenta2") -Destination $ruta -Force } elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force } }')
msg = 'Mal "Restaurado. Mandame esta pantalla."'
assert cola.count(msg) == 2
cola = cola.replace(msg, 'foreach ($t in $respaldados) { Remove-Item -LiteralPath ((Join-Path $raiz $t) + ".bak-borrar-cuenta2") -Force -ErrorAction SilentlyContinue }\n' + msg)
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "LISTO: la app compila bien. Sale en la PROXIMA build."', cola)
total = cabeza + motor_ini + guardas + cambios + cola
open(R + 'aplicar-borrar-cuenta2-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
