# Genera scripts/aplicar-permisos-registro-app.ps1 (app, PROXIMA build, Android e iPhone).
# Luciano (20/11/2026): en Salud, la tarjeta del reloj con deteccion de caidas. Es SOLO informativa (no se conecta con ningun reloj, sin precios ni tiendas).
# Agrega src\RelojCaidasAviso.tsx y toca src\TarjetaSaludEntrada.tsx en dos puntos (un import y una linea debajo de "Salud y emergencias"). NO toca App.tsx, el mapa ni el Inicio.
import re, hashlib, subprocess
R = '/home/user/Murray/scripts/'
COMMIT_ARCHIVOS = 'b67472b191d3c2cbd6fe661f7db27f454f307abf'
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
def sha(ruta):
    return hashlib.sha256(open(ruta, 'rb').read()).hexdigest()
nuevos = [('TarjetaPermisos.tsx', 'src\\TarjetaPermisos.tsx'), ('compartirRegistro.ts', 'src\\compartirRegistro.ts')]
descargas = "$descargas = @(\n" + ',\n'.join("    @(%s, %s, %s)" % (psq('https://raw.githubusercontent.com/bickluciano-boop/Murray/%s/scripts/app/src/%s' % (COMMIT_ARCHIVOS, a)), psq(b), psq(sha(R + 'app/src/' + a))) for a, b in nuevos) + "\n)\n"
IMP_A = 'import { TarjetaSaludAjustes } from "./src/TarjetaSaludEntrada";\n'
IMP_B = IMP_A + 'import { TarjetaPermisos } from "./src/TarjetaPermisos";\nimport { compartirRegistroSoporte } from "./src/compartirRegistro";\n'
HUB_A = ('''              <BandaPermisos
                paleta={P}
                android={Platform.OS === "android"}
                permisosEnOrden={permisosEnOrden}
                permisosTotal={4}
                onPress={() => elegirGrupo("permisos")}
              />
              <TarjetaSaludAjustes paleta={P} />
''')
HUB_B = HUB_A.replace('<BandaPermisos', '<TarjetaPermisos', 1)
REG_A = '            </Plegable>\n            <Pressable onPress={onPermissions} style={[styles.secondaryButton, { marginTop: 14 }]}>\n'
REG_B = '''            </Plegable>
            <Pressable
              accessibilityRole="button"
              onPress={() =>
                void compartirRegistroSoporte({
                  version: `${APP_VERSION} (build ${APP_BUILD_LABEL})`,
                  sistema: Platform.OS,
                  aviso: Platform.OS === "android" ? describirRastroDeAviso(fullScreenAlertTrace, hasFullScreenAlertPermission()) : "",
                  historial: fullScreenAlertDiagnostics.map(
                    (e) => `${formatearFecha(e.at)} | ${e.reason} | modulo=${e.moduleFound ? "si" : "NO"} | resultado=${e.result ? "OK" : "fallo"}${e.error ? ` | ${e.error}` : ""}`,
                  ),
                  camaraNativa: nativeCaptureDiagnostics,
                  pasos: pasosCaptura,
                })
              }
              style={[styles.secondaryButton, { marginTop: 14 }]}
            >
              <Text style={styles.secondaryButtonText}>Compartir registro con soporte</Text>
            </Pressable>
            <Pressable onPress={onPermissions} style={[styles.secondaryButton, { marginTop: 14 }]}>
'''
filas = [('App.tsx', 'registro: importar la tarjeta de permisos y el compartir registro', IMP_A, IMP_B),
         ('App.tsx', 'permisos: la franja de Ajustes pasa a tarjeta (el Inicio no cambia)', HUB_A, HUB_B),
         ('App.tsx', 'registro: boton Compartir registro con soporte', REG_A, REG_B)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-permisos-registro-app.ps1 - App (PROXIMA build, Android e iPhone). Luciano (20/11/2026): (1) "Permisos de Android" como tarjeta en Ajustes (la franja verde del Inicio NO cambia); (2) boton "Compartir registro con soporte" en los registros tecnicos.
# Agrega src\\TarjetaPermisos.tsx y src\\compartirRegistro.ts; toca App.tsx en tres puntos (imports, la franja de Ajustes y el boton). No toca el mapa ni el Inicio. No agrega librerias.
# Requiere la tarjeta de salud (aplicar-tarjeta-salud-app.ps1). Respaldo .bak-permisos. Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba.
'''
i0 = base.index('$ErrorActionPreference'); j0 = base.index('Ok "Carpeta correcta"')
guardas = '''Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "App.tsx"))) { Mal "No encuentro App.tsx en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "App.tsx")).texto 'compartirRegistroSoporte') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "App.tsx")).texto 'TarjetaSaludAjustes') -eq 0) { Mal "Falta aplicar primero la tarjeta de salud (aplicar-tarjeta-salud-app.ps1)."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('$descargas = @()\n', descargas, 1).replace('.bak-version', '.bak-permisos')
MENSAJE = 'LISTO: la app compila bien. Ajustes tiene Permisos de Android como tarjeta y los registros tecnicos tienen el boton Compartir registro con soporte (sale en la PROXIMA build, Android e iPhone).'
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "%s"' % MENSAJE, cola)
assert MENSAJE in cola and 'bak-version' not in cola
total = cabeza + base[i0:j0] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕‹›→']
assert not bad, set(bad)
open(R + 'aplicar-permisos-registro-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
muestra = '''import { ProteccionReforzadaTarjeta } from "./src/ProteccionReforzadaTarjeta";
import { TarjetaSaludAjustes } from "./src/TarjetaSaludEntrada";
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
              <TarjetaSaludAjustes paleta={P} />
              <TarjetasConfiguracion
                paleta={P}
              />
            </>
          ) : null}
          {grupoActual === "inicio" ? (
              <BandaPermisos
                paleta={P}
                android={Platform.OS === "android"}
                permisosEnOrden={permisosEnOrden}
                permisosTotal={4}
                soloSiFalta
                onPress={() => elegirGrupo("permisos")}
              />
          ) : null}
            <Plegable titulo="Registros tecnicos (para soporte)" paleta={P}>
              <Text>x</Text>
            </Plegable>
            <Pressable onPress={onPermissions} style={[styles.secondaryButton, { marginTop: 14 }]}>
              <Text style={styles.secondaryButtonText}>Revisar permisos</Text>
            </Pressable>
</>); }
'''
for a, n, v, nv in filas:
    assert muestra.count(v) == 1, (n, muestra.count(v))
out = muestra
for a, n, v, nv in filas:
    out = out.replace(v, nv)
assert out.count('<TarjetaPermisos') == 1 and out.count('<BandaPermisos') == 1, 'la banda del Inicio (soloSiFalta) debe quedar igual'
assert 'soloSiFalta' in out
print('ok', len(total))
