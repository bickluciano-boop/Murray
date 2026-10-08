import * as Location from "expo-location";
import * as TaskManager from "expo-task-manager";
import { AppState, Platform } from "react-native";

import { direccionPara, liveLocationRunning } from "./liveLocation";
import { fetchFamily, sendLiveLocation, type LiveLocationPoint } from "./remoteApi";
import { loadNativeEnrollment } from "./remoteStorage";

/**
 * Ubicación para FAMILIA en iPhone: si este teléfono comparte su ubicación con
 * alguien (Configuración › Familia y amigos), la manda solo, aunque Ojo Guard
 * esté cerrada.
 *
 * POR QUÉ HACE FALTA. En Android el servidor despierta a la app cada 15 minutos
 * con un push y la app contesta con su ubicación. En iPhone ese push no despierta
 * a la app de forma confiable: el 08/10/2026 el iPhone quedó 6 horas sin mandar
 * nada mientras su dueño caminaba por la calle, y se puso al día apenas se abrió
 * la app.
 *
 * CÓMO FUNCIONA. Se usa el seguimiento en segundo plano de iPhone
 * (`startLocationUpdatesAsync`): sale un punto cada vez que el teléfono se movió
 * unos 150 m, como mucho uno por minuto. Quieto, iPhone lo pausa solo y no gasta.
 * La librería además activa los "cambios importantes de ubicación": con eso
 * iPhone vuelve a abrir la app cuando la persona se mueve, aunque la hayan
 * cerrado, y desde ahí el seguimiento se reactiva. Necesita el permiso de
 * ubicación "Siempre"; sin él no arranca y Familia muestra cómo darlo.
 *
 * CUÁNDO. Se revisa al abrir la app y cada vez que vuelve al frente: si la
 * persona está en una familia, se prende (o se reactiva, por si iPhone lo había
 * pausado); si ya no está en ninguna, se apaga. En Android no hace nada.
 */

const TAREA_FAMILIA = "ojo-guard-family-location-v1";
const OPCIONES: Location.LocationTaskOptions = {
  accuracy: Location.Accuracy.Balanced,
  distanceInterval: 150,
  deferredUpdatesInterval: 60_000,
  pausesUpdatesAutomatically: true,
  activityType: Location.ActivityType.Other,
  showsBackgroundLocationIndicator: false,
};
// Si iPhone pausó el seguimiento (quieto un rato) y un cambio importante despierta
// a la app, se vuelve a pedir, como mucho cada 10 minutos.
const REACTIVAR_CADA_MS = 10 * 60_000;
// Face ID y el centro de control también disparan "volvió al frente": no hace
// falta revisar más de una vez por minuto.
const REVISAR_CADA_MS = 60_000;

let ultimaActivacion = 0;
let ultimaRevision = 0;

async function activar() {
  ultimaActivacion = Date.now();
  // Si la tarea ya existe, esto solo vuelve a aplicar las opciones y reanuda el
  // seguimiento que iPhone hubiera pausado.
  await Location.startLocationUpdatesAsync(TAREA_FAMILIA, OPCIONES);
}

/** En iPhone, si la ubicación está permitida "Siempre" (en Android no se usa: devuelve true). */
export async function familyLocationAllowed() {
  if (Platform.OS !== "ios") return true;
  const permiso = await Location.getBackgroundPermissionsAsync().catch(() => null);
  return Boolean(permiso?.granted);
}

/** Prende, reactiva o apaga la ubicación para la familia según si este teléfono comparte con alguien. */
export async function adjustFamilyLocation() {
  if (Platform.OS !== "ios") return;
  ultimaRevision = Date.now();
  const enrollment = await loadNativeEnrollment().catch(() => null);
  let comparte = false;
  if (enrollment) {
    try {
      // Dentro de una familia la visibilidad es mutua: si este teléfono ve a
      // alguien, ese alguien lo ve a él.
      comparte = (await fetchFamily(enrollment)).people.length > 0;
    } catch {
      return; // Sin red: se deja como estaba.
    }
  }
  if (!comparte) {
    if (await Location.hasStartedLocationUpdatesAsync(TAREA_FAMILIA).catch(() => false)) {
      await Location.stopLocationUpdatesAsync(TAREA_FAMILIA).catch(() => undefined);
    }
    return;
  }
  if (!(await familyLocationAllowed())) return;
  await activar().catch(() => undefined);
}

/** Para App.tsx: revisa al abrir y cada vez que la app vuelve al frente. Devuelve la limpieza. */
export function watchFamilyLocation() {
  if (Platform.OS !== "ios") return () => undefined;
  void adjustFamilyLocation();
  const suscripcion = AppState.addEventListener("change", (estado) => {
    if (estado === "active" && Date.now() - ultimaRevision >= REVISAR_CADA_MS) void adjustFamilyLocation();
  });
  return () => suscripcion.remove();
}

if (Platform.OS === "ios" && !TaskManager.isTaskDefined(TAREA_FAMILIA)) {
  TaskManager.defineTask<{ locations?: Location.LocationObject[] }>(TAREA_FAMILIA, async ({ data, error }) => {
    if (error) return;
    const position = data?.locations?.[data.locations.length - 1];
    if (!position) return;
    // Con "Seguir en vivo" prendido ya sale un punto cada 5 segundos.
    if (await liveLocationRunning()) return;
    const enrollment = await loadNativeEnrollment().catch(() => null);
    if (!enrollment) {
      await Location.stopLocationUpdatesAsync(TAREA_FAMILIA).catch(() => undefined);
      return;
    }
    const punto: LiveLocationPoint = {
      latitude: position.coords.latitude,
      longitude: position.coords.longitude,
      accuracy: Math.max(0, Number(position.coords.accuracy) || 0),
      capturedAt: new Date(position.timestamp).toISOString(),
      altitude: position.coords.altitude ?? null,
      heading:
        Number.isFinite(position.coords.heading) && (position.coords.heading as number) >= 0
          ? position.coords.heading
          : null,
      speed:
        Number.isFinite(position.coords.speed) && (position.coords.speed as number) >= 0
          ? position.coords.speed
          : null,
      address: await direccionPara(position),
      live: false,
    };
    // Sin red se pierde este punto; el próximo movimiento manda otro.
    await sendLiveLocation(enrollment, punto).catch(() => undefined);
    if (AppState.currentState !== "active" && Date.now() - ultimaActivacion > REACTIVAR_CADA_MS) {
      await activar().catch(() => undefined);
    }
  });
}
