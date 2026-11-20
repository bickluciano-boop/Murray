import { useState } from "react";
import { Pressable, Text, View } from "react-native";
import { WebView } from "react-native-webview";

/**
 * Tarjeta INFORMATIVA debajo de "Salud y emergencias": los relojes con detección de caídas. Es solo información: Ojo Guard NO se conecta
 * con ningún reloj, no guarda nada ni manda nada. No nombra precios ni tiendas (cambian y no queremos prometer nada que no controlamos).
 * Adentro, "Ver presentación": el mismo video de la presentación de las pulseras de la consola, SIEMPRE SIN SONIDO (a Luciano no le gusta la música),
 * dentro de la tarjeta con la librería de webview que la app ya tiene. Solo se descarga cuando la persona toca "Ver presentación".
 */

export const VIDEO_PRESENTACION_URL = "https://watch.ojoguard.app/ojo-guard-presentacion.mp4?v=3";

/** La página que muestra el video: sin botón de volumen y, si de todos modos se activa el sonido, se vuelve a silenciar sola. */
export function htmlDelVideo(url: string = VIDEO_PRESENTACION_URL): string {
  return (
    '<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">' +
    "<style>html,body{margin:0;height:100%;background:#000}video{width:100%;height:100%;object-fit:contain;background:#000}" +
    "video::-webkit-media-controls-mute-button,video::-webkit-media-controls-volume-slider,video::-webkit-media-controls-volume-control-container{display:none!important}</style></head><body>" +
    `<video id="v" src="${url}" playsinline controls muted preload="metadata"></video>` +
    '<script>var v=document.getElementById("v");v.muted=true;v.onvolumechange=function(){if(!v.muted)v.muted=true};' +
    'v.onerror=function(){document.title="error"};</script></body></html>'
  );
}

type Paleta = { [clave: string]: string };

const PUNTOS: { titulo: string; texto: string }[] = [
  {
    titulo: "Qué hace",
    texto:
      "Si el reloj siente una caída fuerte y no te mueves, te pregunta si estás bien. Si no respondes, puede llamar a emergencias y avisar a tus contactos de emergencia.",
  },
  {
    titulo: "Qué tener en cuenta",
    texto:
      "Tiene que estar puesto, con batería y activada la función. No detecta todas las caídas y a veces avisa sin que haya pasado nada. Apple Watch funciona con iPhone y Galaxy Watch con teléfonos Android.",
  },
  {
    titulo: "Cómo elegir uno",
    texto: "En la ficha del modelo fíjate que diga \"detección de caídas\". Los modelos viejos o muy económicos muchas veces no la traen.",
  },
  {
    titulo: "Y Ojo Guard",
    texto: "Todavía no se conecta con los relojes. Es un complemento: no reemplaza ni cambia nada de lo que hace Ojo Guard.",
  },
];

export function RelojCaidasAviso({ paleta }: { paleta: Paleta }) {
  const [abierta, setAbierta] = useState(false);
  const [verVideo, setVerVideo] = useState(false);
  const [falloVideo, setFalloVideo] = useState(false);
  const c = {
    superficie: paleta.superficieHonda ?? paleta.superficie ?? "#FFFFFF",
    borde: paleta.borde ?? "#DFE4F0",
    texto: paleta.texto ?? "#14213D",
    suave: paleta.textoSuave ?? "#4A5578",
  };

  return (
    <View
      style={{
        backgroundColor: c.superficie,
        borderColor: c.borde,
        borderRadius: 14,
        borderWidth: 1,
        marginBottom: 8,
        overflow: "hidden",
      }}
    >
      <Pressable
        accessibilityHint={abierta ? "Cierra la información" : "Muestra la información"}
        accessibilityLabel="Reloj con detección de caídas"
        accessibilityRole="button"
        accessibilityState={{ expanded: abierta }}
        onPress={() => {
          setAbierta((v) => !v);
          setVerVideo(false);
          setFalloVideo(false);
        }}
        style={{ alignItems: "center", flexDirection: "row", gap: 12, paddingHorizontal: 12, paddingVertical: 10 }}
      >
        <View style={{ alignItems: "center", backgroundColor: "#2F6FED", borderRadius: 10, height: 36, justifyContent: "center", width: 36 }}>
          <View style={{ borderColor: "#FFFFFF", borderRadius: 6, borderWidth: 2, height: 18, width: 15 }} />
          <View style={{ backgroundColor: "#FFFFFF", borderRadius: 1.5, height: 2, position: "absolute", top: 5, width: 7 }} />
          <View style={{ backgroundColor: "#FFFFFF", borderRadius: 1.5, bottom: 5, height: 2, position: "absolute", width: 7 }} />
        </View>
        <View style={{ flex: 1, gap: 1 }}>
          <Text style={{ color: c.texto, fontSize: 15, fontWeight: "800" }}>Reloj con detección de caídas</Text>
          <Text style={{ color: c.suave, fontSize: 13, lineHeight: 18 }}>Un complemento por si te caes</Text>
        </View>
        <Text style={{ color: c.suave, fontSize: 18, transform: [{ rotate: abierta ? "90deg" : "0deg" }] }}>›</Text>
      </Pressable>
      {abierta ? (
        <View style={{ borderColor: c.borde, borderTopWidth: 1, gap: 12, paddingHorizontal: 16, paddingVertical: 14 }}>
          {/* Ver presentación arriba (20/11/2026): el botón va ANTES de los textos para que se encuentre sin bajar. */}
          {verVideo ? (
            <View style={{ gap: 8 }}>
              <View style={{ aspectRatio: 16 / 9, backgroundColor: "#000000", borderRadius: 10, overflow: "hidden", width: "100%" }}>
                <WebView
                  allowsInlineMediaPlayback
                  javaScriptEnabled
                  onError={() => setFalloVideo(true)}
                  onHttpError={() => setFalloVideo(true)}
                  originWhitelist={["*"]}
                  source={{ baseUrl: "https://watch.ojoguard.app", html: htmlDelVideo() }}
                  style={{ backgroundColor: "#000000", flex: 1 }}
                />
              </View>
              <Text style={{ color: c.suave, fontSize: 12.5, lineHeight: 17 }}>
                {falloVideo ? "No se pudo cargar el video. Revisa tu conexión a internet e inténtalo de nuevo." : "Sin sonido. El video se carga por internet."}
              </Text>
              <Pressable
                accessibilityRole="button"
                onPress={() => {
                  setVerVideo(false);
                  setFalloVideo(false);
                }}
                style={{ alignSelf: "flex-start", paddingVertical: 6 }}
              >
                <Text style={{ color: c.texto, fontSize: 14, fontWeight: "800" }}>Cerrar video</Text>
              </Pressable>
            </View>
          ) : (
            <Pressable
              accessibilityLabel="Ver presentación del reloj, sin sonido"
              accessibilityRole="button"
              onPress={() => {
                setFalloVideo(false);
                setVerVideo(true);
              }}
              style={{ alignItems: "center", backgroundColor: c.texto, borderRadius: 12, paddingVertical: 11 }}
            >
              <Text style={{ color: c.superficie, fontSize: 14.5, fontWeight: "800" }}>Ver presentación</Text>
            </Pressable>
          )}
          {PUNTOS.map((p) => (
            <View key={p.titulo} style={{ gap: 2 }}>
              <Text style={{ color: c.texto, fontSize: 14.5, fontWeight: "800" }}>{p.titulo}</Text>
              <Text style={{ color: c.suave, fontSize: 14, lineHeight: 20 }}>{p.texto}</Text>
            </View>
          ))}
        </View>
      ) : null}
    </View>
  );
}
