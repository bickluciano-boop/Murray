import { useEffect, useState } from "react";
import { Modal, Pressable, StyleSheet, Text, View } from "react-native";

import { cancelarCuentaAtras, enviarAhora, escucharCuentaAtras, type EstadoCuentaAtras } from "./sosCuentaAtras";

/**
 * La pantalla de la cuenta regresiva del SOS que se pidió desde afuera de la app (atajo del iPhone). Pantalla completa, número grande y un botón
 * enorme para cancelar. Se monta una sola vez, junto al botón SOS de la barra de abajo (SosEnBarra). Si no se toca nada, el SOS sale solo.
 */
export function SosCuentaAtras() {
  const [cuenta, setCuenta] = useState<EstadoCuentaAtras>({ activa: false, restante: 0 });
  useEffect(() => escucharCuentaAtras(setCuenta), []);

  return (
    <Modal
      visible={cuenta.activa}
      transparent
      animationType="fade"
      statusBarTranslucent
      onRequestClose={() => {
        cancelarCuentaAtras();
      }}
    >
      <View style={s.fondo}>
        <Text accessibilityRole="header" style={s.titulo}>
          Enviando SOS a tu familia
        </Text>
        <Text accessibilityLiveRegion="polite" style={s.numero}>
          {cuenta.restante}
        </Text>
        <Text style={s.texto}>Si fue sin querer, toca Cancelar. Si es una emergencia no hagas nada: el SOS sale solo.</Text>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="Cancelar el SOS"
          onPress={() => {
            cancelarCuentaAtras();
          }}
          style={s.cancelar}
        >
          <Text style={s.cancelarTexto}>Cancelar</Text>
        </Pressable>
        <Pressable accessibilityRole="button" accessibilityLabel="Enviar el SOS ya" onPress={enviarAhora} style={s.enviar}>
          <Text style={s.enviarTexto}>Enviar ya</Text>
        </Pressable>
      </View>
    </Modal>
  );
}

const s = StyleSheet.create({
  fondo: { alignItems: "center", backgroundColor: "rgba(8,8,10,0.96)", flex: 1, gap: 18, justifyContent: "center", padding: 24 },
  titulo: { color: "#ffffff", fontSize: 24, fontWeight: "800", textAlign: "center" },
  numero: { color: "#ff6b5e", fontSize: 120, fontWeight: "900", lineHeight: 130, textAlign: "center" },
  texto: { color: "#d5d7e0", fontSize: 16, lineHeight: 23, maxWidth: 420, textAlign: "center" },
  cancelar: { alignItems: "center", alignSelf: "stretch", backgroundColor: "#ffffff", borderRadius: 20, maxWidth: 420, paddingVertical: 22 },
  cancelarTexto: { color: "#111111", fontSize: 24, fontWeight: "800" },
  enviar: { padding: 14 },
  enviarTexto: { color: "#ffb4a8", fontSize: 17, fontWeight: "800", textDecorationLine: "underline" },
});
