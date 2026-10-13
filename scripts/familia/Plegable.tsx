import { useState, type ReactNode } from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";

/**
 * Renglón que se abre y se cierra con un toque (▸ cerrado, ▾ abierto). Lo usan "Mi protección" y el SOS para que lo largo
 * (instrucciones, detalle de la revisión) quede escondido hasta que la persona lo pide y Configuración no sea una tira
 * interminable. `abiertoInicial` solo vale al armarse: para reabrirlo desde afuera, cambiarle la `key`.
 */

type Paleta = { [clave: string]: string };

type Props = {
  titulo: string;
  paleta: Paleta;
  abiertoInicial?: boolean;
  children: ReactNode;
};

export function Plegable({ titulo, paleta: P, abiertoInicial = false, children }: Props) {
  const [abierto, setAbierto] = useState(abiertoInicial);
  const s = estilos(P);
  return (
    <View style={s.caja}>
      <Pressable accessibilityRole="button" accessibilityState={{ expanded: abierto }} onPress={() => setAbierto((valor) => !valor)} style={s.cabecera}>
        <Text style={s.titulo}>{titulo}</Text>
        <Text style={s.flecha}>{abierto ? "▾" : "▸"}</Text>
      </Pressable>
      {abierto ? <View style={s.cuerpo}>{children}</View> : null}
    </View>
  );
}

function estilos(P: Paleta) {
  return StyleSheet.create({
    caja: { marginTop: 14, borderTopWidth: 1, borderTopColor: P.borde },
    cabecera: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", paddingVertical: 12 },
    titulo: { flex: 1, color: P.textoSuave, fontSize: 13, fontWeight: "600" },
    flecha: { color: P.textoSuave, fontSize: 14, marginLeft: 10 },
    cuerpo: { paddingBottom: 4 },
  });
}
