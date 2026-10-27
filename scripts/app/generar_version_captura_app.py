# Genera scripts/aplicar-version-captura-app.ps1: app (proxima build): boton "Actualizar version" (Android), pasos de la captura de evidencia anotados (iPhone y Android)
# con entrega de la foto frontal si se agota el tiempo, y sin el texto de Android del ahorro de bateria en iPhone.
import re
R = '/home/user/Murray/scripts/'
APPSRC = '/root/.claude/uploads/459a989e-0585-521a-8ee1-3a385ef7024a/ee1c9a0c-App-actual-263510.tsx'
base = open(R + 'aplicar-captura-reintentos-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
app = open(APPSRC, encoding='utf-8').read().replace('\r\n', '\n')

filas = []
def cambio(rotulo, viejo, nuevo):
    assert app.count(viejo) == 1, (rotulo, app.count(viejo))
    filas.append(('App.tsx', rotulo, viejo, nuevo))

cambio('ayudas del registro de pasos de la captura',
 'const CLAVE_BIENVENIDA_VISTA = "ojo_bienvenida_vista_v1";',
 r'''const CLAVE_BIENVENIDA_VISTA = "ojo_bienvenida_vista_v1";
// Pasos de la captura de evidencia, para soporte. En iPhone no hay registro nativo de camara: sin esto no se sabe en que paso se traba.
const CLAVE_PASOS_CAPTURA = "ojo_captura_pasos_v1";
async function anotarPasoCaptura(texto: string) {
  try {
    const previo = JSON.parse((await AsyncStorage.getItem(CLAVE_PASOS_CAPTURA)) ?? "[]") as string[];
    const nuevo = [`${new Date().toISOString()} ${Platform.OS} ${texto}`, ...previo].slice(0, 24);
    await AsyncStorage.setItem(CLAVE_PASOS_CAPTURA, JSON.stringify(nuevo));
  } catch {
    // El registro es solo para soporte: si falla, la captura sigue igual.
  }
}
async function leerPasosCaptura(): Promise<string[]> {
  try {
    const previo = JSON.parse((await AsyncStorage.getItem(CLAVE_PASOS_CAPTURA)) ?? "[]") as unknown;
    return Array.isArray(previo) ? previo.map((x) => String(x)) : [];
  } catch {
    return [];
  }
}
// Boton "Actualizar version" de Ajustes (Android): consulta la ultima version publicada en ojoguard.app.
const URL_VERSION_APP = "https://ojoguard.app/api/app/version";
const URL_DESCARGA_APP = "https://ojoguard.app/descargar";''')

cambio('paso actual de la captura (referencia)',
 '  const frontPhotoRef = useRef<string | null>(null);',
 '''  const frontPhotoRef = useRef<string | null>(null);
  const capturaPasoRef = useRef("sin empezar");''')

cambio('pedido remoto: anota el primer paso',
 '''        setCameraFacing("front");
        setAlertState("capturing");
        await startAudioEvidence();
        return await new Promise<{''',
 '''        setCameraFacing("front");
        setAlertState("capturing");
        await startAudioEvidence();
        capturaPasoRef.current = "esperando camara frontal";
        void anotarPasoCaptura("pedido remoto: esperando camara frontal");
        return await new Promise<{''')

cambio('tiempo agotado: anota el paso y entrega la frontal si ya salio',
 '''          const timeout = setTimeout(() => {
            remoteCaptureRef.current = null;
            setCameraActive(false);
            setAlertState("failed");
            void stopAudioEvidence();
            dismissFullScreenAlert();
            reject(new Error("remote_capture_timeout"));
          }, 30_000);''',
 '''          const timeout = setTimeout(() => {
            const paso = capturaPasoRef.current;
            const frontal = frontPhotoRef.current;
            frontPhotoRef.current = null;
            remoteCaptureRef.current = null;
            setCameraActive(false);
            void anotarPasoCaptura(`tiempo agotado en: ${paso}${frontal ? " (la frontal ya estaba: se entrega sola)" : ""}`);
            if (frontal) {
              // La foto frontal ya salio: se entrega aunque la trasera se haya trabado.
              void finalizeSecurityEvidence(frontal, null).then((evidencia) => {
                setAlertState("idle");
                resolve(evidencia);
              }, () => {
                setAlertState("failed");
                dismissFullScreenAlert();
                reject(new Error(`remote_capture_timeout:${paso}`));
              });
              dismissFullScreenAlert();
              return;
            }
            setAlertState("failed");
            void stopAudioEvidence();
            dismissFullScreenAlert();
            reject(new Error(`remote_capture_timeout:${paso}`));
          }, 30_000);''')

cambio('camara lista: anota y marca el paso',
 'onCameraReady={() => void captureSecurityEvidence()}',
 '''onCameraReady={() => {
              capturaPasoRef.current = cameraFacing === "front" ? "sacando foto frontal" : "sacando foto trasera";
              void anotarPasoCaptura(`camara ${cameraFacing === "front" ? "frontal" : "trasera"} lista`);
              void captureSecurityEvidence();
            }}''')

cambio('reintentos: anota en que intento salio',
 '      if (intentoLogrado > 1) {',
 '''      if (intentoLogrado > 1) {
        void anotarPasoCaptura(`foto ${cameraFacing}: salio en el intento ${intentoLogrado}`);''')

cambio('frontal guardada: anota y marca el paso',
 '        frontPhotoRef.current = photo.base64;',
 '''        frontPhotoRef.current = photo.base64;
        capturaPasoRef.current = "esperando camara trasera";
        void anotarPasoCaptura("foto frontal lista; esperando camara trasera");''')

cambio('trasera lista: anota el guardado',
 '      const evidence = await finalizeSecurityEvidence(frontImageBase64, rearImageBase64);',
 '''      capturaPasoRef.current = "guardando evidencia";
      const evidence = await finalizeSecurityEvidence(frontImageBase64, rearImageBase64);
      void anotarPasoCaptura("evidencia completa: frontal y trasera");''')

cambio('errores de captura quedan anotados',
 '''    } catch (error) {
      setCameraActive(false);
      const frontImageBase64 = frontPhotoRef.current;
      if (cameraFacing === "back" && frontImageBase64) {''',
 '''    } catch (error) {
      void anotarPasoCaptura(`error en ${capturaPasoRef.current}: ${error instanceof Error ? error.message : String(error)}`);
      setCameraActive(false);
      const frontImageBase64 = frontPhotoRef.current;
      if (cameraFacing === "back" && frontImageBase64) {''')

cambio('estado de la pantalla de ajustes: pasos y mensaje de actualizacion',
 '''  const [nativeCaptureDiagnostics, setNativeCaptureDiagnostics] =
    useState<string[]>([]);''',
 '''  const [nativeCaptureDiagnostics, setNativeCaptureDiagnostics] =
    useState<string[]>([]);
  const [pasosCaptura, setPasosCaptura] = useState<string[]>([]);
  const [actualizacionMsg, setActualizacionMsg] = useState("");''')

cambio('ajustes: lee los pasos de captura',
 '    setNativeCaptureDiagnostics(getNativeCaptureDiagnostics());',
 '''    setNativeCaptureDiagnostics(getNativeCaptureDiagnostics());
    void leerPasosCaptura().then(setPasosCaptura);''')

cambio('ajustes: funcion de buscar actualizacion',
 '  async function openBatterySaverSettings() {',
 r'''  async function buscarActualizacion() {
    setActualizacionMsg("Buscando la última versión…");
    try {
      const respuesta = await fetch(URL_VERSION_APP, { headers: { accept: "application/json" } });
      const dato = (await respuesta.json()) as { disponible?: boolean; version?: string };
      if (!dato.disponible) {
        setActualizacionMsg("Todavía no hay una versión nueva publicada.");
        return;
      }
      const tengo = Number.parseInt(String(APP_BUILD_LABEL), 10);
      const coincidencia = /\((\d+)\)\s*$/.exec(String(dato.version ?? ""));
      const ultima = coincidencia ? Number.parseInt(coincidencia[1], 10) : Number.NaN;
      if (Number.isFinite(tengo) && Number.isFinite(ultima) && tengo >= ultima) {
        setActualizacionMsg(`Ya tenés la última versión (${APP_VERSION}, build ${APP_BUILD_LABEL}).`);
        return;
      }
      setActualizacionMsg(
        `Hay una versión publicada${dato.version ? `: ${dato.version}` : ""}. La tuya es ${APP_VERSION}, build ${APP_BUILD_LABEL}. Se abre la página de descarga.`,
      );
      await Linking.openURL(URL_DESCARGA_APP);
    } catch {
      setActualizacionMsg("No pude consultar la última versión. Revisá la conexión e intentá de nuevo.");
    }
  }

  async function openBatterySaverSettings() {''')

cambio('iPhone: sin el texto de Android del ahorro de bateria (principio)',
 '''            <Text style={styles.fieldHelp}>
              Android exige que vos confirmes el ahorro de batería.''',
 '''            {Platform.OS === "android" ? (
              <>
            <Text style={styles.fieldHelp}>
              Android exige que vos confirmes el ahorro de batería.''')

cambio('iPhone: sin el texto de Android del ahorro de bateria (final)',
 '''              <Text style={styles.secondaryButtonText}>Abrir ahorro de batería</Text>
            </Pressable>''',
 '''              <Text style={styles.secondaryButtonText}>Abrir ahorro de batería</Text>
            </Pressable>
              </>
            ) : null}''')

cambio('registros tecnicos: pasos de la captura (iPhone y Android)',
 '''            </Plegable>
            <Pressable onPress={onPermissions} style={[styles.secondaryButton, { marginTop: 14 }]}>''',
 r'''            <Text style={[styles.fieldHelp, { marginTop: 14 }]}>
              {pasosCaptura.length
                ? "Pasos de las últimas capturas de evidencia (más reciente primero):"
                : "Todavía no hay pasos de captura guardados."}
            </Text>
            {pasosCaptura.map((linea, index) => (
              <Text key={`paso-captura-${index}`} style={[styles.fieldHelp, { marginTop: 4, fontSize: 12 }]}>
                {linea}
              </Text>
            ))}
            </Plegable>
            <Pressable onPress={onPermissions} style={[styles.secondaryButton, { marginTop: 14 }]}>''')

cambio('boton Actualizar version (Android)',
 '''                Probar aviso en este teléfono
              </Text>
            </Pressable>''',
 r'''                Probar aviso en este teléfono
              </Text>
            </Pressable>
            {Platform.OS === "android" ? (
              <>
                <Pressable accessibilityRole="button" onPress={() => void buscarActualizacion()} style={styles.secondaryButton}>
                  <Text style={styles.secondaryButtonText}>{"Actualizar versión"}</Text>
                </Pressable>
                {actualizacionMsg ? <Text style={styles.fieldHelp}>{actualizacionMsg}</Text> : null}
              </>
            ) : null}''')

cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-version-captura-app.ps1 - App (PROXIMA build): "Actualizar version" en Ajustes (Android), pasos de la captura de evidencia anotados y foto frontal entregada si se agota el tiempo, y sin el texto de Android del ahorro de bateria en iPhone.
# Luciano (27/10/2026): "ponen actualizar" en la app; la foto del iPhone fallo una vez por tiempo agotado sin dejar rastro; en el iPhone aparece texto de Android.
#  1) Ajustes > Revisar permisos: boton "Actualizar version" (solo Android). Consulta ojoguard.app/api/app/version; si el numero de build entre parentesis de la version publicada (ej. "0.9.2 (163)") es mayor al instalado, abre ojoguard.app/descargar.
#  2) Captura de evidencia (iPhone y Android): cada paso queda anotado y se ve en Registros tecnicos; si se agota el tiempo (30 s) y la foto frontal ya salio, se entrega esa; si no, el error dice en que paso se trabo (remote_capture_timeout:<paso>).
#  3) iPhone: en Ajustes ya no aparece el texto de Android sobre el ahorro de bateria.
# Requiere aplicar-captura-reintentos-app.ps1. Toca App.tsx. Va en la carpeta de la APP (la que tiene app.json). Respaldo .bak-version. Si la revision de tipos falla, deja todo como estaba.
# Es solo codigo de la app (nada nativo): sale en la PROXIMA build.
'''
i = base.index('$ErrorActionPreference'); j = base.index('Ok "Carpeta correcta"')
motor_ini = base[i:j]
# la guarda de "carpeta correcta" y existencia de App.tsx viene del instalador base
k = base.index('if (-not (Test-Path (Join-Path $raiz "App.tsx")))'); k2 = base.index('$cambios = @(')
guardas = base[j:k2]
guardas = re.sub(r'if \(\(Contar \(Leer \(Join-Path \$raiz "App.tsx"\)\)\.texto .*\n', '''if ((Contar (Leer (Join-Path $raiz "App.tsx")).texto 'const CLAVE_PASOS_CAPTURA') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "App.tsx")).texto 'const esperas = Platform.OS === "ios"') -eq 0) { Mal "Falta aplicar primero aplicar-captura-reintentos-app.ps1. No toco nada."; return }
''', guardas)
cola = base[base.index('$descargas = @()'):].replace('.bak-reintentos', '.bak-version')
cola = cola.replace('Ok "LISTO: la app compila bien. Sale en la PROXIMA build."', 'Ok "LISTO: la app compila bien. Sale en la PROXIMA build (Android e iPhone)."')
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127]
print('no-ascii:', sorted(set(bad)))
open(R + 'aplicar-version-captura-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total), len(filas))
