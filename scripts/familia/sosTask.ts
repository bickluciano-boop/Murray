import AsyncStorage from "@react-native-async-storage/async-storage";
import { Alert, AppRegistry, AppState, Linking, Platform } from "react-native";
import * as Crypto from "expo-crypto";
import * as Notifications from "expo-notifications";
import * as SecureStore from "expo-secure-store";

import { isSosGestureEnabled, isSosGestureRunning, sosGestureAvailable } from "../modules/sos-trigger";
import { loadNativeEnrollment } from "./remoteStorage";
import { sendSos, SosError } from "./sos";

/**
 * SOS sin abrir la app (o abriéndola sola): lo que pasa cuando algo de afuera pide ayuda.
 *
 *  - Android: mantener apretados los dos botones de volumen 3 segundos (servicio de accesibilidad "Ojo Guard SOS" del
 *    módulo nativo sos-trigger). Arranca la tarea headless "OjoGuardSosTask", que corre esto con la app cerrada.
 *  - iPhone: el enlace `ojoguard://sos?k=<clave>`. Con la app de Atajos se arma un atajo "Abrir URL" con ese enlace y
 *    se lo dispara con Siri, el toque en la espalda (Ajustes > Accesibilidad > Tocar) o un control de la pantalla de
 *    bloqueo. La clave es de este teléfono (se muestra en Configuración > Familia): sin ella el enlace no hace nada, así
 *    nadie puede mandar un SOS falso con un link armado por afuera.
 *
 * Se registra al cargar el módulo, tanto en un arranque normal como en uno headless: por eso lo importa SosBlock.tsx,
 * que App.tsx ya carga.
 */

// Dos pedidos seguidos (por ejemplo el enlace y el volumen a la vez) salen una sola vez.
const ESPERA_MS = 15_000;
const REINTENTOS = 3;
const ESPERA_REINTENTO_MS = 3_000;
const CANAL = "ojo-alertas";
const CLAVE_ENLACE = "ojo-guard-sos-link-key-v1";
const CLAVE_USO_ATAJO = "ojo-guard-sos-atajo-uso-v1";
const CLAVE_AVISO_GESTO = "ojo-guard-sos-gesto-aviso-v1";
const AVISO_GESTO_CADA_MS = 12 * 3_600_000;
const GESTO_INTENTOS = 3;
const GESTO_ESPERA_MS = 3_000;

let enCurso = false;
let ultimo = 0;

// Android: el canal por el que llegan los SOS de la familia. Siempre suena con la sirena de Ojo Guard (la misma del
// "Hacer sonar", ya incluida en la app) y con volumen de alarma, y pide atravesar "No interrumpir". Si el sistema no
// deja pedirlo por programa, en Configuración > Familia hay un botón que abre esta pantalla para activarlo a mano.
// Se crea al cargar el módulo (también en un arranque headless) y el servidor manda los SOS con este mismo id.
export const SOS_CHANNEL = "ojo-sos";
if (Platform.OS === "android") {
  void Notifications.setNotificationChannelAsync(SOS_CHANNEL, {
    name: "SOS de la familia",
    description: "Pedidos de ayuda de tu familia. Suenan con sirena aunque el teléfono esté en silencio o en No interrumpir.",
    importance: Notifications.AndroidImportance.MAX,
    sound: "ojo_sirena.wav",
    vibrationPattern: [0, 700, 250, 700, 250, 1200],
    enableVibrate: true,
    bypassDnd: true,
    lockscreenVisibility: Notifications.AndroidNotificationVisibility.PUBLIC,
    audioAttributes: {
      usage: Notifications.AndroidAudioUsage.ALARM,
      contentType: Notifications.AndroidAudioContentType.SONIFICATION,
      flags: { enforceAudibility: true, requestHardwareAudioVideoSynchronization: false },
    },
  }).catch(() => undefined);
}

const pausa = (ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms));

