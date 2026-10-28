import { useEffect, useRef, useState } from "react";
import { ActivityIndicator, Image, Linking, Pressable, Text, TextInput, View } from "react-native";
import * as FileSystem from "expo-file-system/legacy";
import { CameraView, useCameraPermissions } from "expo-camera";
import * as ImageManipulator from "expo-image-manipulator";
import { clearPendingSystemActivity, markPendingSystemActivity } from "./pendingSystemActivity";
import { loadNativeEnrollment } from "./remoteStorage";
import { Icono } from "./Iconos";

/**
 * Verificación de identidad: número de DNI + sexo + una selfie. El servidor (ojoguard.app) consulta a Didit, que confirma el DNI contra
 * RENAPER (el registro oficial) y compara la cara con la foto que RENAPER tiene de ese DNI. Ojo Guard NO guarda la selfie ni el número
 * completo del DNI: la selfie se borra del teléfono apenas se manda y el servidor guarda solo el resultado.
 *
 * Es opcional: se puede omitir y usar la app igual. Mientras no esté verificada, la persona no puede pedir foto y audio a OTRAS personas
 * de la familia (lo controla el servidor, no esta pantalla). Se usa en el arranque (ArranqueIdentidad) y en Configuración.
 *
 * La selfie se saca con la camara DENTRO de la app (expo-camera), no con la app de camara del telefono: en el Xiaomi, al abrir la camara del
 * sistema Android cerraba la app por memoria y al volver pedia el codigo de nuevo (28/10/2026). Asi la app nunca se va al fondo.
 */

const URL_API = "https://ojo-guard-ms-api.bickluciano.workers.dev";

/**
 * Abrir la camara manda la app a segundo plano. Android devuelve la foto (onActivityResult) ANTES de avisar que la app volvio al
 * frente (onResume): si el aviso de "pantalla del sistema abierta" se baja apenas llega la foto, esa vuelta tardia se toma por una salida
 * real y la app pide el codigo de nuevo (paso el 28/10/2026 en el Xiaomi al sacar la selfie). Por eso el aviso se mantiene unos segundos
 * despues de que vuelve la foto. La marca evita que una camara abierta de nuevo enseguida pierda el aviso por un temporizador viejo.
 */
const PAUSA_CAMARA_MS = 5000;
let marcaCamara = 0;
export function avisarCamaraAbierta() {
  marcaCamara += 1;
  markPendingSystemActivity();
}
export function soltarAvisoCamara() {
  const esta = marcaCamara;
  setTimeout(() => {
    if (marcaCamara === esta) clearPendingSystemActivity();
  }, PAUSA_CAMARA_MS);
}

export type PaletaIdentidad = {
  fondo: string;
  superficie: string;
  texto: string;
  textoMedio: string;
  textoDebil: string;
  borde: string;
  doradoRelleno: string;
  sobreDorado: string;
  peligro: string;
};

export type EtapaIdentidad = "datos" | "selfie" | "resultado";
type Sexo = "M" | "F" | "X";

export type EstadoIdentidad = "verificada" | "sin-verificar" | "error";

export async function consultarIdentidad(): Promise<EstadoIdentidad> {
  try {
    const enrollment = await loadNativeEnrollment();
    if (!enrollment) return "error";
    const respuesta = await fetch(`${URL_API}/api/native/identity?deviceId=${encodeURIComponent(enrollment.deviceId)}`, {
      headers: { accept: "application/json", authorization: `Bearer ${enrollment.accessToken}` },
    });
    if (!respuesta.ok) return "error";
    const dato = (await respuesta.json()) as { verified?: boolean };
    return dato.verified === true ? "verificada" : "sin-verificar";
  } catch {
    return "error";
  }
}

type Resultado = { ok: true } | { ok: false; mensaje: string; volverA: "datos" | "selfie" };

