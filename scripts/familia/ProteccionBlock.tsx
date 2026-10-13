import { useCallback, useEffect, useRef, useState } from "react";
import { ActivityIndicator, AppState, Linking, Platform, Pressable, StyleSheet, Text, View, type StyleProp, type TextStyle, type ViewStyle } from "react-native";

import { openBatterySettings } from "../modules/exact-alarm";
import { openSosAccessibilitySettings, openSosChannelSettings } from "../modules/sos-trigger";
import { markPendingSystemActivity } from "./pendingSystemActivity";
import { Plegable } from "./Plegable";
import { revisarProteccion, type Arreglo, type EstadoItem, type ResultadoProteccion } from "./proteccion";
import type { NativeEnrollment } from "./remoteStorage";
import { probarSirena } from "./sosTask";

/**
 * "Dr. Ojo Guard" dentro de "Familia y amigos", justo arriba del SOS: un título que se despliega (cerrado, muestra el último
 * porcentaje) con el botón "Hacer chequeo". Mira qué está prendido y qué no (ver proteccion.ts), muestra un porcentaje y, en cada
 * cosa que falta, un botón que lleva a la pantalla del sistema donde se arregla. Si la persona vuelve de Ajustes, se chequea sola
 * de nuevo para que el porcentaje suba al momento. En Android además tiene "Probar la sirena": hace sonar una alarma de prueba por
 * el mismo canal del SOS, para comprobar de verdad que se oye.
 */

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

const TEXTO_ARREGLO: Record<Arreglo, string> = {
  ajustes: "Abrir los ajustes de la app",
  gesto: "Abrir Accesibilidad",
  canal: "Abrir el canal de la sirena",
  bateria: "Abrir la batería",
  bluetooth: "Abrir el Bluetooth",
};

const MARCA: Record<EstadoItem, string> = { ok: "✓", revisar: "!", falta: "✕" };

function dosDigitos(n: number) {
  return String(n).padStart(2, "0");
}

