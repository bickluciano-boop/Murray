import AsyncStorage from "@react-native-async-storage/async-storage";
import * as Location from "expo-location";
import * as TaskManager from "expo-task-manager";
import { AppState, Platform } from "react-native";

/**
 * PROTECCION REFORZADA (solo Android, y solo si la persona la prende en Configuración › Permisos de Android).
 *
 * POR QUÉ. El 18/11/2026 el Android de Luciano estuvo casi 5 horas (13:24 a 18:21) sin que la app se despertara: las alarmas de cada 15
 * minutos se cortaron y el Modo Perdido, la alarma y la evidencia pedidos desde el panel quedaron esperando hasta que alguien tocó el teléfono.
 * En el registro técnico de la app no hay ni una sincronización en esas horas (y de noche, con el teléfono igual de quieto, funcionó 6 horas).
 * No se pudo probar la causa; esto es la defensa estándar de Android: un servicio en primer plano. Con él la app deja de ser "una app
 * en caché" y el sistema no la congela.
 *
 * QUÉ HACE. Prende un seguimiento de ubicación de muy bajo consumo (precisión equilibrada, un punto cada 10 minutos, que no se manda a
 * ningún lado) cuyo único fin es mantener el servicio en primer plano. Se ve una notificación fija y discreta. No manda datos ni cambia
 * lo que ya hace la app: solo la mantiene despierta.
 *
 * LÍMITES (honestos). (1) Necesita el permiso de ubicación "Permitir todo el tiempo", el mismo de "Seguir en vivo". (2) Tras reiniciar el
 * teléfono Android no deja arrancar un servicio de ubicación hasta que alguien abre la app: se reanuda sola al abrirla. (3) No se probó
 * todavía que cure el corte del 18/11: se prueba dejando el teléfono quieto un par de horas y mirando el registro técnico.
 */

const TAREA = "ojo-guard-refuerzo-v1";
const CLAVE = "ojo-guard-refuerzo-activo-v1";
const INTERVALO_MS = 10 * 60_000;
// Face ID y el centro de control también disparan "volvió al frente": no hace falta revisar más de una vez por minuto.
const REVISAR_CADA_MS = 60_000;

let ultimaRevision = 0;

export const proteccionReforzadaDisponible = Platform.OS === "android";

export type ResultadoActivar = "ok" | "sin_permiso" | "error";

export async function proteccionReforzadaPrendida() {
  if (!proteccionReforzadaDisponible) return false;
  return (await AsyncStorage.getItem(CLAVE).catch(() => null)) === "1";
}

export async function proteccionReforzadaCorriendo() {
  if (!proteccionReforzadaDisponible) return false;
  return Location.hasStartedLocationUpdatesAsync(TAREA).catch(() => false);
}

async function arrancar() {
  await Location.startLocationUpdatesAsync(TAREA, {
    accuracy: Location.Accuracy.Balanced,
    timeInterval: INTERVALO_MS,
    distanceInterval: 0,
    deferredUpdatesInterval: 0,
    pausesUpdatesAutomatically: false,
    activityType: Location.ActivityType.Other,
    showsBackgroundLocationIndicator: false,
    foregroundService: {
      notificationTitle: "Ojo Guard protege este teléfono",
      notificationBody: "Protección reforzada activa.",
      notificationColor: "#D9B24C",
      killServiceOnDestroy: false,
    },
  });
}

async function permisoDeUbicacion() {
  const primero = await Location.getForegroundPermissionsAsync().catch(() => null);
  const fondo = await Location.getBackgroundPermissionsAsync().catch(() => null);
  return Boolean(primero?.granted && fondo?.granted);
}

/** Prende la protección reforzada. Hay que llamarla con la app a la vista (Android no deja arrancar este servicio desde el fondo). */
export async function activarProteccionReforzada(): Promise<ResultadoActivar> {
  if (!proteccionReforzadaDisponible) return "error";
  if (!(await permisoDeUbicacion())) return "sin_permiso";
  try {
    await arrancar();
    await AsyncStorage.setItem(CLAVE, "1");
    return "ok";
  } catch {
    return "error";
  }
}

export async function desactivarProteccionReforzada() {
  if (!proteccionReforzadaDisponible) return;
  await AsyncStorage.removeItem(CLAVE).catch(() => undefined);
  if (await proteccionReforzadaCorriendo()) await Location.stopLocationUpdatesAsync(TAREA).catch(() => undefined);
}

/** Si la persona la dejó prendida y el servicio no está corriendo (reinicio del teléfono, el sistema lo cortó), lo vuelve a arrancar. */
export async function reanudarProteccionReforzada() {
  if (!proteccionReforzadaDisponible) return;
  ultimaRevision = Date.now();
  if (!(await proteccionReforzadaPrendida())) return;
  if (await proteccionReforzadaCorriendo()) return;
  if (!(await permisoDeUbicacion())) return;
  // Si Android no deja arrancarlo desde el fondo, se reintenta la próxima vez que la app se vea.
  await arrancar().catch(() => undefined);
}

if (proteccionReforzadaDisponible) {
  // La tarea no hace nada con los puntos: existe solo para mantener el servicio en primer plano.
  if (!TaskManager.isTaskDefined(TAREA)) TaskManager.defineTask(TAREA, async () => undefined);
  void reanudarProteccionReforzada();
  AppState.addEventListener("change", (estado) => {
    if (estado === "active" && Date.now() - ultimaRevision >= REVISAR_CADA_MS) void reanudarProteccionReforzada();
  });
}
