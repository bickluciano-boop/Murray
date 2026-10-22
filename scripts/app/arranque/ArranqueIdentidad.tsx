import { useState, type ReactNode } from "react";
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
import * as ImagePicker from "expo-image-picker";
import { clearPendingSystemActivity, markPendingSystemActivity } from "./pendingSystemActivity";
import { Icono } from "./Iconos";

// Tres pasos obligatorios despues de abrir la cuenta: foto de perfil, foto del
// documento (DNI o pasaporte) y foto de la cara. Ninguno se puede saltar.
//
// IMPORTANTE: por ahora las tres fotos quedan guardadas en ESTE telefono con el
// estado "pendiente_de_verificar". La comparacion entre la cara y el documento
// todavia no existe: cuando se conecte, es lo unico que tiene que cambiar el
// estado a "verificada". La pantalla no afirma que ya se haya comparado nada.

export type TipoDocumento = "dni" | "pasaporte";

export type IdentidadGuardada = {
  perfilUri: string;
  documentoUri: string;
  documentoTipo: TipoDocumento;
  caraUri: string;
  estado: "pendiente_de_verificar" | "verificada" | "rechazada";
  creadaEn: string;
};

const CLAVE_IDENTIDAD = "ojo_identidad_v1";
const CARPETA = "ojo-identidad";

