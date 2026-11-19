import { useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import { ActivityIndicator, Alert, Image, KeyboardAvoidingView, Linking, Modal, Platform, Pressable, SafeAreaView, ScrollView, Text, TextInput, View } from "react-native";
import { CameraView, useCameraPermissions } from "expo-camera";
import * as ImagePicker from "expo-image-picker";

import {
  MAX_CONTACTOS,
  alternarEnLista,
  borrarFoto,
  borrarTarjeta,
  cargarMedicamentos,
  cargarTarjeta,
  edadDe,
  enLista,
  fechaDeTexto,
  formatearFechaEscrita,
  guardarFotoCredencial,
  guardarTarjeta,
  limpiarTelefono,
  numeroParaLlamar,
  rutaFoto,
  tarjetaConDatos,
  tarjetaVacia,
  textoDeFecha,
  textoSangre,
  type DonanteOrganos,
  type FactorSangre,
  type GrupoSangre,
  type ListaMedicamentos,
  type TarjetaSalud,
} from "./tarjetaSalud";
import { avisarCamaraAbierta, soltarAvisoCamara } from "./VerificarIdentidad";

/**
 * TARJETA DE SALUD (fase 1). Una sola pantalla con dos modos: VER (la tarjeta lista para mostrarle a un médico: la sangre grande arriba, las alergias
 * resaltadas, los medicamentos, la obra social con la foto de la credencial, y botones para llamar) y EDITAR (el formulario). Todo queda en este
 * teléfono (ver tarjetaSalud.ts). Para la credencial se usa la cámara propia de la app (en algunos Android, como Xiaomi, abrir la cámara del sistema
 * saca a la app) o la galería, con el aviso a la guardia de siempre.
 */

type Paleta = { [clave: string]: string };

const ATAJOS_ALERGIAS = ["Penicilina", "Sulfas", "Aspirina", "Ibuprofeno", "Dipirona", "Látex", "Mariscos", "Frutos secos", "Ninguna conocida"];
const ATAJOS_CONDICIONES = ["Diabetes", "Hipertensión", "Asma", "Epilepsia", "Marcapasos", "Anticoagulado", "Cardiopatía", "Embarazo"];
const SANGRES: Array<{ valor: GrupoSangre; texto: string }> = [
  { valor: "A", texto: "A" },
  { valor: "B", texto: "B" },
  { valor: "AB", texto: "AB" },
  { valor: "O", texto: "O" },
  { valor: "no-se", texto: "No sé" },
];

/** ¿El color de fondo es oscuro? (para que el resaltado de las alergias se lea tanto con el tema claro como con el noche) */
function esOscuro(hex: string): boolean {
  const m = /^#?([0-9a-f]{6})/i.exec(hex.trim());
  if (!m || !m[1]) return false;
  const n = parseInt(m[1], 16);
  return (0.299 * ((n >> 16) & 255) + 0.587 * ((n >> 8) & 255) + 0.114 * (n & 255)) / 255 < 0.5;
}

function colores(p: Paleta) {
  const c = (clave: string, defecto: string) => p[clave] ?? defecto;
  const oscuro = esOscuro(c("fondo", "#FAF8F2"));
  return {
    fondo: c("fondo", "#FAF8F2"),
    superficie: c("superficieHonda", c("superficie", "#FFFFFF")),
    texto: c("texto", "#14213D"),
    suave: c("textoSuave", "#4A5578"),
    tenue: c("textoTenue", "#6B7390"),
    borde: c("borde", "#DFE4F0"),
    dorado: c("doradoTexto", "#8A6A1F"),
    doradoFondo: c("doradoFondo", "#FFF6DC"),
    doradoBorde: c("doradoBorde", "#E5C877"),
    exito: c("exito", "#1F6B3A"),
    // Rojo para textos y bordes de alerta (más claro con el tema noche) y rojo fijo y profundo para el cuadro de la sangre (siempre con texto blanco).
    peligro: oscuro ? "#FF8A80" : c("peligro", "#B3261E"),
    peligroFondo: oscuro ? "#3B1613" : "#FDECEA",
    sangre: "#B3261E",
  };
}

function fechaLarga(iso: string | null): string {
  if (!iso) return "";
  const f = new Date(iso);
  if (Number.isNaN(f.getTime())) return "";
  const d = String(f.getDate()).padStart(2, "0"), m = String(f.getMonth() + 1).padStart(2, "0");
  return `${d}/${m}/${f.getFullYear()}`;
}

type Props = { visible: boolean; onCerrar: () => void; paleta: Paleta };
type LadoFoto = "frente" | "dorso";

export function TarjetaSaludPantalla({ visible, onCerrar, paleta }: Props) {
  const c = useMemo(() => colores(paleta), [paleta]);
  const [cargando, setCargando] = useState(true);
  const [modo, setModo] = useState<"ver" | "editar">("ver");
  const [tarjeta, setTarjeta] = useState<TarjetaSalud>(tarjetaVacia());
  const [borrador, setBorrador] = useState<TarjetaSalud>(tarjetaVacia());
  const [fechaTexto, setFechaTexto] = useState("");
  const [meds, setMeds] = useState<ListaMedicamentos | null>(null);
  const [aviso, setAviso] = useState("");
  const [ocupado, setOcupado] = useState(false);
  const [zoom, setZoom] = useState<string | null>(null);
  const [fotosRotas, setFotosRotas] = useState<string[]>([]);
  // Cámara propia de la app para la credencial.
  const [camara, setCamara] = useState<LadoFoto | null>(null);
  const [camaraLista, setCamaraLista] = useState(false);
  const [permisoCamara, pedirPermisoCamara] = useCameraPermissions();
  const camaraRef = useRef<CameraView>(null);
  const [pendiente, setPendiente] = useState<{ lado: LadoFoto; uri: string } | null>(null);
  const creadas = useRef<string[]>([]);

  useEffect(() => {
    if (!visible) return;
    let vivo = true;
    setCargando(true);
    setAviso("");
    setZoom(null);
    setCamara(null);
    setPendiente(null);
    setFotosRotas([]);
    setMeds(null);
    setModo("ver");
    void cargarTarjeta().then((t) => {
      if (!vivo) return;
      setTarjeta(t);
      setCargando(false);
    });
    void cargarMedicamentos().then((m) => {
      if (vivo) setMeds(m);
    });
    return () => {
      vivo = false;
    };
  }, [visible]);

  function empezarEdicion() {
    creadas.current = [];
    setBorrador({ ...tarjeta, contactos: tarjeta.contactos.map((x) => ({ ...x })) });
    setFechaTexto(textoDeFecha(tarjeta.nacimiento));
    setAviso("");
    setModo("editar");
  }

  async function cancelarEdicion() {
    for (const nombre of creadas.current) await borrarFoto(nombre);
    creadas.current = [];
    setCamara(null);
    setPendiente(null);
    setAviso("");
    setModo("ver");
  }

  async function guardar() {
    if (ocupado) return;
    const iso = fechaTexto.trim() ? fechaDeTexto(fechaTexto) : "";
    if (fechaTexto.trim() && !iso) {
      setAviso("La fecha de nacimiento no es válida. Escríbela así: DD/MM/AAAA.");
      return;
    }
    setOcupado(true);
    try {
      const guardada = await guardarTarjeta({ ...borrador, nacimiento: iso });
      if (!guardada) {
        setAviso("No se pudo guardar. Revisa que el teléfono tenga espacio y prueba de nuevo.");
        return;
      }
      // Las fotos que ya no se usan (la anterior cambiada, o las sacadas y descartadas en esta edición) se borran del teléfono.
      const vigentes = [guardada.credencialFrente, guardada.credencialDorso];
      for (const vieja of [tarjeta.credencialFrente, tarjeta.credencialDorso, ...creadas.current]) {
        if (vieja && !vigentes.includes(vieja)) await borrarFoto(vieja);
      }
      creadas.current = [];
      setTarjeta(guardada);
      setFotosRotas([]);
      setAviso("");
      setModo("ver");
    } finally {
      setOcupado(false);
    }
  }

  function confirmarBorrado() {
    Alert.alert(
      "Borrar la tarjeta de salud",
      "Se borran de este teléfono todos los datos y las fotos de la credencial. No se puede deshacer.",
      [
        { text: "Cancelar", style: "cancel" },
        {
          text: "Borrar",
          style: "destructive",
          onPress: () => {
            void borrarTarjeta().then(() => {
              setTarjeta(tarjetaVacia());
              setBorrador(tarjetaVacia());
              setFechaTexto("");
              setMeds(null);
              setModo("ver");
              void cargarMedicamentos().then(setMeds);
            });
          },
        },
      ],
    );
  }

  // ---- Foto de la credencial ----
  async function abrirCamara(lado: LadoFoto) {
    if (ocupado) return;
    setAviso("");
    let concedido = permisoCamara?.granted === true;
    if (!concedido) {
      const respuesta = await pedirPermisoCamara().catch(() => null);
      concedido = respuesta?.granted === true;
    }
    if (!concedido) {
      setAviso("Se necesita el permiso de la cámara para sacar la foto. Actívalo en los ajustes del teléfono.");
      return;
    }
    setPendiente(null);
    setCamaraLista(false);
    setCamara(lado);
  }

  async function sacarFoto() {
    if (ocupado || !camaraLista || !camara) return;
    setOcupado(true);
    try {
      const sacar = () => camaraRef.current?.takePictureAsync({ base64: false, quality: 0.8, skipProcessing: false });
      let foto = await Promise.resolve(sacar()).catch(() => null);
      if (!foto?.uri) {
        await new Promise<void>((listo) => setTimeout(listo, 700));
        foto = await Promise.resolve(sacar()).catch(() => null);
      }
      if (foto?.uri) {
        setPendiente({ lado: camara, uri: foto.uri });
        setCamara(null);
      } else {
        setAviso("No se pudo sacar la foto. Prueba de nuevo.");
      }
    } finally {
      setOcupado(false);
    }
  }

  async function elegirDeGaleria(lado: LadoFoto) {
    if (ocupado) return;
    setOcupado(true);
    setAviso("");
    try {
      avisarCamaraAbierta();
      const resultado = await ImagePicker.launchImageLibraryAsync({ mediaTypes: ["images"], quality: 0.85 });
      const uri = resultado.canceled ? null : (resultado.assets[0]?.uri ?? null);
      if (uri) setPendiente({ lado, uri });
    } catch {
      setAviso("No se pudo abrir la galería. Prueba de nuevo.");
    } finally {
      soltarAvisoCamara();
      setOcupado(false);
    }
  }

  async function usarFoto() {
    if (!pendiente || ocupado) return;
    setOcupado(true);
    try {
      const nombre = await guardarFotoCredencial(pendiente.uri, pendiente.lado);
      if (!nombre) {
        setAviso("No se pudo guardar la foto. Revisa que el teléfono tenga espacio y prueba de nuevo.");
        return;
      }
      creadas.current.push(nombre);
      setBorrador((b) => (pendiente.lado === "frente" ? { ...b, credencialFrente: nombre } : { ...b, credencialDorso: nombre }));
      setPendiente(null);
    } finally {
      setOcupado(false);
    }
  }

  const cambiar = <K extends keyof TarjetaSalud>(clave: K, valor: TarjetaSalud[K]) => setBorrador((b) => ({ ...b, [clave]: valor }));
  const cambiarContacto = (i: number, campo: "nombre" | "parentesco" | "telefono", valor: string) =>
    setBorrador((b) => ({ ...b, contactos: b.contactos.map((x, j) => (j === i ? { ...x, [campo]: campo === "telefono" ? limpiarTelefono(valor) : valor } : x)) }));

  function llamar(numero: string) {
    const marcar = numeroParaLlamar(numero);
    if (!marcar) return;
    void Linking.openURL(`tel:${marcar}`).catch(() => setAviso("No se pudo abrir el teléfono para llamar."));
  }

  // ---- Piezas de pantalla ----
  const boton = (texto: string, alPresionar: () => void, opciones: { principal?: boolean; peligro?: boolean; deshabilitado?: boolean; etiqueta?: string } = {}) => (
    <Pressable
      accessibilityLabel={opciones.etiqueta ?? texto}
      accessibilityRole="button"
      accessibilityState={{ disabled: Boolean(opciones.deshabilitado) }}
      disabled={opciones.deshabilitado}
      onPress={alPresionar}
      style={{
        minHeight: 48,
        borderRadius: 14,
        paddingHorizontal: 16,
        alignItems: "center",
        justifyContent: "center",
        backgroundColor: opciones.principal ? c.dorado : "transparent",
        borderWidth: opciones.principal ? 0 : 1.5,
        borderColor: opciones.peligro ? c.peligro : c.dorado,
        opacity: opciones.deshabilitado ? 0.45 : 1,
      }}
    >
      <Text style={{ color: opciones.principal ? "#FFFFFF" : opciones.peligro ? c.peligro : c.dorado, fontSize: 15.5, fontWeight: "800" }}>{texto}</Text>
    </Pressable>
  );

  const bloque = (titulo: string, hijos: ReactNode, resaltado = false) => (
    <View
      style={{
        backgroundColor: resaltado ? c.peligroFondo : c.superficie,
        borderColor: resaltado ? c.peligro : c.borde,
        borderRadius: 16,
        borderWidth: 1,
        padding: 16,
        marginBottom: 12,
        gap: 6,
      }}
    >
      <Text accessibilityRole="header" style={{ color: resaltado ? c.peligro : c.dorado, fontSize: 12.5, fontWeight: "900", letterSpacing: 1, textTransform: "uppercase" }}>
        {titulo}
      </Text>
      {hijos}
    </View>
  );

  const dato = (etiqueta: string, valor: string) =>
    valor ? (
      <Text key={etiqueta} style={{ color: c.texto, fontSize: 16, lineHeight: 23 }}>
        <Text style={{ color: c.suave, fontWeight: "700" }}>{etiqueta}: </Text>
        {valor}
      </Text>
    ) : null;

  const miniatura = (nombre: string, titulo: string) => {
    const ruta = rutaFoto(nombre);
    if (!nombre) return null;
    const rota = !ruta || fotosRotas.includes(nombre);
    return (
      <Pressable
        key={nombre}
        accessibilityLabel={`${titulo}. Toca para ampliar`}
        accessibilityRole="imagebutton"
        disabled={rota}
        onPress={() => ruta && setZoom(ruta)}
        style={{ flex: 1, minWidth: 130 }}
      >
        <Text style={{ color: c.suave, fontSize: 12.5, fontWeight: "700", marginBottom: 4 }}>{titulo}</Text>
        {rota ? (
          <View style={{ height: 110, borderRadius: 10, borderWidth: 1, borderColor: c.borde, alignItems: "center", justifyContent: "center", padding: 8 }}>
            <Text style={{ color: c.tenue, fontSize: 12.5, textAlign: "center" }}>No se encontró la foto en este teléfono. Vuelve a cargarla.</Text>
          </View>
        ) : (
          <Image
            onError={() => setFotosRotas((r) => [...r, nombre])}
            resizeMode="cover"
            source={{ uri: ruta ?? "" }}
            style={{ height: 110, borderRadius: 10, borderWidth: 1, borderColor: c.borde, backgroundColor: "#00000010" }}
          />
        )}
      </Pressable>
    );
  };

  // ---- Cámara / vista previa de la credencial (ocupan toda la pantalla) ----
  function pantallaFoto() {
    if (camara) {
      return (
        <View style={{ flex: 1, backgroundColor: "#000" }}>
          <CameraView ref={camaraRef} animateShutter={false} facing="back" onCameraReady={() => setCamaraLista(true)} style={{ flex: 1 }} />
          <View style={{ backgroundColor: c.fondo, gap: 10, padding: 16 }}>
            <Text style={{ color: c.suave, fontSize: 14, textAlign: "center" }}>
              Credencial, {camara === "frente" ? "frente" : "dorso"}: que se lea bien todo el texto.
            </Text>
            {boton(camaraLista ? "Sacar la foto" : "Preparando la cámara…", () => void sacarFoto(), { principal: true, deshabilitado: ocupado || !camaraLista })}
            {boton("Cancelar", () => setCamara(null), { deshabilitado: ocupado })}
          </View>
        </View>
      );
    }
    if (pendiente) {
      return (
        <View style={{ flex: 1, backgroundColor: c.fondo }}>
          <Image resizeMode="contain" source={{ uri: pendiente.uri }} style={{ flex: 1, backgroundColor: "#000" }} />
          <View style={{ gap: 10, padding: 16 }}>
            {boton("Usar esta foto", () => void usarFoto(), { principal: true, deshabilitado: ocupado })}
            {boton("Sacar otra", () => void abrirCamara(pendiente.lado), { deshabilitado: ocupado })}
            {boton("Cancelar", () => setPendiente(null), { deshabilitado: ocupado })}
          </View>
        </View>
      );
    }
    return null;
  }

  // ---- MODO VER ----
  function vista() {
    const t = tarjeta;
    const sangre = textoSangre(t);
    const edad = edadDe(t.nacimiento);
    const contactos = t.contactos.filter((x) => x.nombre || x.telefono);
    const vacia = !tarjetaConDatos(t);
    if (vacia) {
      return (
        <View style={{ gap: 14, paddingVertical: 24 }}>
          <Text style={{ color: c.texto, fontSize: 22, fontWeight: "900" }}>Tu tarjeta de salud está vacía</Text>
          <Text style={{ color: c.suave, fontSize: 16, lineHeight: 24 }}>
            Carga una sola vez lo que te piden en una emergencia: grupo sanguíneo, alergias, medicamentos, obra social y a quién avisar. Queda guardada solo en este
            teléfono y la tienes a mano cuando la necesites.
          </Text>
          {boton("Cargar mis datos", empezarEdicion, { principal: true })}
        </View>
      );
    }
    return (
      <View>
        <View style={{ alignItems: "center", flexDirection: "row", gap: 14, marginBottom: 14 }}>
          <View
            accessibilityLabel={sangre ? `Grupo sanguíneo ${sangre}` : "Grupo sanguíneo sin cargar"}
            style={{ alignItems: "center", backgroundColor: sangre ? c.sangre : c.borde, borderRadius: 18, justifyContent: "center", minWidth: 92, paddingHorizontal: 10, paddingVertical: 14 }}
          >
            <Text style={{ color: sangre ? "#FFFFFF" : c.tenue, fontSize: sangre && sangre.length > 3 ? 22 : 34, fontWeight: "900" }}>{sangre || "—"}</Text>
            <Text style={{ color: sangre ? "#FFFFFF" : c.tenue, fontSize: 11.5, fontWeight: "800" }}>SANGRE</Text>
          </View>
          <View style={{ flex: 1 }}>
            <Text style={{ color: c.texto, fontSize: 22, fontWeight: "900" }}>{t.nombre || "Sin nombre"}</Text>
            {edad !== null || t.nacimiento ? (
              <Text style={{ color: c.suave, fontSize: 15.5 }}>
                {edad !== null ? `${edad} años` : ""}
                {edad !== null && t.nacimiento ? " · " : ""}
                {t.nacimiento ? textoDeFecha(t.nacimiento) : ""}
              </Text>
            ) : null}
            {t.documento ? <Text style={{ color: c.suave, fontSize: 15.5 }}>DNI {t.documento}</Text> : null}
          </View>
        </View>

        {t.alergias ? bloque("Alergias", <Text style={{ color: c.texto, fontSize: 17, fontWeight: "700", lineHeight: 24 }}>{t.alergias}</Text>, true) : null}
        {t.condiciones ? bloque("Condiciones médicas", <Text style={{ color: c.texto, fontSize: 16.5, lineHeight: 24 }}>{t.condiciones}</Text>) : null}

        {bloque(
          "Medicamentos",
          <>
            {meds === null ? <ActivityIndicator color={c.dorado} style={{ alignSelf: "flex-start" }} /> : null}
            {meds && meds.items.length === 0 && !t.otrosMedicamentos ? (
              <Text style={{ color: c.tenue, fontSize: 15, lineHeight: 22 }}>No hay medicamentos cargados. Se cargan en Medicamentos y aparecen aquí.</Text>
            ) : null}
            {meds?.items.map((m) => (
              <Text key={m.nombre} style={{ color: c.texto, fontSize: 16.5, lineHeight: 24 }}>
                • {m.nombre}
                {m.horas.length ? <Text style={{ color: c.suave }}>{`  (${m.horas.join(", ")} h)`}</Text> : null}
              </Text>
            ))}
            {t.otrosMedicamentos ? dato("Otros", t.otrosMedicamentos) : null}
            {meds?.desdeCopia && meds.copiadaEn ? (
              <Text style={{ color: c.tenue, fontSize: 12.5 }}>Sin conexión: lista guardada el {fechaLarga(meds.copiadaEn)}.</Text>
            ) : null}
          </>,
        )}

        {t.obraSocial || t.plan || t.afiliado || t.telefonoObraSocial || t.credencialFrente || t.credencialDorso
          ? bloque(
              "Cobertura de salud",
              <>
                {dato("Obra social", t.obraSocial)}
                {dato("Plan", t.plan)}
                {dato("N.º de afiliado", t.afiliado)}
                {t.telefonoObraSocial ? (
                  <View style={{ alignItems: "flex-start", gap: 6 }}>
                    {dato("Urgencias", t.telefonoObraSocial)}
                    {boton("Llamar a la obra social", () => llamar(t.telefonoObraSocial))}
                  </View>
                ) : null}
                {t.credencialFrente || t.credencialDorso ? (
                  <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 10, marginTop: 6 }}>
                    {miniatura(t.credencialFrente, "Credencial, frente")}
                    {miniatura(t.credencialDorso, "Credencial, dorso")}
                  </View>
                ) : null}
              </>,
            )
          : null}

        {t.medico || t.telefonoMedico
          ? bloque(
              "Médico de cabecera",
              <>
                {dato("Nombre", t.medico)}
                {dato("Teléfono", t.telefonoMedico)}
                {t.telefonoMedico ? boton("Llamar al médico", () => llamar(t.telefonoMedico)) : null}
              </>,
            )
          : null}

        {contactos.length
          ? bloque(
              "Avisar a",
              <>
                {contactos.map((x, i) => (
                  <View key={`${x.nombre}-${i}`} style={{ gap: 6, marginBottom: 6 }}>
                    <Text style={{ color: c.texto, fontSize: 16.5, fontWeight: "700" }}>
                      {x.nombre || "Sin nombre"}
                      {x.parentesco ? <Text style={{ color: c.suave, fontWeight: "400" }}>{`  (${x.parentesco})`}</Text> : null}
                    </Text>
                    {x.telefono ? (
                      <View style={{ alignItems: "flex-start", gap: 6 }}>
                        <Text style={{ color: c.suave, fontSize: 15.5 }}>{x.telefono}</Text>
                        {boton(`Llamar a ${x.nombre || "este contacto"}`, () => llamar(x.telefono))}
                      </View>
                    ) : null}
                  </View>
                ))}
              </>,
            )
          : null}

        {t.donante || t.cirugias || t.instrucciones
          ? bloque(
              "Otros datos",
              <>
                {t.donante ? dato("Donante de órganos", t.donante === "si" ? "Sí" : t.donante === "no" ? "No" : "No sé") : null}
                {dato("Cirugías o implantes", t.cirugias)}
                {dato("Instrucciones importantes", t.instrucciones)}
              </>,
            )
          : null}

        <Text style={{ color: c.tenue, fontSize: 12.5, lineHeight: 18, marginTop: 4, textAlign: "center" }}>
          {t.actualizada ? `Actualizada el ${fechaLarga(t.actualizada)}. ` : ""}Esta tarjeta está solo en este teléfono: no se envía a ningún servidor.
        </Text>
        <View style={{ gap: 10, marginTop: 14 }}>
          {boton("Editar mis datos", empezarEdicion, { principal: true })}
          {boton("Borrar la tarjeta", confirmarBorrado, { peligro: true })}
        </View>
      </View>
    );
  }

  // ---- MODO EDITAR ----
  const campo = (etiqueta: string, valor: string, alCambiar: (v: string) => void, opciones: { teclado?: "default" | "numeric" | "phone-pad"; multilinea?: boolean; ayuda?: string; max?: number } = {}) => (
    <View style={{ gap: 4 }}>
      <Text style={{ color: c.suave, fontSize: 13.5, fontWeight: "700" }}>{etiqueta}</Text>
      <TextInput
        accessibilityLabel={etiqueta}
        autoCapitalize={opciones.teclado ? "none" : "sentences"}
        keyboardType={opciones.teclado ?? "default"}
        maxLength={opciones.max}
        multiline={opciones.multilinea}
        onChangeText={alCambiar}
        placeholder={opciones.ayuda}
        placeholderTextColor={c.tenue}
        style={{
          backgroundColor: c.fondo,
          borderColor: c.borde,
          borderRadius: 12,
          borderWidth: 1,
          color: c.texto,
          fontSize: 16,
          minHeight: opciones.multilinea ? 84 : 48,
          paddingHorizontal: 12,
          paddingVertical: 10,
          textAlignVertical: opciones.multilinea ? "top" : "center",
        }}
        value={valor}
      />
    </View>
  );

  const chip = (texto: string, activo: boolean, alPresionar: () => void) => (
    <Pressable
      key={texto}
      accessibilityRole="button"
      accessibilityState={{ selected: activo }}
      onPress={alPresionar}
      style={{
        backgroundColor: activo ? c.dorado : "transparent",
        borderColor: c.dorado,
        borderRadius: 999,
        borderWidth: 1.5,
        paddingHorizontal: 13,
        paddingVertical: 8,
      }}
    >
      <Text style={{ color: activo ? "#FFFFFF" : c.dorado, fontSize: 14.5, fontWeight: "800" }}>{texto}</Text>
    </Pressable>
  );

  const fotoEditable = (lado: LadoFoto, nombre: string) => {
    const titulo = lado === "frente" ? "Credencial, frente" : "Credencial, dorso";
    return (
      <View key={lado} style={{ gap: 8 }}>
        {nombre ? <View style={{ flexDirection: "row" }}>{miniatura(nombre, titulo)}</View> : <Text style={{ color: c.suave, fontSize: 13.5, fontWeight: "700" }}>{titulo}: sin foto</Text>}
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 8 }}>
          {boton(nombre ? "Sacar otra" : "Sacar foto", () => void abrirCamara(lado), { deshabilitado: ocupado })}
          {boton("Elegir de la galería", () => void elegirDeGaleria(lado), { deshabilitado: ocupado })}
          {nombre ? boton("Quitar", () => cambiar(lado === "frente" ? "credencialFrente" : "credencialDorso", ""), { peligro: true, deshabilitado: ocupado }) : null}
        </View>
      </View>
    );
  };

  function formulario() {
    const b = borrador;
    return (
      <View>
        {bloque(
          "Datos personales",
          <View style={{ gap: 10 }}>
            {campo("Nombre completo", b.nombre, (v) => cambiar("nombre", v), { max: 80 })}
            {campo("Fecha de nacimiento", fechaTexto, (v) => setFechaTexto(formatearFechaEscrita(v)), { teclado: "numeric", ayuda: "DD/MM/AAAA", max: 10 })}
            {campo("DNI", b.documento, (v) => cambiar("documento", v), { teclado: "numeric", max: 20 })}
          </View>,
        )}

        {bloque(
          "Grupo sanguíneo",
          <View style={{ gap: 10 }}>
            <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 8 }}>
              {SANGRES.map((s) => chip(s.texto, b.sangre === s.valor, () => setBorrador((x) => ({ ...x, sangre: x.sangre === s.valor ? "" : s.valor, factor: s.valor === "no-se" ? "" : x.factor }))))}
            </View>
            {b.sangre && b.sangre !== "no-se" ? (
              <View style={{ flexDirection: "row", gap: 8 }}>
                {(["+", "-"] as FactorSangre[]).map((f) => chip(f === "+" ? "Positivo (+)" : "Negativo (−)", b.factor === f, () => cambiar("factor", b.factor === f ? "" : f)))}
              </View>
            ) : null}
          </View>,
        )}

        {bloque(
          "Alergias",
          <View style={{ gap: 10 }}>
            <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 8 }}>
              {ATAJOS_ALERGIAS.map((a) => chip(a, enLista(b.alergias, a), () => cambiar("alergias", alternarEnLista(b.alergias, a))))}
            </View>
            {campo("Alergias (puedes escribir otras)", b.alergias, (v) => cambiar("alergias", v), { multilinea: true, max: 400 })}
          </View>,
        )}

        {bloque(
          "Condiciones médicas",
          <View style={{ gap: 10 }}>
            <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 8 }}>
              {ATAJOS_CONDICIONES.map((a) => chip(a, enLista(b.condiciones, a), () => cambiar("condiciones", alternarEnLista(b.condiciones, a))))}
            </View>
            {campo("Enfermedades o condiciones", b.condiciones, (v) => cambiar("condiciones", v), { multilinea: true, max: 400 })}
          </View>,
        )}

        {bloque(
          "Medicamentos",
          <View style={{ gap: 10 }}>
            <Text style={{ color: c.suave, fontSize: 14, lineHeight: 20 }}>
              Los medicamentos que ya cargaste en Medicamentos aparecen solos en la tarjeta, no hay que escribirlos otra vez.
              {meds && meds.items.length ? ` Hoy hay ${meds.items.length}.` : ""}
            </Text>
            {campo("Otros medicamentos (los que tomas de vez en cuando)", b.otrosMedicamentos, (v) => cambiar("otrosMedicamentos", v), { multilinea: true, max: 300 })}
          </View>,
        )}

        {bloque(
          "Cobertura de salud",
          <View style={{ gap: 10 }}>
            {campo("Obra social o prepaga", b.obraSocial, (v) => cambiar("obraSocial", v), { max: 60 })}
            {campo("Plan", b.plan, (v) => cambiar("plan", v), { max: 40 })}
            {campo("Número de afiliado", b.afiliado, (v) => cambiar("afiliado", v), { max: 30 })}
            {campo("Teléfono de urgencias de la obra social", b.telefonoObraSocial, (v) => cambiar("telefonoObraSocial", limpiarTelefono(v)), { teclado: "phone-pad", max: 25 })}
            {fotoEditable("frente", b.credencialFrente)}
            {fotoEditable("dorso", b.credencialDorso)}
          </View>,
        )}

        {bloque(
          "Médico de cabecera",
          <View style={{ gap: 10 }}>
            {campo("Nombre", b.medico, (v) => cambiar("medico", v), { max: 80 })}
            {campo("Teléfono", b.telefonoMedico, (v) => cambiar("telefonoMedico", limpiarTelefono(v)), { teclado: "phone-pad", max: 25 })}
          </View>,
        )}

        {bloque(
          "Avisar a (contactos de emergencia)",
          <View style={{ gap: 14 }}>
            <Text style={{ color: c.suave, fontSize: 14, lineHeight: 20 }}>
              Personas a quienes llamar si te pasa algo. Son aparte de los referentes del SOS de Ojo Guard: estos aparecen solo en esta tarjeta.
            </Text>
            {Array.from({ length: MAX_CONTACTOS }, (_, i) => {
              const x = b.contactos[i];
              if (!x) return null;
              return (
                <View key={i} style={{ gap: 8 }}>
                  <Text style={{ color: c.dorado, fontSize: 13, fontWeight: "900" }}>Contacto {i + 1}</Text>
                  {campo("Nombre", x.nombre, (v) => cambiarContacto(i, "nombre", v), { max: 60 })}
                  {campo("Parentesco (hijo, pareja, amigo…)", x.parentesco, (v) => cambiarContacto(i, "parentesco", v), { max: 30 })}
                  {campo("Teléfono", x.telefono, (v) => cambiarContacto(i, "telefono", v), { teclado: "phone-pad", max: 25 })}
                </View>
              );
            })}
          </View>,
        )}

        {bloque(
          "Otros datos",
          <View style={{ gap: 10 }}>
            <Text style={{ color: c.suave, fontSize: 13.5, fontWeight: "700" }}>Donante de órganos</Text>
            <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 8 }}>
              {([["si", "Sí"], ["no", "No"], ["no-se", "No sé"]] as Array<[DonanteOrganos, string]>).map(([valor, texto]) => chip(texto, b.donante === valor, () => cambiar("donante", b.donante === valor ? "" : valor)))}
            </View>
            {campo("Cirugías o implantes importantes", b.cirugias, (v) => cambiar("cirugias", v), { multilinea: true, max: 400 })}
            {campo("Instrucciones importantes (por ejemplo: no acepto transfusiones)", b.instrucciones, (v) => cambiar("instrucciones", v), { multilinea: true, max: 400 })}
          </View>,
        )}

        <View style={{ gap: 10, marginTop: 6 }}>
          {boton(ocupado ? "Guardando…" : "Guardar", () => void guardar(), { principal: true, deshabilitado: ocupado })}
          {boton("Cancelar", () => void cancelarEdicion(), { deshabilitado: ocupado })}
        </View>
      </View>
    );
  }

  const contenidoFoto = pantallaFoto();

  return (
    <Modal animationType="slide" onRequestClose={() => (modo === "editar" ? void cancelarEdicion() : onCerrar())} transparent={false} visible={visible}>
      <SafeAreaView style={{ backgroundColor: c.fondo, flex: 1 }}>
        {contenidoFoto ?? (
          <KeyboardAvoidingView behavior={Platform.OS === "ios" ? "padding" : undefined} style={{ flex: 1 }}>
            <View style={{ alignItems: "center", borderBottomColor: c.borde, borderBottomWidth: 1, flexDirection: "row", justifyContent: "space-between", paddingHorizontal: 16, paddingVertical: 12 }}>
              <Text accessibilityRole="header" style={{ color: c.texto, fontSize: 20, fontWeight: "900" }}>
                {modo === "editar" ? "Editar tarjeta de salud" : "Tarjeta de salud"}
              </Text>
              <Pressable accessibilityLabel={modo === "editar" ? "Cancelar la edición" : "Cerrar"} accessibilityRole="button" onPress={() => (modo === "editar" ? void cancelarEdicion() : onCerrar())} style={{ minHeight: 44, justifyContent: "center", paddingHorizontal: 8 }}>
                <Text style={{ color: c.dorado, fontSize: 16, fontWeight: "800" }}>{modo === "editar" ? "Cancelar" : "Cerrar"}</Text>
              </Pressable>
            </View>
            <ScrollView contentContainerStyle={{ padding: 16, paddingBottom: 40 }} keyboardShouldPersistTaps="handled">
              {aviso ? (
                <Text accessibilityLiveRegion="polite" style={{ backgroundColor: c.doradoFondo, borderColor: c.doradoBorde, borderRadius: 12, borderWidth: 1, color: c.texto, fontSize: 14.5, lineHeight: 21, marginBottom: 12, padding: 12 }}>
                  {aviso}
                </Text>
              ) : null}
              {cargando ? <ActivityIndicator color={c.dorado} style={{ marginTop: 40 }} /> : modo === "editar" ? formulario() : vista()}
            </ScrollView>
          </KeyboardAvoidingView>
        )}
        {zoom ? (
          <Pressable
            accessibilityLabel="Cerrar la foto ampliada"
            accessibilityRole="button"
            onPress={() => setZoom(null)}
            style={{ backgroundColor: "#000000EE", bottom: 0, justifyContent: "center", left: 0, position: "absolute", right: 0, top: 0 }}
          >
            <Image resizeMode="contain" source={{ uri: zoom }} style={{ height: "80%", width: "100%" }} />
            <Text style={{ color: "#FFFFFF", fontSize: 14, marginTop: 10, textAlign: "center" }}>Toca para cerrar</Text>
          </Pressable>
        ) : null}
      </SafeAreaView>
    </Modal>
  );
}
