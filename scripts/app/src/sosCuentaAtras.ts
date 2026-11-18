import { AppState, Vibration } from "react-native";
import type * as Notificaciones from "expo-notifications";

/**
 * Cuenta regresiva para el SOS que se pide desde afuera de la app: el enlace del atajo del iPhone (toque en la espalda, Siri o botón de la
 * pantalla de bloqueo). Esos caminos se disparan con facilidad sin querer (el iPhone en el bolsillo, tres toques en la espalda), y antes el
 * SOS salía al instante y le sonaba la sirena a toda la familia. Ahora hay unos segundos para cancelar; si no se toca nada, sale solo.
 * El botón rojo de la app (mantenerlo 3 segundos) y los dos botones de volumen de Android ya piden mantener apretado: siguen igual.
 *
 * Todo es DISCRETO a propósito (Luciano, 18/11/2026: "si te están por robar no está bueno ver algo muy llamativo"): ni la pantalla ni el aviso dicen «SOS»,
 * «familia» ni «cancelar SOS», no hay sirena ni pitidos por segundo, y nada parpadea en rojo.
 *  - Pantalla a la vista: 5 segundos, pantalla casi negra con un número tenue y un «Cancelar» sobrio (SosCuentaAtras.tsx).
 *  - Teléfono bloqueado o app en segundo plano ("cuando apretás tres veces la pantalla se apaga y hasta que lee Face ID ya salió"): 15 segundos, con un
 *    único aviso neutro («Ojo Guard · Toca para revisar») que avisa con el sonido o la vibración normal del teléfono. Al desbloquear y abrir la app se ve la
 *    pantalla de arriba con al menos 5 segundos para cancelar. Si no se toca nada, el SOS sale solo.
 *
 * Este archivo solo lleva la cuenta, una vibración corta al empezar y el aviso neutro. La pantalla que la muestra es SosCuentaAtras.tsx.
 */
export const CUENTA_ATRAS_SEGUNDOS = 5;
export const CUENTA_ATRAS_BLOQUEADO_SEGUNDOS = 15;
/** Si la pantalla se ve a mitad de la cuenta, queda al menos esto para cancelar. */
const MINIMO_AL_VERSE_SEGUNDOS = 5;

export type EstadoCuentaAtras = { activa: boolean; restante: number };
type Oyente = (estado: EstadoCuentaAtras) => void;

let estado: EstadoCuentaAtras = { activa: false, restante: 0 };
let reloj: ReturnType<typeof setInterval> | null = null;
let alTerminar: (() => void) | null = null;
const oyentes = new Set<Oyente>();
let suscripcionApp: { remove: () => void } | null = null;
let avisoPantallaBloqueo: { modulo: typeof Notificaciones; id: string } | null = null;

function avisar() {
  const copia = { ...estado };
  oyentes.forEach((oyente) => oyente(copia));
}

/** Saca de la pantalla de bloqueo el aviso neutro (si estaba). */
function quitarAvisoPantallaBloqueo() {
  const aviso = avisoPantallaBloqueo;
  avisoPantallaBloqueo = null;
  if (!aviso) return;
  void aviso.modulo.dismissNotificationAsync(aviso.id).catch(() => undefined);
}

function parar() {
  if (reloj) clearInterval(reloj);
  reloj = null;
  alTerminar = null;
  estado = { activa: false, restante: 0 };
  suscripcionApp?.remove();
  suscripcionApp = null;
  quitarAvisoPantallaBloqueo();
  avisar();
}

/** Para que la pantalla se entere de cada segundo. Devuelve la función que deja de escuchar. */
export function escucharCuentaAtras(oyente: Oyente) {
  oyentes.add(oyente);
  oyente({ ...estado });
  return () => {
    oyentes.delete(oyente);
  };
}

async function cargarNotificaciones(): Promise<typeof Notificaciones | null> {
  try {
    return await import("expo-notifications");
  } catch {
    return null;
  }
}

/** Con el teléfono bloqueado: un único aviso NEUTRO (no dice SOS ni familia, sin botones) para que el dueño sepa que algo pasó. Si algo falla, la cuenta corre igual. */
async function avisoDiscretoPantallaBloqueo() {
  const modulo = await cargarNotificaciones();
  if (!modulo) return;
  try {
    const contenido = { title: "Ojo Guard", body: "Toca para revisar.", sound: "default", data: { type: "aviso-discreto" } } as Notificaciones.NotificationContentInput;
    const id = await modulo.scheduleNotificationAsync({ content: contenido, trigger: null });
    if (!estado.activa) {
      void modulo.dismissNotificationAsync(id).catch(() => undefined);
      return;
    }
    avisoPantallaBloqueo = { modulo, id };
  } catch {
    // Sin el aviso la cuenta igual corre (y se cancela desde la app al desbloquear).
  }
}

/**
 * Empieza la cuenta. Si ya hay una en marcha no empieza otra (dos pedidos seguidos salen una sola vez). Al llegar a cero llama a `enviar`.
 * Sin `segundos`: 5 si la pantalla está a la vista, 15 si el teléfono está bloqueado o la app en segundo plano.
 */
export function iniciarCuentaAtras(enviar: () => void, segundos?: number) {
  if (estado.activa) return;
  const aLaVista = AppState.currentState === "active";
  const total = segundos ?? (aLaVista ? CUENTA_ATRAS_SEGUNDOS : CUENTA_ATRAS_BLOQUEADO_SEGUNDOS);
  alTerminar = enviar;
  estado = { activa: true, restante: total };
  Vibration.vibrate(150);
  avisar();
  if (!aLaVista) {
    void avisoDiscretoPantallaBloqueo();
    // Si se desbloquea y la pantalla se ve a mitad de la cuenta: queda al menos MINIMO_AL_VERSE_SEGUNDOS para cancelar y el aviso neutro sobra.
    suscripcionApp = AppState.addEventListener("change", (nuevo) => {
      if (nuevo !== "active" || !estado.activa) return;
      quitarAvisoPantallaBloqueo();
      if (estado.restante < MINIMO_AL_VERSE_SEGUNDOS) {
        estado = { activa: true, restante: MINIMO_AL_VERSE_SEGUNDOS };
        avisar();
      }
    });
  }
  reloj = setInterval(() => {
    const restante = estado.restante - 1;
    if (restante <= 0) {
      enviarAhora();
      return;
    }
    estado = { activa: true, restante };
    avisar();
  }, 1000);
}

/** Cancela: el SOS no sale. Devuelve true si había una cuenta en marcha. */
export function cancelarCuentaAtras() {
  if (!estado.activa) return false;
  parar();
  return true;
}

/** Manda el SOS ya, sin esperar los segundos que faltan. */
export function enviarAhora() {
  if (!estado.activa) return;
  const enviar = alTerminar;
  parar();
  enviar?.();
}