export async function cargarIdentidad(): Promise<IdentidadGuardada | null> {
  try {
    const crudo = await AsyncStorage.getItem(CLAVE_IDENTIDAD);
    if (!crudo) return null;
    const dato = JSON.parse(crudo) as IdentidadGuardada;
    return dato && dato.perfilUri && dato.documentoUri && dato.caraUri ? dato : null;
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

export type PaletaIdentidad = {
  fondo: string;
  superficie: string;
  texto: string;
  textoMedio: string;
  textoDebil: string;
  borde: string;
  doradoRelleno: string;
  sobreDorado: string;
  peligro: string;
};

type Paso = "perfil" | "documento" | "cara";
const ORDEN: Paso[] = ["perfil", "documento", "cara"];
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
  const [paso, setPaso] = useState<Paso>("perfil");
  const [perfilUri, setPerfilUri] = useState<string | null>(null);
  const [documentoUri, setDocumentoUri] = useState<string | null>(null);
  const [documentoTipo, setDocumentoTipo] = useState<TipoDocumento>("dni");
  const [caraUri, setCaraUri] = useState<string | null>(null);
  const [ocupado, setOcupado] = useState(false);
  const [aviso, setAviso] = useState("");
  const [sinPermiso, setSinPermiso] = useState(false);

  const azul = noche ? "#7C9CFF" : paleta.doradoRelleno;
  const azulSuave = noche ? "#1A2757" : "#E4EBFC";
  const tarjeta = noche ? "#16203F" : "#FFFFFF";
  const indice = ORDEN.indexOf(paso);
  const fotoActual = paso === "perfil" ? perfilUri : paso === "documento" ? documentoUri : caraUri;

  function ponerFoto(uri: string | null) {
    if (paso === "perfil") setPerfilUri(uri);
    else if (paso === "documento") setDocumentoUri(uri);
    else setCaraUri(uri);
  }

  async function sacarFoto(frontal: boolean, galeria = false) {
    if (ocupado) return;
    setOcupado(true);
    setAviso("");
    setSinPermiso(false);
    try {
      if (!galeria) {
        const permiso = await ImagePicker.requestCameraPermissionsAsync();
        if (!permiso.granted) {
          setSinPermiso(true);
          setAviso("Necesitamos la cámara para este paso. Activala en los ajustes del teléfono y volvé.");
          return;
        }
      }
      // Abrir la camara manda la app a segundo plano: se avisa para que la
      // guardia no lo tome por una salida de la app.
      markPendingSystemActivity();
      const resultado = galeria
        ? await ImagePicker.launchImageLibraryAsync({ mediaTypes: ["images"], quality: 0.85 })
        : await ImagePicker.launchCameraAsync({
            mediaTypes: ["images"],
            quality: 0.85,
            cameraType: frontal ? ImagePicker.CameraType.front : ImagePicker.CameraType.back,
          });
      if (resultado.canceled || !resultado.assets[0]?.uri) return;
      ponerFoto(resultado.assets[0].uri);
    } catch {
      setAviso("No se pudo abrir la cámara. Probá de nuevo.");
    } finally {
      clearPendingSystemActivity();
      setOcupado(false);
    }
  }

  async function seguir() {
    if (!fotoActual || ocupado) return;
    if (paso !== "cara") {
      setAviso("");
      setPaso(ORDEN[indice + 1]);
      return;
    }
    if (!perfilUri || !documentoUri || !caraUri) return;
    setOcupado(true);
    try {
      const identidad: IdentidadGuardada = {
        perfilUri: await guardarFoto(perfilUri, "perfil"),
        documentoUri: await guardarFoto(documentoUri, "documento"),
        documentoTipo,
        caraUri: await guardarFoto(caraUri, "cara"),
        estado: "pendiente_de_verificar",
        creadaEn: new Date().toISOString(),
      };
      await AsyncStorage.setItem(CLAVE_IDENTIDAD, JSON.stringify(identidad));
      onTerminar(identidad);
    } catch {
      setAviso("No se pudieron guardar las fotos. Revisá que el teléfono tenga espacio y probá de nuevo.");
      setOcupado(false);
    }
  }

  const textos = {
    perfil: {
      titulo: "Tu foto de perfil",
      texto: "Es la foto que ve tu círculo al lado de tu nombre. Podés usar una de la galería o sacarte una ahora.",
      boton: "Sacarme una foto",
      pie: "",
    },
    documento: {
      titulo: "Foto de tu documento",
      texto: "Sacale una foto a tu documento con buena luz, sobre una superficie lisa.",
      boton: "Sacar la foto del documento",
      pie: "Después te pedimos una foto de tu cara para compararlas.",
    },
    cara: {
      titulo: "Ahora, tu cara",
      texto: "Una foto con buena luz, de frente y sin lentes oscuros. La comparamos con la foto de tu documento para confirmar que sos vos.",
      boton: "Sacarme la foto",
      pie: "",
    },
  }[paso];

  const boton = (texto: string, onPress: () => void, opciones: { principal?: boolean; deshabilitado?: boolean } = {}) => (
    <Pressable
      accessibilityRole="button"
      disabled={opciones.deshabilitado}
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

  let cuerpo: ReactNode;
  if (fotoActual) {
    cuerpo = (
      <View style={{ alignItems: "center" }}>
        <Image
          source={{ uri: fotoActual }}
          resizeMode="cover"
          style={
            paso === "perfil"
              ? { width: 220, height: 220, borderRadius: 110, borderWidth: 4, borderColor: DORADO }
              : { width: 300, height: paso === "documento" ? 200 : 300, borderRadius: 24, borderWidth: 3, borderColor: DORADO }
          }
        />
      </View>
    );
  } else if (paso === "perfil") {
    cuerpo = (
      <View style={{ alignItems: "center" }}>
        <View style={{ width: 200, height: 200, borderRadius: 100, backgroundColor: azulSuave, borderWidth: 2, borderStyle: "dashed", borderColor: DORADO, alignItems: "center", justifyContent: "center" }}>
          <Icono nombre="persona" color={azul} tam={86} />
        </View>
      </View>
    );
  } else if (paso === "documento") {
    cuerpo = (
      <View style={{ alignItems: "center", gap: 18 }}>
        <View style={{ flexDirection: "row", borderRadius: 22, backgroundColor: azulSuave, padding: 4 }}>
          {(["dni", "pasaporte"] as TipoDocumento[]).map((tipo) => (
            <Pressable
              key={tipo}
              accessibilityRole="button"
              accessibilityState={{ selected: documentoTipo === tipo }}
              onPress={() => setDocumentoTipo(tipo)}
              style={{ height: 38, paddingHorizontal: 26, borderRadius: 19, alignItems: "center", justifyContent: "center", backgroundColor: documentoTipo === tipo ? tarjeta : "transparent" }}
            >
              <Text style={{ color: documentoTipo === tipo ? azul : paleta.textoDebil, fontSize: 14, fontWeight: "700" }}>
                {tipo === "dni" ? "DNI" : "Pasaporte"}
              </Text>
            </Pressable>
          ))}
        </View>
        <View style={{ width: 300, height: 190, borderRadius: 22, borderWidth: 2, borderStyle: "dashed", borderColor: DORADO, alignItems: "center", justifyContent: "center" }}>
          <View style={{ width: 252, height: 150, borderRadius: 14, backgroundColor: tarjeta, flexDirection: "row", padding: 14, gap: 14, elevation: 3 }}>
            <View style={{ width: 68, height: 86, borderRadius: 8, backgroundColor: azulSuave, alignItems: "center", justifyContent: "center" }}>
              <Icono nombre="persona" color={azul} tam={40} />
            </View>
            <View style={{ flex: 1, gap: 9, paddingTop: 6 }}>
              <View style={{ height: 9, width: "86%", borderRadius: 5, backgroundColor: paleta.borde }} />
              <View style={{ height: 9, width: "62%", borderRadius: 5, backgroundColor: paleta.borde }} />
              <View style={{ height: 9, width: "74%", borderRadius: 5, backgroundColor: paleta.borde }} />
            </View>
          </View>
        </View>
        <View style={{ gap: 8, alignSelf: "stretch" }}>
          {["Que se vea completo, sin reflejos ni sombras", "Solo lo usamos para verificar tu identidad"].map((t) => (
            <View key={t} style={{ flexDirection: "row", alignItems: "center", gap: 10 }}>
              <View style={{ width: 22, height: 22, borderRadius: 11, backgroundColor: azul, alignItems: "center", justifyContent: "center" }}>
                <Icono nombre="check" color="#fff" tam={14} />
              </View>
              <Text style={{ color: paleta.textoMedio, fontSize: 14, flex: 1 }}>{t}</Text>
            </View>
          ))}
        </View>
      </View>
    );
  } else {
    cuerpo = (
      <View style={{ alignItems: "center" }}>
        <View style={{ width: 230, height: 280, borderRadius: 115, backgroundColor: azulSuave, borderWidth: 2, borderStyle: "dashed", borderColor: DORADO, alignItems: "center", justifyContent: "center" }}>
          <Icono nombre="persona" color={azul} tam={100} />
        </View>
      </View>
    );
  }

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: paleta.fondo }}>
      <StatusBar barStyle={noche ? "light-content" : "dark-content"} backgroundColor={paleta.fondo} />
      <View style={{ paddingHorizontal: 24, paddingTop: 22, flexDirection: "row", alignItems: "center", justifyContent: "space-between" }}>
        <View style={{ flexDirection: "row", gap: 5 }}>
          {Array.from({ length: TOTAL_PASOS }, (_, i) => (
            <View key={i} style={{ width: 18, height: 6, borderRadius: 3, backgroundColor: i < PRIMER_PASO + indice ? azul : paleta.borde }} />
          ))}
        </View>
        <Text style={{ color: paleta.textoDebil, fontSize: 13, fontWeight: "700" }}>
          Paso {PRIMER_PASO + indice} de {TOTAL_PASOS}
        </Text>
      </View>
      <ScrollView contentContainerStyle={{ paddingHorizontal: 24, paddingTop: 22, paddingBottom: 24 }}>
        <Text accessibilityRole="header" style={{ color: paleta.texto, fontSize: 28, fontWeight: "700", letterSpacing: -0.5 }}>
          {textos.titulo}
        </Text>
        <Text style={{ color: paleta.textoMedio, fontSize: 15, lineHeight: 23, marginTop: 10, marginBottom: 22 }}>{textos.texto}</Text>
        {cuerpo}
        {aviso ? (
          <Text accessibilityLiveRegion="polite" style={{ color: paleta.peligro, fontSize: 13.5, lineHeight: 19, marginTop: 18, textAlign: "center" }}>
            {aviso}
          </Text>
        ) : null}
        {ocupado ? <ActivityIndicator color={azul} style={{ marginTop: 16 }} /> : null}
      </ScrollView>
      <View style={{ paddingHorizontal: 24, paddingBottom: 22, gap: 10 }}>
        {textos.pie && !fotoActual ? (
          <Text style={{ color: paleta.textoDebil, fontSize: 12.5, textAlign: "center" }}>{textos.pie}</Text>
        ) : null}
        {fotoActual ? (
          <>
            {boton(paso === "cara" ? "Usar esta foto y seguir" : "Usar esta foto", () => void seguir(), { principal: true, deshabilitado: ocupado })}
            {boton("Sacar otra", () => ponerFoto(null), { deshabilitado: ocupado })}
          </>
        ) : (
          <>
            {boton(textos.boton, () => void sacarFoto(paso !== "documento"), { principal: true, deshabilitado: ocupado })}
            {paso === "perfil" ? boton("Elegir de la galería", () => void sacarFoto(true, true), { deshabilitado: ocupado }) : null}
            {sinPermiso ? boton("Abrir ajustes del teléfono", () => void Linking.openSettings()) : null}
          </>
        )}
        {indice > 0 ? (
          <Pressable
            accessibilityRole="button"
            hitSlop={10}
            onPress={() => {
              setAviso("");
              setPaso(ORDEN[indice - 1]);
            }}
            style={{ alignItems: "center", paddingVertical: 6 }}
          >
            <Text style={{ color: paleta.textoDebil, fontSize: 14, fontWeight: "600" }}>Volver al paso anterior</Text>
          </Pressable>
        ) : null}
      </View>
    </SafeAreaView>
  );
}
