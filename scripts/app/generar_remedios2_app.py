# Genera scripts/aplicar-remedios2-app.ps1: REMEDIOS v2 (app, PROXIMA build). A pedido de Luciano (12/11/2026) tras probar la 199:
#  - Varios remedios a la misma hora: llega UN aviso con todos, "Lo tomé" confirma todos juntos; "Agregar otro con este horario" copia el horario.
#  - Frecuencia: Todos los dias / Algunos dias (lunes a viernes, fines de semana o los que elijas) / Una vez al mes (dia del mes).
import ast
import re
R = '/home/user/Murray/scripts/'
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"

# Los bloques de la v1 (lo que ya esta en la app), tal cual los dejo el instalador anterior.
g1 = open(R + 'app/generar_remedios_app.py', encoding='utf-8').read()
ns = {}
arbol = ast.parse(g1)
for nodo in arbol.body:
    if isinstance(nodo, ast.Assign) and len(nodo.targets) == 1 and isinstance(nodo.targets[0], ast.Name) and re.fullmatch(r'[AB][1-7]', nodo.targets[0].id):
        exec(compile(ast.Module([nodo], []), 'g1', 'exec'), ns)
OLD_API = ns['B1'][:-len(ns['A1'])]
OLD_PANT = ns['B3'][:-len(ns['A3'])]
OLD_APP = ns['B5'][:-len(ns['A5'])]
assert OLD_API.startswith('/** Remedios (opcional') and OLD_PANT.startswith('// ----') and OLD_APP.startswith('      // Tocar el aviso de un remedio')

# ---------------- remoteApi.ts ----------------
NEW_API = OLD_API
def rep(txt, a, b):
    assert txt.count(a) == 1, (txt.count(a), a[:80])
    return txt.replace(a, b)
NEW_API = rep(NEW_API, 'export type RemedioItem = { id: string; nombre: string; horas: string[]; dias: number[]; activo: boolean };', 'export type RemedioItem = { id: string; nombre: string; horas: string[]; dias: number[]; activo: boolean; diaMes: number | null };')
NEW_API = rep(NEW_API, 'dias: Array.isArray(i.dias) ? i.dias.map((d) => Number(d)) : [], activo: i.activo !== false }))', 'dias: Array.isArray(i.dias) ? i.dias.map((d) => Number(d)) : [], activo: i.activo !== false, diaMes: i.diaMes === null || i.diaMes === undefined ? null : Number(i.diaMes) }))')
NEW_API = rep(NEW_API, 'export async function saveRemedio(enrollment: NativeEnrollment, remedio: { id?: string; nombre: string; horas: string[]; dias: number[]; activo?: boolean }) {', 'export async function saveRemedio(enrollment: NativeEnrollment, remedio: { id?: string; nombre: string; horas: string[]; dias: number[]; diaMes?: number | null; activo?: boolean }) {')
NEW_API = rep(NEW_API, 'export async function confirmRemedio(enrollment: NativeEnrollment, toma: { dosisId?: string; itemId?: string; hhmm?: string }) {', 'export async function confirmRemedio(enrollment: NativeEnrollment, toma: { dosisId?: string; dosisIds?: string[]; itemId?: string; hhmm?: string }) {')
NEW_API = rep(NEW_API, '/** "Lo tome": con el aviso (dosisId) o una toma que todavia no tenia aviso (itemId + hora). */', '/** "Lo tome": con el aviso (dosisId o dosisIds, todos los de una hora) o una toma que todavia no tenia aviso (itemId + hora). */')

