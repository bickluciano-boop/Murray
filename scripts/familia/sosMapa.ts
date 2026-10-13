import AsyncStorage from "@react-native-async-storage/async-storage";
import * as Notifications from "expo-notifications";
import { Linking, Platform } from "react-native";

import { fetchFamily } from "./remoteApi";
import { loadNativeEnrollment } from "./remoteStorage";

/**
 * Tocar el aviso de SOS lleva al mapa. El servidor manda con el aviso `data: { type: "sos", personId, name, latitude,
 * longitude }`; acá, al tocarlo (con la app abierta, en segundo plano o cerrada), se busca la ubicación más nueva de esa
 * persona (el SOS la va renovando cada pocos segundos) y se abre en el mapa del teléfono: Apple Maps en iPhone, Google Maps
 * en Android. Si no hay ubicación, queda solo la app abierta.
 *
 * Se registra al cargar el módulo (lo importa SosBlock.tsx, que App.tsx ya carga). Un mismo toque no se atiende dos veces,
 * ni aunque lo traigan a la vez el aviso en vivo y el "último toque" que guarda el sistema al abrir la app.
 */

const CLAVE_ATENDIDO = "ojo-guard-sos-toque-v1";
const atendidos = new Set<string>();

const numero = (valor: unknown) => (typeof valor === "number" && Number.isFinite(valor) ? valor : null);

function direccionDelMapa(latitud: number, longitud: number, nombre: string) {
  if (Platform.OS === "ios") return `https://maps.apple.com/?ll=${latitud},${longitud}&q=${encodeURIComponent(nombre || "SOS")}`;
  return `https://www.google.com/maps/search/?api=1&query=${latitud},${longitud}`;
}

async function alTocar(respuesta: Notifications.NotificationResponse | null | undefined) {
  if (!respuesta) return;
  const datos = respuesta.notification.request.content.data as Record<string, unknown> | undefined;
  if (!datos || datos.type !== "sos") return;
  const marca = `${respuesta.notification.request.identifier}:${respuesta.notification.date}`;
  if (atendidos.has(marca)) return;
  atendidos.add(marca);
  if ((await AsyncStorage.getItem(CLAVE_ATENDIDO).catch(() => null)) === marca) return;
  await AsyncStorage.setItem(CLAVE_ATENDIDO, marca).catch(() => undefined);

  let latitud = numero(datos.latitude);
  let longitud = numero(datos.longitude);
  const nombre = typeof datos.name === "string" ? datos.name : "";
  // La ubicación del aviso es la del momento en que se pidió ayuda: se prefiere la más nueva de la persona.
  if (typeof datos.personId === "string") {
    const vinculo = await loadNativeEnrollment().catch(() => null);
    const familia = vinculo ? await fetchFamily(vinculo).catch(() => null) : null;
    const ubicacion = familia?.people.find((persona) => persona.id === datos.personId)?.lastLocation;
    const nuevaLatitud = numero(ubicacion?.latitude);
    const nuevaLongitud = numero(ubicacion?.longitude);
    if (nuevaLatitud !== null && nuevaLongitud !== null) {
      latitud = nuevaLatitud;
      longitud = nuevaLongitud;
    }
  }
  if (latitud === null || longitud === null) return;
  await Linking.openURL(direccionDelMapa(latitud, longitud, nombre)).catch(() => undefined);
}

if (Platform.OS !== "web") {
  Notifications.addNotificationResponseReceivedListener((respuesta) => void alTocar(respuesta));
  // App cerrada: el sistema guarda el toque que la abrió.
  void Notifications.getLastNotificationResponseAsync().then((respuesta) => alTocar(respuesta)).catch(() => undefined);
}
