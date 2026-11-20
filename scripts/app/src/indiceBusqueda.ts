/**
 * BUSCADOR de Ajustes (lógica pura, sin pantalla: se prueba sola). Luciano (20/11/2026): "el buscador es una de las mejores cosas; hasta a mí me cuesta encontrar un lugar, imagínate un usuario:
 * debería ir reconociendo lo que escribes y poder navegar con la búsqueda".
 * - No distingue tildes ni mayúsculas, ignora signos.
 * - Reconoce mientras se escribe (prefijos: "bat" ya encuentra "batería").
 * - Tolera errores de tipeo ("baterai", "permisso") y entiende sinónimos ("foto" lleva a Intentos de entrada, "contraseña" a Claves de acceso).
 * - Si con todas las palabras no hay nada, muestra lo más parecido en lugar de quedar vacío.
 * Cada resultado lleva el GRUPO de Ajustes donde está la sección (el mismo valor que usa `elegirGrupo`), y la sección sigue siendo la de siempre: no se mueve ni cambia nada.
 */

export type EntradaBusqueda = {
  id: string;
  titulo: string;
  ayuda: string;
  /** Grupo de Ajustes donde está la sección (valor de `elegirGrupo`). */
  grupo: string;
  /** Palabras que la persona usaría para buscarla (sinónimos, cómo lo diría en la calle). */
  palabras: string;
  soloAndroid?: boolean;
  soloIphone?: boolean;
  /** Si no es un grupo sino una tarjeta con su propio estado: el nombre con el que se anota en aperturasAjustes.ts (ej.: "salud"). */
  abre?: string;
};

/** Nombre con el que se ve cada grupo en Ajustes, para decir "Está en …". */
export const NOMBRE_DE_GRUPO: { [grupo: string]: string } = {
  configuracion: "Ajustes",
  permisos: "Permisos",
  perfil: "Perfil",
  perdido: "Modo perdido",
  claves: "Claves y Seguridad",
  preferencias: "Preferencias",
  fotos: "Fotos de Intrusos",
  conexion: "Ojo Guard MS",
  familia: "Familia y amigos",
};

