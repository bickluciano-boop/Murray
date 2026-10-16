import * as Battery from "expo-battery";
import { initialWindowMetrics } from "react-native-safe-area-context";
import { createContext, useContext, useEffect, useState, type ReactNode } from "react";
import { Image, Keyboard, Platform, Pressable, StatusBar, StyleSheet, Text, View, type ImageSourcePropType } from "react-native";

/**
 * La pantalla a la que se entra con la clave de administrador, en tres niveles:
 *
 *  - La barra de abajo (BarraInferior) queda fija en todas las pantallas: SOS (cuadradito rojo, se mantiene apretado 3 segundos), Inicio, Perfil,
 *    Ajustes (Configuración) y Abrir el panel Ojo Guard MS. Marca en cuál se está.
 *  - Inicio (null): lo de todos los días. Una línea con este teléfono y el mapa con todos los equipos y la familia (ver InicioMapa.tsx).
 *  - Familia y amigos ("familia"): un grupo de Ajustes con lo que no está en el mapa: unirse con un código, pausar la propia ubicación, el
 *    SOS y sus ayudas, y salir de una familia. Las personas se ven y se suman desde el mapa del Inicio.
 *  - Mi perfil ("perfil"): los datos de quien usa el teléfono (nombre, correo, cómo se ve, cómo está).
 *  - Configuración ("configuracion"): seis tarjetas grandes y la banda de permisos. Cada tarjeta abre un grupo.
 *  - Un grupo: solo los bloques de ese grupo, con "‹ Atrás" para volver (a las tarjetas o al Inicio).
 *
 * Los bloques de siempre (con sus mismos botones y textos) se marcan con el grupo al que pertenecen. "todo" es el primer arranque
 * ("Preparar este teléfono"): se ve todo junto, como siempre, para no cambiar los pasos de la instalación.
 */

type Paleta = { [clave: string]: string };

export type GrupoConfiguracion = "claves" | "fotos" | "perdido" | "preferencias" | "proteccion" | "conexion" | "permisos" | "perfil" | "familia";
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
  fotos: { titulo: "Fotos de Intrusos", resumen: "Los intentos de entrada que registró este teléfono." },
  perdido: { titulo: "Modo Perdido y Cercanía", resumen: "Qué ve quien encuentre el teléfono, la cercanía y tus accesorios." },
  preferencias: { titulo: "Preferencias", resumen: "Modo preventivo, pantalla OLED y lo que falta enviar." },
  perfil: { titulo: "Mi perfil", resumen: "Los datos de este teléfono y cómo se ve la app." },
  familia: { titulo: "Familia y amigos", resumen: "Unirte con un código, pausar tu ubicación, el SOS y cómo pedir ayuda sin abrir la app. Las personas se ven y se suman desde el mapa del Inicio." },
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

const ICONOS: Record<Exclude<GrupoConfiguracion, "permisos" | "perfil">, ImageSourcePropType> = {
  familia: require("../assets/config-familia.png"),
  claves: require("../assets/config-llave.png"),
  fotos: require("../assets/config-camara.png"),
  perdido: require("../assets/config-radar.png"),
  preferencias: require("../assets/config-ajustes.png"),
  proteccion: require("../assets/config-chequeo.png"),
  conexion: require("../assets/config-conexion.png"),
};
const ICONO_TUERCA: ImageSourcePropType = require("../assets/config-tuerca.png");
const ICONO_INICIO: ImageSourcePropType = require("../assets/config-inicio.png");
const ICONO_PERFIL: ImageSourcePropType = require("../assets/config-perfil.png");

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
};

/** Arriba del Inicio: cómo se llama este teléfono, si está en línea, la batería y el correo. */
export function TarjetaTelefono({ paleta: P, nombre, correo, enLinea }: TelefonoProps) {
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
    </View>
  );
}

type CabezaProps = { paleta: Paleta; nombre: string; enLinea: boolean | null };

/** Inicio con mapa: el nombre del teléfono y cómo está (en línea y batería), chico y en el renglón de arriba, entre la ✕ y la ayuda (?). */
export function CabezaInicio({ paleta: P, nombre, enLinea }: CabezaProps) {
  const s = estilos(P);
  const bateria = useBateria();
  const estado = enLinea === null ? "Comprobando" : enLinea ? "En línea" : "Sin internet";
  const colorEstado = enLinea === false ? P.doradoTexto : P.exito;
  return (
    <View style={s.cabeza}>
      <Text adjustsFontSizeToFit minimumFontScale={0.7} numberOfLines={1} style={s.cabezaNombre}>
        {nombre.trim() || "Mi teléfono"}
      </Text>
      <View style={s.cabezaEstado}>
        <View style={[s.punto, { backgroundColor: colorEstado }]} />
        <Text style={[s.cabezaEstadoTexto, { color: colorEstado }]}>
          {estado}
          {bateria !== null ? ` · batería ${bateria}%` : ""}
        </Text>
      </View>
    </View>
  );
}

