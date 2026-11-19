import AsyncStorage from "@react-native-async-storage/async-storage";
import * as FileSystem from "expo-file-system/legacy";

import { fetchRemedios } from "./remoteApi";
import { loadNativeEnrollment } from "./remoteStorage";

/**
 * TARJETA DE SALUD (fase 1: solo en este teléfono). Luciano (19/11/2026): "una tarjeta donde tenga adentro todos los datos: los medicamentos, la
 * credencial de la obra social, el grupo sanguíneo, todo lo que te pueden pedir cuando tenés un accidente y nunca los tenés".
 *
 * DÓNDE SE GUARDA. Los textos, en AsyncStorage (clave ojo_salud_v1) y las fotos de la credencial, en la carpeta privada ojo-identidad/ de la app,
 * la misma de la foto de perfil. Es el almacenamiento privado de la app (ninguna otra app lo lee y el sistema lo cifra con el teléfono bloqueado).
 * "Borrar mi cuenta" ya borra las dos cosas (AsyncStorage.clear() y la carpeta ojo-identidad/): no hace falta tocar ese archivo.
 * NADA sale del teléfono: ni el servidor ni el panel ven esta tarjeta.
 *
 * LOS MEDICAMENTOS NO SE CARGAN DE NUEVO: se leen de los remedios que la persona ya tiene (fetchRemedios). Se guarda una copia de la última lista
 * para que la tarjeta la muestre aunque no haya internet (en una emergencia puede no haber señal).
 */

export const CLAVE_SALUD = "ojo_salud_v1";
export const CLAVE_MEDICAMENTOS = "ojo_salud_meds_v1";
export const CARPETA_FOTOS = "ojo-identidad";
export const MAX_CONTACTOS = 3;

export type GrupoSangre = "" | "A" | "B" | "AB" | "O" | "no-se";
export type FactorSangre = "" | "+" | "-";
export type DonanteOrganos = "" | "si" | "no" | "no-se";
export type ContactoEmergencia = { nombre: string; parentesco: string; telefono: string };

export type TarjetaSalud = {
  nombre: string;
  /** AAAA-MM-DD, o "" si no se cargó. */
  nacimiento: string;
  documento: string;
  sangre: GrupoSangre;
  factor: FactorSangre;
  alergias: string;
  condiciones: string;
  otrosMedicamentos: string;
  obraSocial: string;
  plan: string;
  afiliado: string;
  telefonoObraSocial: string;
  /** Solo el nombre del archivo (la ruta completa cambia al actualizar la app en iPhone). */
  credencialFrente: string;
  credencialDorso: string;
  medico: string;
  telefonoMedico: string;
  contactos: ContactoEmergencia[];
  donante: DonanteOrganos;
  cirugias: string;
  instrucciones: string;
  /** ISO de la última vez que se guardó. */
  actualizada: string;
};

export type MedicamentoResumen = { nombre: string; horas: string[] };
export type ListaMedicamentos = { items: MedicamentoResumen[]; desdeCopia: boolean; copiadaEn: string | null };

const LARGOS = {
  nombre: 80,
  documento: 20,
  alergias: 400,
  condiciones: 400,
  otrosMedicamentos: 300,
  obraSocial: 60,
  plan: 40,
  afiliado: 30,
  telefono: 25,
  medico: 80,
  contactoNombre: 60,
  parentesco: 30,
  cirugias: 400,
  instrucciones: 400,
} as const;

export function contactoVacio(): ContactoEmergencia {
  return { nombre: "", parentesco: "", telefono: "" };
}

export function tarjetaVacia(): TarjetaSalud {
  return {
    nombre: "",
    nacimiento: "",
    documento: "",
    sangre: "",
    factor: "",
    alergias: "",
    condiciones: "",
    otrosMedicamentos: "",
    obraSocial: "",
    plan: "",
    afiliado: "",
    telefonoObraSocial: "",
    credencialFrente: "",
    credencialDorso: "",
    medico: "",
    telefonoMedico: "",
    contactos: Array.from({ length: MAX_CONTACTOS }, contactoVacio),
    donante: "",
    cirugias: "",
    instrucciones: "",
    actualizada: "",
  };
}

function texto(valor: unknown, largo: number): string {
  return typeof valor === "string" ? valor.replace(/\r/g, "").trim().slice(0, largo) : "";
}

