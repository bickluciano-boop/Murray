import { useEffect, useState, type ReactNode } from "react";
import { AppState, StyleSheet, View, type StyleProp, type TextStyle, type ViewStyle } from "react-native";

import { BotonesInicioMapa, CabezaInicio } from "./GruposConfiguracion";
import { MapaEnApp } from "./MapaEnApp";
import { fetchFamily } from "./remoteApi";
import { loadNativeEnrollment, type NativeEnrollment } from "./remoteStorage";
import { SosBlock } from "./SosBlock";

/**
 * El Inicio de la app: lo que se usa con el teléfono en la mano. Arriba una línea con este teléfono y tres botones (Mi perfil, Familia
 * y Configuración); en el medio, ocupando casi toda la pantalla, el mapa con los equipos y la familia (ver MapaEnApp.tsx); y abajo,
 * siempre a mano pero chico, el botón de SOS.
 *
 * Entrar al panel Ojo Guard MS está a un toque, arriba a la derecha ("Abrir panel"): pide el acceso directo y abre el navegador con la
 * sesión iniciada, sin pasar por Configuración ni por la pantalla de sincronización.
 *
 * Lo que sirve cuando el teléfono ya no está en tus manos (Modo perdido, evidencia) se maneja desde el panel Ojo Guard MS.
 * Lo que antes estaba acá abajo (la lista de la familia, unirse con un código, pausar la ubicación y el SOS completo con sus ayudas)
 * está ahora en "Familia".
 */

type Paleta = { [clave: string]: string };

type Props = {
  paleta: Paleta;
  tema: "claro" | "oscuro";
  nombre: string;
  enLinea: boolean | null;
  onPerfil: () => void;
  onFamilia: () => void;
  onConfiguracion: () => void;
  /** Cuando el teléfono no está vinculado: lleva a donde se vincula. */
  onVincular: () => void;
  /** Abre el panel Ojo Guard MS entrando directo, sin pedir códigos (el botón "Abrir panel" de arriba). */
  onPanel: () => void | Promise<void>;
  /** La banda de permisos que faltan, si hace falta mostrarla. */
  banda?: ReactNode;
  /** Un aviso arriba del mapa (por ejemplo el diagnóstico de captura), si hace falta. */
  aviso?: ReactNode;
  botones: {
    secundario: StyleProp<ViewStyle>;
    secundarioTexto: StyleProp<TextStyle>;
    ayuda: StyleProp<TextStyle>;
  };
};

export function InicioMapa({ paleta: P, tema, nombre, enLinea, onPerfil, onFamilia, onConfiguracion, onVincular, onPanel, banda, aviso, botones }: Props) {
  const [vinculo, setVinculo] = useState<NativeEnrollment | null | undefined>(undefined);
  const [conFamilia, setConFamilia] = useState(false);
  const [abriendo, setAbriendo] = useState(false);

  // Pedir el acceso y abrir el navegador tarda un instante: mientras tanto el botón dice "Abriendo…".
  async function abrirPanel() {
    if (abriendo) return;
    setAbriendo(true);
    try {
      await onPanel();
    } finally {
      setAbriendo(false);
    }
  }

  // El SOS se muestra solo si este teléfono está en una familia (o ve a alguien): se mira al abrir y cada vez que se vuelve a la app.
  useEffect(() => {
    let vivo = true;
    const mirar = async () => {
      const actual = await loadNativeEnrollment().catch(() => null);
      if (!vivo) return;
      setVinculo(actual);
      if (!actual) return;
      try {
        const datos = await fetchFamily(actual);
        if (vivo) setConFamilia(datos.me.memberships > 0 || datos.people.length > 0);
      } catch {
        // Sin red se deja como estaba.
      }
    };
    void mirar();
    const suscripcion = AppState.addEventListener("change", (estado) => {
      if (estado === "active") void mirar();
    });
    return () => {
      vivo = false;
      suscripcion.remove();
    };
  }, []);

  const s = estilos();
  return (
    <View style={s.raiz}>
      <CabezaInicio paleta={P} nombre={nombre} enLinea={enLinea} onPanel={() => void abrirPanel()} abriendo={abriendo} />
      <BotonesInicioMapa paleta={P} onPerfil={onPerfil} onFamilia={onFamilia} onConfiguracion={onConfiguracion} />
      {banda}
      {aviso}
      <MapaEnApp paleta={P} tema={tema} onVincular={onVincular} />
      <SosBlock enrollment={vinculo} visible={conFamilia} compacto paleta={P} botones={botones} />
    </View>
  );
}

function estilos() {
  return StyleSheet.create({
    // Arriba queda lugar para la ✕ de salir y la ayuda (?), que flotan sobre la pantalla.
    raiz: { flex: 1, paddingBottom: 12, paddingHorizontal: 16, paddingTop: 52 },
  });
}
