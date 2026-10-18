# aplicar-por-las-dudas-cron-panel.ps1 - Por las dudas, segunda parte: aviso AUTOMATICO a los referentes. Estado: NUCLEO - EN VALIDACION.
# Luciano (18/10/2026): "no le tendria que haber llegado un mail que diga que se cumplieron dos de las cuatro?". Con el cron de cada 15 minutos:
#  1. Si se cumplen las condiciones, se le pregunta a la persona "Estas bien?" (mail con boton y aviso en el telefono).
#  2. Si a los ~15 minutos no respondio, se les avisa por mail a los referentes que aceptaron, con su enlace para ver la ultima senal.
#     Se repite cada ~30 minutos, hasta 4 veces. A la persona le llega "Les avisamos a tus referentes" con su boton "Estoy bien".
#  3. Si responde "Estoy bien", se les cuenta a los referentes y no se avisa mas hasta que el telefono vuelva a dar senal.
#  4. Si el telefono vuelve a dar senal, se les avisa a los referentes ("volvio a dar senal") y se cierra.
#  5. "Apagado en movimiento con bateria alta" avisa enseguida, sin esperar los 15 minutos.
# Tambien: todos los mails a un referente llevan su enlace (los enlaces se pueden volver a armar), "Reenviar" manda el MISMO enlace (el anterior sigue
# sirviendo), el mail de invitacion trae el enlace escrito debajo del boton, la ultima senal sin calle muestra las coordenadas, "1 hora" en singular
# y el aviso del telefono ya no manda a abrir el correo. Los enlaces que ya se mandaron siguen sirviendo.
# Reemplaza TODO el codigo de Por las dudas dentro de src\index.ts (despues de comprobar con una huella que es el que dejaron los parches anteriores),
# agrega una linea al cron (scheduled) y crea la tabla pld_episodios. Requiere los parches anteriores de Por las dudas.
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Respaldo .bak-pldcron. Al final publica el panel solo.
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

if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
$indice = Join-Path $raiz "src\index.ts"
if (-not (Test-Path $indice)) { Mal "No encuentro src\index.ts en esta carpeta."; return }
$f = Leer $indice
$yaAplicado = ((Contar $f.texto 'async function pldCron(env') -ne 0)
$sqlEpisodios = 'CREATE TABLE IF NOT EXISTS pld_episodios (owner_email TEXT PRIMARY KEY, started_at TEXT NOT NULL, checkin_at TEXT, seen_at TEXT, alerts INTEGER NOT NULL DEFAULT 0, last_alert_at TEXT, state TEXT NOT NULL);'
$marcaIni = Ajustar '// ---------------------------------------------------------------------------
// "Por las dudas" (N\u00daCLEO \u00b7 EN VALIDACI\u00d3N): referentes de emergencia.' $f.crlf
$marcaFin = Ajustar 'async function fetchCorreo(input: string, init: RequestInit) {' $f.crlf
$ganchoViejo = Ajustar 'ctx.waitUntil(retryPendingCommandsCron(env));' $f.crlf
$ganchoNuevo = Ajustar 'ctx.waitUntil(retryPendingCommandsCron(env));
    ctx.waitUntil(pldCron(env).catch((error) => console.error("pld_cron_failed", error)));' $f.crlf
$huellaVieja = "c49fb5ac0f48a8eaada0685d77b65407336e3b86e173fb68340353e0c35f9b1d"
if ($yaAplicado) {
    Avi "El aviso automatico ya estaba en src\index.ts. Solo reviso la tabla y publico de nuevo."
} else {
    if ((Contar $f.texto 'async function pldApiDuenio') -ne 1) { Mal "Falta aplicar antes los parches de Por las dudas (aplicar-por-las-dudas-panel.ps1 y los siguientes)."; return }
    if ((Contar $f.texto $marcaIni) -ne 1) { Mal "No encuentro el principio del codigo de Por las dudas (esperaba 1). No toco nada. Mandame esta pantalla."; return }
    if ((Contar $f.texto $marcaFin) -ne 1) { Mal "No encuentro el final del codigo de Por las dudas (esperaba 1). No toco nada. Mandame esta pantalla."; return }
    if ((Contar $f.texto $ganchoViejo) -ne 1) { Mal "No encuentro la parte del cron (scheduled) donde enganchar el aviso (esperaba 1). No toco nada. Mandame esta pantalla."; return }
    $a = $f.texto.IndexOf($marcaIni, [System.StringComparison]::Ordinal)
    $b = $f.texto.IndexOf($marcaFin, $a, [System.StringComparison]::Ordinal)
    if ($b -le $a) { Mal "El codigo de Por las dudas no esta donde esperaba. No toco nada. Mandame esta pantalla."; return }
    $viejo = $f.texto.Substring($a, $b - $a)
    $viejoLF = ($viejo -replace "`r`n", "`n")
    $hasher = [System.Security.Cryptography.SHA256]::Create()
    $huella = ([System.BitConverter]::ToString($hasher.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($viejoLF)))).Replace("-", "").ToLower()
    if ($huella -ne $huellaVieja) { Mal ("El codigo de Por las dudas que hay en src\index.ts no es el que dejaron los parches anteriores (huella " + $huella + "). No toco nada. Mandame esta pantalla."); return }
    Ok ("Codigo de Por las dudas actual reconocido: " + $viejoLF.Length + " caracteres")
    Ok "Hook del cron: 1"
}
Write-Host ""
Ok "Creo la tabla del aviso automatico en la base..."
& npx.cmd wrangler d1 execute ojo-guard-ms --remote --command $sqlEpisodios
if ($LASTEXITCODE -ne 0) { Mal "No se pudo crear la tabla, asi que no cambie nada. Mandame esta pantalla."; return }
Ok "Tabla lista"
if (-not $yaAplicado) {
    if (Test-Path ($indice + ".bak-pldcron")) { Mal "Ya existe src\index.ts.bak-pldcron. No toco nada."; return }
    Copy-Item -LiteralPath $indice -Destination ($indice + ".bak-pldcron")
    Ok "Respaldo creado: src\index.ts.bak-pldcron"
    $nuevoBloque = Ajustar '// ---------------------------------------------------------------------------
// "Por las dudas" (N\u00daCLEO \u00b7 EN VALIDACI\u00d3N): referentes de emergencia.
// La persona elige de antemano a qui\u00e9n avisar; en el d\u00eda a d\u00eda nadie ve nada. Si pasan cosas raras (las condiciones que ella
// misma permiti\u00f3), un referente preocupado puede ver la \u00faltima se\u00f1al del tel\u00e9fono con el bot\u00f3n "No lo encuentro".
// Tablas: pld_config, pld_referentes, pld_log, pld_checkins, pld_episodios (se crean con wrangler d1 execute, ver los aplicar-por-las-dudas-*.ps1).
// Especificaci\u00f3n: scripts/POR-LAS-DUDAS-ESPECIFICACION.md. Primera parte: referentes, "No lo encuentro" y \u00faltima se\u00f1al.
// Segunda parte (pldCron, enganchado en scheduled): si se cumplen las condiciones, se le pregunta a la persona si est\u00e1 bien y, si a los
// ~15 minutos no respondi\u00f3, se les avisa a sus referentes (con su enlace); se repite cada ~30 minutos, hasta 4 veces; avisa si el tel\u00e9fono vuelve.
// ---------------------------------------------------------------------------
const PLD_MAX_REFERENTES = 5;
const PLD_ESPERA_MIN = 14;        // minutos entre el "\u00bfEst\u00e1s bien?" y el aviso a los referentes (el cron corre cada 15)
const PLD_ENTRE_AVISOS_MIN = 29;  // minutos entre un aviso a los referentes y el siguiente
const PLD_MAX_AVISOS = 4;         // avisos a los referentes por episodio

type PldConfig = {
  enabled: boolean;
  displayName: string;
  nightFrom: number;
  nightTo: number;
  silenceNightMin: number;
  silenceDayMin: number;
  farKm: number;
  batteryPct: number;
  minSignals: number;
  emergencyHours: number;
  homeLat: number | null;
  homeLng: number | null;
  pausedUntil: string | null;
};

const PLD_POR_DEFECTO: PldConfig = {
  enabled: true,
  displayName: "",
  nightFrom: 21,
  nightTo: 6,
  silenceNightMin: 90,
  silenceDayMin: 360,
  farKm: 3,
  batteryPct: 15,
  minSignals: 3,
  emergencyHours: 3,
  homeLat: null,
  homeLng: null,
  pausedUntil: null,
};

/** Una hora ISO a `minutos` minutos de ahora (negativo: en el pasado). */
function pldEnMinutos(minutos: number) {
  return new Date(Date.now() + minutos * 60_000).toISOString();
}

function pldNumero(valor: unknown, minimo: number, maximo: number, defecto: number) {
  const n = Number(valor);
  return Number.isFinite(n) ? Math.min(maximo, Math.max(minimo, n)) : defecto;
}

function pldSecreto() {
  const bytes = new Uint8Array(18);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (x) => x.toString(16).padStart(2, "0")).join("");
}

/**
 * Los enlaces personales (del referente y del "Estoy bien") llevan una firma que el servidor puede volver a armar cuando lo necesita
 * (HMAC con la clave del servidor sobre el tipo, el id y la huella guardada). As\u00ed cualquier mail al referente puede llevar su enlace y
 * reenviarlo no deja sin efecto el anterior. Los enlaces viejos (el secreto al azar de la primera versi\u00f3n) siguen sirviendo.
 */