/** Un teléfono: solo dígitos, +, espacios, guiones y paréntesis. */
export function limpiarTelefono(valor: unknown): string {
  return typeof valor === "string" ? valor.replace(/[^0-9+()\-\s]/g, "").trim().slice(0, LARGOS.telefono) : "";
}

/** Para marcar: solo dígitos y un + al principio. */
export function numeroParaLlamar(valor: string): string {
  const digitos = valor.replace(/[^0-9]/g, "");
  return valor.trim().startsWith("+") ? `+${digitos}` : digitos;
}

/** El nombre de archivo de una foto guardada: sin carpetas ni caracteres raros (nunca viene de afuera, pero se cuida igual). */
function nombreArchivo(valor: unknown): string {
  if (typeof valor !== "string") return "";
  const limpio = valor.slice(valor.lastIndexOf("/") + 1);
  return /^[A-Za-z0-9._-]{1,80}\.jpg$/.test(limpio) ? limpio : "";
}

export function fechaValida(iso: string): boolean {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso);
  if (!m) return false;
  const [anio, mes, dia] = [Number(m[1]), Number(m[2]), Number(m[3])];
  const f = new Date(Date.UTC(anio, mes - 1, dia));
  return f.getUTCFullYear() === anio && f.getUTCMonth() === mes - 1 && f.getUTCDate() === dia && anio >= 1900 && f.getTime() <= Date.now();
}

/** "15/03/1980" -> "1980-03-15" (o "" si no es una fecha). Acepta también "15031980". */
export function fechaDeTexto(escrita: string): string {
  const digitos = escrita.replace(/[^0-9]/g, "");
  if (digitos.length !== 8) return "";
  const iso = `${digitos.slice(4, 8)}-${digitos.slice(2, 4)}-${digitos.slice(0, 2)}`;
  return fechaValida(iso) ? iso : "";
}

/** "1980-03-15" -> "15/03/1980". */
export function textoDeFecha(iso: string): string {
  return fechaValida(iso) ? `${iso.slice(8, 10)}/${iso.slice(5, 7)}/${iso.slice(0, 4)}` : "";
}

/** Mientras se escribe: agrega las barras solas (15031980 -> 15/03/1980). */
export function formatearFechaEscrita(escrita: string): string {
  const digitos = escrita.replace(/[^0-9]/g, "").slice(0, 8);
  if (digitos.length <= 2) return digitos;
  if (digitos.length <= 4) return `${digitos.slice(0, 2)}/${digitos.slice(2)}`;
  return `${digitos.slice(0, 2)}/${digitos.slice(2, 4)}/${digitos.slice(4)}`;
}

export function edadDe(nacimiento: string, ahora: Date = new Date()): number | null {
  if (!fechaValida(nacimiento)) return null;
  const anio = Number(nacimiento.slice(0, 4)), mes = Number(nacimiento.slice(5, 7)), dia = Number(nacimiento.slice(8, 10));
  let edad = ahora.getFullYear() - anio;
  if (ahora.getMonth() + 1 < mes || (ahora.getMonth() + 1 === mes && ahora.getDate() < dia)) edad -= 1;
  return edad >= 0 && edad < 125 ? edad : null;
}

/** "A+", "0-"... o "" si falta algo. */
export function textoSangre(t: Pick<TarjetaSalud, "sangre" | "factor">): string {
  if (t.sangre === "no-se") return "No sé";
  if (!t.sangre) return "";
  return `${t.sangre}${t.factor === "+" || t.factor === "-" ? (t.factor === "-" ? "−" : "+") : ""}`;
}