# ---------------- FamiliaPantalla.tsx ----------------
NEW_PANT = r'''// ---------------------------------------------------------------------------
// Remedios: los carga, los prende y los apaga la propia persona (nadie decide por ella). A cada hora le llega UN aviso con todos los de esa hora y toca "Lo tomé".
// Se cargan todos los dias, algunos dias de la semana o una vez al mes. Opcional (apagado): avisar a quienes reciben su SOS si no lo confirma, sin decir el remedio (son datos de salud).
// ---------------------------------------------------------------------------
const DIAS_REMEDIO = ["dom", "lun", "mar", "mié", "jue", "vie", "sáb"];
const ORDEN_DIAS_REMEDIO = [1, 2, 3, 4, 5, 6, 0];
const TODOS_LOS_DIAS = [0, 1, 2, 3, 4, 5, 6];
type FrecuenciaRemedio = "diaria" | "semanal" | "mensual";
type BorradorRemedio = { id: string | null; nombre: string; horas: string[]; frecuencia: FrecuenciaRemedio; dias: number[]; diaMes: number; hora: string };

function mismosDias(a: number[], b: number[]): boolean {
  return a.length === b.length && b.every((d) => a.includes(d));
}

/** "todos los días", "lunes a viernes", "fines de semana", "lun, mié, vie" o "el día 15 de cada mes". */
function textoFrecuenciaRemedio(it: { dias: number[]; diaMes: number | null }): string {
  if (it.diaMes !== null) return `el día ${it.diaMes} de cada mes`;
  if (it.dias.length === 7) return "todos los días";
  if (mismosDias(it.dias, [1, 2, 3, 4, 5])) return "lunes a viernes";
  if (mismosDias(it.dias, [0, 6])) return "fines de semana";
  return ORDEN_DIAS_REMEDIO.filter((d) => it.dias.includes(d)).map((d) => DIAS_REMEDIO[d] ?? "").join(", ");
}

/** Mueve una hora "HH:MM" de a 30 minutos (da la vuelta a las 24 h). */
function moverHoraRemedio(hhmm: string, pasos: number): string {
  const total = Number(hhmm.slice(0, 2)) * 60 + Number(hhmm.slice(3, 5));
  const nuevo = (((total + pasos * 30) % 1440) + 1440) % 1440;
  return `${String(Math.floor(nuevo / 60)).padStart(2, "0")}:${String(nuevo % 60).padStart(2, "0")}`;
}

function TarjetaRemedios({ P, enrollment, botones }: { P: Paleta; enrollment: NativeEnrollment; botones: { primario: StyleProp<ViewStyle>; primarioTexto: StyleProp<TextStyle>; ayuda: StyleProp<TextStyle> } }) {
  const sp = estilosPermisos(P);
  const [rem, setRem] = useState<RemediosEstado | null>(null);
  const [borrador, setBorrador] = useState<BorradorRemedio | null>(null);
  const [guardando, setGuardando] = useState<string[]>([]);
  const [aviso, setAviso] = useState("");
  const cargar = useCallback(async () => {
    try {
      setRem(await fetchRemedios(enrollment));
    } catch {
      // Sin conexion o con un servidor viejo: la tarjeta simplemente no se muestra.
    }
  }, [enrollment]);
  useEffect(() => {
    void cargar();
  }, [cargar]);
  // Al volver a la app se actualiza lo de hoy (por si lo confirmo desde el aviso).
  useEffect(() => {
    const suscripcion = AppState.addEventListener("change", (estadoApp) => {
      if (estadoApp === "active") void cargar();
    });
    return () => suscripcion.remove();
  }, [cargar]);
  if (!rem) return null;
  const actual = rem;
  const ocupado = (marca: string) => guardando.includes(marca);
  const correr = async (marca: string, accion: () => Promise<void>) => {
    if (ocupado(marca)) return;
    setAviso("");
    setGuardando((g) => [...g, marca]);
    try {
      await accion();
      await cargar();
    } catch (error) {
      const codigo = error instanceof Error ? error.message : "";
      setAviso(
        codigo === "too_many"
          ? `Podés cargar hasta ${actual.max.items} remedios.`
          : codigo === "no_recipients"
            ? "Todavía no hay nadie que reciba tu SOS. Sumá a alguien antes de prender este aviso."
            : "No se pudo guardar. Probá de nuevo.",
      );
      void cargar();
    } finally {
      setGuardando((g) => g.filter((x) => x !== marca));
    }
  };
  const nuevo = () => {
    setAviso("");
    setBorrador({ id: null, nombre: "", horas: [], frecuencia: "diaria", dias: TODOS_LOS_DIAS, diaMes: 1, hora: "08:00" });
  };
  const frecuenciaDe = (it: RemedioItem): FrecuenciaRemedio => (it.diaMes !== null ? "mensual" : it.dias.length === 7 ? "diaria" : "semanal");
  const editar = (it: RemedioItem) => {
    setAviso("");
    setBorrador({ id: it.id, nombre: it.nombre, horas: it.horas, frecuencia: frecuenciaDe(it), dias: it.dias.length ? it.dias : TODOS_LOS_DIAS, diaMes: it.diaMes ?? 1, hora: it.horas[0] ?? "08:00" });
  };
  // Varios remedios a la misma hora: se copia el horario y solo se escribe el nombre.
  const otroConEsteHorario = (it: RemedioItem) => {
    setAviso("");
    setBorrador({ id: null, nombre: "", horas: it.horas, frecuencia: frecuenciaDe(it), dias: it.dias.length ? it.dias : TODOS_LOS_DIAS, diaMes: it.diaMes ?? 1, hora: it.horas[0] ?? "08:00" });
  };
  const guardarBorrador = () => {
    if (!borrador) return;
    const nombre = borrador.nombre.trim();
    if (!nombre) {
      setAviso("Escribí el nombre del remedio.");
      return;
    }
    if (!borrador.horas.length) {
      setAviso("Agregá al menos una hora con «Agregar esta hora».");
      return;
    }
    if (borrador.frecuencia === "semanal" && !borrador.dias.length) {
      setAviso("Elegí al menos un día de la semana.");
      return;
    }
    const dias = borrador.frecuencia === "semanal" ? borrador.dias : TODOS_LOS_DIAS;
    const datos = { ...(borrador.id ? { id: borrador.id } : {}), nombre, horas: borrador.horas, dias, diaMes: borrador.frecuencia === "mensual" ? borrador.diaMes : null };
    void correr("guardar", async () => {
      await saveRemedio(enrollment, datos);
      setBorrador(null);
    });
  };
  const agregarHora = () => {
    if (!borrador) return;
    if (borrador.horas.includes(borrador.hora)) return;
    if (borrador.horas.length >= actual.max.horas) {
      setAviso(`Hasta ${actual.max.horas} horas por remedio.`);
      return;
    }
    setAviso("");
    setBorrador({ ...borrador, horas: [...borrador.horas, borrador.hora].sort() });
  };
  const elegirFrecuencia = (frecuencia: FrecuenciaRemedio) => {
    if (!borrador) return;
    // Al pasar a "algunos dias" se arranca sin ninguno marcado (se eligen); al volver a "todos los dias" se marcan los siete.
    setBorrador({ ...borrador, frecuencia, dias: frecuencia === "semanal" ? (borrador.dias.length === 7 ? [] : borrador.dias) : TODOS_LOS_DIAS });
  };
  const alternarDia = (d: number) => {
    if (!borrador) return;
    setBorrador({ ...borrador, dias: borrador.dias.includes(d) ? borrador.dias.filter((x) => x !== d) : [...borrador.dias, d] });
  };
  const alternarActivo = (it: RemedioItem) => void correr(`activo-${it.id}`, () => saveRemedio(enrollment, { id: it.id, nombre: it.nombre, horas: it.horas, dias: it.dias, diaMes: it.diaMes, activo: !it.activo }));
  const borrar = (it: RemedioItem) =>
    Alert.alert(`¿Borrar ${it.nombre}?`, "Dejás de recibir su recordatorio.", [
      { text: "Cancelar", style: "cancel" },
      { text: "Borrar", style: "destructive", onPress: () => void correr(`borrar-${it.id}`, () => deleteRemedio(enrollment, it.id)) },
    ]);
  const tome = (t: RemedioToma) => void correr(`ok-${t.itemId}-${t.hhmm}`, () => confirmRemedio(enrollment, t.dosisId ? { dosisId: t.dosisId } : { itemId: t.itemId, hhmm: t.hhmm }));
  const tomeTodos = (hhmm: string, pendientes: RemedioToma[]) =>
    void correr(`ok-hora-${hhmm}`, () => confirmRemedio(enrollment, { dosisIds: pendientes.map((t) => t.dosisId).filter((x): x is string => typeof x === "string") }));
  const cambiarPrefs = (marca: string, cambios: { avisar?: boolean; limiteMin?: number }) => {
    setRem({ ...actual, prefs: { ...actual.prefs, ...cambios } });
    void correr(marca, () => setRemediosPrefs(enrollment, cambios));
  };
  const hoy = actual.hoy.filter((t) => t.estado !== "sin_aviso");
  const horasDeHoy = [...new Set(hoy.map((t) => t.hhmm))].sort();
  const hayActivos = actual.items.some((i) => i.activo);
  const chip = (activa: boolean) => ({ backgroundColor: activa ? P.doradoFondo : P.campo, borderColor: activa ? P.doradoBorde : P.borde, borderRadius: 12, borderWidth: 1, paddingHorizontal: 12, paddingVertical: 8 });
  const chipTexto = (activa: boolean) => ({ color: activa ? P.doradoTexto : P.textoClaro, fontSize: 13.5, fontWeight: "700" as const });
  const enlace = { color: P.textoClaro, fontSize: 13.5, fontWeight: "700" as const, textDecorationLine: "underline" as const };
  return (
    <>
      <Text style={{ color: P.textoDebil, fontSize: 12, fontWeight: "800", letterSpacing: 1.1, marginBottom: 8, marginTop: 20 }}>REMEDIOS</Text>
      <View style={{ backgroundColor: P.superficie, borderColor: P.borde, borderRadius: 18, borderWidth: 1, gap: 10, padding: 16 }}>
        <Text maxFontSizeMultiplier={TOPE_LETRA} style={botones.ayuda}>
          Recordatorios opcionales: los cargás y los apagás vos. A cada hora te llega un solo aviso con todos los remedios de esa hora; tocá «Lo tomé» para confirmar.
        </Text>
        {hoy.length ? (
          <>
            <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.separador}>HOY</Text>
            {horasDeHoy.map((hhmm) => {
              const delaHora = hoy.filter((t) => t.hhmm === hhmm);
              const pendientes = delaHora.filter((t) => (t.estado === "esperando" || t.estado === "sin_confirmar") && t.dosisId !== null);
              return (
                <View key={hhmm} style={{ gap: 4 }}>
                  {delaHora.map((t) => (
                    <View key={`${t.itemId}-${t.hhmm}`} style={sp.fila}>
                      <Text maxFontSizeMultiplier={TOPE_LETRA} style={{ color: P.texto, fontSize: 14.5, fontWeight: "800", width: 54 }}>{t === delaHora[0] ? t.hhmm : ""}</Text>
                      <Text maxFontSizeMultiplier={TOPE_LETRA} numberOfLines={1} style={{ color: P.textoClaro, flex: 1, fontSize: 14 }}>{t.nombre}</Text>
                      {t.estado === "tomado" ? (
                        <Text maxFontSizeMultiplier={TOPE_LETRA} style={{ color: P.exito, fontSize: 13, fontWeight: "800" }}>✓ Tomado</Text>
                      ) : t.estado === "programado" ? (
                        <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.nota}>Más tarde</Text>
                      ) : pendientes.length > 1 ? null : (
                        <Pressable accessibilityRole="button" accessibilityLabel={`Lo tomé: ${t.nombre}`} disabled={ocupado(`ok-${t.itemId}-${t.hhmm}`)} onPress={() => tome(t)} style={chip(true)}>
                          <Text maxFontSizeMultiplier={TOPE_LETRA} style={chipTexto(true)}>Lo tomé</Text>
                        </Pressable>
                      )}
                    </View>
                  ))}
                  {pendientes.length > 1 ? (
                    <Pressable accessibilityRole="button" accessibilityLabel={`Lo tomé todo lo de las ${hhmm}`} disabled={ocupado(`ok-hora-${hhmm}`)} onPress={() => tomeTodos(hhmm, pendientes)} style={[chip(true), { alignSelf: "flex-start", marginLeft: 54 }]}>
                      <Text maxFontSizeMultiplier={TOPE_LETRA} style={chipTexto(true)}>{`Los tomé todos (${pendientes.length})`}</Text>
                    </Pressable>
                  ) : null}
                </View>
              );
            })}
          </>
        ) : null}
        {actual.items.length ? <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.separador}>MIS REMEDIOS</Text> : null}
        {actual.items.map((it) => (
          <View key={it.id} style={{ borderColor: P.borde, borderRadius: 12, borderWidth: 1, gap: 6, padding: 10 }}>
            <View style={sp.fila}>
              <View style={{ flex: 1, minWidth: 0 }}>
                <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.titulo}>{it.nombre}</Text>
                <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.detalle}>{`${it.horas.join(" · ")} · ${textoFrecuenciaRemedio(it)}`}</Text>
              </View>
              <Pressable accessibilityRole="switch" accessibilityState={{ checked: it.activo }} accessibilityLabel={`Recordatorio de ${it.nombre}`} disabled={ocupado(`activo-${it.id}`)} onPress={() => alternarActivo(it)} style={[sp.pastilla, { backgroundColor: it.activo ? P.exitoFondo : P.peligroFondo, borderColor: it.activo ? P.exitoBorde : P.peligroBorde, opacity: ocupado(`activo-${it.id}`) ? 0.55 : 1 }]}>
                <View style={[sp.punto, { backgroundColor: it.activo ? P.exito : (P.peligroFuerte ?? P.peligro) }]} />
                <Text maxFontSizeMultiplier={TOPE_LETRA} style={[sp.pastillaTexto, { color: it.activo ? P.exito : (P.peligroFuerte ?? P.peligro) }]}>{it.activo ? "Sí" : "No"}</Text>
              </Pressable>
            </View>
            <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 16 }}>
              <Pressable accessibilityRole="button" onPress={() => editar(it)}>
                <Text maxFontSizeMultiplier={TOPE_LETRA} style={enlace}>Editar</Text>
              </Pressable>
              <Pressable accessibilityRole="button" disabled={actual.items.length >= actual.max.items} onPress={() => otroConEsteHorario(it)}>
                <Text maxFontSizeMultiplier={TOPE_LETRA} style={enlace}>Agregar otro con este horario</Text>
              </Pressable>
              <Pressable accessibilityRole="button" onPress={() => borrar(it)}>
                <Text maxFontSizeMultiplier={TOPE_LETRA} style={{ ...enlace, color: P.peligroFuerte ?? P.peligro }}>Borrar</Text>
              </Pressable>
            </View>
          </View>
        ))}
        {borrador ? (
          <View style={{ borderTopColor: P.borde, borderTopWidth: 1, gap: 8, paddingTop: 12 }}>
            <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.separador}>{borrador.id ? "EDITAR REMEDIO" : "NUEVO REMEDIO"}</Text>
            <TextInput
              accessibilityLabel="Nombre del remedio"
              autoCapitalize="sentences"
              maxLength={40}
              onChangeText={(texto) => setBorrador({ ...borrador, nombre: texto })}
              placeholder="Nombre del remedio"
              placeholderTextColor={P.textoDebil}
              style={{ backgroundColor: P.campo, borderColor: P.borde, borderRadius: 12, borderWidth: 1, color: P.texto, fontSize: 16, paddingHorizontal: 12, paddingVertical: 10 }}
              value={borrador.nombre}
            />
            <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.separador}>HORAS</Text>
            {borrador.horas.length ? (
              <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 6 }}>
                {borrador.horas.map((h) => (
                  <Pressable key={h} accessibilityRole="button" accessibilityLabel={`Quitar la hora ${h}`} onPress={() => setBorrador({ ...borrador, horas: borrador.horas.filter((x) => x !== h) })} style={chip(true)}>
                    <Text maxFontSizeMultiplier={TOPE_LETRA} style={chipTexto(true)}>{`${h}  ✕`}</Text>
                  </Pressable>
                ))}
              </View>
            ) : (
              <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.nota}>Elegí la hora y tocá «Agregar esta hora». Podés poner varias. Si tomás varios remedios a la misma hora, cargá cada uno con esa hora: te llega un solo aviso.</Text>
            )}
            <View style={{ alignItems: "center", flexDirection: "row", flexWrap: "wrap", gap: 10 }}>
              <Pressable accessibilityRole="button" accessibilityLabel="Hora anterior" onPress={() => setBorrador({ ...borrador, hora: moverHoraRemedio(borrador.hora, -1) })} style={chip(false)}>
                <Text maxFontSizeMultiplier={TOPE_LETRA} style={chipTexto(false)}>−</Text>
              </Pressable>
              <Text maxFontSizeMultiplier={TOPE_LETRA} style={{ color: P.texto, fontSize: 20, fontWeight: "800", minWidth: 64, textAlign: "center" }}>{borrador.hora}</Text>
              <Pressable accessibilityRole="button" accessibilityLabel="Hora siguiente" onPress={() => setBorrador({ ...borrador, hora: moverHoraRemedio(borrador.hora, 1) })} style={chip(false)}>
                <Text maxFontSizeMultiplier={TOPE_LETRA} style={chipTexto(false)}>+</Text>
              </Pressable>
              <Pressable accessibilityRole="button" onPress={agregarHora} style={chip(true)}>
                <Text maxFontSizeMultiplier={TOPE_LETRA} style={chipTexto(true)}>Agregar esta hora</Text>
              </Pressable>
            </View>
            <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.separador}>CADA CUÁNTO</Text>
            <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 6 }}>
              {([["diaria", "Todos los días"], ["semanal", "Algunos días"], ["mensual", "Una vez al mes"]] as [FrecuenciaRemedio, string][]).map(([valor, texto]) => (
                <Pressable key={valor} accessibilityRole="button" accessibilityState={{ selected: borrador.frecuencia === valor }} onPress={() => elegirFrecuencia(valor)} style={chip(borrador.frecuencia === valor)}>
                  <Text maxFontSizeMultiplier={TOPE_LETRA} style={chipTexto(borrador.frecuencia === valor)}>{texto}</Text>
                </Pressable>
              ))}
            </View>
            {borrador.frecuencia === "semanal" ? (
              <>
                <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 6 }}>
                  {ORDEN_DIAS_REMEDIO.map((d) => (
                    <Pressable key={d} accessibilityRole="button" accessibilityState={{ selected: borrador.dias.includes(d) }} onPress={() => alternarDia(d)} style={chip(borrador.dias.includes(d))}>
                      <Text maxFontSizeMultiplier={TOPE_LETRA} style={chipTexto(borrador.dias.includes(d))}>{DIAS_REMEDIO[d] ?? ""}</Text>
                    </Pressable>
                  ))}
                </View>
                <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 16 }}>
                  <Pressable accessibilityRole="button" onPress={() => setBorrador({ ...borrador, dias: [1, 2, 3, 4, 5] })}>
                    <Text maxFontSizeMultiplier={TOPE_LETRA} style={enlace}>Lunes a viernes</Text>
                  </Pressable>
                  <Pressable accessibilityRole="button" onPress={() => setBorrador({ ...borrador, dias: [0, 6] })}>
                    <Text maxFontSizeMultiplier={TOPE_LETRA} style={enlace}>Fines de semana</Text>
                  </Pressable>
                  <Pressable accessibilityRole="button" onPress={() => setBorrador({ ...borrador, dias: [] })}>
                    <Text maxFontSizeMultiplier={TOPE_LETRA} style={enlace}>Borrar elección</Text>
                  </Pressable>
                </View>
                {!borrador.dias.length ? <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.nota}>Tocá los días en que lo tomás.</Text> : null}
              </>
            ) : null}
            {borrador.frecuencia === "mensual" ? (
              <>
                <View style={{ alignItems: "center", flexDirection: "row", gap: 10 }}>
                  <Pressable accessibilityRole="button" accessibilityLabel="Día anterior" onPress={() => setBorrador({ ...borrador, diaMes: borrador.diaMes <= 1 ? 31 : borrador.diaMes - 1 })} style={chip(false)}>
                    <Text maxFontSizeMultiplier={TOPE_LETRA} style={chipTexto(false)}>−</Text>
                  </Pressable>
                  <Text maxFontSizeMultiplier={TOPE_LETRA} style={{ color: P.texto, fontSize: 20, fontWeight: "800", minWidth: 120, textAlign: "center" }}>{`Día ${borrador.diaMes}`}</Text>
                  <Pressable accessibilityRole="button" accessibilityLabel="Día siguiente" onPress={() => setBorrador({ ...borrador, diaMes: borrador.diaMes >= 31 ? 1 : borrador.diaMes + 1 })} style={chip(false)}>
                    <Text maxFontSizeMultiplier={TOPE_LETRA} style={chipTexto(false)}>+</Text>
                  </Pressable>
                </View>
                {borrador.diaMes > 28 ? <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.nota}>En los meses que no tienen ese día, te avisa el último día del mes.</Text> : null}
              </>
            ) : null}
            <Pressable accessibilityRole="button" disabled={ocupado("guardar")} onPress={guardarBorrador} style={botones.primario}>
              <Text style={botones.primarioTexto}>{ocupado("guardar") ? "Guardando…" : "Guardar remedio"}</Text>
            </Pressable>
            <Pressable accessibilityRole="button" onPress={() => { setBorrador(null); setAviso(""); }}>
              <Text maxFontSizeMultiplier={TOPE_LETRA} style={enlace}>Cancelar</Text>
            </Pressable>
          </View>
        ) : (
          <Pressable accessibilityRole="button" disabled={actual.items.length >= actual.max.items} onPress={nuevo} style={botones.primario}>
            <Text style={botones.primarioTexto}>{actual.items.length ? "Agregar otro remedio" : "Agregar un remedio"}</Text>
          </Pressable>
        )}
        {hayActivos ? (
          <>
            <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.separador}>SI NO LO CONFIRMO</Text>
            <FilaCuidado
              P={P}
              titulo="Avisar a mi familia"
              detalle={actual.destinatarios.length ? `Se avisa a: ${listaDeNombres(actual.destinatarios)}. No decimos qué remedio.` : "Todavía no hay nadie que reciba tu SOS."}
              on={actual.prefs.avisar}
              guardando={ocupado("avisar")}
              onPress={() => cambiarPrefs("avisar", { avisar: !actual.prefs.avisar })}
            />
            {actual.prefs.avisar ? (
              <OpcionesCuidado P={P} titulo="SI NO LO CONFIRMO EN" opciones={PLAZOS_BUEN_DIA.map((p) => ({ valor: String(p.min), texto: p.texto }))} elegida={String(actual.prefs.limiteMin)} onElegir={(v) => cambiarPrefs("limite", { limiteMin: Number(v) })} />
            ) : null}
          </>
        ) : null}
        {aviso ? <View style={sp.cartel}><Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.cartelTexto}>{aviso}</Text></View> : null}
      </View>
    </>
  );
}

'''

