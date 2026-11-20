# Genera scripts/aplicar-tarjetas-compactas-app.ps1 (app, PROXIMA build, Android e iPhone).
# Luciano (20/11/2026): en Salud, la tarjeta del reloj con deteccion de caidas. Es SOLO informativa (no se conecta con ningun reloj, sin precios ni tiendas).
# Agrega src\RelojCaidasAviso.tsx y toca src\TarjetaSaludEntrada.tsx en dos puntos (un import y una linea debajo de "Salud y emergencias"). NO toca App.tsx, el mapa ni el Inicio.
import re, hashlib, subprocess
R = '/home/user/Murray/scripts/'
COMMIT_ARCHIVOS = '67241453a498bcc446de97418f972fc8aa460f4e'
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
def sha(ruta):
    return hashlib.sha256(open(ruta, 'rb').read()).hexdigest()
nuevos = [('RelojCaidasAviso.tsx', 'src\\RelojCaidasAviso.tsx'), ('TarjetaSaludEntrada.tsx', 'src\\TarjetaSaludEntrada.tsx')]
descargas = "$descargas = @(\n" + ',\n'.join("    @(%s, %s, %s)" % (psq('https://raw.githubusercontent.com/bickluciano-boop/Murray/%s/scripts/app/src/%s' % (COMMIT_ARCHIVOS, a)), psq(b), psq(sha(R + 'app/src/' + a))) for a, b in nuevos) + "\n)\n"
filas = []
cambios = "$cambios = @()\n"
cabeza = '''# aplicar-tarjetas-compactas-app.ps1 - App (PROXIMA build, Android e iPhone). Luciano (20/11/2026): las tarjetas "Salud y emergencias" y "Reloj con deteccion de caidas" mas chicas y delicadas.
# SOLO el aspecto: reemplaza src\\TarjetaSaludEntrada.tsx y src\\RelojCaidasAviso.tsx (no cambia ninguna funcion). No toca App.tsx, el mapa ni el Inicio.
# Requiere haber aplicado antes la tarjeta de salud y la del reloj. Respaldo .bak-compacta. Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba.
'''
i0 = base.index('$ErrorActionPreference'); j0 = base.index('Ok "Carpeta correcta"')
guardas = '''Ok "Carpeta correcta"
foreach ($f in @("src\\TarjetaSaludEntrada.tsx", "src\\RelojCaidasAviso.tsx")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + ". Falta aplicar primero la tarjeta de salud y la del reloj."); return } }
if ((Contar (Leer (Join-Path $raiz "src\\TarjetaSaludEntrada.tsx")).texto 'Tarjetas compactas') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('$descargas = @()\n', descargas, 1).replace('.bak-version', '.bak-compacta')
MENSAJE = 'LISTO: la app compila bien. Las tarjetas de Salud y del reloj quedan mas chicas y delicadas (sale en la PROXIMA build, Android e iPhone).'
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "%s"' % MENSAJE, cola)
assert MENSAJE in cola and 'bak-version' not in cola
total = cabeza + base[i0:j0] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕‹›→']
assert not bad, set(bad)
open(R + 'aplicar-tarjetas-compactas-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
