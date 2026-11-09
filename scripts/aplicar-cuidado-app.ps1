# aplicar-cuidado-app.ps1 - App (PROXIMA build): tarjeta CUIDADO en Familia y amigos (bateria baja / sin senal y "Buen dia"), opcionales.
# Luciano (09/11/2026): ecosistema de familia y cuidado de mayores; "el mayor sigue siendo adulto": todo lo prende y lo apaga la propia persona. Los avisos van a quienes reciben su SOS.
# Tocar el aviso del "Buen dia" cuenta como contestar. Requiere aplicar-permisos-ojo4-app.ps1 y el servidor aplicar-cuidado-panel.ps1 (sin eso la tarjeta no se muestra). Toca src\remoteApi.ts, src\FamiliaPantalla.tsx y App.tsx (respaldo .bak-cuidado).
# Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba.
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
if ((Contar (Leer (Join-Path $raiz "src\FamiliaPantalla.tsx")).texto 'const noAplica') -eq 0) { Mal "Falta aplicar primero aplicar-permisos-ojo4-app.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\FamiliaPantalla.tsx")).texto 'function TarjetaCuidado') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
$cambios = @(
    @('src\remoteApi.ts', 'cuidado: llamadas al servidor', '/** Salir de la familia de un titular (personId "titular:correo", como viene en fetchFamily). */
', '/** Cuidado (opcional, lo prende la propia persona): aviso de bateria baja / sin senal y "Buen dia". */
export type CuidadoEstado = {
  prefs: { bateria: boolean; buenDia: boolean; hora: string; limiteMin: number };
  hoy: { enviado: boolean; contesto: boolean; alertado: boolean };
  destinatarios: string[];
};
export type CambiosCuidado = { bateria?: boolean; buenDia?: boolean; hora?: string; limiteMin?: number };

export async function fetchCare(enrollment: NativeEnrollment): Promise<CuidadoEstado> {
  const query = new URLSearchParams({ deviceId: enrollment.deviceId });
  const response = await nativeRequest(enrollment, `/api/native/care?${query.toString()}`);
  const r = (await response.json()) as Partial<CuidadoEstado>;
  return {
    prefs: {
      bateria: r.prefs?.bateria !== false,
      buenDia: r.prefs?.buenDia === true,
      hora: typeof r.prefs?.hora === "string" ? r.prefs.hora : "09:00",
      limiteMin: Number(r.prefs?.limiteMin) || 60,
    },
    hoy: { enviado: r.hoy?.enviado === true, contesto: r.hoy?.contesto === true, alertado: r.hoy?.alertado === true },
    destinatarios: Array.isArray(r.destinatarios) ? r.destinatarios.map((x) => String(x)) : [],
  };
}

export async function setCarePrefs(enrollment: NativeEnrollment, cambios: CambiosCuidado) {
  await nativeRequest(enrollment, "/api/native/care/prefs", {
    method: "POST",
    body: JSON.stringify({ deviceId: enrollment.deviceId, tzOffsetMin: -new Date().getTimezoneOffset(), ...cambios }),
  });
}

/** Contestar "estoy bien" al Buen dia (day = el dia que trae el aviso, para que el de ayer no cuente hoy). */
export async function answerBuenDia(enrollment: NativeEnrollment, day?: string) {
  await nativeRequest(enrollment, "/api/native/care/buen-dia/ok", {
    method: "POST",
    body: JSON.stringify({ deviceId: enrollment.deviceId, ...(day ? { day } : {}) }),
  });
}

/** Salir de la familia de un titular (personId "titular:correo", como viene en fetchFamily). */
'),
    @('src\FamiliaPantalla.tsx', 'cuidado: importar las llamadas', 'import { fetchFamily, joinFamily, leaveFamily, pauseFamilyLocation, setFamilyPermission, type FamilyPerson } from "./remoteApi";', 'import { answerBuenDia, fetchCare, fetchFamily, joinFamily, leaveFamily, pauseFamilyLocation, setCarePrefs, setFamilyPermission, type CambiosCuidado, type CuidadoEstado, type FamilyPerson } from "./remoteApi";'),
    @('src\FamiliaPantalla.tsx', 'cuidado: componentes de la tarjeta', '/** A quien le suena el SOS de esta persona', '// ---------------------------------------------------------------------------
// Cuidado: servicios OPCIONALES que prende y apaga la propia persona (nadie decide por ella). Los avisos van a quienes reciben SU SOS.
// ---------------------------------------------------------------------------
const HORAS_BUEN_DIA = ["07:00", "08:00", "09:00", "10:00", "11:00"];
const PLAZOS_BUEN_DIA: { min: number; texto: string }[] = [{ min: 30, texto: "30 min" }, { min: 60, texto: "1 h" }, { min: 90, texto: "1 h 30" }, { min: 120, texto: "2 h" }];

function FilaCuidado({ P, titulo, detalle, on, guardando, onPress }: { P: Paleta; titulo: string; detalle: string; on: boolean; guardando: boolean; onPress: () => void }) {
  const sp = estilosPermisos(P);
  const tono = on ? P.exito : (P.peligroFuerte ?? P.peligro);
  return (
    <Pressable accessibilityRole="switch" accessibilityState={{ checked: on }} disabled={guardando} onPress={onPress} style={sp.fila}>
      <View style={{ flex: 1, minWidth: 0 }}>
        <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.titulo}>{titulo}</Text>
        <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.detalle}>{detalle}</Text>
      </View>
      <View style={[sp.pastilla, { backgroundColor: on ? P.exitoFondo : P.peligroFondo, borderColor: on ? P.exitoBorde : P.peligroBorde, opacity: guardando ? 0.55 : 1 }]}>
        <View style={[sp.punto, { backgroundColor: tono }]} />
        <Text maxFontSizeMultiplier={TOPE_LETRA} style={[sp.pastillaTexto, { color: tono }]}>{on ? "Sí" : "No"}</Text>
      </View>
    </Pressable>
  );
}

function OpcionesCuidado({ P, titulo, opciones, elegida, onElegir }: { P: Paleta; titulo: string; opciones: { valor: string; texto: string }[]; elegida: string; onElegir: (valor: string) => void }) {
  const sp = estilosPermisos(P);
  return (
    <View style={{ gap: 6 }}>
      <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.separador}>{titulo}</Text>
      <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 6 }}>
        {opciones.map((o) => {
          const activa = o.valor === elegida;
          return (
            <Pressable key={o.valor} accessibilityRole="button" accessibilityState={{ selected: activa }} onPress={() => onElegir(o.valor)} style={{ backgroundColor: activa ? P.doradoFondo : P.campo, borderColor: activa ? P.doradoBorde : P.borde, borderRadius: 10, borderWidth: 1, paddingHorizontal: 12, paddingVertical: 8 }}>
              <Text maxFontSizeMultiplier={TOPE_LETRA} style={{ color: activa ? P.doradoTexto : P.textoClaro, fontSize: 13.5, fontWeight: "700" }}>{o.texto}</Text>
            </Pressable>
          );
        })}
      </View>
    </View>
  );
}

