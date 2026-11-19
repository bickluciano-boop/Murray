# Genera scripts/aplicar-tarjeta-salud-app.ps1 (app, PROXIMA build, Android e iPhone).
# Luciano (19/11/2026): "una tarjeta donde tenga adentro todos los datos: medicamentos, credencial de la obra social, grupo sanguineo, todo lo que te pueden pedir cuando tenes un accidente". Lista de campos APROBADA por el.
# Fase 1: solo en el telefono (sin servidor). Agrega src\tarjetaSalud.ts (logica y guardado), src\TarjetaSaludPantalla.tsx (ver / editar, camara propia para la credencial) y src\TarjetaSaludEntrada.tsx (la entrada "Salud y emergencias" arriba de las tarjetas de Ajustes).
# Toca App.tsx en DOS puntos (un import y una linea en el menu de Ajustes). NO toca el mapa ni el Inicio (regla firme de Luciano: "lo que se ve en el mapa no se toca nada").
import re, hashlib
R = '/home/user/Murray/scripts/'
COMMIT_ARCHIVOS = 'e5886444407b0ab69dfd8e0932865eb418dec39d'
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
def sha(ruta):
    return hashlib.sha256(open(ruta, 'rb').read()).hexdigest()
nuevos = [('tarjetaSalud.ts', 'src\\tarjetaSalud.ts'), ('TarjetaSaludPantalla.tsx', 'src\\TarjetaSaludPantalla.tsx'), ('TarjetaSaludEntrada.tsx', 'src\\TarjetaSaludEntrada.tsx')]
descargas = "$descargas = @(\n" + ',\n'.join("    @(%s, %s, %s)" % (psq('https://raw.githubusercontent.com/bickluciano-boop/Murray/%s/scripts/app/src/%s' % (COMMIT_ARCHIVOS, a)), psq(b), psq(sha(R + 'app/src/' + a))) for a, b in nuevos) + "\n)\n"
IMP_A = 'import { ProteccionReforzadaTarjeta } from "./src/ProteccionReforzadaTarjeta";\n'
IMP_B = IMP_A + 'import { TarjetaSaludAjustes } from "./src/TarjetaSaludEntrada";\n'
# menu de Ajustes (lineas reales que pego Luciano, App.tsx ~3817): dentro de <> ... </> junto a <BandaPermisos .../>
HUB_A = '              <TarjetasConfiguracion\n                paleta={P}\n                android={Platform.OS === "android"}\n                intentos={evidenceAttempts.length}'
HUB_B = '              <TarjetaSaludAjustes paleta={P} />\n' + HUB_A
filas = [('App.tsx', 'salud: importar la entrada de la tarjeta de salud', IMP_A, IMP_B),
         ('App.tsx', 'salud: la entrada "Salud y emergencias" arriba de las tarjetas de Ajustes', HUB_A, HUB_B)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-tarjeta-salud-app.ps1 - App (PROXIMA build, Android e iPhone). Luciano (19/11/2026): una tarjeta de salud con lo que te piden en una emergencia (sangre, alergias, medicamentos, obra social con foto de la credencial, a quien avisar).
# FASE 1, solo en el telefono: nada sale del telefono. Agrega src\\tarjetaSalud.ts, src\\TarjetaSaludPantalla.tsx y src\\TarjetaSaludEntrada.tsx; toca App.tsx en dos puntos (un import y la entrada "Salud y emergencias" arriba de las tarjetas de Ajustes). No toca el mapa ni el Inicio.
# Requiere los remedios (aplicar-remedios-app.ps1) y la identidad (VerificarIdentidad.tsx). Respaldo .bak-salud. Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba.
'''
i0 = base.index('$ErrorActionPreference'); j0 = base.index('Ok "Carpeta correcta"')
guardas = '''Ok "Carpeta correcta"
foreach ($f in @("App.tsx", "src\\remoteApi.ts", "src\\remoteStorage.ts", "src\\VerificarIdentidad.tsx")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "App.tsx")).texto 'TarjetaSaludAjustes') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\remoteApi.ts")).texto 'export async function fetchRemedios') -eq 0) { Mal "Falta aplicar primero los remedios (aplicar-remedios-app.ps1)."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('$descargas = @()\n', descargas, 1).replace('.bak-version', '.bak-salud')
MENSAJE = 'LISTO: la app compila bien. Ajustes tiene la entrada "Salud y emergencias" con la tarjeta de salud (sale en la PROXIMA build, Android e iPhone).'
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "%s"' % MENSAJE, cola)
assert MENSAJE in cola and 'bak-version' not in cola
total = cabeza + base[i0:j0] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕‹›→']
assert not bad, set(bad)
open(R + 'aplicar-tarjeta-salud-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
# prueba de los anclajes sobre las lineas reales que pego Luciano (App.tsx 3817-3830) y sobre el import que dejo mi instalador anterior
prev = open(R + 'aplicar-proteccion-reforzada-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
assert prev.count(IMP_B.split('\n')[0] + '\n') >= 1 or IMP_A.strip() in prev, 'el import de la proteccion reforzada no coincide'
muestra = '''import { watchFamilyLocation } from "./src/familyLocation";
import { ProteccionReforzadaTarjeta } from "./src/ProteccionReforzadaTarjeta";
function X() { return (<>
          {grupoActual === "configuracion" ? (
            <>
              <BandaPermisos
                paleta={P}
                android={Platform.OS === "android"}
                permisosEnOrden={permisosEnOrden}
                permisosTotal={4}
                onPress={() => elegirGrupo("permisos")}
              />
              <TarjetasConfiguracion
                paleta={P}
                android={Platform.OS === "android"}
                intentos={evidenceAttempts.length}
                pendientes={pendingCount}
              />
            </>
          ) : null}
</>); }
'''
for a, n, v, nv in filas:
    assert muestra.count(v) == 1, (n, muestra.count(v))
out = muestra
for a, n, v, nv in filas:
    out = out.replace(v, nv)
print(out)
print('ok', len(total))
