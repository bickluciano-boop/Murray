import { useRef, useState } from "react";
import {
  ActivityIndicator,
  Image,
  Linking,
  Pressable,
  SafeAreaView,
  ScrollView,
  StatusBar,
  Text,
  View,
} from "react-native";
import AsyncStorage from "@react-native-async-storage/async-storage";
import * as FileSystem from "expo-file-system/legacy";
import { CameraView, useCameraPermissions } from "expo-camera";
import * as ImagePicker from "expo-image-picker";
import { Icono } from "./Iconos";
import { avisarCamaraAbierta, soltarAvisoCamara, VerificarIdentidad, type EtapaIdentidad, type PaletaIdentidad } from "./VerificarIdentidad";

// Despues de abrir la cuenta: la foto de perfil (obligatoria; se saca con la camara propia de la app porque en algunos Android, como Xiaomi, abrir la camara del sistema mata la app) y la verificacion de identidad (opcional: DNI + sexo + selfie, ver
// VerificarIdentidad.tsx). La foto del documento ya no se pide: el numero de DNI se comprueba contra RENAPER y no se guarda ninguna
// foto del documento. Sin verificar se puede usar la app, pero no se puede pedir foto y audio a otras personas (lo controla el servidor).

export type { PaletaIdentidad };

export type IdentidadGuardada = {
  perfilUri: string;
  estado: "pendiente" | "verificada" | "omitida";
  creadaEn: string;
};

const CLAVE_IDENTIDAD = "ojo_identidad_v1";
const CARPETA = "ojo-identidad";

/**
 * La identidad guardada en este telefono, o null si todavia no se hizo el arranque. Las versiones anteriores guardaban ademas una foto
 * del documento y una de la cara: ya no se usan y son datos sensibles, asi que se borran del telefono apenas se las encuentra.
 */
export async function cargarIdentidad(): Promise<IdentidadGuardada | null> {
  try {
    const crudo = await AsyncStorage.getItem(CLAVE_IDENTIDAD);
    if (!crudo) return null;
    const dato = JSON.parse(crudo) as Record<string, unknown> | null;
    if (!dato || typeof dato.perfilUri !== "string" || !dato.perfilUri) return null;
    const viejas = [dato.documentoUri, dato.caraUri].filter((u): u is string => typeof u === "string" && u.length > 0);
    const estadoViejo = String(dato.estado ?? "");
    const estado: IdentidadGuardada["estado"] = estadoViejo === "verificada" || estadoViejo === "omitida" ? estadoViejo : "pendiente";
    const limpia: IdentidadGuardada = { perfilUri: dato.perfilUri, estado, creadaEn: String(dato.creadaEn ?? new Date().toISOString()) };
    if (viejas.length > 0 || dato.documentoUri !== undefined || dato.caraUri !== undefined) {
      for (const uri of viejas) await FileSystem.deleteAsync(uri, { idempotent: true }).catch(() => undefined);
      await AsyncStorage.setItem(CLAVE_IDENTIDAD, JSON.stringify(limpia));
    }
    return limpia;
  } catch {
    return null;
  }
}

async function guardarFoto(origen: string, nombre: string): Promise<string> {
  const base = FileSystem.documentDirectory;
  if (!base) return origen;
  const carpeta = `${base}${CARPETA}/`;
  try {
    await FileSystem.makeDirectoryAsync(carpeta, { intermediates: true });
  } catch {
    // Si ya existe no pasa nada.
  }
  const destino = `${carpeta}${nombre}-${Date.now()}.jpg`;
  await FileSystem.copyAsync({ from: origen, to: destino });
  return destino;
}

const TOTAL_PASOS = 6;
const PRIMER_PASO = 3;
const DORADO = "#D4A94D";

