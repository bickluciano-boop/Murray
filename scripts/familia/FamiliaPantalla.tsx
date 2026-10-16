import { useCallback, useEffect, useState, type ComponentType, type ReactNode } from "react";
import { Alert, AppState, Linking, Platform, Pressable, StyleSheet, Text, TextInput, View, type StyleProp, type TextStyle, type ViewStyle } from "react-native";
import * as Location from "expo-location";

import { adjustFamilyLocation, familyLocationAllowed } from "./familyLocation";
import { markPendingSystemActivity } from "./pendingSystemActivity";
import { SosBlock } from "./SosBlock";
import { fetchFamily, joinFamily, leaveFamily, pauseFamilyLocation, type FamilyPerson } from "./remoteApi";
import { loadNativeEnrollment, type NativeEnrollment } from "./remoteStorage";

/**
 * "Familia y amigos", un grupo de Ajustes (tarjeta ancha de arriba). Las personas ya se ven, con cómo están y qué se puede hacer con cada una,
 * en el mapa del Inicio (y ahí mismo se suma gente con el botón «Sumar»), así que acá no se repite la lista. Quedan las cosas que el mapa no
 * hace: cuántas personas comparten su ubicación con vos, el aviso del iPhone («Siempre»), pausar la propia ubicación, el SOS y sus ayudas para
 * pedirlo sin abrir la app, unirse a una familia con un código y salir de una familia. Son las mismas funciones de antes (FamilySection.tsx).
 *
 * Reemplaza a FamilySection en App.tsx con solo cambiar el import (exporta el mismo nombre y las mismas propiedades).
 */

type Paleta = { [clave: string]: string };

type Props = {
  paleta: Paleta;
  /** Ya no se usa (la pantalla no es un acordeón); se acepta para no cambiar App.tsx. */
  Seccion?: ComponentType<{ title: string; subtitle?: string; defaultOpen?: boolean; children: ReactNode }>;
  /** Lleva al mapa del Inicio, donde se ve y se suma a la gente. */
  onVerEnMapa?: () => void;
  botones: {
    primario: StyleProp<ViewStyle>;
    primarioTexto: StyleProp<TextStyle>;
    secundario: StyleProp<ViewStyle>;
    secundarioTexto: StyleProp<TextStyle>;
    ayuda: StyleProp<TextStyle>;
  };
};

const ERRORES: Record<string, string> = {
  invalid_code: "El código tiene 6 letras o números.",
  code_not_found_or_expired: "Ese código no existe o ya venció. Pedí uno nuevo.",
  own_family: "Ese código es de tu propia familia.",
  minor_cannot_pause: "Como menor, tu ubicación no se puede pausar.",
  unauthorized: "Este teléfono no está vinculado con Ojo Guard MS.",
};

function mensajeDeError(error: unknown) {
  const clave = error instanceof Error ? error.message : "";
  return ERRORES[clave] ?? "No se pudo conectar con Ojo Guard MS. Probá de nuevo.";
}

