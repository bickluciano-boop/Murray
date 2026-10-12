import * as Location from "expo-location";
import * as TaskManager from "expo-task-manager";
import { Platform } from "react-native";

import { direccionPara } from "./liveLocation";
import { sendLiveLocation, type LiveLocationPoint } from "./remoteApi";
import { loadNativeEnrollment, type NativeEnrollment } from "./remoteStorage";

/**
 * Avisos de llegada y salida en iPhone ("avisame cuando X llegue o salga de Casa"), con geocercos del sistema.
 *
 * POR QUÉ HACE FALTA. El seguimiento por movimiento (familyLocation.ts) manda un punto cada tantos metros y
 * se pausa solo cuando el teléfono queda quieto. El 11/10/2026 el último punto del viaje quedó a 245 m de
 * casa, la llegada nunca se reportó y el aviso "llegó a Casa" no salió.
 *
 * CÓMO FUNCIONA. El servidor dice qué círculos hay que vigilar: los lugares de los avisos que alguien armó
 * sobre esta persona. Por cada uno se registran dos geocercos del sistema:
 *   - uno del tamaño del lugar, que avisa al ENTRAR;
 *   - otro un poco más grande, que avisa al SALIR (coincide con el margen que usa el servidor para dar por
 *     terminada la estadía, así un rebote del GPS en el borde no arma un aviso falso).
 * iPhone vigila los geocercos por su cuenta, casi sin gastar batería, y despierta a la app al cruzarlos aunque
 * esté cerrada. Ahí se pide una ubicación fresca y se manda: el servidor decide si corresponde avisar.
 *
 * CUÁNDO. La lista se renueva al abrir la app y cada vez que vuelve al frente, y mientras el teléfono se mueve
 * (como mucho cada 10 minutos). Un aviso nuevo empieza a valer cuando el teléfono de esa persona renueva la lista.
 * iPhone permite 20 geocercos por app: alcanza para 10 lugares. Necesita el permiso de ubicación "Siempre".
 * En Android no hace nada: ahí el servidor despierta a la app cada 15 minutos con un push.
 */

const TAREA_GEOCERCO = "ojo-guard-family-geofence-v1";
const OJO_REMOTE_API_BASE = "https://ojo-guard-ms-api.bickluciano.workers.dev";
// Cada lugar usa dos geocercos y iPhone permite 20 por app.
const MAXIMO_GEOCERCOS = 20;
// iPhone no mide bien círculos de menos de unos 100 m.
const RADIO_MINIMO = 100;
const RENOVAR_CADA_MS = 10 * 60_000;
// Al despertar por un geocerco iPhone da unos 10 segundos: la ubicación y la dirección tienen tope de espera.
const UBICACION_ESPERA_MS = 6_000;
const DIRECCION_ESPERA_MS = 2_000;

type Lugar = { id: string; latitude: number; longitude: number; radius: number; outerRadius: number };

let ultimaRenovacion = 0;
let renovando = false;

async function pedirLugares(enrollment: NativeEnrollment): Promise<Lugar[] | null> {
  const query = new URLSearchParams({ deviceId: enrollment.deviceId });
  const response = await fetch(`${OJO_REMOTE_API_BASE}/api/native/family/regions?${query.toString()}`, {
    headers: { accept: "application/json", authorization: `Bearer ${enrollment.accessToken}` },
  });
  if (!response.ok) return null;
  const result = (await response.json().catch(() => null)) as { regions?: Partial<Lugar>[] } | null;
  if (!result || !Array.isArray(result.regions)) return null;
  const lugares: Lugar[] = [];
  for (const r of result.regions) {
    const { id, latitude, longitude, radius, outerRadius } = r;
    if (typeof id !== "string" || typeof latitude !== "number" || typeof longitude !== "number") continue;
    if (typeof radius !== "number" || typeof outerRadius !== "number") continue;
    lugares.push({ id, latitude, longitude, radius, outerRadius });
  }
  return lugares;
}

/** Deja de vigilar los lugares (por ejemplo, cuando este teléfono ya no está en ninguna familia). */
export async function stopFamilyGeofences() {
  if (Platform.OS !== "ios") return;
  if (await Location.hasStartedGeofencingAsync(TAREA_GEOCERCO).catch(() => false)) {
    await Location.stopGeofencingAsync(TAREA_GEOCERCO).catch(() => undefined);
  }
}

/**
 * Pide al servidor los lugares a vigilar y los registra en iPhone (reemplaza los anteriores).
 * Sin `forzar`, como mucho una vez cada 10 minutos. Sin red, deja lo que ya estaba registrado.
 */
export async function adjustFamilyGeofences(forzar = false) {
  if (Platform.OS !== "ios" || renovando) return;
  if (!forzar && Date.now() - ultimaRenovacion < RENOVAR_CADA_MS) return;
  renovando = true;
  try {
    const enrollment = await loadNativeEnrollment().catch(() => null);
    if (!enrollment) {
      await stopFamilyGeofences();
      return;
    }
    const lugares = await pedirLugares(enrollment).catch(() => null);
    if (!lugares) return;
    ultimaRenovacion = Date.now();
    if (!lugares.length) {
      await stopFamilyGeofences();
      return;
    }
    const permiso = await Location.getBackgroundPermissionsAsync().catch(() => null);
    if (!permiso?.granted) return;
    const regiones: Location.LocationRegion[] = [];
    for (const lugar of lugares) {
      regiones.push({
        identifier: `${lugar.id}:entrar`,
        latitude: lugar.latitude,
        longitude: lugar.longitude,
        radius: Math.max(RADIO_MINIMO, lugar.radius),
        notifyOnEnter: true,
        notifyOnExit: false,
      });
      regiones.push({
        identifier: `${lugar.id}:salir`,
        latitude: lugar.latitude,
        longitude: lugar.longitude,
        radius: Math.max(RADIO_MINIMO, lugar.outerRadius),
        notifyOnEnter: false,
        notifyOnExit: true,
      });
    }
    await Location.startGeofencingAsync(TAREA_GEOCERCO, regiones.slice(0, MAXIMO_GEOCERCOS));
  } finally {
    renovando = false;
  }
}

if (Platform.OS === "ios" && !TaskManager.isTaskDefined(TAREA_GEOCERCO)) {
  TaskManager.defineTask(TAREA_GEOCERCO, async ({ error }) => {
    if (error) return;
    // iPhone avisa que se cruzó un borde, pero no trae la ubicación: se pide una fresca y se manda.
    const enrollment = await loadNativeEnrollment().catch(() => null);
    if (!enrollment) {
      await stopFamilyGeofences();
      return;
    }
    const position =
      (await Promise.race([
        Location.getCurrentPositionAsync({ accuracy: Location.Accuracy.High }).catch(() => null),
        new Promise<null>((resolve) => setTimeout(() => resolve(null), UBICACION_ESPERA_MS)),
      ])) ?? (await Location.getLastKnownPositionAsync({ maxAge: 60_000 }).catch(() => null));
    if (!position) return;
    const direccion = await Promise.race([
      direccionPara(position).catch(() => null),
      new Promise<null>((resolve) => setTimeout(() => resolve(null), DIRECCION_ESPERA_MS)),
    ]);
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
      address: direccion,
      live: false,
    };
    // Sin red se pierde este punto: el próximo movimiento o cruce manda otro.
    await sendLiveLocation(enrollment, punto).catch(() => undefined);
  });
}
