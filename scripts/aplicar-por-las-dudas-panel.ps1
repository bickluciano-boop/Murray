# aplicar-por-las-dudas-panel.ps1 - "Por las dudas": referentes de emergencia, primera parte (servidor). Estado: NUCLEO - EN VALIDACION.
# Idea de Luciano (17/10/2026) a partir de un caso real: un chico de 16 anos desaparecio y la familia no tenia como saber donde estuvo por ultima vez.
# La persona elige de antemano a sus REFERENTES. En el dia a dia nadie ve nada. Si algo parece raro, un referente preocupado aprieta "No lo encuentro"
# (en una pagina web con su enlace personal, sin app): se le manda a la persona un "Estas bien?" (mail y aviso en el telefono) y, solo si se cumplen
# las condiciones que ella permitio (sin senal hace rato, lejos de casa, bateria baja, de noche; o apagado en movimiento con bateria alta; o emergencia
# tras unas horas), se le muestra la ULTIMA SENAL del telefono. Cada consulta le llega a la persona y queda en su registro.
# Que agrega (todo nuevo, no cambia nada de lo que ya anda):
#  - Paginas: /por-las-dudas (la persona elige referentes y condiciones), /referente (el enlace del referente) y /estoy-bien.
#  - Cuatro tablas nuevas: pld_config, pld_referentes, pld_log, pld_checkins. Se enganchan solo las rutas nuevas y el codigo va junto a fetchCorreo.
#  - Todavia NO hay avisos automaticos del cron (eso es la segunda parte): por ahora el referente tiene que apretar el boton.
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Toca src\index.ts (respaldo .bak-pld), crea las tablas en la base y publica solo.
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
$yaAplicado = ((Contar $f.texto 'async function pldApiDuenio') -ne 0)
$anclas = @(
    @('codigo de Por las dudas junto a fetchCorreo', 'async function fetchCorreo(input: string, init: RequestInit) {', '// ---------------------------------------------------------------------------
// "Por las dudas" (N\u00daCLEO \u00b7 EN VALIDACI\u00d3N): referentes de emergencia.
// La persona elige de antemano a qui\u00e9n avisar; en el d\u00eda a d\u00eda nadie ve nada. Si pasan cosas raras (las condiciones que ella
// misma permiti\u00f3), un referente preocupado puede ver la \u00faltima se\u00f1al del tel\u00e9fono con el bot\u00f3n "No lo encuentro".
// Tablas: pld_config, pld_referentes, pld_log, pld_checkins (se crean con wrangler d1 execute, ver aplicar-por-las-dudas-panel.ps1).
// Especificaci\u00f3n: scripts/POR-LAS-DUDAS-ESPECIFICACION.md. Primera parte: referentes, "No lo encuentro" y \u00faltima se\u00f1al.
// Todav\u00eda no hay avisos autom\u00e1ticos del cron (segunda parte).
// ---------------------------------------------------------------------------
const PLD_MAX_REFERENTES = 5;

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
  return `${Math.max(1, Math.round(minutos))} minutos`;
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
  if (!f || f.status === "baja" || f.tokenHash !== (await hash(secreto))) return null;
  return f;
}

async function pldInvitar(env: Env, origen: string, duenio: string, cfg: PldConfig, referente: { id: string; name: string; email: string }, secreto: string) {
  const quien = pldNombreDe(duenio, cfg);
  const enlace = `${origen}/referente?t=${referente.id}.${secreto}`;
  await pldCorreo(
    env, referente.email, `${quien} te eligi\u00f3 como referente en Ojo Guard`,
    `<p style="font-size:20px;font-weight:700;margin:0 0 14px">Hola ${escapeHtml(referente.name)},</p>`
    + `<p style="color:#d2d2ce;line-height:1.55"><strong style="color:#fff">${escapeHtml(quien)}</strong> te eligi\u00f3 como <strong style="color:#fff">referente</strong>: una persona de confianza a la que recurrir <em>por las dudas</em>, si no logra comunicarse con ${escapeHtml(quien)} y algo parece raro.</p>`
    + `<p style="color:#d2d2ce;line-height:1.55">No ves la ubicaci\u00f3n de ${escapeHtml(quien)} en el d\u00eda a d\u00eda. Solo si pasan cosas raras (por ejemplo, el tel\u00e9fono deja de dar se\u00f1ales de noche y lejos de casa), vas a poder ver su <strong style="color:#fff">\u00faltima se\u00f1al</strong>.</p>`
    + pldBoton(enlace, "Aceptar y guardar mi enlace")
    + `<p style="color:#8f8d85;font-size:13px;line-height:1.5">Guard\u00e1 este mail: el enlace es personal y es el que vas a usar si alguna vez necesit\u00e1s el bot\u00f3n <strong>No lo encuentro</strong>.</p>`,
  );
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
    const id = `ref${pldSecreto().slice(0, 14)}`, secreto = pldSecreto();
    await env.DB.prepare("INSERT INTO pld_referentes (id,owner_email,name,email,token_hash,status,created_at) VALUES (?,?,?,?,?,?,?)")
      .bind(id, email, nombre, correo, await hash(secreto), "pendiente", now()).run();
    await pldInvitar(env, origen, email, cfg, { id, name: nombre, email: correo }, secreto);
    await pldRegistrar(env, email, id, "referente", `Se sum\u00f3 a ${nombre} como referente.`);
  } else if (accion === "reenviar") {
    const id = String(cuerpo.id ?? "");
    const r = await env.DB.prepare("SELECT id,name,email FROM pld_referentes WHERE id=? AND owner_email=? AND status<>''baja''").bind(id, email).first<{ id: string; name: string; email: string }>();
    if (!r) return json({ error: "not_found" }, 404);
    const secreto = pldSecreto();
    await env.DB.prepare("UPDATE pld_referentes SET token_hash=? WHERE id=?").bind(await hash(secreto), id).run();
    await pldInvitar(env, origen, email, cfg, r, secreto);
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
  return json(await pldPanorama(env, email));
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
  if (!reciente && cfg.enabled) {
    const secreto = pldSecreto(), id = `chk${pldSecreto().slice(0, 14)}`;
    await env.DB.prepare("INSERT INTO pld_checkins (id,owner_email,referente_id,token_hash,created_at) VALUES (?,?,?,?,?)").bind(id, email, r.id, await hash(secreto), now()).run();
    const enlace = `${origen}/estoy-bien?t=${id}.${secreto}`;
    await pldCorreo(
      env, email, `${r.name} quiere saber si est\u00e1s bien`,
      `<p style="font-size:20px;font-weight:700;margin:0 0 12px">\u00bfEst\u00e1s bien?</p><p style="color:#d2d2ce;line-height:1.55"><strong style="color:#fff">${escapeHtml(r.name)}</strong> no logra comunicarse con vos y apret\u00f3 <em>No lo encuentro</em>. Si est\u00e1s bien, avisale con un toque.</p>${pldBoton(enlace, "Estoy bien")}`,
    );
    if (estado.pushToken) {
      await sendExpoNotice(estado.pushToken, `${r.name} quiere saber si est\u00e1s bien`, "Abr\u00ed tu correo y toc\u00e1 \"Estoy bien\", o escribile.", {}).catch(() => false);
    }
    // En Android se pide adem\u00e1s una ubicaci\u00f3n nueva (en iPhone el aviso silencioso no despierta la app).
    if (estado.deviceId && estado.pushToken && estado.plataforma !== "ios") {
      await queueAutoLocateCommand(env, { id: estado.deviceId, ownerEmail: email, pushToken: estado.pushToken }).catch(() => false);
    }
  }

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
  if (!c || c.tokenHash !== (await hash(secreto))) return json({ error: "enlace_invalido" }, 404);
  if (!c.answeredAt) {
    await env.DB.prepare("UPDATE pld_checkins SET answered_at=? WHERE owner_email=? AND answered_at IS NULL").bind(now(), c.ownerEmail).run();
    const r = await env.DB.prepare("SELECT name,email FROM pld_referentes WHERE id=?").bind(c.referenteId).first<{ name: string; email: string }>();
    const cfg = await pldLeerConfig(env, c.ownerEmail);
    const quien = pldNombreDe(c.ownerEmail, cfg);
    await pldRegistrar(env, c.ownerEmail, c.referenteId, "estoy-bien", `La persona respondi\u00f3 "Estoy bien".`);
    if (r) await pldCorreo(env, r.email, `${quien} dice que est\u00e1 bien`, `<p style="font-size:20px;font-weight:700;margin:0 0 12px">${escapeHtml(quien)} dice que est\u00e1 bien.</p><p style="color:#d2d2ce;line-height:1.55">Respondi\u00f3 al "\u00bfEst\u00e1s bien?" que se le mand\u00f3 cuando apretaste <em>No lo encuentro</em>.</p>`);
  }
  return json({ ok: true });
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
<p class="suave">Esta funci\u00f3n est\u00e1 en validaci\u00f3n: todav\u00eda no la probamos de punta a punta en un tel\u00e9fono real.</p>
<div id="aviso"></div>
<div class="tarjeta"><h2>C\u00f3mo est\u00e1s hoy</h2><div id="hoy" class="suave">Cargando\u2026</div></div>
<div class="tarjeta"><h2>Tus referentes</h2><div id="referentes" class="suave">Cargando\u2026</div>
<label>Nombre</label><input id="rNombre" maxlength="60" placeholder="Mam\u00e1"><label>Correo</label><input id="rCorreo" type="email" placeholder="mama@correo.com">
<p><button id="rAgregar">Elegir referente</button></p><small class="suave">Hasta 5. Le llega un mail con su enlace personal y tiene que aceptar.</small></div>
<div class="tarjeta"><h2>Condiciones</h2><small class="suave">Un referente solo ve tu \u00faltima se\u00f1al si se cumplen al menos estas se\u00f1ales a la vez.</small>
<label>C\u00f3mo te llaman tus referentes</label><input id="cNombre" maxlength="60">
<div class="dos"><div><label>De noche desde (hora)</label><input id="cDesde" type="number" min="0" max="23"></div><div><label>hasta (hora)</label><input id="cHasta" type="number" min="0" max="23"></div></div>
<div class="dos"><div><label>Sin se\u00f1al de noche (min)</label><input id="cSilNoche" type="number" min="10"></div><div><label>Sin se\u00f1al de d\u00eda (min)</label><input id="cSilDia" type="number" min="10"></div></div>
<div class="dos"><div><label>Lejos de casa (km)</label><input id="cKm" type="number" min="0.5" step="0.5"></div><div><label>Bater\u00eda baja (%)</label><input id="cBat" type="number" min="1" max="50"></div></div>
<div class="dos"><div><label>Se\u00f1ales necesarias (de 4)</label><select id="cMin"><option>2</option><option>3</option><option>4</option></select></div><div><label>Emergencia tras (horas)</label><input id="cEmer" type="number" min="1" max="48"></div></div>
<label><input id="cActivo" type="checkbox" style="width:auto"> Por las dudas est\u00e1 encendido</label>
<p><button id="cGuardar">Guardar condiciones</button> <button class="sec" id="cCasa">Mi casa es donde est\u00e1 mi tel\u00e9fono ahora</button></p><div id="casa" class="suave"></div></div>
<div class="tarjeta"><h2>Esta noche, afuera</h2><small class="suave">Si dorm\u00eds en otro lado, paus\u00e1 los avisos por unas horas.</small><p><button class="sec" data-h="8">Pausar 8 horas</button> <button class="sec" data-h="0">Quitar pausa</button></p><div id="pausa" class="suave"></div></div>
<div class="tarjeta"><h2>Registro</h2><div id="registro" class="suave">Cargando\u2026</div></div>
<script>
(function(){
var $=function(i){return document.getElementById(i)};
function aviso(t){$("aviso").textContent=t||""}
function api(cuerpo){return fetch("/api/remote/por-las-dudas",{method:cuerpo?"POST":"GET",headers:{"content-type":"application/json"},body:cuerpo?JSON.stringify(cuerpo):undefined,credentials:"same-origin"}).then(function(r){return r.json().then(function(d){if(r.status===401){throw new Error("Entr\u00e1 primero al panel de Ojo Guard MS con tu cuenta y volv\u00e9 a abrir esta p\u00e1gina.")}if(!r.ok){throw new Error(({invalid_referente:"Revis\u00e1 el nombre y el correo.",referente_es_vos:"El referente no puede ser vos.",demasiados_referentes:"Ya ten\u00e9s 5 referentes.",referente_repetido:"Ese correo ya es referente.",sin_ubicacion:"Todav\u00eda no hay una ubicaci\u00f3n de tu tel\u00e9fono."})[d.error]||"No se pudo. Prob\u00e1 de nuevo.")}return d})})}
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
    if(x.status!=="aceptado"){var re=document.createElement("button");re.className="sec chico";re.textContent="Reenviar";re.onclick=function(){accion({accion:"reenviar",id:x.id},"Enlace reenviado.")};dr.appendChild(re);dr.appendChild(document.createTextNode(" "))}
    var qu=document.createElement("button");qu.className="sec chico";qu.textContent="Quitar";qu.onclick=function(){if(confirm("\u00bfQuitar a "+x.name+"?"))accion({accion:"quitar",id:x.id},"Referente quitado.")};dr.appendChild(qu);f.appendChild(dr);r.appendChild(f)});
  var c=d.config;$("cNombre").value=c.displayName||"";$("cDesde").value=c.nightFrom;$("cHasta").value=c.nightTo;$("cSilNoche").value=c.silenceNightMin;$("cSilDia").value=c.silenceDayMin;$("cKm").value=c.farKm;$("cBat").value=c.batteryPct;$("cMin").value=String(c.minSignals);$("cEmer").value=c.emergencyHours;$("cActivo").checked=!!c.enabled;
  $("casa").textContent=c.homeLat===null?"Todav\u00eda no marcaste d\u00f3nde est\u00e1 tu casa: sin eso, la se\u00f1al \u201clejos de casa\u201d no cuenta.":"Casa marcada ("+Number(c.homeLat).toFixed(4)+", "+Number(c.homeLng).toFixed(4)+").";
  $("pausa").textContent=c.pausedUntil&&c.pausedUntil>new Date().toISOString()?"En pausa hasta "+fecha(c.pausedUntil)+".":"Sin pausa.";
  var g=$("registro");limpiar(g);if(!d.registro.length){texto(g,"Todav\u00eda no hay nada.")}
  d.registro.forEach(function(x){var f=document.createElement("div");f.className="fila";var t=document.createElement("span");t.textContent=x.detail;var w=document.createElement("small");w.textContent=fecha(x.createdAt);w.className="suave";f.appendChild(t);f.appendChild(w);g.appendChild(f)});
}
function accion(cuerpo,ok){aviso("");return api(cuerpo).then(function(d){pintar(d);if(ok)aviso(ok)}).catch(function(e){aviso(e.message)})}
$("rAgregar").onclick=function(){accion({accion:"agregar",name:$("rNombre").value,email:$("rCorreo").value},"Listo: le mandamos el mail a tu referente.").then(function(){$("rNombre").value="";$("rCorreo").value=""})};
$("cGuardar").onclick=function(){accion({accion:"config",config:{displayName:$("cNombre").value,nightFrom:$("cDesde").value,nightTo:$("cHasta").value,silenceNightMin:$("cSilNoche").value,silenceDayMin:$("cSilDia").value,farKm:$("cKm").value,batteryPct:$("cBat").value,minSignals:$("cMin").value,emergencyHours:$("cEmer").value,enabled:$("cActivo").checked}},"Condiciones guardadas.")};
$("cCasa").onclick=function(){accion({accion:"casa"},"Casa marcada.")};
Array.prototype.forEach.call(document.querySelectorAll("button[data-h]"),function(b){b.onclick=function(){accion({accion:"pausa",horas:Number(b.getAttribute("data-h"))},b.getAttribute("data-h")==="0"?"Pausa quitada.":"Pausa puesta por 8 horas.")}});
api().then(pintar).catch(function(e){aviso(e.message)});
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
  var l=document.createElement("label");l.style.display="block";l.style.margin="14px 0";var k=document.createElement("input");k.type="checkbox";k.style.width="auto";l.appendChild(k);l.appendChild(document.createTextNode(" Es una emergencia (pasaron m\u00e1s de "+e.emergenciaHoras+" horas sin noticias)"));c.appendChild(l);
  var b2=document.createElement("button");b2.className="grande";b2.textContent="No lo encuentro";c.appendChild(b2);
  var r=document.createElement("div");c.appendChild(r);
  b2.onclick=function(){b2.disabled=true;$("aviso").textContent="Mirando\u2026";post("/api/referente/buscar",{t:t,emergencia:k.checked}).then(function(d){$("aviso").textContent="";b2.disabled=false;limpiar(r);resultado(r,d)}).catch(function(){b2.disabled=false;$("aviso").textContent="No se pudo. Prob\u00e1 de nuevo."})};
}
function resultado(r,d){
  var t=document.createElement("div");t.className="tarjeta";
  if(!d.mostrar){t.appendChild(p(d.mensaje,d.estaBien?"ok":""));r.appendChild(t);return}
  var h=document.createElement("h2");h.textContent="\u00daltima se\u00f1al de "+d.quien;t.appendChild(h);
  t.appendChild(p((d.ubicacion.address||"Sin direcci\u00f3n")+(d.ubicacion.en?" \u00b7 "+fecha(d.ubicacion.en):"")));
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
async function fetchCorreo(input: string, init: RequestInit) {'),
    @('rutas de Por las dudas', 'if (route === "GET /unirme") return familyJoinPage(url);', 'if (route === "GET /por-las-dudas") return pldPaginaDuenio();
      if (url.pathname === "/api/remote/por-las-dudas") return pldApiDuenio(request, env);
      if (route === "GET /referente") return pldPaginaReferente();
      if (route === "POST /api/referente/estado") return pldApiReferenteEstado(request, env);
      if (route === "POST /api/referente/aceptar") return pldApiReferenteAceptar(request, env);
      if (route === "POST /api/referente/buscar") return pldApiReferenteBuscar(request, env);
      if (route === "GET /estoy-bien") return pldPaginaEstoyBien();
      if (route === "POST /api/estoy-bien") return pldApiEstoyBien(request, env);
      if (route === "GET /unirme") return familyJoinPage(url);')
)
if ($yaAplicado) {
    Avi "El codigo de Por las dudas ya estaba en src\index.ts. Solo reviso las tablas y publico de nuevo."
} else {
    $ok = $true
    foreach ($c in $anclas) {
        $cuantos = Contar $f.texto (Ajustar $c[1] $f.crlf)
        if ($cuantos -eq 1) { Ok ($c[0] + ": 1") } else { Mal ($c[0] + ": " + $cuantos + " (esperaba 1)"); $ok = $false }
    }
    if (-not $ok) { Mal "Alguna ancla no coincide. No toco nada. Mandame esta pantalla."; return }
    if (Test-Path ($indice + ".bak-pld")) { Mal "Ya existe src\index.ts.bak-pld. No toco nada."; return }
    Copy-Item -LiteralPath $indice -Destination ($indice + ".bak-pld")
    Ok "Respaldo creado: src\index.ts.bak-pld"
    $nuevo = $f.texto
    $esperado = $f.texto.Length
    foreach ($c in $anclas) {
        $a = Ajustar $c[1] $f.crlf; $r = Ajustar $c[2] $f.crlf
        $nuevo = $nuevo.Replace($a, $r)
        $esperado = $esperado + ($r.Length - $a.Length)
    }
    [System.IO.File]::WriteAllText($indice, $nuevo, (New-Object System.Text.UTF8Encoding($f.bom)))
    $v = Leer $indice
    $bien = ($v.texto.Length -eq $esperado) -and ((Contar $v.texto 'async function pldApiDuenio') -eq 1) -and ((Contar $v.texto 'GET /por-las-dudas') -eq 1) -and ((Contar $v.texto 'async function fetchCorreo') -eq 1)
    if (-not $bien) {
        Mal "Algo no salio bien. Restauro src\index.ts desde el respaldo."
        Copy-Item -LiteralPath ($indice + ".bak-pld") -Destination $indice -Force
        Mal "Restaurado. Mandame esta pantalla."
        return
    }
    Ok ("src\index.ts: largo " + $v.texto.Length + " (esperado " + $esperado + ")")
}
Write-Host ""
Ok "Creo las cuatro tablas de Por las dudas en la base y publico el panel..."
$sqlPld = 'CREATE TABLE IF NOT EXISTS pld_config (owner_email TEXT PRIMARY KEY, enabled INTEGER NOT NULL DEFAULT 1, display_name TEXT NOT NULL, night_from INTEGER NOT NULL DEFAULT 21, night_to INTEGER NOT NULL DEFAULT 6, silence_night_min INTEGER NOT NULL DEFAULT 90, silence_day_min INTEGER NOT NULL DEFAULT 360, far_km REAL NOT NULL DEFAULT 3, battery_pct INTEGER NOT NULL DEFAULT 15, min_signals INTEGER NOT NULL DEFAULT 3, emergency_hours INTEGER NOT NULL DEFAULT 3, home_lat REAL, home_lng REAL, paused_until TEXT, updated_at TEXT NOT NULL); CREATE TABLE IF NOT EXISTS pld_referentes (id TEXT PRIMARY KEY, owner_email TEXT NOT NULL, name TEXT NOT NULL, email TEXT NOT NULL, token_hash TEXT NOT NULL, status TEXT NOT NULL, created_at TEXT NOT NULL, accepted_at TEXT, muted_until TEXT); CREATE TABLE IF NOT EXISTS pld_log (id TEXT PRIMARY KEY, owner_email TEXT NOT NULL, referente_id TEXT, kind TEXT NOT NULL, detail TEXT, created_at TEXT NOT NULL); CREATE TABLE IF NOT EXISTS pld_checkins (id TEXT PRIMARY KEY, owner_email TEXT NOT NULL, referente_id TEXT NOT NULL, token_hash TEXT NOT NULL, created_at TEXT NOT NULL, answered_at TEXT); CREATE INDEX IF NOT EXISTS pld_referentes_owner ON pld_referentes (owner_email); CREATE INDEX IF NOT EXISTS pld_log_owner ON pld_log (owner_email, created_at); CREATE INDEX IF NOT EXISTS pld_checkins_ref ON pld_checkins (referente_id, created_at);'
& npx.cmd wrangler d1 execute ojo-guard-ms --remote --command $sqlPld
if ($LASTEXITCODE -ne 0) { Mal "No se pudieron crear las tablas, asi que no publique nada. Mandame esta pantalla."; return }
Ok "Tablas listas"
& npx.cmd wrangler deploy
if ($LASTEXITCODE -ne 0) { Mal "No se pudo publicar el panel. Mandame esta pantalla."; return }
Write-Host ""
Ok "LISTO: Por las dudas esta publicado."
Ok "Tu pagina: https://ojo-guard-ms-api.bickluciano.workers.dev/por-las-dudas (abrila en el navegador donde ya entraste al panel)."
Write-Host ""