export function ArranqueIdentidad({
  paleta,
  noche,
  onTerminar,
}: {
  paleta: PaletaIdentidad;
  noche: boolean;
  onTerminar: (identidad: IdentidadGuardada) => void;
}) {
  const [etapa, setEtapa] = useState<"perfil" | EtapaIdentidad>("perfil");
  const [perfilUri, setPerfilUri] = useState<string | null>(null);
  const [guardada, setGuardada] = useState<IdentidadGuardada | null>(null);
  const [ocupado, setOcupado] = useState(false);
  const [aviso, setAviso] = useState("");
  const [sinPermiso, setSinPermiso] = useState(false);
  const [camaraAbierta, setCamaraAbierta] = useState(false);
  const [camaraLista, setCamaraLista] = useState(false);
  const [permisoCamara, pedirPermisoCamara] = useCameraPermissions();
  const camaraRef = useRef<CameraView>(null);

  const azul = noche ? "#7C9CFF" : paleta.doradoRelleno;
  const azulSuave = noche ? "#1A2757" : "#E4EBFC";
  // Perfil = paso 3; datos del DNI = paso 4; selfie y resultado = paso 5 (el paso 6 es la pantalla siguiente).
  const pasoActual = etapa === "perfil" ? PRIMER_PASO : etapa === "datos" ? PRIMER_PASO + 1 : PRIMER_PASO + 2;

  async function abrirCamara() {
    if (ocupado) return;
    setAviso("");
    setSinPermiso(false);
    let concedido = permisoCamara?.granted === true;
    if (!concedido) {
      const respuesta = await pedirPermisoCamara().catch(() => null);
      concedido = respuesta?.granted === true;
    }
    if (!concedido) {
      setSinPermiso(true);
      setAviso("Necesitamos la cámara para este paso. Activala en los ajustes del teléfono y volvé.");
      return;
    }
    setCamaraLista(false);
    setCamaraAbierta(true);
  }

  async function sacarConCamara() {
    if (ocupado || !camaraLista) return;
    setOcupado(true);
    setAviso("");
    try {
      const sacar = () => camaraRef.current?.takePictureAsync({ base64: false, quality: 0.7, skipProcessing: false });
      // En iPhone la camara avisa "lista" un instante antes de poder sacar y a veces la primera falla: se reintenta una vez.
      let foto = await Promise.resolve(sacar()).catch(() => null);
      if (!foto?.uri) {
        await new Promise<void>((listo) => setTimeout(listo, 700));
        foto = await Promise.resolve(sacar()).catch(() => null);
      }
      if (foto?.uri) {
        setPerfilUri(foto.uri);
        setCamaraAbierta(false);
      } else {
        setAviso("No se pudo sacar la foto. Probá de nuevo.");
      }
    } finally {
      setOcupado(false);
    }
  }

  async function elegirDeGaleria() {
    if (ocupado) return;
    setOcupado(true);
    setAviso("");
    setSinPermiso(false);
    try {
      // La galeria del sistema tambien manda la app a segundo plano: se avisa para que la guardia no lo tome por una salida de la app.
      avisarCamaraAbierta();
      const resultado = await ImagePicker.launchImageLibraryAsync({ mediaTypes: ["images"], quality: 0.85 });
      const uri = resultado.canceled ? null : (resultado.assets[0]?.uri ?? null);
      if (uri) setPerfilUri(uri);
    } catch {
      setAviso("No se pudo abrir la galería. Probá de nuevo.");
    } finally {
      soltarAvisoCamara();
      setOcupado(false);
    }
  }

  async function usarPerfil() {
    if (!perfilUri || ocupado) return;
    setOcupado(true);
    try {
      const identidad: IdentidadGuardada = {
        perfilUri: await guardarFoto(perfilUri, "perfil"),
        estado: "pendiente",
        creadaEn: new Date().toISOString(),
      };
      await AsyncStorage.setItem(CLAVE_IDENTIDAD, JSON.stringify(identidad));
      setGuardada(identidad);
      setAviso("");
      setEtapa("datos");
    } catch {
      setAviso("No se pudo guardar la foto. Revisá que el teléfono tenga espacio y probá de nuevo.");
    } finally {
      setOcupado(false);
    }
  }

  async function terminar(estado: "verificada" | "omitida") {
    if (!guardada) return;
    const final: IdentidadGuardada = { ...guardada, estado };
    try {
      await AsyncStorage.setItem(CLAVE_IDENTIDAD, JSON.stringify(final));
    } catch {
      // Si no se pudo anotar igual se sigue: el servidor es quien sabe si esta verificada.
    }
    onTerminar(final);
  }

  const boton = (texto: string, onPress: () => void, opciones: { principal?: boolean; deshabilitado?: boolean } = {}) => (
    <Pressable
      accessibilityRole="button"
      disabled={opciones.deshabilitado === true}
      onPress={onPress}
      style={{
        height: 54,
        borderRadius: 27,
        alignItems: "center",
        justifyContent: "center",
        backgroundColor: opciones.principal ? paleta.doradoRelleno : "transparent",
        borderWidth: opciones.principal ? 0 : 1.5,
        borderColor: azul,
        opacity: opciones.deshabilitado ? 0.45 : 1,
      }}
    >
      <Text style={{ color: opciones.principal ? paleta.sobreDorado : azul, fontSize: 16, fontWeight: "800" }}>{texto}</Text>
    </Pressable>
  );

  const cabecera = (
    <View style={{ paddingHorizontal: 24, paddingTop: 22, flexDirection: "row", alignItems: "center", justifyContent: "space-between" }}>
      <View style={{ flexDirection: "row", gap: 5 }}>
        {Array.from({ length: TOTAL_PASOS }, (_, i) => (
          <View key={i} style={{ width: 18, height: 6, borderRadius: 3, backgroundColor: i < pasoActual ? azul : paleta.borde }} />
        ))}
      </View>
      <Text style={{ color: paleta.textoDebil, fontSize: 13, fontWeight: "700" }}>
        Paso {pasoActual} de {TOTAL_PASOS}
      </Text>
    </View>
  );

  if (etapa !== "perfil") {
    return (
      <SafeAreaView style={{ flex: 1, backgroundColor: paleta.fondo }}>
        <StatusBar barStyle={noche ? "light-content" : "dark-content"} backgroundColor={paleta.fondo} />
        {cabecera}
        <ScrollView keyboardShouldPersistTaps="handled" contentContainerStyle={{ paddingHorizontal: 24, paddingTop: 22, paddingBottom: 32 }}>
          <VerificarIdentidad
            noche={noche}
            onEtapa={setEtapa}
            onListo={(estado) => void terminar(estado)}
            paleta={paleta}
            permitirOmitir
            revisarEstado={false}
          />
        </ScrollView>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: paleta.fondo }}>
      <StatusBar barStyle={noche ? "light-content" : "dark-content"} backgroundColor={paleta.fondo} />
      {cabecera}
      <ScrollView contentContainerStyle={{ paddingHorizontal: 24, paddingTop: 22, paddingBottom: 24 }}>
        <Text accessibilityRole="header" style={{ color: paleta.texto, fontSize: 28, fontWeight: "700", letterSpacing: -0.5 }}>
          Tu foto de perfil
        </Text>
        <Text style={{ color: paleta.textoMedio, fontSize: 15, lineHeight: 23, marginTop: 10, marginBottom: 22 }}>
          Es la foto que ve tu círculo al lado de tu nombre. Podés usar una de la galería o sacarte una ahora.
        </Text>
        <View style={{ alignItems: "center" }}>
          {camaraAbierta ? (
            <View style={{ width: 220, height: 220, borderRadius: 110, overflow: "hidden", borderWidth: 4, borderColor: DORADO, backgroundColor: "#000" }}>
              <CameraView ref={camaraRef} facing="front" animateShutter={false} onCameraReady={() => setCamaraLista(true)} style={{ flex: 1 }} />
            </View>
          ) : perfilUri ? (
            <Image source={{ uri: perfilUri }} resizeMode="cover" style={{ width: 220, height: 220, borderRadius: 110, borderWidth: 4, borderColor: DORADO }} />
          ) : (
            <View style={{ width: 200, height: 200, borderRadius: 100, backgroundColor: azulSuave, borderWidth: 2, borderStyle: "dashed", borderColor: DORADO, alignItems: "center", justifyContent: "center" }}>
              <Icono nombre="persona" color={azul} tam={86} />
            </View>
          )}
        </View>
        {aviso ? (
          <Text accessibilityLiveRegion="polite" style={{ color: paleta.peligro, fontSize: 13.5, lineHeight: 19, marginTop: 18, textAlign: "center" }}>
            {aviso}
          </Text>
        ) : null}
        {ocupado ? <ActivityIndicator color={azul} style={{ marginTop: 16 }} /> : null}
      </ScrollView>
      <View style={{ paddingHorizontal: 24, paddingBottom: 22, gap: 10 }}>
        {camaraAbierta ? (
          <>
            {boton(camaraLista ? "Sacar la foto" : "Preparando la cámara…", () => void sacarConCamara(), { principal: true, deshabilitado: ocupado || !camaraLista })}
            {boton("Cancelar", () => setCamaraAbierta(false), { deshabilitado: ocupado })}
          </>
        ) : perfilUri ? (
          <>
            {boton("Usar esta foto", () => void usarPerfil(), { principal: true, deshabilitado: ocupado })}
            {boton("Sacar otra", () => { setPerfilUri(null); void abrirCamara(); }, { deshabilitado: ocupado })}
          </>
        ) : (
          <>
            {boton("Sacarme una foto", () => void abrirCamara(), { principal: true, deshabilitado: ocupado })}
            {boton("Elegir de la galería", () => void elegirDeGaleria(), { deshabilitado: ocupado })}
            {sinPermiso ? boton("Abrir ajustes del teléfono", () => void Linking.openSettings()) : null}
          </>
        )}
      </View>
    </SafeAreaView>
  );
}