export type SeccionBarra = "inicio" | "perfil" | "configuracion";

type BarraProps = {
  paleta: Paleta;
  /** En cuál de las tres pantallas se está (todos los grupos de Configuración, también Familia y amigos, cuentan como "configuracion"). */
  actual: SeccionBarra;
  onElegir: (destino: SeccionBarra) => void;
  /** Abre el panel Ojo Guard MS entrando directo, sin pedir códigos. */
  onPanel: () => void;
  /** Mientras se pide el acceso y se abre el panel. */
  abriendo?: boolean;
  /** El cuadradito del SOS (ver SosBlock.tsx), que va primero en la barra. No aparece si este teléfono no está en una familia. */
  sos?: ReactNode;
};

/**
 * La barra de abajo, fija en todas las pantallas (como las pestañas de Ojo Guard MS): el SOS (cuadradito rojo), Inicio, Perfil, Ajustes y,
 * destacado, "Panel", que abre Ojo Guard MS entrando directo. Todo en una línea: se cambia de pantalla sin volver atrás, el SOS y el panel
 * están siempre a un toque, y el mapa se queda con casi toda la pantalla. Familia y amigos está dentro de Ajustes (las personas se ven en el mapa).
 */
/** Mientras se escribe, la barra de abajo se esconde para no quitarle lugar al teclado. */
function useTecladoVisible() {
  const [visible, setVisible] = useState(false);
  useEffect(() => {
    const mostrar = Keyboard.addListener(Platform.OS === "ios" ? "keyboardWillShow" : "keyboardDidShow", () => setVisible(true));
    const ocultar = Keyboard.addListener(Platform.OS === "ios" ? "keyboardWillHide" : "keyboardDidHide", () => setVisible(false));
    return () => {
      mostrar.remove();
      ocultar.remove();
    };
  }, []);
  return visible;
}

export function BarraInferior({ paleta: P, actual, onElegir, onPanel, abriendo = false, sos }: BarraProps) {
  const s = estilos(P);
  const tecladoVisible = useTecladoVisible();
  if (tecladoVisible) return null;
  // En Android la app llega hasta abajo de todo: los botones del sistema (atrás, inicio, recientes) o el gesto quedaban encima de la barra y se
  // comían los toques. Se deja debajo el lugar que mide el teléfono (48 si no se pudo medir). En iPhone ya lo cuida la pantalla segura.
  const lugarAbajo = Platform.OS === "android" ? Math.round(initialWindowMetrics?.insets.bottom ?? 48) : 0;
  const items: Array<{ clave: SeccionBarra; texto: string; icono: ImageSourcePropType }> = [
    { clave: "inicio", texto: "Inicio", icono: ICONO_INICIO },
    { clave: "perfil", texto: "Perfil", icono: ICONO_PERFIL },
    { clave: "configuracion", texto: "Ajustes", icono: ICONO_TUERCA },
  ];
  return (
    <View style={[s.barra, { paddingBottom: 12 + lugarAbajo }]}>
      {sos}
      {items.map(({ clave, texto, icono }) => {
        const activo = clave === actual;
        return (
          <Pressable
            key={clave}
            accessibilityRole="button"
            accessibilityLabel={clave === "configuracion" ? "Configuración" : texto}
            accessibilityState={{ selected: activo }}
            onPress={() => onElegir(clave)}
            style={[s.barraItem, activo && s.barraItemActivo]}
          >
            <Image source={icono} style={s.barraIcono} resizeMode="contain" />
            <Text adjustsFontSizeToFit minimumFontScale={0.8} numberOfLines={1} style={[s.barraTexto, activo && s.barraTextoActivo]}>{texto}</Text>
          </Pressable>
        );
      })}
      <Pressable
        accessibilityRole="button"
        accessibilityLabel="Abrir el panel de Ojo Guard MS"
        disabled={abriendo}
        onPress={onPanel}
        style={[s.barraItem, s.barraPanel, abriendo && s.barraPanelApagado]}
      >
        <Image source={ICONOS.conexion} style={s.barraIcono} resizeMode="contain" />
        <Text adjustsFontSizeToFit minimumFontScale={0.8} numberOfLines={1} style={[s.barraTexto, s.barraTextoActivo]}>{abriendo ? "Abriendo…" : "Panel"}</Text>
      </Pressable>
    </View>
  );
}