export function ProteccionBlock({ enrollment, visible, paleta: P, botones }: Props) {
  const [resultado, setResultado] = useState<ResultadoProteccion | null>(null);
  const [revisando, setRevisando] = useState(false);
  const [avisoSirena, setAvisoSirena] = useState("");
  const yaRevisado = useRef(false);

  const revisar = useCallback(async () => {
    if (!enrollment) return;
    setRevisando(true);
    try {
      setResultado(await revisarProteccion(enrollment));
      yaRevisado.current = true;
    } finally {
      setRevisando(false);
    }
  }, [enrollment]);

  // Al volver de Ajustes (donde se arregla casi todo) se revisa de nuevo, solo si la persona ya había tocado el botón.
  useEffect(() => {
    const suscripcion = AppState.addEventListener("change", (estado) => {
      if (estado === "active" && yaRevisado.current) void revisar();
    });
    return () => suscripcion.remove();
  }, [revisar]);

  function arreglar(arreglo: Arreglo) {
    // Volver de Ajustes no tiene que mandar la app a la pantalla de bloqueo.
    markPendingSystemActivity();
    if (arreglo === "gesto") openSosAccessibilitySettings();
    else if (arreglo === "canal") openSosChannelSettings();
    else if (arreglo === "bateria") openBatterySettings();
    else if (arreglo === "bluetooth") void Linking.sendIntent("android.settings.BLUETOOTH_SETTINGS").catch(() => Linking.openSettings());
    else void Linking.openSettings();
  }

  async function sirena() {
    setAvisoSirena((await probarSirena()) ? "Mandé una alarma de prueba. Si no la oís, revisá el volumen de alarma y que no tengas auriculares Bluetooth conectados." : "No pude mandar la prueba. Revisá que las notificaciones estén permitidas.");
  }

  if (!visible || !enrollment) return null;
  const s = estilos(P);
  const color = (estado: EstadoItem) => (estado === "ok" ? P.exito : estado === "revisar" ? P.doradoTexto : P.peligroFuerte);
  const fondo = (estado: EstadoItem) => (estado === "ok" ? P.exitoFondo : estado === "revisar" ? P.doradoFondo : P.peligroFondo);
  const borde = (estado: EstadoItem) => (estado === "ok" ? P.exitoBorde : estado === "revisar" ? P.doradoBorde : P.peligroBorde);
  const general: EstadoItem = !resultado ? "ok" : resultado.porcentaje >= 100 ? "ok" : resultado.porcentaje >= 60 ? "revisar" : "falta";

  return (
    <Plegable titulo={resultado ? `Dr. Ojo Guard · ${resultado.porcentaje} %` : "Dr. Ojo Guard"} paleta={P}>
      {resultado ? (
        <>
          <View style={[s.resumen, { borderColor: borde(general), backgroundColor: fondo(general) }]}>
            <Text style={[s.porcentaje, { color: color(general) }]}>{resultado.porcentaje} %</Text>
            <View style={s.barra}>
              <View style={[s.barraRelleno, { width: `${resultado.porcentaje}%`, backgroundColor: color(general) }]} />
            </View>
            <Text style={s.resumenTexto}>
              {resultado.porcentaje >= 100
                ? "Todo en orden: no encontré nada que arreglar."
                : "Hay cosas para arreglar. Tocá el botón de cada una."}
            </Text>
          </View>
          <Plegable key={resultado.porcentaje >= 100 ? "detalle-ok" : "detalle-falta"} titulo="Ver el detalle" paleta={P} abiertoInicial={resultado.porcentaje < 100}>
            {resultado.items.map((item) => (
              <View key={item.id} style={s.item}>
                <View style={[s.marca, { borderColor: borde(item.estado), backgroundColor: fondo(item.estado) }]}>
                  <Text style={[s.marcaTexto, { color: color(item.estado) }]}>{MARCA[item.estado]}</Text>
                </View>
                <View style={s.itemCuerpo}>
                  <Text style={s.itemTitulo}>{item.titulo}</Text>
                  <Text style={s.itemDetalle}>{item.detalle}</Text>
                  {item.estado !== "ok" && item.arreglo ? (
                    <Pressable accessibilityRole="button" onPress={() => arreglar(item.arreglo as Arreglo)} style={[botones.secundario, s.arreglo]}>
                      <Text style={botones.secundarioTexto}>{TEXTO_ARREGLO[item.arreglo]}</Text>
                    </Pressable>
                  ) : null}
                </View>
              </View>
            ))}
            {resultado.notas.map((nota) => (
              <Text key={nota} style={[botones.ayuda, s.nota]}>
                {nota}
              </Text>
            ))}
            <Text style={[botones.ayuda, s.nota]}>
              Chequeo hecho a las {dosDigitos(resultado.revisadoEn.getHours())}:{dosDigitos(resultado.revisadoEn.getMinutes())}. Este chequeo mira lo que el teléfono permite
              mirar: igual conviene probar el SOS de vez en cuando.
            </Text>
          </Plegable>
        </>
      ) : (
        <Text style={botones.ayuda}>
          El Dr. Ojo Guard revisa que el SOS, los avisos y la ubicación estén listos en este teléfono. Si algo falla, te dice qué tocar.
        </Text>
      )}
      <Pressable accessibilityRole="button" disabled={revisando} onPress={() => void revisar()} style={[botones.secundario, s.espacio, revisando && s.apagado]}>
        {revisando ? <ActivityIndicator color={P.texto} /> : <Text style={botones.secundarioTexto}>{resultado ? "Volver a hacer el chequeo" : "Hacer chequeo"}</Text>}
      </Pressable>
      {Platform.OS === "android" ? (
        <>
          <Pressable accessibilityRole="button" onPress={() => void sirena()} style={botones.secundario}>
            <Text style={botones.secundarioTexto}>Probar la sirena</Text>
          </Pressable>
          {avisoSirena ? <Text style={botones.ayuda}>{avisoSirena}</Text> : null}
        </>
      ) : null}
    </Plegable>
  );
}

function estilos(P: Paleta) {
  return StyleSheet.create({
    espacio: { marginTop: 12 },
    apagado: { opacity: 0.5 },
    resumen: { padding: 14, borderRadius: 14, borderWidth: 1 },
    porcentaje: { fontSize: 30, fontWeight: "800" },
    barra: { height: 8, borderRadius: 4, backgroundColor: P.borde, overflow: "hidden", marginTop: 8 },
    barraRelleno: { height: 8, borderRadius: 4 },
    resumenTexto: { color: P.texto, fontSize: 13, lineHeight: 18, marginTop: 8 },
    item: { flexDirection: "row", gap: 10, marginTop: 14 },
    marca: { width: 26, height: 26, borderRadius: 13, borderWidth: 1, alignItems: "center", justifyContent: "center", marginTop: 1 },
    marcaTexto: { fontSize: 14, fontWeight: "800" },
    itemCuerpo: { flex: 1 },
    itemTitulo: { color: P.texto, fontSize: 14, fontWeight: "700" },
    itemDetalle: { color: P.textoClaro, fontSize: 13, lineHeight: 18, marginTop: 2 },
    arreglo: { marginTop: 8 },
    nota: { marginTop: 12 },
  });
}
