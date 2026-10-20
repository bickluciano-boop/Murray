# aplicar-guardian-mejoras-panel.ps1 - Modo Guardian, mejoras de la primera prueba (20/10/2026): tiempo calculado por Google Mapas, pitidos al final y "con que demora toque".
# Luciano, probando el Guardian: (1) "el tiempo de recorrido lo tiene que poner la app calculando en mapas segun transito o cortes; la persona se equivoca mas";
# (2) "que diga con que demora toque"; (3) "los ultimos 15 segundos que suene pip pip cada segundo, como una bomba para desactivar, asi se dan cuenta de apretar".
#  1) El tiempo lo calcula Google (Routes API) desde donde esta el telefono hasta el Lugar o la direccion escrita: en auto con el TRANSITO DE AHORA, en transporte publico o a pie. No se puede cambiar a mano.
#     Si queda a mas de 5 horas (por ejemplo "Kansas", EEUU) avisa que se revise y no deja empezar. Al tocar Empezar la pagina intenta usar la ubicacion exacta del celular (pide permiso).
#     Si no hay clave de Google, o Google no contesta, o no hay ruta: se estima por la distancia (solo tus Lugares) o la persona pone los minutos, como hasta ahora. El registro dice de donde salio el tiempo.
#     Hace falta una CLAVE de Google con la "Routes API" habilitada, guardada como secreto del panel: npx wrangler secret put GOOGLE_ROUTES_KEY (la clave se pega en esa pantalla, no se la mandes a nadie).
#  2) Al tocar "Llegue" la pagina, el registro y el mail a los referentes (si se les habia avisado) dicen a que hora tocaste y con cuanta demora: "1 minuto antes del limite" / "4 minutos despues del limite",
#     mas cuanto tardaste contra el tiempo calculado.
#  3) En la pagina del camino, en los ultimos 15 segundos suena un pip por segundo (y uno largo al llegar a cero) y vibra; hay un boton "Sonido: activado / apagado". La pantalla tiene que estar abierta y
#     tocarla una vez para habilitar el sonido (regla de los navegadores); mientras hay camino en marcha la pagina mantiene la pantalla encendida.
# Reemplaza el codigo de Modo Cautela dentro de src\index.ts, comprobando antes con una huella SHA-256 que es el que dejaron los parches anteriores (acepta las siete versiones). No cambia tablas ni rutas.
# Requiere aplicar-guardian-camino-panel.ps1. Va en la carpeta del PANEL (la que tiene wrangler.toml). Respaldo .bak-pldmejoras. Al final publica el panel solo.
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
if ((Contar $f.texto 'async function gdRutaMapas(') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $f.texto 'async function gdCron(') -ne 1) { Mal "Falta aplicar antes aplicar-guardian-camino-panel.ps1."; return }
$marcaIni = Ajustar '// ---------------------------------------------------------------------------
// "Modo Cautela" (antes "Por las dudas"; N\u00daCLEO \u00b7 EN VALIDACI\u00d3N): referentes de emergencia.' $f.crlf
$marcaFin = Ajustar 'async function fetchCorreo(input: string, init: RequestInit) {' $f.crlf
$huellasViejas = @("88d257c0bb656331b11ebc66c0f3521a884bd69fffa915a649cf143c0211d218", "a887fbf6bdbf1e85e4a223f5a4030a2e76d03a926b175bb25bf434da812c4e11", "e9d0a02cb9e148f97f2252c27b6ff6e255dd2c7691460711436024ca7eb3bc1c", "36cda30909fa54787b0e682833b526b4719fe9ad7c4bc4fdd3f510e149560ccd", "db1d0c40da359644ef62f03571f025a20e1935957c372430fe1848d945aee385", "905732ab1a69eaaeb7405cb0b5eab31fb0c970558761dcde20bf73808b582759", "85283ceb6c5b866c568093e2b33e3fda9454c1c4271a79951c4772142da076dd")
$ok = $true
if ((Contar $f.texto $marcaIni) -ne 1) { Mal "No encuentro el principio del codigo de Modo Cautela (esperaba 1)."; $ok = $false }
if ((Contar $f.texto $marcaFin) -ne 1) { Mal "No encuentro el final del codigo de Modo Cautela (esperaba 1)."; $ok = $false }
if (-not $ok) { Mal "Alguna ancla no coincide. No toco nada. Mandame esta pantalla."; return }
$a = $f.texto.IndexOf($marcaIni, [System.StringComparison]::Ordinal)
$b = $f.texto.IndexOf($marcaFin, $a, [System.StringComparison]::Ordinal)
if ($b -le $a) { Mal "El codigo de Modo Cautela no esta donde esperaba. No toco nada. Mandame esta pantalla."; return }
$viejo = $f.texto.Substring($a, $b - $a)
$viejoLF = ($viejo -replace "`r`n", "`n")
$hasher = [System.Security.Cryptography.SHA256]::Create()
$huella = ([System.BitConverter]::ToString($hasher.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($viejoLF)))).Replace("-", "").ToLower()
if ($huellasViejas -notcontains $huella) { Mal ("El codigo de Modo Cautela que hay en src\index.ts no es el que dejaron los parches anteriores (huella " + $huella + "). No toco nada. Mandame esta pantalla."); return }
Ok ("Codigo de Modo Cautela actual reconocido: " + $viejoLF.Length + " caracteres")
if (Test-Path ($indice + ".bak-pldmejoras")) { Mal "Ya existe src\index.ts.bak-pldmejoras. No toco nada."; return }
Copy-Item -LiteralPath $indice -Destination ($indice + ".bak-pldmejoras")
Ok "Respaldo creado: src\index.ts.bak-pldmejoras"
$nuevoBloque = Ajustar '// ---------------------------------------------------------------------------
// "Modo Cautela" (antes "Por las dudas"; N\u00daCLEO \u00b7 EN VALIDACI\u00d3N): referentes de emergencia.
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
  if (!cfg.enabled) return { ...estado, motivo: "Esta persona tiene apagado el Modo Cautela." };
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
  const html = `<div style="font-family:Arial,sans-serif;max-width:560px;margin:auto;background:#0c0d0f;color:#f6f6f2;padding:28px;border-radius:20px">${cuerpo}<p style="color:#8f8d85;font-size:12px;margin:26px 0 0">ojo guard &middot; modo cautela</p></div>`;
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
async function pldPanorama(env: Env, email: string, persona: PldPersona, sesionEmail: string) {
  const cfg = await pldLeerConfig(env, email);
  if (!persona.propia && !cfg.displayName.trim() && persona.nombre) cfg.displayName = persona.nombre.slice(0, 60);
  const personas = persona.soloLectura ? { results: [] as Array<{ email: string; name: string }> }
    : await env.DB.prepare("SELECT member_email AS email,name FROM family_members WHERE status=''activo'' AND role=''menor'' AND (owner_email=? OR owner_email IN (SELECT owner_email FROM family_members WHERE member_email=? AND status=''activo'' AND role=''adulto'')) ORDER BY name ASC")
      .bind(normalizeEmail(sesionEmail), normalizeEmail(sesionEmail)).all<{ email: string; name: string }>();
  const referentes = await env.DB.prepare("SELECT id,name,email,status,created_at AS createdAt,accepted_at AS acceptedAt,muted_until AS mutedUntil FROM pld_referentes WHERE owner_email=? AND status<>''baja'' ORDER BY created_at ASC").bind(email).all();
  const registro = await env.DB.prepare("SELECT l.kind,l.detail,l.created_at AS createdAt,r.name AS referente FROM pld_log l LEFT JOIN pld_referentes r ON r.id=l.referente_id WHERE l.owner_email=? ORDER BY l.created_at DESC LIMIT 25").bind(email).all();
  const hoy = await pldEvaluar(env, email, { ...cfg, enabled: true, pausedUntil: null }, false);
  return {
    ok: true,
    email,
    persona,
    personas: (personas.results ?? []).filter((x, i, todos) => todos.findIndex((y) => y.email === x.email) === i),
    config: cfg,
    referentes: referentes.results ?? [],
    registro: registro.results ?? [],
    hoy: {
      telefono: hoy.telefono,
      hayDatos: hoy.hayDatos,
      senales: hoy.senales,
      cumplen: hoy.cumplen,
      mostrar: hoy.mostrar,
      apagadoEnMovimiento: hoy.apagadoEnMovimiento,
      bateria: hoy.bateria,
      ultimaVez: hoy.ultimaVez,
      motivo: hoy.motivo,
    },
  };
}

type PldPersona = { email: string; nombre: string; propia: boolean; soloLectura: boolean };

/** Para qui\u00e9n es la p\u00e1gina. Un adulto arma la suya. Un MENOR solo puede mirar la suya, sin editar: la arma el titular de la familia
 *  (o un adulto de esa familia, por ejemplo un hermano mayor cuando el padre viaja), que tambi\u00e9n puede mirar y armar la de cada menor (con ?persona=correo). */
async function pldResolverPersona(env: Env, sesionEmail: string, pedida: string): Promise<PldPersona | { error: string; status: number }> {
  const yo = normalizeEmail(sesionEmail);
  const otra = pedida ? normalizeEmail(pedida) : "";
  const soyMenor = await env.DB.prepare("SELECT name FROM family_members WHERE member_email=? AND status=''activo'' AND role=''menor'' LIMIT 1").bind(yo).first<{ name: string }>();
  if (soyMenor) {
    if (otra && otra !== yo) return { error: "solo_administrador", status: 403 };
    return { email: sesionEmail, nombre: String(soyMenor.name ?? ""), propia: true, soloLectura: true };
  }
  if (!otra || otra === yo) return { email: sesionEmail, nombre: "", propia: true, soloLectura: false };
  const menor = await env.DB.prepare("SELECT name FROM family_members WHERE member_email=? AND status=''activo'' AND role=''menor'' AND (owner_email=? OR owner_email IN (SELECT owner_email FROM family_members WHERE member_email=? AND status=''activo'' AND role=''adulto'')) LIMIT 1")
    .bind(otra, yo, yo).first<{ name: string }>();
  if (!menor) return { error: "no_autorizado", status: 403 };
  return { email: otra, nombre: String(menor.name ?? ""), propia: false, soloLectura: false };
}

function pldHorasTexto(horas: number) {
  return horas === 1 ? "1 hora" : `${Math.round(horas * 10) / 10} horas`;
}

/** Si la persona pausa o apaga el Modo Cautela, se cierra el episodio abierto (al volver empieza de cero, con un "\u00bfEst\u00e1s bien?").
 *  Si ya se les hab\u00eda avisado a los referentes, se les cuenta, para que no se queden esperando. */
async function pldCerrarEpisodio(env: Env, email: string, cfg: PldConfig, que: string) {
  const ep = await pldLeerEpisodio(env, email);
  if (!ep) return;
  await env.DB.prepare("DELETE FROM pld_episodios WHERE owner_email=?").bind(email).run();
  if (ep.alerts === 0 || ep.state === "respondio") return;
  const quien = pldNombreDe(email, cfg);
  let avisados = 0;
  for (const x of await pldReferentesActivos(env, email)) {
    const ok = await pldCorreo(
      env, x.email, `${quien} entr\u00f3 a su cuenta de Ojo Guard`,
      `<p style="font-size:20px;font-weight:700;margin:0 0 14px">Hola ${escapeHtml(x.name)},</p>`
      + `<p style="color:#d2d2ce;line-height:1.55"><strong style="color:#fff">${escapeHtml(quien)}</strong> entr\u00f3 a su cuenta de Ojo Guard y ${que}. Por eso, por el momento, no te vamos a seguir avisando.</p>`
      + `<p style="color:#8f8d85;font-size:13px;line-height:1.5">Si todav\u00eda te preocupa, intent\u00e1 comunicarte con ${escapeHtml(quien)}. Si es grave, llam\u00e1 al 911.</p>`,
    );
    if (ok) avisados++;
  }
  if (avisados > 0) await pldRegistrar(env, email, null, "aviso", `Se les avis\u00f3 a tus referentes que ${que}: dejan de recibir avisos por ahora.`);
}

