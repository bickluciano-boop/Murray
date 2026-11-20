import { useCallback, useEffect, useState } from "react";
import { Pressable, Text, View } from "react-native";

import { RelojCaidasAviso } from "./RelojCaidasAviso";
import { TarjetaSaludPantalla } from "./TarjetaSaludPantalla";
import { cargarTarjeta, progresoCarga, tarjetaConDatos, textoSangre } from "./tarjetaSalud";

/**
 * La entrada a la TARJETA DE SALUD (ver TarjetaSaludPantalla.tsx), arriba de las tarjetas de Ajustes: "Salud y emergencias". Toca y se abre la tarjeta
 * a pantalla completa (se ve y se edita ahí). No cambia nada del resto de Ajustes ni del mapa: es un bloque aparte con su propio estado.
 * Tarjetas compactas (20/11/2026): más chica y delicada, una línea de título y una de detalle.
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
      setDetalle("Todavía vacía · toca para cargarla");
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
          alignSelf: "stretch",
          backgroundColor: c.superficie,
          borderColor: c.borde,
          borderRadius: 14,
          borderWidth: 1,
          flexDirection: "row",
          gap: 12,
          marginBottom: 8,
          paddingHorizontal: 12,
          paddingVertical: 10,
        }}
      >
        <View style={{ alignItems: "center", backgroundColor: "#C0392B", borderRadius: 10, height: 36, justifyContent: "center", width: 36 }}>
          <View style={{ backgroundColor: "#FFFFFF", borderRadius: 1.5, height: 5, position: "absolute", width: 18 }} />
          <View style={{ backgroundColor: "#FFFFFF", borderRadius: 1.5, height: 18, position: "absolute", width: 5 }} />
        </View>
        <View style={{ flex: 1, gap: 1 }}>
          <Text style={{ color: c.texto, fontSize: 15, fontWeight: "800" }}>Salud y emergencias</Text>
          <Text style={{ color: c.suave, fontSize: 13, lineHeight: 18 }}>{detalle}</Text>
        </View>
        <Text style={{ color: c.suave, fontSize: 18 }}>›</Text>
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