async function avisar(titulo: string, texto: string) {
  try {
    await Notifications.scheduleNotificationAsync({
      identifier: "ojo-guard-sos",
      content: { title: titulo, body: texto, sound: "default" },
      trigger: Platform.OS === "android" ? { channelId: CANAL } : null,
    });
  } catch {
    // Sin permiso de notificaciones queda solo el aviso en pantalla, si la app está abierta.
  }
  if (AppState.currentState === "active") Alert.alert(titulo, texto);
}

function listaDeNombres(nombres: string[]) {
  if (nombres.length <= 1) return nombres[0] ?? "tu familia";
  return `${nombres.slice(0, -1).join(", ")} y ${nombres[nombres.length - 1]}`;
}

/** La clave de este teléfono para el enlace del SOS (se crea la primera vez). */
async function claveDelEnlace() {
  let clave = await SecureStore.getItemAsync(CLAVE_ENLACE).catch(() => null);
  if (!clave) {
    clave = Crypto.randomUUID().replace(/-/g, "").slice(0, 16);
    await SecureStore.setItemAsync(CLAVE_ENLACE, clave, { keychainAccessible: SecureStore.AFTER_FIRST_UNLOCK }).catch(() => undefined);
  }
  return clave;
}

/** El enlace que hay que poner en el atajo de iPhone ("Abrir URL"). */
export async function sosShortcutLink() {
  return `ojoguard://sos?k=${await claveDelEnlace()}`;
}

/** Manda el SOS ya mismo y avisa cómo salió. */
export async function triggerSos() {
  if (enCurso || Date.now() - ultimo < ESPERA_MS) return;
  enCurso = true;
  try {
    const enrollment = await loadNativeEnrollment().catch(() => null);
    if (!enrollment) {
      await avisar("No se pudo mandar el SOS", "Este teléfono no está vinculado con Ojo Guard MS.");
      return;
    }
    for (let intento = 1; intento <= REINTENTOS; intento += 1) {
      try {
        const r = await sendSos(enrollment);
        ultimo = Date.now();
        await avisar(
          "SOS enviado",
          `Le avisamos a ${listaDeNombres(r.to)}. Si estás bien, abrí Ojo Guard y tocá «Estoy bien».`,
        );
        return;
      } catch (error) {
        const codigo = error instanceof SosError ? error.code : "red";
        // Solo la falta de conexión se reintenta: los demás errores no cambian por esperar.
        if (codigo === "red" && intento < REINTENTOS) {
          await pausa(ESPERA_REINTENTO_MS);
          continue;
        }
        await avisar(
          "No se pudo mandar el SOS",
          codigo === "no_recipients"
            ? "No hay nadie a quien avisar: sumá a alguien a tu familia."
            : "Revisá la conexión y probá de nuevo. Si es una emergencia, llamá a emergencias.",
        );
        return;
      }
    }
  } finally {
    enCurso = false;
  }
}

/** Cuándo se abrió por última vez el enlace del atajo de iPhone (ISO), o null si nunca. Lo usa el chequeo del Dr. Ojo Guard. */
export async function ultimoUsoDelAtajo() {
  return AsyncStorage.getItem(CLAVE_USO_ATAJO).catch(() => null);
}

/**
 * Android: hace sonar un aviso de prueba por el mismo canal que usa el SOS de la familia, para que la persona compruebe que se oye
 * (volumen de alarma, No interrumpir, auriculares Bluetooth conectados). Devuelve false si no se pudo mandar el aviso.
 */
export async function probarSirena() {
  if (Platform.OS !== "android") return false;
  try {
    await Notifications.scheduleNotificationAsync({
      identifier: "ojo-guard-sirena-prueba",
      content: { title: "Prueba de la sirena", body: "Si estás oyendo la sirena, un SOS de tu familia va a sonar así." },
      trigger: { channelId: SOS_CHANNEL },
    });
    return true;
  } catch {
    return false;
  }
}

