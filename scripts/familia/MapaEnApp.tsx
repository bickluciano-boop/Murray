import { useCallback, useEffect, useRef, useState } from "react";
import { ActivityIndicator, AppState, Linking, Pressable, StyleSheet, Text, View } from "react-native";
import { WebView, type WebViewMessageEvent } from "react-native-webview";

import { markPendingSystemActivity } from "./pendingSystemActivity";
import { requestPanelHandoff } from "./remoteApi";
import { loadNativeEnrollment } from "./remoteStorage";

/**
 * El mapa de Ojo Guard MS adentro de la app: los equipos y la familia, con sus fotos, "Hacer sonar", "Seguir en vivo", "Cómo llegar",
 * invitar, lugares y avisos. Es el mismo mapa del panel, en su modo "solo mapa" (`/acceso-v7?app=mapa`), así que todo lo que se mejora
 * en el panel aparece acá sin tocar la app.
 *
 * POR QUÉ ASÍ. El mapa nativo de Google en Android necesita una clave que la app no tiene (y sin ella la app se cierra). En cambio el
 * mapa del panel ya funciona en cualquier navegador. Para entrar sin pedir códigos, la app pide al servidor un enlace de un solo uso
 * (como el botón "Abrir Ojo Guard MS"): el teléfono ya está vinculado y se entró a la app con la clave de administrador. Ese acceso
 * dura 30 minutos, así que se renueva solo cada 20 minutos y al volver a la app si pasó más tiempo.
 *
 * Los enlaces que salen del panel (por ejemplo "Cómo llegar" en Google Maps) se abren afuera, y volver no pide la clave de la app.
 */

const ORIGEN = "https://ojo-guard-ms-api.bickluciano.workers.dev";
const RENOVAR_MS = 20 * 60_000;

type Paleta = { [clave: string]: string };
type Estado = "cargando" | "listo" | "error" | "sin_vinculo";

type Props = {
  paleta: Paleta;
  /** El tema de la app: el mapa se ve igual (claro o noche). */
  tema: "claro" | "oscuro";
  /** Cuando este teléfono no está vinculado con Ojo Guard MS: lleva a donde se vincula. */
  onVincular: () => void;
};

export function MapaEnApp({ paleta: P, tema, onVincular }: Props) {
  const [estado, setEstado] = useState<Estado>("cargando");
  const [uri, setUri] = useState<string | null>(null);
  const [carga, setCarga] = useState(0);
  const cargadoEn = useRef(0);
  const s = estilos(P);

  const cargar = useCallback(async () => {
    setEstado("cargando");
    try {
      const vinculo = await loadNativeEnrollment();
      if (!vinculo) {
        setEstado("sin_vinculo");
        return;
      }
      const enlace = await requestPanelHandoff(vinculo, "mapa");
      cargadoEn.current = Date.now();
      setUri(enlace);
      setCarga((n) => n + 1);
    } catch {
      setEstado("error");
    }
  }, []);

  useEffect(() => {
    void cargar();
  }, [cargar]);

  // El acceso dura 30 minutos: se renueva si la app estuvo un rato en segundo plano y cada 20 minutos mientras sigue abierta.
  useEffect(() => {
    const suscripcion = AppState.addEventListener("change", (estadoApp) => {
      if (estadoApp === "active" && cargadoEn.current && Date.now() - cargadoEn.current > RENOVAR_MS) void cargar();
    });
    const intervalo = setInterval(() => {
      if (AppState.currentState === "active" && cargadoEn.current && Date.now() - cargadoEn.current > RENOVAR_MS) void cargar();
    }, 60_000);
    return () => {
      suscripcion.remove();
      clearInterval(intervalo);
    };
  }, [cargar]);

  function alMensaje(evento: WebViewMessageEvent) {
    try {
      const dato = JSON.parse(evento.nativeEvent.data) as { tipo?: string };
      if (dato.tipo === "sin_sesion") setEstado("error");
    } catch {
      // Un mensaje que no es del panel.
    }
  }

  const destino = estado === "sin_vinculo" ? null : uri;

  return (
    <View style={s.caja}>
      {destino ? (
        <WebView
          key={carga}
          source={{ uri: destino }}
          style={s.web}
          // El tema de la app se le pasa al mapa antes de que dibuje.
          injectedJavaScriptBeforeContentLoaded={`try { localStorage.setItem("ojo_ms_tema", "${tema}"); } catch (e) {} true;`}
          javaScriptEnabled
          domStorageEnabled
          geolocationEnabled
          sharedCookiesEnabled
          thirdPartyCookiesEnabled
          setSupportMultipleWindows={false}
          mixedContentMode="never"
          originWhitelist={["https://*"]}
          overScrollMode="never"
          bounces={false}
          onShouldStartLoadWithRequest={(pedido) => {
            if (pedido.isTopFrame === false || pedido.url.startsWith(ORIGEN) || pedido.url.startsWith("about:")) return true;
            // Lo que sale del panel (Cómo llegar en Google Maps, etc.) se abre afuera; volver no tiene que pedir la clave de la app.
            markPendingSystemActivity();
            void Linking.openURL(pedido.url).catch(() => undefined);
            return false;
          }}
          onLoadEnd={() => setEstado((actual) => (actual === "cargando" ? "listo" : actual))}
          onError={() => setEstado("error")}
          onHttpError={() => setEstado("error")}
          onMessage={alMensaje}
        />
      ) : null}

      {estado === "cargando" ? (
        <View style={s.velo} pointerEvents="none">
          <ActivityIndicator color={P.doradoTexto} />
          <Text style={s.veloTexto}>Cargando el mapa…</Text>
        </View>
      ) : null}

      {estado === "error" ? (
        <View style={s.velo}>
          <Text style={s.veloTitulo}>No se pudo cargar el mapa</Text>
          <Text style={s.veloTexto}>Revisá que haya internet y probá de nuevo.</Text>
          <Pressable accessibilityRole="button" onPress={() => void cargar()} style={s.boton}>
            <Text style={s.botonTexto}>Reintentar</Text>
          </Pressable>
        </View>
      ) : null}

      {estado === "sin_vinculo" ? (
        <View style={s.velo}>
          <Text style={s.veloTitulo}>Falta vincular este teléfono</Text>
          <Text style={s.veloTexto}>Para ver el mapa con tu familia y tus equipos, vinculá este teléfono con Ojo Guard MS.</Text>
          <Pressable accessibilityRole="button" onPress={onVincular} style={s.boton}>
            <Text style={s.botonTexto}>Vincular ahora</Text>
          </Pressable>
        </View>
      ) : null}
    </View>
  );
}

function estilos(P: Paleta) {
  return StyleSheet.create({
    caja: { backgroundColor: P.fondo, borderColor: P.borde, borderRadius: 18, borderWidth: 1, flex: 1, overflow: "hidden" },
    web: { backgroundColor: P.fondo, flex: 1 },
    velo: { alignItems: "center", backgroundColor: P.superficieHonda, bottom: 0, gap: 10, justifyContent: "center", left: 0, padding: 24, position: "absolute", right: 0, top: 0 },
    veloTitulo: { color: P.texto, fontSize: 17, fontWeight: "800", textAlign: "center" },
    veloTexto: { color: P.textoSuave, fontSize: 14, lineHeight: 20, textAlign: "center" },
    boton: { backgroundColor: P.doradoFondo, borderColor: P.doradoBorde, borderRadius: 14, borderWidth: 1, marginTop: 6, paddingHorizontal: 20, paddingVertical: 12 },
    botonTexto: { color: P.doradoTexto, fontSize: 15, fontWeight: "800" },
  });
}
