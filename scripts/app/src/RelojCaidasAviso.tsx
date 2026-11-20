import { useState } from "react";
import { Pressable, Text, View } from "react-native";

/**
 * Tarjeta INFORMATIVA debajo de "Salud y emergencias": los relojes con detección de caídas. Es solo información: Ojo Guard NO se conecta
 * con ningún reloj, no guarda nada ni manda nada. No nombra precios ni tiendas (cambian y no queremos prometer nada que no controlamos).
 */

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
        onPress={() => setAbierta((v) => !v)}
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
