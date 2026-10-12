import { useCallback, useEffect, useRef, useState } from "react";
import { ActivityIndicator, Animated, AppState, Easing, Pressable, StyleSheet, Text, Vibration, View, type StyleProp, type TextStyle, type ViewStyle } from "react-native";

import type { NativeEnrollment } from "./remoteStorage";
import { cancelSos, fetchMySos, sendSos, SosError, type SosEstado } from "./sos";

/**
 * Botón de SOS dentro de "Familia y amigos". Hay que mantenerlo apretado 3 segundos (para que no salga por un toque
 * sin querer): vibra, manda el pedido y muestra a quién se le avisó, con "Estoy bien" para cancelarlo.
 *
 * Se ve solo si este teléfono está en una familia. Lo que pasa del otro lado (sirena, mail, mapa) está en sos.ts y en el
 * servidor. Más adelante el mismo pedido se podrá disparar sin abrir la app (volumen mantenido, Siri, toque en la espalda).
 */

const MANTENER_MS = 3_000;
const ROJO = "#c4291b";
const ROJO_OSCURO = "#7f1810";

type Paleta = { [clave: string]: string };

type Props = {
  enrollment: NativeEnrollment | null | undefined;
  visible: boolean;
  paleta: Paleta;
  botones: {
    secundario: StyleProp<ViewStyle>;
    secundarioTexto: StyleProp<TextStyle>;
    ayuda: StyleProp<TextStyle>;
  };
};

const ERRORES: Record<string, string> = {
  no_recipients: "No hay nadie a quien avisar. Sumá a alguien a tu familia primero.",
  unauthorized: "Este teléfono ya no está vinculado con Ojo Guard MS.",
  red: "No se pudo mandar. Revisá la conexión y probá de nuevo.",
};

function mensajeDeError(error: unknown) {
  const clave = error instanceof SosError ? error.code : "red";
  return ERRORES[clave] ?? "No se pudo mandar el SOS. Probá de nuevo.";
}

function listaDeNombres(nombres: string[]) {
  if (nombres.length <= 1) return nombres[0] ?? "tu familia";
  return `${nombres.slice(0, -1).join(", ")} y ${nombres[nombres.length - 1]}`;
}

export function SosBlock({ enrollment, visible, paleta: P, botones }: Props) {
  const [sos, setSos] = useState<SosEstado | null>(null);
  const [trabajando, setTrabajando] = useState(false);
  const [mensaje, setMensaje] = useState("");
  const avance = useRef(new Animated.Value(0)).current;

  const cargar = useCallback(async () => {
    if (!enrollment) return;
    try {
      setSos(await fetchMySos(enrollment));
    } catch {
      // Sin red se deja como está.
    }
  }, [enrollment]);

  useEffect(() => {
    if (visible && enrollment) void cargar();
  }, [visible, enrollment, cargar]);

  useEffect(() => {
    const suscripcion = AppState.addEventListener("change", (estado) => {
      if (estado === "active") void cargar();
    });
    return () => suscripcion.remove();
  }, [cargar]);

  const empezar = () => {
    avance.setValue(0);
    Animated.timing(avance, { toValue: 1, duration: MANTENER_MS, easing: Easing.linear, useNativeDriver: false }).start();
  };
  const soltar = () => {
    avance.stopAnimation();
    avance.setValue(0);
  };

  async function enviar() {
    if (!enrollment || trabajando) return;
    Vibration.vibrate(400);
    setTrabajando(true);
    setMensaje("");
    try {
      const r = await sendSos(enrollment);
      setSos({ id: r.id, createdAt: new Date().toISOString(), to: r.to });
    } catch (error) {
      setMensaje(mensajeDeError(error));
    } finally {
      setTrabajando(false);
      soltar();
    }
  }

  async function estoyBien() {
    if (!enrollment || trabajando) return;
    setTrabajando(true);
    setMensaje("");
    try {
      await cancelSos(enrollment);
      setSos(null);
      setMensaje("Listo: les avisamos que estás bien.");
    } catch (error) {
      setMensaje(mensajeDeError(error));
    } finally {
      setTrabajando(false);
    }
  }

  if (!visible || !enrollment) return null;
  const s = estilos(P);
  const ancho = avance.interpolate({ inputRange: [0, 1], outputRange: ["0%", "100%"] });

  return (
    <View style={s.bloque}>
      <Text style={s.titulo}>Pedir ayuda (SOS)</Text>
      {sos ? (
        <View style={s.enCurso}>
          <Text style={s.enCursoTitulo}>SOS enviado</Text>
          <Text style={s.enCursoTexto}>
            Le avisamos a {listaDeNombres(sos.to)}. Ven tu ubicación en el mapa y les suena la sirena hasta que lo atiendan.
          </Text>
          <Pressable accessibilityRole="button" disabled={trabajando} onPress={() => void estoyBien()} style={[botones.secundario, s.estoyBien, trabajando && s.apagado]}>
            {trabajando ? <ActivityIndicator color={P.texto} /> : <Text style={botones.secundarioTexto}>Estoy bien</Text>}
          </Pressable>
        </View>
      ) : (
        <>
          <Pressable
            accessibilityRole="button"
            accessibilityLabel="Pedir ayuda"
            accessibilityHint="Mantenelo apretado 3 segundos para avisarle a tu familia"
            delayLongPress={MANTENER_MS}
            disabled={trabajando}
            onLongPress={() => void enviar()}
            onPressIn={empezar}
            onPressOut={soltar}
            style={s.boton}
          >
            <Animated.View pointerEvents="none" style={[s.relleno, { width: ancho }]} />
            {trabajando ? (
              <ActivityIndicator color="#ffffff" />
            ) : (
              <View style={s.botonTextos} pointerEvents="none">
                <Text style={s.botonTexto}>SOS</Text>
                <Text style={s.botonSub}>Mantené apretado 3 segundos</Text>
              </View>
            )}
          </Pressable>
          <Text style={[botones.ayuda, s.ayuda]}>
            Avisa a tu familia con tu ubicación: les suena una sirena y te ven en el mapa 10 minutos.
          </Text>
        </>
      )}
      {mensaje ? <Text style={s.mensaje}>{mensaje}</Text> : null}
    </View>
  );
}

function estilos(P: Paleta) {
  return StyleSheet.create({
    bloque: { marginTop: 18 },
    titulo: { color: P.textoSuave, fontSize: 13, fontWeight: "600", marginBottom: 8 },
    boton: { height: 68, borderRadius: 16, overflow: "hidden", alignItems: "center", justifyContent: "center", backgroundColor: ROJO },
    relleno: { position: "absolute", left: 0, top: 0, bottom: 0, backgroundColor: ROJO_OSCURO },
    botonTextos: { alignItems: "center" },
    botonTexto: { color: "#ffffff", fontSize: 24, fontWeight: "800", letterSpacing: 4 },
    botonSub: { color: "#ffd9d4", fontSize: 12, marginTop: 1 },
    ayuda: { marginTop: 8 },
    enCurso: { padding: 14, borderRadius: 14, borderWidth: 1, borderColor: P.peligroBorde ?? ROJO, backgroundColor: P.peligroFondo ?? "#261313" },
    enCursoTitulo: { color: P.peligroFuerte ?? "#ff9d9d", fontSize: 16, fontWeight: "800" },
    enCursoTexto: { color: P.texto, fontSize: 13, lineHeight: 18, marginTop: 4 },
    estoyBien: { marginTop: 12 },
    apagado: { opacity: 0.5 },
    mensaje: { color: P.doradoTexto, fontSize: 13, marginTop: 10, lineHeight: 18 },
  });
}
