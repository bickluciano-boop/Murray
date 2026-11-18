import { AppState } from "react-native";

/**
 * Limpia de la pantalla de notificaciones los avisos de Ojo Guard que ya cumplieron su función, para que no se acumule una pila (Luciano, 18/11/2026:
 * "es medio tedioso tantas notificaciones": había 21 apiladas y el aviso nuevo de medicamentos quedaba enterrado entre los de días anteriores).
 * Cada vez que se abre la app (y al arrancar) se sacan los avisos de medicamentos, del "Buen día" y el aviso neutro de la cuenta regresiva del SOS: abrir la app es verlos.
 * NO se toca nada más: ni el SOS de alguien de la familia, ni las alarmas, ni los demás avisos.
 */
const TIPOS_QUE_SE_LIMPIAN = new Set(["remedio", "buen-dia", "aviso-discreto"]);

/** Saca los avisos ya vistos. Devuelve cuántos sacó. Nunca falla: si algo sale mal, no hace nada. */
export async function limpiarAvisosViejos(): Promise<number> {
  try {
    const modulo = await import("expo-notifications");
    const presentes = await modulo.getPresentedNotificationsAsync();
    let sacadas = 0;
    for (const aviso of presentes) {
      const datos = aviso.request.content.data as Record<string, unknown> | null | undefined;
      const tipo = typeof datos?.type === "string" ? datos.type : "";
      if (!TIPOS_QUE_SE_LIMPIAN.has(tipo)) continue;
      await modulo.dismissNotificationAsync(aviso.request.identifier).catch(() => undefined);
      sacadas += 1;
    }
    return sacadas;
  } catch {
    return 0;
  }
}

/** Limpia al arrancar y cada vez que la app vuelve a verse. Devuelve la función que deja de escuchar. */
export function iniciarLimpiezaDeAvisos() {
  void limpiarAvisosViejos();
  const suscripcion = AppState.addEventListener("change", (estadoApp) => {
    if (estadoApp === "active") void limpiarAvisosViejos();
  });
  return () => suscripcion.remove();
}
