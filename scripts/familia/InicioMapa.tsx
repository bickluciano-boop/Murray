import { type ReactNode } from "react";
import { StyleSheet, View, type StyleProp, type TextStyle, type ViewStyle } from "react-native";

import { CabezaInicio } from "./GruposConfiguracion";
import { MapaEnApp } from "./MapaEnApp";

/**
 * El Inicio de la app: lo que se usa con el teléfono en la mano. Arriba, chico y en el renglón de la ✕ y la ayuda (?), el nombre de este
 * teléfono y cómo está; y el resto de la pantalla, hasta la barra de abajo, es el mapa con los equipos y la familia (ver MapaEnApp.tsx).
 *
 * La barra de abajo (SOS, Inicio, Perfil, Ajustes y Panel) no es de esta pantalla: queda fija en todas (ver BarraInferior en
 * GruposConfiguracion.tsx). El SOS es el cuadradito rojo de esa barra (ver SosBlock.tsx); "Panel" abre Ojo Guard MS entrando directo.
 *
 * Lo que sirve cuando el teléfono ya no está en tus manos (Modo perdido, evidencia) se maneja desde el panel Ojo Guard MS.
 * Unirse con un código, pausar la ubicación y las ayudas del SOS están en Ajustes > Familia y amigos; las personas se ven y se suman
 * desde el mapa de acá.
 */

type Paleta = { [clave: string]: string };

type Props = {
  paleta: Paleta;
  tema: "claro" | "oscuro";
  nombre: string;
  enLinea: boolean | null;
  /** Cuando el teléfono no está vinculado: lleva a donde se vincula. */
  onVincular: () => void;
  /** La banda de permisos que faltan, si hace falta mostrarla. */
  banda?: ReactNode;
  /** Un aviso arriba del mapa (por ejemplo el diagnóstico de captura), si hace falta. */
  aviso?: ReactNode;
  /** Ya no se usa en el Inicio (el SOS pasó a la barra de abajo); se acepta para no cambiar App.tsx. */
  botones?: {
    secundario: StyleProp<ViewStyle>;
    secundarioTexto: StyleProp<TextStyle>;
    ayuda: StyleProp<TextStyle>;
  };
};

export function InicioMapa({ paleta: P, tema, nombre, enLinea, onVincular, banda, aviso }: Props) {
  const s = estilos();
  return (
    <View style={s.raiz}>
      <CabezaInicio paleta={P} nombre={nombre} enLinea={enLinea} />
      {banda}
      {aviso}
      <MapaEnApp paleta={P} tema={tema} onVincular={onVincular} />
    </View>
  );
}

function estilos() {
  return StyleSheet.create({
    raiz: { flex: 1, paddingBottom: 8, paddingHorizontal: 12 },
  });
}
