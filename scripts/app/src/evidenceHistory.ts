import AsyncStorage from "@react-native-async-storage/async-storage";
import * as FileSystem from "expo-file-system/legacy";

import type { CapturedLocation } from "./api";

const HISTORY_KEY = "ojo-guard-native-evidence-history-v1";
const HISTORY_DIRECTORY = `${FileSystem.documentDirectory}ojo-guard-history/`;
const HISTORY_FOLDER = "ojo-guard-history/";
const MAX_ATTEMPTS = 20;

/**
 * En iPhone la carpeta de datos de la app puede cambiar de identificador al actualizar o reinstalar (TestFlight), y las rutas guardadas con
 * el identificador viejo ya no son validas ("File ... is not writable"). Se guarda la ruta completa, pero al leerla se rearma con la carpeta
 * actual usando solo el nombre del archivo.
 */
function currentUri(uri: string): string;
function currentUri(uri: string | null | undefined): string | null;
function currentUri(uri: string | null | undefined): string | null {
  if (!uri) return null;
  const position = uri.lastIndexOf(HISTORY_FOLDER);
  return position >= 0 ? `${HISTORY_DIRECTORY}${uri.slice(position + HISTORY_FOLDER.length)}` : uri;
}

/** Borrar un archivo viejo nunca debe impedir guardar la evidencia nueva. */
async function safeDelete(uri: string) {
  try {
    await FileSystem.deleteAsync(uri, { idempotent: true });
  } catch {
    // Un archivo que no se puede borrar (ruta de una carpeta anterior) se deja: no es motivo para fallar.
  }
}

export type EvidenceAttempt = {
  id: string;
  imageUri: string;
  rearImageUri?: string | null;
  audioUri?: string | null;
  audioDurationSeconds?: number | null;
  occurredAt: string;
  location: CapturedLocation | null;
  deliveryStatus: "sent" | "queued" | "failed";
};

async function ensureHistoryDirectory() {
  const info = await FileSystem.getInfoAsync(HISTORY_DIRECTORY);
  if (!info.exists) {
    await FileSystem.makeDirectoryAsync(HISTORY_DIRECTORY, {
      intermediates: true,
    });
  }
}

export async function loadEvidenceHistory(): Promise<EvidenceAttempt[]> {
  const value = await AsyncStorage.getItem(HISTORY_KEY);
  if (!value) return [];
  try {
    const attempts = JSON.parse(value) as EvidenceAttempt[];
    if (!Array.isArray(attempts)) return [];
    return attempts.slice(0, MAX_ATTEMPTS).map((attempt) => ({
      ...attempt,
      imageUri: currentUri(attempt.imageUri),
      rearImageUri: currentUri(attempt.rearImageUri),
      audioUri: currentUri(attempt.audioUri),
    }));
  } catch {
    return [];
  }
}

export async function saveEvidenceAttempt({
  id,
  imageBase64,
  occurredAt,
  location,
  deliveryStatus,
  rearImageBase64,
  audioBase64,
  audioDurationSeconds,
}: Omit<EvidenceAttempt, "imageUri" | "rearImageUri" | "audioUri"> & {
  imageBase64: string;
  rearImageBase64?: string | null;
  audioBase64?: string | null;
}) {
  await ensureHistoryDirectory();
  const imageUri = `${HISTORY_DIRECTORY}${id}.jpg`;
  await FileSystem.writeAsStringAsync(imageUri, imageBase64, {
    encoding: FileSystem.EncodingType.Base64,
  });
  const rearImageUri = rearImageBase64
    ? `${HISTORY_DIRECTORY}${id}-back.jpg`
    : null;
  if (rearImageUri && rearImageBase64) {
    await FileSystem.writeAsStringAsync(rearImageUri, rearImageBase64, {
      encoding: FileSystem.EncodingType.Base64,
    });
  }
  const audioUri = audioBase64 ? `${HISTORY_DIRECTORY}${id}.m4a` : null;
  if (audioUri && audioBase64) {
    await FileSystem.writeAsStringAsync(audioUri, audioBase64, {
      encoding: FileSystem.EncodingType.Base64,
    });
  }

  const previous = await loadEvidenceHistory();
  const next = [
    {
      id,
      imageUri,
      rearImageUri,
      audioUri,
      audioDurationSeconds: audioDurationSeconds ?? null,
      occurredAt,
      location,
      deliveryStatus,
    },
    ...previous.filter((attempt) => attempt.id !== id),
  ];
  const kept = next.slice(0, MAX_ATTEMPTS);
  const removed = next.slice(MAX_ATTEMPTS);
  await AsyncStorage.setItem(HISTORY_KEY, JSON.stringify(kept));
  await Promise.all(
    removed.flatMap((attempt) => [
      safeDelete(attempt.imageUri),
      ...(attempt.rearImageUri ? [safeDelete(attempt.rearImageUri)] : []),
      ...(attempt.audioUri ? [safeDelete(attempt.audioUri)] : []),
    ]),
  );
  return kept;
}

/**
 * Actualiza solamente el estado de entrega de un intento ya guardado
 * (por ejemplo de "queued" a "sent" cuando el servidor confirma la
 * recepción), sin volver a escribir los archivos de evidencia.
 */
export async function updateEvidenceAttemptStatus(
  id: string,
  deliveryStatus: EvidenceAttempt["deliveryStatus"],
) {
  const attempts = await loadEvidenceHistory();
  if (!attempts.some((attempt) => attempt.id === id)) return attempts;
  const next = attempts.map((attempt) =>
    attempt.id === id ? { ...attempt, deliveryStatus } : attempt,
  );
  await AsyncStorage.setItem(HISTORY_KEY, JSON.stringify(next));
  return next;
}

export async function clearEvidenceHistory() {
  const attempts = await loadEvidenceHistory();
  await Promise.all(
    attempts.flatMap((attempt) => [
      safeDelete(attempt.imageUri),
      ...(attempt.rearImageUri ? [safeDelete(attempt.rearImageUri)] : []),
      ...(attempt.audioUri ? [safeDelete(attempt.audioUri)] : []),
    ]),
  );
  await AsyncStorage.removeItem(HISTORY_KEY);
}
