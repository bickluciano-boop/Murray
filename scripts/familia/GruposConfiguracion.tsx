import * as Battery from "expo-battery";
import { createContext, useContext, useEffect, useState } from "react";
import { Image, Pressable, StyleSheet, Text, View, type ImageSourcePropType } from "react-native";

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
  /** Nombre que se le puso a este teléfono. */
  nombre: string;
  /** Correo privado de alertas (puede estar vacío). */
  correo: string;
  /** true: hay internet; false: no hay; null: todavía comprobando. */
  enLinea: boolean | null;
  /** Cuántos de los cuatro permisos de Android están en orden; null si todavía no se pudo leer. */
  permisosEnOrden: number | null;
  permisosTotal: number;
  intentos: number;
  pendientes: number;
  cercania: boolean;
  radioMetros: number;
  onElegir: (grupo: GrupoConfiguracion) => void;
};

const ICONOS: Record<Exclude<GrupoConfiguracion, "permisos">, ImageSourcePropType> = {
  claves: require("../assets/config-llave.png"),
  fotos: require("../assets/config-camara.png"),
  perdido: require("../assets/config-radar.png"),
  telefono: require("../assets/config-telefono.png"),
};

function useBateria() {
  const [porcentaje, setPorcentaje] = useState<number | null>(null);
  useEffect(() => {
    let activo = true;
    const leer = async () => {
      const valor = await Battery.getBatteryLevelAsync().catch(() => -1);
      if (activo && valor >= 0) setPorcentaje(Math.round(valor * 100));
    };
    void leer();
    const intervalo = setInterval(() => void leer(), 60_000);
    return () => {
      activo = false;
      clearInterval(intervalo);
    };
  }, []);
  return porcentaje;
}

/**
 * Portada de Configuración: la tarjeta de este teléfono (nombre, si está en línea y la batería, correo), la banda de permisos
 * (toca para ver o arreglar los de Android) y cuatro tarjetas grandes con ícono. Cada una abre los bloques de siempre de su grupo.
 */
