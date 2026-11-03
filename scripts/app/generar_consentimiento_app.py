# Genera scripts/aplicar-consentimiento-app.ps1: la pantalla de verificacion de identidad muestra el consentimiento biometrico (DNI + selfie) y pide aceptarlo antes de seguir.
import os, re
R = '/home/user/Murray/scripts/'
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s): return "'" + s.replace("'", "''") + "'"

# Version del texto de consentimiento (AAAA-MM-DD). Si se cambia el texto, se cambia la version: la app vuelve a pedirlo y el servidor registra la nueva.
VERSION = '2026-11-03'

# El archivo que tiene Luciano = la version del repositorio + los dos cambios del instalador "selfie espejo" (que no se reflejan en el repositorio).
t = open(R + 'app/src/VerificarIdentidad.tsx', encoding='utf-8').read()
for a, b in [('<CameraView ref={camaraRef} facing="front" animateShutter={false}', '<CameraView ref={camaraRef} facing="front" mirror={false} animateShutter={false}'),
             ('<Image source={{ uri: selfieUri }} resizeMode="cover" style={{ width: 240, height: 290, borderRadius: 120, borderWidth: 4, borderColor: DORADO }} />', '<Image source={{ uri: selfieUri }} resizeMode="cover" style={{ width: 240, height: 290, borderRadius: 120, borderWidth: 4, borderColor: DORADO, transform: [{ scaleX: -1 }] }} />')]:
    assert t.count(a) == 1, a
    t = t.replace(a, b)

a1 = 'import * as FileSystem from "expo-file-system/legacy";\n'
b1 = 'import AsyncStorage from "@react-native-async-storage/async-storage";\n' + a1

a2 = 'const URL_API = "https://ojo-guard-ms-api.bickluciano.workers.dev";\n'
b2 = a2 + '''
/**
 * Consentimiento biometrico (03/11/2026): antes de pedir el DNI y la selfie se muestra un texto y la persona tiene que aceptarlo.
 * CONSENTIMIENTO_VERSION identifica ESE texto (AAAA-MM-DD): si el texto cambia, se cambia la version y se vuelve a pedir.
 * La version aceptada se guarda en el telefono (para no preguntar cada vez) y se manda al servidor con cada verificacion, que registra cual version y cuando.
 */
const CONSENTIMIENTO_VERSION = "%s";
const CLAVE_CONSENTIMIENTO = "ojo-guard-consentimiento-biometrico";

async function consentimientoAceptado(): Promise<boolean> {
  try {
    return (await AsyncStorage.getItem(CLAVE_CONSENTIMIENTO)) === CONSENTIMIENTO_VERSION;
  } catch {
    return false;
  }
}

async function guardarConsentimiento(): Promise<void> {
  try {
    await AsyncStorage.setItem(CLAVE_CONSENTIMIENTO, CONSENTIMIENTO_VERSION);
  } catch {
    // Si no se puede guardar en el telefono igual se sigue: el servidor recibe la version con cada verificacion.
  }
}
''' % VERSION

a3 = '''    case "invalid_selfie":
      return { mensaje: "La foto no se pudo usar. Sacate otra.", volverA: "selfie" };
'''
b3 = '''    case "consent_required":
      return { mensaje: "Falta aceptar el consentimiento. Actualizá Ojo Guard a la última versión y probá de nuevo.", volverA: "datos" };
''' + a3

a4 = 'body: JSON.stringify({ deviceId: enrollment.deviceId, documentNumber: documento, gender: sexo, selfieBase64 }),'
b4 = 'body: JSON.stringify({ deviceId: enrollment.deviceId, documentNumber: documento, gender: sexo, selfieBase64, consentVersion: CONSENTIMIENTO_VERSION }),'