/** API del due\u00f1o (con sesi\u00f3n): ver y cambiar sus referentes y condiciones. */
async function pldApiDuenio(request: Request, env: Env) {
  const sesion = await readSessionInfo(request, env.SESSION_SECRET);
  if (!sesion) return json({ error: "unauthorized" }, 401);
  if (sesion.method === "emergency") return json({ error: "not_allowed_in_emergency" }, 403);
  const persona = await pldResolverPersona(env, sesion.email, new URL(request.url).searchParams.get("persona") ?? "");
  if ("error" in persona) return json({ error: persona.error }, persona.status);
  const email = persona.email;
  if (request.method === "GET") return json(await pldPanorama(env, email, persona, sesion.email));
  if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  if (persona.soloLectura) return json({ error: "solo_administrador" }, 403);
  const cuerpo = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const accion = String(cuerpo.accion ?? "");
  let cfg = await pldLeerConfig(env, email);
  if (!persona.propia && !cfg.displayName.trim() && persona.nombre) {
    cfg = { ...cfg, displayName: persona.nombre.slice(0, 60) };
    await pldGuardarConfig(env, email, cfg);
  }
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
    const cambioEncendido = nuevo.enabled !== cfg.enabled;
    await pldRegistrar(env, email, null, "config", cambioEncendido ? (nuevo.enabled ? "La persona encendi\u00f3 el Modo Cautela." : "La persona apag\u00f3 el Modo Cautela.") : "La persona cambi\u00f3 sus condiciones.");
    if (cambioEncendido && !nuevo.enabled) await pldCerrarEpisodio(env, email, cfg, "apag\u00f3 el Modo Cautela");
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
    await pldRegistrar(env, email, null, "config", horas > 0 ? `Pausa de ${pldHorasTexto(horas)} (pausa de avisos).` : "Se quit\u00f3 la pausa.");
    if (horas > 0) await pldCerrarEpisodio(env, email, cfg, `paus\u00f3 los avisos por ${pldHorasTexto(horas)}`);
  } else {
    return json({ error: "accion_desconocida" }, 400);
  }
  if (!persona.propia) {
    const hizo: Record<string, string> = { agregar: "agreg\u00f3 un referente", quitar: "quit\u00f3 un referente", config: "cambi\u00f3 las condiciones o el encendido", pausa: "cambi\u00f3 la pausa", casa: "marc\u00f3 la casa", reenviar: "reenvi\u00f3 un enlace" };
    await pldRegistrar(env, email, null, "config", `${sesion.email} (administrador de la familia) ${hizo[accion] ?? "hizo un cambio"}.`);
  }
  return json({ ...(await pldPanorama(env, email, persona, sesion.email)), ...extra });
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
    await sendExpoNotice(estado.pushToken, titulo, cuerpo, { data: { tipo: "pld-estoy-bien", url: enlace } }).catch(() => false);
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

// ---------------------------------------------------------------------------
// SOS: cuando la persona aprieta el bot\u00f3n de ayuda (el de la app o un disparador del sistema), tambi\u00e9n se les avisa a sus referentes.
// Lo llaman nativeFamilySos (al pedir y al cancelar) desde src/index.ts. Es una acci\u00f3n de la propia persona, as\u00ed que no espera ni pregunta,
// va con la ubicaci\u00f3n del SOS y no depende de la pausa de avisos ni de que el Modo Cautela est\u00e9 encendido o apagado.
// ---------------------------------------------------------------------------
async function pldTieneGuardianes(env: Env, email: string) {
  return (await pldReferentesActivos(env, email)).length > 0;
}

async function pldAvisarSos(env: Env, email: string, ubicacion: Record<string, unknown> | null) {
  const cfg = await pldLeerConfig(env, email);
  const referentes = await pldReferentesActivos(env, email);
  if (!referentes.length) return 0;
  const quien = pldNombreDe(email, cfg);
  const origen = pldOrigen(env);
  const lat = Number(ubicacion?.latitude), lng = Number(ubicacion?.longitude);
  const hayMapa = Number.isFinite(lat) && Number.isFinite(lng) && !(lat === 0 && lng === 0);
  const direccion = ubicacion?.address ? String(ubicacion.address) : "";
  let enviados = 0;
  for (const x of referentes) {
    const enlace = await pldEnlaceReferente(env, origen, x);
    const ok = await pldCorreo(
      env, x.email, `SOS: ${quien} pidi\u00f3 ayuda`,
      `<p style="font-size:20px;font-weight:700;margin:0 0 14px">Hola ${escapeHtml(x.name)},</p>`
      + `<p style="color:#d2d2ce;line-height:1.55"><strong style="color:#fff">${escapeHtml(quien)}</strong> acaba de apretar el bot\u00f3n de ayuda (SOS) en Ojo Guard.</p>`
      + (direccion ? `<p style="color:#d2d2ce;line-height:1.55">\u00daltima ubicaci\u00f3n: ${escapeHtml(direccion)}</p>` : "")
      + (hayMapa ? pldBoton(`https://www.google.com/maps?q=${lat},${lng}`, "Abrir en el mapa") : "")
      + `<p style="color:#d2d2ce;line-height:1.55">Intent\u00e1 comunicarte con ${escapeHtml(quien)} ahora. Si no logr\u00e1s hablar y es grave, llam\u00e1 al 911 y mostrales esta ubicaci\u00f3n.</p>`
      + `<p style="color:#8f8d85;font-size:13px;line-height:1.5">Tambi\u00e9n pod\u00e9s ver su \u00faltima se\u00f1al desde tu enlace personal:</p>`
      + pldBoton(enlace, "Ver su \u00faltima se\u00f1al") + pldEnlaceEscrito(enlace),
    );
    if (ok) {
      enviados++;
      await pldRegistrar(env, email, x.id, "sos", `Se le avis\u00f3 a ${x.name} del SOS.`);
    }
  }
  return enviados;
}

