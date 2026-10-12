import * as Location from "expo-location";

import { direccionPara, startLiveLocation, stopLiveLocation } from "./liveLocation";
import type { LiveLocationPoint } from "./remoteApi";
import type { NativeEnrollment } from "./remoteStorage";

/**
 * SOS de Familia: la persona pide ayuda desde su teléfono. El servidor le avisa al titular y a los adultos de su
 * familia (a un amigo, solo al titular que lo invitó) con sirena, mail y, si lo tienen activado, SMS, y deja su
 * ubicación en vivo 10 minutos. Quien lo manda ve a quién le avisó y lo puede cancelar ("Estoy bien").
 *
 * Esto es lo que usan el botón de la app (SosBlock.tsx) y, más adelante, los disparadores que no necesitan abrirla.
 * No toca remoteApi.ts a propósito: llama al servidor directo, así sirve igual sin importar qué más se haya aplicado.
 */

const OJO_REMOTE_API_BASE = "https://ojo-guard-ms-api.bickluciano.workers.dev";
const UBICACION_ESPERA_MS = 6_000;
const DIRECCION_ESPERA_MS = 2_500;

export type SosEstado = { id: string; createdAt: string; to: string[] };

/** `code` es el error del servidor ("no_recipients", "unauthorized"…) o `red` si no hubo conexión. */
export class SosError extends Error {
  code: string;
  constructor(code: string) {
    super(code);
    this.code = code;
  }
}

async function pedir(enrollment: NativeEnrollment, path: string, init?: RequestInit) {
  let response: Response;
  try {
    response = await fetch(`${OJO_REMOTE_API_BASE}${path}`, {
      ...init,
      headers: {
        accept: "application/json",
        authorization: `Bearer ${enrollment.accessToken}`,
        "content-type": "application/json",
      },
    });
  } catch {
    throw new SosError("red");
  }
  const result = (await response.json().catch(() => ({}))) as Record<string, unknown>;
  if (!response.ok) throw new SosError(typeof result.error === "string" ? result.error : `http_${response.status}`);
  return result;
}

/** El SOS que este teléfono tiene en curso, o null. */
export async function fetchMySos(enrollment: NativeEnrollment): Promise<SosEstado | null> {
  const query = new URLSearchParams({ deviceId: enrollment.deviceId });
  const result = await pedir(enrollment, `/api/native/family?${query.toString()}`);
  const me = result.me as { sos?: { id?: unknown; createdAt?: unknown; to?: unknown } | null } | undefined;
  const sos = me?.sos;
  if (!sos || typeof sos.id !== "string") return null;
  return {
    id: sos.id,
    createdAt: typeof sos.createdAt === "string" ? sos.createdAt : new Date().toISOString(),
    to: Array.isArray(sos.to) ? sos.to.map(String) : [],
  };
}

/** La ubicación de ahora (GPS, con tope de espera) o, si no hay, la última conocida. Sin permiso devuelve null. */
export async function currentSosLocation(): Promise<LiveLocationPoint | null> {
  let permiso = await Location.getForegroundPermissionsAsync().catch(() => null);
  if (!permiso?.granted) permiso = await Location.requestForegroundPermissionsAsync().catch(() => null);
  if (!permiso?.granted) return null;
  const position =
    (await Promise.race([
      Location.getCurrentPositionAsync({ accuracy: Location.Accuracy.High }).catch(() => null),
      new Promise<null>((resolve) => setTimeout(() => resolve(null), UBICACION_ESPERA_MS)),
    ])) ?? (await Location.getLastKnownPositionAsync({ maxAge: 5 * 60_000 }).catch(() => null));
  if (!position) return null;
  const direccion = await Promise.race([
    direccionPara(position).catch(() => null),
    new Promise<null>((resolve) => setTimeout(() => resolve(null), DIRECCION_ESPERA_MS)),
  ]);
  return {
    latitude: position.coords.latitude,
    longitude: position.coords.longitude,
    accuracy: Math.max(0, Number(position.coords.accuracy) || 0),
    capturedAt: new Date(position.timestamp).toISOString(),
    altitude: position.coords.altitude ?? null,
    heading:
      Number.isFinite(position.coords.heading) && (position.coords.heading as number) >= 0 ? position.coords.heading : null,
    speed:
      Number.isFinite(position.coords.speed) && (position.coords.speed as number) >= 0 ? position.coords.speed : null,
    address: direccion,
    live: false,
  };
}

/**
 * Manda el SOS con la ubicación de ahora. Si ya había uno en curso no vuelve a avisar: solo renueva la ubicación en
 * vivo. Devuelve a quién se le avisó. Lanza SosError (por ejemplo "no_recipients" si no hay nadie a quién avisar).
 */
export async function sendSos(enrollment: NativeEnrollment): Promise<{ id: string; to: string[]; repeated: boolean }> {
  const punto = await currentSosLocation().catch(() => null);
  const result = await pedir(enrollment, "/api/native/family/sos", {
    method: "POST",
    body: JSON.stringify({ deviceId: enrollment.deviceId, ...(punto ? { location: punto } : {}) }),
  });
  // Mientras dura el SOS, este teléfono manda su ubicación cada pocos segundos (si el permiso lo deja).
  if (typeof result.until === "string") await startLiveLocation(result.until).catch(() => undefined);
  return {
    id: String(result.id ?? ""),
    to: Array.isArray(result.to) ? result.to.map(String) : [],
    repeated: result.repeated === true,
  };
}

/** "Estoy bien": cancela el SOS, le avisa a quienes lo recibieron y corta la ubicación en vivo. */
export async function cancelSos(enrollment: NativeEnrollment): Promise<void> {
  await pedir(enrollment, "/api/native/family/sos", {
    method: "POST",
    body: JSON.stringify({ deviceId: enrollment.deviceId, action: "cancel" }),
  });
  await stopLiveLocation("estoy bien").catch(() => undefined);
}
