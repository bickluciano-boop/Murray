/**
 * Registro mínimo para que el BUSCADOR de Ajustes pueda abrir cosas que no son un grupo de Ajustes sino una tarjeta con su propio estado
 * ("Salud y emergencias" abre su pantalla, "Reloj con detección de caídas" se despliega). Cada tarjeta se anota al aparecer en pantalla
 * (`registrarApertura`) y se borra sola al desaparecer; el buscador la llama por su nombre (`abrirDesdeBuscador`). Si la tarjeta no está en pantalla, no pasa nada.
 */
const registro = new Map<string, () => void>();

export function registrarApertura(id: string, abrir: () => void): () => void {
  registro.set(id, abrir);
  return () => {
    if (registro.get(id) === abrir) registro.delete(id);
  };
}

export function abrirDesdeBuscador(id: string): boolean {
  const abrir = registro.get(id);
  if (!abrir) return false;
  abrir();
  return true;
}
