import { Vibration } from "react-native";

/**
 * Cuenta regresiva para el SOS que se pide desde afuera de la app: el enlace del atajo del iPhone (toque en la espalda, Siri o botón de la
 * pantalla de bloqueo). Esos caminos se disparan con facilidad sin querer (el iPhone en el bolsillo, tres toques en la espalda), y antes el
 * SOS salía al instante y le sonaba la sirena a toda la familia. Ahora hay unos segundos para cancelar; si no se toca nada, sale solo.
 * El botón rojo de la app (mantenerlo 3 segundos) y los dos botones de volumen de Android ya piden mantener apretado: siguen igual.
 *
 * Este archivo solo lleva la cuenta (y la vibración). La pantalla que la muestra es SosCuentaAtras.tsx.
 */
export const CUENTA_ATRAS_SEGUNDOS = 5;

export type EstadoCuentaAtras = { activa: boolean; restante: number };
type Oyente = (estado: EstadoCuentaAtras) => void;

let estado: EstadoCuentaAtras = { activa: false, restante: 0 };
let reloj: ReturnType<typeof setInterval> | null = null;
let alTerminar: (() => void) | null = null;
const oyentes = new Set<Oyente>();

function avisar() {
  const copia = { ...estado };
  oyentes.forEach((oyente) => oyente(copia));
}

function parar() {
  if (reloj) clearInterval(reloj);
  reloj = null;
  alTerminar = null;
  estado = { activa: false, restante: 0 };
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

/** Empieza la cuenta. Si ya hay una en marcha no empieza otra (dos pedidos seguidos salen una sola vez). Al llegar a cero llama a `enviar`. */
export function iniciarCuentaAtras(enviar: () => void, segundos: number = CUENTA_ATRAS_SEGUNDOS) {
  if (estado.activa) return;
  alTerminar = enviar;
  estado = { activa: true, restante: segundos };
  Vibration.vibrate(300);
  avisar();
  reloj = setInterval(() => {
    const restante = estado.restante - 1;
    if (restante <= 0) {
      enviarAhora();
      return;
    }
    estado = { activa: true, restante };
    Vibration.vibrate(120);
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
