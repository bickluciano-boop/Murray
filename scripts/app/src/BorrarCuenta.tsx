import { useState } from "react";
import { ActivityIndicator, BackHandler, Modal, Platform, Pressable, SafeAreaView, Text, TextInput, View } from "react-native";
import AsyncStorage from "@react-native-async-storage/async-storage";
import * as FileSystem from "expo-file-system/legacy";
import { clearEvidenceHistory } from "./evidenceHistory";
import { clearNativeEnrollment, loadNativeEnrollment } from "./remoteStorage";
import type { PaletaIdentidad } from "./VerificarIdentidad";

// "Borrar mi cuenta" (Apple exige poder hacerlo dentro de la app). Pide escribir BORRAR, le pide al servidor que borre todo lo de esta cuenta
// y recien cuando el servidor confirma limpia este telefono (vinculo, historial de evidencias, identidad y ajustes).

const URL_API = "https://ojo-guard-ms-api.bickluciano.workers.dev";
const PALABRA = "BORRAR";

type Resultado = { ok: true; parcial: boolean } | { ok: false; mensaje: string };

async function borrarEnServidor(): Promise<Resultado> {
  const enrollment = await loadNativeEnrollment();
  if (!enrollment) return { ok: false, mensaje: "Este teléfono no está vinculado a una cuenta, así que no hay nada para borrar desde acá." };
  const control = new AbortController();
  const corte = setTimeout(() => control.abort(), 60_000);
  try {
    const respuesta = await fetch(`${URL_API}/api/native/account/delete`, {
      method: "POST",
      headers: { accept: "application/json", "content-type": "application/json", authorization: `Bearer ${enrollment.accessToken}` },
      body: JSON.stringify({ deviceId: enrollment.deviceId, confirm: PALABRA }),
      signal: control.signal,
    });
    const dato = (await respuesta.json().catch(() => ({}))) as { ok?: boolean; parcial?: boolean; error?: string };
    if (respuesta.ok && dato.ok === true) return { ok: true, parcial: dato.parcial === true };
    if (respuesta.status === 401 || dato.error === "unauthorized") return { ok: false, mensaje: "Este teléfono ya no está vinculado a la cuenta. Entrá con tu código y volvé a intentar." };
    return { ok: false, mensaje: "No se pudo borrar la cuenta ahora. No se borró nada: probá de nuevo en unos minutos." };
  } catch {
    return { ok: false, mensaje: "Sin conexión. No se borró nada: revisá internet y probá de nuevo." };
  } finally {
    clearTimeout(corte);
  }
}

async function limpiarTelefono() {
  await clearEvidenceHistory().catch(() => undefined);
  const base = FileSystem.documentDirectory;
  if (base) await FileSystem.deleteAsync(`${base}ojo-identidad/`, { idempotent: true }).catch(() => undefined);
  await clearNativeEnrollment().catch(() => undefined);
  await AsyncStorage.clear().catch(() => undefined);
}

