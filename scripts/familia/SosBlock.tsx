import { useCallback, useEffect, useRef, useState } from "react";
import { ActivityIndicator, Animated, AppState, Easing, Platform, Pressable, Share, StyleSheet, Text, Vibration, View, type StyleProp, type TextStyle, type ViewStyle } from "react-native";

import { isSosGestureEnabled, openSosAccessibilitySettings, openSosAppInfo, openSosChannelSettings, sosGestureAvailable } from "../modules/sos-trigger";
import { markPendingSystemActivity } from "./pendingSystemActivity";
import { Plegable } from "./Plegable";
import { fetchFamily } from "./remoteApi";
import { loadNativeEnrollment, type NativeEnrollment } from "./remoteStorage";
import { cancelSos, fetchMySos, sendSos, SosError, type SosEstado } from "./sos";
import "./sosMapa";
import { sosShortcutLink } from "./sosTask";

/**
 * El SOS. El botón es un cuadradito rojo dentro de la barra de abajo, fija en todas las pantallas (modo `cuadrado`, ver SosEnBarra); la
 * pantalla de Familia y amigos solo trae las ayudas para pedirlo sin abrir la app (así el botón no se repite). El modo `compacto` (la franja
 * ancha que había en el Inicio) ya no se usa, pero se deja. Hay que mantenerlo apretado 3 segundos (para que no salga por un toque
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
  /** Inicio con mapa: solo el botón (o "SOS enviado" con "Estoy bien"), en una franja baja. Lo demás queda en Familia. */
  compacto?: boolean;
  /** En la barra de abajo: un cuadradito con "SOS" y "3 s" (mantener apretado 3 segundos). */
  cuadrado?: boolean;
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

