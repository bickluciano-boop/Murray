# Genera scripts/aplicar-buscador-salud-reloj-app.ps1 (app, PROXIMA build, Android e iPhone).
# Luciano (20/11/2026): en Salud, la tarjeta del reloj con deteccion de caidas. Es SOLO informativa (no se conecta con ningun reloj, sin precios ni tiendas).
# Agrega src\RelojCaidasAviso.tsx y toca src\TarjetaSaludEntrada.tsx en dos puntos (un import y una linea debajo de "Salud y emergencias"). NO toca App.tsx, el mapa ni el Inicio.
import re, hashlib, subprocess
R = '/home/user/Murray/scripts/'
COMMIT_ARCHIVOS = '9c7d7fab728229b88ef41aae86307085b31d5a74'
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
def sha(ruta):
    return hashlib.sha256(open(ruta, 'rb').read()).hexdigest()
nuevos = [('aperturasAjustes.ts', 'src\\aperturasAjustes.ts'), ('indiceBusqueda.ts', 'src\\indiceBusqueda.ts'), ('BuscadorAjustes.tsx', 'src\\BuscadorAjustes.tsx'), ('TarjetaSaludEntrada.tsx', 'src\\TarjetaSaludEntrada.tsx'), ('RelojCaidasAviso.tsx', 'src\\RelojCaidasAviso.tsx')]
descargas = "$descargas = @(\n" + ',\n'.join("    @(%s, %s, %s)" % (psq('https://raw.githubusercontent.com/bickluciano-boop/Murray/%s/scripts/app/src/%s' % (COMMIT_ARCHIVOS, a)), psq(b), psq(sha(R + 'app/src/' + a))) for a, b in nuevos) + "\n)\n"
filas = []
cambios = "$cambios = @()\n"
cabeza = '''# aplicar-buscador-salud-reloj-app.ps1 - App (PROXIMA build, Android e iPhone). Luciano (20/11/2026): que el buscador de Ajustes tambien encuentre "Salud y emergencias" y el "Reloj" y los abra solos.
# Agrega src\\aperturasAjustes.ts y reemplaza src\\indiceBusqueda.ts, src\\BuscadorAjustes.tsx, src\\TarjetaSaludEntrada.tsx y src\\RelojCaidasAviso.tsx (las dos tarjetas solo suman una linea que las anota para que el buscador las abra). Mejora el ranking de errores de tipeo ("alerjias") e ignora palabras vacias ("se cae"). No cambia ninguna funcion, el mapa ni el Inicio. No agrega librerias.
# Requiere aplicar-buscador-ajustes-app.ps1 y el video del reloj. Respaldo .bak-busqueda2. Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba.
'''
i0 = base.index('$ErrorActionPreference'); j0 = base.index('Ok "Carpeta correcta"')
guardas = '''Ok "Carpeta correcta"
foreach ($f in @("src\\BuscadorAjustes.tsx", "src\\indiceBusqueda.ts", "src\\TarjetaSaludEntrada.tsx", "src\\RelojCaidasAviso.tsx")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + ". Falta aplicar antes el buscador de Ajustes y la tarjeta del reloj con el video."); return } }
if ((Contar (Leer (Join-Path $raiz "src\\BuscadorAjustes.tsx")).texto 'abrirDesdeBuscador') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\RelojCaidasAviso.tsx")).texto 'htmlDelVideo') -eq 0) { Mal "Falta aplicar primero el video del reloj (aplicar-reloj-video-app.ps1)."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('$descargas = @()\n', descargas, 1).replace('.bak-version', '.bak-busqueda2')
MENSAJE = 'LISTO: la app compila bien. El buscador de Ajustes encuentra Salud y emergencias y el Reloj y los abre solo (sale en la PROXIMA build, Android e iPhone).'
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "%s"' % MENSAJE, cola)
assert MENSAJE in cola and 'bak-version' not in cola
total = cabeza + base[i0:j0] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕‹›→']
assert not bad, set(bad)
open(R + 'aplicar-buscador-salud-reloj-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
