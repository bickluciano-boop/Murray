import { Share } from "react-native";

/**
 * "Compartir registro con soporte" (Ajustes → Configuración → Registros técnicos). Arma UN texto con todo lo que la app anotó en segundo plano
 * y abre el menú de compartir de Android/iPhone (Gmail, WhatsApp, Drive, Notas…) para mandárselo a soporte. No manda nada solo ni sale de la
 * app sin que la persona elija adónde: es la persona la que lo envía. No incluye contraseñas, PIN ni claves (la app no las anota ahí).
 */

export type DatosRegistro = {
  version: string;
  sistema: string;
  aviso: string;
  historial: string[];
  camaraNativa: string[];
  pasos: string[];
};

function seccion(titulo: string, lineas: string[], vacio: string): string {
  return `== ${titulo} ==\n${lineas.length ? lineas.join("\n") : vacio}`;
}

export function armarRegistro(d: DatosRegistro, ahora: Date = new Date()): string {
  return [
    "Registro técnico de Ojo Guard",
    `Versión: ${d.version}`,
    `Sistema: ${d.sistema}`,
    `Generado: ${ahora.toISOString()}`,
    "",
    ...(d.aviso ? ["== Aviso de pantalla completa ==", d.aviso, ""] : []),
    seccion("Historial de segundo plano (más reciente primero)", d.historial, "(sin registros)"),
    "",
    seccion("Cámara nativa (más reciente primero)", d.camaraNativa, "(sin registros)"),
    "",
    seccion("Pasos de las últimas capturas de evidencia (más reciente primero)", d.pasos, "(sin registros)"),
    "",
  ].join("\n");
}

/** Abre el menú de compartir con el registro. Devuelve false si no se pudo abrir (nunca revienta la pantalla). */
export async function compartirRegistroSoporte(d: DatosRegistro): Promise<boolean> {
  try {
    await Share.share({ title: "Registro técnico de Ojo Guard", message: armarRegistro(d) });
    return true;
  } catch {
    return false;
  }
}