export function BorrarCuenta({ paleta, noche }: { paleta: PaletaIdentidad; noche: boolean }) {
  const [abierto, setAbierto] = useState(false);
  const [texto, setTexto] = useState("");
  const [ocupado, setOcupado] = useState(false);
  const [aviso, setAviso] = useState("");
  const [terminado, setTerminado] = useState<"completo" | "parcial" | null>(null);

  const rojo = noche ? "#FF8A7A" : paleta.peligro;
  const habilitado = texto.trim().toUpperCase() === PALABRA && !ocupado;

  async function confirmar() {
    if (!habilitado) return;
    setOcupado(true);
    setAviso("");
    try {
      const r = await borrarEnServidor();
      if (!r.ok) {
        setAviso(r.mensaje);
        return;
      }
      await limpiarTelefono();
      setTerminado(r.parcial ? "parcial" : "completo");
    } finally {
      setOcupado(false);
    }
  }

  const tarjeta = { backgroundColor: paleta.superficie, borderRadius: 18, borderWidth: 1, borderColor: paleta.borde, padding: 18, marginBottom: 14 } as const;

  if (terminado) {
    const mensaje =
      (terminado === "parcial"
        ? "Se borró casi todo. Si querés que revisemos que no quede nada, escribinos a soporte@ojoguard.app. "
        : "Borramos tus equipos, ubicaciones, evidencias, familia, avisos y foto de perfil. ") +
      (Platform.OS === "android" ? "Cerrá Ojo Guard para terminar." : "Deslizá hacia arriba para cerrar Ojo Guard.");
    return (
      <Modal animationType="fade" onRequestClose={() => undefined} presentationStyle="fullScreen" visible>
        <SafeAreaView style={{ flex: 1, backgroundColor: paleta.fondo, justifyContent: "center", paddingHorizontal: 28 }}>
          <Text accessibilityRole="header" style={{ color: paleta.texto, fontSize: 28, fontWeight: "700", letterSpacing: -0.5 }}>
            Tu cuenta se borró
          </Text>
          <Text style={{ color: paleta.textoMedio, fontSize: 16, lineHeight: 24, marginTop: 14 }}>{mensaje}</Text>
          <Text style={{ color: paleta.textoDebil, fontSize: 13.5, lineHeight: 20, marginTop: 12 }}>
            Para volver a usar Ojo Guard, abrila de nuevo y creá una cuenta nueva.
          </Text>
          {Platform.OS === "android" ? (
            <Pressable
              accessibilityRole="button"
              onPress={() => BackHandler.exitApp()}
              style={{ height: 54, borderRadius: 27, alignItems: "center", justifyContent: "center", backgroundColor: paleta.doradoRelleno, marginTop: 28 }}
            >
              <Text style={{ color: paleta.sobreDorado, fontSize: 16, fontWeight: "800" }}>Cerrar Ojo Guard</Text>
            </Pressable>
          ) : null}
        </SafeAreaView>
      </Modal>
    );
  }

  return (
    <View style={tarjeta}>
      <Text accessibilityRole="header" style={{ color: paleta.texto, fontSize: 19, fontWeight: "800" }}>
        Borrar mi cuenta
      </Text>
      <Text style={{ color: paleta.textoMedio, fontSize: 14, lineHeight: 21, marginTop: 6 }}>
        Borra para siempre todo lo tuyo en Ojo Guard. No se puede deshacer.
      </Text>
      {abierto ? (
        <View style={{ marginTop: 14, gap: 10 }}>
          <Text style={{ color: paleta.texto, fontSize: 14, lineHeight: 21 }}>
            Se borran tus equipos, ubicaciones, evidencias (fotos y audios), tu familia y sus avisos, tu verificación de identidad y tu foto de perfil. Quienes invitaste dejan de verte, y vos dejás de ver a tu familia. Después de borrar, para volver a usar la app hay que abrir una cuenta nueva.
          </Text>
          <Text style={{ color: paleta.textoMedio, fontSize: 13.5 }}>Para confirmar, escribí {PALABRA}:</Text>
          <TextInput
            accessibilityLabel="Escribí BORRAR para confirmar"
            autoCapitalize="characters"
            autoCorrect={false}
            editable={!ocupado}
            onChangeText={setTexto}
            placeholder={PALABRA}
            placeholderTextColor={paleta.textoDebil}
            style={{ borderWidth: 1.5, borderColor: rojo, borderRadius: 14, paddingHorizontal: 14, height: 48, color: paleta.texto, fontSize: 16, letterSpacing: 2 }}
            value={texto}
          />
          {aviso ? (
            <Text accessibilityLiveRegion="polite" style={{ color: rojo, fontSize: 13.5, lineHeight: 19 }}>
              {aviso}
            </Text>
          ) : null}
          {ocupado ? <ActivityIndicator color={rojo} /> : null}
          <Pressable
            accessibilityRole="button"
            disabled={!habilitado}
            onPress={() => void confirmar()}
            style={{ height: 50, borderRadius: 25, alignItems: "center", justifyContent: "center", backgroundColor: rojo, opacity: habilitado ? 1 : 0.4 }}
          >
            <Text style={{ color: noche ? "#2B0B07" : "#FFFFFF", fontSize: 15, fontWeight: "800" }}>Borrar todo definitivamente</Text>
          </Pressable>
          <Pressable
            accessibilityRole="button"
            disabled={ocupado}
            onPress={() => {
              setAbierto(false);
              setTexto("");
              setAviso("");
            }}
            style={{ height: 50, borderRadius: 25, alignItems: "center", justifyContent: "center", borderWidth: 1.5, borderColor: paleta.borde, opacity: ocupado ? 0.45 : 1 }}
          >
            <Text style={{ color: paleta.texto, fontSize: 15, fontWeight: "800" }}>Cancelar</Text>
          </Pressable>
        </View>
      ) : (
        <Pressable
          accessibilityRole="button"
          onPress={() => setAbierto(true)}
          style={{ height: 50, borderRadius: 25, alignItems: "center", justifyContent: "center", borderWidth: 1.5, borderColor: rojo, marginTop: 14 }}
        >
          <Text style={{ color: rojo, fontSize: 15, fontWeight: "800" }}>Borrar mi cuenta</Text>
        </Pressable>
      )}
    </View>
  );
}
