import AsyncStorage from "@react-native-async-storage/async-storage";
import * as Location from "expo-location";
import * as TaskManager from "expo-task-manager";
import { Platform } from "react-native";

import { recordFullScreenAlertAttempt } from "./fullScreenAlertDiagnostics";
import { sendLiveLocation, type LiveLocationPoint } from "./remoteApi";
import { loadNativeEnrollment } from "./remoteStorage";

/**
 * Ubicación EN VIVO: mientras el titular mira el mapa de Ojo Guard MS y toca
 * "Seguir en vivo", el teléfono manda su posición cada pocos segundos.
 *
 * CÓMO FUNCIONA. El panel crea una orden `live` en el servidor; la orden llega
 * como cualquier otra (push → backgroundRemoteTask, o la app abierta) y su
 * `expiresAt` dice hasta cuándo seguir. Acá se arranca el seguimiento de
 * Android (`startLocationUpdatesAsync`) con un servicio en primer plano: la
 * notificación fija "Ojo Guard está compartiendo tu ubicación" la exige
 * Android y, además, es lo honesto con quien tiene el teléfono en la mano.
 *
 * CÓMO SE APAGA. Cada punto que se manda vuelve con `live` y `until` del
 * servidor: si el panel se cerró (o pasaron los minutos pedidos) `live` llega
 * en false y el seguimiento se corta solo. Si no hay red, se corta igual al
 * llegar a `until`, que se guarda acá. Nunca dura más de MAXIMO_MS aunque el
 * servidor pida más, para que un error no deje el GPS prendido horas.
 */

const TAREA_EN_VIVO = "ojo-guard-live-location-v1";
const CLAVE_HASTA = "ojo-guard-live-until-v1";
const CLAVE_DIRECCION = "ojo-guard-live-address-v1";
const INTERVALO_MS = 5_000;
const MAXIMO_MS = 30 * 60_000;
// La dirección en texto no cambia cada 5 segundos: se vuelve a pedir recién
// cuando el teléfono se movió bastante o pasó un rato.
const DIRECCION_CADA_MS = 60_000;
const DIRECCION_CADA_METROS = 80;

type DireccionGuardada = { latitude: number; longitude: number; at: number; text: string | null };

function metros(a: { latitude: number; longitude: number }, b: { latitude: number; longitude: number }) {
  const R = 6371000;
  const rad = Math.PI / 180;
  const dLat = (b.latitude - a.latitude) * rad;
  const dLng = (b.longitude - a.longitude) * rad;
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(a.latitude * rad) * Math.cos(b.latitude * rad) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

async function direccionPara(position: Location.LocationObject): Promise<string | null> {
  const punto = { latitude: position.coords.latitude, longitude: position.coords.longitude };
  let guardada: DireccionGuardada | null = null;
  try {
    guardada = JSON.parse((await AsyncStorage.getItem(CLAVE_DIRECCION)) || "null") as DireccionGuardada | null;
  } catch {
    guardada = null;
  }
  if (
    guardada &&
    Date.now() - guardada.at < DIRECCION_CADA_MS &&
    metros(guardada, punto) < DIRECCION_CADA_METROS
  ) {
    return guardada.text;
  }
  let text: string | null = guardada?.text ?? null;
  try {
    const [address] = await Promise.race([
      Location.reverseGeocodeAsync(punto),
      new Promise<never>((_, reject) => setTimeout(() => reject(new Error("reverse_geocode_timeout")), 3_000)),
    ]);
    if (address) {
      text = [
        [address.street ?? address.name, address.streetNumber].filter(Boolean).join(" "),
        address.district,
        address.city,
      ]
        .filter(Boolean)
        .join(", ") || text;
    }
  } catch {
    // Sin dirección nueva se manda la anterior: las coordenadas son lo que importa.
  }
  await AsyncStorage.setItem(CLAVE_DIRECCION, JSON.stringify({ ...punto, at: Date.now(), text })).catch(() => undefined);
  return text;
}

async function hastaGuardado(): Promise<number> {
  const valor = Number(await AsyncStorage.getItem(CLAVE_HASTA).catch(() => null));
  return Number.isFinite(valor) ? valor : 0;
}

async function guardarHasta(hastaIso: string | null | undefined) {
  const pedido = Date.parse(String(hastaIso ?? ""));
  if (!Number.isFinite(pedido)) return;
  await AsyncStorage.setItem(CLAVE_HASTA, String(Math.min(pedido, Date.now() + MAXIMO_MS)));
}

export async function liveLocationRunning() {
  if (Platform.OS === "web") return false;
  return Location.hasStartedLocationUpdatesAsync(TAREA_EN_VIVO).catch(() => false);
}

/** Arranca (o prolonga) la ubicación en vivo hasta `hastaIso`. */
export async function startLiveLocation(hastaIso: string) {
  if (Platform.OS === "web") return;
  await guardarHasta(hastaIso);
  const foreground = await Location.getForegroundPermissionsAsync();
  const background = await Location.getBackgroundPermissionsAsync();
  // Sin "Permitir todo el tiempo" Android no deja seguir la ubicación con la
  // pantalla apagada: se informa como falla para que el panel lo diga claro.
  if (!foreground.granted || !background.granted) {
    throw new Error("background_location_not_granted");
  }
  if (await liveLocationRunning()) return;
  await Location.startLocationUpdatesAsync(TAREA_EN_VIVO, {
    accuracy: Location.Accuracy.High,
    timeInterval: INTERVALO_MS,
    distanceInterval: 0,
    deferredUpdatesInterval: 0,
    pausesUpdatesAutomatically: false,
    activityType: Location.ActivityType.Other,
    showsBackgroundLocationIndicator: true,
    foregroundService: {
      notificationTitle: "Ojo Guard está compartiendo tu ubicación",
      notificationBody: "Se pidió desde Ojo Guard MS. Se apaga sola en unos minutos.",
      notificationColor: "#D9B24C",
      killServiceOnDestroy: false,
    },
  });
  await recordFullScreenAlertAttempt({
    reason: "ubicacion-en-vivo",
    moduleFound: true,
    result: true,
    error: `arranco, sigue hasta ${new Date(await hastaGuardado()).toISOString()}`,
  });
}

export async function stopLiveLocation(motivo = "pedido") {
  await AsyncStorage.removeItem(CLAVE_HASTA).catch(() => undefined);
  if (!(await liveLocationRunning())) return;
  await Location.stopLocationUpdatesAsync(TAREA_EN_VIVO).catch(() => undefined);
  await recordFullScreenAlertAttempt({
    reason: "ubicacion-en-vivo",
    moduleFound: true,
    result: true,
    error: `se apago (${motivo})`,
  });
}

if (Platform.OS !== "web" && !TaskManager.isTaskDefined(TAREA_EN_VIVO)) {
  TaskManager.defineTask<{ locations?: Location.LocationObject[] }>(TAREA_EN_VIVO, async ({ data, error }) => {
    if (error) return;
    const position = data?.locations?.[data.locations.length - 1];
    if (!position) return;
    if (Date.now() > (await hastaGuardado())) {
      await stopLiveLocation("vencio");
      return;
    }
    const enrollment = await loadNativeEnrollment().catch(() => null);
    if (!enrollment) {
      await stopLiveLocation("sin vinculo");
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
      live: true,
    };
    try {
      const respuesta = await sendLiveLocation(enrollment, punto);
      if (!respuesta.live) await stopLiveLocation("el panel lo apago");
      else await guardarHasta(respuesta.until);
    } catch {
      // Sin red o servidor caído: se reintenta con el próximo punto, y el
      // corte por `until` guardado sigue valiendo.
    }
  });
}