function textoRechazo(outcome: string): { mensaje: string; volverA: "datos" | "selfie" } {
  switch (outcome) {
    case "BIOMETRIC_NO_MATCH":
      return { mensaje: "No pudimos confirmar que tu cara coincida con la foto de tu DNI. Probá de nuevo con buena luz y de frente.", volverA: "selfie" };
    case "BIOMETRIC_IMAGE_UNUSABLE":
      return { mensaje: "No se vio bien tu cara. Sacate otra foto con buena luz, de frente y sin lentes oscuros.", volverA: "selfie" };
    case "NO_MATCH":
      return { mensaje: "El número de DNI no figura en el registro con esos datos. Revisá el número y el sexo.", volverA: "datos" };
    case "REGISTRY_UNAVAILABLE":
      return { mensaje: "El registro oficial no responde en este momento. Probá en unos minutos.", volverA: "selfie" };
    default:
      return { mensaje: "No se pudo verificar tu identidad esta vez. Revisá los datos y probá de nuevo.", volverA: "datos" };
  }
}

function textoError(codigo: string): { mensaje: string; volverA: "datos" | "selfie" } {
  switch (codigo) {
    case "unauthorized":
      return { mensaje: "Este teléfono todavía no está vinculado a tu cuenta. Entrá con tu código y volvé a intentar.", volverA: "datos" };
    case "too_many_attempts":
      return { mensaje: "Hoy ya usaste todos los intentos. Probá de nuevo mañana.", volverA: "datos" };
    case "invalid_document":
      return { mensaje: "Revisá el número de DNI: tiene que tener 7 u 8 números.", volverA: "datos" };
    case "invalid_gender":
      return { mensaje: "Elegí el sexo que figura en tu DNI.", volverA: "datos" };
    case "invalid_selfie":
      return { mensaje: "La foto no se pudo usar. Sacate otra.", volverA: "selfie" };
    case "network_failed":
      return { mensaje: "Sin conexión. Revisá internet y probá de nuevo.", volverA: "selfie" };
    default:
      return { mensaje: "El servicio de verificación no está disponible ahora. Probá más tarde.", volverA: "selfie" };
  }
}

/**
 * Didit corta la conexion cuando el pedido pasa de unos 100-300 KB (se midio el 28/10/2026: 100 KB pasa, 300 KB se corta) y la camara entrega ~600 KB.
 * Para comparar una cara alcanza con una foto chica: se achica a 600 px de ancho y se comprime (queda en unas decenas de KB).
 * Se usa la API vieja (manipulateAsync) o la nueva (manipulate) segun la version de expo-image-manipulator que traiga el proyecto.
 */
const ANCHO_SELFIE = 600;
type ResultadoReduccion = { uri: string; base64?: string | undefined };
type OpcionesGuardado = { compress: number; format: string; base64: boolean };
type ManipuladorCompat = {
  manipulateAsync?: (uri: string, acciones: Array<{ resize: { width: number } }>, opciones: OpcionesGuardado) => Promise<ResultadoReduccion>;
  manipulate?: (uri: string) => {
    resize: (tam: { width: number }) => unknown;
    renderAsync: () => Promise<{ saveAsync: (opciones: OpcionesGuardado) => Promise<ResultadoReduccion> }>;
  };
};

async function reducirSelfie(uri: string): Promise<{ uri: string; base64: string } | null> {
  try {
    const m = ImageManipulator as unknown as ManipuladorCompat;
    const opciones: OpcionesGuardado = { compress: 0.6, format: "jpeg", base64: true };
    let r: ResultadoReduccion | null = null;
    if (typeof m.manipulateAsync === "function") {
      r = await m.manipulateAsync(uri, [{ resize: { width: ANCHO_SELFIE } }], opciones);
    } else if (typeof m.manipulate === "function") {
      const contexto = m.manipulate(uri);
      contexto.resize({ width: ANCHO_SELFIE });
      const imagen = await contexto.renderAsync();
      r = await imagen.saveAsync(opciones);
    }
    return r?.base64 ? { uri: r.uri, base64: r.base64 } : null;
  } catch {
    return null;
  }
}

