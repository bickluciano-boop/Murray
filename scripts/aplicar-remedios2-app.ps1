# aplicar-remedios2-app.ps1 - App (PROXIMA build): REMEDIOS v2. A pedido de Luciano (12/11/2026) tras probar la 199:
#  - Varios remedios a la misma hora: un solo aviso con todos y "Lo tome" confirma todos; "Agregar otro con este horario" copia el horario.
#  - "Cada cuanto": todos los dias / algunos dias (lunes a viernes, fines de semana o los que elijas, sin obligar a dejar uno marcado) / una vez al mes (dia del mes).
# Requiere aplicar-remedios-app.ps1 y el servidor aplicar-remedios2-panel.ps1. Toca src\remoteApi.ts, src\FamiliaPantalla.tsx y App.tsx (respaldo .bak-remedios2). Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba.
$ErrorActionPreference = "Continue"
function Ok($t)  { Write-Host ("OK    " + $t) -ForegroundColor Green }
function Mal($t) { Write-Host ("MAL   " + $t) -ForegroundColor Red }
function Avi($t) { Write-Host ("AVISO " + $t) -ForegroundColor Yellow }
$raiz = (Get-Location).Path
function Contar([string]$donde, [string]$que) {
    if ([string]::IsNullOrEmpty($que)) { return 0 }
    $n = 0; $i = 0
    while ($true) { $i = $donde.IndexOf($que, $i, [System.StringComparison]::Ordinal); if ($i -lt 0) { break }; $n = $n + 1; $i = $i + $que.Length }
    return $n
}
function Leer([string]$ruta) {
    $bytes = [System.IO.File]::ReadAllBytes($ruta)
    $bom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    $texto = [System.IO.File]::ReadAllText($ruta, [System.Text.Encoding]::UTF8)
    return @{ texto = $texto; bom = $bom; crlf = $texto.Contains("`r`n") }
}
function Ajustar([string]$t, [bool]$crlf) { $x = ($t -replace "`r`n", "`n"); if ($crlf) { $x = $x -replace "`n", "`r`n" }; return $x }
function Sha([string]$ruta) { return (Get-FileHash -Algorithm SHA256 -LiteralPath $ruta).Hash.ToLower() }