export function SosBlock({ enrollment, visible, compacto = false, cuadrado = false, paleta: P, botones }: Props) {
  const [sos, setSos] = useState<SosEstado | null>(null);
  const [trabajando, setTrabajando] = useState(false);
  const [mensaje, setMensaje] = useState("");
  const [gestoActivo, setGestoActivo] = useState(false);
  const [enlace, setEnlace] = useState("");
  const avance = useRef(new Animated.Value(0)).current;
  // Mientras se mantiene apretado, el cuadradito cuenta 3, 2, 1 para que se note que está andando.
  const [restante, setRestante] = useState<number | null>(null);
  const cuenta = useRef<ReturnType<typeof setInterval> | null>(null);
  useEffect(() => () => { if (cuenta.current) clearInterval(cuenta.current); }, []);

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
    const inicio = Date.now();
    setRestante(Math.ceil(MANTENER_MS / 1000));
    if (cuenta.current) clearInterval(cuenta.current);
    cuenta.current = setInterval(() => setRestante(Math.max(1, Math.ceil((MANTENER_MS - (Date.now() - inicio)) / 1000))), 200);
  };
  const soltar = () => {
    avance.stopAnimation();
    avance.setValue(0);
    if (cuenta.current) {
      clearInterval(cuenta.current);
      cuenta.current = null;
    }
    setRestante(null);
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

  // En el cuadradito el aviso flota arriba de la barra: se va solo a los 8 segundos.
  useEffect(() => {
    if (!cuadrado || !mensaje) return;
    const espera = setTimeout(() => setMensaje(""), 8_000);
    return () => clearTimeout(espera);
  }, [cuadrado, mensaje]);

  if (!visible || !enrollment) return null;
  const s = estilos(P);
  const ancho = avance.interpolate({ inputRange: [0, 1], outputRange: ["0%", "100%"] });

  if (cuadrado) {
    const aviso = mensaje || (sos ? `SOS enviado. Le avisamos a ${listaDeNombres(sos.to)}.` : "");
    return (
      <View style={s.cuadradoCaja}>
        {sos ? (
          <Pressable
            accessibilityRole="button"
            accessibilityLabel="Estoy bien. Cancelar el SOS"
            disabled={trabajando}
            onPress={() => void estoyBien()}
            style={[s.cuadrado, s.cuadradoEnCurso, trabajando && s.apagado]}
          >
            {trabajando ? (
              <ActivityIndicator color="#ffffff" />
            ) : (
              <Text style={s.cuadradoEstoyBien}>{"Estoy\nbien"}</Text>
            )}
          </Pressable>
        ) : (
          <Pressable
            accessibilityRole="button"
            accessibilityLabel="Pedir ayuda"
            accessibilityHint="Mantenelo apretado 3 segundos para avisarle a tu familia"
            delayLongPress={MANTENER_MS}
            disabled={trabajando}
            onLongPress={() => void enviar()}
            onPressIn={empezar}
            onPressOut={soltar}
            style={s.cuadrado}
          >
            <Animated.View pointerEvents="none" style={[s.relleno, { width: ancho }]} />
            {trabajando ? (
              <ActivityIndicator color="#ffffff" />
            ) : (
              <View pointerEvents="none" style={s.cuadradoTextos}>
                <Text style={s.cuadradoSos}>SOS</Text>
                <Text style={s.cuadradoSub}>{restante ?? 3} s</Text>
              </View>
            )}
          </Pressable>
        )}
        {aviso ? (
          <View pointerEvents="none" style={s.flotante}>
            <Text style={s.flotanteTexto}>{aviso}</Text>
          </View>
        ) : null}
      </View>
    );
  }

  if (compacto) {
    return (
      <View style={s.compacto}>
        {sos ? (
          <View style={[s.enCurso, s.enCursoFila]}>
            <View style={s.enCursoTextos}>
              <Text style={s.enCursoTitulo}>SOS enviado</Text>
              <Text numberOfLines={2} style={s.enCursoTexto}>
                Le avisamos a {listaDeNombres(sos.to)}.
              </Text>
            </View>
            <Pressable accessibilityRole="button" disabled={trabajando} onPress={() => void estoyBien()} style={[botones.secundario, s.compactoBoton, trabajando && s.apagado]}>
              {trabajando ? <ActivityIndicator color={P.texto} /> : <Text style={botones.secundarioTexto}>Estoy bien</Text>}
            </Pressable>
          </View>
        ) : (
          <Pressable
            accessibilityRole="button"
            accessibilityLabel="Pedir ayuda"
            accessibilityHint="Mantenelo apretado 3 segundos para avisarle a tu familia"
            delayLongPress={MANTENER_MS}
            disabled={trabajando}
            onLongPress={() => void enviar()}
            onPressIn={empezar}
            onPressOut={soltar}
            style={[s.boton, s.botonCompacto]}
          >
            <Animated.View pointerEvents="none" style={[s.relleno, { width: ancho }]} />
            {trabajando ? (
              <ActivityIndicator color="#ffffff" />
            ) : (
              <View style={s.botonCompactoTextos} pointerEvents="none">
                <Text style={s.botonCompactoSos}>SOS</Text>
                <Text style={s.botonCompactoSub}>Mantené apretado 3 segundos</Text>
              </View>
            )}
          </Pressable>
        )}
        {mensaje ? <Text style={s.mensaje}>{mensaje}</Text> : null}
      </View>
    );
  }

  // Pantalla de Familia: el botón de SOS ya está en el Inicio (franja roja de abajo); acá solo se explica y quedan las ayudas para pedirlo
  // sin abrir la app.
  return (
    <View style={s.bloque}>
      <Text style={[botones.ayuda, s.ayuda]}>
        El botón de SOS está en el Inicio, abajo: mantenelo apretado 3 segundos y avisa a tu familia con tu ubicación (les suena una sirena y te ven en el mapa 10 minutos).
      </Text>
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
    // El cuadradito de la barra de abajo: ocupa lo mismo que cada botón de la barra (flex 1) y es rojo.
    cuadradoCaja: { flex: 1 },
    cuadrado: { alignItems: "center", backgroundColor: ROJO, borderRadius: 14, flex: 1, justifyContent: "center", minHeight: 52, overflow: "hidden", paddingHorizontal: 2 },
    cuadradoEnCurso: { backgroundColor: ROJO_OSCURO },
    cuadradoTextos: { alignItems: "center" },
    cuadradoSos: { color: "#ffffff", fontSize: 17, fontWeight: "900", letterSpacing: 1.5 },
    cuadradoSub: { color: "#ffd9d4", fontSize: 12, fontWeight: "800", marginTop: -1 },
    cuadradoEstoyBien: { color: "#ffffff", fontSize: 14, fontWeight: "900", lineHeight: 17, textAlign: "center" },
    flotante: { backgroundColor: ROJO_OSCURO, borderRadius: 12, bottom: "100%", left: 0, marginBottom: 8, paddingHorizontal: 12, paddingVertical: 8, position: "absolute", width: 250 },
    flotanteTexto: { color: "#ffffff", fontSize: 13, fontWeight: "700", lineHeight: 18 },
    compacto: { marginTop: 8 },
    botonCompacto: { height: 56 },
    botonCompactoTextos: { alignItems: "center", flexDirection: "row", gap: 12, justifyContent: "center", paddingHorizontal: 12 },
    botonCompactoSos: { color: "#ffffff", fontSize: 22, fontWeight: "800", letterSpacing: 4 },
    botonCompactoSub: { color: "#ffd9d4", flexShrink: 1, fontSize: 12 },
    enCursoFila: { alignItems: "center", flexDirection: "row", gap: 12 },
    enCursoTextos: { flex: 1 },
    compactoBoton: { paddingHorizontal: 16 },
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

/**
 * El SOS dentro de la barra de abajo (BarraInferior): mira si este teléfono está en una familia (o ve a alguien) y, solo en ese caso, muestra el
 * cuadradito. Se vuelve a mirar cada vez que se vuelve a la app.
 */
export function SosEnBarra({ paleta, botones }: { paleta: Paleta; botones: Props["botones"] }) {
  const [vinculo, setVinculo] = useState<NativeEnrollment | null | undefined>(undefined);
  const [conFamilia, setConFamilia] = useState(false);

  useEffect(() => {
    let vivo = true;
    const mirar = async () => {
      const actual = await loadNativeEnrollment().catch(() => null);
      if (!vivo) return;
      setVinculo(actual);
      if (!actual) return;
      try {
        const datos = await fetchFamily(actual);
        if (vivo) setConFamilia(datos.me.memberships > 0 || datos.people.length > 0);
      } catch {
        // Sin red se deja como estaba.
      }
    };
    void mirar();
    const suscripcion = AppState.addEventListener("change", (estado) => {
      if (estado === "active") void mirar();
    });
    return () => {
      vivo = false;
      suscripcion.remove();
    };
  }, []);

  return <SosBlock enrollment={vinculo} visible={conFamilia} cuadrado paleta={paleta} botones={botones} />;
}
