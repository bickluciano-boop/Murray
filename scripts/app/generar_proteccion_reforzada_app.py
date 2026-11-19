# Genera scripts/aplicar-proteccion-reforzada-app.ps1 (app, PROXIMA build, solo Android).
# Luciano (18/11/2026): el Android quedo ~5 h (13:24 a 18:21) sin que la app se despertara (alarmas de 15 min cortadas, Modo Perdido/alarma/evidencia en espera hasta tocar el telefono). Dijo "si, preparalo".
# Agrega un interruptor "Protección reforzada" en Configuracion > Permisos de Android: un servicio en primer plano (ubicacion de bajisimo consumo que no se manda a ningun lado) para que Android no duerma la app.
# Agrega src\proteccionReforzada.ts y src\ProteccionReforzadaTarjeta.tsx; toca App.tsx (respaldo .bak-refuerzo). No cambia app.json: los permisos del servicio ya los puso aplicar-en-vivo-app.ps1.
import re, hashlib
R = '/home/user/Murray/scripts/'
COMMIT_ARCHIVOS = 'cabd949885a5fb9efb25762cfcb96d1e7ecaf297'
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
def sha(ruta):
    return hashlib.sha256(open(ruta, 'rb').read()).hexdigest()
nuevos = [('proteccionReforzada.ts', 'src\\proteccionReforzada.ts'), ('ProteccionReforzadaTarjeta.tsx', 'src\\ProteccionReforzadaTarjeta.tsx')]
descargas = "$descargas = @(\n" + ',\n'.join("    @(%s, %s, %s)" % (psq('https://raw.githubusercontent.com/bickluciano-boop/Murray/%s/scripts/app/src/%s' % (COMMIT_ARCHIVOS, a)), psq(b), psq(sha(R + 'app/src/' + a))) for a, b in nuevos) + "\n)\n"
IMP_A = 'import { watchFamilyLocation } from "./src/familyLocation";\n'
IMP_B = IMP_A + 'import { ProteccionReforzadaTarjeta } from "./src/ProteccionReforzadaTarjeta";\n'
SEC_A = '          {Platform.OS === "android" ? (\n            <CollapsibleSection grupo="permisos" title="Modo personalizado (Android)"'
SEC_B = ('          {Platform.OS === "android" ? (\n'
         '            <CollapsibleSection grupo="permisos" title="Protección reforzada" subtitle="Mantiene Ojo Guard despierto en este teléfono">\n'
         '              <ProteccionReforzadaTarjeta />\n'
         '            </CollapsibleSection>\n'
         '          ) : null}\n\n') + SEC_A
filas = [
 ('App.tsx', 'refuerzo: importar la tarjeta', IMP_A, IMP_B),
 ('App.tsx', 'refuerzo: la tarjeta va en Permisos de Android, antes de "Modo personalizado"', SEC_A, SEC_B),
]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-proteccion-reforzada-app.ps1 - App (PROXIMA build, solo Android). Luciano (18/11/2026): el Android quedo ~5 horas sin que la app se despertara y el Modo Perdido, la alarma y la evidencia pedidos desde el panel esperaron hasta tocar el telefono.
# Agrega en Configuracion > Permisos de Android un interruptor "Proteccion reforzada": un servicio en primer plano (ubicacion de muy bajo consumo que no se manda a ningun lado) para que Android no duerma la app. Muestra una notificacion fija y gasta un poco mas de bateria. Viene APAGADO.
# Agrega src\\proteccionReforzada.ts y src\\ProteccionReforzadaTarjeta.tsx; toca App.tsx (respaldo .bak-refuerzo). No cambia app.json. Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba.
'''
i0 = base.index('$ErrorActionPreference'); j0 = base.index('Ok "Carpeta correcta"')
guardas = '''Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "App.tsx"))) { Mal "No encuentro App.tsx en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "App.tsx")).texto 'ProteccionReforzadaTarjeta') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "app.json")).texto 'FOREGROUND_SERVICE_LOCATION') -eq 0) { Mal "Falta aplicar primero aplicar-en-vivo-app.ps1 (los permisos del servicio en primer plano)."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('$descargas = @()\n', descargas, 1).replace('.bak-version', '.bak-refuerzo')
MENSAJE = 'LISTO: la app compila bien. Configuracion > Permisos de Android tiene el interruptor Proteccion reforzada (viene apagado; sale en la PROXIMA build de Android).'
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "%s"' % MENSAJE, cola)
assert MENSAJE in cola and 'bak-version' not in cola
total = cabeza + base[i0:j0] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕']
assert not bad, set(bad)
open(R + 'aplicar-proteccion-reforzada-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
# prueba de los anclajes sobre las lineas reales que pego Luciano (App.tsx:66 y 4522-4527)
muestra = '''import { x } from "./a";
import { watchFamilyLocation } from "./src/familyLocation";
import { y } from "./b";
function P() { return (<>
            </CollapsibleSection>
          ) : null}

          {Platform.OS === "android" ? (
            <CollapsibleSection grupo="permisos" title="Modo personalizado (Android)" subtitle="Mejora la confiabilidad de las órdenes remotas">
              <Text style={styles.fieldHelp}>
</>); }
'''
for a, n, v, nv in filas:
    assert muestra.count(v) == 1, (n, muestra.count(v))
out = muestra
for a, n, v, nv in filas:
    out = out.replace(v, nv)
assert out.count('<ProteccionReforzadaTarjeta />') == 1 and out.count('Modo personalizado (Android)') == 1
print(out)
print('ok', len(total))