export function TarjetasConfiguracion({ paleta: P, android, nombre, correo, enLinea, permisosEnOrden, permisosTotal, intentos, pendientes, cercania, radioMetros, onElegir }: TarjetasProps) {
  const s = estilos(P);
  const bateria = useBateria();
  const estado = enLinea === null ? "Comprobando" : enLinea ? "En línea" : "Sin internet";
  const colorEstado = enLinea === false ? P.doradoTexto : P.exito;
  const completos = permisosEnOrden !== null && permisosEnOrden >= permisosTotal;
  const textoPermisos = !android
    ? "Permisos del iPhone ›"
    : permisosEnOrden === null
      ? "Permisos de Android: revisar ›"
      : completos
        ? `Permisos de Android: ${permisosEnOrden}/${permisosTotal} OK ✓`
        : `Permisos de Android: ${permisosEnOrden}/${permisosTotal} · arreglar ›`;
  const colores = !android || permisosEnOrden === null
    ? { fondo: P.superficieHonda, borde: P.borde, texto: P.textoSuave }
    : completos
      ? { fondo: P.exitoFondo, borde: P.exitoBorde, texto: P.exito }
      : { fondo: P.doradoFondo, borde: P.doradoBorde, texto: P.doradoTexto };

  const tarjetas: Array<{ grupo: Exclude<GrupoConfiguracion, "permisos">; detalle: string }> = [
    { grupo: "claves", detalle: "Claves, señuelo y evidencia" },
    { grupo: "fotos", detalle: (intentos > 0 ? `${intentos} intento${intentos === 1 ? "" : "s"} registrado${intentos === 1 ? "" : "s"}` : "Ningún intento registrado") + (pendientes > 0 ? ` · ${pendientes} por enviar` : "") },
    { grupo: "perdido", detalle: `Mensaje de rescate y ${cercania ? `radio ${radioMetros} m` : "cercanía apagada"}` },
    { grupo: "telefono", detalle: "Nombre, fondo y modo noche" },
  ];

  return (
    <View style={s.portada}>
      <View style={s.telefono}>
        <Text style={s.telefonoNombre}>{nombre.trim() || "Mi teléfono"}</Text>
        <View style={[s.estado, { borderColor: colorEstado }]}>
          <View style={[s.punto, { backgroundColor: colorEstado }]} />
          <Text style={[s.estadoTexto, { color: colorEstado }]}>{estado}{bateria !== null ? ` · ${bateria}%` : ""}</Text>
        </View>
        {correo.trim() ? <Text style={s.correo}>{correo.trim()}</Text> : null}
      </View>

      <Pressable
        accessibilityRole="button"
        accessibilityLabel={textoPermisos}
        onPress={() => onElegir("permisos")}
        style={[s.banda, { backgroundColor: colores.fondo, borderColor: colores.borde }]}
      >
        <Text style={[s.bandaTexto, { color: colores.texto }]}>{textoPermisos}</Text>
      </Pressable>

      <View style={s.grilla}>
        {tarjetas.map(({ grupo, detalle }) => {
          const titulo = textosDe(grupo, android).titulo;
          return (
            <Pressable key={grupo} accessibilityRole="button" accessibilityLabel={`${titulo}. ${detalle}`} onPress={() => onElegir(grupo)} style={s.celda}>
              <Image source={ICONOS[grupo]} style={s.icono} resizeMode="contain" />
              <Text style={s.celdaTitulo}>{titulo}</Text>
              <Text style={s.celdaDetalle}>{detalle}</Text>
            </Pressable>
          );
        })}
      </View>
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
    portada: { marginTop: 14, marginBottom: 6 },
    telefono: { alignItems: "center", backgroundColor: P.superficieHonda, borderColor: P.borde, borderRadius: 22, borderWidth: 1, paddingHorizontal: 18, paddingVertical: 20 },
    telefonoNombre: { color: P.texto, fontSize: 24, fontWeight: "800", textAlign: "center" },
    estado: { alignItems: "center", borderRadius: 16, borderWidth: 1.5, flexDirection: "row", gap: 8, marginTop: 10, paddingHorizontal: 14, paddingVertical: 6 },
    punto: { borderRadius: 5, height: 10, width: 10 },
    estadoTexto: { fontSize: 14, fontWeight: "700" },
    correo: { color: P.textoTenue, fontSize: 14, marginTop: 10, textAlign: "center" },
    banda: { alignItems: "center", borderRadius: 16, borderWidth: 1, marginTop: 12, minHeight: 52, justifyContent: "center", paddingHorizontal: 14, paddingVertical: 12 },
    bandaTexto: { fontSize: 15, fontWeight: "700", textAlign: "center" },
    grilla: { flexDirection: "row", flexWrap: "wrap", gap: 12, justifyContent: "space-between", marginBottom: 12, marginTop: 12 },
    celda: { alignItems: "center", backgroundColor: P.superficieHonda, borderColor: P.borde, borderRadius: 22, borderWidth: 1, minHeight: 176, paddingHorizontal: 10, paddingVertical: 18, width: "48%" },
    icono: { height: 52, width: 52 },
    celdaTitulo: { color: P.texto, fontSize: 17, fontWeight: "800", marginTop: 12, textAlign: "center" },
    celdaDetalle: { color: P.textoTenue, fontSize: 12.5, lineHeight: 17, marginTop: 6, textAlign: "center" },
    cabecera: { marginBottom: 18, marginTop: 38 },
    volver: { alignSelf: "flex-start", paddingVertical: 8 },
    volverTexto: { color: P.doradoTexto, fontSize: 16, fontWeight: "700" },
    cabeceraTitulo: { color: P.texto, fontSize: 28, fontWeight: "700", marginTop: 10 },
    cabeceraResumen: { color: P.textoTenue, fontSize: 14, lineHeight: 20, marginTop: 6 },
  });
}
