# Genera scripts/aplicar-historial-evidencia-app.ps1: la selfie se achica antes de mandarla a Didit (necesita expo-image-manipulator).
import re, subprocess
R = '/home/user/Murray/scripts/'
COMMIT_ARCHIVOS = subprocess.check_output(['git', '-C', R, 'log', '-1', '--format=%H', '--', 'app/src/evidenceHistory.ts']).decode().strip()
SHA = subprocess.check_output(['sha256sum', R + 'app/arranque/ArranqueIdentidad.tsx']).decode().split()[0]
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
def url(ruta):
    return 'https://raw.githubusercontent.com/bickluciano-boop/Murray/%s/scripts/app/%s' % (COMMIT_ARCHIVOS, ruta)
def sha(ruta):
    return subprocess.check_output(['sha256sum', R + 'app/' + ruta]).decode().split()[0]
ARCHIVOS = [('src/evidenceHistory.ts', 'src\\evidenceHistory.ts')]
descargas = "$descargas = @(\n    ," + "@(%s, %s, %s)" % (psq(url(ARCHIVOS[0][0])), psq(ARCHIVOS[0][1]), psq(sha(ARCHIVOS[0][0]))) + "\n)\n"
cambios = "$cambios = @(\n)\n"
cabeza = '''# aplicar-historial-evidencia-app.ps1 - App (PROXIMA build): arregla "Falló el guardado de la evidencia ... deleteAsync ... File ... is not writable" en el iPhone.
# Causa: el historial guarda rutas completas con el identificador de la carpeta de datos de la app, que en iPhone puede cambiar al actualizar por TestFlight; al borrar un archivo viejo con esa ruta, falla y arrastra el guardado de la evidencia nueva.
# Ahora las rutas se rearman con la carpeta actual al leer el historial y el borrado de archivos viejos nunca frena el guardado. Reemplaza src\\evidenceHistory.ts (descarga con huella, respaldo .bak-historial-evidencia). Va en la carpeta de la APP.
'''
i = base.index('$ErrorActionPreference'); j = base.index('Ok "Carpeta correcta"')
motor_ini = base[i:j]
guardas = '''Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\evidenceHistory.ts"))) { Mal "No encuentro src\\evidenceHistory.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\evidenceHistory.ts")).texto 'safeDelete') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('$descargas = @()\n', descargas, 1).replace('.bak-version', '.bak-historial-evidencia')
v = 'if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-historial-evidencia") -Destination $ruta -Force } }'
assert cola.count(v) == 1, cola.count(v)
cola = cola.replace(v, 'if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-historial-evidencia") -Destination $ruta -Force } elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force } }')
msg = 'Mal "Restaurado. Mandame esta pantalla."'
assert cola.count(msg) == 2
cola = cola.replace(msg, 'foreach ($t in $respaldados) { Remove-Item -LiteralPath ((Join-Path $raiz $t) + ".bak-historial-evidencia") -Force -ErrorAction SilentlyContinue }\n' + msg)
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "LISTO: la app compila bien. Sale en la PROXIMA build."', cola)
total = cabeza + motor_ini + guardas + cambios + cola
open(R + 'aplicar-historial-evidencia-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
