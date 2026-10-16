import { useCallback, useEffect, useState, type ComponentType, type ReactNode } from "react";
import { Alert, AppState, Linking, Platform, Pressable, StyleSheet, Text, TextInput, View, type StyleProp, type TextStyle, type ViewStyle } from "react-native";
import * as Location from "expo-location";

import { adjustFamilyLocation, familyLocationAllowed } from "./familyLocation";
import { markPendingSystemActivity } from "./pendingSystemActivity";
import { SosBlock } from "./SosBlock";
import { fetchFamily, joinFamily, leaveFamily, pauseFamilyLocation, type FamilyPerson } from "./remoteApi";
import { loadNativeEnrollment, type NativeEnrollment } from "./remoteStorage";

/**
 * La pantalla "Familia y amigos" (botón Familia de la barra de arriba), con el orden de la lista de Personas de "Buscar" de Apple:
 * primero quién está y cómo (en vivo, hace cuánto, dónde, batería), después lo que uno hace (sumarse con un código, pausar la propia
 * ubicación, pedir ayuda sin abrir la app, salir). Es el mismo contenido y las mismas funciones de antes (FamilySection.tsx), con
 * tres cambios de orden: sin el título repetido adentro (ya lo dice la cabecera), tocar a una persona la lleva al mapa del Inicio
 * (en Android y en iPhone; antes "Mapa ›" tapaba la etiqueta del rol) y cada cosa en su tarjeta con su título.
 *
 * Reemplaza a FamilySection en App.tsx con solo cambiar el import (exporta el mismo nombre y las mismas propiedades).
 */

type Paleta = { [clave: string]: string };