/** La persona cancel\u00f3 su SOS: se les cuenta a los referentes a los que se les hab\u00eda avisado. */
async function pldAvisarSosCancelado(env: Env, email: string, desde: string) {
  const avisados = await env.DB.prepare("SELECT DISTINCT referente_id AS id FROM pld_log WHERE owner_email=? AND kind=''sos'' AND created_at>=? AND referente_id IS NOT NULL")
    .bind(email, desde).all<{ id: string }>();
  if (!(avisados.results ?? []).length) return 0;
  const cfg = await pldLeerConfig(env, email);
  const quien = pldNombreDe(email, cfg);
  let enviados = 0;
  for (const a of avisados.results ?? []) {
    const x = await env.DB.prepare("SELECT name,email FROM pld_referentes WHERE id=? AND status=''aceptado''").bind(a.id).first<{ name: string; email: string }>();
    if (!x) continue;
    const ok = await pldCorreo(
      env, x.email, `${quien} cancel\u00f3 el SOS: est\u00e1 bien`,
      `<p style="font-size:20px;font-weight:700;margin:0 0 14px">Hola ${escapeHtml(x.name)},</p><p style="color:#d2d2ce;line-height:1.55"><strong style="color:#fff">${escapeHtml(quien)}</strong> cancel\u00f3 el SOS: avis\u00f3 que est\u00e1 bien. No hace falta hacer nada.</p>`,
    );
    if (ok) {
      enviados++;
      await pldRegistrar(env, email, a.id, "sos-fin", `${x.name} supo que se cancel\u00f3 el SOS.`);
    }
  }
  return enviados;
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

// ---------------------------------------------------------------------------
// Modo Guardi\u00e1n (N\u00daCLEO \u00b7 EN VALIDACI\u00d3N): acompa\u00f1arte en el camino.
// La persona dice a d\u00f3nde va y c\u00f3mo; el servidor calcula cu\u00e1nto tarda (o ella lo pone) y corre una cuenta regresiva con 2 minutos de m\u00e1s.
// El reloj corre en el servidor (cron de cada minuto): si el tel\u00e9fono se apaga, el aviso sale igual. Dos minutos antes de que venza se le pregunta
// "\u00bfSegu\u00eds en camino?" (Llegu\u00e9 / Extender); si no responde, se les avisa a sus referentes con su \u00faltima ubicaci\u00f3n y se repite cada 10 minutos (hasta 3 veces).
// "Necesito ayuda" avisa enseguida como un SOS. Mientras dura el camino se le pide al tel\u00e9fono una ubicaci\u00f3n nueva cada 5 minutos (Android) y, si el
// tel\u00e9fono llega al destino, se le pregunta "\u00bfLlegaste bien?". Todo queda en el registro.
// ---------------------------------------------------------------------------
const GD_MARGEN_MIN = 2;
const GD_AVISO_ANTES_MIN = 2;
const GD_EXTENSIONES = [10, 20, 30];
const GD_MAX_EXTENSIONES = 3;
const GD_ENTRE_ALERTAS_MIN = 10;
const GD_MAX_ALERTAS = 3;
const GD_RADIO_LLEGADA_M = 150;
const GD_PING_CADA_MIN = 5;
const GD_MAX_MINUTOS = 300;
const GD_CIERRE_HORAS = 12;
const GD_VELOCIDAD_KMH: Record<string, number> = { caminando: 4.5, transporte: 15, auto: 28 };
const GD_MODOS: Record<string, string> = { auto: "en auto", transporte: "en transporte p\u00fablico", caminando: "caminando" };

type GdViaje = {
  id: string; ownerEmail: string; destino: string; destLat: number | null; destLng: number | null; modo: string;
  estimadoMin: number; startedAt: string; deadlineAt: string; extensiones: number; estado: string;
  avisoAt: string | null; alertas: number; lastAlertAt: string | null; llegadaAt: string | null; pingAt: string | null; endedAt: string | null;
};

const GD_COLUMNAS = "id,owner_email AS ownerEmail,destino,dest_lat AS destLat,dest_lng AS destLng,modo,estimado_min AS estimadoMin,started_at AS startedAt,deadline_at AS deadlineAt,extensiones,estado,aviso_at AS avisoAt,alertas,last_alert_at AS lastAlertAt,llegada_at AS llegadaAt,ping_at AS pingAt,ended_at AS endedAt";

/** Minutos que se calculan para ir de un punto a otro (distancia por calles ~30 % m\u00e1s larga que en l\u00ednea recta; el transporte suma 5 min de espera). */
function gdEstimar(km: number, modo: string) {
  const v = GD_VELOCIDAD_KMH[modo] ?? GD_VELOCIDAD_KMH.auto;
  const espera = modo === "transporte" ? 5 : 0;
  return Math.min(GD_MAX_MINUTOS, Math.max(3, Math.ceil((km * 1.3 / v) * 60 + espera)));
}

async function gdActivo(env: Env, email: string) {
  return env.DB.prepare(`SELECT ${GD_COLUMNAS} FROM gd_viajes WHERE owner_email=? AND estado IN (''en_camino'',''aviso'',''alerta'') ORDER BY started_at DESC LIMIT 1`).bind(email).first<GdViaje>();
}

async function gdPorId(env: Env, id: string) {
  return env.DB.prepare(`SELECT ${GD_COLUMNAS} FROM gd_viajes WHERE id=?`).bind(id).first<GdViaje>();
}

async function gdToken(env: Env, v: { id: string; startedAt: string }) {
  return `${v.id}.${await pldFirma(env, "gd", v.id, v.startedAt)}`;
}

async function gdPorToken(env: Env, token: unknown) {
  const [id, firma] = String(token ?? "").split(".");
  if (!id || !firma || id.length > 40 || firma.length > 80) return null;
  const v = await gdPorId(env, id);
  if (!v) return null;
  return pldIgual(firma, await pldFirma(env, "gd", v.id, v.startedAt)) ? v : null;
}

async function gdEnlace(env: Env, v: { id: string; startedAt: string }) {
  return `${pldOrigen(env)}/camino?t=${await gdToken(env, v)}`;
}

function gdHora(iso: string | null) {
  if (!iso) return "";
  try {
    return new Intl.DateTimeFormat("es-AR", { timeZone: "America/Argentina/Buenos_Aires", hour: "2-digit", minute: "2-digit", hourCycle: "h23" }).format(new Date(iso));
  } catch {
    return iso;
  }
}

/** Cu\u00e1ndo termin\u00f3 el camino respecto del l\u00edmite: minutos antes (negativo) o despu\u00e9s (positivo) de la hora prevista, y cu\u00e1nto dur\u00f3. */
function gdFin(v: GdViaje) {
  if (!v.endedAt) return null;
  const fin = Date.parse(v.endedAt), limite = Date.parse(v.deadlineAt), inicio = Date.parse(v.startedAt);
  const total = Math.round((limite - inicio) / 60000);
  return {
    hora: gdHora(v.endedAt), limiteHora: gdHora(v.deadlineAt), despuesMin: Math.round((fin - limite) / 60000),
    duracionMin: Math.max(0, Math.round((fin - inicio) / 60000)), extraMin: Math.max(0, total - v.estimadoMin - GD_MARGEN_MIN),
  };
}

function gdDemoraTexto(despuesMin: number, limiteHora: string) {
  if (despuesMin === 0) return `justo en el l\u00edmite (${limiteHora})`;
  const n = Math.abs(despuesMin);
  return `${n} ${n === 1 ? "minuto" : "minutos"} ${despuesMin < 0 ? "antes" : "despu\u00e9s"} del l\u00edmite (${limiteHora})`;
}

async function gdPresentar(env: Env, v: GdViaje) {
  return {
    fin: gdFin(v),
    id: v.id, destino: v.destino, modo: v.modo, modoTexto: GD_MODOS[v.modo] ?? v.modo, estado: v.estado, estimadoMin: v.estimadoMin, margenMin: GD_MARGEN_MIN,
    startedAt: v.startedAt, deadlineAt: v.deadlineAt, extensiones: v.extensiones, extensionesMax: GD_MAX_EXTENSIONES, alertas: v.alertas,
    puedeExtender: (v.estado === "en_camino" || v.estado === "aviso") && v.extensiones < GD_MAX_EXTENSIONES, opcionesExtender: GD_EXTENSIONES,
    enlace: await gdEnlace(env, v),
  };
}

/** D\u00f3nde est\u00e1 el tel\u00e9fono de la persona ahora (lo \u00faltimo que se sabe). */
async function gdUbicacion(env: Env, email: string) {
  const cfg = await pldLeerConfig(env, email);
  return pldEvaluar(env, email, { ...cfg, enabled: true, pausedUntil: null }, false);
}

/** Les cuenta a los referentes que lleg\u00f3 bien (solo si ya se les hab\u00eda avisado). */
async function gdAvisarLlego(env: Env, v: GdViaje, motivo: string) {
  if (v.alertas <= 0) return 0;
  const cfg = await pldLeerConfig(env, v.ownerEmail);
  const quien = pldNombreDe(v.ownerEmail, cfg);
  let enviados = 0;
  for (const x of await pldReferentesActivos(env, v.ownerEmail)) {
    const ok = await pldCorreo(
      env, x.email, `${quien} est\u00e1 bien`,
      `<p style="font-size:20px;font-weight:700;margin:0 0 14px">Hola ${escapeHtml(x.name)},</p><p style="color:#d2d2ce;line-height:1.55"><strong style="color:#fff">${escapeHtml(quien)}</strong> ${escapeHtml(motivo)} Ya no hace falta que hagas nada.</p>`,
    );
    if (ok) enviados++;
  }
  if (enviados > 0) await pldRegistrar(env, v.ownerEmail, null, "guardian", `Se les avis\u00f3 a tus referentes que est\u00e1s bien (camino a ${v.destino}).`);
  return enviados;
}

/** El aviso a los referentes cuando no lleg\u00f3 a tiempo. */
async function gdAvisarReferentes(env: Env, v: GdViaje, numero: number) {
  const cfg = await pldLeerConfig(env, v.ownerEmail);
  const quien = pldNombreDe(v.ownerEmail, cfg);
  const ub = await gdUbicacion(env, v.ownerEmail);
  const u = ub.ubicacion;
  const tarde = Math.max(0, Math.round((Date.now() - Date.parse(v.deadlineAt)) / 60000));
  const origen = pldOrigen(env);
  let enviados = 0;
  for (const x of await pldReferentesActivos(env, v.ownerEmail)) {
    const enlace = await pldEnlaceReferente(env, origen, x);
    const ok = await pldCorreo(
      env, x.email, `${quien} no lleg\u00f3 a ${v.destino} a la hora prevista`,
      `<p style="font-size:20px;font-weight:700;margin:0 0 14px">Hola ${escapeHtml(x.name)},</p>`
      + `<p style="color:#d2d2ce;line-height:1.55"><strong style="color:#fff">${escapeHtml(quien)}</strong> activ\u00f3 el Modo Guardi\u00e1n para ir a <strong style="color:#fff">${escapeHtml(v.destino)}</strong> ${escapeHtml(GD_MODOS[v.modo] ?? "")} y <strong style="color:#fff">no lleg\u00f3 a la hora prevista</strong> (${escapeHtml(gdHora(v.deadlineAt))}${tarde > 0 ? `, hace ${escapeHtml(pldTiempo(tarde))}` : ""}). No avis\u00f3 que estaba bien ni pidi\u00f3 m\u00e1s tiempo.</p>`
      + (u ? `<p style="color:#d2d2ce;line-height:1.55">\u00daltima ubicaci\u00f3n${ub.ultimaVez ? ` (${escapeHtml(pldFechaHora(ub.ultimaVez))})` : ""}: ${u.address ? escapeHtml(u.address) : `${u.lat.toFixed(5)}, ${u.lng.toFixed(5)}`}</p>${pldBoton(`https://www.google.com/maps?q=${u.lat},${u.lng}`, "Abrir en el mapa")}` : `<p style="color:#d2d2ce;line-height:1.55">Todav\u00eda no tenemos una ubicaci\u00f3n de su tel\u00e9fono.</p>`)
      + `<p style="color:#d2d2ce;line-height:1.55">Prob\u00e1 comunicarte con ${escapeHtml(quien)} ahora. Si no logr\u00e1s hablar y es grave, llam\u00e1 al 911 y mostrales esta ubicaci\u00f3n.</p>`
      + `<p style="color:#8f8d85;font-size:13px;line-height:1.5">Tambi\u00e9n pod\u00e9s ver su \u00faltima se\u00f1al desde tu enlace personal (aviso ${numero} de ${GD_MAX_ALERTAS} como m\u00e1ximo):</p>`
      + pldBoton(enlace, "Ver su \u00faltima se\u00f1al") + pldEnlaceEscrito(enlace),
    );
    if (ok) {
      enviados++;
      await pldRegistrar(env, v.ownerEmail, x.id, "guardian", `Se le avis\u00f3 a ${x.name} que no llegaste a ${v.destino} a tiempo (aviso ${numero}).`);
    }
  }
  if (enviados === 0) await pldRegistrar(env, v.ownerEmail, null, "guardian", "No llegaste a tiempo, pero no hay ning\u00fan referente activo a quien avisar.");
  return enviados;
}

/** El aviso a la persona: por mail (con el enlace a su camino) y en el tel\u00e9fono. */
async function gdAvisarPersona(env: Env, v: GdViaje, asunto: string, titulo: string, texto: string, textoBoton: string) {
  const enlace = await gdEnlace(env, v);
  await pldCorreo(
    env, v.ownerEmail, asunto,
    `<p style="font-size:20px;font-weight:700;margin:0 0 12px">${escapeHtml(titulo)}</p><p style="color:#d2d2ce;line-height:1.55">${texto}</p>${pldBoton(enlace, textoBoton)}${pldEnlaceEscrito(enlace)}`,
  );
  const ub = await gdUbicacion(env, v.ownerEmail);
  if (ub.pushToken) await sendExpoNotice(ub.pushToken, titulo, texto.replace(/<[^>]+>/g, ""), { data: { tipo: "guardian", url: enlace } }).catch(() => false);
}

/** Un paso del reloj de un camino (lo llama el cron cada minuto). */
async function gdAvanzar(env: Env, v: GdViaje) {
  const ahora = Date.now();
  if (ahora - Date.parse(v.startedAt) > GD_CIERRE_HORAS * 3_600_000) {
    await env.DB.prepare("UPDATE gd_viajes SET estado=''cerrado'',ended_at=?,motivo_fin=''expiro'' WHERE id=?").bind(now(), v.id).run();
    await pldRegistrar(env, v.ownerEmail, null, "guardian", `El camino a ${v.destino} se cerr\u00f3 solo despu\u00e9s de ${GD_CIERRE_HORAS} horas.`);
    return;
  }
  const ub = await gdUbicacion(env, v.ownerEmail);
  // seguimiento: se le pide al tel\u00e9fono una ubicaci\u00f3n nueva cada pocos minutos (en iPhone no despierta la app: sirve lo que la app reporte sola)
  if (ub.deviceId && ub.pushToken && ub.plataforma !== "ios" && (!v.pingAt || ahora - Date.parse(v.pingAt) >= GD_PING_CADA_MIN * 60_000)) {
    await queueAutoLocateCommand(env, { id: ub.deviceId, ownerEmail: v.ownerEmail, pushToken: ub.pushToken }).catch(() => false);
    await env.DB.prepare("UPDATE gd_viajes SET ping_at=? WHERE id=?").bind(now(), v.id).run();
  }
  // llegada: el tel\u00e9fono est\u00e1 en el destino y la ubicaci\u00f3n es reciente
  if (v.estado !== "alerta" && !v.llegadaAt && v.destLat !== null && v.destLng !== null && ub.ubicacion && ub.minutosSinSenal !== null && ub.minutosSinSenal <= 10
    && pldDistanciaKm(ub.ubicacion.lat, ub.ubicacion.lng, v.destLat, v.destLng) * 1000 <= GD_RADIO_LLEGADA_M) {
    await env.DB.prepare("UPDATE gd_viajes SET llegada_at=? WHERE id=?").bind(now(), v.id).run();
    await gdAvisarPersona(env, { ...v, llegadaAt: now() }, "\u00bfLlegaste bien?", "\u00bfLlegaste bien?", `Parece que llegaste a <strong style="color:#fff">${escapeHtml(v.destino)}</strong>. Toc\u00e1 <em>Llegu\u00e9</em> para cerrar el camino. Si todav\u00eda no llegaste o necesit\u00e1s m\u00e1s tiempo, tambi\u00e9n pod\u00e9s extenderlo ah\u00ed.`, "Llegu\u00e9 / Necesito m\u00e1s tiempo");
    await pldRegistrar(env, v.ownerEmail, null, "guardian", `Tu tel\u00e9fono lleg\u00f3 a ${v.destino}: se te pregunt\u00f3 si llegaste bien.`);
  }
  const falta = (Date.parse(v.deadlineAt) - ahora) / 60000;
  if (v.estado === "en_camino" && falta <= GD_AVISO_ANTES_MIN && falta > 0) {
    await env.DB.prepare("UPDATE gd_viajes SET estado=''aviso'',aviso_at=? WHERE id=? AND estado=''en_camino''").bind(now(), v.id).run();
    await gdAvisarPersona(env, v, "\u00bfSegu\u00eds en camino?", "\u00bfSegu\u00eds en camino?", `Te quedan <strong style="color:#fff">${Math.max(1, Math.ceil(falta))} minutos</strong> para llegar a <strong style="color:#fff">${escapeHtml(v.destino)}</strong>. Si ya llegaste, toc\u00e1 <em>Llegu\u00e9</em>. Si necesit\u00e1s m\u00e1s tiempo, extendelo. Si no respond\u00e9s, les avisamos a tus referentes.`, "Llegu\u00e9 / Necesito m\u00e1s tiempo");
    await pldRegistrar(env, v.ownerEmail, null, "guardian", `Te quedan ${Math.max(1, Math.ceil(falta))} minutos: se te pregunt\u00f3 si segu\u00eds en camino.`);
    return;
  }
  if ((v.estado === "en_camino" || v.estado === "aviso") && falta <= 0) {
    const enviados = await gdAvisarReferentes(env, v, 1);
    await env.DB.prepare("UPDATE gd_viajes SET estado=''alerta'',alertas=1,last_alert_at=? WHERE id=?").bind(now(), v.id).run();
    await gdAvisarPersona(env, { ...v, estado: "alerta" }, "Les avisamos a tus referentes", "Les avisamos a tus referentes", `No llegaste a <strong style="color:#fff">${escapeHtml(v.destino)}</strong> a la hora prevista${enviados > 0 ? " y les avisamos a tus referentes" : ""}. Si est\u00e1s bien, toc\u00e1 <em>Llegu\u00e9</em> para avisarles.`, "Llegu\u00e9");
    return;
  }
  if (v.estado === "alerta" && v.alertas < GD_MAX_ALERTAS && v.lastAlertAt && ahora - Date.parse(v.lastAlertAt) >= GD_ENTRE_ALERTAS_MIN * 60_000) {
    const numero = v.alertas + 1;
    await gdAvisarReferentes(env, v, numero);
    await env.DB.prepare("UPDATE gd_viajes SET alertas=?,last_alert_at=? WHERE id=?").bind(numero, now(), v.id).run();
  }
}

/** Cron de cada minuto: hace avanzar todos los caminos en marcha. */
async function gdCron(env: Env) {
  const lista = await env.DB.prepare(`SELECT ${GD_COLUMNAS} FROM gd_viajes WHERE estado IN (''en_camino'',''aviso'',''alerta'')`).all<GdViaje>();
  for (const v of lista.results ?? []) {
    try {
      await gdAvanzar(env, v);
    } catch (error) {
      console.error("gd_cron_failed", error);
    }
  }
}

/** El tiempo del camino seg\u00fan Google Mapas, con el tr\u00e1nsito de ahora (auto), a pie o en transporte p\u00fablico. Hace falta la clave GOOGLE_ROUTES_KEY (con la Routes API habilitada).
 *  Devuelve null si no hay clave, no hay ruta o Google no contesta: en ese caso se estima por la distancia o la persona pone los minutos. */
async function gdRutaMapas(env: Env, origen: { lat: number; lng: number }, destino: { lat: number; lng: number } | { texto: string }, modo: string) {
  const clave = String((env as unknown as Record<string, string | undefined>).GOOGLE_ROUTES_KEY ?? "");
  if (!clave) return null;
  const punto = (p: { lat: number; lng: number }) => ({ location: { latLng: { latitude: p.lat, longitude: p.lng } } });
  const cuerpo: Record<string, unknown> = {
    origin: punto(origen),
    destination: "texto" in destino ? { address: destino.texto } : punto(destino),
    travelMode: modo === "auto" ? "DRIVE" : modo === "caminando" ? "WALK" : "TRANSIT",
    languageCode: "es-AR",
    regionCode: "AR",
    units: "METRIC",
  };
  if (modo === "auto") cuerpo.routingPreference = "TRAFFIC_AWARE";
  try {
    const r = await fetch("https://routes.googleapis.com/directions/v2:computeRoutes", {
      method: "POST",
      headers: { "content-type": "application/json", "X-Goog-Api-Key": clave, "X-Goog-FieldMask": "routes.duration,routes.distanceMeters,routes.legs.endLocation" },
      body: JSON.stringify(cuerpo),
    });
    if (!r.ok) return null;
    const d = await r.json() as { routes?: Array<{ duration?: string; distanceMeters?: number; legs?: Array<{ endLocation?: { latLng?: { latitude?: number; longitude?: number } } }> }> };
    const ruta = d.routes?.[0];
    const segundos = Number(String(ruta?.duration ?? "").replace("s", ""));
    if (!ruta || !Number.isFinite(segundos) || segundos <= 0) return null;
    const fin = ruta.legs?.[ruta.legs.length - 1]?.endLocation?.latLng;
    return {
      minutos: Math.max(1, Math.ceil(segundos / 60)),
      km: Math.round((Number(ruta.distanceMeters) || 0) / 100) / 10,
      destLat: Number.isFinite(Number(fin?.latitude)) ? Number(fin?.latitude) : null,
      destLng: Number.isFinite(Number(fin?.longitude)) ? Number(fin?.longitude) : null,
    };
  } catch {
    return null;
  }
}

type GdDestino = { destino: string; destLat: number | null; destLng: number | null; texto: string | null };

/** A d\u00f3nde va: uno de sus Lugares o una direcci\u00f3n escrita. */
async function gdDestino(env: Env, email: string, cuerpo: Record<string, unknown>): Promise<GdDestino | { error: string; status: number }> {
  if (cuerpo.lugarId) {
    const lugar = await env.DB.prepare("SELECT name,latitude,longitude FROM family_places WHERE id=? AND owner_email=?").bind(String(cuerpo.lugarId), email).first<{ name: string; latitude: number; longitude: number }>();
    if (!lugar) return { error: "lugar_invalido", status: 400 };
    return { destino: String(lugar.name).slice(0, 80), destLat: Number(lugar.latitude), destLng: Number(lugar.longitude), texto: null };
  }
  const texto = String(cuerpo.texto ?? "").trim().slice(0, 120);
  if (!texto) return { error: "falta_destino", status: 400 };
  return { destino: texto.slice(0, 80), destLat: null, destLng: null, texto };
}

/** Cu\u00e1nto tarda: primero Google Mapas (con el tr\u00e1nsito de ahora); si no se puede, la distancia en l\u00ednea recta cuando se sabe el destino. */
async function gdCalcular(env: Env, email: string, modo: string, d: GdDestino, origenPedido: unknown) {
  const ub = await gdUbicacion(env, email);
  const o = origenPedido as { lat?: unknown; lng?: unknown } | null;
  const origen = o && Number.isFinite(Number(o.lat)) && Number.isFinite(Number(o.lng)) && Math.abs(Number(o.lat)) <= 90 && Math.abs(Number(o.lng)) <= 180
    ? { lat: Number(o.lat), lng: Number(o.lng) }
    : ub.ubicacion ? { lat: ub.ubicacion.lat, lng: ub.ubicacion.lng } : null;
  if (!origen) return null;
  const mapas = await gdRutaMapas(env, origen, d.destLat !== null && d.destLng !== null ? { lat: d.destLat, lng: d.destLng } : { texto: d.texto ?? d.destino }, modo);
  if (mapas) return { ...mapas, fuente: "mapas" as const };
  if (d.destLat !== null && d.destLng !== null) {
    const km = pldDistanciaKm(origen.lat, origen.lng, d.destLat, d.destLng);
    return { minutos: gdEstimar(km, modo), km: Math.round(km * 10) / 10, destLat: d.destLat, destLng: d.destLng, fuente: "distancia" as const };
  }
  return null;
}

/** Empieza un camino. `cuerpo`: lugarId (de sus Lugares) o texto (otra direcci\u00f3n), modo y, si no se puede calcular, minutos. */
async function gdEmpezar(env: Env, email: string, cuerpo: Record<string, unknown>) {
  const modo = String(cuerpo.modo ?? "");
  if (!GD_MODOS[modo]) return { error: "modo_invalido", status: 400 };
  const previo = await gdActivo(env, email);
  if (previo) return { error: "ya_hay_camino", status: 409, viaje: await gdPresentar(env, previo) };
  if (!(await pldReferentesActivos(env, email)).length) return { error: "sin_referentes", status: 400 };
  const d = await gdDestino(env, email, cuerpo);
  if ("error" in d) return d;
  const ruta = await gdCalcular(env, email, modo, d, cuerpo.origen);
  if (ruta && ruta.fuente === "mapas" && ruta.minutos > GD_MAX_MINUTOS) return { error: "destino_muy_lejos", status: 400 };
  const propios = Number(cuerpo.minutos);
  let minutos: number, fuente: string;
  if (ruta && ruta.fuente === "mapas") { minutos = ruta.minutos; fuente = "calculado con mapas y el tr\u00e1nsito de ahora"; }
  else if (Number.isFinite(propios) && propios > 0) { minutos = propios; fuente = "tiempo que pusiste vos"; }
  else if (ruta) { minutos = ruta.minutos; fuente = "estimado por la distancia"; }
  else return { error: "faltan_minutos", status: 400 };
  const destino = d.destino;
  const destLat = d.destLat ?? ruta?.destLat ?? null, destLng = d.destLng ?? ruta?.destLng ?? null;
  minutos = Math.min(GD_MAX_MINUTOS, Math.max(1, Math.round(minutos)));
  const id = `gdv${pldSecreto().slice(0, 14)}`;
  const inicio = now();
  const limite = new Date(Date.now() + (minutos + GD_MARGEN_MIN) * 60_000).toISOString();
  await env.DB.prepare("INSERT INTO gd_viajes (id,owner_email,destino,dest_lat,dest_lng,modo,estimado_min,started_at,deadline_at,extensiones,estado,alertas) VALUES (?,?,?,?,?,?,?,?,?,0,''en_camino'',0)")
    .bind(id, email, destino, destLat, destLng, modo, minutos, inicio, limite).run();
  await pldRegistrar(env, email, null, "guardian", `Empezaste un camino a ${destino} ${GD_MODOS[modo]}: ${minutos} min (${fuente}) + ${GD_MARGEN_MIN} de margen (hasta las ${gdHora(limite)}).`);
  const v = (await gdPorId(env, id))!;
  return { ok: true, viaje: await gdPresentar(env, v) };
}

/** Llegu\u00e9 / Extender / Necesito ayuda / Cancelar. */
async function gdAccion(env: Env, v: GdViaje, accion: string, minutos: number) {
  const activo = v.estado === "en_camino" || v.estado === "aviso" || v.estado === "alerta";
  if (!activo) return { error: "camino_terminado", status: 409 };
  if (accion === "llegue" || (accion === "cancelar" && v.estado === "alerta")) {
    const fin = now();
    await env.DB.prepare("UPDATE gd_viajes SET estado=''llego'',ended_at=?,motivo_fin=''llegue'' WHERE id=?").bind(fin, v.id).run();
    const f = gdFin({ ...v, endedAt: fin })!;
    await pldRegistrar(env, v.ownerEmail, null, "guardian", `Llegaste bien a ${v.destino}: tocaste Llegu\u00e9 a las ${f.hora}, ${gdDemoraTexto(f.despuesMin, f.limiteHora)}.`);
    await gdAvisarLlego(env, v, `lleg\u00f3 bien a ${v.destino}: toc\u00f3 Llegu\u00e9 a las ${f.hora}, ${gdDemoraTexto(f.despuesMin, f.limiteHora)}.`);
    return { ok: true, estado: "llego" };
  }
  if (accion === "cancelar") {
    await env.DB.prepare("UPDATE gd_viajes SET estado=''cancelado'',ended_at=?,motivo_fin=''cancelado'' WHERE id=?").bind(now(), v.id).run();
    await pldRegistrar(env, v.ownerEmail, null, "guardian", `Cancelaste el camino a ${v.destino}.`);
    return { ok: true, estado: "cancelado" };
  }
  if (accion === "extender") {
    if (v.estado === "alerta") return { error: "ya_se_aviso", status: 409 };
    if (!GD_EXTENSIONES.includes(minutos)) return { error: "minutos_invalidos", status: 400 };
    if (v.extensiones >= GD_MAX_EXTENSIONES) return { error: "demasiadas_extensiones", status: 409 };
    const base = Math.max(Date.parse(v.deadlineAt), Date.now());
    const limite = new Date(base + minutos * 60_000).toISOString();
    await env.DB.prepare("UPDATE gd_viajes SET deadline_at=?,extensiones=extensiones+1,estado=''en_camino'',aviso_at=NULL WHERE id=?").bind(limite, v.id).run();
    await pldRegistrar(env, v.ownerEmail, null, "guardian", `Pediste ${minutos} minutos m\u00e1s para llegar a ${v.destino} (hasta las ${gdHora(limite)}).`);
    return { ok: true, estado: "en_camino" };
  }
  if (accion === "ayuda") {
    const ub = await gdUbicacion(env, v.ownerEmail);
    const enviados = await pldAvisarSos(env, v.ownerEmail, ub.ubicacion ? { latitude: ub.ubicacion.lat, longitude: ub.ubicacion.lng, address: ub.ubicacion.address } : null);
    await env.DB.prepare("UPDATE gd_viajes SET estado=''alerta'',alertas=?,last_alert_at=? WHERE id=?").bind(GD_MAX_ALERTAS, now(), v.id).run();
    await pldRegistrar(env, v.ownerEmail, null, "guardian", `Pediste ayuda en el camino a ${v.destino}: se les avis\u00f3 a ${enviados} referentes.`);
    return { ok: true, estado: "alerta", avisados: enviados };
  }
  return { error: "accion_desconocida", status: 400 };
}

/** API del Modo Guardi\u00e1n. Con `t` (el enlace de la persona) o con la sesi\u00f3n del panel. */
async function gdApi(request: Request, env: Env) {
  if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const cuerpo = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const accion = String(cuerpo.accion ?? "estado");
  let viaje: GdViaje | null = null;
  let email = "";
  if (cuerpo.t) {
    viaje = await gdPorToken(env, cuerpo.t);
    if (!viaje) return json({ error: "enlace_invalido" }, 404);
    email = viaje.ownerEmail;
  } else {
    const sesion = await readSessionInfo(request, env.SESSION_SECRET);
    if (!sesion) return json({ error: "unauthorized" }, 401);
    if (sesion.method === "emergency") return json({ error: "not_allowed_in_emergency" }, 403);
    email = sesion.email;
    if (accion === "empezar") {
      const r = await gdEmpezar(env, email, cuerpo);
      return json("error" in r ? { error: r.error, ...("viaje" in r ? { viaje: r.viaje } : {}) } : r, "error" in r ? r.status : 200);
    }
    if (accion === "estimar") {
      const modo = String(cuerpo.modo ?? "auto");
      if (!GD_MODOS[modo]) return json({ error: "modo_invalido" }, 400);
      const d = await gdDestino(env, email, cuerpo);
      if ("error" in d) return json({ ok: true, minutos: null, km: null, fuente: null, error: d.error });
      const ruta = await gdCalcular(env, email, modo, d, cuerpo.origen);
      if (!ruta) return json({ ok: true, minutos: null, km: null, fuente: null });
      if (ruta.fuente === "mapas" && ruta.minutos > GD_MAX_MINUTOS) return json({ ok: true, minutos: null, km: ruta.km, fuente: "mapas", error: "destino_muy_lejos" });
      return json({ ok: true, minutos: ruta.minutos, km: ruta.km, fuente: ruta.fuente, editable: ruta.fuente !== "mapas" });
    }
    viaje = await gdActivo(env, email);
  }
  if (accion === "estado") {
    const lugares = cuerpo.t ? [] : ((await env.DB.prepare("SELECT id,name FROM family_places WHERE owner_email=? ORDER BY name ASC").bind(email).all<{ id: string; name: string }>()).results ?? []);
    return json({ ok: true, ahora: now(), viaje: viaje ? await gdPresentar(env, viaje) : null, lugares, referentes: (await pldReferentesActivos(env, email)).length });
  }
  if (!viaje) return json({ error: "no_hay_camino" }, 404);
  const r = await gdAccion(env, viaje, accion, Number(cuerpo.minutos));
  if ("error" in r) return json({ error: r.error }, r.status);
  const nuevo = await gdPorId(env, viaje.id);
  return json({ ...r, ahora: now(), viaje: nuevo ? await gdPresentar(env, nuevo) : null });
}

const PLD_ESTILO = `<style>*{box-sizing:border-box}body{margin:0;min-height:100vh;background:#0b0c0e;color:#f3f1ea;font-family:system-ui,-apple-system,Segoe UI,sans-serif;padding:22px 16px 60px}main{max-width:560px;margin:0 auto}img.logo{display:block;height:34px;margin:6px 0 18px}h1{font-size:1.5rem;margin:.2rem 0 .5rem}h2{font-size:1.05rem;margin:0 0 10px}p{color:#d2d2ce;line-height:1.55}small,.suave{color:#a29e92}.etiqueta{display:inline-block;font:700 .68rem/1 ui-monospace,Menlo,monospace;letter-spacing:.08em;color:#ffb400;border:1px solid #4a3f1f;border-radius:6px;padding:5px 8px;margin:0 0 12px}.tarjeta{background:#14151a;border:1px solid #2a2c31;border-radius:18px;padding:16px;margin:14px 0}label{display:block;margin:10px 0 4px;font-size:.88rem;color:#a29e92}input,select{width:100%;background:#0b0c0e;color:#f3f1ea;border:1px solid #2a2c31;border-radius:12px;padding:11px 12px;font:inherit}button,.boton{display:inline-block;background:#d9b24c;color:#111;border:0;border-radius:12px;padding:12px 18px;font:700 1rem system-ui;cursor:pointer;text-decoration:none}button.sec{background:#211d12;color:#f0c75a;border:1px solid #4a3f1f}button.chico{padding:7px 12px;font-size:.85rem}button.grande{width:100%;padding:18px;font-size:1.2rem}button:disabled{opacity:.55;cursor:wait}.fila{display:flex;flex-wrap:wrap;gap:10px;align-items:center;justify-content:space-between;padding:10px 0;border-top:1px solid #2a2c31}.botones{display:flex;flex-wrap:wrap;gap:10px;margin:12px 0}.botones.tres button{flex:1 1 0;padding:12px 6px;font-size:.95rem}.fila:first-child{border-top:0}.dos{display:grid;grid-template-columns:1fr 1fr;gap:10px}.ok{color:#57d48a}.mal{color:#e0806a}.pill{display:inline-block;border:1px solid #2a2c31;border-radius:999px;padding:4px 10px;margin:3px 4px 0 0;font-size:.82rem}.pill.si{border-color:#4a3f1f;background:#211d12;color:#f0c75a}#aviso{min-height:1.2em;color:#f0c75a;margin:8px 0}details.tarjeta>summary{cursor:pointer;list-style:none;display:flex;gap:10px;align-items:center;justify-content:space-between}details.tarjeta>summary::-webkit-details-marker{display:none}details.tarjeta>summary h2{margin:0;display:inline}details.tarjeta>summary::after{content:"Abrir";color:#f0c75a;font-size:.85rem;border:1px solid #4a3f1f;border-radius:999px;padding:4px 12px;white-space:nowrap}details.tarjeta[open]>summary::after{content:"Cerrar"}details.tarjeta[open]>summary{margin-bottom:10px}</style>`;

function pldPagina(titulo: string, cuerpo: string) {
  const html = `<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex"><title>${titulo}</title>${PLD_ESTILO}</head><body><main><img class="logo" src="/marca/logo-correo.png" alt="ojo guard"><span class="etiqueta">N\u00daCLEO \u00b7 EN VALIDACI\u00d3N</span>${cuerpo}</main></body></html>`;
  return new Response(html, { headers: { "content-type": "text/html; charset=utf-8", "cache-control": "no-store", "referrer-policy": "no-referrer" } });
}

/** P\u00e1gina del camino (/camino?t=...): la abre la persona desde el mail, el aviso o su panel. No necesita sesi\u00f3n: el enlace es personal. */
function gdPaginaCamino() {
  return pldPagina("Tu camino \u00b7 Ojo Guard", `
<h1 id="titulo">Tu camino</h1>
<div id="aviso"></div>
<div id="vacio" class="tarjeta" style="display:none"><p style="margin:0">Este enlace no sirve: est\u00e1 mal copiado o el camino ya no existe. Abr\u00ed el Modo Guardi\u00e1n desde tu panel para empezar uno nuevo.</p></div>
<div id="viaje" style="display:none">
<div class="tarjeta"><div id="destino" style="font-weight:700;font-size:1.15rem"></div><div id="detalle" class="suave"></div>
<div id="reloj" style="font-size:2.6rem;font-weight:800;margin:14px 0 4px"></div><div id="estadoTxt"></div></div>
<div class="tarjeta" id="acciones">
<button class="grande" id="bLlegue">Llegu\u00e9</button>
<p class="suave" style="margin:16px 0 4px">\u00bfNecesit\u00e1s m\u00e1s tiempo?</p>
<div class="botones tres" style="margin-top:6px"><button class="sec" data-m="10">+10 min</button><button class="sec" data-m="20">+20 min</button><button class="sec" data-m="30">+30 min</button></div>
<div class="botones"><button class="sec" id="bAyuda" style="border-color:#e0806a;color:#e0806a">Necesito ayuda</button><button class="sec" id="bCancelar">Cancelar camino</button></div>
<small class="suave">Si no lleg\u00e1s a tiempo y no ped\u00eds m\u00e1s tiempo, les avisamos a tus referentes con tu \u00faltima ubicaci\u00f3n. \u201cNecesito ayuda\u201d les avisa ahora mismo.</small>
</div>
<div class="tarjeta" id="sonidoCard"><div class="botones" style="margin-top:0"><button class="sec" id="bSonido">Sonido: activado</button></div><small class="suave" id="sonidoTxt"></small></div>
</div>
<script>
(function(){
var $=function(i){return document.getElementById(i)};
var t=new URLSearchParams(location.search).get("t")||"";
var V=null,desfase=0,ultimoLimite="",ultimoPitido=0,sonoFinal=false,luz=null,AC=null;
var SONIDO=true;try{SONIDO=localStorage.getItem("gdSonido")!=="0"}catch(e){}
function audio(){try{if(!AC){var C=window.AudioContext||window.webkitAudioContext;if(C)AC=new C()}if(AC&&AC.state==="suspended")AC.resume()}catch(e){}return AC}
function pitido(largo){var a=audio();if(!a||a.state!=="running")return false;try{var o=a.createOscillator(),g=a.createGain();o.type="square";o.frequency.value=largo?660:1000;g.gain.value=0.15;o.connect(g);g.connect(a.destination);o.start();o.stop(a.currentTime+(largo?0.9:0.09));if(navigator.vibrate)navigator.vibrate(largo?600:80)}catch(e){}return true}
function estadoSonido(){$("bSonido").textContent=SONIDO?"Sonido: activado":"Sonido: apagado";var a=AC;$("sonidoTxt").textContent=SONIDO?("En los \u00faltimos 15 segundos suena un pip por segundo para que no se te pase. La pantalla tiene que estar abierta"+(a&&a.state==="running"?".":" y tocarla una vez para habilitar el sonido.")):"Los pitidos de los \u00faltimos 15 segundos est\u00e1n apagados."}
function pantallaEncendida(){try{if(!luz&&navigator.wakeLock&&document.visibilityState==="visible"&&V&&(V.estado==="en_camino"||V.estado==="aviso")){navigator.wakeLock.request("screen").then(function(l){luz=l;l.addEventListener("release",function(){luz=null})}).catch(function(){})}}catch(e){}}
["pointerdown","touchstart","keydown"].forEach(function(e){document.addEventListener(e,function(){if(SONIDO)audio();estadoSonido()},{passive:true})});
document.addEventListener("visibilitychange",pantallaEncendida);
function aviso(x){$("aviso").textContent=x||""}
function api(c){c.t=t;return fetch("/api/guardian",{method:"POST",headers:{"content-type":"application/json"},body:JSON.stringify(c),credentials:"same-origin"}).then(function(r){return r.json().then(function(d){if(!r.ok){var e=new Error(d.error||"error");e.codigo=d.error;throw e}return d})})}
function hora(s){try{return new Date(s).toLocaleTimeString("es-AR",{timeZone:"America/Argentina/Buenos_Aires",hour:"2-digit",minute:"2-digit",hour12:false})}catch(e){return s}}
function reloj(ms){var s=Math.max(0,Math.floor(ms/1000));var h=Math.floor(s/3600),m=Math.floor((s%3600)/60),x=s%60;function d(n){return(n<10?"0":"")+n}return h>0?h+" h "+d(m)+" min":d(m)+":"+d(x)}
function pintar(d){
  V=d.viaje;desfase=Date.parse(d.ahora)-Date.now();
  if(!V){$("vacio").style.display="block";$("viaje").style.display="none";return}
  $("vacio").style.display="none";$("viaje").style.display="block";
  $("destino").textContent="Vas a "+V.destino;
  $("detalle").textContent=V.modoTexto.charAt(0).toUpperCase()+V.modoTexto.slice(1)+" \u00b7 "+V.estimadoMin+" min + "+V.margenMin+" de margen";
  var activo=V.estado==="en_camino"||V.estado==="aviso"||V.estado==="alerta";
  $("acciones").style.display=activo?"block":"none";
  var botones=document.querySelectorAll("button[data-m]");
  Array.prototype.forEach.call(botones,function(b){b.disabled=!V.puedeExtender});
  $("bCancelar").style.display=V.estado==="alerta"?"none":"inline-block";
  var tx={en_camino:"Ten\u00e9s que llegar antes de las "+hora(V.deadlineAt)+". Cuando llegues, toc\u00e1 Llegu\u00e9.",aviso:"\u00bfSegu\u00eds en camino? Si no respond\u00e9s, les avisamos a tus referentes.",alerta:"Ya les avisamos a tus referentes. Toc\u00e1 Llegu\u00e9 cuando est\u00e9s bien.",llego:"Llegaste bien. \u00a1Gracias por avisar!",cancelado:"Camino cancelado.",cerrado:"Este camino se cerr\u00f3 solo."}[V.estado]||"";
  var f=V.fin;
  if(V.estado==="llego"&&f){var n=Math.abs(f.despuesMin);tx="Tocaste Llegu\u00e9 a las "+f.hora+": "+(f.despuesMin===0?"justo en el l\u00edmite":n+(n===1?" minuto ":" minutos ")+(f.despuesMin<0?"antes":"despu\u00e9s")+" del l\u00edmite")+" ("+f.limiteHora+"). Tardaste "+f.duracionMin+" min; el c\u00e1lculo era de "+V.estimadoMin+" min + "+V.margenMin+" de margen"+(f.extraMin>0?" + "+f.extraMin+" que pediste":"")+"."}
  $("estadoTxt").textContent=tx;$("estadoTxt").className=V.estado==="alerta"?"mal":(V.estado==="llego"?"ok":"suave");
  if(V.deadlineAt!==ultimoLimite){ultimoLimite=V.deadlineAt;ultimoPitido=0;sonoFinal=false}
  $("sonidoCard").style.display=(V.estado==="en_camino"||V.estado==="aviso")?"block":"none";
  estadoSonido();pantallaEncendida();
  if(!activo&&luz){try{luz.release()}catch(e){}luz=null}
  tick();
}
function tick(){
  if(!V)return;
  var activo=V.estado==="en_camino"||V.estado==="aviso"||V.estado==="alerta";
  if(!activo){$("reloj").textContent=V.estado==="llego"?"Listo":"";return}
  var ms=Date.parse(V.deadlineAt)-(Date.now()+desfase);
  $("reloj").textContent=ms>0?reloj(ms):"Se pas\u00f3 el tiempo";
  if(SONIDO&&(V.estado==="en_camino"||V.estado==="aviso")){
    if(ms>0&&ms<=15000){var seg=Math.ceil(ms/1000);if(seg!==ultimoPitido){ultimoPitido=seg;pitido(false)}}
    else if(ms<=0&&!sonoFinal){sonoFinal=true;pitido(true)}
  }
}
function errorDe(e){return({ya_se_aviso:"Ya les avisamos a tus referentes: toc\u00e1 Llegu\u00e9 cuando est\u00e9s bien.",demasiadas_extensiones:"Ya extendiste el m\u00e1ximo de veces: toc\u00e1 Llegu\u00e9 o ped\u00ed ayuda.",enlace_invalido:"Este enlace no sirve.",camino_terminado:"Este camino ya termin\u00f3."})[e.codigo]||"No se pudo. Prob\u00e1 de nuevo."}
function hacer(c,ok){aviso("");return api(c).then(function(d){pintar(d);if(ok)aviso(ok)}).catch(function(e){aviso(errorDe(e))})}
$("bSonido").onclick=function(){SONIDO=!SONIDO;try{localStorage.setItem("gdSonido",SONIDO?"1":"0")}catch(e){}if(SONIDO)audio();estadoSonido()};
$("bLlegue").onclick=function(){hacer({accion:"llegue"},"Listo: avisamos que llegaste bien.")};
Array.prototype.forEach.call(document.querySelectorAll("button[data-m]"),function(b){b.onclick=function(){hacer({accion:"extender",minutos:Number(b.getAttribute("data-m"))},"Listo: ten\u00e9s "+b.getAttribute("data-m")+" minutos m\u00e1s.")}});
$("bAyuda").onclick=function(){if(confirm("\u00bfPedir ayuda? Les avisamos ahora mismo a tus referentes, con tu \u00faltima ubicaci\u00f3n."))hacer({accion:"ayuda"},"Les avisamos a tus referentes.")};
$("bCancelar").onclick=function(){if(confirm("\u00bfCancelar el camino? No se les avisa a tus referentes."))hacer({accion:"cancelar"},"Camino cancelado.")};
function refrescar(){api({accion:"estado"}).then(pintar).catch(function(e){if(e.codigo==="enlace_invalido"){$("vacio").style.display="block";$("viaje").style.display="none"}})}
refrescar();setInterval(refrescar,20000);setInterval(tick,1000);
})();
</script>`);
}

/** P\u00e1gina del due\u00f1o (/guardian y /por-las-dudas): tus referentes y los modos. */
function pldPaginaDuenio() {
  return pldPagina("Tu protecci\u00f3n \u00b7 Ojo Guard", `
<h1 id="titulo">Tu protecci\u00f3n</h1>
<p>Eleg\u00ed una vez a las personas de confianza, tus <b>referentes</b>: se enteran si algo te pasa. Valen para el SOS y para los modos de m\u00e1s abajo.</p>
<p class="suave">Esta funci\u00f3n est\u00e1 en validaci\u00f3n: ya la probamos de punta a punta con mails reales, pero todav\u00eda no en el d\u00eda a d\u00eda.</p>
<div id="aviso"></div>
<div id="sinSesion" class="tarjeta" style="display:none"><h2>Falta entrar al panel</h2><p>Para ver y cambiar tus referentes ten\u00e9s que entrar al panel de Ojo Guard MS con tu cuenta, <b>en este mismo navegador</b>. Entr\u00e1, y despu\u00e9s volv\u00e9 a esta p\u00e1gina.</p><p><a class="boton" href="/acceso-v7">Entrar al panel</a> <button class="sec" onclick="location.reload()">Ya entr\u00e9, probar de nuevo</button></p></div>
<div id="contenido" style="opacity:.4;pointer-events:none">
<div id="paraQuien" class="tarjeta" style="display:none"><label style="margin-top:0">Est\u00e1s viendo la protecci\u00f3n de</label><select id="persona"></select></div>
<div id="soloLectura" class="tarjeta" style="display:none"><p style="margin:0"><b>Esto lo completa el administrador de tu familia.</b> Ac\u00e1 pod\u00e9s ver c\u00f3mo est\u00e1 armada tu protecci\u00f3n, pero no cambiarla.</p></div>
<div id="enNombreDe" class="tarjeta" style="display:none"></div>
<div class="tarjeta"><h2>Tus referentes</h2><div id="referentes" class="suave">Cargando\u2026</div>
<label>Nombre</label><input id="rNombre" maxlength="60" placeholder="Mam\u00e1"><label>Correo</label><input id="rCorreo" type="email" placeholder="mama@correo.com">
<p><button id="rAgregar">Elegir referente</button></p><div id="invitacion"></div><small class="suave">Hasta 5. Le llega un mail con su enlace personal y tiene que aceptar. Si apret\u00e1s el SOS, tambi\u00e9n se les avisa a ellos.</small>
<p id="dondeBoton" class="suave"><b>\u00bfD\u00f3nde est\u00e1 el bot\u00f3n \u201cNo lo encuentro\u201d?</b> Lo ve solo tu referente, en su enlace personal, despu\u00e9s de aceptar. Vos no ten\u00e9s que apretar nada. Para probarlo, abr\u00ed su enlace en otro navegador (o en una ventana privada) y acept\u00e1.</p></div>
<h2 style="margin:28px 0 2px;font-size:1.3rem">Modo Cautela</h2>
<p class="suave" style="margin:0 0 6px">Por las dudas: si dejo de responder, mis referentes se enteran. Funciona de fondo y solo ven tu <b>\u00faltima se\u00f1al</b> si se cumplen las condiciones que vos permit\u00eds ac\u00e1.</p>
<div class="tarjeta"><h2>Pausar o apagar</h2><div id="estadoModo" class="suave"></div>
<p><b>Pausar los avisos</b> por un rato, por ejemplo si dorm\u00eds en otro lado. Cuando termina el tiempo, el Modo Cautela se prende solo. El SOS sigue avisando a tus referentes.</p>
<label>Pausar por</label><div class="botones tres" style="margin-top:6px"><button class="sec" data-h="8">8 horas</button><button class="sec" data-h="12">12 horas</button><button class="sec" data-h="24">24 horas</button></div>
<div class="dos"><div><label>Otro tiempo (horas, de 1 a 72)</label><input id="pHoras" type="number" min="1" max="72" placeholder="Ej.: 36"></div><div><label>&nbsp;</label><button class="sec" id="pOtro">Pausar ese tiempo</button></div></div>
<p><button class="sec" data-h="0">Quitar pausa</button></p><div id="pausa" class="suave"></div>
<p style="margin-top:18px"><b>Apagar el Modo Cautela</b> hasta que vos lo vuelvas a prender. Mientras est\u00e1 apagado no se manda ning\u00fan aviso autom\u00e1tico a tus referentes. El SOS sigue avisando.</p>
<p><button id="cEncender">Apagar Modo Cautela</button></p></div>
<details class="tarjeta" id="detHoy"><summary><span><h2>Estado de tu tel\u00e9fono</h2><small id="hoyResumen" class="suave" style="display:block;margin-top:2px"></small></span></summary><div id="hoy" class="suave">Cargando\u2026</div></details>
<details class="tarjeta" id="detCondiciones"><summary><h2>Condiciones</h2></summary><small class="suave">Un referente solo ve tu \u00faltima se\u00f1al si se cumplen al menos estas se\u00f1ales a la vez. Cuando se cumplen, te mandamos un \u201c\u00bfEst\u00e1s bien?\u201d (mail y aviso en el tel\u00e9fono) y, si en unos 15 minutos no respond\u00e9s, les avisamos a tus referentes por mail.</small>
<label>C\u00f3mo te llaman tus referentes</label><input id="cNombre" maxlength="60">
<div class="dos"><div><label>De noche desde (hora)</label><input id="cDesde" type="number" min="0" max="23"></div><div><label>hasta (hora)</label><input id="cHasta" type="number" min="0" max="23"></div></div>
<div class="dos"><div><label>Sin se\u00f1al de noche (min)</label><input id="cSilNoche" type="number" min="10"></div><div><label>Sin se\u00f1al de d\u00eda (min)</label><input id="cSilDia" type="number" min="10"></div></div>
<div class="dos"><div><label>Lejos de casa (km)</label><input id="cKm" type="number" min="0.5" step="0.5"></div><div><label>Bater\u00eda baja (%)</label><input id="cBat" type="number" min="1" max="50"></div></div>
<div class="dos"><div><label>Se\u00f1ales necesarias (de 4)</label><select id="cMin"><option>2</option><option>3</option><option>4</option></select></div><div><label>Emergencia tras (horas)</label><input id="cEmer" type="number" min="1" max="48"></div></div>
<div class="botones"><button id="cGuardar">Guardar condiciones</button><button class="sec" id="cCasa">Mi casa es donde est\u00e1 mi tel\u00e9fono ahora</button></div><div id="casa" class="suave"></div></details>
<div id="gdSeccion">
<h2 style="margin:28px 0 2px;font-size:1.3rem">Modo Guardi\u00e1n</h2>
<p class="suave" style="margin:0 0 6px">Te acompa\u00f1a en el camino: eleg\u00eds a d\u00f3nde vas y cu\u00e1nto tard\u00e1s, y si no lleg\u00e1s a tiempo les avisa a tus referentes con tu \u00faltima ubicaci\u00f3n.</p>
<div class="tarjeta" id="guardianCard"><div id="gdCarga" class="suave">Cargando\u2026</div>
<div id="gdActivo" style="display:none"><p id="gdActivoTxt" style="margin-top:0"></p><div class="botones"><a class="boton" id="gdAbrir" href="#">Abrir mi camino</a></div></div>
<div id="gdForm" style="display:none">
<label style="margin-top:0">A d\u00f3nde vas</label><select id="gdLugar"></select>
<div id="gdOtro" style="display:none"><label>Direcci\u00f3n o lugar</label><input id="gdTexto" maxlength="120" placeholder="Av. Cabildo 2040, Buenos Aires"></div>
<label>C\u00f3mo vas</label><select id="gdModo"><option value="auto">En auto</option><option value="transporte">En transporte p\u00fablico</option><option value="caminando">Caminando</option></select>
<label>Tiempo del camino, en minutos <span class="suave" id="gdAyudaMin"></span></label><input id="gdMin" type="number" min="1" max="300" placeholder="Ej.: 20">
<div class="botones"><button id="gdEmpezar">Empezar camino</button></div>
<small class="suave">Ten\u00e9s 2 minutos de margen. Si no lleg\u00e1s ni ped\u00eds m\u00e1s tiempo, les avisamos a tus referentes. Pod\u00e9s extender 10, 20 o 30 minutos, hasta 3 veces.</small>
</div>
<div id="gdSinRef" style="display:none"><p class="suave" style="margin:0">Para usar el Modo Guardi\u00e1n ten\u00e9s que tener al menos un referente que haya aceptado. Elegilo arriba, en \u201cTus referentes\u201d.</p></div>
</div>
</div>
<details class="tarjeta" id="detRegistro"><summary><h2>Registro</h2></summary><div id="registro" class="suave">Cargando\u2026</div></details>
</div>
<script>
(function(){
var $=function(i){return document.getElementById(i)};
var encendido=true;
var PERSONA=new URLSearchParams(location.search).get("persona")||"";
function aviso(t){$("aviso").textContent=t||""}
function api(cuerpo){return fetch("/api/remote/por-las-dudas"+(PERSONA?"?persona="+encodeURIComponent(PERSONA):""),{method:cuerpo?"POST":"GET",headers:{"content-type":"application/json"},body:cuerpo?JSON.stringify(cuerpo):undefined,credentials:"same-origin"}).then(function(r){return r.json().then(function(d){if(r.status===401){var er=new Error("Entr\u00e1 primero al panel de Ojo Guard MS con tu cuenta y volv\u00e9 a abrir esta p\u00e1gina.");er.sinSesion=true;throw er}if(!r.ok){throw new Error(({invalid_referente:"Revis\u00e1 el nombre y el correo.",referente_es_vos:"El referente no puede ser vos.",demasiados_referentes:"Ya ten\u00e9s 5 referentes.",referente_repetido:"Ese correo ya es referente.",sin_ubicacion:"Todav\u00eda no hay una ubicaci\u00f3n de tu tel\u00e9fono.",solo_administrador:"Esto lo completa el administrador de tu familia.",no_autorizado:"No ten\u00e9s permiso para armar la protecci\u00f3n de esa persona."})[d.error]||"No se pudo. Prob\u00e1 de nuevo.")}return d})})}
function fecha(s){if(!s)return"";try{return new Date(s).toLocaleString("es-AR",{timeZone:"America/Argentina/Buenos_Aires",day:"2-digit",month:"2-digit",hour:"2-digit",minute:"2-digit"})}catch(e){return s}}
function limpiar(n){while(n.firstChild)n.removeChild(n.firstChild)}
function texto(n,t){n.appendChild(document.createTextNode(t))}
function pintar(d){
  var h=$("hoy");limpiar(h);
  var rs=$("hoyResumen");rs.textContent=!d.hoy.hayDatos?"Sin datos todav\u00eda":(d.hoy.mostrar?"Con se\u00f1ales de alerta":"Todo tranquilo");rs.className=!d.hoy.hayDatos?"suave":(d.hoy.mostrar?"":"ok");rs.style.color=d.hoy.hayDatos&&d.hoy.mostrar?"#f0c75a":"";
  if(!d.hoy.hayDatos){texto(h,"Todav\u00eda no hay ninguna ubicaci\u00f3n de "+d.hoy.telefono+".")}else{
    texto(h,"Con lo que sabemos de "+d.hoy.telefono+", tus referentes "+(d.hoy.mostrar?"podr\u00edan ver tu \u00faltima se\u00f1al.":"no ver\u00edan nada ahora."));h.appendChild(document.createElement("br"));
    var pr=document.createElement("small");pr.textContent="Se cumplen "+d.hoy.cumplen+" de 4 se\u00f1ales (hacen falta "+d.config.minSignals+"):";h.appendChild(pr);h.appendChild(document.createElement("br"));
    d.hoy.senales.forEach(function(s){var p=document.createElement("span");p.className="pill"+(s.cumple?" si":"");p.textContent=s.texto;h.appendChild(p)});
    if(d.hoy.apagadoEnMovimiento){h.appendChild(document.createElement("br"));texto(h,"Tambi\u00e9n: dej\u00f3 de dar se\u00f1ales yendo en veh\u00edculo con bater\u00eda alta.")}
  }
  var r=$("referentes");limpiar(r);
  if(!d.referentes.length){texto(r,"Todav\u00eda no elegiste a nadie.")}
  d.referentes.forEach(function(x){
    var f=document.createElement("div");f.className="fila";var iz=document.createElement("div");
    var b=document.createElement("b");b.textContent=x.name;iz.appendChild(b);iz.appendChild(document.createElement("br"));
    var s=document.createElement("small");s.textContent=x.email+" \u00b7 "+(x.status==="aceptado"?"acept\u00f3":"esperando que acepte");s.className=x.status==="aceptado"?"ok":"suave";iz.appendChild(s);f.appendChild(iz);
    var dr=document.createElement("div");dr.className="botones";dr.style.margin="0";
    var ya=x.status==="aceptado";var re=document.createElement("button");re.className="sec chico";re.textContent=ya?"Mandar enlace de nuevo":"Reenviar";re.onclick=function(){accion({accion:"reenviar",id:x.id},ya?"Le mandamos su enlace de nuevo (es el mismo: el que ya tiene sigue sirviendo).":"Enlace reenviado.")};dr.appendChild(re);
    var qu=document.createElement("button");qu.className="sec chico";qu.textContent="Quitar";qu.onclick=function(){if(confirm("\u00bfQuitar a "+x.name+"?"))accion({accion:"quitar",id:x.id},"Referente quitado.")};dr.appendChild(qu);f.appendChild(dr);r.appendChild(f)});
  var c=d.config;$("cNombre").value=c.displayName||"";$("cDesde").value=c.nightFrom;$("cHasta").value=c.nightTo;$("cSilNoche").value=c.silenceNightMin;$("cSilDia").value=c.silenceDayMin;$("cKm").value=c.farKm;$("cBat").value=c.batteryPct;$("cMin").value=String(c.minSignals);$("cEmer").value=c.emergencyHours;encendido=!!c.enabled;
  $("casa").textContent=c.homeLat===null?"Todav\u00eda no marcaste d\u00f3nde est\u00e1 tu casa: sin eso, la se\u00f1al \u201clejos de casa\u201d no cuenta.":"Casa marcada ("+Number(c.homeLat).toFixed(4)+", "+Number(c.homeLng).toFixed(4)+").";
  var enPausa=!!(c.pausedUntil&&c.pausedUntil>new Date().toISOString());
  $("pausa").textContent=enPausa?"En pausa hasta "+fecha(c.pausedUntil):"Sin pausa.";
  var em=$("estadoModo");em.className=!c.enabled?"mal":(enPausa?"suave":"ok");
  em.textContent=!c.enabled?"Ahora: apagado. No se manda ning\u00fan aviso autom\u00e1tico.":(enPausa?"Ahora: encendido, pero en pausa hasta "+fecha(c.pausedUntil):"Ahora: encendido.");
  $("cEncender").textContent=c.enabled?"Apagar Modo Cautela":"Encender Modo Cautela";
  $("cEncender").className=c.enabled?"sec":"";
  var g=$("registro");limpiar(g);if(!d.registro.length){texto(g,"Todav\u00eda no hay nada.")}
  d.registro.forEach(function(x){var f=document.createElement("div");f.className="fila";var t=document.createElement("span");t.textContent=x.detail;var w=document.createElement("small");w.textContent=fecha(x.createdAt);w.className="suave";f.appendChild(t);f.appendChild(w);g.appendChild(f)});
  personaPantalla(d);
}
function personaPantalla(d){
  var pe=d.persona||{};var nom=pe.nombre||"esta persona";
  var sel=$("persona");limpiar(sel);
  if(d.personas&&d.personas.length){
    var o0=document.createElement("option");o0.value="";o0.textContent="Yo";sel.appendChild(o0);
    d.personas.forEach(function(x){var o=document.createElement("option");o.value=x.email;o.textContent=x.name||x.email;sel.appendChild(o)});
    sel.value=PERSONA;$("paraQuien").style.display="block";
  }else{$("paraQuien").style.display="none"}
  var nd=$("enNombreDe");
  if(pe.propia===false){nd.style.display="block";nd.textContent="Est\u00e1s armando la protecci\u00f3n de "+nom+". Los referentes que elijas son los de "+nom+": a cada uno le llega un mail para aceptar, y si "+nom+" aprieta el SOS tambi\u00e9n les avisamos.";$("titulo").textContent="Protecci\u00f3n de "+nom;$("cCasa").textContent="La casa de "+nom+" es donde est\u00e1 su tel\u00e9fono ahora"}
  else{nd.style.display="none";$("titulo").textContent="Tu protecci\u00f3n";$("cCasa").textContent="Mi casa es donde est\u00e1 mi tel\u00e9fono ahora"}
  $("gdSeccion").style.display=pe.propia===false?"none":"block";
  var ro=!!pe.soloLectura;$("soloLectura").style.display=ro?"block":"none";
  if(ro){Array.prototype.forEach.call(document.querySelectorAll("#contenido input,#contenido select,#contenido button"),function(e){if(!$("gdSeccion").contains(e))e.disabled=true})}
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
$("cGuardar").onclick=function(){accion({accion:"config",config:{displayName:$("cNombre").value,nightFrom:$("cDesde").value,nightTo:$("cHasta").value,silenceNightMin:$("cSilNoche").value,silenceDayMin:$("cSilDia").value,farKm:$("cKm").value,batteryPct:$("cBat").value,minSignals:$("cMin").value,emergencyHours:$("cEmer").value}},"Condiciones guardadas.")};
function gdPost(c){return fetch("/api/guardian",{method:"POST",headers:{"content-type":"application/json"},body:JSON.stringify(c),credentials:"same-origin"}).then(function(r){return r.json().then(function(d){return{ok:r.ok,d:d}})})}
function gdCargar(){return gdPost({accion:"estado"}).then(function(x){
  var d=x.d;$("gdCarga").style.display="none";
  if(!x.ok||!d.ok){$("gdCarga").style.display="block";$("gdCarga").textContent="No se pudo cargar el Modo Guardi\u00e1n.";return}
  if(d.viaje){$("gdForm").style.display="none";$("gdSinRef").style.display="none";$("gdActivo").style.display="block";$("gdActivoTxt").textContent="Hay un camino en marcha: vas a "+d.viaje.destino+".";$("gdAbrir").href=d.viaje.enlace;return}
  $("gdActivo").style.display="none";
  if(!d.referentes){$("gdForm").style.display="none";$("gdSinRef").style.display="block";return}
  $("gdSinRef").style.display="none";$("gdForm").style.display="block";
  var sel=$("gdLugar");limpiar(sel);
  d.lugares.forEach(function(l){var o=document.createElement("option");o.value=l.id;o.textContent=l.name;sel.appendChild(o)});
  var o2=document.createElement("option");o2.value="";o2.textContent="Otro lugar\u2026";sel.appendChild(o2);
  gdCambio();
}).catch(function(){$("gdCarga").style.display="block";$("gdCarga").textContent="No se pudo cargar el Modo Guardi\u00e1n."})}
function gdCambio(){
  var otro=!$("gdLugar").value;$("gdOtro").style.display=otro?"block":"none";$("gdAyudaMin").textContent="";
  var c={accion:"estimar",modo:$("gdModo").value};
  if(otro){var t=$("gdTexto").value.trim();if(!t){$("gdMin").readOnly=false;$("gdAyudaMin").textContent="(escrib\u00ed la direcci\u00f3n y sal\u00ed del casillero)";return}c.texto=t}else{c.lugarId=$("gdLugar").value}
  $("gdAyudaMin").textContent="(calculando con mapas\u2026)";
  gdPost(c).then(function(x){var d=x.d||{};
    if(x.ok&&d.minutos){$("gdMin").value=d.minutos;$("gdMin").readOnly=d.fuente==="mapas";$("gdAyudaMin").textContent=d.fuente==="mapas"?"(calculado con mapas y el tr\u00e1nsito de ahora)":"(estimado por la distancia: pod\u00e9s cambiarlo)"}
    else{$("gdMin").readOnly=false;$("gdAyudaMin").textContent=d.error==="destino_muy_lejos"?"(ese lugar queda a m\u00e1s de 5 horas: revis\u00e1 la direcci\u00f3n)":"(no pudimos calcularlo: pon\u00e9 cu\u00e1nto tard\u00e1s)"}
  }).catch(function(){$("gdMin").readOnly=false;$("gdAyudaMin").textContent="(no pudimos calcularlo: pon\u00e9 cu\u00e1nto tard\u00e1s)"})}
$("gdLugar").onchange=gdCambio;$("gdModo").onchange=gdCambio;$("gdTexto").onchange=gdCambio;
$("gdEmpezar").onclick=function(){var c={accion:"empezar",modo:$("gdModo").value,minutos:Number($("gdMin").value)||0};if($("gdLugar").value)c.lugarId=$("gdLugar").value;else c.texto=$("gdTexto").value;
  var enviar=function(){gdPost(c).then(function(x){if(x.ok&&x.d.viaje){location.href=x.d.viaje.enlace;return}aviso(({sin_referentes:"Primero eleg\u00ed un referente que haya aceptado.",ya_hay_camino:"Ya ten\u00e9s un camino en marcha.",falta_destino:"Escrib\u00ed a d\u00f3nde vas.",faltan_minutos:"Pon\u00e9 cu\u00e1ntos minutos tard\u00e1s.",lugar_invalido:"Ese lugar no existe.",modo_invalido:"Eleg\u00ed c\u00f3mo vas.",destino_muy_lejos:"Ese lugar queda a m\u00e1s de 5 horas: revis\u00e1 la direcci\u00f3n."})[x.d.error]||"No se pudo empezar el camino.")})};
  var hecho=false;var seguir=function(){if(!hecho){hecho=true;enviar()}};
  try{navigator.geolocation.getCurrentPosition(function(p){c.origen={lat:p.coords.latitude,lng:p.coords.longitude};seguir()},seguir,{timeout:4000,maximumAge:60000});setTimeout(seguir,4500)}catch(e){seguir()}};
$("persona").onchange=function(){location.search=this.value?"?persona="+encodeURIComponent(this.value):""};
$("cCasa").onclick=function(){accion({accion:"casa"},"Casa marcada.")};
Array.prototype.forEach.call(document.querySelectorAll("button[data-h]"),function(b){b.onclick=function(){accion({accion:"pausa",horas:Number(b.getAttribute("data-h"))},b.getAttribute("data-h")==="0"?"Pausa quitada.":"Pausa puesta por "+b.getAttribute("data-h")+" horas.")}});
$("pOtro").onclick=function(){var h=Number($("pHoras").value);if(!(h>=1&&h<=72)){aviso("Pon\u00e9 un n\u00famero de horas entre 1 y 72.");return}accion({accion:"pausa",horas:h},"Pausa puesta por "+h+(h===1?" hora.":" horas."))};
$("cEncender").onclick=function(){if(encendido&&!confirm("\u00bfApagar el Modo Cautela? Mientras est\u00e9 apagado no se manda ning\u00fan aviso autom\u00e1tico a tus referentes. El SOS sigue avisando. Si es por un rato, mejor us\u00e1 la pausa."))return;accion({accion:"config",config:{enabled:!encendido}},encendido?"Modo Cautela apagado.":"Modo Cautela encendido.")};
api().then(function(d){var c=$("contenido");c.style.opacity="";c.style.pointerEvents="";pintar(d);gdCargar()}).catch(function(e){if(e.sinSesion){aviso("");$("sinSesion").style.display="block";$("contenido").style.display="none"}else{aviso(e.message)}});
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
$esperado = $f.texto.Length - $viejo.Length + $nuevoBloque.Length
[System.IO.File]::WriteAllText($indice, $nuevo, (New-Object System.Text.UTF8Encoding($f.bom)))
$v = Leer $indice
$bien = ($v.texto.Length -eq $esperado) -and ((Contar $v.texto 'async function gdRutaMapas(') -eq 1) -and ((Contar $v.texto 'function gdFin(') -eq 1) -and ((Contar $v.texto 'async function gdCron(') -eq 1) -and ((Contar $v.texto 'route === "GET /camino"') -eq 1) -and ((Contar $v.texto 'async function pldResolverPersona(') -eq 1) -and ((Contar $v.texto 'Estado de tu tel') -eq 1) -and ((Contar $v.texto 'id="detCondiciones"') -eq 1) -and ((Contar $v.texto 'id="pOtro"') -eq 1) -and ((Contar $v.texto 'async function pldCerrarEpisodio(') -eq 1) -and ((Contar $v.texto 'route === "GET /guardian"') -eq 1) -and ((Contar $v.texto 'async function pldAvisarSos(') -eq 1) -and ((Contar $v.texto 'async function nativeFamilySos') -eq 1) -and ((Contar $v.texto 'async function fetchCorreo') -eq 1)
if (-not $bien) {
    Mal "Algo no salio bien. Restauro src\index.ts desde el respaldo."
    Copy-Item -LiteralPath ($indice + ".bak-pldmejoras") -Destination $indice -Force
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Ok ("src\index.ts: largo " + $v.texto.Length + " (esperado " + $esperado + ")")
Write-Host ""
Ok "Archivo listo. Ahora publico el panel..."
& npx.cmd wrangler deploy
if ($LASTEXITCODE -ne 0) { Mal "No se pudo publicar el panel. Mandame esta pantalla."; return }
Write-Host ""
Ok "LISTO: Guardian con tiempo de Google Mapas (cuando haya clave: npx wrangler secret put GOOGLE_ROUTES_KEY), pitidos al final y la demora al llegar. Abri /guardian con Ctrl+F5."
Write-Host ""
