import AsyncStorage from "@react-native-async-storage/async-storage";
import * as ImageManipulator from "expo-image-manipulator";
import { loadNativeEnrollment } from "./remoteStorage";

// La foto de perfil se comparte con el circulo: se achica a 256 px de ancho (unos 10-30 KB) y se sube al servidor, que solo se la muestra
// a quienes ya ven a esta persona en la lista de familia. Se guarda aparte cual foto del telefono ya se subio para no pedirlo dos veces.

const URL_API = "https://ojo-guard-ms-api.bickluciano.workers.dev";
const CLAVE_SUBIDA = "ojo_perfil_subida_v1";
const ANCHO_PERFIL = 256;

type ResultadoReduccion = { uri: string; base64?: string | undefined };
type OpcionesGuardado = { compress: number; format: string; base64: boolean };
type ManipuladorCompat = {
  manipulateAsync?: (uri: string, acciones: Array<{ resize: { width: number } }>, opciones: OpcionesGuardado) => Promise<ResultadoReduccion>;
  manipulate?: (uri: string) => {
    resize: (tam: { width: number }) => unknown;
    renderAsync: () => Promise<{ saveAsync: (opciones: OpcionesGuardado) => Promise<ResultadoReduccion> }>;
  };
};

// Igual que la selfie de la verificacion: API vieja (manipulateAsync) o nueva (manipulate) segun la version de expo-image-manipulator.
async function reducirPerfil(uri: string): Promise<string | null> {
  try {
    const m = ImageManipulator as unknown as ManipuladorCompat;
    const opciones: OpcionesGuardado = { compress: 0.7, format: "jpeg", base64: true };
    let r: ResultadoReduccion | null = null;
    if (typeof m.manipulateAsync === "function") {
      r = await m.manipulateAsync(uri, [{ resize: { width: ANCHO_PERFIL } }], opciones);
    } else if (typeof m.manipulate === "function") {
      const contexto = m.manipulate(uri);
      contexto.resize({ width: ANCHO_PERFIL });
      const imagen = await contexto.renderAsync();
      r = await imagen.saveAsync(opciones);
    }
    return r?.base64 ?? null;
  } catch {
    return null;
  }
}

/** Sube la foto al servidor. Devuelve true si el servidor la guardo. */
export async function subirFotoPerfil(uri: string): Promise<boolean> {
  try {
    const enrollment = await loadNativeEnrollment();
    if (!enrollment) return false;
    const base64 = await reducirPerfil(uri);
    if (!base64) return false;
    const control = new AbortController();
    const corte = setTimeout(() => control.abort(), 30_000);
    try {
      const respuesta = await fetch(`${URL_API}/api/native/profile-photo`, {
        method: "POST",
        headers: { accept: "application/json", "content-type": "application/json", authorization: `Bearer ${enrollment.accessToken}` },
        body: JSON.stringify({ deviceId: enrollment.deviceId, photoBase64: base64 }),
        signal: control.signal,
      });
      return respuesta.ok;
    } finally {
      clearTimeout(corte);
    }
  } catch {
    return false;
  }
}

/** La foto (ruta en el telefono) que ya se subio, o null. */
export async function fotoSubida(): Promise<string | null> {
  try {
    return await AsyncStorage.getItem(CLAVE_SUBIDA);
  } catch {
    return null;
  }
}

export async function marcarFotoSubida(uri: string): Promise<void> {
  try {
    await AsyncStorage.setItem(CLAVE_SUBIDA, uri);
  } catch {
    // Si no se pudo anotar, la tarjeta de Perfil vuelve a ofrecer compartirla: no pasa nada.
  }
}