type Props = {
  paleta: Paleta;
  /** Ya no se usa (la pantalla no es un acordeón); se acepta para no cambiar App.tsx. */
  Seccion?: ComponentType<{ title: string; subtitle?: string; defaultOpen?: boolean; children: ReactNode }>;
  /** Al tocar a una persona: lleva al mapa del Inicio (si no se pasa, se abre Google Maps afuera, como antes). */
  onVerEnMapa?: () => void;
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

const VIVO_MS = 10 * 60_000;
const SIN_CONEXION_MS = 3 * 3600_000;

function haceCuanto(fecha: string | null) {
  if (!fecha) return "sin ubicación todavía";
  const s = Math.max(0, (Date.now() - new Date(fecha).getTime()) / 1000);
  if (s < 90) return "hace un momento";
  if (s < 3600) return `hace ${Math.round(s / 60)} min`;
  if (s < 86_400) return `hace ${Math.round(s / 3600)} h`;
  const dias = Math.round(s / 86_400);
  return `hace ${dias} ${dias === 1 ? "día" : "días"}`;
}

type Tono = "vivo" | "apagado" | "alerta" | "normal";

/** Cómo está esa persona, con las mismas reglas del mapa: en vivo (10 min), sin conexión (3 h sin señales) o hace cuánto. */
function estadoDe(p: FamilyPerson): { texto: string; tono: Tono } {
  if (p.paused) return { texto: "Ubicación pausada", tono: "apagado" };
  if (!p.lastLocationAt) return { texto: "Sin ubicación todavía", tono: "apagado" };
  const edad = Date.now() - new Date(p.lastLocationAt).getTime();
  const cuando = haceCuanto(p.lastLocationAt);
  if (edad <= VIVO_MS) return { texto: `En vivo · ${cuando}`, tono: "vivo" };
  if (!p.online && edad > SIN_CONEXION_MS) return { texto: `Sin conexión · ${cuando}`, tono: "alerta" };
  return { texto: cuando.charAt(0).toUpperCase() + cuando.slice(1), tono: "normal" };
}

// Abre a la persona en Google Maps (solo si la pantalla no recibe cómo ir al mapa del Inicio).
function abrirEnMapa(p: FamilyPerson) {
  const lat = Number(p.lastLocation?.latitude);
  const lng = Number(p.lastLocation?.longitude);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return;
  // Volver de Google Maps no tiene que mandar la app a la pantalla de bloqueo.
  markPendingSystemActivity();
  void Linking.openURL(`https://www.google.com/maps/search/?api=1&query=${lat},${lng}`).catch(() => undefined);
}

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
  const colorDeTono = (tono: Tono) => (tono === "vivo" ? P.exito : tono === "alerta" ? P.peligroFuerte : tono === "apagado" ? P.textoDebil : P.textoClaro);
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
            <Text style={s.etiqueta}>
              {people.length ? (people.length === 1 ? "1 PERSONA" : `${people.length} PERSONAS`) : "PERSONAS"}
            </Text>
            <Pressable accessibilityRole="button" hitSlop={10} onPress={() => { setMensaje(""); void cargar(enrollment); }}>
              <Text style={s.actualizar}>Actualizar</Text>
            </Pressable>
          </View>

          {people.length ? (
            <View style={s.tarjetaLista}>
              {people.map((p, i) => {
                const estado = estadoDe(p);
                const sePuedeVer = Boolean(p.lastLocation) && !p.paused;
                const direccion = p.paused ? "" : p.lastLocation?.address ?? "";
                const bateria = typeof p.battery === "number" && Number.isFinite(p.battery) ? Math.round(p.battery) : null;
                return (
                  <Pressable
                    key={p.id}
                    accessibilityRole="button"
                    accessibilityLabel={`${p.name}. ${estado.texto}${direccion ? `. ${direccion}` : ""}${sePuedeVer ? ". Ver en el mapa" : ""}`}
                    disabled={!sePuedeVer}
                    onPress={() => (onVerEnMapa ? onVerEnMapa() : abrirEnMapa(p))}
                    style={[s.fila, i > 0 && s.filaConLinea]}
                  >
                    <View style={[s.avatar, { borderColor: estado.tono === "vivo" ? P.exito : P.doradoBorde }]}>
                      <Text style={s.avatarTexto}>{(p.name || "?").trim()[0]?.toUpperCase() ?? "?"}</Text>
                    </View>
                    <View style={s.filaTexto}>
                      <View style={s.nombreFila}>
                        <Text numberOfLines={1} style={s.nombre}>{p.name}</Text>
                        {ROLES[p.role] && !p.owner ? <Text style={s.rol}>{ROLES[p.role]}</Text> : null}
                      </View>
                      <View style={s.estadoFila}>
                        <View style={[s.punto, { backgroundColor: colorDeTono(estado.tono) }]} />
                        <Text style={[s.estado, { color: colorDeTono(estado.tono) }]}>{estado.texto}</Text>
                      </View>
                      {direccion ? <Text numberOfLines={1} style={s.direccion}>{direccion}</Text> : null}
                    </View>
                    <View style={s.derecha}>
                      {bateria !== null ? <Text style={[s.bateria, bateria < 20 && { color: P.peligroFuerte }]}>{bateria} %</Text> : null}
                      {sePuedeVer ? <Text style={s.flecha}>{"›"}</Text> : null}
                    </View>
                  </Pressable>
                );
              })}
            </View>
          ) : (
            <View style={s.tarjeta}>
              <Text style={s.tarjetaTitulo}>Todavía no hay nadie</Text>
              <Text style={botones.ayuda}>
                Para sumar a alguien, invitalo desde el mapa del Inicio (el botón de invitar), o pedile a tu familia un código y escribilo más abajo.
              </Text>
            </View>
          )}

          {people.some((p) => p.lastLocation && !p.paused) ? <Text style={s.nota}>Tocá a una persona para verla en el mapa.</Text> : null}
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
    tarjetaLista: { backgroundColor: P.superficie, borderColor: P.borde, borderRadius: 18, borderWidth: 1, overflow: "hidden" },
    fila: { alignItems: "center", flexDirection: "row", gap: 12, minHeight: 72, paddingHorizontal: 14, paddingVertical: 12 },
    filaConLinea: { borderTopColor: P.borde, borderTopWidth: 1 },
    avatar: { alignItems: "center", backgroundColor: P.doradoFondo, borderRadius: 24, borderWidth: 2, height: 48, justifyContent: "center", width: 48 },
    avatarTexto: { color: P.doradoTexto, fontSize: 18, fontWeight: "800" },
    filaTexto: { flex: 1, gap: 2 },
    nombreFila: { alignItems: "center", flexDirection: "row", gap: 8 },
    nombre: { color: P.texto, flexShrink: 1, fontSize: 17, fontWeight: "800" },
    rol: { borderColor: P.doradoBorde, borderRadius: 6, borderWidth: 1, color: P.doradoTexto, fontSize: 10, fontWeight: "800", letterSpacing: 1, paddingHorizontal: 6, paddingVertical: 1 },
    estadoFila: { alignItems: "center", flexDirection: "row", gap: 6 },
    punto: { borderRadius: 4, height: 8, width: 8 },
    estado: { flexShrink: 1, fontSize: 13.5, fontWeight: "700" },
    direccion: { color: P.textoClaro, fontSize: 13 },
    derecha: { alignItems: "flex-end", gap: 2, minWidth: 34 },
    bateria: { color: P.textoClaro, fontSize: 12.5, fontWeight: "700" },
    flecha: { color: P.doradoTexto, fontSize: 26, lineHeight: 28 },
    nota: { color: P.textoDebil, fontSize: 12.5, marginTop: 8 },
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