export const INDICE_AJUSTES: EntradaBusqueda[] = [
  { id: "permisos-android", titulo: "Permisos de Android", ayuda: "Revisa que Ojo Guard tenga todo lo que necesita", grupo: "permisos", palabras: "permiso permisos autorizar acceso android estado detalle revisar permisos", soloAndroid: true },
  { id: "guia-android", titulo: "Evitar que Android bloquee Ojo Guard", ayuda: "Cuatro ajustes para que Android no frene la app", grupo: "permisos", palabras: "bloquear bloquea frena frenar cierra se cierra optimizacion segundo plano bateria ahorro de energia no funciona no responde guia", soloAndroid: true },
  { id: "iphone-robo", titulo: "Protege tu iPhone contra robo", ayuda: "Dos ajustes del iPhone, un minuto", grupo: "permisos", palabras: "iphone robo robado face id codigo proteccion dispositivo robado buscar apple", soloIphone: true },
  { id: "autonomia", titulo: "Preparar autonomía para Modo perdido", ayuda: "Batería, alarmas y avisos de pantalla completa", grupo: "permisos", palabras: "autonomia bateria alarma alarmas avisos pantalla completa exactas modo perdido preparar dr ojo guard diagnostico" },
  { id: "registro-soporte", titulo: "Compartir registro con soporte", ayuda: "Registros técnicos para mandar a soporte", grupo: "permisos", palabras: "registro registros tecnicos soporte compartir log error problema diagnostico ayuda mandar enviar", },
  { id: "actualizar", titulo: "Actualizar Ojo Guard", ayuda: "Buscar una versión nueva", grupo: "permisos", palabras: "actualizar actualizacion version nueva update descargar instalar build", soloAndroid: true },
  { id: "probar-aviso", titulo: "Probar aviso en este teléfono", ayuda: "Comprueba que las notificaciones llegan", grupo: "permisos", palabras: "probar prueba aviso notificacion notificaciones sonido llega" },
  { id: "reforzada", titulo: "Protección reforzada", ayuda: "Mantiene Ojo Guard despierto en este teléfono", grupo: "permisos", palabras: "proteccion reforzada despierto segundo plano servicio notificacion fija bateria gasta ordenes tardan demora", soloAndroid: true },
  { id: "modo-android", titulo: "Modo personalizado (Android)", ayuda: "Mejora la confiabilidad de las órdenes remotas", grupo: "permisos", palabras: "modo personalizado no molestar silencio concentracion ordenes remotas confiabilidad", soloAndroid: true },
  { id: "nombre-telefono", titulo: "Datos del teléfono", ayuda: "El nombre de este teléfono", grupo: "perfil", palabras: "nombre telefono equipo alias como se llama datos celular" },
  { id: "apariencia", titulo: "Apariencia", ayuda: "Modo noche, fondo de pantalla y teclado", grupo: "perfil", palabras: "apariencia modo noche oscuro oscuro claro tema fondo pantalla teclado colores" },
  { id: "perdido-mensaje", titulo: "Modo perdido — mensaje de recuperación", ayuda: "Lo que verá quien encuentre el teléfono", grupo: "perdido", palabras: "perdido perdi extravio mensaje recuperacion recuperar contacto quien lo encuentre robo" },
  { id: "cercania", titulo: "Modo cercanía", ayuda: "Aviso cuando te alejas de tu teléfono o de tus cosas", grupo: "perdido", palabras: "cercania cerca lejos radio distancia alejas" },
  { id: "claves", titulo: "Claves de acceso", ayuda: "La clave de administrador de 6 números", grupo: "claves", palabras: "clave claves pin contrasena password codigo administrador acceso seguridad" },
  { id: "evidencia-ubicacion", titulo: "Evidencia y ubicación", ayuda: "Adjuntar la ubicación a la evidencia", grupo: "claves", palabras: "evidencia ubicacion adjuntar gps foto lugar donde" },
  { id: "deteccion-desbloqueo", titulo: "Detección de intentos de desbloqueo", ayuda: "Saca una foto sola si alguien insiste en entrar", grupo: "claves", palabras: "deteccion intentos desbloqueo desbloquear intruso intrusos ladron pin fallido foto sola camara", soloAndroid: true },
  { id: "preferencias", titulo: "Preferencias generales", ayuda: "Opciones generales de la app", grupo: "preferencias", palabras: "preferencias generales opciones configuracion ajustes" },
  { id: "pendientes", titulo: "Envíos pendientes", ayuda: "Lo que falta enviar", grupo: "preferencias", palabras: "envios pendientes enviar sin conexion internet cola falta mandar" },
  { id: "intentos", titulo: "Intentos de entrada", ayuda: "Fotos y registro de quien intentó entrar", grupo: "fotos", palabras: "intentos entrada intrusos intruso fotos foto camara galeria historial quien entro registro evidencias" },
  { id: "ms", titulo: "Ojo Guard MS · Teléfono principal", ayuda: "La conexión con el panel", grupo: "conexion", palabras: "ms panel consola vincular vinculado conexion cuenta enlace desvincular telefono principal web ordenes" },
  { id: "salud", titulo: "Salud y emergencias", ayuda: "Tu tarjeta de salud: lo que te piden en una emergencia", grupo: "configuracion", abre: "salud", palabras: "salud tarjeta sangre grupo sanguineo factor alergia alergias medicamentos remedios obra social prepaga credencial afiliado medico emergencia accidente donante cirugias datos medicos" },
  { id: "reloj", titulo: "Reloj con detección de caídas", ayuda: "Un complemento por si te caes y no puedes pedir ayuda", grupo: "configuracion", abre: "reloj", palabras: "reloj relojes caida caidas deteccion pulsera smartwatch apple watch galaxy watch video presentacion" },
  { id: "familia", titulo: "Familia y amigos", ayuda: "Unirme con un código, pausar mi ubicación y el SOS", grupo: "familia", palabras: "familia amigos codigo invitar unirme pausar ubicacion sos emergencia ayuda menores hijos compartir" },
];

export function normalizar(texto: string): string {
  return texto
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9ñ]+/g, " ")
    .trim()
    .replace(/\s+/g, " ");
}

/** Distancia de edición con trasposición (Damerau-Levenshtein, versión corta). */
export function distancia(a: string, b: string): number {
  if (a === b) return 0;
  const filas = a.length + 1, cols = b.length + 1;
  const d: number[][] = Array.from({ length: filas }, () => new Array<number>(cols).fill(0));
  for (let i = 0; i < filas; i++) (d[i] as number[])[0] = i;
  for (let j = 0; j < cols; j++) (d[0] as number[])[j] = j;
  for (let i = 1; i < filas; i++) {
    for (let j = 1; j < cols; j++) {
      const costo = a[i - 1] === b[j - 1] ? 0 : 1;
      let v = Math.min((d[i - 1] as number[])[j]! + 1, (d[i] as number[])[j - 1]! + 1, (d[i - 1] as number[])[j - 1]! + costo);
      if (i > 1 && j > 1 && a[i - 1] === b[j - 2] && a[i - 2] === b[j - 1]) v = Math.min(v, (d[i - 2] as number[])[j - 2]! + 1);
      (d[i] as number[])[j] = v;
    }
  }
  return (d[filas - 1] as number[])[cols - 1]!;
}