function TarjetaCuidado({ P, enrollment, botones }: { P: Paleta; enrollment: NativeEnrollment; botones: { primario: StyleProp<ViewStyle>; primarioTexto: StyleProp<TextStyle>; ayuda: StyleProp<TextStyle> } }) {
  const sp = estilosPermisos(P);
  const [cuidado, setCuidado] = useState<CuidadoEstado | null>(null);
  const [guardando, setGuardando] = useState<string[]>([]);
  const [aviso, setAviso] = useState("");
  const cargar = useCallback(async () => {
    try {
      setCuidado(await fetchCare(enrollment));
    } catch {
      // Sin conexion o con un servidor viejo: la tarjeta simplemente no se muestra.
    }
  }, [enrollment]);
  useEffect(() => {
    void cargar();
  }, [cargar]);
  if (!cuidado) return null;
  const actual = cuidado;
  // El cambio se ve al instante; si el servidor lo rechaza, vuelve atras y dice por que.
  const cambiar = async (marca: string, cambios: CambiosCuidado, aplicar: (c: CuidadoEstado) => CuidadoEstado) => {
    if (guardando.includes(marca)) return;
    setAviso("");
    setGuardando((g) => [...g, marca]);
    setCuidado(aplicar(actual));
    try {
      await setCarePrefs(enrollment, cambios);
    } catch (error) {
      setCuidado(actual);
      const codigo = error instanceof Error ? error.message : "";
      setAviso(codigo === "no_recipients" ? "Todavía no hay nadie que reciba tu SOS. Sumá a alguien antes de prender el Buen día." : "No se pudo guardar. Probá de nuevo.");
    } finally {
      setGuardando((g) => g.filter((x) => x !== marca));
    }
  };
  const contestar = async () => {
    setGuardando((g) => [...g, "ok"]);
    setCuidado({ ...actual, hoy: { ...actual.hoy, contesto: true } });
    try {
      await answerBuenDia(enrollment);
    } catch {
      setCuidado(actual);
      setAviso("No se pudo avisar. Probá de nuevo.");
    } finally {
      setGuardando((g) => g.filter((x) => x !== "ok"));
    }
  };
  const { prefs, hoy, destinatarios } = actual;
  const plazo = PLAZOS_BUEN_DIA.find((p) => p.min === prefs.limiteMin)?.texto ?? `${prefs.limiteMin} min`;
  return (
    <>
      <Text style={{ color: P.textoDebil, fontSize: 12, fontWeight: "800", letterSpacing: 1.1, marginBottom: 8, marginTop: 20 }}>CUIDADO</Text>
      <View style={{ backgroundColor: P.superficie, borderColor: P.borde, borderRadius: 18, borderWidth: 1, gap: 10, padding: 16 }}>
        <Text maxFontSizeMultiplier={TOPE_LETRA} style={botones.ayuda}>
          {`Servicios opcionales: los prendés y los apagás vos. ${destinatarios.length ? `Se avisa a: ${listaDeNombres(destinatarios)}.` : "Todavía no hay nadie que reciba tu SOS."}`}
        </Text>
        <FilaCuidado P={P} titulo="Batería baja y sin señal" detalle="Avisa si tu batería baja de 15% o si pasan 3 horas sin señal." on={prefs.bateria} guardando={guardando.includes("bateria")} onPress={() => void cambiar("bateria", { bateria: !prefs.bateria }, (c) => ({ ...c, prefs: { ...c.prefs, bateria: !prefs.bateria } }))} />
        <FilaCuidado P={P} titulo="Buen día" detalle="Un saludo por día. Si no contestás, se avisa." on={prefs.buenDia} guardando={guardando.includes("buenDia")} onPress={() => void cambiar("buenDia", { buenDia: !prefs.buenDia }, (c) => ({ ...c, prefs: { ...c.prefs, buenDia: !prefs.buenDia } }))} />
        {prefs.buenDia ? (
          <>
            <OpcionesCuidado P={P} titulo="HORA DEL SALUDO" opciones={HORAS_BUEN_DIA.map((h) => ({ valor: h, texto: h }))} elegida={prefs.hora} onElegir={(h) => void cambiar("hora", { hora: h }, (c) => ({ ...c, prefs: { ...c.prefs, hora: h } }))} />
            <OpcionesCuidado P={P} titulo="SI NO CONTESTO EN" opciones={PLAZOS_BUEN_DIA.map((p) => ({ valor: String(p.min), texto: p.texto }))} elegida={String(prefs.limiteMin)} onElegir={(v) => void cambiar("limite", { limiteMin: Number(v) }, (c) => ({ ...c, prefs: { ...c.prefs, limiteMin: Number(v) } }))} />
            {hoy.enviado && !hoy.contesto ? (
              <>
                <Text maxFontSizeMultiplier={TOPE_LETRA} style={botones.ayuda}>{`Hoy te saludamos y todavía no contestaste. Si no contestás en ${plazo}, se avisa.`}</Text>
                <Pressable accessibilityRole="button" disabled={guardando.includes("ok")} onPress={() => void contestar()} style={botones.primario}>
                  <Text style={botones.primarioTexto}>Estoy bien</Text>
                </Pressable>
              </>
            ) : (
              <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.nota}>{hoy.contesto ? "Hoy ya contestaste. ¡Buen día!" : `El próximo saludo es a las ${prefs.hora}.`}</Text>
            )}
          </>
        ) : null}
        {aviso ? <View style={sp.cartel}><Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.cartelTexto}>{aviso}</Text></View> : null}
      </View>
    </>
  );
}

