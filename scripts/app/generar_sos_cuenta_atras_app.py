# Genera scripts/aplicar-sos-cuenta-atras-app.ps1 (app, PROXIMA build). Luciano (14/11/2026): sono el SOS en el telefono de su familia sin que el lo pidiera; el servidor mostro que salio de su iPhone
# en su casa, probablemente por tres toques en la espalda (atajo "SOS Ojo Guard"). Ahora el SOS pedido desde el enlace del atajo (toque en la espalda, Siri, pantalla de bloqueo) muestra
# 5 segundos de cuenta regresiva con un boton enorme "Cancelar"; si no se toca nada, sale solo. El boton rojo (3 s) y los dos botones de volumen de Android siguen igual.
import re, hashlib
R = '/home/user/Murray/scripts/'
COMMIT_ARCHIVOS = '18440b6288a81345237016e0447b081399fe66f0'
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
def sha(ruta):
    return hashlib.sha256(open(ruta, 'rb').read()).hexdigest()
nuevos = [('sosCuentaAtras.ts', 'src\\sosCuentaAtras.ts'), ('SosCuentaAtrasPantalla.tsx', 'src\\SosCuentaAtrasPantalla.tsx')]
descargas = "$descargas = @(\n" + ',\n'.join("    @(%s, %s, %s)" % (psq('https://raw.githubusercontent.com/bickluciano-boop/Murray/%s/scripts/app/src/%s' % (COMMIT_ARCHIVOS, a)), psq(b), psq(sha(R + 'app/src/' + a))) for a, b in nuevos) + "\n)\n"
filas = [
 ('src\\sosTask.ts', 'sos: importar la cuenta regresiva', 'import AsyncStorage from "@react-native-async-storage/async-storage";\n',
  'import AsyncStorage from "@react-native-async-storage/async-storage";\nimport { iniciarCuentaAtras } from "./sosCuentaAtras";\n'),
 ('src\\sosTask.ts', 'sos: el enlace del atajo empieza la cuenta regresiva (antes mandaba el SOS al instante)',
  '  await AsyncStorage.setItem(CLAVE_USO_ATAJO, new Date().toISOString()).catch(() => undefined);\n  void triggerSos();\n',
  '  await AsyncStorage.setItem(CLAVE_USO_ATAJO, new Date().toISOString()).catch(() => undefined);\n'
  '  // Un toque sin querer en la espalda del iPhone no tiene que hacer sonar la sirena de toda la familia: hay 5 segundos para cancelar (pantalla SosCuentaAtrasPantalla.tsx).\n'
  '  // Si la pantalla no esta a la vista, la cuenta igual corre y el SOS sale solo al llegar a cero.\n'
  '  iniciarCuentaAtras(() => void triggerSos());\n'),
 ('src\\SosBlock.tsx', 'sos: importar la pantalla de la cuenta regresiva', 'import { useCallback, useEffect, useRef, useState } from "react";\n',
  'import { useCallback, useEffect, useRef, useState } from "react";\nimport { SosCuentaAtras } from "./SosCuentaAtrasPantalla";\n'),
 ('src\\SosBlock.tsx', 'sos: la pantalla de la cuenta regresiva junto al boton de la barra',
  '  return <SosBlock enrollment={vinculo} visible={conFamilia} cuadrado paleta={paleta} botones={botones} />;\n}',
  '  return (\n    <>\n      <SosBlock enrollment={vinculo} visible={conFamilia} cuadrado paleta={paleta} botones={botones} />\n      <SosCuentaAtras />\n    </>\n  );\n}'),
]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-sos-cuenta-atras-app.ps1 - App (PROXIMA build, iPhone y Android). Luciano (14/11/2026): el SOS sono en el telefono de su familia sin que lo pidiera; salio de su iPhone en su casa, por el atajo "SOS Ojo Guard" (toque en la espalda).
# Ahora el SOS pedido desde el enlace del atajo (toque en la espalda, Siri, pantalla de bloqueo) muestra una cuenta regresiva de 5 segundos con un boton enorme "Cancelar" y otro "Enviar ya"; si no se toca nada, el SOS sale solo.
# El boton rojo (mantenerlo 3 segundos) y los dos botones de volumen de Android no cambian. Agrega src\\sosCuentaAtras.ts y src\\SosCuentaAtrasPantalla.tsx; toca src\\sosTask.ts y src\\SosBlock.tsx (respaldo .bak-sos5).
# Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba.
'''
i0 = base.index('$ErrorActionPreference'); j0 = base.index('Ok "Carpeta correcta"')
guardas = '''Ok "Carpeta correcta"
foreach ($f in @("src\\sosTask.ts", "src\\SosBlock.tsx")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\\sosTask.ts")).texto 'iniciarCuentaAtras') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('$descargas = @()\n', descargas, 1).replace('.bak-version', '.bak-sos5')
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "LISTO: la app compila bien. El SOS del atajo ahora tiene 5 segundos para cancelar (sale en la PROXIMA build, Android e iPhone)."', cola)
assert 'bak-version' not in cola and 'raw.githubusercontent' in cola
total = cabeza + base[i0:j0] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕']
assert not bad, set(bad)
open(R + 'aplicar-sos-cuenta-atras-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
# replicas sobre las copias del repo
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
for archivo, origen in (('src\\sosTask.ts', R + 'familia/sosTask.ts'), ('src\\SosBlock.tsx', R + 'familia/SosBlock.tsx')):
    t = open(origen, encoding='utf-8').read().replace('\r\n', '\n')
    for a, nombre, v, nv in filas:
        if a == archivo:
            assert t.count(v) == 1, (nombre, t.count(v))
    for a, nombre, v, nv in filas:
        if a == archivo:
            t = t.replace(v, nv)
    open(S + 'sos5-' + archivo.split('\\')[-1], 'w', encoding='utf-8').write(t)
print('ok', len(total))
