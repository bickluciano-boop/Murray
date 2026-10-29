# Genera scripts/aplicar-borrar-cuenta-app.ps1: tarjeta "Mi foto de perfil" dentro de Perfil (camara propia o galeria) y textos honestos en el arranque.
import re, subprocess
R = '/home/user/Murray/scripts/'
def sh(c):
    return subprocess.check_output(c).decode().strip()
COMMIT = sh(['git', '-C', R, 'log', '-1', '--format=%H', '--', 'app/src/BorrarCuenta.tsx'])
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/actual/'
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
app = open(S + 'out_App.tsx', encoding='utf-8').read()
app = app.replace('import { ArranqueIdentidad, cargarIdentidad } from "./src/ArranqueIdentidad";\n', 'import { ArranqueIdentidad, cargarIdentidad } from "./src/ArranqueIdentidad";\nimport { FotoPerfil } from "./src/FotoPerfil";\n')
app = app.replace('          {enGrupo(grupoActual, "perfil") ? (\n            <DeviceStatusCard', '          {enGrupo(grupoActual, "perfil") ? <FotoPerfil noche={temaActivo === "oscuro"} paleta={P} /> : null}\n\n          {enGrupo(grupoActual, "perfil") ? (\n            <DeviceStatusCard')
i1v = 'import { FotoPerfil } from "./src/FotoPerfil";\n'
i1n = i1v + 'import { BorrarCuenta } from "./src/BorrarCuenta";\n'
c2v = '          {enGrupo(grupoActual, "perfil") ? <FotoPerfil noche={temaActivo === "oscuro"} paleta={P} /> : null}\n'
c2n = c2v + '          {enGrupo(grupoActual, "perfil") ? <BorrarCuenta noche={temaActivo === "oscuro"} paleta={P} /> : null}\n'
for v in (i1v, c2v):
    assert app.count(v) == 1, (v, app.count(v))
filas = [('App.tsx', 'importar Borrar mi cuenta', i1v, i1n), ('App.tsx', 'Borrar mi cuenta dentro de Perfil', c2v, c2n)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
def url(ruta):
    return 'https://raw.githubusercontent.com/bickluciano-boop/Murray/%s/scripts/app/%s' % (COMMIT, ruta)
def sha(ruta):
    return sh(['sha256sum', R + 'app/' + ruta]).split()[0]
descargas = "$descargas = @(\n    ,@(%s, %s, %s)\n)\n" % (psq(url('src/BorrarCuenta.tsx')), psq('src\\BorrarCuenta.tsx'), psq(sha('src/BorrarCuenta.tsx')))
cabeza = '''# aplicar-borrar-cuenta-app.ps1 - App (PROXIMA build): "Borrar mi cuenta" dentro de Perfil (Apple lo exige para publicar apps con cuenta).
# Se confirma escribiendo BORRAR; el servidor borra todo (aplicar-borrar-cuenta-panel.ps1) y recien ahi la app limpia este telefono. Descarga src\\BorrarCuenta.tsx (nuevo) y cambia App.tsx (respaldo .bak-borrar-cuenta).
# Requiere aplicar-foto-perfil-app.ps1. Va en la carpeta de la APP.
'''
i = base.index('$ErrorActionPreference'); j = base.index('Ok "Carpeta correcta"')
motor_ini = base[i:j]
guardas = '''Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "App.tsx"))) { Mal "No encuentro App.tsx en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "App.tsx")).texto 'BorrarCuenta') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "App.tsx")).texto 'FotoPerfil') -eq 0) { Mal "Falta aplicar primero aplicar-foto-perfil-app.ps1. No toco nada."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('$descargas = @()\n', descargas, 1).replace('.bak-version', '.bak-borrar-cuenta')
v = 'if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-borrar-cuenta") -Destination $ruta -Force } }'
assert cola.count(v) == 1, cola.count(v)
cola = cola.replace(v, 'if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-borrar-cuenta") -Destination $ruta -Force } elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force } }')
msg = 'Mal "Restaurado. Mandame esta pantalla."'
assert cola.count(msg) == 2
cola = cola.replace(msg, 'foreach ($t in $respaldados) { Remove-Item -LiteralPath ((Join-Path $raiz $t) + ".bak-borrar-cuenta") -Force -ErrorAction SilentlyContinue }\n' + msg)
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "LISTO: la app compila bien. Sale en la PROXIMA build."', cola)
total = cabeza + motor_ini + guardas + cambios + cola
open(R + 'aplicar-borrar-cuenta-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total), COMMIT)
