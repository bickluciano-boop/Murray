# Genera scripts/aplicar-foto-ruta-app.ps1: la selfie se achica antes de mandarla a Didit (necesita expo-image-manipulator).
import re, subprocess
R = '/home/user/Murray/scripts/'
COMMIT_ARCHIVOS = subprocess.check_output(['git', '-C', R, 'log', '-1', '--format=%H', '--', 'app/src/FotoPerfil.tsx', 'app/arranque/ArranqueIdentidad.tsx']).decode().strip()
SHA = subprocess.check_output(['sha256sum', R + 'app/arranque/ArranqueIdentidad.tsx']).decode().split()[0]
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
def url(ruta):
    return 'https://raw.githubusercontent.com/bickluciano-boop/Murray/%s/scripts/app/%s' % (COMMIT_ARCHIVOS, ruta)
def sha(ruta):
    return subprocess.check_output(['sha256sum', R + 'app/' + ruta]).decode().split()[0]
ARCHIVOS = [('src/FotoPerfil.tsx', 'src\\FotoPerfil.tsx'), ('arranque/ArranqueIdentidad.tsx', 'src\\ArranqueIdentidad.tsx')]
descargas = "$descargas = @(\n" + ',\n'.join("    @(%s, %s, %s)" % (psq(url(a)), psq(b), psq(sha(a))) for a, b in ARCHIVOS) + "\n)\n"
cambios = "$cambios = @(\n)\n"
cabeza = '''# aplicar-foto-ruta-app.ps1 - App (PROXIMA build): la foto de perfil no desaparece al actualizar la app en el iPhone.
# Causa: la ruta guardada incluye el identificador de la carpeta de datos del iPhone, que cambia al actualizar por TestFlight; la app buscaba la foto en la carpeta vieja. Ahora la ruta se rearma con la carpeta actual y, si de verdad falta, la tarjeta lo avisa.
# Reemplaza src\\FotoPerfil.tsx y src\\ArranqueIdentidad.tsx (descarga con huella, respaldo .bak-foto-ruta). Requiere aplicar-foto-perfil3-app.ps1. Va en la carpeta de la APP.
'''
i = base.index('$ErrorActionPreference'); j = base.index('Ok "Carpeta correcta"')
motor_ini = base[i:j]
guardas = '''Ok "Carpeta correcta"
foreach ($f in @("src\\FotoPerfil.tsx", "src\\ArranqueIdentidad.tsx")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\\ArranqueIdentidad.tsx")).texto 'rutaActual') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\FotoPerfil.tsx")).texto 'dejarDeCompartirFoto') -eq 0) { Mal "Falta aplicar primero aplicar-foto-perfil3-app.ps1. No toco nada."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('$descargas = @()\n', descargas, 1).replace('.bak-version', '.bak-foto-ruta')
v = 'if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-foto-ruta") -Destination $ruta -Force } }'
assert cola.count(v) == 1, cola.count(v)
cola = cola.replace(v, 'if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-foto-ruta") -Destination $ruta -Force } elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force } }')
msg = 'Mal "Restaurado. Mandame esta pantalla."'
assert cola.count(msg) == 2
cola = cola.replace(msg, 'foreach ($t in $respaldados) { Remove-Item -LiteralPath ((Join-Path $raiz $t) + ".bak-foto-ruta") -Force -ErrorAction SilentlyContinue }\n' + msg)
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "LISTO: la app compila bien. Sale en la PROXIMA build."', cola)
total = cabeza + motor_ini + guardas + cambios + cola
open(R + 'aplicar-foto-ruta-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
