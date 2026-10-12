import { Alert, AppRegistry, AppState, Linking, Platform } from "react-native";
import * as Crypto from "expo-crypto";
import * as Notifications from "expo-notifications";
import * as SecureStore from "expo-secure-store";

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

let enCurso = false;
let ultimo = 0;

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
  void triggerSos();
}

if (Platform.OS !== "web") {
  void Linking.getInitialURL().then(alAbrirEnlace).catch(() => undefined);
  Linking.addEventListener("url", (evento) => void alAbrirEnlace(evento.url));
}
