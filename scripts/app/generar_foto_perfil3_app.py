# Genera scripts/aplicar-foto-perfil3-app.ps1: la selfie se achica antes de mandarla a Didit (necesita expo-image-manipulator).
import re, subprocess
R = '/home/user/Murray/scripts/'
COMMIT_ARCHIVOS = subprocess.check_output(['git', '-C', R, 'log', '-1', '--format=%H', '--', 'app/src/FotoPerfil.tsx', 'app/src/fotoPerfilServidor.ts']).decode().strip()
SHA = subprocess.check_output(['sha256sum', R + 'app/arranque/ArranqueIdentidad.tsx']).decode().split()[0]
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
def url(ruta):
    return 'https://raw.githubusercontent.com/bickluciano-boop/Murray/%s/scripts/app/%s' % (COMMIT_ARCHIVOS, ruta)
def sha(ruta):
    return subprocess.check_output(['sha256sum', R + 'app/' + ruta]).decode().split()[0]
ARCHIVOS = [('src/FotoPerfil.tsx', 'src\\FotoPerfil.tsx'), ('src/fotoPerfilServidor.ts', 'src\\fotoPerfilServidor.ts')]
descargas = "$descargas = @(\n" + ',\n'.join("    @(%s, %s, %s)" % (psq(url(a)), psq(b), psq(sha(a))) for a, b in ARCHIVOS) + "\n)\n"
cambios = "$cambios = @(\n)\n"
cabeza = '''# aplicar-foto-perfil3-app.ps1 - App (PROXIMA build, la 183): boton "Dejar de compartir mi foto" en Perfil (borra la foto del servidor; sigue guardada en el telefono).
# Luciano (28/10/2026): si. Reemplaza src\\FotoPerfil.tsx y src\\fotoPerfilServidor.ts (descarga con huella, respaldo .bak-foto-perfil3). Requiere aplicar-foto-perfil2-app.ps1. Va en la carpeta de la APP.
'''
i = base.index('$ErrorActionPreference'); j = base.index('Ok "Carpeta correcta"')
motor_ini = base[i:j]
guardas = '''Ok "Carpeta correcta"
foreach ($f in @("src\\FotoPerfil.tsx", "src\\fotoPerfilServidor.ts")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta. Falta aplicar aplicar-foto-perfil2-app.ps1."); return } }
if ((Contar (Leer (Join-Path $raiz "src\\FotoPerfil.tsx")).texto 'dejarDeCompartirFoto') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\FotoPerfil.tsx")).texto 'subirFotoPerfil') -eq 0) { Mal "Falta aplicar primero aplicar-foto-perfil2-app.ps1. No toco nada."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('$descargas = @()\n', descargas, 1).replace('.bak-version', '.bak-foto-perfil3')
v = 'if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-foto-perfil3") -Destination $ruta -Force } }'
assert cola.count(v) == 1, cola.count(v)
cola = cola.replace(v, 'if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-foto-perfil3") -Destination $ruta -Force } elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force } }')
msg = 'Mal "Restaurado. Mandame esta pantalla."'
assert cola.count(msg) == 2
cola = cola.replace(msg, 'foreach ($t in $respaldados) { Remove-Item -LiteralPath ((Join-Path $raiz $t) + ".bak-foto-perfil3") -Force -ErrorAction SilentlyContinue }\n' + msg)
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "LISTO: la app compila bien. Sale en la PROXIMA build."', cola)
total = cabeza + motor_ini + guardas + cambios + cola
open(R + 'aplicar-foto-perfil3-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
