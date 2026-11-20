# Genera scripts/aplicar-reloj-video-arriba-app.ps1 (app, PROXIMA build, Android e iPhone).
# Luciano (20/11/2026): en Salud, la tarjeta del reloj con deteccion de caidas. Es SOLO informativa (no se conecta con ningun reloj, sin precios ni tiendas).
# Agrega src\RelojCaidasAviso.tsx y toca src\TarjetaSaludEntrada.tsx en dos puntos (un import y una linea debajo de "Salud y emergencias"). NO toca App.tsx, el mapa ni el Inicio.
import re, hashlib, subprocess
R = '/home/user/Murray/scripts/'
COMMIT_ARCHIVOS = 'd31e2f85c68a523300741191a9bc6bd5eac488af'
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
def sha(ruta):
    return hashlib.sha256(open(ruta, 'rb').read()).hexdigest()
nuevos = [('RelojCaidasAviso.tsx', 'src\\RelojCaidasAviso.tsx')]
# UNA sola fila: lleva la coma delante (si no, PowerShell la aplana: "No se pudo descargar bien t.")
descargas = "$descargas = @(\n    ," + ',\n    ,'.join("@(%s, %s, %s)" % (psq('https://raw.githubusercontent.com/bickluciano-boop/Murray/%s/scripts/app/src/%s' % (COMMIT_ARCHIVOS, a)), psq(b), psq(sha(R + 'app/src/' + a))) for a, b in nuevos) + "\n)\n"
filas = []
cambios = "$cambios = @()\n"
cabeza = '''# aplicar-reloj-video-arriba-app.ps1 - App (PROXIMA build, Android e iPhone). Luciano (20/11/2026): en la tarjeta del reloj de Ajustes, el boton Ver presentacion (el video, sin sonido) pasa ARRIBA, antes de los textos, para encontrarlo sin bajar.
# Reemplaza src\\RelojCaidasAviso.tsx (suma el boton "Ver presentacion": solo se carga cuando se toca). Usa react-native-webview, que la app YA tiene: no agrega librerias ni cambia codigo nativo. No toca App.tsx, el mapa ni el Inicio.
# Requiere haber aplicado antes la tarjeta del reloj. Respaldo .bak-relojarriba. Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba.
'''
i0 = base.index('$ErrorActionPreference'); j0 = base.index('Ok "Carpeta correcta"')
guardas = '''Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\RelojCaidasAviso.tsx"))) { Mal "No encuentro src\\RelojCaidasAviso.tsx. Falta aplicar primero la tarjeta del reloj con el video (aplicar-reloj-video-app.ps1)."; return }
if ((Contar (Leer (Join-Path $raiz "src\\RelojCaidasAviso.tsx")).texto 'Ver presentación arriba') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\RelojCaidasAviso.tsx")).texto 'htmlDelVideo') -eq 0) { Mal "Falta aplicar primero aplicar-reloj-video-app.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "package.json")).texto 'react-native-webview') -eq 0) { Mal "La app no tiene react-native-webview en package.json. No toco nada. Mandame esta pantalla."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('$descargas = @()\n', descargas, 1).replace('.bak-version', '.bak-relojarriba')
MENSAJE = 'LISTO: la app compila bien. En la tarjeta del reloj, Ver presentacion queda arriba, antes de los textos (sale en la PROXIMA build, Android e iPhone).'
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "%s"' % MENSAJE, cola)
assert MENSAJE in cola and 'bak-version' not in cola
total = cabeza + base[i0:j0] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕‹›→']
assert not bad, set(bad)
open(R + 'aplicar-reloj-video-arriba-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
