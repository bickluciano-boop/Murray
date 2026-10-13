import { useCallback, useEffect, useRef, useState } from "react";
import { ActivityIndicator, Animated, AppState, Easing, Platform, Pressable, Share, StyleSheet, Text, Vibration, View, type StyleProp, type TextStyle, type ViewStyle } from "react-native";

import { isSosGestureEnabled, openSosAccessibilitySettings, openSosAppInfo, openSosChannelSettings, sosGestureAvailable } from "../modules/sos-trigger";
import { markPendingSystemActivity } from "./pendingSystemActivity";
import { Plegable } from "./Plegable";
import type { NativeEnrollment } from "./remoteStorage";
import { cancelSos, fetchMySos, sendSos, SosError, type SosEstado } from "./sos";
import "./sosMapa";
import { sosShortcutLink } from "./sosTask";

/**
 * Botón de SOS dentro de "Familia y amigos". Hay que mantenerlo apretado 3 segundos (para que no salga por un toque
 * sin querer): vibra, manda el pedido y muestra a quién se le avisó, con "Estoy bien" para cancelarlo.
 *
 * Se ve solo si este teléfono está en una familia. Lo que pasa del otro lado (sirena, mail, mapa) está en sos.ts y en el
 * servidor. Debajo del botón explica cómo pedir ayuda SIN abrir la app: en Android, mantener los dos botones de volumen
 * (servicio de accesibilidad "Ojo Guard SOS"); en iPhone, un atajo con el enlace del SOS (Siri, toque en la espalda,
 * pantalla de bloqueo). Los dos caminos terminan en sosTask.ts.
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
  const [gestoActivo, setGestoActivo] = useState(false);
  const [enlace, setEnlace] = useState("");
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

  // El gesto de volumen se activa en Ajustes: al volver a la app se vuelve a mirar si quedó activado.
  useEffect(() => {
    const revisar = () => setGestoActivo(isSosGestureEnabled());
    revisar();
    const suscripcion = AppState.addEventListener("change", (estado) => {
      if (estado === "active") {
        revisar();
        void cargar();
      }
    });
    return () => suscripcion.remove();
  }, [cargar]);

  useEffect(() => {
    if (Platform.OS === "ios" && visible) void sosShortcutLink().then(setEnlace).catch(() => undefined);
  }, [visible]);

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

  function activarGesto() {
    // Volver de Ajustes no tiene que mandar la app a la pantalla de bloqueo.
    markPendingSystemActivity();
    openSosAccessibilitySettings();
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

      {Platform.OS === "android" && sosGestureAvailable() ? (
        <Plegable key={gestoActivo ? "gesto-listo" : "gesto-falta"} titulo="Pedir ayuda sin abrir la app" paleta={P} abiertoInicial={!gestoActivo}>
          {gestoActivo ? (
            <Text style={botones.ayuda}>
              Activado: mantené apretados los dos botones de volumen durante 3 segundos, aunque la pantalla esté apagada. El teléfono vibra cuando sale el pedido.
            </Text>
          ) : (
            <>
              <Text style={botones.ayuda}>
                Mantené apretados los dos botones de volumen durante 3 segundos, aunque la pantalla esté apagada. Para activarlo tocá el botón, buscá «Ojo Guard SOS» en Accesibilidad y activalo. Solo mira los botones de volumen: no lee la pantalla.
              </Text>
              <Pressable accessibilityRole="button" onPress={activarGesto} style={[botones.secundario, s.espacio]}>
                <Text style={botones.secundarioTexto}>Activar el gesto de volumen</Text>
              </Pressable>
              <Pressable
                accessibilityRole="button"
                onPress={() => {
                  markPendingSystemActivity();
                  openSosAppInfo();
                }}
                style={[botones.secundario, s.espacio]}
              >
                <Text style={botones.secundarioTexto}>El interruptor está gris</Text>
              </Pressable>
              <Text style={[botones.ayuda, s.ayuda]}>
                Si el interruptor aparece gris: en la información de la app tocá los tres puntos de arriba y elegí «Permitir configuración restringida».
              </Text>
            </>
          )}
          <Text style={[botones.ayuda, s.ayuda]}>
            Los SOS de tu familia te llegan con una sirena. Si tu teléfono está en No interrumpir y no suena, abrí esta pantalla y activá «Anular No interrumpir».
          </Text>
          <Pressable
            accessibilityRole="button"
            onPress={() => {
              markPendingSystemActivity();
              openSosChannelSettings();
            }}
            style={[botones.secundario, s.espacio]}
          >
            <Text style={botones.secundarioTexto}>Que la sirena suene con No interrumpir</Text>
          </Pressable>
        </Plegable>
      ) : null}

      {Platform.OS === "ios" ? (
        <Plegable titulo="Pedir ayuda sin buscar el botón" paleta={P}>
          <Text style={botones.ayuda}>
            1. En la app Atajos creá un atajo con la acción «Abrir URL», pegá este enlace y llamalo «SOS Ojo Guard».{"\n"}
            2. Para dispararlo: decile a Siri «SOS Ojo Guard»; o en Ajustes › Accesibilidad › Tocar › Tocar atrás elegí ese atajo; o agregalo como control en la pantalla de bloqueo.{"\n"}
            Con el iPhone bloqueado pide Face ID para abrir la app. Seguí teniendo configurado el SOS de emergencias de Apple.
          </Text>
          {enlace ? (
            <>
              <Text selectable style={s.enlace}>
                {enlace}
              </Text>
              <Pressable accessibilityRole="button" onPress={() => void Share.share({ message: enlace })} style={[botones.secundario, s.espacio]}>
                <Text style={botones.secundarioTexto}>Copiar o compartir el enlace</Text>
              </Pressable>
            </>
          ) : null}
        </Plegable>
      ) : null}
    </View>
  );
}

function estilos(P: Paleta) {
  return StyleSheet.create({
    bloque: { marginTop: 18 },
    titulo: { color: P.textoSuave, fontSize: 13, fontWeight: "600", marginBottom: 8 },
    boton: { height: 68, borderRadius: 16, overflow: "hidden", alignItems: "center", justifyContent: "center", backgroundColor: ROJO },
    relleno: { position: "absolute", left: 0, top: 0, bottom: 0, backgroundColor: ROJO_OSCURO },
    botonTextos: { alignItems: "center", alignSelf: "stretch", paddingHorizontal: 12 },
    botonTexto: { color: "#ffffff", fontSize: 24, fontWeight: "800", letterSpacing: 4 },
    botonSub: { color: "#ffd9d4", fontSize: 12, marginTop: 1, textAlign: "center" },
    ayuda: { marginTop: 8 },
    enCurso: { padding: 14, borderRadius: 14, borderWidth: 1, borderColor: P.peligroBorde ?? ROJO, backgroundColor: P.peligroFondo ?? "#261313" },
    enCursoTitulo: { color: P.peligroFuerte ?? "#ff9d9d", fontSize: 16, fontWeight: "800" },
    enCursoTexto: { color: P.texto, fontSize: 13, lineHeight: 18, marginTop: 4 },
    estoyBien: { marginTop: 12 },
    apagado: { opacity: 0.5 },
    mensaje: { color: P.doradoTexto, fontSize: 13, marginTop: 10, lineHeight: 18 },
    espacio: { marginTop: 10 },
    enlace: { color: P.texto, fontSize: 13, marginTop: 10, padding: 10, borderRadius: 10, borderWidth: 1, borderColor: P.borde },
  });
}