a5 = '  const [yaVerificada, setYaVerificada] = useState<boolean | null>(revisarEstado ? null : false);\n'
b5 = a5 + '''  // "leyendo" mientras se mira si ya acepto el consentimiento en este telefono; "pendiente" muestra el texto; "aceptado" sigue con los datos.
  const [consentimiento, setConsentimiento] = useState<"leyendo" | "pendiente" | "aceptado">("leyendo");
  const [casilla, setCasilla] = useState(false);

  useEffect(() => {
    let vigente = true;
    void consentimientoAceptado().then((aceptado) => {
      if (vigente) setConsentimiento(aceptado ? "aceptado" : "pendiente");
    });
    return () => {
      vigente = false;
    };
  }, []);

  async function aceptarConsentimiento() {
    if (!casilla) return;
    await guardarConsentimiento();
    setConsentimiento("aceptado");
  }
'''

a6 = '''  if (etapa === "datos") {
    const opciones: Array<{ valor: Sexo; texto: string }> = [
'''
b6 = '''  if (etapa === "datos" && consentimiento !== "aceptado") {
    if (consentimiento === "leyendo") {
      return (
        <View style={{ paddingVertical: 24 }}>
          <ActivityIndicator color={azul} />
        </View>
      );
    }
    const punto = (rotulo: string, texto: string) => (
      <Text style={{ color: paleta.textoMedio, fontSize: 14.5, lineHeight: 21 }}>
        <Text style={{ color: paleta.texto, fontWeight: "800" }}>{rotulo} </Text>
        {texto}
      </Text>
    );
    return (
      <View style={{ gap: 6 }}>
        {sinTituloPropio ? null : titulo("Antes de verificarte")}
        {parrafo("Para confirmar que sos vos te vamos a pedir tu número de DNI, el sexo que figura en él y una selfie. Leé cómo usamos esos datos y, si estás de acuerdo, aceptá.")}
        <View style={{ gap: 12, marginTop: 14, padding: 16, borderRadius: 16, borderWidth: 1, borderColor: paleta.borde, backgroundColor: tarjeta }}>
          {punto("Qué usamos.", "Tu número de DNI, tu sexo y una foto de tu cara. La foto de tu cara es un dato biométrico.")}
          {punto("Para qué.", "Para compararla con la foto que el registro oficial (RENAPER) tiene de tu DNI y confirmar que sos vos. Solo para eso: no usamos tus datos para publicidad ni los vendemos.")}
          {punto("Quién los procesa.", "Didit, la empresa que hace la verificación, y RENAPER. Didit puede procesar los datos fuera de Argentina.")}
          {punto("Qué guardamos nosotros.", "La selfie no. Guardamos el resultado, el puntaje de la comparación, los últimos 3 números del DNI, una huella que no permite recuperar el número y la fecha en que aceptaste esto.")}
          {punto("Cuánto tiempo.", "Didit guarda los datos de la consulta 1 mes (el plazo que le pedimos) y después los elimina.")}
          {punto("Tus derechos.", "Es opcional: podés omitirlo y usar Ojo Guard igual. Podés pedir que borremos tus datos cuando quieras, desde Perfil > Borrar mi cuenta o escribiendo a soporte@ojoguard.app.")}
        </View>
        <Pressable
          accessibilityRole="checkbox"
          accessibilityState={{ checked: casilla }}
          onPress={() => setCasilla(!casilla)}
          style={{ flexDirection: "row", alignItems: "flex-start", gap: 12, marginTop: 18 }}
        >
          <View style={{ width: 26, height: 26, borderRadius: 7, borderWidth: 2, borderColor: azul, backgroundColor: casilla ? azul : "transparent", alignItems: "center", justifyContent: "center", marginTop: 1 }}>
            {casilla ? <Icono nombre="check" color="#fff" tam={18} /> : null}
          </View>
          <Text style={{ flex: 1, color: paleta.texto, fontSize: 15, lineHeight: 22 }}>
            Soy mayor de 18 años y acepto que Ojo Guard use mi DNI y mi selfie para verificar mi identidad, como se explica arriba.
          </Text>
        </Pressable>
        <View style={{ gap: 10, marginTop: 20 }}>
          {boton("Aceptar y seguir", () => void aceptarConsentimiento(), { principal: true, deshabilitado: !casilla })}
          {permitirOmitir ? enlace("Ahora no", () => onListo("omitida")) : null}
        </View>
      </View>
    );
  }

''' + a6

