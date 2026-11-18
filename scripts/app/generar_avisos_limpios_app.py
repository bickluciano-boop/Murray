# Genera scripts/aplicar-avisos-limpios-app.ps1 (app, PROXIMA build). Requiere aplicar-sos-discreto-app.ps1 (usa su pantalla, que esta montada en toda la app).
# Luciano (18/11/2026): "es medio tedioso tantas notificaciones" (en el iPhone habia 21 apiladas de medicamentos de dias anteriores y el aviso nuevo quedaba enterrado).
# Ahora, cada vez que se abre la app (y al arrancar), se sacan de la pantalla de notificaciones los avisos de medicamentos, del "Buen dia" y el aviso neutro de la cuenta regresiva del SOS.
# No se toca el SOS de la familia, las alarmas ni los demas avisos. Agrega src\limpiarAvisos.ts; toca src\SosCuentaAtrasPantalla.tsx (respaldo .bak-avisoslimpios).
import re, hashlib
R = '/home/user/Murray/scripts/'
COMMIT_ARCHIVOS = '387fbf7dbb50510d3ba86c06698303d946d49244'
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
def sha(ruta):
    return hashlib.sha256(open(ruta, 'rb').read()).hexdigest()
nuevos = [('limpiarAvisos.ts', 'src\\limpiarAvisos.ts')]
descargas = "$descargas = @(\n" + ',\n'.join("    ,@(%s, %s, %s)" % (psq('https://raw.githubusercontent.com/bickluciano-boop/Murray/%s/scripts/app/src/%s' % (COMMIT_ARCHIVOS, a)), psq(b), psq(sha(R + 'app/src/' + a))) for a, b in nuevos) + "\n)\n"
P = 'src\\SosCuentaAtrasPantalla.tsx'
filas = [
 (P, 'avisos limpios: importar el limpiador', 'import { cancelarCuentaAtras, enviarAhora, escucharCuentaAtras, type EstadoCuentaAtras } from "./sosCuentaAtras";\n',
  'import { iniciarLimpiezaDeAvisos } from "./limpiarAvisos";\nimport { cancelarCuentaAtras, enviarAhora, escucharCuentaAtras, type EstadoCuentaAtras } from "./sosCuentaAtras";\n'),
 (P, 'avisos limpios: al arrancar y al volver a verse la app se sacan los avisos ya vistos', '  useEffect(() => escucharCuentaAtras(setCuenta), []);\n',
  '  useEffect(() => escucharCuentaAtras(setCuenta), []);\n  // Esta pantalla esta montada en toda la app: de paso limpia los avisos de medicamentos / Buen dia ya vistos (ver limpiarAvisos.ts).\n  useEffect(() => iniciarLimpiezaDeAvisos(), []);\n'),
]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-avisos-limpios-app.ps1 - App (PROXIMA build). Luciano (18/11/2026): "es medio tedioso tantas notificaciones": habia 21 apiladas de medicamentos de dias anteriores y el aviso nuevo quedaba enterrado.
# Cada vez que se abre la app se sacan de la pantalla de notificaciones los avisos de medicamentos, del "Buen dia" y el aviso neutro del SOS (abrir la app es verlos). No se toca el SOS de la familia, las alarmas ni los demas avisos.
# Requiere aplicar-sos-discreto-app.ps1. Agrega src\\limpiarAvisos.ts; toca src\\SosCuentaAtrasPantalla.tsx (respaldo .bak-avisoslimpios). Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba.
'''
i0 = base.index('$ErrorActionPreference'); j0 = base.index('Ok "Carpeta correcta"')
guardas = '''Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\SosCuentaAtrasPantalla.tsx"))) { Mal "No encuentro src\\SosCuentaAtrasPantalla.tsx. Falta aplicar primero aplicar-sos-cuenta-atras-app.ps1 y aplicar-sos-discreto-app.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\\SosCuentaAtrasPantalla.tsx")).texto 'iniciarLimpiezaDeAvisos') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\sosCuentaAtras.ts")).texto 'CUENTA_ATRAS_BLOQUEADO_SEGUNDOS') -eq 0) { Mal "Falta aplicar primero aplicar-sos-discreto-app.ps1."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('$descargas = @()\n', descargas, 1).replace('.bak-version', '.bak-avisoslimpios')
MENSAJE = 'LISTO: la app compila bien. Los avisos de medicamentos y del Buen dia ya vistos se limpian al abrir la app (sale en la PROXIMA build, Android e iPhone).'
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "%s"' % MENSAJE, cola)
assert MENSAJE in cola and 'bak-version' not in cola
total = cabeza + base[i0:j0] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕']
assert not bad, set(bad)
open(R + 'aplicar-avisos-limpios-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
# replica: aplicar las dos filas al archivo del repo y comprobar tipos
t = open(R + 'app/src/SosCuentaAtrasPantalla.tsx', encoding='utf-8').read().replace('\r\n', '\n')
for a, n, v, nv in filas:
    assert t.count(v) == 1, (n, t.count(v))
for a, n, v, nv in filas:
    t = t.replace(v, nv)
open('/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/tcx/src/SosCuentaAtrasPantalla.tsx', 'w', encoding='utf-8').write(t)
print('ok', len(total))