/** A quien le suena el SOS de esta persona'),
    @('src\FamiliaPantalla.tsx', 'cuidado: tarjeta en la pantalla', '      {hayFamilia ? (
        <>
          <Text style={s.etiqueta}>SOS Y AYUDA</Text>
', '      {enrollment ? <TarjetaCuidado P={P} enrollment={enrollment} botones={botones} /> : null}

      {hayFamilia ? (
        <>
          <Text style={s.etiqueta}>SOS Y AYUDA</Text>
'),
    @('App.tsx', 'cuidado: tocar el aviso del Buen dia lo contesta', '      suscripciones.push(notifications.addNotificationResponseReceivedListener(() => stopPhoneAlarmTone()));
', '      // Tocar el aviso del "Buen dia" es contestar que esta bien (el aviso trae el dia: el de ayer no cuenta hoy).
      const contestarBuenDia = (respuesta: { notification: { request: { content: { data?: unknown } } } } | null | undefined) => {
        const datos = respuesta?.notification.request.content.data as { type?: string; day?: string } | null | undefined;
        if (datos?.type !== "buen-dia") return;
        void loadNativeEnrollment()
          .then(async (vinculo) => {
            if (!vinculo) return;
            const { answerBuenDia } = await import("./src/remoteApi");
            await answerBuenDia(vinculo, datos.day);
          })
          .catch(() => undefined);
      };
      suscripciones.push(
        notifications.addNotificationResponseReceivedListener((respuesta) => {
          stopPhoneAlarmTone();
          contestarBuenDia(respuesta);
        }),
      );
      void notifications.getLastNotificationResponseAsync().then((respuesta) => contestarBuenDia(respuesta)).catch(() => undefined);
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
    if (Test-Path ($ruta + ".bak-cuidado")) { Mal ("Ya existe " + $t + ".bak-cuidado. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-cuidado"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-cuidado): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-cuidado") -Destination $ruta -Force }
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
    foreach ($t in $tocados) { $ruta = Join-Path $raiz $t; if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-cuidado") -Destination $ruta -Force } }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "LISTO: la app compila bien. Sale en la PROXIMA build."
Write-Host ""
