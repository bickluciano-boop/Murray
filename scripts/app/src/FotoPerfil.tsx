import { useEffect, useRef, useState } from "react";
import { ActivityIndicator, Image, Linking, Pressable, Text, View } from "react-native";
import { CameraView, useCameraPermissions } from "expo-camera";
import * as ImagePicker from "expo-image-picker";
import { cargarIdentidad, guardarPerfil } from "./ArranqueIdentidad";
import { Icono } from "./Iconos";
import { avisarCamaraAbierta, soltarAvisoCamara, type PaletaIdentidad } from "./VerificarIdentidad";

// Tarjeta "Mi foto de perfil" dentro de Perfil: ver la foto, cambiarla con la camara de la app (en algunos Android, como Xiaomi, la camara del
// sistema saca a la app) o elegir otra de la galeria. La foto se guarda solo en este telefono.

const DORADO = "#D4A94D";

export function FotoPerfil({ paleta, noche }: { paleta: PaletaIdentidad; noche: boolean }) {
  const [perfilUri, setPerfilUri] = useState<string | null>(null);
  const [nuevaUri, setNuevaUri] = useState<string | null>(null);
  const [cargando, setCargando] = useState(true);
  const [camaraAbierta, setCamaraAbierta] = useState(false);
  const [camaraLista, setCamaraLista] = useState(false);
  const [permisoCamara, pedirPermisoCamara] = useCameraPermissions();
  const camaraRef = useRef<CameraView>(null);
  const [ocupado, setOcupado] = useState(false);
  const [aviso, setAviso] = useState("");
  const [sinPermiso, setSinPermiso] = useState(false);

  const azul = noche ? "#7C9CFF" : paleta.doradoRelleno;
  const azulSuave = noche ? "#1A2757" : "#E4EBFC";

  useEffect(() => {
    let vivo = true;
    void cargarIdentidad().then((identidad) => {
      if (!vivo) return;
      setPerfilUri(identidad?.perfilUri ?? null);
      setCargando(false);
    });
    return () => {
      vivo = false;
    };
  }, []);

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
      setAviso("Necesitamos la cámara para sacar la foto. Activala en los ajustes del teléfono y volvé.");
      return;
    }
    setNuevaUri(null);
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
        setNuevaUri(foto.uri);
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
      if (uri) setNuevaUri(uri);
    } catch {
      setAviso("No se pudo abrir la galería. Probá de nuevo.");
    } finally {
      soltarAvisoCamara();
      setOcupado(false);
    }
  }

  async function usarFoto() {
    if (!nuevaUri || ocupado) return;
    setOcupado(true);
    setAviso("");
    try {
      const guardada = await guardarPerfil(nuevaUri);
      if (guardada) {
        setPerfilUri(guardada.perfilUri);
        setNuevaUri(null);
        setAviso("Listo, tu foto de perfil quedó guardada.");
      } else {
        setAviso("No se pudo guardar la foto. Revisá que el teléfono tenga espacio y probá de nuevo.");
      }
    } finally {
      setOcupado(false);
    }
  }

  const boton = (texto: string, onPress: () => void, opciones: { principal?: boolean; deshabilitado?: boolean } = {}) => (
    <Pressable
      accessibilityRole="button"
      disabled={opciones.deshabilitado === true}
      onPress={onPress}
      style={{
        height: 50,
        borderRadius: 25,
        alignItems: "center",
        justifyContent: "center",
        backgroundColor: opciones.principal ? paleta.doradoRelleno : "transparent",
        borderWidth: opciones.principal ? 0 : 1.5,
        borderColor: azul,
        opacity: opciones.deshabilitado ? 0.45 : 1,
      }}
    >
      <Text style={{ color: opciones.principal ? paleta.sobreDorado : azul, fontSize: 15, fontWeight: "800" }}>{texto}</Text>
    </Pressable>
  );

  const mostrada = nuevaUri ?? perfilUri;

  return (
    <View style={{ backgroundColor: paleta.superficie, borderRadius: 18, borderWidth: 1, borderColor: paleta.borde, padding: 18, marginBottom: 14 }}>
      <Text accessibilityRole="header" style={{ color: paleta.texto, fontSize: 19, fontWeight: "800" }}>
        Mi foto de perfil
      </Text>
      <Text style={{ color: paleta.textoMedio, fontSize: 14, lineHeight: 21, marginTop: 6 }}>
        Es tu foto dentro de Ojo Guard. Se guarda solo en este teléfono y la podés cambiar cuando quieras.
      </Text>
      <View style={{ alignItems: "center", marginTop: 16 }}>
        {cargando ? (
          <ActivityIndicator color={azul} />
        ) : camaraAbierta ? (
          <View style={{ width: 200, height: 200, borderRadius: 100, overflow: "hidden", borderWidth: 4, borderColor: DORADO, backgroundColor: "#000" }}>
            <CameraView ref={camaraRef} facing="front" animateShutter={false} onCameraReady={() => setCamaraLista(true)} style={{ flex: 1 }} />
          </View>
        ) : mostrada ? (
          <Image source={{ uri: mostrada }} resizeMode="cover" style={{ width: 160, height: 160, borderRadius: 80, borderWidth: 4, borderColor: DORADO }} />
        ) : (
          <View style={{ width: 150, height: 150, borderRadius: 75, backgroundColor: azulSuave, borderWidth: 2, borderStyle: "dashed", borderColor: DORADO, alignItems: "center", justifyContent: "center" }}>
            <Icono nombre="persona" color={azul} tam={64} />
          </View>
        )}
      </View>
      {aviso ? (
        <Text accessibilityLiveRegion="polite" style={{ color: sinPermiso ? paleta.peligro : paleta.textoMedio, fontSize: 13.5, lineHeight: 19, marginTop: 12, textAlign: "center" }}>
          {aviso}
        </Text>
      ) : null}
      {ocupado && !camaraAbierta ? <ActivityIndicator color={azul} style={{ marginTop: 12 }} /> : null}
      <View style={{ gap: 10, marginTop: 16 }}>
        {camaraAbierta ? (
          <>
            {boton(camaraLista ? "Sacar la foto" : "Preparando la cámara…", () => void sacarConCamara(), { principal: true, deshabilitado: ocupado || !camaraLista })}
            {boton("Cancelar", () => setCamaraAbierta(false), { deshabilitado: ocupado })}
          </>
        ) : nuevaUri ? (
          <>
            {boton("Usar esta foto", () => void usarFoto(), { principal: true, deshabilitado: ocupado })}
            {boton("Sacar otra", () => void abrirCamara(), { deshabilitado: ocupado })}
            {boton("Cancelar", () => setNuevaUri(null), { deshabilitado: ocupado })}
          </>
        ) : (
          <>
            {boton(perfilUri ? "Cambiar con la cámara" : "Sacarme una foto", () => void abrirCamara(), { principal: true, deshabilitado: ocupado || cargando })}
            {boton("Elegir de la galería", () => void elegirDeGaleria(), { deshabilitado: ocupado || cargando })}
            {sinPermiso ? boton("Abrir ajustes del teléfono", () => void Linking.openSettings()) : null}
          </>
        )}
      </View>
    </View>
  );
}