/** Tarjeta que viene de afuera (AsyncStorage): se vuelve a limpiar campo por campo. */
export function limpiarTarjeta(crudo: unknown): TarjetaSalud {
  const base = tarjetaVacia();
  if (!crudo || typeof crudo !== "object") return base;
  const d = crudo as Record<string, unknown>;
  const sangres: GrupoSangre[] = ["A", "B", "AB", "O", "no-se"];
  const sangre = sangres.find((s) => s === d.sangre) ?? "";
  const factor: FactorSangre = d.factor === "+" || d.factor === "-" ? d.factor : "";
  const donantes: DonanteOrganos[] = ["si", "no", "no-se"];
  const contactosCrudos = Array.isArray(d.contactos) ? d.contactos : [];
  const contactos = Array.from({ length: MAX_CONTACTOS }, (_, i) => {
    const c = contactosCrudos[i] as Record<string, unknown> | undefined;
    return c && typeof c === "object"
      ? { nombre: texto(c.nombre, LARGOS.contactoNombre), parentesco: texto(c.parentesco, LARGOS.parentesco), telefono: limpiarTelefono(c.telefono) }
      : contactoVacio();
  });
  const nacimiento = typeof d.nacimiento === "string" && fechaValida(d.nacimiento) ? d.nacimiento : "";
  return {
    nombre: texto(d.nombre, LARGOS.nombre),
    nacimiento,
    documento: texto(d.documento, LARGOS.documento).replace(/[^0-9A-Za-z.\-\s]/g, ""),
    sangre,
    factor: sangre && sangre !== "no-se" ? factor : "",
    alergias: texto(d.alergias, LARGOS.alergias),
    condiciones: texto(d.condiciones, LARGOS.condiciones),
    otrosMedicamentos: texto(d.otrosMedicamentos, LARGOS.otrosMedicamentos),
    obraSocial: texto(d.obraSocial, LARGOS.obraSocial),
    plan: texto(d.plan, LARGOS.plan),
    afiliado: texto(d.afiliado, LARGOS.afiliado),
    telefonoObraSocial: limpiarTelefono(d.telefonoObraSocial),
    credencialFrente: nombreArchivo(d.credencialFrente),
    credencialDorso: nombreArchivo(d.credencialDorso),
    medico: texto(d.medico, LARGOS.medico),
    telefonoMedico: limpiarTelefono(d.telefonoMedico),
    contactos,
    donante: donantes.find((x) => x === d.donante) ?? "",
    cirugias: texto(d.cirugias, LARGOS.cirugias),
    instrucciones: texto(d.instrucciones, LARGOS.instrucciones),
    actualizada: typeof d.actualizada === "string" ? d.actualizada.slice(0, 40) : "",
  };
}

export async function cargarTarjeta(): Promise<TarjetaSalud> {
  try {
    const crudo = await AsyncStorage.getItem(CLAVE_SALUD);
    return crudo ? limpiarTarjeta(JSON.parse(crudo)) : tarjetaVacia();
  } catch {
    return tarjetaVacia();
  }
}

/** Guarda la tarjeta (ya limpia). Devuelve la tarjeta guardada o null si no se pudo. */
export async function guardarTarjeta(t: TarjetaSalud): Promise<TarjetaSalud | null> {
  try {
    const limpia = { ...limpiarTarjeta(t), actualizada: new Date().toISOString() };
    await AsyncStorage.setItem(CLAVE_SALUD, JSON.stringify(limpia));
    return limpia;
  } catch {
    return null;
  }
}

export function tarjetaConDatos(t: TarjetaSalud): boolean {
  return Boolean(
    t.nombre || t.nacimiento || t.documento || t.sangre || t.alergias || t.condiciones || t.otrosMedicamentos || t.obraSocial || t.afiliado ||
      t.credencialFrente || t.credencialDorso || t.medico || t.telefonoMedico || t.donante || t.cirugias || t.instrucciones ||
      t.contactos.some((c) => c.nombre || c.telefono),
  );
}

/** Cuántos de los 8 datos más importantes están cargados (para "Cargada: 5 de 8" en Ajustes). */
export function progresoCarga(t: TarjetaSalud): { llenos: number; total: number } {
  const lista = [
    Boolean(t.nombre && (t.nacimiento || t.documento)),
    Boolean(t.sangre),
    Boolean(t.alergias),
    Boolean(t.condiciones),
    Boolean(t.obraSocial || t.afiliado),
    Boolean(t.credencialFrente || t.credencialDorso),
    Boolean(t.medico || t.telefonoMedico),
    t.contactos.some((c) => c.nombre && c.telefono),
  ];
  return { llenos: lista.filter(Boolean).length, total: lista.length };
}

/** Agrega o saca un atajo ("Penicilina") de un texto separado por comas. */
export function alternarEnLista(textoActual: string, item: string): string {
  const partes = textoActual.split(/[,\n]/).map((p) => p.trim()).filter(Boolean);
  const clave = item.toLowerCase();
  const esta = partes.some((p) => p.toLowerCase() === clave);
  const nuevas = esta ? partes.filter((p) => p.toLowerCase() !== clave) : [...partes, item];
  return nuevas.join(", ");
}

