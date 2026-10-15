import * as Battery from "expo-battery";
import { createContext, useContext, useEffect, useState } from "react";
import { Image, Pressable, StyleSheet, Text, View, type ImageSourcePropType } from "react-native";

/**
 * La pantalla a la que se entra con la clave de administrador, en tres niveles:
 *
 *  - Inicio (null): lo de todos los días. La tarjeta de este teléfono con la tuerca de Configuración, y abajo Familia y SOS.
 *  - Configuración ("configuracion"): seis tarjetas grandes y la banda de permisos. Cada tarjeta abre un grupo.
 *  - Un grupo: solo los bloques de ese grupo, con "‹ Atrás" para volver a las tarjetas.
 *
 * Los bloques de siempre (con sus mismos botones y textos) se marcan con el grupo al que pertenecen. "todo" es el primer arranque
 * ("Preparar este teléfono"): se ve todo junto, como siempre, para no cambiar los pasos de la instalación.
 */

type Paleta = { [clave: string]: string };

export type GrupoConfiguracion = "claves" | "fotos" | "perdido" | "telefono" | "proteccion" | "conexion" | "permisos";
export type GrupoActualValor = GrupoConfiguracion | "configuracion" | "todo" | null;

export const GrupoActual = createContext<GrupoActualValor>("todo");

/** ¿Se muestra un bloque marcado con `grupo` (o sin marca) cuando está abierto `actual`? */
export function seVe(actual: GrupoActualValor, grupo?: GrupoConfiguracion) {
  if (actual === "todo") return true;
  if (actual === "configuracion") return false;
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
  proteccion: { titulo: "Dr. Ojo Guard", resumen: "Revisa que el SOS, los avisos y la ubicación estén listos en este teléfono." },
  conexion: { titulo: "Ojo Guard MS", resumen: "Cómo se conecta este teléfono con el panel de Ojo Guard MS." },
  permisos: { titulo: "Permisos de Android", resumen: "Los ajustes de Android que, si no se tocan, frenan Ojo Guard en silencio." },
};

/** Los textos de cada grupo. "Permisos" cambia de nombre en iPhone, donde los ajustes son otros. */
export function textosDe(grupo: GrupoConfiguracion, android: boolean) {
  if (grupo === "permisos" && !android) {
    return { titulo: "Permisos del iPhone", resumen: "Los ajustes del iPhone que ayudan a que Ojo Guard avise a tiempo." };
  }
  return TEXTOS_GRUPO[grupo];
}

const ICONOS: Record<Exclude<GrupoConfiguracion, "permisos">, ImageSourcePropType> = {
  claves: require("../assets/config-llave.png"),
  fotos: require("../assets/config-camara.png"),
  perdido: require("../assets/config-radar.png"),
  telefono: require("../assets/config-telefono.png"),
  proteccion: require("../assets/config-chequeo.png"),
  conexion: require("../assets/config-conexion.png"),
};
const ICONO_TUERCA: ImageSourcePropType = require("../assets/config-tuerca.png");

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

type TelefonoProps = {
  paleta: Paleta;
  /** Nombre que se le puso a este teléfono. */
  nombre: string;
  /** Correo privado de alertas (puede estar vacío). */
  correo: string;
  /** true: hay internet; false: no hay; null: todavía comprobando. */
  enLinea: boolean | null;
  onConfiguracion: () => void;
};

/** Arriba del Inicio: cómo se llama este teléfono, si está en línea, la batería y la tuerca que abre Configuración. */
export function TarjetaTelefono({ paleta: P, nombre, correo, enLinea, onConfiguracion }: TelefonoProps) {
  const s = estilos(P);
  const bateria = useBateria();
  const estado = enLinea === null ? "Comprobando" : enLinea ? "En línea" : "Sin internet";
  const colorEstado = enLinea === false ? P.doradoTexto : P.exito;
  return (
    <View style={s.telefono}>
      <View style={s.telefonoTextos}>
        <Text adjustsFontSizeToFit minimumFontScale={0.7} numberOfLines={1} style={s.telefonoNombre}>
          {nombre.trim() || "Mi teléfono"}
        </Text>
        <View style={[s.estado, { borderColor: colorEstado }]}>
          <View style={[s.punto, { backgroundColor: colorEstado }]} />
          <Text style={[s.estadoTexto, { color: colorEstado }]}>
            {estado}
            {bateria !== null ? ` · batería ${bateria}%` : ""}
          </Text>
        </View>
        {correo.trim() ? <Text style={s.correo}>{correo.trim()}</Text> : null}
      </View>
      <Pressable accessibilityRole="button" accessibilityLabel="Configuración" hitSlop={8} onPress={onConfiguracion} style={s.tuerca}>
        <Image source={ICONO_TUERCA} style={s.tuercaIcono} resizeMode="contain" />
        <Text style={s.tuercaTexto}>Configuración</Text>
      </Pressable>
    </View>
  );
}