# ---------------- App.tsx ----------------
NEW_APP = r'''      // Tocar el aviso de un remedio pregunta si lo tomo (solo tocar el aviso NO lo marca: hay que decir que si). Si son varios de la misma hora, los confirma todos juntos.
      const preguntarRemedio = (respuesta: { notification: { request: { content: { data?: unknown; body?: string | null } } } } | null | undefined) => {
        const contenido = respuesta?.notification.request.content;
        const datos = contenido?.data as { type?: string; dosisId?: string; dosisIds?: string[] } | null | undefined;
        if (datos?.type !== "remedio") return;
        const dosisIds = Array.isArray(datos.dosisIds) && datos.dosisIds.length ? datos.dosisIds.map((x) => String(x)) : typeof datos.dosisId === "string" ? [datos.dosisId] : [];
        if (!dosisIds.length) return;
        Alert.alert("Remedio", `${contenido?.body ?? "¿Tomaste tu remedio?"}`, [
          { text: "Todavía no", style: "cancel" },
          {
            text: dosisIds.length > 1 ? "Los tomé" : "Lo tomé",
            onPress: () =>
              void loadNativeEnrollment()
                .then(async (vinculo) => {
                  if (!vinculo) return;
                  const { confirmRemedio } = await import("./src/remoteApi");
                  await confirmRemedio(vinculo, { dosisIds });
                })
                .catch(() => Alert.alert("No se pudo avisar", "Abrí Ojo Guard, entrá a Familia y amigos, buscá Remedios y tocá «Lo tomé».")),
          },
        ]);
      };
'''
pares = [('src\\remoteApi.ts', 'remedios v2: llamadas con dia del mes y varios a la vez', OLD_API, NEW_API),
         ('src\\FamiliaPantalla.tsx', 'remedios v2: tarjeta con semana, mes y varios a la misma hora', OLD_PANT, NEW_PANT),
         ('App.tsx', 'remedios v2: tocar el aviso confirma todos los de la hora', OLD_APP, NEW_APP)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in pares) + "\n)\n"
