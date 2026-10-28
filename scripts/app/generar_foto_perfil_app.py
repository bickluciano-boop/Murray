# Genera scripts/aplicar-foto-perfil-app.ps1: tarjeta "Mi foto de perfil" dentro de Perfil (camara propia o galeria) y textos honestos en el arranque.
import re, subprocess
R = '/home/user/Murray/scripts/'
def sh(c):
    return subprocess.check_output(c).decode().strip()
COMMIT = sh(['git', '-C', R, 'log', '-1', '--format=%H', '--', 'app/arranque/ArranqueIdentidad.tsx', 'app/src/FotoPerfil.tsx'])
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/actual/'
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
app = open(S + 'out_App.tsx', encoding='utf-8').read()
i1v = 'import { ArranqueIdentidad, cargarIdentidad } from "./src/ArranqueIdentidad";\n'
i1n = i1v + 'import { FotoPerfil } from "./src/FotoPerfil";\n'
c2v = '          {enGrupo(grupoActual, "perfil") ? (\n            <DeviceStatusCard'
c2n = '          {enGrupo(grupoActual, "perfil") ? <FotoPerfil noche={temaActivo === "oscuro"} paleta={P} /> : null}\n\n' + c2v
for v in (i1v, c2v):
    assert app.count(v) == 1, (v, app.count(v))
filas = [('App.tsx', 'importar la tarjeta Mi foto de perfil', i1v, i1n), ('App.tsx', 'tarjeta Mi foto de perfil dentro de Perfil', c2v, c2n)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
def url(ruta):
    return 'https://raw.githubusercontent.com/bickluciano-boop/Murray/%s/scripts/app/%s' % (COMMIT, ruta)
def sha(ruta):
    return sh(['sha256sum', R + 'app/' + ruta]).split()[0]
descargas = "$descargas = @(\n    @(%s, %s, %s),\n    @(%s, %s, %s)\n)\n" % (
    psq(url('src/FotoPerfil.tsx')), psq('src\\FotoPerfil.tsx'), psq(sha('src/FotoPerfil.tsx')),
    psq(url('arranque/ArranqueIdentidad.tsx')), psq('src\\ArranqueIdentidad.tsx'), psq(sha('arranque/ArranqueIdentidad.tsx')))
cabeza = '''# aplicar-foto-perfil-app.ps1 - App (PROXIMA build, la 182): tarjeta "Mi foto de perfil" dentro de Perfil para ver y cambiar la foto (camara propia de la app o galeria).
# Luciano (28/10/2026): "si alguien se cansa y la quiere cambiar no podria?" y "que este dentro de la tarjeta perfil". La foto se guarda solo en este telefono (no se sube a ningun lado).
# Descarga src\\FotoPerfil.tsx (nuevo) y reemplaza src\\ArranqueIdentidad.tsx (descarga con huella, respaldo .bak-foto-perfil) y cambia App.tsx (respaldo). Requiere aplicar-perfil-camara-app.ps1. Va en la carpeta de la APP.
'''
i = base.index('$ErrorActionPreference'); j = base.index('Ok "Carpeta correcta"')
motor_ini = base[i:j]
guardas = '''Ok "Carpeta correcta"
foreach ($f in @("App.tsx", "src\\ArranqueIdentidad.tsx")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta. Falta aplicar los instaladores de identidad."); return } }
if (-not (Test-Path (Join-Path $raiz "node_modules\\expo-camera"))) { Mal "No encuentro expo-camera en node_modules."; return }
if ((Contar (Leer (Join-Path $raiz "App.tsx")).texto 'FotoPerfil') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\ArranqueIdentidad.tsx")).texto 'abrirCamara') -eq 0) { Mal "Falta aplicar primero aplicar-perfil-camara-app.ps1. No toco nada."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('$descargas = @()\n', descargas, 1).replace('.bak-version', '.bak-foto-perfil')
v = 'if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-foto-perfil") -Destination $ruta -Force } }'
assert cola.count(v) == 1, cola.count(v)
cola = cola.replace(v, 'if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-foto-perfil") -Destination $ruta -Force } elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force } }')
msg = 'Mal "Restaurado. Mandame esta pantalla."'
assert cola.count(msg) == 2
cola = cola.replace(msg, 'foreach ($t in $respaldados) { Remove-Item -LiteralPath ((Join-Path $raiz $t) + ".bak-foto-perfil") -Force -ErrorAction SilentlyContinue }\n' + msg)
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "LISTO: la app compila bien. Sale en la PROXIMA build."', cola)
total = cabeza + motor_ini + guardas + cambios + cola
open(R + 'aplicar-foto-perfil-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total), COMMIT)