async function pldFirma(env: Env, tipo: string, id: string, huella: string) {
  const enc = new TextEncoder();
  const clave = await crypto.subtle.importKey("raw", enc.encode(`pld:${String(env.SESSION_SECRET ?? "")}`), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const firma = new Uint8Array(await crypto.subtle.sign("HMAC", clave, enc.encode(`${tipo}:${id}:${huella}`)));
  return Array.from(firma.slice(0, 18), (x) => x.toString(16).padStart(2, "0")).join("");
}

function pldIgual(a: string, b: string) {
  if (a.length !== b.length) return false;
  let d = 0;
  for (let i = 0; i < a.length; i++) d |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return d === 0;
}

function pldOrigen(env: Env) {
  const e = env as unknown as Record<string, string | undefined>;
  return String(e.PASSKEY_ORIGIN || e.PANEL_URL || "https://ojo-guard-ms-api.bickluciano.workers.dev").replace(/\/+$/, "");
}

/** "18/10, 10:45" en hora de Buenos Aires. */
function pldFechaHora(iso: string | null) {
  if (!iso) return "hace un rato";
  try {
    return new Intl.DateTimeFormat("es-AR", { timeZone: "America/Argentina/Buenos_Aires", day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit", hourCycle: "h23" }).format(new Date(iso));
  } catch {
    return iso;
  }
}

/** C\u00f3mo se llama la persona para sus referentes: el nombre que ella puso o, si no, lo que va antes de la @ de su correo. */
function pldNombreDe(email: string, cfg: PldConfig) {
  if (cfg.displayName.trim()) return cfg.displayName.trim();
  const base = String(email).split("@")[0].replace(/[._-]+/g, " ").trim();
  return base ? base.charAt(0).toUpperCase() + base.slice(1) : "Tu contacto";
}

async function pldLeerConfig(env: Env, email: string): Promise<PldConfig> {
  const f = await env.DB.prepare(
    "SELECT enabled,display_name AS displayName,night_from AS nightFrom,night_to AS nightTo,silence_night_min AS silenceNightMin,silence_day_min AS silenceDayMin,far_km AS farKm,battery_pct AS batteryPct,min_signals AS minSignals,emergency_hours AS emergencyHours,home_lat AS homeLat,home_lng AS homeLng,paused_until AS pausedUntil FROM pld_config WHERE owner_email=?",
  ).bind(email).first<Record<string, unknown>>();
  if (!f) return { ...PLD_POR_DEFECTO };
  return {
    enabled: Number(f.enabled) !== 0,
    displayName: String(f.displayName ?? ""),
    nightFrom: pldNumero(f.nightFrom, 0, 23, PLD_POR_DEFECTO.nightFrom),
    nightTo: pldNumero(f.nightTo, 0, 23, PLD_POR_DEFECTO.nightTo),
    silenceNightMin: pldNumero(f.silenceNightMin, 10, 1440, PLD_POR_DEFECTO.silenceNightMin),
    silenceDayMin: pldNumero(f.silenceDayMin, 10, 2880, PLD_POR_DEFECTO.silenceDayMin),
    farKm: pldNumero(f.farKm, 0.5, 200, PLD_POR_DEFECTO.farKm),
    batteryPct: pldNumero(f.batteryPct, 1, 50, PLD_POR_DEFECTO.batteryPct),
    minSignals: pldNumero(f.minSignals, 1, 4, PLD_POR_DEFECTO.minSignals),
    emergencyHours: pldNumero(f.emergencyHours, 1, 48, PLD_POR_DEFECTO.emergencyHours),
    homeLat: f.homeLat === null || f.homeLat === undefined ? null : Number(f.homeLat),
    homeLng: f.homeLng === null || f.homeLng === undefined ? null : Number(f.homeLng),
    pausedUntil: f.pausedUntil ? String(f.pausedUntil) : null,
  };
}

async function pldGuardarConfig(env: Env, email: string, cfg: PldConfig) {
  await env.DB.prepare(
    "INSERT INTO pld_config (owner_email,enabled,display_name,night_from,night_to,silence_night_min,silence_day_min,far_km,battery_pct,min_signals,emergency_hours,home_lat,home_lng,paused_until,updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(owner_email) DO UPDATE SET enabled=excluded.enabled,display_name=excluded.display_name,night_from=excluded.night_from,night_to=excluded.night_to,silence_night_min=excluded.silence_night_min,silence_day_min=excluded.silence_day_min,far_km=excluded.far_km,battery_pct=excluded.battery_pct,min_signals=excluded.min_signals,emergency_hours=excluded.emergency_hours,home_lat=excluded.home_lat,home_lng=excluded.home_lng,paused_until=excluded.paused_until,updated_at=excluded.updated_at",
  ).bind(
    email, cfg.enabled ? 1 : 0, cfg.displayName.slice(0, 60), cfg.nightFrom, cfg.nightTo, cfg.silenceNightMin, cfg.silenceDayMin, cfg.farKm, cfg.batteryPct,
    cfg.minSignals, cfg.emergencyHours, cfg.homeLat, cfg.homeLng, cfg.pausedUntil, now(),
  ).run();
}

function pldDistanciaKm(lat1: number, lng1: number, lat2: number, lng2: number) {
  const rad = (g: number) => (g * Math.PI) / 180;
  const a = Math.sin(rad(lat2 - lat1) / 2) ** 2 + Math.cos(rad(lat1)) * Math.cos(rad(lat2)) * Math.sin(rad(lng2 - lng1) / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/** La hora (0 a 23) en Buenos Aires. */
function pldHoraBA(ms: number) {
  const texto = new Intl.DateTimeFormat("en-GB", { timeZone: "America/Argentina/Buenos_Aires", hour: "2-digit", hourCycle: "h23" }).format(new Date(ms));
  return Number(texto);
}

function pldEsDeNoche(hora: number, desde: number, hasta: number) {
  if (desde === hasta) return false;
  return desde > hasta ? hora >= desde || hora < hasta : hora >= desde && hora < hasta;
}

type PldEstado = {
  hayDatos: boolean;
  mostrar: boolean;
  motivo: string;
  senales: Array<{ clave: string; texto: string; cumple: boolean }>;
  cumplen: number;
  apagadoEnMovimiento: boolean;
  ubicacion: { lat: number; lng: number; address: string | null; en: string | null } | null;
  bateria: number | null;
  minutosSinSenal: number | null;
  ultimaVez: string | null;
  telefono: string;
  plataforma: string;
  pushToken: string | null;
  deviceId: string | null;
};

function pldTiempo(minutos: number) {
  if (minutos >= 120) return `${Math.round(minutos / 60)} horas`;
  if (minutos >= 60) return "1 hora";
  const m = Math.max(1, Math.round(minutos));
  return m === 1 ? "1 minuto" : `${m} minutos`;
}

/** Mira c\u00f3mo est\u00e1 el tel\u00e9fono de la persona y dice si se cumplen las condiciones que ella permiti\u00f3. No cambia nada. */
async function pldEvaluar(env: Env, email: string, cfg: PldConfig, emergencia: boolean): Promise<PldEstado> {
  const vacio: PldEstado = {
    hayDatos: false, mostrar: false, motivo: "", senales: [], cumplen: 0, apagadoEnMovimiento: false, ubicacion: null, bateria: null,
    minutosSinSenal: null, ultimaVez: null, telefono: "su tel\u00e9fono", plataforma: "", pushToken: null, deviceId: null,
  };
  const d = await env.DB.prepare(
    "SELECT id,name,platform,battery,last_seen_at AS lastSeenAt,last_location_json AS locJson,last_location_at AS locAt,push_token AS pushToken FROM devices WHERE owner_email=? AND approval_status=''approved'' ORDER BY CASE WHEN device_role=''primary'' THEN 0 ELSE 1 END, COALESCE(last_location_at,'''') DESC LIMIT 1",
  ).bind(email).first<{ id: string; name: string | null; platform: string | null; battery: number | null; lastSeenAt: string | null; locJson: string | null; locAt: string | null; pushToken: string | null }>();
  if (!d) {
    return { ...vacio, motivo: "Todav\u00eda no hay ninguna se\u00f1al de este tel\u00e9fono." };
  }
  const ahora = Date.now();
  let loc: Record<string, unknown> | null = null;
  try { loc = d.locJson ? JSON.parse(d.locJson) : null; } catch { loc = null; }
  const lat = Number(loc?.latitude), lng = Number(loc?.longitude);
  const hayUbicacion = Number.isFinite(lat) && Number.isFinite(lng) && !(lat === 0 && lng === 0);
  const ultima = d.lastSeenAt ?? d.locAt;
  const minutos = minutesBetween(ultima, ahora);
  const bateria = typeof d.battery === "number" ? d.battery : null;
  const estado: PldEstado = {
    ...vacio,
    hayDatos: hayUbicacion,
    bateria,
    minutosSinSenal: minutos,
    ultimaVez: ultima,
    telefono: d.name || "su tel\u00e9fono",
    plataforma: d.platform ?? "",
    pushToken: d.pushToken,
    deviceId: d.id,
    ubicacion: hayUbicacion ? { lat, lng, address: loc?.address ? String(loc.address) : null, en: d.locAt ?? ultima } : null,
  };
  if (!cfg.enabled) return { ...estado, motivo: "Esta persona tiene \"Por las dudas\" apagado." };
  if (cfg.pausedUntil && cfg.pausedUntil > new Date().toISOString()) return { ...estado, motivo: "Esta persona paus\u00f3 los avisos por unas horas." };
  if (!hayUbicacion) return { ...estado, motivo: "Todav\u00eda no hay ninguna ubicaci\u00f3n de este tel\u00e9fono." };

  const hora = pldHoraBA(ahora);
  const esNoche = pldEsDeNoche(hora, cfg.nightFrom, cfg.nightTo);
  const umbral = esNoche ? cfg.silenceNightMin : cfg.silenceDayMin;
  const silencio = minutos !== null && minutos >= umbral;

  let kmCasa: number | null = null;
  let enLugarSeguro = false;
  if (cfg.homeLat !== null && cfg.homeLng !== null) kmCasa = pldDistanciaKm(lat, lng, cfg.homeLat, cfg.homeLng);
  const lugares = await env.DB.prepare("SELECT latitude,longitude,radius FROM family_places WHERE owner_email=?").bind(email).all<{ latitude: number; longitude: number; radius: number }>().catch(() => ({ results: [] as Array<{ latitude: number; longitude: number; radius: number }> }));
  for (const l of lugares.results ?? []) {
    if (pldDistanciaKm(lat, lng, Number(l.latitude), Number(l.longitude)) * 1000 <= Number(l.radius)) enLugarSeguro = true;
  }
  const lejos = kmCasa !== null && kmCasa > cfg.farKm && !enLugarSeguro;
  const bateriaBaja = bateria !== null && bateria <= cfg.batteryPct;

  // Apagado en movimiento con bater\u00eda alta: dej\u00f3 de dar se\u00f1ales mientras iba en veh\u00edculo y no estaba por quedarse sin bater\u00eda.
  let apagadoEnMovimiento = false;
  const puntos = await env.DB.prepare("SELECT latitude,longitude,captured_at AS at FROM location_history WHERE device_id=? ORDER BY captured_at DESC LIMIT 2").bind(d.id).all<{ latitude: number; longitude: number; at: string }>().catch(() => ({ results: [] as Array<{ latitude: number; longitude: number; at: string }> }));
  if ((puntos.results ?? []).length === 2 && minutos !== null) {
    const [b, a] = puntos.results;
    const horas = (Date.parse(b.at) - Date.parse(a.at)) / 3_600_000;
    if (horas > 0) {
      const kmh = pldDistanciaKm(Number(a.latitude), Number(a.longitude), Number(b.latitude), Number(b.longitude)) / horas;
      apagadoEnMovimiento = kmh >= 15 && minutos >= 10 && bateria !== null && bateria >= 40;
    }
  }

  const senales = [
    { clave: "silencio", texto: minutos === null ? "Sin se\u00f1al" : `Sin se\u00f1al hace ${pldTiempo(minutos)}`, cumple: silencio },
    { clave: "lejos", texto: kmCasa === null ? "Casa sin elegir" : `A ${kmCasa < 10 ? kmCasa.toFixed(1) : Math.round(kmCasa)} km de casa`, cumple: lejos },
    { clave: "bateria", texto: bateria === null ? "Bater\u00eda sin dato" : `Bater\u00eda ${Math.round(bateria)} %`, cumple: bateriaBaja },
    { clave: "noche", texto: esNoche ? "De noche" : "De d\u00eda", cumple: esNoche },
  ];
  const cumplen = senales.filter((s) => s.cumple).length;
  const porEmergencia = emergencia && minutos !== null && minutos >= cfg.emergencyHours * 60;
  const mostrar = cumplen >= cfg.minSignals || apagadoEnMovimiento || porEmergencia;
  let motivo = "";
  if (!mostrar) {
    motivo = minutos !== null && minutos < 20
      ? "Su tel\u00e9fono se est\u00e1 reportando con normalidad."
      : "Todav\u00eda no se cumplen las condiciones que esta persona permiti\u00f3.";
  }
  return { ...estado, mostrar, motivo, senales, cumplen, apagadoEnMovimiento };
}

async function pldCorreo(env: Env, para: string, asunto: string, cuerpo: string) {
  if (!env.RESEND_API_KEY) return false;
  const html = `<div style="font-family:Arial,sans-serif;max-width:560px;margin:auto;background:#0c0d0f;color:#f6f6f2;padding:28px;border-radius:20px">${cuerpo}<p style="color:#8f8d85;font-size:12px;margin:26px 0 0">ojo guard &middot; por las dudas</p></div>`;
  try {
    const respuesta = await fetchCorreo("https://api.resend.com/emails", {
      method: "POST",
      headers: { authorization: `Bearer ${env.RESEND_API_KEY}`, "content-type": "application/json" },
      body: JSON.stringify({ from: env.MAIL_FROM, reply_to: env.SUPPORT_EMAIL, to: [para], subject: asunto, html }),
    });
    if (!respuesta.ok) console.error("pld_mail_failed", respuesta.status, await respuesta.text());
    return respuesta.ok;
  } catch (error) {
    console.error("pld_mail_error", error);
    return false;
  }
}

function pldBoton(href: string, texto: string) {
  return `<p style="margin:22px 0"><a style="display:inline-block;background:#d9b24c;color:#111;font-weight:700;padding:13px 22px;border-radius:12px;text-decoration:none" href="${href}">${texto}</a></p>`;
}

async function pldRegistrar(env: Env, email: string, referenteId: string | null, tipo: string, detalle: string) {
  await env.DB.prepare("INSERT INTO pld_log (id,owner_email,referente_id,kind,detail,created_at) VALUES (?,?,?,?,?,?)")
    .bind(`log${pldSecreto().slice(0, 14)}`, email, referenteId, tipo, detalle.slice(0, 300), now()).run();
}

type PldReferente = { id: string; ownerEmail: string; name: string; email: string; tokenHash: string; status: string; mutedUntil: string | null };

async function pldReferentePorToken(env: Env, token: unknown): Promise<PldReferente | null> {
  const [id, secreto] = String(token ?? "").split(".");
  if (!id || !secreto || id.length > 40 || secreto.length > 80) return null;
  const f = await env.DB.prepare("SELECT id,owner_email AS ownerEmail,name,email,token_hash AS tokenHash,status,muted_until AS mutedUntil FROM pld_referentes WHERE id=?").bind(id).first<PldReferente>();
  if (!f || f.status === "baja") return null;
  const valido = pldIgual(secreto, await pldFirma(env, "ref", f.id, f.tokenHash)) || pldIgual(f.tokenHash, await hash(secreto));
  return valido ? f : null;
}

/** El enlace personal de un referente, armado con lo que hay guardado (no hace falta guardar el secreto). */
async function pldEnlaceReferente(env: Env, origen: string, referente: { id: string; tokenHash: string }) {
  return `${origen}/referente?t=${referente.id}.${await pldFirma(env, "ref", referente.id, referente.tokenHash)}`;
}

/** El enlace escrito (por si el bot\u00f3n del mail no se ve o se quiere copiar). */
function pldEnlaceEscrito(enlace: string) {
  return `<p style="color:#8f8d85;font-size:12px;line-height:1.5;word-break:break-all;margin:0 0 14px">Si el bot\u00f3n no funciona, copi\u00e1 y peg\u00e1 este enlace en el navegador:<br><span style="color:#d2d2ce">${escapeHtml(enlace)}</span></p>`;
}

async function pldInvitar(env: Env, origen: string, duenio: string, cfg: PldConfig, referente: { id: string; name: string; email: string; tokenHash: string }) {
  const quien = pldNombreDe(duenio, cfg);
  const enlace = await pldEnlaceReferente(env, origen, referente);
  const enviado = await pldCorreo(
    env, referente.email, `${quien} te eligi\u00f3 como referente en Ojo Guard`,
    `<p style="font-size:20px;font-weight:700;margin:0 0 14px">Hola ${escapeHtml(referente.name)},</p>`
    + `<p style="color:#d2d2ce;line-height:1.55"><strong style="color:#fff">${escapeHtml(quien)}</strong> te eligi\u00f3 como <strong style="color:#fff">referente</strong>: una persona de confianza a la que recurrir <em>por las dudas</em>, si no logra comunicarse con ${escapeHtml(quien)} y algo parece raro.</p>`
    + `<p style="color:#d2d2ce;line-height:1.55">No ves la ubicaci\u00f3n de ${escapeHtml(quien)} en el d\u00eda a d\u00eda. Solo si pasan cosas raras (por ejemplo, el tel\u00e9fono deja de dar se\u00f1ales de noche y lejos de casa), vas a poder ver su <strong style="color:#fff">\u00faltima se\u00f1al</strong>. Si eso pasa, te avisamos por mail.</p>`
    + pldBoton(enlace, "Aceptar y guardar mi enlace")
    + pldEnlaceEscrito(enlace)
    + `<p style="color:#8f8d85;font-size:13px;line-height:1.5">Guard\u00e1 este mail: el enlace es personal y es el que vas a usar si alguna vez necesit\u00e1s el bot\u00f3n <strong>No lo encuentro</strong>. Si te llegan dos mails iguales, es el mismo enlace.</p>`,
  );
  return { enviado, enlace };
}

/** Lo que ve el due\u00f1o en su p\u00e1gina: referentes, condiciones, c\u00f3mo est\u00e1 hoy y el registro. */
async function pldPanorama(env: Env, email: string) {
  const cfg = await pldLeerConfig(env, email);
  const referentes = await env.DB.prepare("SELECT id,name,email,status,created_at AS createdAt,accepted_at AS acceptedAt,muted_until AS mutedUntil FROM pld_referentes WHERE owner_email=? AND status<>''baja'' ORDER BY created_at ASC").bind(email).all();
  const registro = await env.DB.prepare("SELECT l.kind,l.detail,l.created_at AS createdAt,r.name AS referente FROM pld_log l LEFT JOIN pld_referentes r ON r.id=l.referente_id WHERE l.owner_email=? ORDER BY l.created_at DESC LIMIT 25").bind(email).all();
  const hoy = await pldEvaluar(env, email, { ...cfg, enabled: true, pausedUntil: null }, false);
  return {
    ok: true,
    email,
    config: cfg,
    referentes: referentes.results ?? [],
    registro: registro.results ?? [],
    hoy: {
      telefono: hoy.telefono,
      hayDatos: hoy.hayDatos,
      senales: hoy.senales,
      cumplen: hoy.cumplen,
      apagadoEnMovimiento: hoy.apagadoEnMovimiento,
      bateria: hoy.bateria,
      ultimaVez: hoy.ultimaVez,
      motivo: hoy.motivo,
    },
  };
}

/** API del due\u00f1o (con sesi\u00f3n): ver y cambiar sus referentes y condiciones. */
async function pldApiDuenio(request: Request, env: Env) {
  const sesion = await readSessionInfo(request, env.SESSION_SECRET);
  if (!sesion) return json({ error: "unauthorized" }, 401);
  if (sesion.method === "emergency") return json({ error: "not_allowed_in_emergency" }, 403);
  const email = sesion.email;
  if (request.method === "GET") return json(await pldPanorama(env, email));
  if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const cuerpo = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const accion = String(cuerpo.accion ?? "");
  const cfg = await pldLeerConfig(env, email);
  const origen = new URL(request.url).origin;
  let extra: Record<string, unknown> = {};

  if (accion === "config") {
    const c = (cuerpo.config ?? {}) as Record<string, unknown>;
    const nuevo: PldConfig = {
      ...cfg,
      enabled: c.enabled === undefined ? cfg.enabled : Boolean(c.enabled),
      displayName: c.displayName === undefined ? cfg.displayName : String(c.displayName).trim().slice(0, 60),
      nightFrom: Math.round(pldNumero(c.nightFrom, 0, 23, cfg.nightFrom)),
      nightTo: Math.round(pldNumero(c.nightTo, 0, 23, cfg.nightTo)),
      silenceNightMin: Math.round(pldNumero(c.silenceNightMin, 10, 1440, cfg.silenceNightMin)),
      silenceDayMin: Math.round(pldNumero(c.silenceDayMin, 10, 2880, cfg.silenceDayMin)),
      farKm: pldNumero(c.farKm, 0.5, 200, cfg.farKm),
      batteryPct: Math.round(pldNumero(c.batteryPct, 1, 50, cfg.batteryPct)),
      minSignals: Math.round(pldNumero(c.minSignals, 1, 4, cfg.minSignals)),
      emergencyHours: Math.round(pldNumero(c.emergencyHours, 1, 48, cfg.emergencyHours)),
    };
    await pldGuardarConfig(env, email, nuevo);
    await pldRegistrar(env, email, null, "config", "La persona cambi\u00f3 sus condiciones.");
  } else if (accion === "agregar") {
    const nombre = String(cuerpo.name ?? "").trim().slice(0, 60);
    const correo = normalizeEmail(String(cuerpo.email ?? ""));
    if (!nombre || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(correo)) return json({ error: "invalid_referente" }, 400);
    if (correo === normalizeEmail(email)) return json({ error: "referente_es_vos" }, 400);
    const vigentes = await env.DB.prepare("SELECT id,email FROM pld_referentes WHERE owner_email=? AND status<>''baja''").bind(email).all<{ id: string; email: string }>();
    if ((vigentes.results ?? []).length >= PLD_MAX_REFERENTES) return json({ error: "demasiados_referentes" }, 409);
    if ((vigentes.results ?? []).some((r) => normalizeEmail(r.email) === correo)) return json({ error: "referente_repetido" }, 409);
    const id = `ref${pldSecreto().slice(0, 14)}`, huella = await hash(pldSecreto());
    await env.DB.prepare("INSERT INTO pld_referentes (id,owner_email,name,email,token_hash,status,created_at) VALUES (?,?,?,?,?,?,?)")
      .bind(id, email, nombre, correo, huella, "pendiente", now()).run();
    const inv = await pldInvitar(env, origen, email, cfg, { id, name: nombre, email: correo, tokenHash: huella });
    extra = { invitacion: { nombre, enlace: inv.enlace, enviado: inv.enviado } };
    await pldRegistrar(env, email, id, "referente", `Se sum\u00f3 a ${nombre} como referente.`);
  } else if (accion === "reenviar") {
    const id = String(cuerpo.id ?? "");
    const r = await env.DB.prepare("SELECT id,name,email,token_hash AS tokenHash FROM pld_referentes WHERE id=? AND owner_email=? AND status<>''baja''").bind(id, email).first<{ id: string; name: string; email: string; tokenHash: string }>();
    if (!r) return json({ error: "not_found" }, 404);
    const inv = await pldInvitar(env, origen, email, cfg, r);
    extra = { invitacion: { nombre: r.name, enlace: inv.enlace, enviado: inv.enviado } };
    await pldRegistrar(env, email, id, "referente", `Se reenvi\u00f3 el enlace a ${r.name}.`);
  } else if (accion === "quitar") {
    const id = String(cuerpo.id ?? "");
    const r = await env.DB.prepare("SELECT name FROM pld_referentes WHERE id=? AND owner_email=? AND status<>''baja''").bind(id, email).first<{ name: string }>();
    if (!r) return json({ error: "not_found" }, 404);
    await env.DB.prepare("UPDATE pld_referentes SET status=''baja'' WHERE id=?").bind(id).run();
    await pldRegistrar(env, email, id, "referente", `Se quit\u00f3 a ${r.name}.`);
  } else if (accion === "casa") {
    let latitud = Number(cuerpo.lat), longitud = Number(cuerpo.lng);
    if (!Number.isFinite(latitud) || !Number.isFinite(longitud)) {
      const estado = await pldEvaluar(env, email, { ...cfg, enabled: true, pausedUntil: null }, false);
      if (!estado.ubicacion) return json({ error: "sin_ubicacion" }, 409);
      latitud = estado.ubicacion.lat;
      longitud = estado.ubicacion.lng;
    }
    await pldGuardarConfig(env, email, { ...cfg, homeLat: latitud, homeLng: longitud });
    await pldRegistrar(env, email, null, "config", "La persona marc\u00f3 d\u00f3nde est\u00e1 su casa.");
  } else if (accion === "pausa") {
    const horas = pldNumero(cuerpo.horas, 0, 72, 0);
    await pldGuardarConfig(env, email, { ...cfg, pausedUntil: horas > 0 ? pldEnMinutos(Math.round(horas * 60)) : null });
    await pldRegistrar(env, email, null, "config", horas > 0 ? `Pausa de ${horas} horas ("esta noche, afuera").` : "Se quit\u00f3 la pausa.");
  } else {
    return json({ error: "accion_desconocida" }, 400);
  }
  return json({ ...(await pldPanorama(env, email)), ...extra });
}

/** Estado que ve el referente al abrir su enlace (sin sesi\u00f3n: el enlace es personal). */
async function pldApiReferenteEstado(request: Request, env: Env) {
  const cuerpo = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const r = await pldReferentePorToken(env, cuerpo.t);
  if (!r) return json({ error: "enlace_invalido" }, 404);
  const cfg = await pldLeerConfig(env, r.ownerEmail);
  return json({ ok: true, quien: pldNombreDe(r.ownerEmail, cfg), referente: r.name, status: r.status, activo: cfg.enabled, emergenciaHoras: cfg.emergencyHours });
}

async function pldApiReferenteAceptar(request: Request, env: Env) {
  const cuerpo = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const r = await pldReferentePorToken(env, cuerpo.t);
  if (!r) return json({ error: "enlace_invalido" }, 404);
  if (r.status !== "aceptado") {
    await env.DB.prepare("UPDATE pld_referentes SET status=''aceptado'',accepted_at=? WHERE id=?").bind(now(), r.id).run();
    await pldRegistrar(env, r.ownerEmail, r.id, "referente", `${r.name} acept\u00f3 ser referente.`);
    await pldCorreo(env, r.ownerEmail, `${r.name} acept\u00f3 ser tu referente`, `<p style="font-size:18px;font-weight:700;margin:0 0 12px">${escapeHtml(r.name)} acept\u00f3 ser tu referente.</p><p style="color:#d2d2ce;line-height:1.55">Solo va a poder ver tu \u00faltima se\u00f1al si se cumplen las condiciones que vos permitiste. Cada consulta te llega por mail y queda en tu registro.</p>`);
  }
  return json({ ok: true, status: "aceptado" });
}

/**
 * "\u00bfEst\u00e1s bien?" a la persona: mail con el bot\u00f3n "Estoy bien" (y el enlace escrito) y aviso en el tel\u00e9fono. `r` es el referente que apret\u00f3
 * "No lo encuentro"; sin `r` lo manda el sistema solo porque se cumplen las condiciones.
 */
async function pldPedirEstasBien(env: Env, origen: string, email: string, estado: PldEstado, r: { id: string; name: string } | null) {
  const id = `chk${pldSecreto().slice(0, 14)}`, huella = await hash(pldSecreto());
  await env.DB.prepare("INSERT INTO pld_checkins (id,owner_email,referente_id,token_hash,created_at) VALUES (?,?,?,?,?)").bind(id, email, r ? r.id : "auto", huella, now()).run();
  const enlace = `${origen}/estoy-bien?t=${id}.${await pldFirma(env, "chk", id, huella)}`;
  const cuanto = estado.minutosSinSenal === null ? "un rato" : pldTiempo(estado.minutosSinSenal);
  const asunto = r ? `${r.name} quiere saber si est\u00e1s bien` : "\u00bfEst\u00e1s bien? Hace rato que no tenemos se\u00f1ales de tu tel\u00e9fono";
  const texto = r
    ? `<strong style="color:#fff">${escapeHtml(r.name)}</strong> no logra comunicarse con vos y apret\u00f3 <em>No lo encuentro</em>. Si est\u00e1s bien, avisale con un toque, o escribile o llamalo.`
    : `Hace <strong style="color:#fff">${escapeHtml(cuanto)}</strong> que no recibimos se\u00f1ales de tu tel\u00e9fono${estado.apagadoEnMovimiento ? ": dej\u00f3 de reportarse mientras estaba en movimiento y con la bater\u00eda alta." : ` y se cumplen ${estado.cumplen} de 4 de las condiciones que permitiste.`} Si est\u00e1s bien, avisanos con un toque. ${estado.apagadoEnMovimiento ? "Como pas\u00f3 yendo en veh\u00edculo, les avisamos enseguida a tus referentes." : "Si en unos 15 minutos no respond\u00e9s, les avisamos a tus referentes."}`;
  await pldCorreo(
    env, email, asunto,
    `<p style="font-size:20px;font-weight:700;margin:0 0 12px">\u00bfEst\u00e1s bien?</p><p style="color:#d2d2ce;line-height:1.55">${texto}</p>${pldBoton(enlace, "Estoy bien")}${pldEnlaceEscrito(enlace)}`,
  );
  if (estado.pushToken) {
    const titulo = r ? `${r.name} quiere saber si est\u00e1s bien` : "\u00bfEst\u00e1s bien?";
    const cuerpo = r
      ? "Avisale que est\u00e1s bien: escribile o llamalo. Tambi\u00e9n pod\u00e9s tocar \u201cEstoy bien\u201d en el mail que te mandamos."
      : "Hace rato que no tenemos se\u00f1ales de tu tel\u00e9fono. Toc\u00e1 \u201cEstoy bien\u201d en el mail que te mandamos; si no, en unos 15 minutos les avisamos a tus referentes.";
    await sendExpoNotice(estado.pushToken, titulo, cuerpo, {}).catch(() => false);
  }
  // En Android se pide adem\u00e1s una ubicaci\u00f3n nueva (en iPhone el aviso silencioso no despierta la app).
  if (estado.deviceId && estado.pushToken && estado.plataforma !== "ios") {
    await queueAutoLocateCommand(env, { id: estado.deviceId, ownerEmail: email, pushToken: estado.pushToken }).catch(() => false);
  }
}

/** El bot\u00f3n "No lo encuentro". */
async function pldApiReferenteBuscar(request: Request, env: Env) {
  const cuerpo = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const r = await pldReferentePorToken(env, cuerpo.t);
  if (!r) return json({ error: "enlace_invalido" }, 404);
  if (r.status !== "aceptado") return json({ error: "falta_aceptar" }, 409);
  const origen = new URL(request.url).origin;
  const email = r.ownerEmail;
  const cfg = await pldLeerConfig(env, email);
  const quien = pldNombreDe(email, cfg);
  const emergencia = Boolean(cuerpo.emergencia);
  const estado = await pldEvaluar(env, email, cfg, emergencia);

  // 1) "\u00bfEst\u00e1s bien?": se le avisa a la persona (mail con bot\u00f3n y aviso en el tel\u00e9fono). Como mucho una vez cada 10 minutos por referente.
  const reciente = await env.DB.prepare("SELECT id FROM pld_checkins WHERE referente_id=? AND created_at>? LIMIT 1").bind(r.id, pldEnMinutos(-10)).first<{ id: string }>();
  if (!reciente && cfg.enabled) await pldPedirEstasBien(env, origen, email, estado, { id: r.id, name: r.name });

  // 2) Si la persona ya dijo que est\u00e1 bien hace poco, no se muestra nada.
  const respondio = await env.DB.prepare("SELECT answered_at AS at FROM pld_checkins WHERE owner_email=? AND answered_at IS NOT NULL AND answered_at>? ORDER BY answered_at DESC LIMIT 1").bind(email, pldEnMinutos(-30)).first<{ at: string }>();
  if (respondio) {
    await pldRegistrar(env, email, r.id, "busqueda", `${r.name} apret\u00f3 "No lo encuentro" y ya hab\u00edas dicho que estabas bien.`);
    return json({ ok: true, mostrar: false, estaBien: true, mensaje: `${quien} respondi\u00f3 que est\u00e1 bien.`, quien });
  }

  // 3) Condiciones: si no se cumplen, solo se le dice c\u00f3mo est\u00e1.
  if (!estado.mostrar) {
    await pldRegistrar(env, email, r.id, "busqueda", `${r.name} apret\u00f3 "No lo encuentro": no se cumpl\u00edan las condiciones, no vio la ubicaci\u00f3n.`);
    return json({
      ok: true, mostrar: false, quien,
      mensaje: `${estado.motivo} Le mandamos un "\u00bfEst\u00e1s bien?" a ${quien}. Si no responde, volv\u00e9 a mirar en 30 minutos.`,
    });
  }

  // 4) Se muestra la \u00faltima se\u00f1al y se le avisa a la persona.
  const u = estado.ubicacion!;
  await pldRegistrar(env, email, r.id, "consulta", `${r.name} vio tu \u00faltima se\u00f1al${emergencia ? " (marc\u00f3 emergencia)" : ""}.`);
  await pldCorreo(
    env, email, `${r.name} consult\u00f3 tu \u00faltima se\u00f1al`,
    `<p style="font-size:18px;font-weight:700;margin:0 0 12px">${escapeHtml(r.name)} consult\u00f3 tu \u00faltima se\u00f1al.</p><p style="color:#d2d2ce;line-height:1.55">Pas\u00f3 porque se cumplieron las condiciones que vos permitiste${emergencia ? " (y marc\u00f3 que era una emergencia)" : ""}. Si est\u00e1s bien, avisale.</p>`,
  );
  return json({
    ok: true, mostrar: true, quien, telefono: estado.telefono,
    ubicacion: { lat: u.lat, lng: u.lng, address: u.address, en: u.en, mapa: `https://www.google.com/maps?q=${u.lat},${u.lng}` },
    bateria: estado.bateria, ultimaVez: estado.ultimaVez, minutosSinSenal: estado.minutosSinSenal,
    senales: estado.senales, apagadoEnMovimiento: estado.apagadoEnMovimiento,
  });
}

/** La persona toca "Estoy bien" en el mail. */
async function pldApiEstoyBien(request: Request, env: Env) {
  const cuerpo = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const [id, secreto] = String(cuerpo.t ?? "").split(".");
  if (!id || !secreto) return json({ error: "enlace_invalido" }, 404);
  const c = await env.DB.prepare("SELECT id,owner_email AS ownerEmail,referente_id AS referenteId,token_hash AS tokenHash,answered_at AS answeredAt FROM pld_checkins WHERE id=?").bind(id).first<{ id: string; ownerEmail: string; referenteId: string; tokenHash: string; answeredAt: string | null }>();
  if (!c || !(pldIgual(secreto, await pldFirma(env, "chk", c.id, c.tokenHash)) || pldIgual(c.tokenHash, await hash(secreto)))) return json({ error: "enlace_invalido" }, 404);
  if (!c.answeredAt) {
    await env.DB.prepare("UPDATE pld_checkins SET answered_at=? WHERE owner_email=? AND answered_at IS NULL").bind(now(), c.ownerEmail).run();
    const cfg = await pldLeerConfig(env, c.ownerEmail);
    const quien = pldNombreDe(c.ownerEmail, cfg);
    await pldRegistrar(env, c.ownerEmail, c.referenteId === "auto" ? null : c.referenteId, "estoy-bien", `La persona respondi\u00f3 "Estoy bien".`);
    // Se les avisa al referente que pregunt\u00f3 y, si ya se hab\u00eda avisado a los referentes, a todos (y el episodio queda en "respondi\u00f3").
    const avisar = new Map<string, { name: string; email: string }>();
    const quienPregunto = c.referenteId === "auto" ? null : await env.DB.prepare("SELECT name,email FROM pld_referentes WHERE id=?").bind(c.referenteId).first<{ name: string; email: string }>();
    if (quienPregunto) avisar.set(quienPregunto.email, quienPregunto);
    const ep = await pldLeerEpisodio(env, c.ownerEmail);
    if (ep) {
      if (ep.alerts > 0) for (const x of await pldReferentesActivos(env, c.ownerEmail)) avisar.set(x.email, x);
      await env.DB.prepare("UPDATE pld_episodios SET state=''respondio'' WHERE owner_email=?").bind(c.ownerEmail).run();
    }
    for (const x of avisar.values()) {
      await pldCorreo(env, x.email, `${quien} dice que est\u00e1 bien`, `<p style="font-size:20px;font-weight:700;margin:0 0 12px">${escapeHtml(quien)} dice que est\u00e1 bien.</p><p style="color:#d2d2ce;line-height:1.55">${ep && ep.alerts > 0 ? "Respondi\u00f3 despu\u00e9s del aviso de que hac\u00eda rato no daba se\u00f1ales. No hace falta hacer nada." : "Respondi\u00f3 al \"\u00bfEst\u00e1s bien?\" que se le mand\u00f3 cuando apretaste <em>No lo encuentro</em>."}</p>`);
    }
  }
  return json({ ok: true });
}

// ---------------------------------------------------------------------------
// Aviso autom\u00e1tico (corre con el cron de cada 15 minutos).
// Un "episodio" empieza cuando se cumplen las condiciones: se le pregunta a la persona si est\u00e1 bien y, si a los ~15 minutos no respondi\u00f3,
// se les avisa a los referentes (con su enlace). Se repite cada ~30 minutos, hasta 4 veces. Si el tel\u00e9fono vuelve a dar se\u00f1al, se les avisa
// y el episodio se cierra. Si la persona responde "Estoy bien", no se avisa m\u00e1s hasta que el tel\u00e9fono vuelva a dar se\u00f1al.
// "Apagado en movimiento con bater\u00eda alta" no espera: avisa en la primera corrida.
// ---------------------------------------------------------------------------
type PldEpisodio = { ownerEmail: string; startedAt: string; checkinAt: string | null; seenAt: string | null; alerts: number; lastAlertAt: string | null; state: string };

async function pldLeerEpisodio(env: Env, email: string) {
  return env.DB.prepare("SELECT owner_email AS ownerEmail,started_at AS startedAt,checkin_at AS checkinAt,seen_at AS seenAt,alerts,last_alert_at AS lastAlertAt,state FROM pld_episodios WHERE owner_email=?")
    .bind(email).first<PldEpisodio>();
}

/** Los referentes que aceptaron y no silenciaron los avisos. */
async function pldReferentesActivos(env: Env, email: string) {
  const lista = await env.DB.prepare("SELECT id,name,email,token_hash AS tokenHash,muted_until AS mutedUntil FROM pld_referentes WHERE owner_email=? AND status=''aceptado'' ORDER BY created_at ASC")
    .bind(email).all<{ id: string; name: string; email: string; tokenHash: string; mutedUntil: string | null }>();
  const ahora = new Date().toISOString();
  return (lista.results ?? []).filter((x) => !x.mutedUntil || x.mutedUntil <= ahora);
}

/** Manda el aviso a los referentes. Devuelve a cu\u00e1ntos les sali\u00f3 el mail. */
async function pldAvisarReferentes(env: Env, origen: string, email: string, quien: string, estado: PldEstado, numero: number) {
  let enviados = 0;
  const cuentan = estado.senales.filter((s) => s.cumple).map((s) => s.texto);
  for (const x of await pldReferentesActivos(env, email)) {
    const enlace = await pldEnlaceReferente(env, origen, x);
    const razones = estado.apagadoEnMovimiento
      ? "Dej\u00f3 de dar se\u00f1ales yendo en veh\u00edculo, con la bater\u00eda alta."
      : `Se cumplen ${estado.cumplen} de 4 de las condiciones que ${escapeHtml(quien)} dej\u00f3 permitidas: ${escapeHtml(cuentan.join(", "))}.`;
    const ok = await pldCorreo(
      env, x.email, `${quien} lleva rato sin dar se\u00f1ales`,
      `<p style="font-size:20px;font-weight:700;margin:0 0 14px">Hola ${escapeHtml(x.name)},</p>`
      + `<p style="color:#d2d2ce;line-height:1.55">Hace un rato no tenemos se\u00f1ales del tel\u00e9fono de <strong style="color:#fff">${escapeHtml(quien)}</strong> (la \u00faltima fue ${escapeHtml(pldFechaHora(estado.ultimaVez))}). ${razones}</p>`
      + `<p style="color:#d2d2ce;line-height:1.55">Puede no ser nada: bater\u00eda agotada o falta de cobertura. Prob\u00e1 comunicarte con ${escapeHtml(quien)} primero. Si no logr\u00e1s hablar con ${escapeHtml(quien)}, mir\u00e1 su \u00faltima se\u00f1al:</p>`
      + pldBoton(enlace, "Ver su \u00faltima se\u00f1al")
      + pldEnlaceEscrito(enlace)
      + `<p style="color:#8f8d85;font-size:13px;line-height:1.5">Si es grave, llam\u00e1 al 911. Si sigue igual, te lo volvemos a avisar (aviso ${numero} de ${PLD_MAX_AVISOS} como m\u00e1ximo).</p>`,
    );
    if (ok) {
      enviados++;
      await pldRegistrar(env, email, x.id, "aviso", `Se le avis\u00f3 a ${x.name} que hace rato no hay se\u00f1ales (aviso ${numero}).`);
    }
  }
  return enviados;
}

async function pldCronPersona(env: Env, email: string) {
  const cfg = await pldLeerConfig(env, email);
  if (!cfg.enabled) return;
  if (cfg.pausedUntil && cfg.pausedUntil > new Date().toISOString()) return;
  const estado = await pldEvaluar(env, email, cfg, false);
  const ep = await pldLeerEpisodio(env, email);
  const ahora = Date.now();
  const quien = pldNombreDe(email, cfg);
  const origen = pldOrigen(env);

  // El tel\u00e9fono dio una se\u00f1al nueva desde que empez\u00f3 el episodio: se cierra (y, si ya se hab\u00eda avisado, se les cuenta a los referentes).
  if (ep && estado.ultimaVez && ep.seenAt && Date.parse(estado.ultimaVez) > Date.parse(ep.seenAt) + 1000) {
    await env.DB.prepare("DELETE FROM pld_episodios WHERE owner_email=?").bind(email).run();
    let avisados = 0;
    if (ep.alerts > 0 && ep.state !== "respondio") {
      for (const x of await pldReferentesActivos(env, email)) {
        const ok = await pldCorreo(
          env, x.email, `${quien} volvi\u00f3 a dar se\u00f1al`,
          `<p style="font-size:20px;font-weight:700;margin:0 0 14px">Hola ${escapeHtml(x.name)},</p><p style="color:#d2d2ce;line-height:1.55">El tel\u00e9fono de <strong style="color:#fff">${escapeHtml(quien)}</strong> volvi\u00f3 a dar se\u00f1al (${escapeHtml(pldFechaHora(estado.ultimaVez))}). No hace falta hacer nada. Si quer\u00e9s, prob\u00e1 comunicarte.</p>`,
        );
        if (ok) avisados++;
      }
    }
    await pldRegistrar(env, email, null, "aviso", avisados > 0 ? "El tel\u00e9fono volvi\u00f3 a dar se\u00f1al: se les avis\u00f3 a tus referentes." : "El tel\u00e9fono volvi\u00f3 a dar se\u00f1al.");
    return;
  }
  if (ep && ep.state === "respondio") return;
  if (!estado.mostrar) return; // si hay un episodio abierto, queda as\u00ed: no se avisa de nuevo hasta que se vuelvan a cumplir las condiciones

  let epi = ep;
  if (!epi) {
    const respondio = await env.DB.prepare("SELECT answered_at AS at FROM pld_checkins WHERE owner_email=? AND answered_at IS NOT NULL AND answered_at>? LIMIT 1").bind(email, pldEnMinutos(-30)).first<{ at: string }>();
    if (respondio) return; // dijo que estaba bien hace poco
    await env.DB.prepare("INSERT OR REPLACE INTO pld_episodios (owner_email,started_at,checkin_at,seen_at,alerts,last_alert_at,state) VALUES (?,?,?,?,0,NULL,''abierto'')").bind(email, now(), now(), estado.ultimaVez).run();
    await pldPedirEstasBien(env, origen, email, estado, null);
    await pldRegistrar(env, email, null, "aviso", `Se cumplen ${estado.cumplen} de 4 condiciones: se te pregunt\u00f3 si est\u00e1s bien.`);
    epi = await pldLeerEpisodio(env, email);
    if (!epi || !estado.apagadoEnMovimiento) return; // normalmente se espera a la pr\u00f3xima corrida
  }

  if (epi.alerts >= PLD_MAX_AVISOS) return;
  const respondida = await env.DB.prepare("SELECT answered_at AS at FROM pld_checkins WHERE owner_email=? AND answered_at IS NOT NULL AND answered_at>=? LIMIT 1").bind(email, epi.startedAt).first<{ at: string }>();
  if (respondida) {
    await env.DB.prepare("UPDATE pld_episodios SET state=''respondio'' WHERE owner_email=?").bind(email).run();
    return;
  }
  const esperaOk = estado.apagadoEnMovimiento || (epi.checkinAt !== null && ahora - Date.parse(epi.checkinAt) >= PLD_ESPERA_MIN * 60_000);
  const espacioOk = epi.alerts === 0 || (epi.lastAlertAt !== null && ahora - Date.parse(epi.lastAlertAt) >= PLD_ENTRE_AVISOS_MIN * 60_000);
  if (!esperaOk || !espacioOk) return;

  const numero = epi.alerts + 1;
  const enviados = await pldAvisarReferentes(env, origen, email, quien, estado, numero);
  if (enviados === 0) return; // no sali\u00f3 ning\u00fan mail: se vuelve a intentar en la pr\u00f3xima corrida
  await env.DB.prepare("UPDATE pld_episodios SET alerts=?,last_alert_at=? WHERE owner_email=?").bind(numero, now(), email).run();
  if (numero === 1) {
    // La persona se entera de a qui\u00e9nes se les avis\u00f3, con su bot\u00f3n "Estoy bien".
    const chk = await env.DB.prepare("SELECT id,token_hash AS tokenHash FROM pld_checkins WHERE owner_email=? AND answered_at IS NULL ORDER BY created_at DESC LIMIT 1").bind(email).first<{ id: string; tokenHash: string }>();
    const nombres = (await pldReferentesActivos(env, email)).map((x) => x.name).join(", ");
    const enlace = chk ? `${origen}/estoy-bien?t=${chk.id}.${await pldFirma(env, "chk", chk.id, chk.tokenHash)}` : "";
    await pldCorreo(
      env, email, "Les avisamos a tus referentes",
      `<p style="font-size:20px;font-weight:700;margin:0 0 12px">Les avisamos a tus referentes</p><p style="color:#d2d2ce;line-height:1.55">Hace rato que no tenemos se\u00f1ales de tu tel\u00e9fono${estado.apagadoEnMovimiento ? ": dej\u00f3 de reportarse mientras estaba en movimiento y con la bater\u00eda alta." : ` y se cumplen ${estado.cumplen} de 4 de las condiciones que permitiste.`} Les avisamos a: <strong style="color:#fff">${escapeHtml(nombres)}</strong>. Si est\u00e1s bien, avisanos con un toque y les contamos.</p>${enlace ? pldBoton(enlace, "Estoy bien") + pldEnlaceEscrito(enlace) : ""}`,
    );
  }
}

async function pldCron(env: Env) {
  const personas = await env.DB.prepare("SELECT DISTINCT owner_email AS email FROM pld_referentes WHERE status=''aceptado''").all<{ email: string }>();
  for (const p of personas.results ?? []) {
    try {
      await pldCronPersona(env, p.email);
    } catch (error) {
      console.error("pld_cron_persona_failed", error);
    }
  }
}

const PLD_ESTILO = `<style>*{box-sizing:border-box}body{margin:0;min-height:100vh;background:#0b0c0e;color:#f3f1ea;font-family:system-ui,-apple-system,Segoe UI,sans-serif;padding:22px 16px 60px}main{max-width:560px;margin:0 auto}img.logo{display:block;height:34px;margin:6px 0 18px}h1{font-size:1.5rem;margin:.2rem 0 .5rem}h2{font-size:1.05rem;margin:0 0 10px}p{color:#d2d2ce;line-height:1.55}small,.suave{color:#a29e92}.etiqueta{display:inline-block;font:700 .68rem/1 ui-monospace,Menlo,monospace;letter-spacing:.08em;color:#ffb400;border:1px solid #4a3f1f;border-radius:6px;padding:5px 8px;margin:0 0 12px}.tarjeta{background:#14151a;border:1px solid #2a2c31;border-radius:18px;padding:16px;margin:14px 0}label{display:block;margin:10px 0 4px;font-size:.88rem;color:#a29e92}input,select{width:100%;background:#0b0c0e;color:#f3f1ea;border:1px solid #2a2c31;border-radius:12px;padding:11px 12px;font:inherit}button,.boton{display:inline-block;background:#d9b24c;color:#111;border:0;border-radius:12px;padding:12px 18px;font:700 1rem system-ui;cursor:pointer;text-decoration:none}button.sec{background:#211d12;color:#f0c75a;border:1px solid #4a3f1f}button.chico{padding:7px 12px;font-size:.85rem}button.grande{width:100%;padding:18px;font-size:1.2rem}button:disabled{opacity:.55;cursor:wait}.fila{display:flex;gap:10px;align-items:center;justify-content:space-between;padding:10px 0;border-top:1px solid #2a2c31}.fila:first-child{border-top:0}.dos{display:grid;grid-template-columns:1fr 1fr;gap:10px}.ok{color:#57d48a}.mal{color:#e0806a}.pill{display:inline-block;border:1px solid #2a2c31;border-radius:999px;padding:4px 10px;margin:3px 4px 0 0;font-size:.82rem}.pill.si{border-color:#4a3f1f;background:#211d12;color:#f0c75a}#aviso{min-height:1.2em;color:#f0c75a;margin:8px 0}</style>`;

function pldPagina(titulo: string, cuerpo: string) {
  const html = `<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex"><title>${titulo}</title>${PLD_ESTILO}</head><body><main><img class="logo" src="/marca/logo-correo.png" alt="ojo guard"><span class="etiqueta">N\u00daCLEO \u00b7 EN VALIDACI\u00d3N</span>${cuerpo}</main></body></html>`;
  return new Response(html, { headers: { "content-type": "text/html; charset=utf-8", "cache-control": "no-store", "referrer-policy": "no-referrer" } });
}

/** P\u00e1gina del due\u00f1o: "Por las dudas". */
function pldPaginaDuenio() {
  return pldPagina("Por las dudas \u00b7 Ojo Guard", `
<h1>por las dudas</h1>
<p>Eleg\u00ed a qui\u00e9n recurrir si alg\u00fan d\u00eda no pod\u00e9s comunicarte y algo parece raro. En el d\u00eda a d\u00eda nadie ve nada: solo se ve tu <b>\u00faltima se\u00f1al</b> si se cumplen las condiciones que vos permit\u00eds ac\u00e1.</p>
<p class="suave">Esta funci\u00f3n est\u00e1 en validaci\u00f3n: ya la probamos de punta a punta con mails reales, pero todav\u00eda no en el d\u00eda a d\u00eda.</p>
<div id="aviso"></div>
<div id="sinSesion" class="tarjeta" style="display:none"><h2>Falta entrar al panel</h2><p>Para ver y cambiar tus referentes ten\u00e9s que entrar al panel de Ojo Guard MS con tu cuenta, <b>en este mismo navegador</b>. Entr\u00e1, y despu\u00e9s volv\u00e9 a esta p\u00e1gina.</p><p><a class="boton" href="/acceso-v7">Entrar al panel</a> <button class="sec" onclick="location.reload()">Ya entr\u00e9, probar de nuevo</button></p></div>
<div id="contenido" style="opacity:.4;pointer-events:none">
<div class="tarjeta"><h2>C\u00f3mo est\u00e1s hoy</h2><div id="hoy" class="suave">Cargando\u2026</div></div>
<div class="tarjeta"><h2>Tus referentes</h2><div id="referentes" class="suave">Cargando\u2026</div>
<label>Nombre</label><input id="rNombre" maxlength="60" placeholder="Mam\u00e1"><label>Correo</label><input id="rCorreo" type="email" placeholder="mama@correo.com">
<p><button id="rAgregar">Elegir referente</button></p><div id="invitacion"></div><small class="suave">Hasta 5. Le llega un mail con su enlace personal y tiene que aceptar.</small>
<p id="dondeBoton" class="suave"><b>\u00bfD\u00f3nde est\u00e1 el bot\u00f3n \u201cNo lo encuentro\u201d?</b> Lo ve solo tu referente, en su enlace personal, despu\u00e9s de aceptar. Vos no ten\u00e9s que apretar nada. Para probarlo, abr\u00ed su enlace en otro navegador (o en una ventana privada) y acept\u00e1.</p></div>
<div class="tarjeta"><h2>Condiciones</h2><small class="suave">Un referente solo ve tu \u00faltima se\u00f1al si se cumplen al menos estas se\u00f1ales a la vez. Cuando se cumplen, te mandamos un \u201c\u00bfEst\u00e1s bien?\u201d (mail y aviso en el tel\u00e9fono) y, si en unos 15 minutos no respond\u00e9s, les avisamos a tus referentes por mail.</small>
<label>C\u00f3mo te llaman tus referentes</label><input id="cNombre" maxlength="60">
<div class="dos"><div><label>De noche desde (hora)</label><input id="cDesde" type="number" min="0" max="23"></div><div><label>hasta (hora)</label><input id="cHasta" type="number" min="0" max="23"></div></div>
<div class="dos"><div><label>Sin se\u00f1al de noche (min)</label><input id="cSilNoche" type="number" min="10"></div><div><label>Sin se\u00f1al de d\u00eda (min)</label><input id="cSilDia" type="number" min="10"></div></div>
<div class="dos"><div><label>Lejos de casa (km)</label><input id="cKm" type="number" min="0.5" step="0.5"></div><div><label>Bater\u00eda baja (%)</label><input id="cBat" type="number" min="1" max="50"></div></div>
<div class="dos"><div><label>Se\u00f1ales necesarias (de 4)</label><select id="cMin"><option>2</option><option>3</option><option>4</option></select></div><div><label>Emergencia tras (horas)</label><input id="cEmer" type="number" min="1" max="48"></div></div>
<label><input id="cActivo" type="checkbox" style="width:auto"> Por las dudas est\u00e1 encendido</label>
<p><button id="cGuardar">Guardar condiciones</button> <button class="sec" id="cCasa">Mi casa es donde est\u00e1 mi tel\u00e9fono ahora</button></p><div id="casa" class="suave"></div></div>
<div class="tarjeta"><h2>Esta noche, afuera</h2><small class="suave">Si dorm\u00eds en otro lado, paus\u00e1 los avisos por unas horas.</small><p><button class="sec" data-h="8">Pausar 8 horas</button> <button class="sec" data-h="0">Quitar pausa</button></p><div id="pausa" class="suave"></div></div>
<div class="tarjeta"><h2>Registro</h2><div id="registro" class="suave">Cargando\u2026</div></div>
</div>
<script>
(function(){
var $=function(i){return document.getElementById(i)};
function aviso(t){$("aviso").textContent=t||""}
function api(cuerpo){return fetch("/api/remote/por-las-dudas",{method:cuerpo?"POST":"GET",headers:{"content-type":"application/json"},body:cuerpo?JSON.stringify(cuerpo):undefined,credentials:"same-origin"}).then(function(r){return r.json().then(function(d){if(r.status===401){var er=new Error("Entr\u00e1 primero al panel de Ojo Guard MS con tu cuenta y volv\u00e9 a abrir esta p\u00e1gina.");er.sinSesion=true;throw er}if(!r.ok){throw new Error(({invalid_referente:"Revis\u00e1 el nombre y el correo.",referente_es_vos:"El referente no puede ser vos.",demasiados_referentes:"Ya ten\u00e9s 5 referentes.",referente_repetido:"Ese correo ya es referente.",sin_ubicacion:"Todav\u00eda no hay una ubicaci\u00f3n de tu tel\u00e9fono."})[d.error]||"No se pudo. Prob\u00e1 de nuevo.")}return d})})}
function fecha(s){if(!s)return"";try{return new Date(s).toLocaleString("es-AR",{timeZone:"America/Argentina/Buenos_Aires",day:"2-digit",month:"2-digit",hour:"2-digit",minute:"2-digit"})}catch(e){return s}}
function limpiar(n){while(n.firstChild)n.removeChild(n.firstChild)}
function texto(n,t){n.appendChild(document.createTextNode(t))}
function pintar(d){
  var h=$("hoy");limpiar(h);
  if(!d.hoy.hayDatos){texto(h,"Todav\u00eda no hay ninguna ubicaci\u00f3n de "+d.hoy.telefono+".")}else{
    texto(h,"Con lo que sabemos de "+d.hoy.telefono+" ahora mismo, se cumplen "+d.hoy.cumplen+" de 4 se\u00f1ales (hacen falta "+d.config.minSignals+").");h.appendChild(document.createElement("br"));
    d.hoy.senales.forEach(function(s){var p=document.createElement("span");p.className="pill"+(s.cumple?" si":"");p.textContent=s.texto;h.appendChild(p)});
    if(d.hoy.apagadoEnMovimiento){h.appendChild(document.createElement("br"));texto(h,"Tambi\u00e9n: dej\u00f3 de dar se\u00f1ales yendo en veh\u00edculo con bater\u00eda alta.")}
  }
  var r=$("referentes");limpiar(r);
  if(!d.referentes.length){texto(r,"Todav\u00eda no elegiste a nadie.")}
  d.referentes.forEach(function(x){
    var f=document.createElement("div");f.className="fila";var iz=document.createElement("div");
    var b=document.createElement("b");b.textContent=x.name;iz.appendChild(b);iz.appendChild(document.createElement("br"));
    var s=document.createElement("small");s.textContent=x.email+" \u00b7 "+(x.status==="aceptado"?"acept\u00f3":"esperando que acepte");s.className=x.status==="aceptado"?"ok":"suave";iz.appendChild(s);f.appendChild(iz);
    var dr=document.createElement("div");
    var ya=x.status==="aceptado";var re=document.createElement("button");re.className="sec chico";re.textContent=ya?"Mandar enlace de nuevo":"Reenviar";re.onclick=function(){accion({accion:"reenviar",id:x.id},ya?"Le mandamos su enlace de nuevo (es el mismo: el que ya tiene sigue sirviendo).":"Enlace reenviado.")};dr.appendChild(re);dr.appendChild(document.createTextNode(" "));
    var qu=document.createElement("button");qu.className="sec chico";qu.textContent="Quitar";qu.onclick=function(){if(confirm("\u00bfQuitar a "+x.name+"?"))accion({accion:"quitar",id:x.id},"Referente quitado.")};dr.appendChild(qu);f.appendChild(dr);r.appendChild(f)});
  var c=d.config;$("cNombre").value=c.displayName||"";$("cDesde").value=c.nightFrom;$("cHasta").value=c.nightTo;$("cSilNoche").value=c.silenceNightMin;$("cSilDia").value=c.silenceDayMin;$("cKm").value=c.farKm;$("cBat").value=c.batteryPct;$("cMin").value=String(c.minSignals);$("cEmer").value=c.emergencyHours;$("cActivo").checked=!!c.enabled;
  $("casa").textContent=c.homeLat===null?"Todav\u00eda no marcaste d\u00f3nde est\u00e1 tu casa: sin eso, la se\u00f1al \u201clejos de casa\u201d no cuenta.":"Casa marcada ("+Number(c.homeLat).toFixed(4)+", "+Number(c.homeLng).toFixed(4)+").";
  $("pausa").textContent=c.pausedUntil&&c.pausedUntil>new Date().toISOString()?"En pausa hasta "+fecha(c.pausedUntil)+".":"Sin pausa.";
  var g=$("registro");limpiar(g);if(!d.registro.length){texto(g,"Todav\u00eda no hay nada.")}
  d.registro.forEach(function(x){var f=document.createElement("div");f.className="fila";var t=document.createElement("span");t.textContent=x.detail;var w=document.createElement("small");w.textContent=fecha(x.createdAt);w.className="suave";f.appendChild(t);f.appendChild(w);g.appendChild(f)});
}
function mostrarInvitacion(i){
  var c=$("invitacion");limpiar(c);if(!i)return;
  var caja=document.createElement("div");caja.className="tarjeta";
  var tx=document.createElement("p");tx.className=i.enviado?"":"mal";
  tx.textContent=i.enviado?("Le mandamos el mail a "+i.nombre+". Si no le llega (que mire Spam), mandale este enlace vos:"):("No pudimos mandar el mail a "+i.nombre+". Mandale este enlace vos:");
  caja.appendChild(tx);
  var inp=document.createElement("input");inp.readOnly=true;inp.value=i.enlace;inp.onclick=function(){inp.select()};caja.appendChild(inp);
  var b1=document.createElement("button");b1.className="sec chico";b1.textContent="Copiar enlace";b1.style.margin="10px 8px 0 0";
  b1.onclick=function(){inp.select();try{navigator.clipboard.writeText(i.enlace).then(function(){b1.textContent="Copiado"},function(){document.execCommand("copy");b1.textContent="Copiado"})}catch(e){document.execCommand("copy");b1.textContent="Copiado"}};
  caja.appendChild(b1);
  var b2=document.createElement("button");b2.className="sec chico";b2.textContent="Mandar por WhatsApp";b2.style.marginTop="10px";
  b2.onclick=function(){window.open("https://wa.me/?text="+encodeURIComponent("Te eleg\u00ed como mi referente en Ojo Guard, por las dudas. Entr\u00e1 a este enlace para aceptar y guardalo: "+i.enlace),"_blank")};
  caja.appendChild(b2);c.appendChild(caja);
}
function accion(cuerpo,ok){aviso("");return api(cuerpo).then(function(d){pintar(d);mostrarInvitacion(d.invitacion);if(d.invitacion&&!d.invitacion.enviado)aviso("No pudimos mandar el mail. Us\u00e1 el enlace de abajo.");else if(ok)aviso(ok)}).catch(function(e){aviso(e.message)})}
$("rAgregar").onclick=function(){var cc=$("rCorreo").value.trim();if(cc&&!confirm("Le vamos a mandar el mail a esta direcci\u00f3n: ["+cc+"]. Fijate letra por letra: si est\u00e1 mal escrito, le llega a otra persona. \u00bfEst\u00e1 bien escrito?"))return;accion({accion:"agregar",name:$("rNombre").value,email:$("rCorreo").value},"Listo: le mandamos el mail a tu referente.").then(function(){$("rNombre").value="";$("rCorreo").value=""})};
$("cGuardar").onclick=function(){accion({accion:"config",config:{displayName:$("cNombre").value,nightFrom:$("cDesde").value,nightTo:$("cHasta").value,silenceNightMin:$("cSilNoche").value,silenceDayMin:$("cSilDia").value,farKm:$("cKm").value,batteryPct:$("cBat").value,minSignals:$("cMin").value,emergencyHours:$("cEmer").value,enabled:$("cActivo").checked}},"Condiciones guardadas.")};
$("cCasa").onclick=function(){accion({accion:"casa"},"Casa marcada.")};
Array.prototype.forEach.call(document.querySelectorAll("button[data-h]"),function(b){b.onclick=function(){accion({accion:"pausa",horas:Number(b.getAttribute("data-h"))},b.getAttribute("data-h")==="0"?"Pausa quitada.":"Pausa puesta por 8 horas.")}});
api().then(function(d){var c=$("contenido");c.style.opacity="";c.style.pointerEvents="";pintar(d)}).catch(function(e){if(e.sinSesion){aviso("");$("sinSesion").style.display="block";$("contenido").style.display="none"}else{aviso(e.message)}});
})();
</script>`);
}

/** P\u00e1gina del referente: aceptar y "No lo encuentro". */
function pldPaginaReferente() {
  return pldPagina("Referente \u00b7 Ojo Guard", `
<h1 id="titulo">\u2026</h1><div id="aviso"></div><div id="cuerpo"></div>
<script>
(function(){
var $=function(i){return document.getElementById(i)};
var t=new URLSearchParams(location.search).get("t")||"";
function post(url,cuerpo){return fetch(url,{method:"POST",headers:{"content-type":"application/json"},body:JSON.stringify(cuerpo)}).then(function(r){return r.json().then(function(d){if(!r.ok)throw new Error(d.error||"error");return d})})}
function limpiar(n){while(n.firstChild)n.removeChild(n.firstChild)}
function p(txt,clase){var e=document.createElement("p");e.textContent=txt;if(clase)e.className=clase;return e}
function fecha(s){if(!s)return"";try{return new Date(s).toLocaleString("es-AR",{timeZone:"America/Argentina/Buenos_Aires",day:"2-digit",month:"2-digit",hour:"2-digit",minute:"2-digit"})}catch(e){return s}}
function pantalla(e){
  var c=$("cuerpo");limpiar(c);$("titulo").textContent="Referente de "+e.quien;
  if(!e.activo){c.appendChild(p(e.quien+" tiene apagada esta funci\u00f3n por ahora."));return}
  if(e.status!=="aceptado"){
    c.appendChild(p(e.quien+" te eligi\u00f3 como referente: una persona de confianza a la que recurrir por las dudas. No ves su ubicaci\u00f3n en el d\u00eda a d\u00eda; solo si pasan cosas raras vas a poder ver su \u00faltima se\u00f1al."));
    var b=document.createElement("button");b.textContent="Aceptar ser referente";b.onclick=function(){b.disabled=true;post("/api/referente/aceptar",{t:t}).then(function(){e.status="aceptado";pantalla(e)}).catch(function(){b.disabled=false;$("aviso").textContent="No se pudo. Prob\u00e1 de nuevo."})};c.appendChild(b);return}
  c.appendChild(p("Si no logr\u00e1s comunicarte con "+e.quien+" y est\u00e1s preocupado, apret\u00e1 el bot\u00f3n. Le mandamos un \u201c\u00bfEst\u00e1s bien?\u201d y, si pasan cosas raras que "+e.quien+" permiti\u00f3, te mostramos su \u00faltima se\u00f1al."));
  var l=document.createElement("label");l.style.display="block";l.style.margin="14px 0";var k=document.createElement("input");k.type="checkbox";k.style.width="auto";l.appendChild(k);l.appendChild(document.createTextNode(" Es una emergencia (pasaron m\u00e1s de "+e.emergenciaHoras+(e.emergenciaHoras===1?" hora":" horas")+" sin noticias)"));c.appendChild(l);
  var b2=document.createElement("button");b2.className="grande";b2.textContent="No lo encuentro";c.appendChild(b2);
  var r=document.createElement("div");c.appendChild(r);
  b2.onclick=function(){b2.disabled=true;$("aviso").textContent="Mirando\u2026";post("/api/referente/buscar",{t:t,emergencia:k.checked}).then(function(d){$("aviso").textContent="";b2.disabled=false;limpiar(r);resultado(r,d)}).catch(function(){b2.disabled=false;$("aviso").textContent="No se pudo. Prob\u00e1 de nuevo."})};
}
function resultado(r,d){
  var t=document.createElement("div");t.className="tarjeta";
  if(!d.mostrar){t.appendChild(p(d.mensaje,d.estaBien?"ok":""));r.appendChild(t);return}
  var h=document.createElement("h2");h.textContent="\u00daltima se\u00f1al de "+d.quien;t.appendChild(h);
  t.appendChild(p((d.ubicacion.address||("Coordenadas "+Number(d.ubicacion.lat).toFixed(5)+", "+Number(d.ubicacion.lng).toFixed(5)))+(d.ubicacion.en?" \u00b7 "+fecha(d.ubicacion.en):"")));
  if(d.bateria!==null)t.appendChild(p("Bater\u00eda: "+Math.round(d.bateria)+" %"));
  var s=document.createElement("div");d.senales.forEach(function(x){var e=document.createElement("span");e.className="pill"+(x.cumple?" si":"");e.textContent=x.texto;s.appendChild(e)});t.appendChild(s);
  if(d.apagadoEnMovimiento)t.appendChild(p("Dej\u00f3 de dar se\u00f1ales yendo en veh\u00edculo, con bater\u00eda alta."));
  var a=document.createElement("a");a.className="boton";a.href=d.ubicacion.mapa;a.target="_blank";a.rel="noopener";a.textContent="Abrir en el mapa";a.style.marginTop="12px";t.appendChild(a);
  t.appendChild(p("Si es grave, llam\u00e1 al 911 y mostrales esta ubicaci\u00f3n."));
  r.appendChild(t);
}
post("/api/referente/estado",{t:t}).then(pantalla).catch(function(){$("titulo").textContent="Enlace no v\u00e1lido";$("cuerpo").appendChild(p("Este enlace ya no sirve. Pedile a la persona que te lo vuelva a mandar."))});
})();
</script>`);
}

/** P\u00e1gina a la que llega la persona desde el mail: "Estoy bien". */
function pldPaginaEstoyBien() {
  return pldPagina("Estoy bien \u00b7 Ojo Guard", `
<h1>\u00bfEst\u00e1s bien?</h1><p>Alguien que te quiere no logra comunicarse con vos. Un toque y se tranquiliza.</p>
<div id="aviso"></div><p><button class="grande" id="b">Estoy bien</button></p>
<script>
(function(){
var t=new URLSearchParams(location.search).get("t")||"";
document.getElementById("b").onclick=function(){var b=this;b.disabled=true;
fetch("/api/estoy-bien",{method:"POST",headers:{"content-type":"application/json"},body:JSON.stringify({t:t})}).then(function(r){if(!r.ok)throw new Error("x");document.getElementById("aviso").textContent="Gracias. Ya les avisamos que est\u00e1s bien.";b.style.display="none"}).catch(function(){b.disabled=false;document.getElementById("aviso").textContent="No se pudo. Prob\u00e1 de nuevo."})};
})();
</script>`);
}
' $f.crlf
    $nuevo = $f.texto.Substring(0, $a) + $nuevoBloque + $f.texto.Substring($b)
    $nuevo = $nuevo.Replace($ganchoViejo, $ganchoNuevo)
    $esperado = $f.texto.Length - $viejo.Length + $nuevoBloque.Length + ($ganchoNuevo.Length - $ganchoViejo.Length)
    [System.IO.File]::WriteAllText($indice, $nuevo, (New-Object System.Text.UTF8Encoding($f.bom)))
    $v = Leer $indice
    $bien = ($v.texto.Length -eq $esperado) -and ((Contar $v.texto 'async function pldCron(env') -eq 1) -and ((Contar $v.texto 'pldCron(env).catch') -eq 1) -and ((Contar $v.texto 'async function pldApiDuenio') -eq 1) -and ((Contar $v.texto 'async function fetchCorreo') -eq 1)
    if (-not $bien) {
        Mal "Algo no salio bien. Restauro src\index.ts desde el respaldo."
        Copy-Item -LiteralPath ($indice + ".bak-pldcron") -Destination $indice -Force
        Mal "Restaurado. Mandame esta pantalla."
        return
    }
    Ok ("src\index.ts: largo " + $v.texto.Length + " (esperado " + $esperado + ")")
}
Write-Host ""
Ok "Archivo listo. Ahora publico el panel..."
& npx.cmd wrangler deploy
if ($LASTEXITCODE -ne 0) { Mal "No se pudo publicar el panel. Mandame esta pantalla."; return }
Write-Host ""
Ok "LISTO: el aviso automatico a los referentes esta publicado (corre con el cron de cada 15 minutos)."
Write-Host ""