type BotonesInicioProps = { paleta: Paleta; onPerfil: () => void; onConfiguracion: () => void };

/** Debajo de la tarjeta del teléfono: "Mi perfil" (los datos de uno) y la tuerca de "Configuración". */
export function BotonesInicio({ paleta: P, onPerfil, onConfiguracion }: BotonesInicioProps) {
  const s = estilos(P);
  return (
    <View style={s.botonesInicio}>
      <Pressable accessibilityRole="button" accessibilityLabel="Mi perfil" onPress={onPerfil} style={s.botonInicio}>
        <Image source={ICONO_PERFIL} style={s.botonInicioIcono} resizeMode="contain" />
        <Text adjustsFontSizeToFit minimumFontScale={0.8} numberOfLines={1} style={s.botonInicioTexto}>Mi perfil</Text>
      </Pressable>
      <Pressable accessibilityRole="button" accessibilityLabel="Configuración" onPress={onConfiguracion} style={s.botonInicio}>
        <Image source={ICONO_TUERCA} style={s.botonInicioIcono} resizeMode="contain" />
        <Text adjustsFontSizeToFit minimumFontScale={0.8} numberOfLines={1} style={s.botonInicioTexto}>Configuración</Text>
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

/** Configuración: Familia y amigos (tarjeta ancha) y seis tarjetas grandes con ícono, de a dos por fila. Cada una abre los bloques de siempre de su grupo. */
export function TarjetasConfiguracion({ paleta: P, android, intentos, pendientes, cercania, radioMetros, conexion, onElegir }: TarjetasProps) {
  const s = estilos(P);
  const tarjetas: Array<{ grupo: Exclude<GrupoConfiguracion, "permisos" | "perfil">; detalle: string }> = [
    { grupo: "claves", detalle: "PIN de admin, señuelo y evidencia" },
    { grupo: "fotos", detalle: intentos > 0 ? `${intentos} intento${intentos === 1 ? "" : "s"} registrado${intentos === 1 ? "" : "s"}` : "Ningún intento registrado" },
    { grupo: "perdido", detalle: `Mensaje de rescate y ${cercania ? `radio ${radioMetros} m` : "cercanía apagada"}` },
    { grupo: "preferencias", detalle: pendientes > 0 ? `Modo preventivo, OLED · ${pendientes} por enviar` : "Modo preventivo, OLED y envíos" },
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
      <Pressable
        accessibilityRole="button"
        accessibilityLabel="Familia y amigos. Unirme con un código, pausar mi ubicación y el SOS"
        onPress={() => onElegir("familia")}
        style={s.celdaAncha}
      >
        <Image source={ICONOS.familia} style={s.iconoAncho} resizeMode="contain" />
        <View style={s.celdaAnchaTextos}>
          <Text style={s.celdaAnchaTitulo}>Familia y amigos</Text>
          <Text style={s.celdaDetalleIzq}>Unirme con un código, pausar mi ubicación y el SOS</Text>
        </View>
        <Text style={s.celdaFlecha}>{"\u203a"}</Text>
      </Pressable>
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

type CabeceraPantallaProps = { paleta: Paleta; titulo: string; resumen?: string; onVolver?: () => void };

/** "‹ Atrás" bien separado de la ✕ (que solo está en el Inicio), el título y, si hace falta, una línea chica. Sin `onVolver` no hay "Atrás": la barra de arriba lleva a las otras pantallas. */
export function CabeceraPantalla({ paleta: P, titulo, resumen, onVolver }: CabeceraPantallaProps) {
  const s = estilos(P);
  return (
    <View style={s.cabecera}>
      {onVolver ? (
        <Pressable accessibilityRole="button" accessibilityLabel="Atrás" hitSlop={10} onPress={onVolver} style={s.volver}>
          <Text style={s.volverTexto}>‹ Atrás</Text>
        </Pressable>
      ) : null}
      <Text style={s.cabeceraTitulo}>{titulo}</Text>
      {resumen ? <Text style={s.cabeceraResumen}>{resumen}</Text> : null}
    </View>
  );
}

type CabeceraProps = { paleta: Paleta; android: boolean; grupo: GrupoConfiguracion; onVolver?: () => void };

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
    botonesInicio: { flexDirection: "row", gap: 12, marginBottom: 12 },
    botonInicio: { alignItems: "center", backgroundColor: P.superficieHonda, borderColor: P.borde, borderRadius: 18, borderWidth: 1, flex: 1, flexDirection: "row", gap: 8, justifyContent: "center", minHeight: 56, paddingHorizontal: 8, paddingVertical: 10 },
    botonInicioIcono: { height: 28, width: 28 },
    // En Android la app llega hasta arriba de todo: el renglón empieza debajo de la barra de estado (hora, batería).
    cabeza: { alignItems: "center", marginBottom: 6, marginHorizontal: 44, paddingTop: Platform.OS === "android" ? Math.max(26, (StatusBar.currentHeight ?? 0) + 2) : 4 },
    cabezaNombre: { color: P.texto, fontSize: 16, fontWeight: "800" },
    cabezaEstado: { alignItems: "center", flexDirection: "row", gap: 6, marginTop: 1 },
    cabezaEstadoTexto: { fontSize: 12, fontWeight: "700" },
    // Abajo, fija: encima del mapa si hay un aviso del SOS (zIndex), y con lugar para el gesto de volver de Android.
    barra: { backgroundColor: P.fondo, borderTopColor: P.borde, borderTopWidth: 1, elevation: 8, flexDirection: "row", gap: 6, paddingBottom: 12, paddingHorizontal: 10, paddingTop: 8, zIndex: 8 },
    barraItem: { alignItems: "center", backgroundColor: P.superficieHonda, borderColor: P.borde, borderRadius: 14, borderWidth: 1, flex: 1, gap: 3, justifyContent: "center", paddingHorizontal: 2, paddingVertical: 7 },
    barraItemActivo: { backgroundColor: P.doradoFondo, borderColor: P.doradoBorde },
    barraPanel: { backgroundColor: P.doradoFondoFuerte, borderColor: P.doradoBordeMedio, borderWidth: 1.5 },
    barraPanelApagado: { opacity: 0.6 },
    barraIcono: { height: 22, width: 22 },
    barraTexto: { color: P.texto, fontSize: 11, fontWeight: "800" },
    barraTextoActivo: { color: P.doradoTexto },
    botonInicioTexto: { color: P.texto, flexShrink: 1, fontSize: 15, fontWeight: "800" },
    banda: { alignItems: "center", borderRadius: 16, borderWidth: 1, justifyContent: "center", marginBottom: 12, marginTop: 4, minHeight: 50, paddingHorizontal: 14, paddingVertical: 12 },
    bandaTexto: { fontSize: 15, fontWeight: "700", textAlign: "center" },
    grilla: { gap: 12, marginBottom: 12, marginTop: 4 },
    fila: { flexDirection: "row", gap: 12 },
    celda: { alignItems: "center", backgroundColor: P.superficieHonda, borderColor: P.borde, borderRadius: 22, borderWidth: 1, flex: 1, minHeight: 150, paddingHorizontal: 10, paddingVertical: 16 },
    icono: { height: 46, width: 46 },
    celdaTitulo: { color: P.texto, fontSize: 16, fontWeight: "800", marginTop: 10, textAlign: "center" },
    celdaDetalle: { color: P.textoTenue, fontSize: 12, lineHeight: 16, marginTop: 5, textAlign: "center" },
    celdaAncha: { alignItems: "center", backgroundColor: P.superficieHonda, borderColor: P.borde, borderRadius: 22, borderWidth: 1, flexDirection: "row", gap: 14, minHeight: 84, paddingHorizontal: 16, paddingVertical: 14 },
    iconoAncho: { height: 46, width: 46 },
    celdaAnchaTextos: { flex: 1 },
    celdaAnchaTitulo: { color: P.texto, fontSize: 16, fontWeight: "800" },
    celdaDetalleIzq: { color: P.textoTenue, fontSize: 12, lineHeight: 16, marginTop: 3 },
    celdaFlecha: { color: P.doradoTexto, fontSize: 28, lineHeight: 30 },
    cabecera: { marginBottom: 16, marginTop: 8 },
    volver: { alignSelf: "flex-start", backgroundColor: P.superficieHonda, borderColor: P.borde, borderRadius: 18, borderWidth: 1, paddingHorizontal: 16, paddingVertical: 8 },
    volverTexto: { color: P.doradoTexto, fontSize: 16, fontWeight: "800" },
    cabeceraTitulo: { color: P.texto, fontSize: 26, fontWeight: "700", marginTop: 14 },
    cabeceraResumen: { color: P.textoTenue, fontSize: 12.5, lineHeight: 18, marginTop: 4 },
  });
}
