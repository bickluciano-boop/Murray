import { Pressable, Text, View } from "react-native";

/**
 * "Permisos de Android" como TARJETA (Ajustes → Configuración), en lugar de la franja verde. Misma función y mismos datos que la franja
 * (`BandaPermisos` de GruposConfiguracion.tsx, que se sigue usando tal cual en el Inicio): toca y abre el grupo de permisos, donde está el
 * estado y el detalle de cada uno. Acá solo cambia cómo se ve: ícono con el estado, título, una línea de detalle y la flecha.
 */

type Paleta = { [clave: string]: string };

type Props = {
  paleta: Paleta;
  android: boolean;
  permisosEnOrden: number | null;
  permisosTotal: number;
  onPress: () => void;
};

export function TarjetaPermisos({ paleta, android, permisosEnOrden, permisosTotal, onPress }: Props) {
  const completos = permisosEnOrden !== null && permisosEnOrden >= permisosTotal;
  const sinDato = !android || permisosEnOrden === null;
  const titulo = android ? "Permisos de Android" : "Permisos del iPhone";
  const detalle = !android
    ? "Toca para ver el estado y el detalle"
    : permisosEnOrden === null
      ? "Toca para revisarlos"
      : completos
        ? `Todo en orden · ${permisosEnOrden} de ${permisosTotal}`
        : `Faltan permisos · ${permisosEnOrden} de ${permisosTotal} · toca para arreglar`;
  const colores = sinDato
    ? { fondo: paleta.superficieHonda ?? "#FFFFFF", borde: paleta.borde ?? "#DFE4F0", acento: paleta.textoSuave ?? "#4A5578", marca: "…" }
    : completos
      ? { fondo: paleta.exitoFondo ?? "#E6F4EA", borde: paleta.exitoBorde ?? "#9CCBA8", acento: paleta.exito ?? "#1E7B34", marca: "✓" }
      : { fondo: paleta.doradoFondo ?? "#FFF4D6", borde: paleta.doradoBorde ?? "#E0B84A", acento: paleta.doradoTexto ?? "#7A5A00", marca: "!" };
  const texto = paleta.texto ?? "#14213D";
  return (
    <Pressable
      accessibilityHint="Abre el estado y el detalle de cada permiso"
      accessibilityLabel={`${titulo}. ${detalle}`}
      accessibilityRole="button"
      onPress={onPress}
      style={{
        alignItems: "center",
        alignSelf: "stretch",
        backgroundColor: colores.fondo,
        borderColor: colores.borde,
        borderRadius: 14,
        borderWidth: 1,
        flexDirection: "row",
        gap: 12,
        marginBottom: 8,
        paddingHorizontal: 12,
        paddingVertical: 10,
      }}
    >
      <View style={{ alignItems: "center", borderColor: colores.acento, borderRadius: 18, borderWidth: 2, height: 36, justifyContent: "center", width: 36 }}>
        <Text style={{ color: colores.acento, fontSize: 18, fontWeight: "900", lineHeight: 22 }}>{colores.marca}</Text>
      </View>
      <View style={{ flex: 1, gap: 1 }}>
        <Text style={{ color: texto, fontSize: 15, fontWeight: "800" }}>{titulo}</Text>
        <Text style={{ color: colores.acento, fontSize: 13, fontWeight: "600", lineHeight: 18 }}>{detalle}</Text>
      </View>
      <Text style={{ color: colores.acento, fontSize: 18 }}>›</Text>
    </Pressable>
  );
}