async function enviarVerificacion(documento: string, sexo: Sexo, selfieBase64: string): Promise<Resultado> {
  const enrollment = await loadNativeEnrollment();
  if (!enrollment) return { ok: false, ...textoError("unauthorized") };
  const control = new AbortController();
  const corte = setTimeout(() => control.abort(), 45_000);
  try {
    const respuesta = await fetch(`${URL_API}/api/native/identity/verify`, {
      method: "POST",
      headers: { accept: "application/json", "content-type": "application/json", authorization: `Bearer ${enrollment.accessToken}` },
      body: JSON.stringify({ deviceId: enrollment.deviceId, documentNumber: documento, gender: sexo, selfieBase64 }),
      signal: control.signal,
    });
    const dato = (await respuesta.json().catch(() => ({}))) as { verified?: boolean; outcome?: string; error?: string };
    if (!respuesta.ok) return { ok: false, ...textoError(dato.error ?? `http_${respuesta.status}`) };
    if (dato.verified === true) return { ok: true };
    return { ok: false, ...textoRechazo(dato.outcome ?? "") };
  } catch {
    return { ok: false, ...textoError("network_failed") };
  } finally {
    clearTimeout(corte);
  }
}

export function VerificarIdentidad({
  paleta,
  noche,
  onListo,
  onEtapa,
  permitirOmitir,
  revisarEstado,
}: {
  paleta: PaletaIdentidad;
  noche: boolean;
  /** "verificada" cuando termina bien; "omitida" cuando la persona elige seguir sin verificar. */
  onListo: (estado: "verificada" | "omitida") => void;
  onEtapa?: ((etapa: EtapaIdentidad) => void) | undefined;
  /** En el arranque se puede omitir; en Configuración no hace falta. */
  permitirOmitir: boolean;
  /** En Configuración: consulta si ya está verificada antes de pedir los datos. */
  revisarEstado: boolean;
}) {
  const [etapa, setEtapa] = useState<EtapaIdentidad>("datos");
  const [documento, setDocumento] = useState("");
  const [sexo, setSexo] = useState<Sexo | null>(null);
  const [selfieUri, setSelfieUri] = useState<string | null>(null);
  const [selfieBase64, setSelfieBase64] = useState<string | null>(null);
  const [camaraAbierta, setCamaraAbierta] = useState(false);
  const [camaraLista, setCamaraLista] = useState(false);
  const [permisoCamara, pedirPermisoCamara] = useCameraPermissions();
  const camaraRef = useRef<CameraView>(null);
  const [ocupado, setOcupado] = useState(false);
  const [aviso, setAviso] = useState("");
  const [sinPermiso, setSinPermiso] = useState(false);
  const [resultado, setResultado] = useState<Resultado | null>(null);
  const [yaVerificada, setYaVerificada] = useState<boolean | null>(revisarEstado ? null : false);

  const azul = noche ? "#7C9CFF" : paleta.doradoRelleno;
  const azulSuave = noche ? "#1A2757" : "#E4EBFC";
  const tarjeta = noche ? "#16203F" : "#FFFFFF";
  const DORADO = "#D4A94D";
  // En Configuracion la pagina ya trae su propio titulo y su bajada ("Verificar mi identidad"): repetirlos aca se veia redundante.
  const sinTituloPropio = revisarEstado;

  useEffect(() => {
    if (!revisarEstado) return;
    let vigente = true;
    void consultarIdentidad().then((estado) => {
      if (vigente) setYaVerificada(estado === "verificada");
    });
    return () => {
      vigente = false;
    };
  }, [revisarEstado]);

  function irA(nueva: EtapaIdentidad) {
    setEtapa(nueva);
    setAviso("");
    onEtapa?.(nueva);
  }

  const numero = documento.replace(/\D/g, "");
  const datosListos = numero.length >= 7 && numero.length <= 8 && sexo !== null;

  async function abrirCamara() {
    if (ocupado) return;
    setAviso("");
    setSinPermiso(false);
    setSelfieUri(null);
    setSelfieBase64(null);
    let concedido = permisoCamara?.granted === true;
    if (!concedido) {
      const r = await pedirPermisoCamara().catch(() => null);
      concedido = r?.granted === true;
    }
    if (!concedido) {
      setSinPermiso(true);
      setAviso("Necesitamos la cámara para la selfie. Activala en los ajustes del teléfono y volvé.");
      return;
    }
    setCamaraLista(false);
    setCamaraAbierta(true);
  }

  async function sacarSelfie() {
    if (ocupado || !camaraLista) return;
    setOcupado(true);
    setAviso("");
    try {
      const sacar = () => camaraRef.current?.takePictureAsync({ base64: false, quality: 0.7, skipProcessing: false });
      // En iPhone la camara avisa "lista" un instante antes de poder sacar y a veces la primera falla: se reintenta una vez.
      let foto = await Promise.resolve(sacar()).catch(() => null);
      if (!foto?.uri) {
        await new Promise<void>((listo) => setTimeout(listo, 700));
        foto = await Promise.resolve(sacar()).catch(() => null);
      }
      if (foto?.uri) {
        const chica = await reducirSelfie(foto.uri);
        // La foto original (varios cientos de KB) ya no hace falta: se borra apenas se achica.
        void FileSystem.deleteAsync(foto.uri, { idempotent: true }).catch(() => undefined);
        if (chica) {
          setSelfieUri(chica.uri);
          setSelfieBase64(chica.base64);
          setCamaraAbierta(false);
        } else {
          setAviso("No se pudo preparar la foto. Probá de nuevo.");
        }
      } else {
        setAviso("No se pudo sacar la foto. Probá de nuevo.");
      }
    } finally {
      setOcupado(false);
    }
  }

  async function verificar() {
    if (!selfieBase64 || !sexo || ocupado) return;
    setOcupado(true);
    setAviso("");
    const uri = selfieUri;
    try {
      const r = await enviarVerificacion(numero, sexo, selfieBase64);
      setResultado(r);
      // La selfie no se conserva: se borra del telefono y de la memoria ya sea que haya salido bien o no.
      setSelfieUri(null);
      setSelfieBase64(null);
      if (uri) void FileSystem.deleteAsync(uri, { idempotent: true }).catch(() => undefined);
      irA("resultado");
    } finally {
      setOcupado(false);
    }
  }

  const boton = (texto: string, onPress: () => void, opciones: { principal?: boolean; deshabilitado?: boolean } = {}) => (
    <Pressable
      accessibilityRole="button"
      disabled={opciones.deshabilitado === true}
      onPress={onPress}
      style={{
        height: 54,
        borderRadius: 27,
        alignItems: "center",
        justifyContent: "center",
        backgroundColor: opciones.principal ? paleta.doradoRelleno : "transparent",
        borderWidth: opciones.principal ? 0 : 1.5,
        borderColor: azul,
        opacity: opciones.deshabilitado ? 0.45 : 1,
      }}
    >
      <Text style={{ color: opciones.principal ? paleta.sobreDorado : azul, fontSize: 16, fontWeight: "800" }}>{texto}</Text>
    </Pressable>
  );

  const enlace = (texto: string, onPress: () => void) => (
    <Pressable accessibilityRole="button" hitSlop={10} onPress={onPress} style={{ alignItems: "center", paddingVertical: 8 }}>
      <Text style={{ color: paleta.textoDebil, fontSize: 14, fontWeight: "600" }}>{texto}</Text>
    </Pressable>
  );

  const titulo = (t: string) => (
    <Text accessibilityRole="header" style={{ color: paleta.texto, fontSize: 28, fontWeight: "700", letterSpacing: -0.5 }}>
      {t}
    </Text>
  );
  const parrafo = (t: string) => <Text style={{ color: paleta.textoMedio, fontSize: 15, lineHeight: 23, marginTop: 10 }}>{t}</Text>;

  if (yaVerificada === null) {
    return (
      <View style={{ paddingVertical: 24 }}>
        <ActivityIndicator color={azul} />
      </View>
    );
  }
  if (yaVerificada) {
    return (
      <View style={{ gap: 14 }}>
        {titulo("Tu identidad está verificada")}
        {parrafo("Ya podés pedir foto y audio a las personas de tu familia desde el mapa. No hace falta hacer nada más.")}
        <View style={{ alignItems: "center", marginVertical: 8 }}>
          <View style={{ width: 84, height: 84, borderRadius: 42, backgroundColor: azul, alignItems: "center", justifyContent: "center" }}>
            <Icono nombre="check" color="#fff" tam={46} />
          </View>
        </View>
        {boton("Listo", () => onListo("verificada"), { principal: true })}
      </View>
    );
  }

  if (etapa === "datos") {
    const opciones: Array<{ valor: Sexo; texto: string }> = [
      { valor: "M", texto: "Masculino" },
      { valor: "F", texto: "Femenino" },
      { valor: "X", texto: "X" },
    ];
    return (
      <View style={{ gap: 6 }}>
        {sinTituloPropio ? null : titulo("Verificá tu identidad")}
        {sinTituloPropio
          ? null
          : parrafo(
              "Confirmamos que sos vos con tu DNI y una selfie. Es opcional por ahora, pero hasta que lo hagas no vas a poder pedir foto y audio a otras personas de tu familia.",
            )}
        <Text style={{ color: paleta.textoDebil, fontSize: 13, lineHeight: 19, marginTop: sinTituloPropio ? 0 : 8 }}>
          Ojo Guard no guarda tu selfie ni tu número completo de DNI. Se comparan con el registro oficial (RENAPER) mediante un servicio de verificación (Didit).
        </Text>
        <Text style={{ color: paleta.texto, fontSize: 14, fontWeight: "700", marginTop: 18 }}>Número de DNI</Text>
        <TextInput
          accessibilityLabel="Número de DNI"
          keyboardType="number-pad"
          maxLength={11}
          onChangeText={setDocumento}
          placeholder="Sin puntos ni espacios"
          placeholderTextColor={paleta.textoDebil}
          style={{ height: 54, borderRadius: 16, borderWidth: 1.5, borderColor: paleta.borde, backgroundColor: tarjeta, color: paleta.texto, fontSize: 20, letterSpacing: 1, paddingHorizontal: 16, marginTop: 6 }}
          value={documento}
        />
        <Text style={{ color: paleta.texto, fontSize: 14, fontWeight: "700", marginTop: 16 }}>Sexo que figura en tu DNI</Text>
        <View style={{ flexDirection: "row", gap: 10, marginTop: 6 }}>
          {opciones.map((o) => (
            <Pressable
              key={o.valor}
              accessibilityRole="button"
              accessibilityState={{ selected: sexo === o.valor }}
              onPress={() => setSexo(o.valor)}
              style={{
                flex: 1,
                height: 48,
                borderRadius: 24,
                alignItems: "center",
                justifyContent: "center",
                backgroundColor: sexo === o.valor ? azul : azulSuave,
              }}
            >
              <Text style={{ color: sexo === o.valor ? paleta.sobreDorado : azul, fontSize: 14, fontWeight: "800" }}>{o.texto}</Text>
            </Pressable>
          ))}
        </View>
        <View style={{ gap: 10, marginTop: 24 }}>
          {boton("Seguir", () => irA("selfie"), { principal: true, deshabilitado: !datosListos })}
          {permitirOmitir ? enlace("Omitir por ahora", () => onListo("omitida")) : null}
        </View>
      </View>
    );
  }

  if (etapa === "selfie") {
    return (
      <View style={{ gap: 6 }}>
        {titulo("Ahora, tu selfie")}
        {parrafo("Una foto con buena luz, de frente y sin lentes oscuros. La comparamos con la foto que el registro oficial tiene de tu DNI.")}
        <View style={{ alignItems: "center", marginTop: 20 }}>
          {camaraAbierta ? (
            <View style={{ width: 240, height: 290, borderRadius: 120, overflow: "hidden", borderWidth: 4, borderColor: DORADO, backgroundColor: "#000" }}>
              <CameraView ref={camaraRef} facing="front" animateShutter={false} onCameraReady={() => setCamaraLista(true)} style={{ flex: 1 }} />
            </View>
          ) : selfieUri ? (
            <Image source={{ uri: selfieUri }} resizeMode="cover" style={{ width: 240, height: 290, borderRadius: 120, borderWidth: 4, borderColor: DORADO }} />
          ) : (
            <View style={{ width: 230, height: 280, borderRadius: 115, backgroundColor: azulSuave, borderWidth: 2, borderStyle: "dashed", borderColor: DORADO, alignItems: "center", justifyContent: "center" }}>
              <Icono nombre="persona" color={azul} tam={100} />
            </View>
          )}
        </View>
        {aviso ? (
          <Text accessibilityLiveRegion="polite" style={{ color: paleta.peligro, fontSize: 13.5, lineHeight: 19, marginTop: 14, textAlign: "center" }}>
            {aviso}
          </Text>
        ) : null}
        {ocupado && selfieUri ? (
          <View style={{ alignItems: "center", marginTop: 14, gap: 6 }}>
            <ActivityIndicator color={azul} />
            <Text style={{ color: paleta.textoMedio, fontSize: 13.5 }}>Verificando… puede tardar unos segundos.</Text>
          </View>
        ) : null}
        <View style={{ gap: 10, marginTop: 22 }}>
          {camaraAbierta ? (
            <>
              {boton(camaraLista ? "Sacar la foto" : "Preparando la cámara…", () => void sacarSelfie(), { principal: true, deshabilitado: ocupado || !camaraLista })}
              {boton("Cancelar", () => setCamaraAbierta(false), { deshabilitado: ocupado })}
            </>
          ) : selfieUri ? (
            <>
              {boton("Verificar mi identidad", () => void verificar(), { principal: true, deshabilitado: ocupado })}
              {boton("Sacar otra", () => void abrirCamara(), { deshabilitado: ocupado })}
            </>
          ) : (
            <>
              {boton("Sacarme la selfie", () => void abrirCamara(), { principal: true, deshabilitado: ocupado })}
              {sinPermiso ? boton("Abrir ajustes del teléfono", () => void Linking.openSettings()) : null}
            </>
          )}
          {camaraAbierta ? null : enlace("Volver a los datos", () => irA("datos"))}
          {permitirOmitir && !camaraAbierta ? enlace("Omitir por ahora", () => onListo("omitida")) : null}
        </View>
      </View>
    );
  }

  // Resultado
  if (resultado?.ok === true) {
    return (
      <View style={{ gap: 14 }}>
        {titulo("Identidad verificada")}
        {parrafo("Listo: confirmamos que sos vos. Ya podés pedir foto y audio a las personas de tu familia desde el mapa.")}
        <View style={{ alignItems: "center", marginVertical: 8 }}>
          <View style={{ width: 84, height: 84, borderRadius: 42, backgroundColor: azul, alignItems: "center", justifyContent: "center" }}>
            <Icono nombre="check" color="#fff" tam={46} />
          </View>
        </View>
        {boton("Continuar", () => onListo("verificada"), { principal: true })}
      </View>
    );
  }
  const falla = resultado && resultado.ok === false ? resultado : null;
  return (
    <View style={{ gap: 14 }}>
      {titulo("No pudimos verificarte")}
      <Text accessibilityLiveRegion="polite" style={{ color: paleta.textoMedio, fontSize: 15, lineHeight: 23 }}>
        {falla?.mensaje ?? "No se pudo verificar tu identidad esta vez."}
      </Text>
      <View style={{ gap: 10, marginTop: 8 }}>
        {boton("Probar de nuevo", () => irA(falla?.volverA ?? "datos"), { principal: true })}
        {permitirOmitir ? enlace("Seguir sin verificar", () => onListo("omitida")) : null}
      </View>
    </View>
  );
}
