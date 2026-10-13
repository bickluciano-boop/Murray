import * as Location from "expo-location";
import * as Notifications from "expo-notifications";
import { Platform } from "react-native";

import { readBatteryUnrestricted } from "../modules/exact-alarm";
import { isSosGestureEnabled, isSosGestureRunning, sosGestureAvailable } from "../modules/sos-trigger";
import type { NativeEnrollment } from "./remoteStorage";
import { fetchMySos, SosError } from "./sos";
import { SOS_CHANNEL, ultimoUsoDelAtajo } from "./sosTask";

/**
 * "Revisar mi protección": mira, con lo que el teléfono deja mirar, si el SOS y los avisos de la familia están listos, y le
 * dice a la persona qué tiene que tocar si falta algo. Da un porcentaje: 100 % es "no encuentro nada que arreglar".
 *
 * Lo que no se puede revisar desde la app (por ejemplo que el modo Concentración del iPhone deje pasar a Ojo Guard) queda
 * dicho aparte, como nota: es de quien usa el teléfono. Lo que sí se puede es un item de esta lista.
 *
 *  - ok: está bien. Vale 1 punto.
 *  - revisar: funciona a medias o no se pudo comprobar. Vale medio punto.
 *  - falta: así no va a funcionar. Vale 0.
 * Cada item pesa 1 o 2 puntos según cuánto importa para que el pedido de ayuda llegue.
 */

export type EstadoItem = "ok" | "revisar" | "falta";

/** Qué botón ofrece cada item para arreglarlo (la pantalla del sistema que corresponde). */
export type Arreglo = "ajustes" | "gesto" | "canal" | "bateria";

export type ItemProteccion = {
  id: string;
  titulo: string;
  estado: EstadoItem;
  detalle: string;
  peso: number;
  arreglo?: Arreglo;
};

export type ResultadoProteccion = {
  items: ItemProteccion[];
  /** 0 a 100. */
  porcentaje: number;
  revisadoEn: Date;
  /** Cosas que la app no puede revisar y le tocan a la persona. */
  notas: string[];
};

const IMPORTANCIA_ALTA = 4;

function haceCuanto(iso: string) {
  const s = Math.max(0, (Date.now() - new Date(iso).getTime()) / 1000);
  if (s < 3600) return "hace menos de una hora";
  if (s < 86_400) return `hace ${Math.round(s / 3600)} h`;
  return `hace ${Math.round(s / 86_400)} días`;
}

/** Cuenta de puntos: lo mismo que se muestra como porcentaje. */
export function puntuar(items: ItemProteccion[]) {
  const total = items.reduce((suma, item) => suma + item.peso, 0);
  if (!total) return 100;
  const logrado = items.reduce((suma, item) => suma + item.peso * (item.estado === "ok" ? 1 : item.estado === "revisar" ? 0.5 : 0), 0);
  return Math.round((logrado / total) * 100);
}

async function itemServidor(enrollment: NativeEnrollment): Promise<ItemProteccion> {
  const base = { id: "servidor", titulo: "Conexión con Ojo Guard MS", peso: 1 };
  try {
    await fetchMySos(enrollment);
    return { ...base, estado: "ok", detalle: "Este teléfono está vinculado y el servidor responde." };
  } catch (error) {
    if (error instanceof SosError && error.code === "unauthorized") {
      return { ...base, estado: "falta", peso: 2, detalle: "Este teléfono ya no está vinculado con Ojo Guard MS. Hay que vincularlo de nuevo desde el panel." };
    }
    return { ...base, estado: "revisar", detalle: "No pude hablar con el servidor ahora. Revisá que tengas internet y volvé a revisar." };
  }
}

async function itemNotificaciones(): Promise<ItemProteccion> {
  const base = { id: "avisos", titulo: "Avisos", peso: 2, arreglo: "ajustes" as const };
  const permiso = await Notifications.getPermissionsAsync().catch(() => null);
  if (permiso?.granted) return { ...base, estado: "ok", detalle: "Las notificaciones están permitidas: te llegan los SOS y los avisos de tu familia." };
  return { ...base, estado: "falta", detalle: "Las notificaciones están apagadas: no te llegaría ningún SOS ni aviso. Activalas en los ajustes de la app." };
}

async function itemUbicacion(): Promise<ItemProteccion> {
  const base = { id: "ubicacion", titulo: "Ubicación «Siempre»", peso: 2, arreglo: "ajustes" as const };
  const fondo = await Location.getBackgroundPermissionsAsync().catch(() => null);
  if (fondo?.granted) return { ...base, estado: "ok", detalle: "La ubicación se comparte aunque la app esté cerrada: tu familia te ve y el SOS lleva tu posición." };
  const frente = await Location.getForegroundPermissionsAsync().catch(() => null);
  if (frente?.granted) {
    return { ...base, estado: "revisar", detalle: "Solo se usa mientras tenés la app abierta. En los ajustes de la app, Ubicación, elegí «Siempre»." };
  }
  return { ...base, estado: "falta", detalle: "No hay permiso de ubicación: el SOS saldría sin tu posición. En los ajustes de la app, Ubicación, elegí «Siempre»." };
}