export function FamilySection({ paleta: P, botones, onVerEnMapa }: Props) {
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

  // Cualquiera puede salir de una familia, tambien un menor (al titular le llega un correo).
  // Si alguien te puso como Menor sin que corresponda, desde aca te vas.
  function confirmarSalir(p: FamilyPerson) {
    Alert.alert(
      `¿Salir de la familia de ${p.name}?`,
      "Dejás de ver a esa familia en el mapa y ellos dejan de verte. Para volver, te tienen que mandar una invitación nueva.",
      [
        { text: "Cancelar", style: "cancel" },
        { text: "Salir", style: "destructive", onPress: () => void salir(p) },
      ],
    );
  }

  async function salir(p: FamilyPerson) {
    if (!enrollment) return;
    setOcupado(true);
    setMensaje("");
    try {
      await leaveFamily(enrollment, p.id);
      setMensaje(`Saliste de la familia de ${p.name}.`);
      await cargar(enrollment);
      void adjustFamilyLocation();
    } catch (error) {
      setMensaje(mensajeDeError(error));
    } finally {
      setOcupado(false);
    }
  }

  const s = estilos(P);
  const codigoListo = codigo.replace(/[^A-Z0-9]/g, "").length === 6;
  const hayFamilia = me.memberships > 0 || people.length > 0;

  return (
    <View>
      {enrollment === null ? (
        <View style={s.tarjeta}>
          <Text style={s.tarjetaTitulo}>Falta vincular este teléfono</Text>
          <Text style={botones.ayuda}>Vinculá este teléfono con Ojo Guard MS (en Ajustes, en «Ojo Guard MS») para ver a tu familia.</Text>
        </View>
      ) : null}

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

      {enrollment ? (
        <>
          <View style={s.etiquetaFila}>
            <Text style={s.etiqueta}>MI FAMILIA</Text>
            <Pressable accessibilityRole="button" hitSlop={10} onPress={() => { setMensaje(""); void cargar(enrollment); }}>
              <Text style={s.actualizar}>Actualizar</Text>
            </Pressable>
          </View>
          <View style={s.tarjeta}>
            <Text style={s.tarjetaTitulo}>
              {people.length ? `${people.length} ${people.length === 1 ? "persona comparte" : "personas comparten"} su ubicación con vos` : "Todavía no hay nadie"}
            </Text>
            <Text style={botones.ayuda}>
              {people.length
                ? "Las ves en el mapa del Inicio, con cómo están y lo que podés hacer con cada una. Para sumar a alguien, tocá «Sumar» en la lista de abajo del mapa."
                : "Para sumar a alguien, tocá «Sumar» en la lista de abajo del mapa del Inicio, o pedile a tu familia un código y escribilo más abajo."}
            </Text>
            {onVerEnMapa ? (
              <Pressable accessibilityRole="button" onPress={onVerEnMapa} style={botones.secundario}>
                <Text style={botones.secundarioTexto}>Ir al mapa</Text>
              </Pressable>
            ) : null}
          </View>
        </>
      ) : null}

      {me.memberships > 0 ? (
        <>
          <Text style={s.etiqueta}>MI UBICACIÓN</Text>
          <View style={s.tarjeta}>
            {me.isMinor ? (
              <Text style={botones.ayuda}>
                Compartís tu ubicación con tu familia. Tus tutores pueden ver dónde estás; siempre vas a ver acá con quién la compartís.
              </Text>
            ) : (
              <>
                <Text style={botones.ayuda}>Tu familia ve dónde estás. Podés pausarlo un rato y volver a compartir cuando quieras.</Text>
                <View style={s.pausaFila}>
                  <Pressable accessibilityRole="button" disabled={ocupado} onPress={() => void pausar(60)} style={[botones.secundario, s.botonMitad]}>
                    <Text adjustsFontSizeToFit numberOfLines={1} style={botones.secundarioTexto}>Pausar 1 hora</Text>
                  </Pressable>
                  <Pressable accessibilityRole="button" disabled={ocupado} onPress={() => void pausar(0)} style={[botones.secundario, s.botonMitad]}>
                    <Text adjustsFontSizeToFit numberOfLines={1} style={botones.secundarioTexto}>Reanudar</Text>
                  </Pressable>
                </View>
              </>
            )}
          </View>
        </>
      ) : null}

      {hayFamilia ? (
        <>
          <Text style={s.etiqueta}>SOS Y AYUDA</Text>
          <View style={s.tarjeta}>
            {/* El SOS trae su propio espacio de arriba (18 y 8): se descuenta para que no quede un hueco dentro de la tarjeta. */}
            <View style={s.sinHueco}>
              <SosBlock enrollment={enrollment} visible paleta={P} botones={botones} />
            </View>
          </View>
        </>
      ) : null}

      {enrollment ? (
        <>
          <Text style={s.etiqueta}>UNIRME A UNA FAMILIA</Text>
          <View style={s.tarjeta}>
            <Text style={botones.ayuda}>Si alguien te invitó, escribí acá el código de 6 letras o números que te mandó.</Text>
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
                disabled={ocupado || !codigoListo}
                onPress={() => void unirme()}
                style={[botones.primario, s.boton, (ocupado || !codigoListo) && s.apagado]}
              >
                <Text style={botones.primarioTexto}>Unirme</Text>
              </Pressable>
            </View>
          </View>
        </>
      ) : null}

      {mensaje ? <Text style={s.mensaje}>{mensaje}</Text> : null}

      {people.filter((p) => p.owner).map((p) => (
        <Pressable key={`salir-${p.id}`} accessibilityRole="button" disabled={ocupado} onPress={() => confirmarSalir(p)} style={s.salirFila}>
          <Text style={s.salir}>Salir de la familia de {p.name}</Text>
        </Pressable>
      ))}
    </View>
  );
}

function estilos(P: Paleta) {
  return StyleSheet.create({
    etiquetaFila: { alignItems: "center", flexDirection: "row", justifyContent: "space-between", marginBottom: 8, marginTop: 4 },
    etiqueta: { color: P.textoDebil, fontSize: 12, fontWeight: "800", letterSpacing: 1.1, marginBottom: 8, marginTop: 20 },
    actualizar: { color: P.doradoTexto, fontSize: 14, fontWeight: "700" },
    tarjeta: { backgroundColor: P.superficie, borderColor: P.borde, borderRadius: 18, borderWidth: 1, gap: 10, padding: 16 },
    sinHueco: { marginTop: -26 },
    tarjetaTitulo: { color: P.texto, fontSize: 16, fontWeight: "800" },
    codigoFila: { alignItems: "center", flexDirection: "row", gap: 8 },
    codigo: { backgroundColor: P.campo, borderColor: P.bordeMedio, borderRadius: 12, borderWidth: 1, color: P.texto, flex: 1, minWidth: 0, fontSize: 20, fontWeight: "700", letterSpacing: 6, paddingHorizontal: 14, paddingVertical: 12 },
    boton: { flexShrink: 0, paddingHorizontal: 18 },
    apagado: { opacity: 0.45 },
    pausaFila: { flexDirection: "row", gap: 8 },
    botonMitad: { alignItems: "center", flex: 1, justifyContent: "center" },
    espacio: { marginTop: 12 },
    mensaje: { color: P.doradoTexto, fontSize: 14, lineHeight: 20, marginTop: 14 },
    salirFila: { paddingVertical: 12 },
    salir: { color: P.textoClaro, fontSize: 13.5, fontWeight: "600", textDecorationLine: "underline" },
    aviso: { backgroundColor: P.doradoFondo, borderColor: P.doradoBorde, borderRadius: 12, borderWidth: 1, marginBottom: 12, padding: 12 },
    avisoTexto: { color: P.texto, fontSize: 13, lineHeight: 18 },
  });
}
