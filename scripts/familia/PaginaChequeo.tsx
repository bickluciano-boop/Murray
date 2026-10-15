import { useEffect, useState, type ComponentProps } from "react";
import { Text } from "react-native";

import { ProteccionBlock } from "./ProteccionBlock";
import { loadNativeEnrollment, type NativeEnrollment } from "./remoteStorage";

/**
 * La página del Dr. Ojo Guard dentro de Configuración. El chequeo necesita saber con qué familia está vinculado este teléfono, así
 * que lo busca acá (antes lo traía la sección de Familia). Sin vínculo no hay nada que revisar: lo dice.
 */

type Props = {
  paleta: ComponentProps<typeof ProteccionBlock>["paleta"];
  botones: ComponentProps<typeof ProteccionBlock>["botones"];
};

export function PaginaChequeo({ paleta, botones }: Props) {
  const [enrollment, setEnrollment] = useState<NativeEnrollment | null | undefined>(undefined);
  useEffect(() => {
    void loadNativeEnrollment().then(setEnrollment).catch(() => setEnrollment(null));
  }, []);
  if (enrollment === null) {
    return <Text style={botones.ayuda}>Vinculá este teléfono con Ojo Guard MS para usar el chequeo del Dr. Ojo Guard.</Text>;
  }
  return <ProteccionBlock abierto enrollment={enrollment} paleta={paleta} botones={botones} visible />;
}