cabeza = '''# aplicar-remedios2-app.ps1 - App (PROXIMA build): REMEDIOS v2. A pedido de Luciano (12/11/2026) tras probar la 199:
#  - Varios remedios a la misma hora: un solo aviso con todos y "Lo tome" confirma todos; "Agregar otro con este horario" copia el horario.
#  - "Cada cuanto": todos los dias / algunos dias (lunes a viernes, fines de semana o los que elijas, sin obligar a dejar uno marcado) / una vez al mes (dia del mes).
# Requiere aplicar-remedios-app.ps1 y el servidor aplicar-remedios2-panel.ps1. Toca src\\remoteApi.ts, src\\FamiliaPantalla.tsx y App.tsx (respaldo .bak-remedios2). Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba.
'''
i0 = base.index('$ErrorActionPreference'); j0 = base.index('Ok "Carpeta correcta"')
guardas = '''Ok "Carpeta correcta"
foreach ($f in @("src\\FamiliaPantalla.tsx", "src\\remoteApi.ts", "App.tsx")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\\FamiliaPantalla.tsx")).texto 'function TarjetaRemedios') -eq 0) { Mal "Falta aplicar primero aplicar-remedios-app.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\\FamiliaPantalla.tsx")).texto 'function textoFrecuenciaRemedio') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('.bak-version', '.bak-remedios2')
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "LISTO: la app compila bien. Sale en la PROXIMA build."', cola)
assert 'bak-version' not in cola
total = cabeza + base[i0:j0] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕']
assert not bad, set(bad)
open(R + 'aplicar-remedios2-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
# Replicas para probar
f = open(S + 'FamiliaPantalla-remedios.tsx', encoding='utf-8').read().replace('\r\n', '\n')
assert f.count(OLD_PANT) == 1, f.count(OLD_PANT)
open(S + 'FamiliaPantalla-remedios2.tsx', 'w', encoding='utf-8').write(f.replace(OLD_PANT, NEW_PANT))
open(S + 'remoteApi-remedios2-bloque.ts', 'w', encoding='utf-8').write(NEW_API)
open(S + 'App-remedios2-bloque.txt', 'w', encoding='utf-8').write(NEW_APP)
print('ok', len(total))
