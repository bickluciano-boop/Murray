import { useCallback, useEffect, useState } from "react";
import { Pressable, Text, View } from "react-native";

import { RelojCaidasAviso } from "./RelojCaidasAviso";
import { TarjetaSaludPantalla } from "./TarjetaSaludPantalla";
import { cargarTarjeta, progresoCarga, tarjetaConDatos, textoSangre } from "./tarjetaSalud";

/**
 * La entrada a la TARJETA DE SALUD (ver TarjetaSaludPantalla.tsx), arriba de las tarjetas de Ajustes: "Salud y emergencias". Toca y se abre la tarjeta
 * a pantalla completa (se ve y se edita ahí). No cambia nada del resto de Ajustes ni del mapa: es un bloque aparte con su propio estado.
 */

type Paleta = { [clave: string]: string };

export function TarjetaSaludAjustes({ paleta }: { paleta: Paleta }) {
  const [abierta, setAbierta] = useState(false);
  const [detalle, setDetalle] = useState("Cargando…");
  const c = {
    superficie: paleta.superficieHonda ?? paleta.superficie ?? "#FFFFFF",
    borde: paleta.borde ?? "#DFE4F0",
    texto: paleta.texto ?? "#14213D",
    suave: paleta.textoSuave ?? "#4A5578",
  };

  const leer = useCallback(async () => {
    const t = await cargarTarjeta();
    if (!tarjetaConDatos(t)) {
      setDetalle("Todavía vacía. Carga tu grupo sanguíneo, alergias, medicamentos y obra social.");
      return;
    }
    const { llenos, total } = progresoCarga(t);
    const sangre = textoSangre(t);
    setDetalle(`Cargada: ${llenos} de ${total} datos${sangre ? ` · sangre ${sangre}` : ""}`);
  }, []);

  useEffect(() => {
    void leer();
  }, [leer]);

  return (
    <>
      <Pressable
        accessibilityHint="Abre tu tarjeta de salud con los datos que piden en una emergencia"
        accessibilityLabel="Salud y emergencias. Tu tarjeta de salud"
        accessibilityRole="button"
        onPress={() => setAbierta(true)}
        style={{
          alignItems: "center",
          backgroundColor: c.superficie,
          borderColor: c.borde,
          borderRadius: 20,
          borderWidth: 1,
          flexDirection: "row",
          gap: 14,
          marginBottom: 12,
          padding: 16,
        }}
      >
        <View style={{ alignItems: "center", backgroundColor: "#C0392B", borderRadius: 14, height: 52, justifyContent: "center", width: 52 }}>
          <View style={{ backgroundColor: "#FFFFFF", borderRadius: 2, height: 8, position: "absolute", width: 28 }} />
          <View style={{ backgroundColor: "#FFFFFF", borderRadius: 2, height: 28, position: "absolute", width: 8 }} />
        </View>
        <View style={{ flex: 1, gap: 2 }}>
          <Text style={{ color: c.texto, fontSize: 17, fontWeight: "900" }}>Salud y emergencias</Text>
          <Text style={{ color: c.suave, fontSize: 14, lineHeight: 20 }}>Tu tarjeta de salud: lo que te piden en una emergencia.</Text>
          <Text style={{ color: c.suave, fontSize: 13.5, fontWeight: "700", lineHeight: 19 }}>{detalle}</Text>
        </View>
        <Text style={{ color: c.suave, fontSize: 22 }}>›</Text>
      </Pressable>
      <RelojCaidasAviso paleta={paleta} />
      <TarjetaSaludPantalla
        onCerrar={() => {
          setAbierta(false);
          void leer();
        }}
        paleta={paleta}
        visible={abierta}
      />
    </>
  );
}