export function enLista(textoActual: string, item: string): boolean {
  const clave = item.toLowerCase();
  return textoActual.split(/[,\n]/).some((p) => p.trim().toLowerCase() === clave);
}

// ---------------------------------------------------------------------------------------------------------------------------------------------
// Fotos de la credencial (carpeta privada de la app)
// ---------------------------------------------------------------------------------------------------------------------------------------------

export function rutaFoto(nombre: string): string | null {
  const base = FileSystem.documentDirectory;
  const limpio = nombreArchivo(nombre);
  return base && limpio ? `${base}${CARPETA_FOTOS}/${limpio}` : null;
}

/** Copia la foto a la carpeta privada y devuelve el nombre del archivo (o null si no se pudo). */
export async function guardarFotoCredencial(origen: string, lado: "frente" | "dorso"): Promise<string | null> {
  const base = FileSystem.documentDirectory;
  if (!base) return null;
  try {
    const carpeta = `${base}${CARPETA_FOTOS}/`;
    await FileSystem.makeDirectoryAsync(carpeta, { intermediates: true }).catch(() => undefined);
    const nombre = `salud-${lado}-${Date.now()}.jpg`;
    await FileSystem.copyAsync({ from: origen, to: `${carpeta}${nombre}` });
    return nombre;
  } catch {
    return null;
  }
}

export async function borrarFoto(nombre: string): Promise<void> {
  const ruta = rutaFoto(nombre);
  if (ruta) await FileSystem.deleteAsync(ruta, { idempotent: true }).catch(() => undefined);
}

/** Borra la tarjeta entera: textos, fotos y la copia de medicamentos. */
export async function borrarTarjeta(): Promise<void> {
  const actual = await cargarTarjeta();
  await borrarFoto(actual.credencialFrente);
  await borrarFoto(actual.credencialDorso);
  await AsyncStorage.removeItem(CLAVE_SALUD).catch(() => undefined);
  await AsyncStorage.removeItem(CLAVE_MEDICAMENTOS).catch(() => undefined);
}

// ---------------------------------------------------------------------------------------------------------------------------------------------
// Medicamentos (se leen de los remedios de la persona; con copia para cuando no hay internet)
// ---------------------------------------------------------------------------------------------------------------------------------------------

async function copiaDeMedicamentos(): Promise<ListaMedicamentos | null> {
  try {
    const crudo = await AsyncStorage.getItem(CLAVE_MEDICAMENTOS);
    if (!crudo) return null;
    const d = JSON.parse(crudo) as { items?: unknown; copiadaEn?: unknown };
    const items = Array.isArray(d.items)
      ? d.items
          .map((i) => i as { nombre?: unknown; horas?: unknown })
          .filter((i) => typeof i.nombre === "string" && i.nombre.trim())
          .map((i) => ({ nombre: texto(i.nombre, 80), horas: Array.isArray(i.horas) ? i.horas.map((h) => texto(h, 5)).filter(Boolean).slice(0, 12) : [] }))
      : [];
    return { items, desdeCopia: true, copiadaEn: typeof d.copiadaEn === "string" ? d.copiadaEn : null };
  } catch {
    return null;
  }
}

/** Los medicamentos activos de la persona. Con internet, la lista al día (y se guarda una copia); sin internet, la última copia. */
export async function cargarMedicamentos(esperaMs = 6000): Promise<ListaMedicamentos> {
  try {
    const enrollment = await loadNativeEnrollment();
    if (enrollment) {
      const estado = await Promise.race([
        fetchRemedios(enrollment),
        new Promise<null>((resolver) => setTimeout(() => resolver(null), esperaMs)),
      ]);
      if (estado) {
        const items = estado.items.filter((i) => i.activo).map((i) => ({ nombre: texto(i.nombre, 80), horas: [...i.horas].sort() })).filter((i) => i.nombre);
        const copiadaEn = new Date().toISOString();
        await AsyncStorage.setItem(CLAVE_MEDICAMENTOS, JSON.stringify({ items, copiadaEn })).catch(() => undefined);
        return { items, desdeCopia: false, copiadaEn };
      }
    }
  } catch {
    // Sin internet o sin vincular: se muestra la última copia.
  }
  return (await copiaDeMedicamentos()) ?? { items: [], desdeCopia: true, copiadaEn: null };
}
