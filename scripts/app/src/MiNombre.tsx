import { useEffect, useState } from "react";
import { ActivityIndicator, Pressable, Text, TextInput, View } from "react-native";
import { loadNativeEnrollment } from "./remoteStorage";
import type { PaletaIdentidad } from "./VerificarIdentidad";

// Tarjeta "Mi nombre" dentro de Perfil: es como te ven las personas de tu circulo en el mapa y en las listas. Si no ponés ninguno, te ven con el
// nombre que te puso quien te invito. Se guarda en el servidor (el mismo para todos los que te ven).

const URL_API = "https://ojo-guard-ms-api.bickluciano.workers.dev";
const LARGO_MAXIMO = 30;

async function pedir(ruta: string, cuerpo?: Record<string, unknown>): Promise<{ ok: boolean; nombre: string | null }> {
  const enrollment = await loadNativeEnrollment();
  if (!enrollment) return { ok: false, nombre: null };
  const control = new AbortController();
  const corte = setTimeout(() => control.abort(), 20_000);
  try {
    const url = cuerpo ? `${URL_API}${ruta}` : `${URL_API}${ruta}?deviceId=${encodeURIComponent(enrollment.deviceId)}`;
    const respuesta = await fetch(url, {
      method: cuerpo ? "POST" : "GET",
      headers: { accept: "application/json", "content-type": "application/json", authorization: `Bearer ${enrollment.accessToken}` },
      ...(cuerpo ? { body: JSON.stringify({ deviceId: enrollment.deviceId, ...cuerpo }) } : {}),
      signal: control.signal,
    });
    if (!respuesta.ok) return { ok: false, nombre: null };
    const dato = (await respuesta.json().catch(() => ({}))) as { name?: string | null };
    return { ok: true, nombre: typeof dato.name === "string" && dato.name.trim() ? dato.name.trim() : null };
  } catch {
    return { ok: false, nombre: null };
  } finally {
    clearTimeout(corte);
  }
}

export function MiNombre({ paleta, noche }: { paleta: PaletaIdentidad; noche: boolean }) {
  const [valor, setValor] = useState("");
  const [guardado, setGuardado] = useState<string | null>(null);
  const [cargando, setCargando] = useState(true);
  const [ocupado, setOcupado] = useState(false);
  const [aviso, setAviso] = useState("");

  const azul = noche ? "#7C9CFF" : paleta.doradoRelleno;

  useEffect(() => {
    let vivo = true;
    void pedir("/api/native/profile-name").then((r) => {
      if (!vivo) return;
      setGuardado(r.nombre);
      setValor(r.nombre ?? "");
      setCargando(false);
    });
    return () => {
      vivo = false;
    };
  }, []);

  const limpio = valor.replace(/\s+/g, " ").trim();
  const sinCambios = limpio === (guardado ?? "");

  async function guardar(nombre: string) {
    if (ocupado) return;
    setOcupado(true);
    setAviso("");
    const r = await pedir("/api/native/profile-name", { name: nombre });
    setOcupado(false);
    if (!r.ok) {
      setAviso("No se pudo guardar el nombre. Revisá la conexión e intentá de nuevo.");
      return;
    }
    setGuardado(r.nombre);
    setValor(r.nombre ?? "");
    setAviso(r.nombre ? `Listo. Tu círculo te ve como "${r.nombre}".` : "Listo. Tu círculo te ve con el nombre que te puso quien te invitó.");
  }

  return (
    <View style={{ backgroundColor: paleta.superficie, borderRadius: 18, borderWidth: 1, borderColor: paleta.borde, padding: 18, marginBottom: 14 }}>
      <Text accessibilityRole="header" style={{ color: paleta.texto, fontSize: 19, fontWeight: "800" }}>
        Mi nombre
      </Text>
      <Text style={{ color: paleta.textoMedio, fontSize: 14, lineHeight: 21, marginTop: 6 }}>
        Así te ven las personas de tu círculo en el mapa y en las listas. Si no ponés ninguno, te ven con el nombre que te puso quien te invitó.
      </Text>
      {cargando ? (
        <ActivityIndicator color={azul} style={{ marginTop: 14 }} />
      ) : (
        <>
          <TextInput
            accessibilityLabel="Mi nombre"
            value={valor}
            onChangeText={(texto) => {
              setValor(texto.slice(0, LARGO_MAXIMO));
              setAviso("");
            }}
            maxLength={LARGO_MAXIMO}
            autoCapitalize="words"
            autoCorrect={false}
            placeholder="Cómo querés que te vean"
            placeholderTextColor={paleta.textoMedio}
            style={{ marginTop: 14, borderWidth: 1, borderColor: paleta.borde, borderRadius: 12, paddingHorizontal: 12, paddingVertical: 11, fontSize: 16, color: paleta.texto }}
          />
          {aviso ? (
            <Text accessibilityLiveRegion="polite" style={{ color: paleta.textoMedio, fontSize: 13.5, lineHeight: 19, marginTop: 10 }}>
              {aviso}
            </Text>
          ) : null}
          <View style={{ gap: 10, marginTop: 14 }}>
            <Pressable
              accessibilityRole="button"
              disabled={ocupado || sinCambios || !limpio}
              onPress={() => void guardar(limpio)}
              style={{ borderRadius: 14, paddingVertical: 14, alignItems: "center", backgroundColor: azul, opacity: ocupado || sinCambios || !limpio ? 0.45 : 1 }}
            >
              <Text style={{ color: paleta.sobreDorado, fontSize: 15, fontWeight: "800" }}>{ocupado ? "Guardando…" : "Guardar mi nombre"}</Text>
            </Pressable>
            {guardado ? (
              <Pressable
                accessibilityRole="button"
                disabled={ocupado}
                onPress={() => void guardar("")}
                style={{ borderRadius: 14, paddingVertical: 14, alignItems: "center", borderWidth: 1.5, borderColor: azul, opacity: ocupado ? 0.45 : 1 }}
              >
                <Text style={{ color: azul, fontSize: 15, fontWeight: "800" }}>Quitar mi nombre</Text>
              </Pressable>
            ) : null}
          </View>
        </>
      )}
    </View>
  );
}
