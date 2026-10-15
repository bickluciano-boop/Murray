import { createContext, useContext } from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";

/**
 * Configuración en cinco tarjetas grandes en vez de una tira larga de bloques. Cada bloque de siempre sigue existiendo, con sus
 * mismos botones y textos: solo cambió DÓNDE se abre. Tocar una tarjeta muestra únicamente los bloques de ese grupo, con un
 * "‹ Configuración" para volver.
 *
 *  - "todo": primer arranque ("Preparar este teléfono"). Se ve todo junto, como siempre, para no cambiar los pasos de la instalación.
 *  - null: la pantalla de tarjetas. Se ven las tarjetas y los bloques que no pertenecen a ningún grupo (Familia y amigos, Ojo Guard MS).
 *  - un grupo: se ven solo los bloques marcados con ese grupo.
 */

type Paleta = { [clave: string]: string };

export type GrupoConfiguracion = "claves" | "fotos" | "perdido" | "telefono" | "permisos";
export type GrupoActualValor = GrupoConfiguracion | "todo" | null;

export const GrupoActual = createContext<GrupoActualValor>("todo");

/** ¿Se muestra un bloque marcado con `grupo` (o sin marca) cuando está abierto `actual`? */
export function seVe(actual: GrupoActualValor, grupo?: GrupoConfiguracion) {
  if (actual === "todo") return true;
  if (actual === null) return grupo === undefined;
  return grupo === actual;
}

/** Lo mismo para un bloque que no es una sección plegable (por ejemplo la tarjeta del estado del teléfono). */
export function enGrupo(actual: GrupoActualValor, grupo: GrupoConfiguracion) {
  return actual === "todo" || actual === grupo;
}

export function useSeVe(grupo?: GrupoConfiguracion) {
  return seVe(useContext(GrupoActual), grupo);
}

const TEXTOS_GRUPO: Record<GrupoConfiguracion, { titulo: string; resumen: string }> = {
  claves: { titulo: "Claves y Seguridad", resumen: "Tus claves, la detección de intentos de desbloqueo y lo que se guarda como evidencia." },
  fotos: { titulo: "Fotos de Intrusos", resumen: "Los intentos de entrada que registró este teléfono y lo que falta enviar." },
  perdido: { titulo: "Modo Perdido y Cercanía", resumen: "Qué ve quien encuentre el teléfono, la cercanía y tus accesorios." },
  telefono: { titulo: "Mi Teléfono y Fondo", resumen: "El nombre de este teléfono, cómo se ve y cómo está." },
  permisos: { titulo: "Permisos de Android", resumen: "Los ajustes de Android que, si no se tocan, frenan Ojo Guard en silencio." },
};

/** Los textos de cada grupo. "Permisos" cambia de nombre en iPhone, donde los ajustes son otros. */
export function textosDe(grupo: GrupoConfiguracion, android: boolean) {
  if (grupo === "permisos" && !android) {
    return { titulo: "Permisos del iPhone", resumen: "Los ajustes del iPhone que ayudan a que Ojo Guard avise a tiempo." };
  }
  return TEXTOS_GRUPO[grupo];
}

type TarjetasProps = {
  paleta: Paleta;
  android: boolean;
  /** Cuántos de los cuatro permisos de Android están en orden; null si todavía no se pudo leer. */
  permisosEnOrden: number | null;
  permisosTotal: number;
  intentos: number;
  pendientes: number;
  cercania: boolean;
  radioMetros: number;
  onElegir: (grupo: GrupoConfiguracion) => void;
};

