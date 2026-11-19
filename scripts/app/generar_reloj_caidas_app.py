# Genera scripts/aplicar-reloj-caidas-app.ps1 (app, PROXIMA build, Android e iPhone).
# Luciano (20/11/2026): en Salud, la tarjeta del reloj con deteccion de caidas. Es SOLO informativa (no se conecta con ningun reloj, sin precios ni tiendas).
# Agrega src\RelojCaidasAviso.tsx y toca src\TarjetaSaludEntrada.tsx en dos puntos (un import y una linea debajo de "Salud y emergencias"). NO toca App.tsx, el mapa ni el Inicio.
import re, hashlib, subprocess
R = '/home/user/Murray/scripts/'
COMMIT_ARCHIVOS = 'e7e673e53e395929c4864d3b0d037740a639ef45'
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
def sha(ruta):
    return hashlib.sha256(open(ruta, 'rb').read()).hexdigest()
nuevos = [('RelojCaidasAviso.tsx', 'src\\RelojCaidasAviso.tsx')]
descargas = "$descargas = @(\n" + ',\n'.join("    @(%s, %s, %s)" % (psq('https://raw.githubusercontent.com/bickluciano-boop/Murray/%s/scripts/app/src/%s' % (COMMIT_ARCHIVOS, a)), psq(b), psq(sha(R + 'app/src/' + a))) for a, b in nuevos) + "\n)\n"
IMP_A = 'import { TarjetaSaludPantalla } from "./TarjetaSaludPantalla";\n'
IMP_B = 'import { RelojCaidasAviso } from "./RelojCaidasAviso";\n' + IMP_A
REN_A = '      </Pressable>\n      <TarjetaSaludPantalla\n'
REN_B = '      </Pressable>\n      <RelojCaidasAviso paleta={paleta} />\n      <TarjetaSaludPantalla\n'
filas = [('src\\TarjetaSaludEntrada.tsx', 'reloj: importar la tarjeta informativa del reloj con deteccion de caidas', IMP_A, IMP_B),
         ('src\\TarjetaSaludEntrada.tsx', 'reloj: la tarjeta debajo de "Salud y emergencias"', REN_A, REN_B)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-reloj-caidas-app.ps1 - App (PROXIMA build, Android e iPhone). Luciano (20/11/2026): en Salud, una tarjeta informativa sobre los relojes con deteccion de caidas.
# SOLO informacion: Ojo Guard no se conecta con ningun reloj; sin precios ni tiendas. Agrega src\\RelojCaidasAviso.tsx y toca src\\TarjetaSaludEntrada.tsx en dos puntos. No toca App.tsx, el mapa ni el Inicio.
# Requiere la tarjeta de salud (aplicar-tarjeta-salud-app.ps1). Respaldo .bak-reloj. Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba.
'''
i0 = base.index('$ErrorActionPreference'); j0 = base.index('Ok "Carpeta correcta"')
guardas = '''Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\TarjetaSaludEntrada.tsx"))) { Mal "No encuentro src\\TarjetaSaludEntrada.tsx. Falta aplicar primero la tarjeta de salud (aplicar-tarjeta-salud-app.ps1)."; return }
if ((Contar (Leer (Join-Path $raiz "src\\TarjetaSaludEntrada.tsx")).texto 'RelojCaidasAviso') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('$descargas = @()\n', descargas, 1).replace('.bak-version', '.bak-reloj')
MENSAJE = 'LISTO: la app compila bien. Salud y emergencias tiene debajo la tarjeta informativa del reloj con deteccion de caidas (sale en la PROXIMA build, Android e iPhone).'
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "%s"' % MENSAJE, cola)
assert MENSAJE in cola and 'bak-version' not in cola
total = cabeza + base[i0:j0] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕‹›→']
assert not bad, set(bad)
open(R + 'aplicar-reloj-caidas-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
# prueba: anclajes sobre el archivo REAL que instalo mi instalador anterior (commit e588644), no una muestra a mano
previo = subprocess.run(['git', '-C', R, 'show', 'e588644:scripts/app/src/TarjetaSaludEntrada.tsx'], capture_output=True, text=True, check=True).stdout.replace('\r\n', '\n')
for a, n, v, nv in filas:
    assert previo.count(v) == 1, (n, previo.count(v))
out = previo
for a, n, v, nv in filas:
    out = out.replace(v, nv)
actual = open(R + 'app/src/TarjetaSaludEntrada.tsx', encoding='utf-8').read().replace('\r\n', '\n')
assert out == actual, 'el resultado del instalador no coincide con el archivo del repo'
print('ok', len(total))