/** Cuánto se parece una palabra escrita a una palabra del índice: 0 = nada. */
function puntosDePalabra(escrita: string, palabra: string): number {
  if (palabra === escrita) return 3;
  if (escrita.length >= 2 && palabra.startsWith(escrita)) return 2.5;
  if (escrita.length >= 3 && palabra.includes(escrita)) return 1.5;
  if (escrita.length >= 4) {
    const maximo = escrita.length >= 8 ? 2 : 1;
    // Un error de una letra puntúa más que uno de dos: así "alerjias" prefiere "alergias" antes que una palabra que se parece menos.
    const completa = distancia(escrita, palabra);
    if (completa <= maximo) return completa <= 1 ? 1.2 : 0.9;
    // Se está escribiendo todavía y ya hay un error: se compara contra el principio de la palabra.
    if (palabra.length > escrita.length) {
      const inicio = distancia(escrita, palabra.slice(0, escrita.length));
      if (inicio <= maximo) return inicio <= 1 ? 1.1 : 0.8;
    }
  }
  return 0;
}

type Preparada = { entrada: EntradaBusqueda; titulo: string[]; resto: string[] };

function preparar(entrada: EntradaBusqueda): Preparada {
  return {
    entrada,
    titulo: normalizar(entrada.titulo).split(" ").filter(Boolean),
    resto: normalizar(`${entrada.ayuda} ${entrada.palabras}`).split(" ").filter(Boolean),
  };
}

const PREPARADAS = INDICE_AJUSTES.map(preparar);

function puntosEntrada(p: Preparada, palabras: string[], exigirTodas: boolean): number {
  let total = 0, acertadas = 0;
  for (const w of palabras) {
    let mejor = 0;
    for (const t of p.titulo) mejor = Math.max(mejor, puntosDePalabra(w, t) + 0.8 * (puntosDePalabra(w, t) > 0 ? 1 : 0));
    for (const t of p.resto) mejor = Math.max(mejor, puntosDePalabra(w, t));
    if (mejor > 0) acertadas++;
    total += mejor;
  }
  if (exigirTodas && acertadas < palabras.length) return 0;
  if (!exigirTodas && acertadas === 0) return 0;
  return total / palabras.length + (acertadas === palabras.length ? 0.5 : 0);
}

/** Palabras que no dicen nada por sí solas ("se cae", "el pin"): se ignoran mientras haya otras palabras con las que buscar. */
const PALABRAS_VACIAS = new Set(["de", "del", "la", "el", "los", "las", "lo", "le", "se", "me", "mi", "mis", "tu", "tus", "te", "un", "una", "unos", "unas", "y", "o", "a", "al", "en", "que", "por", "con", "para", "es"]);

export type ResultadoBusqueda = { entrada: EntradaBusqueda; exacto: boolean };

/** Busca mientras se escribe. `android` filtra lo que solo existe en Android o solo en iPhone. */
export function buscarEnAjustes(consulta: string, android: boolean, limite = 6): { resultados: ResultadoBusqueda[]; aproximado: boolean } {
  const todas = normalizar(consulta).split(" ").filter(Boolean);
  const utiles = todas.filter((w) => !PALABRAS_VACIAS.has(w));
  const palabras = utiles.length ? utiles : todas;
  if (!palabras.length || palabras.join("").length < 2) return { resultados: [], aproximado: false };
  const visibles = PREPARADAS.filter((p) => !(android ? p.entrada.soloIphone : p.entrada.soloAndroid));
  const con = (exigir: boolean) =>
    visibles
      .map((p) => ({ p, puntos: puntosEntrada(p, palabras, exigir) }))
      .filter((x) => x.puntos > 0)
      .sort((a, b) => b.puntos - a.puntos || a.p.entrada.titulo.localeCompare(b.p.entrada.titulo, "es"))
      .slice(0, limite);
  const justos = con(true);
  if (justos.length) return { resultados: justos.map((x) => ({ entrada: x.p.entrada, exacto: true })), aproximado: false };
  const parecidos = palabras.length > 1 ? con(false) : [];
  return { resultados: parecidos.map((x) => ({ entrada: x.p.entrada, exacto: false })), aproximado: parecidos.length > 0 };
}

/** Lo que se ofrece antes de escribir nada. */
export const BUSQUEDAS_FRECUENTES = ["Batería", "Fotos", "Clave (PIN)", "Modo perdido", "Permisos", "Actualizar"];
