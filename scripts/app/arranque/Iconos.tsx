import { View } from "react-native";

// Iconos dibujados con vistas simples (sin librerias nuevas), para que la
// bienvenida y el arranque no dependan de ningun paquete que haya que
// instalar en la build.

export type NombreIcono =
  | "tel"
  | "pc"
  | "reloj"
  | "cam"
  | "mic"
  | "pin"
  | "campana"
  | "casa"
  | "candado"
  | "mochila"
  | "check"
  | "correo"
  | "persona";

export function Icono({ nombre, color, tam = 28 }: { nombre: NombreIcono; color: string; tam?: number }) {
  const t = tam;
  const g = Math.max(2, Math.round(t / 13));
  const caja = { width: t, height: t, alignItems: "center", justifyContent: "center" } as const;

  if (nombre === "tel") {
    return (
      <View style={caja}>
        <View style={{ width: t * 0.5, height: t * 0.86, borderRadius: t * 0.13, borderWidth: g, borderColor: color, alignItems: "center", justifyContent: "flex-end", paddingBottom: t * 0.07 }}>
          <View style={{ width: t * 0.16, height: g, borderRadius: g, backgroundColor: color }} />
        </View>
      </View>
    );
  }
  if (nombre === "pc") {
    return (
      <View style={caja}>
        <View style={{ width: t * 0.86, height: t * 0.56, borderRadius: t * 0.07, borderWidth: g, borderColor: color }} />
        <View style={{ width: t * 0.98, height: g, borderRadius: g, backgroundColor: color, marginTop: t * 0.07 }} />
      </View>
    );
  }
  if (nombre === "reloj") {
    return (
      <View style={caja}>
        <View style={{ width: t * 0.3, height: t * 0.16, backgroundColor: color, opacity: 0.55, borderTopLeftRadius: g, borderTopRightRadius: g }} />
        <View style={{ width: t * 0.54, height: t * 0.58, borderRadius: t * 0.17, borderWidth: g, borderColor: color }} />
        <View style={{ width: t * 0.3, height: t * 0.16, backgroundColor: color, opacity: 0.55, borderBottomLeftRadius: g, borderBottomRightRadius: g }} />
      </View>
    );
  }
  if (nombre === "cam") {
    return (
      <View style={caja}>
        <View style={{ width: t * 0.88, height: t * 0.6, borderRadius: t * 0.14, borderWidth: g, borderColor: color, alignItems: "center", justifyContent: "center" }}>
          <View style={{ width: t * 0.3, height: t * 0.3, borderRadius: t * 0.15, borderWidth: g, borderColor: color }} />
        </View>
      </View>
    );
  }
  if (nombre === "mic") {
    return (
      <View style={caja}>
        <View style={{ width: t * 0.28, height: t * 0.46, borderRadius: t * 0.14, borderWidth: g, borderColor: color }} />
        <View style={{ width: t * 0.5, height: t * 0.22, borderBottomLeftRadius: t * 0.25, borderBottomRightRadius: t * 0.25, borderWidth: g, borderTopWidth: 0, borderColor: color, marginTop: t * 0.04 }} />
        <View style={{ width: g, height: t * 0.1, backgroundColor: color }} />
      </View>
    );
  }
  if (nombre === "pin") {
    return (
      <View style={caja}>
        <View style={{ width: t * 0.5, height: t * 0.5, borderRadius: t * 0.25, borderWidth: g, borderColor: color, alignItems: "center", justifyContent: "center" }}>
          <View style={{ width: t * 0.16, height: t * 0.16, borderRadius: t * 0.08, backgroundColor: color }} />
        </View>
        <View style={{ width: g, height: t * 0.26, backgroundColor: color, marginTop: -g }} />
      </View>
    );
  }
  if (nombre === "campana") {
    return (
      <View style={caja}>
        <View style={{ width: t * 0.58, height: t * 0.52, borderTopLeftRadius: t * 0.29, borderTopRightRadius: t * 0.29, borderWidth: g, borderBottomWidth: 0, borderColor: color }} />
        <View style={{ width: t * 0.8, height: g, borderRadius: g, backgroundColor: color }} />
        <View style={{ width: t * 0.16, height: t * 0.16, borderRadius: t * 0.08, backgroundColor: color, marginTop: g }} />
      </View>
    );
  }
  if (nombre === "casa") {
    return (
      <View style={caja}>
        <View style={{ width: 0, height: 0, borderLeftWidth: t * 0.46, borderRightWidth: t * 0.46, borderBottomWidth: t * 0.34, borderLeftColor: "transparent", borderRightColor: "transparent", borderBottomColor: color }} />
        <View style={{ width: t * 0.62, height: t * 0.4, borderWidth: g, borderTopWidth: 0, borderColor: color, alignItems: "center", justifyContent: "flex-end" }}>
          <View style={{ width: t * 0.18, height: t * 0.24, borderTopLeftRadius: g, borderTopRightRadius: g, borderWidth: g, borderBottomWidth: 0, borderColor: color }} />
        </View>
      </View>
    );
  }
  if (nombre === "candado") {
    return (
      <View style={caja}>
        <View style={{ width: t * 0.4, height: t * 0.3, borderTopLeftRadius: t * 0.2, borderTopRightRadius: t * 0.2, borderWidth: g, borderBottomWidth: 0, borderColor: color }} />
        <View style={{ width: t * 0.64, height: t * 0.42, borderRadius: t * 0.1, backgroundColor: color, alignItems: "center", justifyContent: "center" }}>
          <View style={{ width: g * 1.6, height: g * 3, borderRadius: g, backgroundColor: "#fff", opacity: 0.85 }} />
        </View>
      </View>
    );
  }
  if (nombre === "mochila") {
    return (
      <View style={caja}>
        <View style={{ width: t * 0.3, height: t * 0.14, borderTopLeftRadius: t * 0.15, borderTopRightRadius: t * 0.15, borderWidth: g, borderBottomWidth: 0, borderColor: color }} />
        <View style={{ width: t * 0.64, height: t * 0.62, borderRadius: t * 0.2, borderWidth: g, borderColor: color, alignItems: "center", justifyContent: "flex-end", paddingBottom: t * 0.08 }}>
          <View style={{ width: t * 0.34, height: t * 0.2, borderRadius: t * 0.06, borderWidth: g, borderColor: color }} />
        </View>
      </View>
    );
  }
  if (nombre === "check") {
    return (
      <View style={caja}>
        <View style={{ width: t * 0.5, height: t * 0.28, borderLeftWidth: g * 1.4, borderBottomWidth: g * 1.4, borderColor: color, transform: [{ rotate: "-45deg" }, { translateY: -t * 0.05 }] }} />
      </View>
    );
  }
  if (nombre === "correo") {
    return (
      <View style={caja}>
        <View style={{ width: t * 0.88, height: t * 0.62, borderRadius: t * 0.1, borderWidth: g, borderColor: color, overflow: "hidden", alignItems: "center" }}>
          <View style={{ width: t * 0.5, height: t * 0.5, borderRightWidth: g, borderBottomWidth: g, borderColor: color, transform: [{ rotate: "45deg" }, { translateY: -t * 0.28 }, { translateX: -t * 0.0 }] }} />
        </View>
      </View>
    );
  }
  // persona
  return (
    <View style={caja}>
      <View style={{ width: t * 0.3, height: t * 0.3, borderRadius: t * 0.15, borderWidth: g, borderColor: color }} />
      <View style={{ width: t * 0.66, height: t * 0.32, borderTopLeftRadius: t * 0.33, borderTopRightRadius: t * 0.33, borderWidth: g, borderBottomWidth: 0, borderColor: color, marginTop: t * 0.06 }} />
    </View>
  );
}
