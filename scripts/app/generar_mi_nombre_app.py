# Genera scripts/aplicar-mi-nombre-app.ps1: tarjeta "Mi nombre" dentro de Perfil (como te ven los demas en el mapa y las listas). Descarga src\MiNombre.tsx y cambia src\FotoPerfil.tsx.
import re, subprocess
R = '/home/user/Murray/scripts/'
def sh(c):
    return subprocess.check_output(c).decode().strip()
COMMIT = sh(['git', '-C', R, 'log', '-1', '--format=%H', '--', 'app/src/MiNombre.tsx'])
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
fuente = open(R + 'app/src/FotoPerfil.tsx', encoding='utf-8').read()
arch = 'src\\FotoPerfil.tsx'
a1 = 'import { Icono } from "./Iconos";\n'
b1 = a1 + 'import { MiNombre } from "./MiNombre";\n'
a2 = '  return (\n    <View style={{ backgroundColor: paleta.superficie, borderRadius: 18, borderWidth: 1, borderColor: paleta.borde, padding: 18, marginBottom: 14 }}>\n      <Text accessibilityRole="header" style={{ color: paleta.texto, fontSize: 19, fontWeight: "800" }}>\n        Mi foto de perfil\n'
b2 = '  return (\n    <>\n    <MiNombre paleta={paleta} noche={noche} />\n    <View style={{ backgroundColor: paleta.superficie, borderRadius: 18, borderWidth: 1, borderColor: paleta.borde, padding: 18, marginBottom: 14 }}>\n      <Text accessibilityRole="header" style={{ color: paleta.texto, fontSize: 19, fontWeight: "800" }}>\n        Mi foto de perfil\n'
a3 = '        )}\n      </View>\n    </View>\n  );\n}'
b3 = '        )}\n      </View>\n    </View>\n    </>\n  );\n}'
for a in (a1, a2, a3):
    assert fuente.count(a) == 1, a[:50]
filas = [(arch, 'importar la tarjeta Mi nombre', a1, b1), (arch, 'Mi nombre arriba de la foto de perfil', a2, b2), (arch, 'cerrar el bloque de Perfil', a3, b3)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
def url(ruta):
    return 'https://raw.githubusercontent.com/bickluciano-boop/Murray/%s/scripts/app/%s' % (COMMIT, ruta)
sha = sh(['sha256sum', R + 'app/src/MiNombre.tsx']).split()[0]
descargas = "$descargas = @(\n    ,@(%s, %s, %s)\n)\n" % (psq(url('src/MiNombre.tsx')), psq('src\\MiNombre.tsx'), psq(sha))
cabeza = '''# aplicar-mi-nombre-app.ps1 - App (PROXIMA build): tarjeta "Mi nombre" dentro de Perfil, arriba de la foto: es como te ven las personas de tu circulo en el mapa y las listas.
# Si no pones ninguno, te ven con el nombre que te puso quien te invito. Idea de Luciano (29/10/2026). Descarga src\\MiNombre.tsx (nuevo) y cambia src\\FotoPerfil.tsx (respaldo .bak-mi-nombre).
# Requiere aplicar-foto-perfil3-app.ps1 y el servidor con aplicar-mi-nombre-panel.ps1. Va en la carpeta de la APP.
'''
i = base.index('$ErrorActionPreference'); j = base.index('Ok "Carpeta correcta"')
motor_ini = base[i:j]
guardas = '''Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\FotoPerfil.tsx"))) { Mal "No encuentro src\\FotoPerfil.tsx en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\FotoPerfil.tsx")).texto 'MiNombre') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\FotoPerfil.tsx")).texto 'dejarDeCompartirFoto') -eq 0) { Mal "Falta aplicar primero aplicar-foto-perfil3-app.ps1. No toco nada."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('$descargas = @()\n', descargas, 1).replace('.bak-version', '.bak-mi-nombre')
v = 'if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-mi-nombre") -Destination $ruta -Force } }'
assert cola.count(v) == 1, cola.count(v)
cola = cola.replace(v, 'if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-mi-nombre") -Destination $ruta -Force } elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force } }')
msg = 'Mal "Restaurado. Mandame esta pantalla."'
assert cola.count(msg) == 2
cola = cola.replace(msg, 'foreach ($t in $respaldados) { Remove-Item -LiteralPath ((Join-Path $raiz $t) + ".bak-mi-nombre") -Force -ErrorAction SilentlyContinue }\n' + msg)
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "LISTO: la app compila bien. Sale en la PROXIMA build."', cola)
assert 'bak-version' not in cola
total = cabeza + motor_ini + guardas + cambios + cola
open(R + 'aplicar-mi-nombre-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total), COMMIT)
