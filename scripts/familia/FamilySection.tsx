import { useCallback, useEffect, useState, type ComponentType, type ReactNode } from "react";
import { AppState, Linking, Platform, Pressable, StyleSheet, Text, TextInput, View, type StyleProp, type TextStyle, type ViewStyle } from "react-native";
import * as Location from "expo-location";
import MapView, { Marker } from "react-native-maps";

import { adjustFamilyLocation, familyLocationAllowed } from "./familyLocation";
import { markPendingSystemActivity } from "./pendingSystemActivity";
import { fetchFamily, joinFamily, pauseFamilyLocation, type FamilyPerson } from "./remoteApi";
import { loadNativeEnrollment, type NativeEnrollment } from "./remoteStorage";

/**
 * Familia y amigos, etapa A, dentro de Configuración: ver a la familia en el
 * mapa, unirse con el código de una invitación y pausar la propia ubicación
 * (adultos y amigos; los menores no pueden).
 *
 * En iPhone, además, avisa si falta el permiso de ubicación "Siempre": sin él
 * la familia solo ve dónde estaba la persona la última vez que abrió la app
 * (ver familyLocation.ts).
 *
 * Vive en un archivo aparte para no agrandar App.tsx: recibe de ahí la paleta,
 * la sección plegable y los estilos de los botones, así se ve igual que el resto
 * de Configuración y cambia con el tema claro u oscuro.
 */

type Paleta = { [clave: string]: string };

type Props = {
  paleta: Paleta;
  Seccion: ComponentType<{ title: string; subtitle?: string; defaultOpen?: boolean; children: ReactNode }>;
  botones: {
    primario: StyleProp<ViewStyle>;
    primarioTexto: StyleProp<TextStyle>;
    secundario: StyleProp<ViewStyle>;
    secundarioTexto: StyleProp<TextStyle>;
    ayuda: StyleProp<TextStyle>;
  };
};

const ROLES: Record<string, string> = { adulto: "ADULTO", menor: "MENOR", amigo: "AMIGO" };

const ERRORES: Record<string, string> = {
  invalid_code: "El código tiene 6 letras o números.",
  code_not_found_or_expired: "Ese código no existe o ya venció. Pedí uno nuevo.",
  own_family: "Ese código es de tu propia familia.",
  minor_cannot_pause: "Como menor, tu ubicación no se puede pausar.",
  unauthorized: "Este teléfono no está vinculado con Ojo Guard MS.",
};

function haceCuanto(fecha: string | null) {
  if (!fecha) return "sin ubicación todavía";
  const s = Math.max(0, (Date.now() - new Date(fecha).getTime()) / 1000);
  if (s < 90) return "hace un momento";
  if (s < 3600) return `hace ${Math.round(s / 60)} min`;
  if (s < 86_400) return `hace ${Math.round(s / 3600)} h`;
  return `hace ${Math.round(s / 86_400)} días`;
}

function mensajeDeError(error: unknown) {
  const clave = error instanceof Error ? error.message : "";
  return ERRORES[clave] ?? "No se pudo conectar con Ojo Guard MS. Probá de nuevo.";
}

