import { useCallback, useEffect, useState } from "react";
import { AppState, Linking, Platform, Pressable, StyleSheet, Switch, Text, View } from "react-native";

import {
  activarProteccionReforzada,
  desactivarProteccionReforzada,
  proteccionReforzadaCorriendo,
  proteccionReforzadaPrendida,
} from "./proteccionReforzada";

/**
 * Tarjeta "Protección reforzada" (Configuración › Permisos de Android). Un interruptor que prende un servicio en primer plano para
 * que Android no duerma a Ojo Guard (ver proteccionReforzada.ts). Solo se ve en Android.
 */

type Estado = "cargando" | "apagada" | "prendida" | "sin_permiso" | "error";

export function ProteccionReforzadaTarjeta() {
  const [estado, setEstado] = useState<Estado>("cargando");
  const [trabajando, setTrabajando] = useState(false);

  const leer = useCallback(async () => {
    const prendida = await proteccionReforzadaPrendida();
    const corriendo = prendida ? await proteccionReforzadaCorriendo() : false;
    setEstado((anterior) => {
      if (!prendida) return anterior === "sin_permiso" ? anterior : "apagada";
      return corriendo ? "prendida" : "error";
    });
  }, []);

  useEffect(() => {
    void leer();
    // Si la persona vuelve de Ajustes (por ejemplo de dar el permiso de ubicación), se revisa de nuevo.
    const suscripcion = AppState.addEventListener("change", (siguiente) => {
      if (siguiente === "active") void leer();
    });
    return () => suscripcion.remove();
  }, [leer]);

  if (Platform.OS !== "android") return null;

  const prendida = estado === "prendida";

  const cambiar = async (quiere: boolean) => {
    if (trabajando) return;
    setTrabajando(true);
    try {
      if (!quiere) {
        await desactivarProteccionReforzada();
        setEstado("apagada");
        return;
      }
      const resultado = await activarProteccionReforzada();
      setEstado(resultado === "ok" ? "prendida" : resultado === "sin_permiso" ? "sin_permiso" : "error");
    } finally {
      setTrabajando(false);
    }
  };

  return (
    <View style={estilos.caja}>
      <View style={estilos.fila}>
        <View style={estilos.textos}>
          <Text style={estilos.titulo}>Mantener Ojo Guard despierto</Text>
          <Text style={estilos.ayuda}>
            Evita que Android duerma la app cuando el teléfono pasa horas quieto, para que el Modo Perdido, la alarma y la evidencia pedidos
            desde el panel lleguen al instante. Muestra una notificación fija y gasta un poco más de batería.
          </Text>
        </View>
        <Switch
          accessibilityLabel="Protección reforzada"
          disabled={trabajando || estado === "cargando"}
          onValueChange={(valor) => void cambiar(valor)}
          trackColor={{ false: "#c9cfdd", true: "#D9B24C" }}
          thumbColor={prendida ? "#ffffff" : "#f4f5f8"}
          value={prendida}
        />
      </View>
      {estado === "prendida" ? <Text style={estilos.ok}>Activa en este teléfono.</Text> : null}
      {estado === "sin_permiso" ? (
        <View style={estilos.aviso}>
          <Text style={estilos.ayuda}>
            Falta el permiso de ubicación «Permitir todo el tiempo». Ábrelo en Ajustes › Permisos › Ubicación, vuelve y prende el interruptor.
          </Text>
          <Pressable accessibilityRole="button" onPress={() => void Linking.openSettings()} style={estilos.boton}>
            <Text style={estilos.botonTexto}>Abrir los ajustes de la app</Text>
          </Pressable>
        </View>
      ) : null}
      {estado === "error" ? (
        <Text style={estilos.ayuda}>
          No se pudo dejar activa. Abre la app, toca el interruptor de nuevo y, si sigue igual, avísanos.
        </Text>
      ) : null}
    </View>
  );
}

const estilos = StyleSheet.create({
  caja: { gap: 10 },
  fila: { alignItems: "center", flexDirection: "row", gap: 12 },
  textos: { flex: 1, gap: 4 },
  titulo: { color: "#14213d", fontSize: 15, fontWeight: "700" },
  ayuda: { color: "#4a5578", fontSize: 13.5, lineHeight: 19 },
  ok: { color: "#1f6b3a", fontSize: 13.5, fontWeight: "700" },
  aviso: { gap: 8 },
  boton: { alignSelf: "flex-start", borderColor: "#c9cfdd", borderRadius: 12, borderWidth: 1, paddingHorizontal: 12, paddingVertical: 8 },
  botonTexto: { color: "#14213d", fontSize: 13.5, fontWeight: "700" },
});