/**
 * Android: avisa si el gesto de volumen figura prendido en Accesibilidad pero el servicio no está funcionando (pasa a veces
 * después de actualizar la app o por el ahorro de batería: el interruptor sigue en "Activado" y no hace nada). Sin aviso,
 * la persona se entera cuando lo necesita. Se mira al abrir la app, al volver al frente y con el trabajo periódico de
 * fondo; el servicio puede tardar unos segundos en engancharse, por eso mira varias veces antes de avisar. Como mucho un
 * aviso cada 12 horas. Si el interruptor está apagado a propósito no dice nada.
 */
export async function vigilarGesto() {
  if (Platform.OS !== "android" || !sosGestureAvailable() || !isSosGestureEnabled()) return;
  for (let intento = 0; intento < GESTO_INTENTOS; intento += 1) {
    const funcionando = isSosGestureRunning();
    // null: esta build no sabe decirlo, no se puede acusar al servicio.
    if (funcionando === null) return;
    if (funcionando) {
      await AsyncStorage.removeItem(CLAVE_AVISO_GESTO).catch(() => undefined);
      await Notifications.dismissNotificationAsync("ojo-guard-sos-gesto").catch(() => undefined);
      return;
    }
    if (intento < GESTO_INTENTOS - 1) await pausa(GESTO_ESPERA_MS);
  }
  const ultimoAviso = Number(await AsyncStorage.getItem(CLAVE_AVISO_GESTO).catch(() => null)) || 0;
  if (Date.now() - ultimoAviso < AVISO_GESTO_CADA_MS) return;
  try {
    await Notifications.scheduleNotificationAsync({
      identifier: "ojo-guard-sos-gesto",
      content: {
        title: "El gesto de volumen del SOS no está funcionando",
        body: "Android lo muestra activado pero no responde. Apagalo y volvelo a prender en Accesibilidad, o hacé el chequeo del Dr. Ojo Guard en Configuración > Familia.",
        sound: "default",
      },
      trigger: { channelId: CANAL },
    });
    await AsyncStorage.setItem(CLAVE_AVISO_GESTO, String(Date.now())).catch(() => undefined);
  } catch {
    // Sin permiso de notificaciones no hay cómo avisar: el chequeo del Dr. Ojo Guard lo muestra igual.
  }
}

if (Platform.OS === "android") {
  if (AppState.currentState === "active") void vigilarGesto();
  AppState.addEventListener("change", (estado) => {
    if (estado === "active") void vigilarGesto();
  });
}

// Android: la tarea que arranca el servicio nativo (SosTaskService.kt). El nombre tiene que coincidir exactamente.
if (Platform.OS === "android") {
  AppRegistry.registerHeadlessTask("OjoGuardSosTask", () => async () => {
    try {
      await triggerSos();
    } catch {
      // Nada más para hacer acá: quien lo pidió ve el aviso de error o vuelve a intentar.
    }
  });
}

// Enlace ojoguard://sos?k=<clave> (Atajos, Siri, toque en la espalda). Sin la clave de este teléfono no hace nada.
async function alAbrirEnlace(url: string | null | undefined) {
  if (!url || !/^ojoguard:\/\/sos(?![a-z0-9])/i.test(url)) return;
  const recibida = /[?&]k=([A-Za-z0-9]+)/.exec(url)?.[1];
  const guardada = await SecureStore.getItemAsync(CLAVE_ENLACE).catch(() => null);
  if (!recibida || !guardada || recibida !== guardada) {
    Alert.alert("Enlace de SOS no válido", "Abrí Ojo Guard, andá a Configuración > Familia y copiá de nuevo el enlace del SOS.");
    return;
  }
  await AsyncStorage.setItem(CLAVE_USO_ATAJO, new Date().toISOString()).catch(() => undefined);
  void triggerSos();
}

if (Platform.OS !== "web") {
  void Linking.getInitialURL().then(alAbrirEnlace).catch(() => undefined);
  Linking.addEventListener("url", (evento) => void alAbrirEnlace(evento.url));
}