export function FamilySection({ paleta: P, Seccion, botones }: Props) {
  const [enrollment, setEnrollment] = useState<NativeEnrollment | null | undefined>(undefined);
  const [people, setPeople] = useState<FamilyPerson[]>([]);
  const [me, setMe] = useState<{ memberships: number; isMinor: boolean }>({ memberships: 0, isMinor: false });
  const [codigo, setCodigo] = useState("");
  const [ocupado, setOcupado] = useState(false);
  const [mensaje, setMensaje] = useState("");
  const [siempre, setSiempre] = useState(true);

  const cargar = useCallback(async (vinculo: NativeEnrollment) => {
    try {
      const datos = await fetchFamily(vinculo);
      setPeople(datos.people);
      setMe(datos.me);
    } catch (error) {
      setMensaje(mensajeDeError(error));
    }
  }, []);

  // Se vuelve a mirar al regresar de Ajustes, así el aviso se va solo apenas se da el permiso.
  useEffect(() => {
    const revisar = () => void familyLocationAllowed().then(setSiempre);
    revisar();
    const suscripcion = AppState.addEventListener("change", (estado) => {
      if (estado === "active") revisar();
    });
    return () => suscripcion.remove();
  }, []);

  useEffect(() => {
    void loadNativeEnrollment().then((vinculo) => {
      setEnrollment(vinculo);
      if (vinculo) void cargar(vinculo);
    });
  }, [cargar]);

  async function unirme() {
    if (!enrollment) return;
    setOcupado(true);
    setMensaje("");
    try {
      const r = await joinFamily(enrollment, codigo);
      setCodigo("");
      setMensaje(`Listo: ya estás en la familia${r.role === "menor" ? ". Tus tutores van a poder ver dónde estás." : "."}`);
      await cargar(enrollment);
      void adjustFamilyLocation();
    } catch (error) {
      setMensaje(mensajeDeError(error));
    } finally {
      setOcupado(false);
    }
  }

  async function permitirSiempre() {
    const primero = await Location.requestForegroundPermissionsAsync().catch(() => null);
    const fondo = primero?.granted ? await Location.requestBackgroundPermissionsAsync().catch(() => null) : null;
    if (fondo?.granted) {
      setSiempre(true);
      void adjustFamilyLocation();
      return;
    }
    // iPhone lo pregunta una sola vez; si ya se contestó, se cambia en Ajustes.
    // Volver de Ajustes no tiene que mandar la app a la pantalla de bloqueo.
    markPendingSystemActivity();
    void Linking.openSettings();
  }

  async function pausar(minutos: number) {
    if (!enrollment) return;
    setOcupado(true);
    try {
      await pauseFamilyLocation(enrollment, minutos);
      setMensaje(minutos ? "Tu ubicación queda pausada por 1 hora. Tu familia ve «Ubicación pausada»." : "Volviste a compartir tu ubicación.");
    } catch (error) {
      setMensaje(mensajeDeError(error));
    } finally {
      setOcupado(false);
    }
  }

  const s = estilos(P);
  const conUbicacion = people.filter(
    (p) => !p.paused && Number.isFinite(Number(p.lastLocation?.latitude)) && Number.isFinite(Number(p.lastLocation?.longitude)),
  );
  const lats = conUbicacion.map((p) => Number(p.lastLocation?.latitude));
  const lngs = conUbicacion.map((p) => Number(p.lastLocation?.longitude));
  const region = conUbicacion.length
    ? {
        latitude: (Math.min(...lats) + Math.max(...lats)) / 2,
        longitude: (Math.min(...lngs) + Math.max(...lngs)) / 2,
        latitudeDelta: Math.max(0.01, (Math.max(...lats) - Math.min(...lats)) * 1.6),
        longitudeDelta: Math.max(0.01, (Math.max(...lngs) - Math.min(...lngs)) * 1.6),
      }
    : null;

  return (
    <Seccion
      defaultOpen
      title="Familia y amigos"
      subtitle={people.length ? `${people.length} ${people.length === 1 ? "persona comparte" : "personas comparten"} su ubicación con vos` : "Compartí la ubicación con tu familia"}
    >
      {enrollment === null ? (
        <Text style={botones.ayuda}>Vinculá este teléfono con Ojo Guard MS (más abajo) para usar Familia.</Text>
      ) : null}

      {region ? (
        <View style={s.mapa}>
          <MapView initialRegion={region} style={StyleSheet.absoluteFill}>
            {conUbicacion.map((p) => (
              <Marker
                key={p.id}
                coordinate={{ latitude: Number(p.lastLocation?.latitude), longitude: Number(p.lastLocation?.longitude) }}
                title={p.name}
                description={p.lastLocation?.address ?? undefined}
                pinColor={P.doradoTexto}
              />
            ))}
          </MapView>
        </View>
      ) : null}

      {people.map((p) => (
        <View key={p.id} style={s.fila}>
          <View style={s.avatar}>
            <Text style={s.avatarTexto}>{(p.name || "?").trim()[0]?.toUpperCase() ?? "?"}</Text>
          </View>
          <View style={s.filaTexto}>
            <View style={s.nombreFila}>
              <Text style={s.nombre}>{p.name}</Text>
              {ROLES[p.role] && !p.owner ? <Text style={s.rol}>{ROLES[p.role]}</Text> : null}
            </View>
            <Text style={s.detalle} numberOfLines={1}>
              {p.paused ? "Ubicación pausada" : [haceCuanto(p.lastLocationAt), p.lastLocation?.address].filter(Boolean).join(" · ")}
            </Text>
          </View>
        </View>
      ))}

      {Platform.OS === "ios" && people.length > 0 && !siempre ? (
        <View style={s.aviso}>
          <Text style={s.avisoTexto}>
            Para que tu familia te vea aunque Ojo Guard esté cerrada, el iPhone tiene que permitir la ubicación «Siempre».
          </Text>
          <Pressable accessibilityRole="button" onPress={() => void permitirSiempre()} style={[botones.primario, s.espacio]}>
            <Text style={botones.primarioTexto}>Permitir siempre</Text>
          </Pressable>
        </View>
      ) : null}

      {enrollment && !people.length && !me.memberships ? (
        <Text style={botones.ayuda}>Todavía no hay nadie. Para sumar a alguien, invitalo desde el mapa de Ojo Guard MS, o pedile a tu familia un código y escribilo acá abajo.</Text>
      ) : null}

      {enrollment ? (
        <>
          <Text style={s.titulo}>Unirme con un código</Text>
          <View style={s.codigoFila}>
            <TextInput
              autoCapitalize="characters"
              autoCorrect={false}
              maxLength={7}
              onChangeText={(texto) => setCodigo(texto.toUpperCase())}
              placeholder="ABC234"
              placeholderTextColor={P.marcador}
              style={s.codigo}
              value={codigo}
            />
            <Pressable
              accessibilityRole="button"
              disabled={ocupado || codigo.replace(/[^A-Z0-9]/g, "").length !== 6}
              onPress={() => void unirme()}
              style={[botones.primario, s.boton, (ocupado || codigo.replace(/[^A-Z0-9]/g, "").length !== 6) && s.apagado]}
            >
              <Text style={botones.primarioTexto}>Unirme</Text>
            </Pressable>
          </View>
        </>
      ) : null}

      {me.memberships > 0 ? (
        me.isMinor ? (
          <Text style={[botones.ayuda, s.espacio]}>
            Compartís tu ubicación con tu familia. Tus tutores pueden ver dónde estás; siempre vas a ver acá con quién la compartís.
          </Text>
        ) : (
          <View style={s.pausaFila}>
            <Pressable accessibilityRole="button" disabled={ocupado} onPress={() => void pausar(60)} style={[botones.secundario, s.botonMitad]}>
              <Text style={botones.secundarioTexto}>Pausar 1 hora</Text>
            </Pressable>
            <Pressable accessibilityRole="button" disabled={ocupado} onPress={() => void pausar(0)} style={[botones.secundario, s.botonMitad]}>
              <Text style={botones.secundarioTexto}>Compartir de nuevo</Text>
            </Pressable>
          </View>
        )
      ) : null}

      {enrollment ? (
        <Pressable accessibilityRole="button" onPress={() => { setMensaje(""); void cargar(enrollment); }} style={[botones.secundario, s.espacio]}>
          <Text style={botones.secundarioTexto}>Actualizar</Text>
        </Pressable>
      ) : null}

      {mensaje ? <Text style={[s.mensaje]}>{mensaje}</Text> : null}
    </Seccion>
  );
}

