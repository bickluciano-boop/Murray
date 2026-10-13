import { Platform } from "react-native";

type SosTriggerNativeModule = {
  isEnabled(): boolean;
  isRunning?: () => boolean;
  openAccessibilitySettings(): string;
  openAppInfo(): string;
  openSosChannelSettings(): string;
};

function loadNativeModule(): SosTriggerNativeModule | null {
  if (Platform.OS !== "android") return null;
  try {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const { requireNativeModule } = require("expo-modules-core");
    return requireNativeModule("SosTrigger") as SosTriggerNativeModule;
  } catch {
    return null;
  }
}

let cached: SosTriggerNativeModule | null | undefined;
function nativeModule(): SosTriggerNativeModule | null {
  if (cached === undefined) cached = loadNativeModule();
  return cached;
}

/** ¿Esta build trae el gesto de volumen? (Android con el módulo nativo). */
export function sosGestureAvailable(): boolean {
  return nativeModule() !== null;
}

/** ¿Ya está activado "Ojo Guard SOS" en Ajustes > Accesibilidad? */
export function isSosGestureEnabled(): boolean {
  try {
    return Boolean(nativeModule()?.isEnabled());
  } catch {
    return false;
  }
}

/**
 * ¿El servicio está de verdad conectado y recibiendo los botones? Android puede dejar el interruptor "prendido" con el
 * servicio caído. Devuelve `null` si no se puede saber (build vieja sin esta función): no es lo mismo que "caído".
 */
export function isSosGestureRunning(): boolean | null {
  const modulo = nativeModule();
  if (!modulo || typeof modulo.isRunning !== "function") return null;
  try {
    return Boolean(modulo.isRunning());
  } catch {
    return null;
  }
}

/** Abre Ajustes > Accesibilidad para que el dueño active "Ojo Guard SOS". Devuelve "ok" o "error:...". */
export function openSosAccessibilitySettings(): string {
  try {
    return nativeModule()?.openAccessibilitySettings() ?? "sin_modulo";
  } catch (error) {
    return `error:${String(error)}`;
  }
}

/** Abre la pantalla del canal "SOS de la familia" (sirena y "Anular No interrumpir"). */
export function openSosChannelSettings(): string {
  try {
    return nativeModule()?.openSosChannelSettings() ?? "sin_modulo";
  } catch (error) {
    return `error:${String(error)}`;
  }
}

/** Abre la información de la app (para "Permitir configuración restringida" en Android 13+). */
export function openSosAppInfo(): string {
  try {
    return nativeModule()?.openAppInfo() ?? "sin_modulo";
  } catch (error) {
    return `error:${String(error)}`;
  }
}
