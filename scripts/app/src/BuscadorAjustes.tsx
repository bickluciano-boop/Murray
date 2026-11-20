import { useMemo, useState } from "react";
import { Modal, Platform, Pressable, ScrollView, StatusBar, Text, TextInput, View } from "react-native";

import { abrirDesdeBuscador } from "./aperturasAjustes";
import { BUSQUEDAS_FRECUENTES, NOMBRE_DE_GRUPO, buscarEnAjustes } from "./indiceBusqueda";

/**
 * "Buscar en Ajustes": un cuadro arriba de Ajustes que abre una hoja con el teclado listo. Reconoce lo que se escribe mientras se escribe, sin importar tildes,
 * mayúsculas ni errores de tipeo, y al tocar un resultado lleva a la sección (el grupo de Ajustes donde está). No cambia ninguna sección ni el mapa.
 * Va en una hoja propia (no dentro de la pantalla con scroll) para que el primer toque en un resultado funcione aunque el teclado esté abierto.
 */

type Paleta = { [clave: string]: string };

export function BuscadorAjustes({ paleta, android, onElegir }: { paleta: Paleta; android: boolean; onElegir: (grupo: string) => void }) {
  const [abierto, setAbierto] = useState(false);
  const [consulta, setConsulta] = useState("");
  const c = {
    fondo: paleta.fondo ?? "#FAF8F2",
    superficie: paleta.superficieHonda ?? paleta.superficie ?? "#FFFFFF",
    borde: paleta.borde ?? "#DFE4F0",
    texto: paleta.texto ?? "#14213D",
    suave: paleta.textoSuave ?? "#4A5578",
    acento: paleta.dorado ?? paleta.doradoTexto ?? "#7A5A00",
  };
  const { resultados, aproximado } = useMemo(() => buscarEnAjustes(consulta, android), [consulta, android]);
  const escribio = consulta.trim().length > 0;

  // El texto se limpia al ABRIR (no al cerrar): así la hoja no muestra por un instante la pantalla vacía mientras se desliza hacia abajo.
  function abrir() {
    setConsulta("");
    setAbierto(true);
  }
  function cerrar() {
    setAbierto(false);
  }
  function elegir(entrada: { grupo: string; abre?: string }) {
    cerrar();
    if (entrada.abre) {
      const cual = entrada.abre;
      // Se espera a que termine de cerrarse la hoja: en iPhone, abrir otra pantalla mientras esta se cierra la ignora.
      setTimeout(() => abrirDesdeBuscador(cual), 500);
      return;
    }
    onElegir(entrada.grupo);
  }

  return (
    <>
      <Pressable
        accessibilityHint="Abre un buscador para encontrar cualquier opción de Ajustes"
        accessibilityLabel="Buscar en Ajustes"
        accessibilityRole="search"
        onPress={abrir}
        style={{
          alignItems: "center",
          alignSelf: "stretch",
          backgroundColor: c.superficie,
          borderColor: c.borde,
          borderRadius: 14,
          borderWidth: 1,
          flexDirection: "row",
          gap: 10,
          marginBottom: 8,
          paddingHorizontal: 12,
          paddingVertical: 11,
        }}
      >
        <Lupa color={c.suave} />
        <Text style={{ color: c.suave, flex: 1, fontSize: 15 }}>Buscar en Ajustes (batería, pin, fotos…)</Text>
      </Pressable>
      <Modal animationType="slide" onRequestClose={cerrar} visible={abierto}>
        <View style={{ backgroundColor: c.fondo, flex: 1, paddingTop: Platform.OS === "ios" ? 54 : (StatusBar.currentHeight ?? 24) + 8 }}>
          <View style={{ alignItems: "center", flexDirection: "row", gap: 8, paddingHorizontal: 16 }}>
            <View
              style={{
                alignItems: "center",
                backgroundColor: c.superficie,
                borderColor: c.borde,
                borderRadius: 14,
                borderWidth: 1,
                flex: 1,
                flexDirection: "row",
                gap: 8,
                minWidth: 0,
                paddingHorizontal: 12,
              }}
            >
              <Lupa color={c.suave} />
              <TextInput
                accessibilityLabel="Qué quieres buscar en Ajustes"
                autoCapitalize="none"
                autoCorrect={false}
                autoFocus
                onChangeText={setConsulta}
                onSubmitEditing={() => {
                  const primero = resultados[0];
                  if (primero) elegir(primero.entrada);
                }}
                placeholder="¿Qué quieres buscar?"
                placeholderTextColor={c.suave}
                returnKeyType="search"
                style={{ color: c.texto, flex: 1, fontSize: 17, minWidth: 0, paddingVertical: 12 }}
                value={consulta}
              />
              {escribio ? (
                <Pressable accessibilityLabel="Borrar lo escrito" accessibilityRole="button" hitSlop={10} onPress={() => setConsulta("")}>
                  <Text style={{ color: c.suave, fontSize: 20, fontWeight: "700" }}>✕</Text>
                </Pressable>
              ) : null}
            </View>
            <Pressable accessibilityRole="button" onPress={cerrar} style={{ paddingVertical: 12 }}>
              <Text style={{ color: c.texto, fontSize: 15, fontWeight: "800" }}>Cerrar</Text>
            </Pressable>
          </View>
          <ScrollView contentContainerStyle={{ gap: 8, padding: 16 }} keyboardShouldPersistTaps="handled">
            {!escribio ? (
              <>
                <Text style={{ color: c.suave, fontSize: 13.5, fontWeight: "700" }}>Búsquedas frecuentes</Text>
                <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 8 }}>
                  {BUSQUEDAS_FRECUENTES.map((texto) => (
                    <Pressable
                      accessibilityRole="button"
                      key={texto}
                      onPress={() => setConsulta(texto)}
                      style={{ backgroundColor: c.superficie, borderColor: c.borde, borderRadius: 999, borderWidth: 1, paddingHorizontal: 14, paddingVertical: 8 }}
                    >
                      <Text style={{ color: c.texto, fontSize: 14.5, fontWeight: "700" }}>{texto}</Text>
                    </Pressable>
                  ))}
                </View>
              </>
            ) : resultados.length ? (
              <>
                {aproximado ? <Text style={{ color: c.suave, fontSize: 13.5 }}>No encontré todo lo que escribiste. Esto se parece:</Text> : null}
                {resultados.map(({ entrada }) => (
                  <Pressable
                    accessibilityLabel={`${entrada.titulo}. Está en ${NOMBRE_DE_GRUPO[entrada.grupo] ?? "Ajustes"}`}
                    accessibilityRole="button"
                    key={entrada.id}
                    onPress={() => elegir(entrada)}
                    style={{ backgroundColor: c.superficie, borderColor: c.borde, borderRadius: 14, borderWidth: 1, gap: 2, paddingHorizontal: 14, paddingVertical: 12 }}
                  >
                    <Text style={{ color: c.texto, fontSize: 16, fontWeight: "800" }}>{entrada.titulo}</Text>
                    <Text style={{ color: c.suave, fontSize: 13.5, lineHeight: 19 }}>{entrada.ayuda}</Text>
                    <Text style={{ color: c.acento, fontSize: 12.5, fontWeight: "800" }}>Está en: {NOMBRE_DE_GRUPO[entrada.grupo] ?? "Ajustes"} ›</Text>
                  </Pressable>
                ))}
              </>
            ) : (
              <Text style={{ color: c.suave, fontSize: 15, lineHeight: 22 }}>
                No encontré «{consulta.trim()}». Prueba con otra palabra, por ejemplo: batería, pin, fotos, permisos o actualizar.
              </Text>
            )}
          </ScrollView>
        </View>
      </Modal>
    </>
  );
}

function Lupa({ color }: { color: string }) {
  return (
    <View style={{ height: 22, width: 22 }}>
      <View style={{ borderColor: color, borderRadius: 7, borderWidth: 2.2, height: 14, left: 1, position: "absolute", top: 1, width: 14 }} />
      <View style={{ backgroundColor: color, borderRadius: 2, height: 3, left: 11, position: "absolute", top: 15, transform: [{ rotate: "45deg" }], width: 9 }} />
    </View>
  );
}
