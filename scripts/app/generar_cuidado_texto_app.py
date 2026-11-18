# Genera scripts/aplicar-cuidado-texto-app.ps1 (app, PROXIMA build): el texto de "Bateria baja y sin senal" en la tarjeta Cuidado decia "3 horas"; ahora dice lo que hace el servidor
# (cuidado-dueno + cuidado-lugares): la bateria baja avisa solo al dueno; el sin senal avisa a la familia a las 6 h (24 h si estaba en un lugar guardado).
import re
R = '/home/user/Murray/scripts/'
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
V = 'detalle="Avisa si tu batería baja de 15% o si pasan 3 horas sin señal."'
N = 'detalle="Te avisa a ti si tu batería baja de 15%. Avisa a tu familia si pasan 6 horas sin señal (24 h si estabas en un lugar guardado)."'
filas = [('src\\FamiliaPantalla.tsx', 'cuidado: texto de bateria baja y sin senal', V, N)]
# Con UNA sola fila, PowerShell aplana @(@(...)) y $c[0] pasa a ser la primera letra: hay que anteponer una coma (,@(...)).
cambios = "$cambios = @(\n" + ',\n'.join(("    ," if len(filas) == 1 else "    ") + "@(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
i0 = base.index('$ErrorActionPreference'); j0 = base.index('Ok "Carpeta correcta"')
cola = base[base.index('$descargas = @()'):].replace('.bak-version', '.bak-cuidadotexto')
MENSAJE = 'LISTO: la app compila bien. El texto de Bateria baja y sin senal dice lo que hace (sale en la PROXIMA build, Android e iPhone).'
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "%s"' % MENSAJE, cola)
assert MENSAJE in cola
cabeza = '''# aplicar-cuidado-texto-app.ps1 - App (PROXIMA build): el texto de "Bateria baja y sin senal" (tarjeta Cuidado) pasa de "3 horas" a lo que hace el servidor: avisa a ti si la bateria baja de 15% y a tu familia si pasan 6 horas sin senal (24 h si estabas en un lugar guardado).
# Toca src\\FamiliaPantalla.tsx (respaldo .bak-cuidadotexto). Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba.
'''
guardas = '''Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\FamiliaPantalla.tsx"))) { Mal "No encuentro src\\FamiliaPantalla.tsx en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\FamiliaPantalla.tsx")).texto '24 h si estabas en un lugar guardado') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
'''
total = cabeza + base[i0:j0] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕‹›']
assert not bad, set(bad)
open(R + 'aplicar-cuidado-texto-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
