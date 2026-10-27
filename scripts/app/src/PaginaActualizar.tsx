import { useCallback, useEffect, useState } from "react";
import { Linking, Platform, Pressable, Text, View, type StyleProp, type TextStyle, type ViewStyle } from "react-native";

/**
 * "Actualizar Ojo Guard" (Android): la tarjeta de Configuración y la línea del Dr. Ojo Guard.
 * Pregunta a ojoguard.app cuál es la última versión publicada (el APK que sube Luciano con subir-apk-panel.ps1) y la compara con el
 * número de build instalado. La versión publicada se escribe "0.9.1 (175)": el número entre paréntesis es el build de Android.
 * Sin ese número no se puede comparar y se ofrece bajarla igual. En iPhone la app se actualiza por TestFlight o la App Store.
 */

const URL_VERSION_APP = "https://ojoguard.app/api/app/version";
const URL_DESCARGA_APP = "https://ojoguard.app/descargar";

type Botones = {
  secundario: StyleProp<ViewStyle>;
  secundarioTexto: StyleProp<TextStyle>;
  ayuda: StyleProp<TextStyle>;
};

export type EstadoVersion =
  | { estado: "buscando" }
  | { estado: "al-dia"; publicada: string }
  | { estado: "nueva"; publicada: string }
  | { estado: "sin-numero"; publicada: string }
  | { estado: "nada" }
  | { estado: "error" };

export async function consultarVersion(build: string): Promise<EstadoVersion> {
  try {
    const respuesta = await fetch(URL_VERSION_APP, { headers: { accept: "application/json" } });
    const dato = (await respuesta.json()) as { disponible?: boolean; version?: string };
    if (!dato.disponible) return { estado: "nada" };
    const publicada = String(dato.version ?? "").trim();
    const tengo = Number.parseInt(build, 10);
    const ultima = Number.parseInt(/\((\d+)\)\s*$/.exec(publicada)?.[1] ?? "", 10);
    if (!Number.isFinite(tengo) || !Number.isFinite(ultima)) return { estado: "sin-numero", publicada };
    return tengo >= ultima ? { estado: "al-dia", publicada } : { estado: "nueva", publicada };
  } catch {
    return { estado: "error" };
  }
}

function abrirDescarga() {
  void Linking.openURL(URL_DESCARGA_APP).catch(() => undefined);
}

function textoEstado(e: EstadoVersion): string {
  switch (e.estado) {
    case "buscando":
      return "Buscando la última versión…";
    case "al-dia":
      return `Ya tenés la última versión (${e.publicada}).`;
    case "nueva":
      return `Hay una versión nueva: ${e.publicada}. Tocá "Descargar la nueva versión".`;
    case "sin-numero":
      return `Hay una versión publicada (${e.publicada || "sin número"}), pero no puedo saber si es más nueva que la tuya. Podés bajarla igual.`;
    case "nada":
      return "Todavía no hay una versión publicada.";
    default:
      return "No pude consultar la última versión. Revisá la conexión e intentá de nuevo.";
  }
}

type Props = { botones: Botones; version: string; build: string };

/** La página propia (grupo "actualizacion" de Configuración). */
export function PaginaActualizar({ botones, version, build }: Props) {
  const [estado, setEstado] = useState<EstadoVersion>({ estado: "buscando" });
  const buscar = useCallback(async () => {
    setEstado({ estado: "buscando" });
    setEstado(await consultarVersion(build));
  }, [build]);
  useEffect(() => {
    void buscar();
  }, [buscar]);
  if (Platform.OS !== "android") {
    return <Text style={botones.ayuda}>En iPhone, Ojo Guard se actualiza desde TestFlight o la App Store.</Text>;
  }
  return (
    <View>
      <Text style={botones.ayuda}>{`Tu versión: ${version} · build ${build}`}</Text>
      <Text style={[botones.ayuda, { fontWeight: "700", marginTop: 8 }]}>{textoEstado(estado)}</Text>
      <Pressable accessibilityRole="button" onPress={() => void buscar()} style={[botones.secundario, { marginTop: 14 }]}>
        <Text style={botones.secundarioTexto}>Buscar actualización</Text>
      </Pressable>
      <Pressable accessibilityRole="button" onPress={abrirDescarga} style={botones.secundario}>
        <Text style={botones.secundarioTexto}>
          {estado.estado === "nueva" ? "Descargar la nueva versión" : "Volver a instalar la última"}
        </Text>
      </Pressable>
      <Text style={[botones.ayuda, { marginTop: 10 }]}>
        Se abre la página de descarga de Ojo Guard (ojoguard.app/descargar). Bajás el archivo y lo instalás encima de esta versión. Si Android dice que no se puede instalar, no borres la app: avisanos.
      </Text>
    </View>
  );
}

type LineaProps = { build: string; botones: Botones; onActualizar?: (() => void) | undefined };

/** Arriba del Dr. Ojo Guard: si la app está al día o hay una versión nueva. Sin dato (sin conexión o nada publicado) no muestra nada. */
export function LineaVersion({ build, botones, onActualizar }: LineaProps) {
  const [estado, setEstado] = useState<EstadoVersion>({ estado: "buscando" });
  useEffect(() => {
    let vivo = true;
    void consultarVersion(build).then((e) => {
      if (vivo) setEstado(e);
    });
    return () => {
      vivo = false;
    };
  }, [build]);
  if (estado.estado === "buscando" || estado.estado === "error" || estado.estado === "nada") return null;
  const texto =
    estado.estado === "nueva"
      ? `Hay una versión nueva de Ojo Guard (${estado.publicada}). Tocá para actualizar.`
      : estado.estado === "al-dia"
        ? "Versión de Ojo Guard: al día ✓"
        : "Versión de Ojo Guard: tocá para ver si hay una nueva.";
  return (
    <Pressable accessibilityRole="button" onPress={onActualizar} style={[botones.secundario, { marginBottom: 12 }]}>
      <Text style={botones.secundarioTexto}>{texto}</Text>
    </Pressable>
  );
}