type BandaProps = {
  paleta: Paleta;
  android: boolean;
  /** Cuántos de los cuatro permisos de Android están en orden; null si todavía no se pudo leer. */
  permisosEnOrden: number | null;
  permisosTotal: number;
  /** En el Inicio la banda solo aparece si falta algo; en Configuración está siempre. */
  soloSiFalta?: boolean;
  onPress: () => void;
};

export function BandaPermisos({ paleta: P, android, permisosEnOrden, permisosTotal, soloSiFalta = false, onPress }: BandaProps) {
  const s = estilos(P);
  const completos = permisosEnOrden !== null && permisosEnOrden >= permisosTotal;
  if (soloSiFalta && (!android || permisosEnOrden === null || completos)) return null;
  const texto = !android
    ? "Permisos del iPhone ›"
    : permisosEnOrden === null
      ? "Permisos de Android: revisar ›"
      : completos
        ? `Permisos de Android: ${permisosEnOrden}/${permisosTotal} OK ✓`
        : `Permisos de Android: ${permisosEnOrden}/${permisosTotal} · arreglar ›`;
  const colores =
    !android || permisosEnOrden === null
      ? { fondo: P.superficieHonda, borde: P.borde, texto: P.textoSuave }
      : completos
        ? { fondo: P.exitoFondo, borde: P.exitoBorde, texto: P.exito }
        : { fondo: P.doradoFondo, borde: P.doradoBorde, texto: P.doradoTexto };
  return (
    <Pressable accessibilityRole="button" accessibilityLabel={texto} onPress={onPress} style={[s.banda, { backgroundColor: colores.fondo, borderColor: colores.borde }]}>
      <Text adjustsFontSizeToFit minimumFontScale={0.75} numberOfLines={1} style={[s.bandaTexto, { color: colores.texto }]}>
        {texto}
      </Text>
    </Pressable>
  );
}

type TarjetasProps = {
  paleta: Paleta;
  android: boolean;
  intentos: number;
  pendientes: number;
  cercania: boolean;
  radioMetros: number;
  /** Estado de la vinculación con Ojo Guard MS: "not-linked", "syncing", "executed", "offline" o conectado. */
  conexion: string;
  onElegir: (grupo: GrupoConfiguracion) => void;
};