filas = [('src\\VerificarIdentidad.tsx', 'importar el almacenamiento del telefono', a1, b1),
         ('src\\VerificarIdentidad.tsx', 'version del consentimiento y funciones para leerlo y guardarlo', a2, b2),
         ('src\\VerificarIdentidad.tsx', 'mensaje si el servidor pide el consentimiento', a3, b3),
         ('src\\VerificarIdentidad.tsx', 'mandar la version del consentimiento con la verificacion', a4, b4),
         ('src\\VerificarIdentidad.tsx', 'estado del consentimiento', a5, b5),
         ('src\\VerificarIdentidad.tsx', 'pantalla del consentimiento antes de pedir el DNI', a6, b6)]
for f in filas:
    assert t.count(f[2]) == 1, (f[1], t.count(f[2]))
nuevo = t
for f in filas:
    nuevo = nuevo.replace(f[2], f[3])
# Copia ya cambiada, para revisar tipos con el compilador estricto (si existe la carpeta de prueba).
carpeta = S + 'tc-consent/src/'
if os.path.isdir(carpeta):
    open(carpeta + 'VerificarIdentidad.tsx', 'w', encoding='utf-8').write(nuevo)
    open(S + 'VerificarIdentidad.consentimiento.tsx', 'w', encoding='utf-8').write(nuevo)

cambios = "$cambios = @(\n" + ',\n'.join(("    ,@(%s, %s, %s, %s)" if len(filas) == 1 else "    @(%s, %s, %s, %s)") % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-consentimiento-app.ps1 - App (PROXIMA build): antes de pedir el DNI y la selfie, la pantalla de verificacion de identidad muestra el consentimiento biometrico y pide aceptarlo (casilla "Soy mayor de 18 anios y acepto...").
# Qué dice: que datos se usan (DNI, sexo, selfie = dato biometrico), para que, quien los procesa (Didit y RENAPER), que guarda Ojo Guard (no la selfie), cuanto tiempo (Didit 1 mes), y como pedir el borrado. La version aceptada (%s) se guarda en el telefono y se manda al servidor con cada verificacion.
# Cambia SOLO src\\VerificarIdentidad.tsx (respaldo .bak-consentimiento) con anclas exactas, sin reemplazar el archivo: respeta los cambios de la camara y del espejo. Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba.
# Conviene instalar antes aplicar-identidad-consentimiento-panel.ps1 (el servidor que guarda la version). Sale en la PROXIMA build.
''' % VERSION
i = base.index('$ErrorActionPreference'); j = base.index('Ok "Carpeta correcta"')
motor_ini = base[i:j]
guardas = '''Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\VerificarIdentidad.tsx"))) { Mal "No encuentro src\\VerificarIdentidad.tsx en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\VerificarIdentidad.tsx")).texto 'CONSENTIMIENTO_VERSION') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('.bak-version', '.bak-consentimiento')
v = 'if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-consentimiento") -Destination $ruta -Force } }'
assert cola.count(v) == 1, cola.count(v)
cola = cola.replace(v, 'if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-consentimiento") -Destination $ruta -Force } elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force } }')
msg = 'Mal "Restaurado. Mandame esta pantalla."'
assert cola.count(msg) == 2
cola = cola.replace(msg, 'foreach ($t in $respaldados) { Remove-Item -LiteralPath ((Join-Path $raiz $t) + ".bak-consentimiento") -Force -ErrorAction SilentlyContinue }\n' + msg)
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "LISTO: la app compila bien. Sale en la PROXIMA build."', cola)
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›✓']
assert not bad, set(bad)
open(R + 'aplicar-consentimiento-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total), 'version', VERSION)