function estilos(P: Paleta) {
  return StyleSheet.create({
    mapa: { height: 220, borderRadius: 14, overflow: "hidden", marginBottom: 12, backgroundColor: P.mapaFondo },
    fila: { flexDirection: "row", alignItems: "center", gap: 12, paddingVertical: 9, borderBottomWidth: 1, borderBottomColor: P.borde },
    avatar: { width: 38, height: 38, borderRadius: 19, alignItems: "center", justifyContent: "center", backgroundColor: P.doradoFondo, borderWidth: 2, borderColor: P.doradoBorde },
    avatarTexto: { color: P.doradoTexto, fontWeight: "700", fontSize: 15 },
    filaTexto: { flex: 1 },
    nombreFila: { flexDirection: "row", alignItems: "center", gap: 8 },
    nombre: { color: P.texto, fontSize: 15, fontWeight: "600" },
    rol: { color: P.doradoTexto, fontSize: 9, fontWeight: "700", letterSpacing: 1.2, borderWidth: 1, borderColor: P.doradoBorde, borderRadius: 6, paddingHorizontal: 5, paddingVertical: 1 },
    detalle: { color: P.textoSuave, fontSize: 12, marginTop: 2 },
    titulo: { color: P.textoSuave, fontSize: 13, fontWeight: "600", marginTop: 16, marginBottom: 8 },
    codigoFila: { flexDirection: "row", gap: 8, alignItems: "center" },
    codigo: { flex: 1, color: P.texto, backgroundColor: P.campo, borderWidth: 1, borderColor: P.bordeMedio, borderRadius: 12, paddingHorizontal: 14, paddingVertical: 12, fontSize: 20, letterSpacing: 6, fontWeight: "700" },
    boton: { paddingHorizontal: 18 },
    apagado: { opacity: 0.45 },
    pausaFila: { flexDirection: "row", gap: 8, marginTop: 14 },
    botonMitad: { flex: 1 },
    espacio: { marginTop: 12 },
    mensaje: { color: P.doradoTexto, fontSize: 13, marginTop: 12, lineHeight: 18 },
    aviso: { marginTop: 12, padding: 12, borderRadius: 12, borderWidth: 1, borderColor: P.doradoBorde, backgroundColor: P.doradoFondo },
    avisoTexto: { color: P.texto, fontSize: 13, lineHeight: 18 },
  });
}