/** Configuración: seis tarjetas grandes con ícono, de a dos por fila. Cada una abre los bloques de siempre de su grupo. */
export function TarjetasConfiguracion({ paleta: P, android, intentos, pendientes, cercania, radioMetros, conexion, onElegir }: TarjetasProps) {
  const s = estilos(P);
  const tarjetas: Array<{ grupo: Exclude<GrupoConfiguracion, "permisos">; detalle: string }> = [
    { grupo: "claves", detalle: "PIN de admin, señuelo y evidencia" },
    {
      grupo: "fotos",
      detalle:
        (intentos > 0 ? `${intentos} intento${intentos === 1 ? "" : "s"} registrado${intentos === 1 ? "" : "s"}` : "Ningún intento registrado") +
        (pendientes > 0 ? ` · ${pendientes} por enviar` : ""),
    },
    { grupo: "perdido", detalle: `Mensaje de rescate y ${cercania ? `radio ${radioMetros} m` : "cercanía apagada"}` },
    { grupo: "telefono", detalle: "Nombre, fondo y modo noche" },
    { grupo: "proteccion", detalle: "Chequeo del teléfono y prueba de sirena" },
    {
      grupo: "conexion",
      detalle: conexion === "not-linked" ? "Sin vincular" : conexion === "syncing" ? "Buscando…" : conexion === "executed" ? "Orden ejecutada" : conexion === "offline" ? "Sin conexión" : "Conectado",
    },
  ];
  const filas: Array<typeof tarjetas> = [];
  for (let i = 0; i < tarjetas.length; i += 2) filas.push(tarjetas.slice(i, i + 2));
  void android;

  return (
    <View style={s.grilla}>
      {filas.map((fila, indice) => (
        <View key={indice} style={s.fila}>
          {fila.map(({ grupo, detalle }) => {
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
      ))}
    </View>
  );
}

type CabeceraPantallaProps = { paleta: Paleta; titulo: string; resumen?: string; onVolver: () => void };

/** "‹ Atrás" bien separado de la ✕ (que solo está en el Inicio), el título y, si hace falta, una línea chica. */
export function CabeceraPantalla({ paleta: P, titulo, resumen, onVolver }: CabeceraPantallaProps) {
  const s = estilos(P);
  return (
    <View style={s.cabecera}>
      <Pressable accessibilityRole="button" accessibilityLabel="Atrás" hitSlop={10} onPress={onVolver} style={s.volver}>
        <Text style={s.volverTexto}>‹ Atrás</Text>
      </Pressable>
      <Text style={s.cabeceraTitulo}>{titulo}</Text>
      {resumen ? <Text style={s.cabeceraResumen}>{resumen}</Text> : null}
    </View>
  );
}

type CabeceraProps = { paleta: Paleta; android: boolean; grupo: GrupoConfiguracion; onVolver: () => void };

export function CabeceraGrupo({ paleta, android, grupo, onVolver }: CabeceraProps) {
  const textos = textosDe(grupo, android);
  return <CabeceraPantalla paleta={paleta} titulo={textos.titulo} resumen={textos.resumen} onVolver={onVolver} />;
}

function estilos(P: Paleta) {
  return StyleSheet.create({
    telefono: { alignItems: "center", backgroundColor: P.superficieHonda, borderColor: P.borde, borderRadius: 22, borderWidth: 1, flexDirection: "row", gap: 10, marginBottom: 12, marginTop: 14, padding: 16 },
    telefonoTextos: { flex: 1 },
    telefonoNombre: { color: P.texto, fontSize: 22, fontWeight: "800" },
    estado: { alignItems: "center", alignSelf: "flex-start", borderRadius: 16, borderWidth: 1.5, flexDirection: "row", gap: 8, marginTop: 8, paddingHorizontal: 12, paddingVertical: 5 },
    punto: { borderRadius: 5, height: 10, width: 10 },
    estadoTexto: { fontSize: 13, fontWeight: "700" },
    correo: { color: P.textoTenue, fontSize: 13, marginTop: 8 },
    tuerca: { alignItems: "center", justifyContent: "center", minWidth: 74, paddingVertical: 4 },
    tuercaIcono: { height: 40, width: 40 },
    tuercaTexto: { color: P.textoTenue, fontSize: 11, fontWeight: "600", marginTop: 2 },
    banda: { alignItems: "center", borderRadius: 16, borderWidth: 1, justifyContent: "center", marginBottom: 12, marginTop: 4, minHeight: 50, paddingHorizontal: 14, paddingVertical: 12 },
    bandaTexto: { fontSize: 15, fontWeight: "700", textAlign: "center" },
    grilla: { gap: 12, marginBottom: 12, marginTop: 4 },
    fila: { flexDirection: "row", gap: 12 },
    celda: { alignItems: "center", backgroundColor: P.superficieHonda, borderColor: P.borde, borderRadius: 22, borderWidth: 1, flex: 1, minHeight: 150, paddingHorizontal: 10, paddingVertical: 16 },
    icono: { height: 46, width: 46 },
    celdaTitulo: { color: P.texto, fontSize: 16, fontWeight: "800", marginTop: 10, textAlign: "center" },
    celdaDetalle: { color: P.textoTenue, fontSize: 12, lineHeight: 16, marginTop: 5, textAlign: "center" },
    cabecera: { marginBottom: 16, marginTop: 8 },
    volver: { alignSelf: "flex-start", backgroundColor: P.superficieHonda, borderColor: P.borde, borderRadius: 18, borderWidth: 1, paddingHorizontal: 16, paddingVertical: 8 },
    volverTexto: { color: P.doradoTexto, fontSize: 16, fontWeight: "800" },
    cabeceraTitulo: { color: P.texto, fontSize: 26, fontWeight: "700", marginTop: 14 },
    cabeceraResumen: { color: P.textoTenue, fontSize: 12.5, lineHeight: 18, marginTop: 4 },
  });
}