if (-not (Test-Path (Join-Path $raiz "app.json")) -or (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta de la APP (la que tiene app.json), no la del panel."; return }
Ok "Carpeta correcta"
foreach ($f in @("src\FamiliaPantalla.tsx", "src\remoteApi.ts", "App.tsx")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\FamiliaPantalla.tsx")).texto 'function TarjetaRemedios') -eq 0) { Mal "Falta aplicar primero aplicar-remedios-app.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\FamiliaPantalla.tsx")).texto 'function textoFrecuenciaRemedio') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
$cambios = @(
    @('src\remoteApi.ts', 'remedios v2: llamadas con dia del mes y varios a la vez', '/** Remedios (opcional, los carga la propia persona): recordatorios con aviso a la hora y "Lo tome". */
export type RemedioItem = { id: string; nombre: string; horas: string[]; dias: number[]; activo: boolean };
export type RemedioToma = { itemId: string; nombre: string; hhmm: string; dosisId: string | null; estado: string };
export type RemediosEstado = {
  items: RemedioItem[];
  prefs: { avisar: boolean; limiteMin: number };
  hoy: RemedioToma[];
  destinatarios: string[];
  max: { items: number; horas: number };
};

export async function fetchRemedios(enrollment: NativeEnrollment): Promise<RemediosEstado> {
  const query = new URLSearchParams({ deviceId: enrollment.deviceId });
  const response = await nativeRequest(enrollment, `/api/native/care/med?${query.toString()}`);
  const r = (await response.json()) as Partial<RemediosEstado>;
  return {
    items: Array.isArray(r.items)
      ? r.items.map((i) => ({ id: String(i.id), nombre: String(i.nombre ?? ""), horas: Array.isArray(i.horas) ? i.horas.map((h) => String(h)) : [], dias: Array.isArray(i.dias) ? i.dias.map((d) => Number(d)) : [], activo: i.activo !== false }))
      : [],
    prefs: { avisar: r.prefs?.avisar === true, limiteMin: Number(r.prefs?.limiteMin) || 60 },
    hoy: Array.isArray(r.hoy)
      ? r.hoy.map((t) => ({ itemId: String(t.itemId), nombre: String(t.nombre ?? ""), hhmm: String(t.hhmm ?? ""), dosisId: typeof t.dosisId === "string" ? t.dosisId : null, estado: String(t.estado ?? "") }))
      : [],
    destinatarios: Array.isArray(r.destinatarios) ? r.destinatarios.map((x) => String(x)) : [],
    max: { items: Number(r.max?.items) || 8, horas: Number(r.max?.horas) || 6 },
  };
}

/** Crear (sin id) o cambiar (con id) uno de MIS remedios. */
export async function saveRemedio(enrollment: NativeEnrollment, remedio: { id?: string; nombre: string; horas: string[]; dias: number[]; activo?: boolean }) {
  await nativeRequest(enrollment, "/api/native/care/med/item", {
    method: "POST",
    body: JSON.stringify({ deviceId: enrollment.deviceId, tzOffsetMin: -new Date().getTimezoneOffset(), ...remedio }),
  });
}

export async function deleteRemedio(enrollment: NativeEnrollment, id: string) {
  await nativeRequest(enrollment, "/api/native/care/med/item/delete", { method: "POST", body: JSON.stringify({ deviceId: enrollment.deviceId, id }) });
}

/** "Avisar a mi familia si no lo confirmo" (apagado por defecto) y en cuanto tiempo. */
export async function setRemediosPrefs(enrollment: NativeEnrollment, cambios: { avisar?: boolean; limiteMin?: number }) {
  await nativeRequest(enrollment, "/api/native/care/med/prefs", { method: "POST", body: JSON.stringify({ deviceId: enrollment.deviceId, ...cambios }) });
}

/** "Lo tome": con el aviso (dosisId) o una toma que todavia no tenia aviso (itemId + hora). */
export async function confirmRemedio(enrollment: NativeEnrollment, toma: { dosisId?: string; itemId?: string; hhmm?: string }) {
  await nativeRequest(enrollment, "/api/native/care/med/ok", { method: "POST", body: JSON.stringify({ deviceId: enrollment.deviceId, ...toma }) });
}

', '/** Remedios (opcional, los carga la propia persona): recordatorios con aviso a la hora y "Lo tome". */
export type RemedioItem = { id: string; nombre: string; horas: string[]; dias: number[]; activo: boolean; diaMes: number | null };
export type RemedioToma = { itemId: string; nombre: string; hhmm: string; dosisId: string | null; estado: string };
export type RemediosEstado = {
  items: RemedioItem[];
  prefs: { avisar: boolean; limiteMin: number };
  hoy: RemedioToma[];
  destinatarios: string[];
  max: { items: number; horas: number };
};

export async function fetchRemedios(enrollment: NativeEnrollment): Promise<RemediosEstado> {
  const query = new URLSearchParams({ deviceId: enrollment.deviceId });
  const response = await nativeRequest(enrollment, `/api/native/care/med?${query.toString()}`);
  const r = (await response.json()) as Partial<RemediosEstado>;
  return {
    items: Array.isArray(r.items)
      ? r.items.map((i) => ({ id: String(i.id), nombre: String(i.nombre ?? ""), horas: Array.isArray(i.horas) ? i.horas.map((h) => String(h)) : [], dias: Array.isArray(i.dias) ? i.dias.map((d) => Number(d)) : [], activo: i.activo !== false, diaMes: i.diaMes === null || i.diaMes === undefined ? null : Number(i.diaMes) }))
      : [],
    prefs: { avisar: r.prefs?.avisar === true, limiteMin: Number(r.prefs?.limiteMin) || 60 },
    hoy: Array.isArray(r.hoy)
      ? r.hoy.map((t) => ({ itemId: String(t.itemId), nombre: String(t.nombre ?? ""), hhmm: String(t.hhmm ?? ""), dosisId: typeof t.dosisId === "string" ? t.dosisId : null, estado: String(t.estado ?? "") }))
      : [],
    destinatarios: Array.isArray(r.destinatarios) ? r.destinatarios.map((x) => String(x)) : [],
    max: { items: Number(r.max?.items) || 8, horas: Number(r.max?.horas) || 6 },
  };
}

/** Crear (sin id) o cambiar (con id) uno de MIS remedios. */
export async function saveRemedio(enrollment: NativeEnrollment, remedio: { id?: string; nombre: string; horas: string[]; dias: number[]; diaMes?: number | null; activo?: boolean }) {
  await nativeRequest(enrollment, "/api/native/care/med/item", {
    method: "POST",
    body: JSON.stringify({ deviceId: enrollment.deviceId, tzOffsetMin: -new Date().getTimezoneOffset(), ...remedio }),
  });
}

export async function deleteRemedio(enrollment: NativeEnrollment, id: string) {
  await nativeRequest(enrollment, "/api/native/care/med/item/delete", { method: "POST", body: JSON.stringify({ deviceId: enrollment.deviceId, id }) });
}

/** "Avisar a mi familia si no lo confirmo" (apagado por defecto) y en cuanto tiempo. */
export async function setRemediosPrefs(enrollment: NativeEnrollment, cambios: { avisar?: boolean; limiteMin?: number }) {
  await nativeRequest(enrollment, "/api/native/care/med/prefs", { method: "POST", body: JSON.stringify({ deviceId: enrollment.deviceId, ...cambios }) });
}

/** "Lo tome": con el aviso (dosisId o dosisIds, todos los de una hora) o una toma que todavia no tenia aviso (itemId + hora). */
export async function confirmRemedio(enrollment: NativeEnrollment, toma: { dosisId?: string; dosisIds?: string[]; itemId?: string; hhmm?: string }) {
  await nativeRequest(enrollment, "/api/native/care/med/ok", { method: "POST", body: JSON.stringify({ deviceId: enrollment.deviceId, ...toma }) });
}

'),
    @('src\FamiliaPantalla.tsx', 'remedios v2: tarjeta con semana, mes y varios a la misma hora', '// ---------------------------------------------------------------------------
// Remedios: los carga, los prende y los apaga la propia persona (nadie decide por ella). A cada hora le llega un aviso y toca "Lo tomé".
// Opcional (apagado): avisar a quienes reciben su SOS si no lo confirma, sin decir el nombre del remedio (son datos de salud).
// ---------------------------------------------------------------------------
const DIAS_REMEDIO = ["dom", "lun", "mar", "mié", "jue", "vie", "sáb"];
const ORDEN_DIAS_REMEDIO = [1, 2, 3, 4, 5, 6, 0];
type BorradorRemedio = { id: string | null; nombre: string; horas: string[]; dias: number[]; hora: string };

function textoDiasRemedio(dias: number[]): string {
  if (dias.length === 7) return "todos los días";
  return ORDEN_DIAS_REMEDIO.filter((d) => dias.includes(d)).map((d) => DIAS_REMEDIO[d] ?? "").join(", ");
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
    setBorrador({ id: null, nombre: "", horas: [], dias: [0, 1, 2, 3, 4, 5, 6], hora: "08:00" });
  };
  const editar = (it: RemedioItem) => {
    setAviso("");
    setBorrador({ id: it.id, nombre: it.nombre, horas: it.horas, dias: it.dias, hora: it.horas[0] ?? "08:00" });
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
    const datos = { ...(borrador.id ? { id: borrador.id } : {}), nombre, horas: borrador.horas, dias: borrador.dias };
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
  const alternarDia = (d: number) => {
    if (!borrador) return;
    const dias = borrador.dias.includes(d) ? borrador.dias.filter((x) => x !== d) : [...borrador.dias, d];
    if (!dias.length) return;
    setBorrador({ ...borrador, dias });
  };
  const alternarActivo = (it: RemedioItem) => void correr(`activo-${it.id}`, () => saveRemedio(enrollment, { id: it.id, nombre: it.nombre, horas: it.horas, dias: it.dias, activo: !it.activo }));
  const borrar = (it: RemedioItem) =>
    Alert.alert(`¿Borrar ${it.nombre}?`, "Dejás de recibir su recordatorio.", [
      { text: "Cancelar", style: "cancel" },
      { text: "Borrar", style: "destructive", onPress: () => void correr(`borrar-${it.id}`, () => deleteRemedio(enrollment, it.id)) },
    ]);
  const tome = (t: RemedioToma) => void correr(`ok-${t.itemId}-${t.hhmm}`, () => confirmRemedio(enrollment, t.dosisId ? { dosisId: t.dosisId } : { itemId: t.itemId, hhmm: t.hhmm }));
  const cambiarPrefs = (marca: string, cambios: { avisar?: boolean; limiteMin?: number }) => {
    setRem({ ...actual, prefs: { ...actual.prefs, ...cambios } });
    void correr(marca, () => setRemediosPrefs(enrollment, cambios));
  };
  const hoy = actual.hoy.filter((t) => t.estado !== "sin_aviso");
  const hayActivos = actual.items.some((i) => i.activo);
  const chip = (activa: boolean) => ({ backgroundColor: activa ? P.doradoFondo : P.campo, borderColor: activa ? P.doradoBorde : P.borde, borderRadius: 12, borderWidth: 1, paddingHorizontal: 12, paddingVertical: 8 });
  const chipTexto = (activa: boolean) => ({ color: activa ? P.doradoTexto : P.textoClaro, fontSize: 13.5, fontWeight: "700" as const });
  return (
    <>
      <Text style={{ color: P.textoDebil, fontSize: 12, fontWeight: "800", letterSpacing: 1.1, marginBottom: 8, marginTop: 20 }}>REMEDIOS</Text>
      <View style={{ backgroundColor: P.superficie, borderColor: P.borde, borderRadius: 18, borderWidth: 1, gap: 10, padding: 16 }}>
        <Text maxFontSizeMultiplier={TOPE_LETRA} style={botones.ayuda}>
          Recordatorios opcionales: los cargás y los apagás vos. A la hora te llega un aviso; tocá «Lo tomé» para confirmar.
        </Text>
        {hoy.length ? (
          <>
            <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.separador}>HOY</Text>
            {hoy.map((t) => (
              <View key={`${t.itemId}-${t.hhmm}`} style={sp.fila}>
                <Text maxFontSizeMultiplier={TOPE_LETRA} style={{ color: P.texto, fontSize: 14.5, fontWeight: "800", width: 54 }}>{t.hhmm}</Text>
                <Text maxFontSizeMultiplier={TOPE_LETRA} numberOfLines={1} style={{ color: P.textoClaro, flex: 1, fontSize: 14 }}>{t.nombre}</Text>
                {t.estado === "tomado" ? (
                  <Text maxFontSizeMultiplier={TOPE_LETRA} style={{ color: P.exito, fontSize: 13, fontWeight: "800" }}>✓ Tomado</Text>
                ) : t.estado === "programado" ? (
                  <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.nota}>Más tarde</Text>
                ) : (
                  <Pressable accessibilityRole="button" accessibilityLabel={`Lo tomé: ${t.nombre}`} disabled={ocupado(`ok-${t.itemId}-${t.hhmm}`)} onPress={() => tome(t)} style={chip(true)}>
                    <Text maxFontSizeMultiplier={TOPE_LETRA} style={chipTexto(true)}>Lo tomé</Text>
                  </Pressable>
                )}
              </View>
            ))}
          </>
        ) : null}
        {actual.items.length ? <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.separador}>MIS REMEDIOS</Text> : null}
        {actual.items.map((it) => (
          <View key={it.id} style={{ borderColor: P.borde, borderRadius: 12, borderWidth: 1, gap: 6, padding: 10 }}>
            <View style={sp.fila}>
              <View style={{ flex: 1, minWidth: 0 }}>
                <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.titulo}>{it.nombre}</Text>
                <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.detalle}>{`${it.horas.join(" · ")} · ${textoDiasRemedio(it.dias)}`}</Text>
              </View>
              <Pressable accessibilityRole="switch" accessibilityState={{ checked: it.activo }} accessibilityLabel={`Recordatorio de ${it.nombre}`} disabled={ocupado(`activo-${it.id}`)} onPress={() => alternarActivo(it)} style={[sp.pastilla, { backgroundColor: it.activo ? P.exitoFondo : P.peligroFondo, borderColor: it.activo ? P.exitoBorde : P.peligroBorde, opacity: ocupado(`activo-${it.id}`) ? 0.55 : 1 }]}>
                <View style={[sp.punto, { backgroundColor: it.activo ? P.exito : (P.peligroFuerte ?? P.peligro) }]} />
                <Text maxFontSizeMultiplier={TOPE_LETRA} style={[sp.pastillaTexto, { color: it.activo ? P.exito : (P.peligroFuerte ?? P.peligro) }]}>{it.activo ? "Sí" : "No"}</Text>
              </Pressable>
            </View>
            <View style={{ flexDirection: "row", gap: 18 }}>
              <Pressable accessibilityRole="button" onPress={() => editar(it)}>
                <Text maxFontSizeMultiplier={TOPE_LETRA} style={{ color: P.textoClaro, fontSize: 13.5, fontWeight: "700", textDecorationLine: "underline" }}>Editar</Text>
              </Pressable>
              <Pressable accessibilityRole="button" onPress={() => borrar(it)}>
                <Text maxFontSizeMultiplier={TOPE_LETRA} style={{ color: P.peligroFuerte ?? P.peligro, fontSize: 13.5, fontWeight: "700", textDecorationLine: "underline" }}>Borrar</Text>
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
              <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.nota}>Elegí la hora y tocá «Agregar esta hora». Podés poner varias.</Text>
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
            <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.separador}>DÍAS</Text>
            <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 6 }}>
              {ORDEN_DIAS_REMEDIO.map((d) => (
                <Pressable key={d} accessibilityRole="button" accessibilityState={{ selected: borrador.dias.includes(d) }} onPress={() => alternarDia(d)} style={chip(borrador.dias.includes(d))}>
                  <Text maxFontSizeMultiplier={TOPE_LETRA} style={chipTexto(borrador.dias.includes(d))}>{DIAS_REMEDIO[d] ?? ""}</Text>
                </Pressable>
              ))}
            </View>
            <Pressable accessibilityRole="button" disabled={ocupado("guardar")} onPress={guardarBorrador} style={botones.primario}>
              <Text style={botones.primarioTexto}>{ocupado("guardar") ? "Guardando…" : "Guardar remedio"}</Text>
            </Pressable>
            <Pressable accessibilityRole="button" onPress={() => { setBorrador(null); setAviso(""); }}>
              <Text maxFontSizeMultiplier={TOPE_LETRA} style={{ color: P.textoClaro, fontSize: 13.5, fontWeight: "700", textDecorationLine: "underline" }}>Cancelar</Text>
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

', '// ---------------------------------------------------------------------------
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

'),
    @('App.tsx', 'remedios v2: tocar el aviso confirma todos los de la hora', '      // Tocar el aviso de un remedio pregunta si lo tomo (solo tocar el aviso NO lo marca: hay que decir que si).
      const preguntarRemedio = (respuesta: { notification: { request: { content: { data?: unknown; body?: string | null } } } } | null | undefined) => {
        const contenido = respuesta?.notification.request.content;
        const datos = contenido?.data as { type?: string; dosisId?: string } | null | undefined;
        if (datos?.type !== "remedio" || typeof datos.dosisId !== "string") return;
        const dosisId = datos.dosisId;
        Alert.alert("Remedio", `${contenido?.body ?? "¿Tomaste tu remedio?"}`, [
          { text: "Todavía no", style: "cancel" },
          {
            text: "Lo tomé",
            onPress: () =>
              void loadNativeEnrollment()
                .then(async (vinculo) => {
                  if (!vinculo) return;
                  const { confirmRemedio } = await import("./src/remoteApi");
                  await confirmRemedio(vinculo, { dosisId });
                })
                .catch(() => Alert.alert("No se pudo avisar", "Abrí Ojo Guard, entrá a Familia y amigos, buscá Remedios y tocá «Lo tomé».")),
          },
        ]);
      };
', '      // Tocar el aviso de un remedio pregunta si lo tomo (solo tocar el aviso NO lo marca: hay que decir que si). Si son varios de la misma hora, los confirma todos juntos.
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
')
)
$descargas = @()

# --- Revisar que todas las anclas esten exactamente una vez, en todos los archivos ---
$archivos = @{}
foreach ($c in $cambios) {
    $ruta = Join-Path $raiz $c[0]
    if (-not (Test-Path $ruta)) { Mal ("No encuentro " + $c[0]); return }
    if (-not $archivos.ContainsKey($c[0])) { $archivos[$c[0]] = Leer $ruta }
}
$ok = $true
foreach ($c in $cambios) {
    $f = $archivos[$c[0]]
    $ancla = Ajustar $c[2] $f.crlf
    $cuantos = Contar $f.texto $ancla
    if ($cuantos -eq 1) { Ok ($c[0] + ": " + $c[1] + ": 1") } else { Mal ($c[0] + ": " + $c[1] + ": " + $cuantos + " (esperaba 1)"); $ok = $false }
}
if (-not $ok) { Mal "Alguna ancla no coincide. No toco nada. Mandame esta pantalla."; return }

# --- Descargar archivos nuevos y verificar que llegaron completos ---
foreach ($d in $descargas) {
    $tmp = (Join-Path $raiz $d[1]) + ".descarga"
    try { Invoke-WebRequest -UseBasicParsing $d[0] -OutFile $tmp } catch { }
    if (-not (Test-Path $tmp) -or (Sha $tmp) -ne $d[2]) {
        foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }
        Mal ("No se pudo descargar bien " + $d[1] + ". No toque nada."); return
    }
    Ok ("Descargado y verificado: " + $d[1])
}

# --- Respaldos ---
$tocados = @($archivos.Keys) + @($descargas | ForEach-Object { $_[1] })
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path ($ruta + ".bak-remedios2")) { Mal ("Ya existe " + $t + ".bak-remedios2. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-remedios2"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-remedios2): " + ($respaldados -join ", "))

# --- Aplicar ---
$esperado = @{}
foreach ($k in $archivos.Keys) { $esperado[$k] = $archivos[$k].texto.Length }
$nuevos = @{}
foreach ($k in $archivos.Keys) { $nuevos[$k] = $archivos[$k].texto }
foreach ($c in $cambios) {
    $f = $archivos[$c[0]]
    $ancla = Ajustar $c[2] $f.crlf; $reemplazo = Ajustar $c[3] $f.crlf
    $nuevos[$c[0]] = $nuevos[$c[0]].Replace($ancla, $reemplazo)
    $esperado[$c[0]] = $esperado[$c[0]] + ($reemplazo.Length - $ancla.Length)
}
foreach ($k in $archivos.Keys) { [System.IO.File]::WriteAllText((Join-Path $raiz $k), $nuevos[$k], (New-Object System.Text.UTF8Encoding($archivos[$k].bom))) }
foreach ($d in $descargas) { Move-Item -LiteralPath ((Join-Path $raiz $d[1]) + ".descarga") -Destination (Join-Path $raiz $d[1]) -Force }

# --- Verificar ---
$todoBien = $true
function Chk([string]$que, [bool]$cond) { if ($cond) { Ok $que } else { Mal $que; $script:todoBien = $false } }
foreach ($c in $cambios) {
    $v = (Leer (Join-Path $raiz $c[0]))
    Chk ($c[0] + ": " + $c[1] + " aplicado") ((Contar $v.texto (Ajustar $c[3] $v.crlf)) -eq 1)
}
foreach ($k in $archivos.Keys) {
    $largo = (Leer (Join-Path $raiz $k)).texto.Length
    Chk ($k + ": largo " + $largo + " (esperado " + $esperado[$k] + ")") ($largo -eq $esperado[$k])
}
foreach ($d in $descargas) { Chk ($d[1] + ": verificado") ((Sha (Join-Path $raiz $d[1])) -eq $d[2]) }

if (-not $todoBien) {
    Mal "Algo no salio bien. Restauro todo desde los respaldos."
    foreach ($t in $tocados) {
        $ruta = Join-Path $raiz $t
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-remedios2") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "Archivos listos. Reviso que la app compile (puede tardar un minuto)..."
& npx.cmd tsc --noEmit
if ($LASTEXITCODE -ne 0) {
    Mal "La revision de tipos encontro errores (arriba). Dejo todo como estaba."
    foreach ($t in $tocados) { $ruta = Join-Path $raiz $t; if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-remedios2") -Destination $ruta -Force } }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "LISTO: la app compila bien. Sale en la PROXIMA build."
Write-Host ""
