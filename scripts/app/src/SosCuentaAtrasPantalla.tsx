import { useEffect, useState } from "react";
import { Modal, Pressable, StyleSheet, Text, View } from "react-native";

import { cancelarCuentaAtras, enviarAhora, escucharCuentaAtras, type EstadoCuentaAtras } from "./sosCuentaAtras";

/**
 * La pantalla de la cuenta regresiva del SOS que se pidió desde afuera de la app (atajo del iPhone). DISCRETA a propósito (Luciano, 18/11/2026: "si te están por
 * robar no está bueno ver algo muy llamativo"): pantalla casi negra, un número tenue y un «Cancelar» sobrio; no dice «SOS» ni «familia», sin rojo ni parpadeos.
 * Los lectores de pantalla sí leen el texto completo (para quien lo necesite). Se monta una sola vez, junto al botón SOS de la barra de abajo (SosEnBarra).
 * Si no se toca nada, el SOS sale solo.
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
        <Text style={s.marca}>Ojo Guard</Text>
        <Text accessibilityLabel={`Aviso a tu familia en ${cuenta.restante} segundos`} accessibilityLiveRegion="polite" style={s.numero}>
          {cuenta.restante}
        </Text>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="Cancelar el aviso a tu familia"
          onPress={() => {
            cancelarCuentaAtras();
          }}
          style={s.cancelar}
        >
          <Text style={s.cancelarTexto}>Cancelar</Text>
        </Pressable>
        <Pressable accessibilityRole="button" accessibilityLabel="Avisar a tu familia ya" onPress={enviarAhora} style={s.enviar}>
          <Text style={s.enviarTexto}>Ya</Text>
        </Pressable>
      </View>
    </Modal>
  );
}

const s = StyleSheet.create({
  fondo: { alignItems: "center", backgroundColor: "#050506", flex: 1, gap: 22, justifyContent: "center", padding: 24 },
  marca: { color: "#4a4c55", fontSize: 14, fontWeight: "600", letterSpacing: 1 },
  numero: { color: "#6b6e7a", fontSize: 56, fontWeight: "300", lineHeight: 64, textAlign: "center" },
  cancelar: { alignItems: "center", borderColor: "#3a3c45", borderRadius: 18, borderWidth: 1, minWidth: 220, paddingHorizontal: 28, paddingVertical: 16 },
  cancelarTexto: { color: "#8d909c", fontSize: 18, fontWeight: "500" },
  enviar: { padding: 12 },
  enviarTexto: { color: "#3f414a", fontSize: 14, fontWeight: "500" },
});