export function TarjetasConfiguracion({ paleta: P, android, permisosEnOrden, permisosTotal, intentos, pendientes, cercania, radioMetros, onElegir }: TarjetasProps) {
  const s = estilos(P);
  const fotos =
    (intentos > 0 ? `${intentos} registrado${intentos === 1 ? "" : "s"}` : "Ninguno") + (pendientes > 0 ? ` · ${pendientes} por enviar` : "");
  const completos = permisosEnOrden !== null && permisosEnOrden >= permisosTotal;
  const filas: Array<{ grupo: GrupoConfiguracion; detalle: string }> = [
    { grupo: "claves", detalle: "Claves, intentos de desbloqueo, evidencia" },
    { grupo: "fotos", detalle: fotos },
    { grupo: "perdido", detalle: `Mensaje para quien lo encuentre · ${cercania ? `cercanía activa (${radioMetros} m)` : "cercanía apagada"}` },
    { grupo: "telefono", detalle: "Nombre, fondo de pantalla, estado" },
  ];
  filas.push({ grupo: "permisos", detalle: android ? "Batería, avisos de pantalla completa, bloqueo" : "Protección contra robo y permisos de la app" });

  return (
    <View style={s.lista}>
      {filas.map(({ grupo, detalle }) => {
        const esPermisos = android && grupo === "permisos" && permisosEnOrden !== null;
        const titulo = textosDe(grupo, android).titulo;
        return (
          <Pressable
            key={grupo}
            accessibilityRole="button"
            accessibilityLabel={`${titulo}. ${detalle}`}
            onPress={() => onElegir(grupo)}
            style={[s.tarjeta, esPermisos && { borderColor: completos ? P.exitoBorde : P.doradoBorde }]}
          >
            <View style={s.texto}>
              <Text style={s.titulo}>{titulo}</Text>
              <Text style={s.detalle}>{detalle}</Text>
            </View>
            {esPermisos ? (
              <View style={[s.estado, { backgroundColor: completos ? P.exitoFondo : P.doradoFondo, borderColor: completos ? P.exitoBorde : P.doradoBorde }]}>
                <Text style={[s.estadoTexto, { color: completos ? P.exito : P.doradoTexto }]}>
                  {completos ? "✓" : "!"} {permisosEnOrden} de {permisosTotal}
                </Text>
              </View>
            ) : null}
            <Text style={s.flecha}>›</Text>
          </Pressable>
        );
      })}
    </View>
  );
}

type CabeceraProps = { paleta: Paleta; android: boolean; grupo: GrupoConfiguracion; onVolver: () => void };

export function CabeceraGrupo({ paleta: P, android, grupo, onVolver }: CabeceraProps) {
  const s = estilos(P);
  const textos = textosDe(grupo, android);
  return (
    <View style={s.cabecera}>
      <Pressable accessibilityRole="button" accessibilityLabel="Volver a Configuración" hitSlop={10} onPress={onVolver} style={s.volver}>
        <Text style={s.volverTexto}>‹ Configuración</Text>
      </Pressable>
      <Text style={s.cabeceraTitulo}>{textos.titulo}</Text>
      <Text style={s.cabeceraResumen}>{textos.resumen}</Text>
    </View>
  );
}

function estilos(P: Paleta) {
  return StyleSheet.create({
    lista: { marginTop: 18, marginBottom: 6 },
    tarjeta: {
      alignItems: "center",
      backgroundColor: P.superficie,
      borderColor: P.borde,
      borderRadius: 16,
      borderWidth: 1,
      flexDirection: "row",
      gap: 10,
      marginBottom: 12,
      minHeight: 76,
      paddingHorizontal: 18,
      paddingVertical: 16,
    },
    texto: { flex: 1 },
    titulo: { color: P.texto, fontSize: 18, fontWeight: "700" },
    detalle: { color: P.textoTenue, fontSize: 13, lineHeight: 18, marginTop: 4 },
    estado: { borderRadius: 12, borderWidth: 1, paddingHorizontal: 10, paddingVertical: 5 },
    estadoTexto: { fontSize: 13, fontWeight: "800" },
    flecha: { color: P.doradoTexto, fontSize: 28, fontWeight: "300", lineHeight: 30 },
    cabecera: { marginBottom: 18, marginTop: 38 },
    volver: { alignSelf: "flex-start", paddingVertical: 8 },
    volverTexto: { color: P.doradoTexto, fontSize: 16, fontWeight: "700" },
    cabeceraTitulo: { color: P.texto, fontSize: 28, fontWeight: "700", marginTop: 10 },
    cabeceraResumen: { color: P.textoTenue, fontSize: 14, lineHeight: 20, marginTop: 6 },
  });
}