function itemGesto(): ItemProteccion | null {
  if (Platform.OS !== "android" || !sosGestureAvailable()) return null;
  const base = { id: "gesto", titulo: "Gesto de volumen", peso: 2, arreglo: "gesto" as const };
  if (!isSosGestureEnabled()) {
    return { ...base, estado: "falta", detalle: "Está apagado: los botones de volumen no piden ayuda. Activá «Ojo Guard SOS» en Accesibilidad." };
  }
  const funcionando = isSosGestureRunning();
  if (funcionando === null) {
    return { ...base, estado: "revisar", detalle: "Figura activado, pero esta versión no puede comprobar si responde. Probalo con una vibración: mantené los dos botones de volumen 3 segundos." };
  }
  if (!funcionando) {
    return { ...base, estado: "falta", detalle: "Figura activado pero Android lo dejó caído y no responde. Apagá «Ojo Guard SOS» en Accesibilidad y volvelo a prender." };
  }
  return { ...base, estado: "ok", detalle: "Activado y funcionando: mantené los dos botones de volumen 3 segundos y el teléfono vibra." };
}

async function itemSirena(): Promise<ItemProteccion | null> {
  if (Platform.OS !== "android") return null;
  const base = { id: "sirena", titulo: "Sirena del SOS", peso: 1, arreglo: "canal" as const };
  const canal = await Notifications.getNotificationChannelAsync(SOS_CHANNEL).catch(() => null);
  if (!canal) {
    return { ...base, estado: "revisar", detalle: "El canal de la sirena todavía no se creó. Abrí Ojo Guard una vez y volvé a revisar." };
  }
  if (canal.importance < IMPORTANCIA_ALTA || !canal.sound) {
    return { ...base, estado: "falta", detalle: "Silenciaste el canal «SOS de la familia»: un SOS llegaría sin sonido. Subí la importancia y dejá el sonido activado." };
  }
  if (!canal.bypassDnd) {
    return { ...base, estado: "revisar", detalle: "Si el teléfono está en No interrumpir, la sirena no suena. Activá «Anular No interrumpir» en este canal." };
  }
  return { ...base, estado: "ok", detalle: "Suena con sirena y atraviesa No interrumpir." };
}

function itemBateria(): ItemProteccion | null {
  if (Platform.OS !== "android") return null;
  const libre = readBatteryUnrestricted();
  if (libre === null) return null;
  const base = { id: "bateria", titulo: "Batería sin restricciones", peso: 1, arreglo: "bateria" as const };
  if (libre) return { ...base, estado: "ok", detalle: "Android no duerme a Ojo Guard para ahorrar batería." };
  return { ...base, estado: "revisar", detalle: "Android puede dormir la app y demorar los avisos. En Batería elegí «Sin restricciones»." };
}

async function itemAtajo(): Promise<ItemProteccion | null> {
  if (Platform.OS !== "ios") return null;
  const base = { id: "atajo", titulo: "Atajo del SOS", peso: 2 };
  const uso = await ultimoUsoDelAtajo();
  if (uso) return { ...base, estado: "ok", detalle: `Funcionó ${haceCuanto(uso)}: Siri, el toque en la espalda o el control de pantalla llegan a Ojo Guard.` };
  return {
    ...base,
    estado: "revisar",
    detalle: "No tengo registro de que el atajo haya funcionado. Armalo más abajo en «Pedir ayuda sin buscar el botón» y probalo una vez (manda un SOS de verdad: avisale a tu familia y cancelalo con «Estoy bien»).",
  };
}

function notas(): string[] {
  if (Platform.OS === "ios") {
    return [
      "Esto la app no lo puede revisar: en Ajustes › Concentración, en cada modo que uses (No molestar, Trabajo, Dormir…), permití las notificaciones de Ojo Guard. Si no, el SOS puede llegar mudo.",
      "Tampoco puede ver el interruptor de silencio (el botón de al costado del iPhone). Con el teléfono en silencio, el SOS aparece en pantalla pero no suena: revisá que no esté silenciado.",
    ];
  }
  return [
    "La sirena del SOS sale por el volumen de alarma: revisá en Ajustes › Sonido que no esté en cero.",
    "Después de actualizar la app o de reiniciar el teléfono, volvé a revisar: Android a veces apaga solo los servicios de Accesibilidad.",
  ];
}

/** Hace todas las comprobaciones y arma el resultado. No lanza errores: lo que no se pudo comprobar queda como «revisar». */
export async function revisarProteccion(enrollment: NativeEnrollment): Promise<ResultadoProteccion> {
  const [servidor, avisos, ubicacion, sirena, atajo] = await Promise.all([
    itemServidor(enrollment),
    itemNotificaciones(),
    itemUbicacion(),
    itemSirena(),
    itemAtajo(),
  ]);
  const items = [servidor, avisos, ubicacion, itemGesto(), sirena, itemBateria(), atajo].filter((item): item is ItemProteccion => item !== null);
  return { items, porcentaje: puntuar(items), revisadoEn: new Date(), notas: notas() };
}
