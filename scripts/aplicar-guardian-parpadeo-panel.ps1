# aplicar-guardian-parpadeo-panel.ps1 - Modo Guardian: en los ultimos 15 segundos el reloj del camino parpadea en rojo (no depende del sonido).
# Luciano (20/10/2026): el pip pip pip de los ultimos 15 segundos no se escucho porque el telefono tenia unos auriculares Bluetooth conectados (el sonido salia por ahi). Una pagina web no puede forzar el parlante
# del telefono, asi que mientras llega la version de la app que lo haga: "me parece que suma tambien lo del parpadeo para los 15 segundos".
# Que cambia (solo la pantalla del camino):
#  - En los ultimos 15 segundos el reloj se pone rojo y parpadea (una vez por segundo), la tarjeta del reloj se marca en rojo y aparece "Se termina el tiempo: toca Llegue o pedi mas tiempo" (lo ultimo solo si se puede pedir
#    mas tiempo). Pasado el limite, el reloj queda rojo y quieto. Si el telefono tiene activado "reducir movimiento", no parpadea: queda rojo. El sonido y la vibracion siguen igual.
#  - Incluye todo lo de los parches anteriores de Guardian, lugares, Configuracion, recalculo por transito y pausa. Este los reemplaza: se puede correr encima de cualquiera de ellos.
# Reemplaza el codigo de Modo Cautela dentro de src\index.ts, comprobando antes con una huella SHA-256 que es el que dejaron los parches anteriores (acepta las veinte versiones). No toca nada mas del panel.
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Respaldo .bak-pldparpadeo. Al final publica el panel solo.
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
if ((Contar $f.texto 'id="finalTxt"') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $f.texto 'async function gdRutaMapas(') -ne 1) { Mal "Falta aplicar antes aplicar-guardian-mejoras-panel.ps1."; return }
$marcaIni = Ajustar '// ---------------------------------------------------------------------------
// "Modo Cautela" (antes "Por las dudas"; N\u00daCLEO \u00b7 EN VALIDACI\u00d3N): referentes de emergencia.' $f.crlf
$marcaFin = Ajustar 'async function fetchCorreo(input: string, init: RequestInit) {' $f.crlf
$huellasViejas = @("88d257c0bb656331b11ebc66c0f3521a884bd69fffa915a649cf143c0211d218", "a887fbf6bdbf1e85e4a223f5a4030a2e76d03a926b175bb25bf434da812c4e11", "e9d0a02cb9e148f97f2252c27b6ff6e255dd2c7691460711436024ca7eb3bc1c", "36cda30909fa54787b0e682833b526b4719fe9ad7c4bc4fdd3f510e149560ccd", "db1d0c40da359644ef62f03571f025a20e1935957c372430fe1848d945aee385", "905732ab1a69eaaeb7405cb0b5eab31fb0c970558761dcde20bf73808b582759", "85283ceb6c5b866c568093e2b33e3fda9454c1c4271a79951c4772142da076dd", "0c81f3e5789c0d0adfb413684025bdb4eba0b2607c6485aae6c891b4d061f328", "8ef511b2d13d6fd83a10324cef0957a1440069a4cb44789ac189687fdfdea086", "8caf8ec1e76564ee7b11a1f13f4183a7eb1812a81a7847a4270cb680332b754f", "450ac01b1e85bbcc4a065754c21abbc84e9e07c200d146dea0ce3413f2345d9a", "17d575d8937b1d4cd0aabeae342947043a209b60fd212ba026f780b92316217c", "512cfe3d7c2b3988534dfe2f722f99fd5ab50abaf6b6c6faa5fa31b7b60d00f0", "b976c0026e3c7b379bfbc11275c45d23d0a0661ec27fa3e97f47380f438e7f26", "8c7fa17c76c184d4800758649dc7f29132bed43e25a0204867846d33f4e432ba", "c287fc279d4df85ed98dd24929d76da96052e9deffbf56fb27a2938f98af25f5", "b66ebca4a1f4d502ae307f3bb2ebb1d7197243bf36e5832400c956da81ba18be", "fd39fc50f50ba957e6a3a6e6159dae7c6e1e2c659df8b7112355dc24abedfa76", "65787f3d87e7cb874e73bde5022c13f575747d05b6d5017bd47dd4ef6faf2515", "abc104785111176e9d541bb7f60e63cfccb530c5960c50b73eb90686cf8e0bab")
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
if (Test-Path ($indice + ".bak-pldparpadeo")) { Mal "Ya existe src\index.ts.bak-pldparpadeo. No toco nada."; return }
Copy-Item -LiteralPath $indice -Destination ($indice + ".bak-pldparpadeo")
Ok "Respaldo creado: src\index.ts.bak-pldparpadeo"
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
    defaults: PLD_POR_DEFECTO,
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
const GD_PARADAS = [15, 30, 60];
const GD_MAX_PARADAS = 2;
const GD_AJUSTE_AUTO_MAX_MIN = 60;
const GD_AJUSTE_CADA_MIN = 4;
const GD_AJUSTE_DESDE_MIN = 20;
const GD_AJUSTE_AVANCE_M = 100;
const GD_AJUSTE_MIN_ATRASO = 2;
const GD_UBICACION_RECIENTE_MIN = 10;
const GD_PAUSA_RESTA_MINIMA_MS = 60_000; // al seguir despues de una pausa siempre queda al menos un minuto
const GD_PRECISION_MAX_M = 5000; // una ubicacion del navegador mas imprecisa que esto (por ejemplo la de una computadora por su conexion) no sirve para calcular el camino
const GD_MODOS: Record<string, string> = { auto: "en auto", transporte: "en transporte p\u00fablico", caminando: "caminando" };

/** Lo que cada persona puede cambiar del Modo Guardi\u00e1n (Configuraci\u00f3n). Los valores recomendados son las constantes de arriba; cada cambio queda en gd_config. */
type GdConfig = { margenMin: number; avisoMin: number; maxExtensiones: number; entreAlertasMin: number; maxAlertas: number; autoAjusteMin: number };
const GD_POR_DEFECTO: GdConfig = { margenMin: GD_MARGEN_MIN, avisoMin: GD_AVISO_ANTES_MIN, maxExtensiones: GD_MAX_EXTENSIONES, entreAlertasMin: GD_ENTRE_ALERTAS_MIN, maxAlertas: GD_MAX_ALERTAS, autoAjusteMin: GD_AJUSTE_AUTO_MAX_MIN };
const GD_LIMITES: Record<keyof GdConfig, [number, number]> = { margenMin: [1, 15], avisoMin: [1, 10], maxExtensiones: [0, 5], entreAlertasMin: [5, 60], maxAlertas: [1, 5], autoAjusteMin: [0, 180] };
let gdTablaLista = false;

/** Agrega a una tabla de una instalacion anterior las columnas que le faltan (mira cuales tiene y solo agrega las que no estan). */
async function gdAgregarColumnas(env: Env, tabla: string, columnas: string[]) {
  let tiene = new Set<string>();
  try { tiene = new Set((((await env.DB.prepare(`PRAGMA table_info(${tabla})`).all<{ name: string }>()).results) ?? []).map((c) => String(c.name))); } catch { /* si no se puede mirar, se prueba con cada una */ }
  for (const definicion of columnas) {
    if (tiene.has(definicion.split(" ")[0])) continue;
    try { await env.DB.prepare(`ALTER TABLE ${tabla} ADD COLUMN ${definicion}`).run(); } catch { /* ya estaba */ }
  }
}

/** Las tablas se crean solas la primera vez que se usan, y si vienen de una instalacion anterior se les agregan las columnas nuevas (no hace falta tocar la base de datos al instalar). */
async function gdAsegurarTabla(env: Env) {
  if (gdTablaLista) return;
  await env.DB.prepare("CREATE TABLE IF NOT EXISTS gd_config (owner_email TEXT PRIMARY KEY, margen_min INTEGER, aviso_min INTEGER, max_ext INTEGER, entre_alertas_min INTEGER, max_alertas INTEGER, auto_max_min INTEGER, updated_at TEXT)").run();
  await gdAgregarColumnas(env, "gd_config", ["auto_max_min INTEGER"]);
  await env.DB.prepare("CREATE TABLE IF NOT EXISTS gd_progreso (viaje_id TEXT PRIMARY KEY, ref_lat REAL, ref_lng REAL, ref_at TEXT, recalc_at TEXT, auto_min INTEGER NOT NULL DEFAULT 0, paradas INTEGER NOT NULL DEFAULT 0, pausa_ini TEXT, pausa_hasta TEXT, resta_ms INTEGER, parada_min INTEGER NOT NULL DEFAULT 0, updated_at TEXT)").run();
  await gdAgregarColumnas(env, "gd_progreso", ["pausa_ini TEXT", "pausa_hasta TEXT", "resta_ms INTEGER", "parada_min INTEGER NOT NULL DEFAULT 0"]);
  gdTablaLista = true;
}

function gdConfigValida(c: Record<string, unknown>, base: GdConfig): GdConfig {
  const n = (k: keyof GdConfig) => (c[k] === undefined || c[k] === null || c[k] === "" ? base[k] : Math.round(pldNumero(c[k], GD_LIMITES[k][0], GD_LIMITES[k][1], base[k])));
  return { margenMin: n("margenMin"), avisoMin: n("avisoMin"), maxExtensiones: n("maxExtensiones"), entreAlertasMin: n("entreAlertasMin"), maxAlertas: n("maxAlertas"), autoAjusteMin: n("autoAjusteMin") };
}

async function gdLeerConfig(env: Env, email: string): Promise<GdConfig> {
  try {
    await gdAsegurarTabla(env);
    const f = await env.DB.prepare("SELECT margen_min AS margenMin,aviso_min AS avisoMin,max_ext AS maxExtensiones,entre_alertas_min AS entreAlertasMin,max_alertas AS maxAlertas,auto_max_min AS autoAjusteMin FROM gd_config WHERE owner_email=?").bind(email).first<Record<string, unknown>>();
    return f ? gdConfigValida(f, GD_POR_DEFECTO) : { ...GD_POR_DEFECTO };
  } catch {
    return { ...GD_POR_DEFECTO };
  }
}

async function gdGuardarConfig(env: Env, email: string, c: GdConfig) {
  await gdAsegurarTabla(env);
  await env.DB.prepare("INSERT INTO gd_config (owner_email,margen_min,aviso_min,max_ext,entre_alertas_min,max_alertas,auto_max_min,updated_at) VALUES (?,?,?,?,?,?,?,?) ON CONFLICT(owner_email) DO UPDATE SET margen_min=excluded.margen_min,aviso_min=excluded.aviso_min,max_ext=excluded.max_ext,entre_alertas_min=excluded.entre_alertas_min,max_alertas=excluded.max_alertas,auto_max_min=excluded.auto_max_min,updated_at=excluded.updated_at")
    .bind(email, c.margenMin, c.avisoMin, c.maxExtensiones, c.entreAlertasMin, c.maxAlertas, c.autoAjusteMin, now()).run();
}

/** Lo que se sabe de un camino mientras dura: la ultima muestra de ubicacion (para ver si se acerca), cuando se recalculo, cuantos minutos se sumaron solos por transito, cuantas paradas hizo y,
 *  si esta frenado, la pausa (desde cuando, hasta cuando y cuanto le quedaba para llegar, que es lo que el reloj retoma) y cuantos minutos estuvo frenado en total. */
type GdProgreso = { refLat: number | null; refLng: number | null; refAt: string | null; recalcAt: string | null; autoMin: number; paradas: number; pausaIni: string | null; pausaHasta: string | null; restaMs: number | null; paradaMin: number };
const GD_PROGRESO_VACIO: GdProgreso = { refLat: null, refLng: null, refAt: null, recalcAt: null, autoMin: 0, paradas: 0, pausaIni: null, pausaHasta: null, restaMs: null, paradaMin: 0 };

async function gdLeerProgreso(env: Env, id: string): Promise<GdProgreso> {
  try {
    await gdAsegurarTabla(env);
    const f = await env.DB.prepare("SELECT ref_lat AS refLat,ref_lng AS refLng,ref_at AS refAt,recalc_at AS recalcAt,auto_min AS autoMin,paradas,pausa_ini AS pausaIni,pausa_hasta AS pausaHasta,resta_ms AS restaMs,parada_min AS paradaMin FROM gd_progreso WHERE viaje_id=?").bind(id).first<Record<string, unknown>>();
    if (!f) return { ...GD_PROGRESO_VACIO };
    const num = (x: unknown) => (x === null || x === undefined ? null : Number.isFinite(Number(x)) ? Number(x) : null);
    return { refLat: num(f.refLat), refLng: num(f.refLng), refAt: f.refAt ? String(f.refAt) : null, recalcAt: f.recalcAt ? String(f.recalcAt) : null, autoMin: Math.max(0, Math.round(Number(f.autoMin) || 0)), paradas: Math.max(0, Math.round(Number(f.paradas) || 0)),
      pausaIni: f.pausaIni ? String(f.pausaIni) : null, pausaHasta: f.pausaHasta ? String(f.pausaHasta) : null, restaMs: num(f.restaMs), paradaMin: Math.max(0, Math.round(Number(f.paradaMin) || 0)) };
  } catch {
    return { ...GD_PROGRESO_VACIO };
  }
}

async function gdGuardarProgreso(env: Env, id: string, p: GdProgreso) {
  await gdAsegurarTabla(env);
  await env.DB.prepare("INSERT INTO gd_progreso (viaje_id,ref_lat,ref_lng,ref_at,recalc_at,auto_min,paradas,pausa_ini,pausa_hasta,resta_ms,parada_min,updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(viaje_id) DO UPDATE SET ref_lat=excluded.ref_lat,ref_lng=excluded.ref_lng,ref_at=excluded.ref_at,recalc_at=excluded.recalc_at,auto_min=excluded.auto_min,paradas=excluded.paradas,pausa_ini=excluded.pausa_ini,pausa_hasta=excluded.pausa_hasta,resta_ms=excluded.resta_ms,parada_min=excluded.parada_min,updated_at=excluded.updated_at")
    .bind(id, p.refLat, p.refLng, p.refAt, p.recalcAt, p.autoMin, p.paradas, p.pausaIni, p.pausaHasta, p.restaMs, p.paradaMin, now()).run();
}

/** Cierra la pausa de "Voy a frenar un rato": la persona toco "Ya sigo", se termino el tiempo que habia elegido o llego. Suma lo que duro a lo frenado y, si se corta antes de tiempo, el reloj
 *  sigue desde lo que le quedaba para llegar (si se termino sola, el limite ya estaba bien puesto: el fin de la pausa mas lo que quedaba). Despues de una pausa se vuelve a tomar la muestra de ubicacion. */
async function gdCerrarPausa(env: Env, v: GdViaje, p: GdProgreso, ahora: number): Promise<{ viaje: GdViaje; progreso: GdProgreso }> {
  if (!p.pausaHasta || !p.pausaIni) return { viaje: v, progreso: p };
  const hasta = Date.parse(p.pausaHasta);
  const usados = Math.max(0, Math.round((Math.min(ahora, hasta) - Date.parse(p.pausaIni)) / 60_000));
  let viaje = v;
  if (ahora < hasta) {
    const limite = new Date(ahora + Math.max(GD_PAUSA_RESTA_MINIMA_MS, p.restaMs ?? 0)).toISOString();
    await env.DB.prepare("UPDATE gd_viajes SET deadline_at=?,estado=''en_camino'',aviso_at=NULL WHERE id=?").bind(limite, v.id).run();
    viaje = { ...v, deadlineAt: limite, estado: "en_camino", avisoAt: null };
  }
  const progreso: GdProgreso = { ...p, pausaIni: null, pausaHasta: null, restaMs: null, paradaMin: p.paradaMin + usados, refLat: null, refLng: null, refAt: null };
  await gdGuardarProgreso(env, v.id, progreso);
  return { viaje, progreso };
}

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
function gdFin(v: GdViaje, margenMin = GD_MARGEN_MIN, autoMin = 0, paradaMin = 0) {
  if (!v.endedAt) return null;
  const fin = Date.parse(v.endedAt), limite = Date.parse(v.deadlineAt), inicio = Date.parse(v.startedAt);
  const total = Math.round((limite - inicio) / 60000);
  return {
    hora: gdHora(v.endedAt), limiteHora: gdHora(v.deadlineAt), despuesMin: Math.round((fin - limite) / 60000),
    duracionMin: Math.max(0, Math.round((fin - inicio) / 60000)), extraMin: Math.max(0, total - v.estimadoMin - margenMin - autoMin - paradaMin), autoMin, paradaMin,
  };
}

function gdDemoraTexto(despuesMin: number, limiteHora: string) {
  if (despuesMin === 0) return `justo en el l\u00edmite (${limiteHora})`;
  const n = Math.abs(despuesMin);
  return `${n} ${n === 1 ? "minuto" : "minutos"} ${despuesMin < 0 ? "antes" : "despu\u00e9s"} del l\u00edmite (${limiteHora})`;
}

async function gdPresentar(env: Env, v: GdViaje) {
  const g = await gdLeerConfig(env, v.ownerEmail);
  const pr = await gdLeerProgreso(env, v.id);
  const activo = v.estado === "en_camino" || v.estado === "aviso";
  const enPausa = activo && !!pr.pausaHasta && Date.now() < Date.parse(pr.pausaHasta);
  return {
    fin: gdFin(v, g.margenMin, pr.autoMin, pr.paradaMin),
    id: v.id, destino: v.destino, modo: v.modo, modoTexto: GD_MODOS[v.modo] ?? v.modo, estado: v.estado, estimadoMin: v.estimadoMin, margenMin: g.margenMin,
    startedAt: v.startedAt, deadlineAt: v.deadlineAt, extensiones: v.extensiones, extensionesMax: g.maxExtensiones, alertas: v.alertas,
    puedeExtender: activo && v.extensiones < g.maxExtensiones, opcionesExtender: GD_EXTENSIONES,
    ajusteAutoMin: pr.autoMin, pausa: enPausa ? { hasta: pr.pausaHasta, restaMs: pr.restaMs ?? 0 } : null, paradas: pr.paradas, paradasMax: g.maxExtensiones > 0 ? GD_MAX_PARADAS : 0, puedeParar: activo && g.maxExtensiones > 0 && pr.paradas < GD_MAX_PARADAS, opcionesParada: GD_PARADAS, puedeCambiar: activo, destinoExacto: v.destLat !== null && v.destLng !== null,
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
  const g = await gdLeerConfig(env, v.ownerEmail);
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
      + `<p style="color:#8f8d85;font-size:13px;line-height:1.5">Tambi\u00e9n pod\u00e9s ver su \u00faltima se\u00f1al desde tu enlace personal (aviso ${numero} de ${g.maxAlertas} como m\u00e1ximo):</p>`
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

/** Mientras el camino esta en marcha: si el telefono SE ESTA ACERCANDO al destino pero Google calcula que va a tardar mas de lo previsto (transito, un desvio), el limite se corre solo,
 *  hasta un tope (autoAjusteMin). Si el telefono esta quieto (la persona freno) o se aleja, no se suma nada: sigue el aviso de siempre. Se evalua cada ~4 minutos con una ubicacion reciente
 *  y solo se le pregunta a Google cuando faltan 20 minutos o menos. */
async function gdAjustarPorTransito(env: Env, v: GdViaje, g: GdConfig, ub: Awaited<ReturnType<typeof gdUbicacion>>, ahora: number): Promise<GdViaje | null> {
  if (g.autoAjusteMin <= 0 || (v.estado !== "en_camino" && v.estado !== "aviso")) return null;
  if (v.destLat === null || v.destLng === null || !ub.ubicacion) return null;
  const muestraEn = Date.parse(ub.ubicacion.en ?? "");
  if (!Number.isFinite(muestraEn) || ahora - muestraEn > GD_UBICACION_RECIENTE_MIN * 60_000) return null;
  const p = await gdLeerProgreso(env, v.id);
  if (p.pausaHasta) return null; // frenado: el reloj esta en pausa
  if (p.recalcAt && ahora - Date.parse(p.recalcAt) < GD_AJUSTE_CADA_MIN * 60_000) return null;
  const aqui = { lat: ub.ubicacion.lat, lng: ub.ubicacion.lng };
  const nuevaRef: GdProgreso = { ...p, refLat: aqui.lat, refLng: aqui.lng, refAt: new Date(muestraEn).toISOString(), recalcAt: new Date(ahora).toISOString() };
  if (p.refLat === null || p.refLng === null || !p.refAt) { await gdGuardarProgreso(env, v.id, nuevaRef); return null; }
  if (muestraEn - Date.parse(p.refAt) < 3 * 60_000) return null; // todavia no hay una ubicacion mas nueva para comparar
  const avanceM = (pldDistanciaKm(p.refLat, p.refLng, v.destLat, v.destLng) - pldDistanciaKm(aqui.lat, aqui.lng, v.destLat, v.destLng)) * 1000;
  await gdGuardarProgreso(env, v.id, nuevaRef);
  if (avanceM < GD_AJUSTE_AVANCE_M) return null;
  if ((Date.parse(v.deadlineAt) - ahora) / 60_000 > GD_AJUSTE_DESDE_MIN || p.autoMin >= g.autoAjusteMin) return null;
  const ruta = await gdRutaMapas(env, aqui, { lat: v.destLat, lng: v.destLng }, v.modo);
  if ("fallo" in ruta) return null;
  const atraso = (ahora + (ruta.minutos + g.margenMin) * 60_000 - Date.parse(v.deadlineAt)) / 60_000;
  if (atraso < GD_AJUSTE_MIN_ATRASO) return null;
  const suma = Math.min(Math.ceil(atraso), g.autoAjusteMin - p.autoMin);
  if (suma < 1) return null;
  const limite = new Date(Date.parse(v.deadlineAt) + suma * 60_000).toISOString();
  await env.DB.prepare("UPDATE gd_viajes SET deadline_at=?,estado=''en_camino'',aviso_at=NULL WHERE id=? AND estado IN (''en_camino'',''aviso'')").bind(limite, v.id).run();
  await gdGuardarProgreso(env, v.id, { ...nuevaRef, autoMin: p.autoMin + suma });
  await pldRegistrar(env, v.ownerEmail, null, "guardian", `Hay m\u00e1s tr\u00e1nsito: se te sumaron ${suma} minutos para llegar a ${v.destino} (hasta las ${gdHora(limite)}).`);
  if (ub.pushToken) await sendExpoNotice(ub.pushToken, "Hay m\u00e1s tr\u00e1nsito", `Te dimos ${suma} minutos m\u00e1s para llegar a ${v.destino}. Ten\u00e9s que llegar antes de las ${gdHora(limite)}.`, { data: { tipo: "guardian", url: await gdEnlace(env, v) } }).catch(() => false);
  return { ...v, deadlineAt: limite, estado: "en_camino", avisoAt: null };
}

/** Un paso del reloj de un camino (lo llama el cron cada minuto). */
async function gdAvanzar(env: Env, v: GdViaje) {
  const ahora = Date.now();
  const g = await gdLeerConfig(env, v.ownerEmail);
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
  if (v.estado === "en_camino" || v.estado === "aviso") {
    const pausa = await gdLeerProgreso(env, v.id);
    if (pausa.pausaHasta) {
      if (ahora < Date.parse(pausa.pausaHasta)) return; // frenado: el reloj esta en pausa, no se pregunta ni se avisa nada
      await gdCerrarPausa(env, v, pausa, ahora); // se termino la pausa: el reloj sigue con lo que le quedaba
      const quedan = Math.max(0, (Date.parse(v.deadlineAt) - ahora) / 60000);
      await pldRegistrar(env, v.ownerEmail, null, "guardian", `Termin\u00f3 tu parada: el reloj sigue, te quedan ${Math.max(1, Math.ceil(quedan))} minutos para llegar a ${v.destino} (hasta las ${gdHora(v.deadlineAt)}).`);
      if (quedan > g.avisoMin) await gdAvisarPersona(env, v, "Termin\u00f3 tu parada", "Termin\u00f3 tu parada", `El reloj sigue: te quedan <strong style="color:#fff">${Math.ceil(quedan)} minutos</strong> para llegar a <strong style="color:#fff">${escapeHtml(v.destino)}</strong>. Si ya llegaste, toc\u00e1 <em>Llegu\u00e9</em>. Si todav\u00eda est\u00e1s parado, pod\u00e9s frenar de nuevo.`, "Abrir mi camino");
    }
    const ajustado = await gdAjustarPorTransito(env, v, g, ub, ahora).catch((error) => { console.error("gd_ajuste_failed", error); return null; });
    if (ajustado) return; // el limite se corrio: lo demas se evalua el proximo minuto
  }
  const falta = (Date.parse(v.deadlineAt) - ahora) / 60000;
  if (v.estado === "en_camino" && falta <= g.avisoMin && falta > 0) {
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
  if (v.estado === "alerta" && v.alertas < g.maxAlertas && v.lastAlertAt && ahora - Date.parse(v.lastAlertAt) >= g.entreAlertasMin * 60_000) {
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

/** La clave de Google (GOOGLE_ROUTES_KEY), limpia. Si al guardarla en el servidor se colaron caracteres invisibles (por ejemplo al pegarla en la consola), Google corta la conexi\u00f3n o contesta 400 sin mensaje:
 *  se usa solo la parte que tiene forma de clave ("AIza" y 35 caracteres) y se anota cu\u00e1ntos caracteres sobraban. */
function gdClave(env: Env): { clave: string; sobran: number } {
  const cruda = String((env as unknown as Record<string, string | undefined>).GOOGLE_ROUTES_KEY ?? "");
  const m = /AIza[0-9A-Za-z_-]{35}/.exec(cruda);
  const clave = m ? m[0] : cruda.replace(/[^0-9A-Za-z_-]/g, "");
  return { clave, sobran: cruda.length - clave.length };
}

/** Datos de la clave para mostrar cuando algo falla (sin mostrarla entera): cu\u00e1ntos caracteres tiene, con qu\u00e9 empieza y si hubo que quitarle caracteres raros. */
function gdNotaClave(k: { clave: string; sobran: number }): string {
  return `clave de ${k.clave.length} caracteres, empieza con ${k.clave.slice(0, 4)}${k.sobran > 0 ? `, se quitaron ${k.sobran} caracteres raros` : ""}`;
}

/** Llama a Google (POST) y lee la respuesta entera. A veces la conexi\u00f3n entre Cloudflare y Google se corta ("Network connection lost"): en ese caso se reintenta una vez. */
async function gdLlamarGoogle(url: string, clave: string, cuerpo: unknown, mascara = ""): Promise<{ estado: number; texto: string } | { red: string }> {
  let ultimo = "";
  for (let intento = 0; intento < 2; intento++) {
    try {
      const r = await fetch(url, {
        method: "POST",
        headers: { "content-type": "application/json", "X-Goog-Api-Key": clave, ...(mascara ? { "X-Goog-FieldMask": mascara } : {}) },
        body: JSON.stringify(cuerpo),
      });
      return { estado: r.status, texto: await r.text() };
    } catch (error) {
      ultimo = String(error).slice(0, 100);
    }
  }
  return { red: ultimo };
}

/** Por qu\u00e9 Google rechaz\u00f3 un pedido: el mensaje que devuelve (o, si no hay, el estado o el principio de la respuesta) para poder mostrarlo en pantalla. */
function gdMotivoGoogle(crudo: string): string {
  try {
    const e = JSON.parse(crudo) as { error?: { message?: string; status?: string; details?: Array<{ reason?: string }> } };
    const m = String(e?.error?.message ?? "").trim();
    if (m) return m.slice(0, 160);
    return String(e?.error?.details?.[0]?.reason ?? e?.error?.status ?? crudo).slice(0, 160);
  } catch {
    return crudo.replace(/\s+/g, " ").trim().slice(0, 160);
  }
}

type GdRutaMapas = { minutos: number; km: number; destLat: number | null; destLng: number | null };
type GdFalloMapas = { fallo: string; detalle: string };

/** El tiempo del camino seg\u00fan Google Mapas, con el tr\u00e1nsito de ahora (auto), a pie o en transporte p\u00fablico. Hace falta la clave GOOGLE_ROUTES_KEY (con la Routes API habilitada).
 *  Si no se puede, devuelve el motivo (sin_clave, http_403, sin_ruta, red...) para poder decirle a la persona qu\u00e9 pas\u00f3: en ese caso se estima por la distancia o ella pone los minutos. */
async function gdRutaMapas(env: Env, origen: { lat: number; lng: number }, destino: { lat: number; lng: number } | { texto: string } | { placeId: string }, modo: string): Promise<GdRutaMapas | GdFalloMapas> {
  const k = gdClave(env);
  const clave = k.clave;
  if (!clave) return { fallo: "sin_clave", detalle: "" };
  const punto = (p: { lat: number; lng: number }) => ({ location: { latLng: { latitude: p.lat, longitude: p.lng } } });
  const cuerpo: Record<string, unknown> = {
    origin: punto(origen),
    destination: "placeId" in destino ? { placeId: destino.placeId } : "texto" in destino ? { address: destino.texto } : punto(destino),
    travelMode: modo === "auto" ? "DRIVE" : modo === "caminando" ? "WALK" : "TRANSIT",
    languageCode: "es-AR",
    regionCode: "AR",
    units: "METRIC",
  };
  if (modo === "auto") cuerpo.routingPreference = "TRAFFIC_AWARE";
  try {
    const g = await gdLlamarGoogle("https://routes.googleapis.com/directions/v2:computeRoutes", clave, cuerpo, "routes.duration,routes.distanceMeters,routes.legs.endLocation");
    if ("red" in g) return { fallo: "red", detalle: `${g.red} (${gdNotaClave(k)})`.slice(0, 220) };
    if (g.estado < 200 || g.estado > 299) {
      const motivo = gdMotivoGoogle(g.texto);
      return { fallo: `http_${g.estado}`, detalle: (motivo && k.sobran === 0 ? motivo : `${motivo} (${gdNotaClave(k)})`.trim()).slice(0, 220) };
    }
    const d = JSON.parse(g.texto) as { routes?: Array<{ duration?: string; distanceMeters?: number; legs?: Array<{ endLocation?: { latLng?: { latitude?: number; longitude?: number } } }> }> };
    const ruta = d.routes?.[0];
    const segundos = Number(String(ruta?.duration ?? "").replace("s", ""));
    if (!ruta || !Number.isFinite(segundos) || segundos <= 0) return { fallo: "sin_ruta", detalle: "" };
    const fin = ruta.legs?.[ruta.legs.length - 1]?.endLocation?.latLng;
    return {
      minutos: Math.max(1, Math.ceil(segundos / 60)),
      km: Math.round((Number(ruta.distanceMeters) || 0) / 100) / 10,
      destLat: Number.isFinite(Number(fin?.latitude)) ? Number(fin?.latitude) : null,
      destLng: Number.isFinite(Number(fin?.longitude)) ? Number(fin?.longitude) : null,
    };
  } catch (error) {
    return { fallo: "red", detalle: String(error).slice(0, 100) };
  }
}

/** Sugerencias mientras la persona escribe (Google Places, nuevo): direcciones y tambi\u00e9n nombres de lugares (restaurantes, locales, plazas...), cerca de donde est\u00e1, con el barrio, la ciudad
 *  y a cu\u00e1ntos km queda, para elegir el correcto. */
async function gdBuscarLugares(env: Env, texto: string, origen: { lat: number; lng: number } | null, conDistancia = true) {
  const k = gdClave(env);
  const clave = k.clave;
  type Sugerencia = { placeId: string; principal: string; secundario: string; km: number | null };
  if (!clave) return { sugerencias: [] as Sugerencia[], fallo: "sin_clave", detalle: "" };
  const base: Record<string, unknown> = { input: texto, languageCode: "es", regionCode: "AR" };
  const conUbicacion: Record<string, unknown> = origen
    ? { ...base, locationBias: { circle: { center: { latitude: origen.lat, longitude: origen.lng }, radius: 50000 } }, ...(conDistancia ? { origin: { latitude: origen.lat, longitude: origen.lng } } : {}) }
    : base;
  // Si Google rechaza el pedido completo (400), se corta la conexion o no encuentra nada, se prueba con uno mas simple: asi una opcion que Google no acepte no deja a la persona sin sugerencias.
  const intentos: Array<[string, Record<string, unknown>]> = [["A", conUbicacion], ["B", base], ["C", { input: texto }]];
  let fallo = "";
  let primero = "";
  const marcas: string[] = [];
  for (const [letra, cuerpo] of intentos) {
    const g = await gdLlamarGoogle("https://places.googleapis.com/v1/places:autocomplete", clave, cuerpo);
    if ("red" in g) {
      marcas.push(`${letra}:red`);
      if (!fallo) { fallo = "red"; primero = g.red; }
      continue;
    }
    marcas.push(`${letra}${g.estado}`);
    if (g.estado < 200 || g.estado > 299) {
      const motivo = gdMotivoGoogle(g.texto);
      if (!fallo) { fallo = `http_${g.estado}`; primero = motivo; }
      if (g.estado === 400 && !/api key|clave/i.test(motivo)) continue;
      return { sugerencias: [] as Sugerencia[], fallo: `http_${g.estado}`, detalle: `[${marcas.join(" ")}] ${motivo}${k.sobran > 0 ? ` (${gdNotaClave(k)})` : ""}`.slice(0, 240) };
    }
    try {
      const d = JSON.parse(g.texto) as { suggestions?: Array<{ placePrediction?: { placeId?: string; distanceMeters?: number; text?: { text?: string }; structuredFormat?: { mainText?: { text?: string }; secondaryText?: { text?: string } } } }> };
      const sugerencias: Sugerencia[] = (d.suggestions ?? []).map((x) => x.placePrediction).filter((p) => p && p.placeId).slice(0, 6).map((p) => ({
        placeId: String(p!.placeId),
        principal: String(p!.structuredFormat?.mainText?.text ?? p!.text?.text ?? "").slice(0, 120),
        secundario: String(p!.structuredFormat?.secondaryText?.text ?? "").slice(0, 120),
        km: Number.isFinite(Number(p!.distanceMeters)) && Number(p!.distanceMeters) >= 0 ? Math.round(Number(p!.distanceMeters) / 100) / 10 : null,
      })).filter((x) => x.principal);
      if (sugerencias.length) return { sugerencias };
    } catch {
      if (!fallo) { fallo = "http_200"; primero = "respuesta ilegible"; }
    }
  }
  if (!fallo) return { sugerencias: [] as Sugerencia[], fallo: "sin_resultados", detalle: `[${marcas.join(" ")}] ${gdNotaClave(k)}`.slice(0, 240) };
  return { sugerencias: [] as Sugerencia[], fallo: fallo || "http_400", detalle: `[${marcas.join(" ")}] ${primero} (${gdNotaClave(k)})`.slice(0, 240) };
}

type GdDestino = { destino: string; destLat: number | null; destLng: number | null; texto: string | null; placeId: string | null };

/** A d\u00f3nde va: uno de sus Lugares, una direcci\u00f3n sugerida por Google (placeId) o una direcci\u00f3n escrita. */
async function gdDestino(env: Env, email: string, cuerpo: Record<string, unknown>): Promise<GdDestino | { error: string; status: number }> {
  if (cuerpo.lugarId) {
    const lugar = await env.DB.prepare("SELECT name,latitude,longitude FROM family_places WHERE id=? AND owner_email=?").bind(String(cuerpo.lugarId), email).first<{ name: string; latitude: number; longitude: number }>();
    if (!lugar) return { error: "lugar_invalido", status: 400 };
    return { destino: String(lugar.name).slice(0, 80), destLat: Number(lugar.latitude), destLng: Number(lugar.longitude), texto: null, placeId: null };
  }
  if (cuerpo.placeId) {
    const placeId = String(cuerpo.placeId);
    if (!/^[A-Za-z0-9_-]{10,300}$/.test(placeId)) return { error: "destino_invalido", status: 400 };
    const etiqueta = String(cuerpo.texto ?? "").trim().slice(0, 80) || "Lugar elegido";
    return { destino: etiqueta, destLat: null, destLng: null, texto: etiqueta, placeId };
  }
  const texto = String(cuerpo.texto ?? "").trim().slice(0, 120);
  if (!texto) return { error: "falta_destino", status: 400 };
  return { destino: texto.slice(0, 80), destLat: null, destLng: null, texto, placeId: null };
}

/** Desde donde se calcula un camino: la ubicacion que manda el navegador de la persona en ese momento (lo mas actual, como Google Maps o Waze); si no hay, la del telefono pero solo si es de los
 *  ultimos minutos. Nunca un lugar guardado (como Casa) ni una ubicacion vieja: si no hay una buena, se avisa en vez de calcular desde otro punto. */
async function gdOrigenActual(env: Env, email: string, pedido: unknown): Promise<{ origen: { lat: number; lng: number }; fuente: "navegador" | "telefono"; haceMin: number } | { fallo: "sin_ubicacion" | "ubicacion_vieja"; haceMin: number | null; vieja: { lat: number; lng: number } | null }> {
  const o = pedido as { lat?: unknown; lng?: unknown; precision?: unknown } | null;
  if (o && Number.isFinite(Number(o.lat)) && Number.isFinite(Number(o.lng)) && Math.abs(Number(o.lat)) <= 90 && Math.abs(Number(o.lng)) <= 180 && !(Number(o.precision) > GD_PRECISION_MAX_M)) {
    return { origen: { lat: Number(o.lat), lng: Number(o.lng) }, fuente: "navegador", haceMin: 0 };
  }
  const ub = await gdUbicacion(env, email);
  if (!ub.ubicacion) return { fallo: "sin_ubicacion", haceMin: null, vieja: null };
  const en = Date.parse(ub.ubicacion.en ?? "");
  const haceMin = Number.isFinite(en) ? Math.max(0, Math.round((Date.now() - en) / 60_000)) : null;
  if (haceMin === null || haceMin > GD_UBICACION_RECIENTE_MIN) return { fallo: "ubicacion_vieja", haceMin, vieja: { lat: ub.ubicacion.lat, lng: ub.ubicacion.lng } };
  return { origen: { lat: ub.ubicacion.lat, lng: ub.ubicacion.lng }, fuente: "telefono", haceMin };
}

/** Cu\u00e1nto tarda: primero Google Mapas (con el tr\u00e1nsito de ahora); si no se puede, la distancia en l\u00ednea recta cuando se sabe el destino. Si falla Google, dice por qu\u00e9.
 *  `origen` dice de donde se calculo (el navegador de la persona o la ultima ubicacion de su telefono) para que la pantalla lo cuente. */
async function gdCalcular(env: Env, email: string, modo: string, d: GdDestino, origenPedido: unknown) {
  const o = await gdOrigenActual(env, email, origenPedido);
  if ("fallo" in o) return { ruta: null, fallo: o.fallo as string, detalle: o.haceMin === null ? "" : `la \u00faltima ubicaci\u00f3n de tu tel\u00e9fono es de hace ${pldTiempo(o.haceMin)}`, origen: null };
  const origen = o.origen, desde = { fuente: o.fuente, haceMin: o.haceMin };
  const destino = d.placeId ? { placeId: d.placeId } : d.destLat !== null && d.destLng !== null ? { lat: d.destLat, lng: d.destLng } : { texto: d.texto ?? d.destino };
  const mapas = await gdRutaMapas(env, origen, destino, modo);
  if (!("fallo" in mapas)) return { ruta: { ...mapas, fuente: "mapas" as const }, fallo: "", detalle: "", origen: desde };
  if (d.destLat !== null && d.destLng !== null) {
    const km = pldDistanciaKm(origen.lat, origen.lng, d.destLat, d.destLng);
    return { ruta: { minutos: gdEstimar(km, modo), km: Math.round(km * 10) / 10, destLat: d.destLat, destLng: d.destLng, fuente: "distancia" as const }, fallo: mapas.fallo === "sin_clave" ? "" : mapas.fallo, detalle: mapas.detalle, origen: desde };
  }
  return { ruta: null, fallo: mapas.fallo, detalle: mapas.detalle, origen: desde };
}

/** Cuantos minutos vale el camino: lo que calcula Google Mapas; si no se pudo, los que puso la persona; y si tampoco, la estimacion por la distancia. */
function gdElegirMinutos(ruta: { minutos: number; fuente: "mapas" | "distancia" } | null, propios: unknown): { minutos: number; fuente: string } | null {
  const p = Number(propios);
  let minutos: number, fuente: string;
  if (ruta && ruta.fuente === "mapas") { minutos = ruta.minutos; fuente = "calculado con mapas y el tr\u00e1nsito de ahora"; }
  else if (Number.isFinite(p) && p > 0) { minutos = p; fuente = "tiempo que pusiste vos"; }
  else if (ruta) { minutos = ruta.minutos; fuente = "estimado por la distancia"; }
  else return null;
  return { minutos: Math.min(GD_MAX_MINUTOS, Math.max(1, Math.round(minutos))), fuente };
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
  const { ruta, fallo } = await gdCalcular(env, email, modo, d, cuerpo.origen);
  if (ruta && ruta.fuente === "mapas" && ruta.minutos > GD_MAX_MINUTOS) return { error: "destino_muy_lejos", status: 400 };
  const elegido = gdElegirMinutos(ruta, cuerpo.minutos);
  if (!elegido) return { error: "faltan_minutos", status: 400, fallo };
  const { minutos, fuente } = elegido;
  const destino = d.destino;
  const destLat = d.destLat ?? ruta?.destLat ?? null, destLng = d.destLng ?? ruta?.destLng ?? null;
  const id = `gdv${pldSecreto().slice(0, 14)}`;
  const inicio = now();
  const g = await gdLeerConfig(env, email);
  const limite = new Date(Date.now() + (minutos + g.margenMin) * 60_000).toISOString();
  await env.DB.prepare("INSERT INTO gd_viajes (id,owner_email,destino,dest_lat,dest_lng,modo,estimado_min,started_at,deadline_at,extensiones,estado,alertas) VALUES (?,?,?,?,?,?,?,?,?,0,''en_camino'',0)")
    .bind(id, email, destino, destLat, destLng, modo, minutos, inicio, limite).run();
  await pldRegistrar(env, email, null, "guardian", `Empezaste un camino a ${destino} ${GD_MODOS[modo]}: ${minutos} min (${fuente}) + ${g.margenMin} de margen (hasta las ${gdHora(limite)}).`);
  const v = (await gdPorId(env, id))!;
  return { ok: true, viaje: await gdPresentar(env, v) };
}

/** Llegu\u00e9 / Extender / Necesito ayuda / Cancelar. */
async function gdAccion(env: Env, v: GdViaje, accion: string, minutos: number, cuerpo: Record<string, unknown> = {}) {
  const activo = v.estado === "en_camino" || v.estado === "aviso" || v.estado === "alerta";
  if (!activo) return { error: "camino_terminado", status: 409 };
  const g = await gdLeerConfig(env, v.ownerEmail);
  const pr = await gdLeerProgreso(env, v.id);
  if (accion === "llegue" || (accion === "cancelar" && v.estado === "alerta")) {
    let vf = v, pf = pr;
    if (pr.pausaHasta && v.estado !== "alerta") ({ viaje: vf, progreso: pf } = await gdCerrarPausa(env, v, pr, Date.now())); // llego frenado: se cuenta lo que duro la pausa y el limite vuelve a lo que quedaba
    const fin = now();
    await env.DB.prepare("UPDATE gd_viajes SET estado=''llego'',ended_at=?,motivo_fin=''llegue'' WHERE id=?").bind(fin, v.id).run();
    const f = gdFin({ ...vf, endedAt: fin }, g.margenMin, pf.autoMin, pf.paradaMin)!;
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
    if (g.maxExtensiones === 0) return { error: "sin_extensiones", status: 409 };
    if (v.extensiones >= g.maxExtensiones) return { error: "demasiadas_extensiones", status: 409 };
    const base = Math.max(Date.parse(v.deadlineAt), Date.now());
    const limite = new Date(base + minutos * 60_000).toISOString();
    await env.DB.prepare("UPDATE gd_viajes SET deadline_at=?,extensiones=extensiones+1,estado=''en_camino'',aviso_at=NULL WHERE id=?").bind(limite, v.id).run();
    if (pr.pausaHasta && Date.now() < Date.parse(pr.pausaHasta)) await gdGuardarProgreso(env, v.id, { ...pr, restaMs: (pr.restaMs ?? 0) + minutos * 60_000 }); // frenado: lo pedido se suma a lo que le queda para llegar
    await pldRegistrar(env, v.ownerEmail, null, "guardian", `Pediste ${minutos} minutos m\u00e1s para llegar a ${v.destino} (hasta las ${gdHora(limite)}).`);
    return { ok: true, estado: "en_camino" };
  }
  if (accion === "parada") {
    if (v.estado === "alerta") return { error: "ya_se_aviso", status: 409 };
    if (!GD_PARADAS.includes(minutos)) return { error: "minutos_invalidos", status: 400 };
    if (g.maxExtensiones === 0) return { error: "sin_extensiones", status: 409 };
    if (pr.paradas >= GD_MAX_PARADAS) return { error: "demasiadas_paradas", status: 409 };
    const ahora = Date.now();
    const previa = pr.pausaHasta && ahora >= Date.parse(pr.pausaHasta) ? (await gdCerrarPausa(env, v, pr, ahora)).progreso : pr; // la pausa anterior ya se habia terminado
    const sigue = !!previa.pausaHasta; // ya estaba frenado: se alarga la pausa
    const hasta = (sigue ? Date.parse(previa.pausaHasta!) : ahora) + minutos * 60_000;
    const resta = sigue ? Math.max(GD_PAUSA_RESTA_MINIMA_MS, previa.restaMs ?? 0) : Math.max(GD_PAUSA_RESTA_MINIMA_MS, Date.parse(v.deadlineAt) - ahora);
    const limite = new Date(hasta + resta).toISOString();
    await env.DB.prepare("UPDATE gd_viajes SET deadline_at=?,estado=''en_camino'',aviso_at=NULL WHERE id=?").bind(limite, v.id).run();
    await gdGuardarProgreso(env, v.id, { ...previa, paradas: previa.paradas + 1, pausaIni: sigue ? previa.pausaIni : new Date(ahora).toISOString(), pausaHasta: new Date(hasta).toISOString(), restaMs: resta, refLat: null, refLng: null, refAt: null });
    await pldRegistrar(env, v.ownerEmail, null, "guardian", sigue
      ? `Alargaste la pausa ${minutos} minutos (hasta las ${gdHora(new Date(hasta).toISOString())}). El reloj sigue en pausa con ${Math.ceil(resta / 60_000)} minutos para llegar a ${v.destino}. No se les avis\u00f3 a tus referentes.`
      : `Vas a frenar un rato: el reloj queda en pausa ${minutos} minutos (hasta las ${gdHora(new Date(hasta).toISOString())}) con ${Math.ceil(resta / 60_000)} minutos para llegar a ${v.destino}. No se les avis\u00f3 a tus referentes.`);
    return { ok: true, estado: "en_camino" };
  }
  if (accion === "seguir") {
    if (v.estado === "alerta") return { error: "ya_se_aviso", status: 409 };
    if (!pr.pausaHasta) return { error: "sin_pausa", status: 409 };
    const ahora = Date.now();
    const c = await gdCerrarPausa(env, v, pr, ahora);
    await pldRegistrar(env, v.ownerEmail, null, "guardian", `Segu\u00eds en camino a ${v.destino}: el reloj sigue con ${Math.max(1, Math.ceil((Date.parse(c.viaje.deadlineAt) - ahora) / 60_000))} minutos (hasta las ${gdHora(c.viaje.deadlineAt)}).`);
    return { ok: true, estado: "en_camino" };
  }
  if (accion === "cambiar") {
    if (v.estado === "alerta") return { error: "ya_se_aviso", status: 409 };
    const modo = cuerpo.modo === undefined || cuerpo.modo === null || cuerpo.modo === "" ? v.modo : String(cuerpo.modo); // si no elige otro, sigue con el que traia
    if (!GD_MODOS[modo]) return { error: "modo_invalido", status: 400 };
    const mismo = cuerpo.mismo === true; // sigue yendo al mismo lugar pero cambia como va (o recalcula desde donde esta)
    if (mismo && (v.destLat === null || v.destLng === null)) return { error: "destino_invalido", status: 400 };
    const d = mismo ? ({ destino: v.destino, destLat: v.destLat, destLng: v.destLng, texto: null, placeId: null } as GdDestino) : await gdDestino(env, v.ownerEmail, cuerpo);
    if ("error" in d) return d;
    const { ruta, fallo, origen: desde } = await gdCalcular(env, v.ownerEmail, modo, d, cuerpo.origen);
    if (ruta && ruta.fuente === "mapas" && ruta.minutos > GD_MAX_MINUTOS) return { error: "destino_muy_lejos", status: 400 };
    const elegido = gdElegirMinutos(ruta, cuerpo.minutos);
    if (!elegido) return { error: "faltan_minutos", status: 400, fallo };
    const ahora = Date.now();
    const transcurrido = Math.max(0, Math.round((ahora - Date.parse(v.startedAt)) / 60000));
    const limite = new Date(ahora + (elegido.minutos + g.margenMin) * 60_000).toISOString();
    const destLat = d.destLat ?? ruta?.destLat ?? null, destLng = d.destLng ?? ruta?.destLng ?? null;
    await env.DB.prepare("UPDATE gd_viajes SET destino=?,dest_lat=?,dest_lng=?,modo=?,estimado_min=?,deadline_at=?,estado=''en_camino'',aviso_at=NULL,llegada_at=NULL WHERE id=?")
      .bind(d.destino, destLat, destLng, modo, transcurrido + elegido.minutos, limite, v.id).run();
    await gdGuardarProgreso(env, v.id, { ...GD_PROGRESO_VACIO, paradas: pr.paradas });
    const km = ruta ? `, ${String(ruta.km).replace(".", ",")} km` : "";
    const desdeTxt = desde ? ` Calculado desde ${desde.fuente === "navegador" ? "donde estabas" : `la \u00faltima ubicaci\u00f3n de tu tel\u00e9fono (hace ${desde.haceMin} min)`}.` : "";
    await pldRegistrar(env, v.ownerEmail, null, "guardian", mismo
      ? `Cambiaste c\u00f3mo vas a ${v.destino}: ahora ${GD_MODOS[modo]}: ${elegido.minutos} min (${elegido.fuente}${km}) + ${g.margenMin} de margen (hasta las ${gdHora(limite)}).${desdeTxt}`
      : `Cambiaste el destino a ${d.destino}${modo !== v.modo ? ` (ahora ${GD_MODOS[modo]})` : ""}: ${elegido.minutos} min (${elegido.fuente}${km}) + ${g.margenMin} de margen (hasta las ${gdHora(limite)}).${desdeTxt}`);
    return { ok: true, estado: "en_camino", origen: desde, minutos: elegido.minutos, km: ruta ? ruta.km : null, modo };
  }
  if (accion === "ayuda") {
    const ub = await gdUbicacion(env, v.ownerEmail);
    const enviados = await pldAvisarSos(env, v.ownerEmail, ub.ubicacion ? { latitude: ub.ubicacion.lat, longitude: ub.ubicacion.lng, address: ub.ubicacion.address } : null);
    await env.DB.prepare("UPDATE gd_viajes SET estado=''alerta'',alertas=?,last_alert_at=? WHERE id=?").bind(g.maxAlertas, now(), v.id).run();
    await pldRegistrar(env, v.ownerEmail, null, "guardian", `Pediste ayuda en el camino a ${v.destino}: se les avis\u00f3 a ${enviados} referentes.`);
    return { ok: true, estado: "alerta", avisados: enviados };
  }
  return { error: "accion_desconocida", status: 400 };
}

/** Sugerencias de lugares (direcciones y nombres) cerca de donde esta la persona. Si no se sabe donde esta ahora (la ultima ubicacion del telefono es vieja), solo se usa para ordenar y no se dicen distancias. */
async function gdBuscarApi(env: Env, email: string, cuerpo: Record<string, unknown>) {
  const texto = String(cuerpo.texto ?? "").trim().slice(0, 100);
  if (texto.length < 3) return json({ ok: true, sugerencias: [] });
  const o = await gdOrigenActual(env, email, cuerpo.origen);
  if ("origen" in o) return json({ ok: true, ...(await gdBuscarLugares(env, texto, o.origen, true)) });
  return json({ ok: true, ...(await gdBuscarLugares(env, texto, o.vieja, false)) });
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
      return json("error" in r ? { error: r.error, ...("viaje" in r ? { viaje: r.viaje } : {}), ...("fallo" in r && r.fallo ? { fallo: r.fallo } : {}) } : r, "error" in r ? r.status : 200);
    }
    if (accion === "buscar") return gdBuscarApi(env, email, cuerpo);
    if (accion === "config") {
      const persona = await pldResolverPersona(env, email, "");
      if ("error" in persona) return json({ error: persona.error }, persona.status);
      if (persona.soloLectura) return json({ error: "solo_administrador" }, 403);
      if (await gdActivo(env, email)) return json({ error: "camino_en_marcha" }, 409);
      const c = (cuerpo.config ?? {}) as Record<string, unknown>;
      const nuevo = c.restablecer ? { ...GD_POR_DEFECTO } : gdConfigValida(c, await gdLeerConfig(env, email));
      await gdGuardarConfig(env, email, nuevo);
      await pldRegistrar(env, email, null, "guardian", c.restablecer ? "Volviste los tiempos y avisos del Modo Guardi\u00e1n a los valores recomendados." : "Cambiaste los tiempos y avisos del Modo Guardi\u00e1n.");
      return json({ ok: true, config: nuevo, defaults: GD_POR_DEFECTO });
    }
    if (accion === "estimar") {
      const modo = String(cuerpo.modo ?? "auto");
      if (!GD_MODOS[modo]) return json({ error: "modo_invalido" }, 400);
      const d = await gdDestino(env, email, cuerpo);
      if ("error" in d) return json({ ok: true, minutos: null, km: null, fuente: null, error: d.error });
      const { ruta, fallo, detalle, origen } = await gdCalcular(env, email, modo, d, cuerpo.origen);
      if (!ruta) return json({ ok: true, minutos: null, km: null, fuente: null, fallo, detalle, origen });
      if (ruta.fuente === "mapas" && ruta.minutos > GD_MAX_MINUTOS) return json({ ok: true, minutos: null, km: ruta.km, fuente: "mapas", error: "destino_muy_lejos", origen });
      return json({ ok: true, minutos: ruta.minutos, km: ruta.km, fuente: ruta.fuente, editable: ruta.fuente !== "mapas", fallo, detalle, origen });
    }
    viaje = await gdActivo(env, email);
  }
  if (accion === "estado") {
    const lugares = cuerpo.t ? [] : ((await env.DB.prepare("SELECT id,name FROM family_places WHERE owner_email=? ORDER BY name ASC").bind(email).all<{ id: string; name: string }>()).results ?? []);
    return json({ ok: true, ahora: now(), viaje: viaje ? await gdPresentar(env, viaje) : null, lugares, referentes: (await pldReferentesActivos(env, email)).length, ...(cuerpo.t ? {} : { config: await gdLeerConfig(env, email), defaults: GD_POR_DEFECTO }) });
  }
  if (accion === "lugares") {
    const lugares = (await env.DB.prepare("SELECT id,name FROM family_places WHERE owner_email=? ORDER BY name ASC").bind(email).all<{ id: string; name: string }>()).results ?? [];
    return json({ ok: true, lugares });
  }
  if (!viaje) return json({ error: "no_hay_camino" }, 404);
  if (accion === "buscar") {
    if (viaje.estado !== "en_camino" && viaje.estado !== "aviso" && viaje.estado !== "alerta") return json({ error: "camino_terminado" }, 409);
    return gdBuscarApi(env, email, cuerpo);
  }
  const r = await gdAccion(env, viaje, accion, Number(cuerpo.minutos), cuerpo);
  if ("error" in r) return json({ error: r.error, ...("fallo" in r && r.fallo ? { fallo: r.fallo } : {}) }, r.status);
  const nuevo = await gdPorId(env, viaje.id);
  return json({ ...r, ahora: now(), viaje: nuevo ? await gdPresentar(env, nuevo) : null });
}

/** Los tres modos de ir (auto, transporte, caminando) como botones con icono, para empezar un camino y para cambiarlo. */
const GD_ICONO_MODO: Record<string, string> = {
  auto: ''<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12l1.8-4.2A1.5 1.5 0 0 1 8.2 7h7.6a1.5 1.5 0 0 1 1.4.8L19 12"/><rect x="3.5" y="12" width="17" height="5.5" rx="1.5"/><circle cx="7.5" cy="17.5" r="1.7"/><circle cx="16.5" cy="17.5" r="1.7"/></svg>'',
  transporte: ''<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="5" y="3.5" width="14" height="14" rx="2.5"/><path d="M5 11h14M8 7h8"/><circle cx="8.5" cy="14.2" r=".7"/><circle cx="15.5" cy="14.2" r=".7"/><path d="M7.5 17.5V20M16.5 17.5V20"/></svg>'',
  caminando: ''<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="13.5" cy="4.5" r="1.8"/><path d="M12.5 8.5l-2 4.5 3 2.5 1 5M12.5 8.5l3 3.2 2.5.6M12.5 8.5L9 10.3l-.8 2.7M10.5 13l-2.3 6.5"/></svg>'',
};
function gdModosHtml(id: string, actual: string) {
  const rotulo: Record<string, string> = { auto: "Auto", transporte: "Transporte", caminando: "Caminando" };
  const titulo: Record<string, string> = { auto: "En auto", transporte: "En transporte p\u00fablico", caminando: "Caminando" };
  return `<div class="modos" id="${id}" role="radiogroup" aria-label="C\u00f3mo vas">${Object.keys(rotulo).map((m) => `<button type="button" class="modo" role="radio" data-modo="${m}" title="${titulo[m]}" aria-checked="${m === actual ? "true" : "false"}">${GD_ICONO_MODO[m]}<span>${rotulo[m]}</span></button>`).join("")}</div>`;
}

const PLD_ESTILO = `<style>*{box-sizing:border-box}body{margin:0;min-height:100vh;background:#0b0c0e;color:#f3f1ea;font-family:system-ui,-apple-system,Segoe UI,sans-serif;padding:22px 16px 60px}main{max-width:560px;margin:0 auto}img.logo{display:block;height:34px;margin:6px 0 18px}h1{font-size:1.5rem;margin:.2rem 0 .5rem}h2{font-size:1.05rem;margin:0 0 10px}p{color:#d2d2ce;line-height:1.55}small,.suave{color:#a29e92}.etiqueta{display:inline-block;font:700 .68rem/1 ui-monospace,Menlo,monospace;letter-spacing:.08em;color:#ffb400;border:1px solid #4a3f1f;border-radius:6px;padding:5px 8px;margin:0 0 12px}.tarjeta{background:#14151a;border:1px solid #2a2c31;border-radius:18px;padding:16px;margin:14px 0}label{display:block;margin:10px 0 4px;font-size:.88rem;color:#a29e92}input,select{width:100%;background:#0b0c0e;color:#f3f1ea;border:1px solid #2a2c31;border-radius:12px;padding:11px 12px;font:inherit}button,.boton{display:inline-block;background:#d9b24c;color:#111;border:0;border-radius:12px;padding:12px 18px;font:700 1rem system-ui;cursor:pointer;text-decoration:none}button.sec,.boton.sec{background:#211d12;color:#f0c75a;border:1px solid #4a3f1f}.subpanel{border:1px solid #2a2c31;border-radius:14px;padding:12px;margin:10px 0;background:#0f1013}.modo-sw{display:flex;align-items:center;justify-content:space-between;gap:14px}.modo-sw .modo-txt{display:block;flex:1;min-width:0;color:inherit;text-decoration:none}.modo-sw h2{margin:0 0 6px}.modo-sw p{margin:0 0 6px}button.sw{position:relative;flex:none;width:56px;height:32px;padding:0;border-radius:999px;border:1px solid #4a3f1f;background:#211d12;cursor:pointer}button.sw::after{content:"";position:absolute;top:3px;left:3px;width:24px;height:24px;border-radius:50%;background:#a29e92;transition:left .15s}button.sw[aria-checked="true"]{background:#d9b24c;border-color:#d9b24c}button.sw[aria-checked="true"]::after{left:27px;background:#111}.fila-sw{display:flex;align-items:center;justify-content:space-between;gap:14px;padding:12px 0;border-top:1px solid #2a2c31}.fila-sw:first-child{border-top:0}.fila-sw h2{margin:0 0 2px;font-size:1rem}.lista{background:#14151a;border:1px solid #2a2c31;border-radius:18px;overflow:hidden;margin:14px 0}.lista .item{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:14px 16px;border-top:1px solid #2a2c31;color:inherit;text-decoration:none}.lista .item:first-child{border-top:0}.lista .item::after{content:"\\203A";color:#a29e92;font-size:1.5rem;line-height:1}.lista .item b{display:block}.lista .item small{display:block;margin-top:2px}.lista .item:hover,.lista .item:focus-visible{background:#1a1b21}.ac body{color:#fff}.ac p,.ac small,.ac .suave,.ac label{color:#f3f1ea}.ac .tarjeta,.ac .lista,.ac input,.ac select{border-color:#8a8d95}.ac button.sec,.ac .boton.sec,.ac .atras{border-color:#d9b24c}.ac .lista .item{border-color:#8a8d95}.ab button,.ab .boton,.ab .atras{padding:16px 22px;font-size:1.1rem}.ab button.sw{padding:0;font-size:1rem}.ab .lista .item{padding:18px 16px}a.modo{display:block;color:inherit;text-decoration:none}a.modo h2{display:flex;justify-content:space-between;align-items:center;gap:10px;margin:0 0 6px}a.modo h2::after{content:"Abrir";color:#f0c75a;font-size:.85rem;font-weight:600;border:1px solid #4a3f1f;border-radius:999px;padding:4px 12px;white-space:nowrap}a.modo p{margin:0 0 6px}a.modo:hover,a.modo:focus-visible{border-color:#4a3f1f}.arriba{display:flex;flex-wrap:wrap;gap:8px;margin:0 0 10px}.arriba .atras{margin:0}.atras{display:inline-block;color:#f0c75a;text-decoration:none;border:1px solid #4a3f1f;background:#211d12;border-radius:999px;padding:8px 14px;font:600 .9rem system-ui;margin:0 0 10px}button.chico{padding:7px 12px;font-size:.85rem}button.grande{width:100%;padding:18px;font-size:1.2rem}button:disabled{opacity:.55;cursor:wait}.fila{display:flex;flex-wrap:wrap;gap:10px;align-items:center;justify-content:space-between;padding:10px 0;border-top:1px solid #2a2c31}.botones{display:flex;flex-wrap:wrap;gap:10px;margin:12px 0}.botones.tres button{flex:1 1 0;padding:12px 6px;font-size:.95rem}.fila:first-child{border-top:0}.dos{display:grid;grid-template-columns:1fr 1fr;gap:10px}.ok{color:#57d48a}.mal{color:#e0806a}.pill{display:inline-block;border:1px solid #2a2c31;border-radius:999px;padding:4px 10px;margin:3px 4px 0 0;font-size:.82rem}.pill.si{border-color:#4a3f1f;background:#211d12;color:#f0c75a}#aviso{min-height:1.2em;color:#f0c75a;margin:8px 0}#reloj.urgente{color:#ff5a4d;animation:parpadeo 1s step-end infinite}#reloj.vencido{color:#ff5a4d}@keyframes parpadeo{50%{opacity:.15}}.tarjeta.final{border-color:#ff5a4d;box-shadow:0 0 0 2px rgba(255,90,77,.35)}@media (prefers-reduced-motion:reduce){#reloj.urgente{animation:none}}.modos{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;margin:4px 0 6px}.modos .modo{display:flex;flex-direction:column;align-items:center;gap:4px;padding:10px 4px;font:600 .85rem system-ui}.modos .modo svg{width:30px;height:30px;stroke:currentColor;fill:none;stroke-width:1.8;stroke-linecap:round;stroke-linejoin:round}.modos .modo[aria-checked="false"]{background:#211d12;color:#f0c75a;border:1px solid #4a3f1f}.modos .modo[aria-checked="true"]{background:#d9b24c;color:#111;border:1px solid #d9b24c}.ac .modos .modo[aria-checked="false"]{border-color:#d9b24c}details.tarjeta>summary{cursor:pointer;list-style:none;display:flex;gap:10px;align-items:center;justify-content:space-between}details.tarjeta>summary::-webkit-details-marker{display:none}details.tarjeta>summary h2{margin:0;display:inline}details.tarjeta>summary::after{content:"Abrir";color:#f0c75a;font-size:.85rem;border:1px solid #4a3f1f;border-radius:999px;padding:4px 12px;white-space:nowrap}details.tarjeta[open]>summary::after{content:"Cerrar"}details.tarjeta[open]>summary{margin-bottom:10px}</style>`;

function pldPagina(titulo: string, cuerpo: string) {
  const html = `<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex"><title>${titulo}</title>${PLD_ESTILO}<script>try{var q=JSON.parse(localStorage.getItem("ogAcc")||"{}")||{},r=document.documentElement;if(q.t==="g")r.style.fontSize="118%";if(q.t==="x")r.style.fontSize="136%";if(q.c)r.classList.add("ac");if(q.b)r.classList.add("ab")}catch(e){}</script></head><body><main><img class="logo" src="/marca/logo-correo.png" alt="ojo guard"><span class="etiqueta">N\u00daCLEO \u00b7 EN VALIDACI\u00d3N</span>${cuerpo}</main></body></html>`;
  return new Response(html, { headers: { "content-type": "text/html; charset=utf-8", "cache-control": "no-store", "referrer-policy": "no-referrer" } });
}

/** P\u00e1gina del camino (/camino?t=...): la abre la persona desde el mail, el aviso o su panel. No necesita sesi\u00f3n: el enlace es personal. */
function gdPaginaCamino() {
  return pldPagina("Tu camino \u00b7 Ojo Guard", `
<div class="arriba"><a class="atras" id="atras" href="/guardian">\u2190 Volver a Tu protecci\u00f3n</a><a class="atras" id="aInicio" href="/">Ir al inicio</a></div>
<h1 id="titulo">Tu camino</h1>
<div id="aviso"></div>
<div id="vacio" class="tarjeta" style="display:none"><p style="margin:0 0 12px">Este enlace no sirve: est\u00e1 mal copiado o el camino ya no existe. Abr\u00ed el Modo Guardi\u00e1n desde tu panel para empezar uno nuevo.</p><div class="botones" style="margin:0"><a class="boton" href="/guardian#guardian">Ir a Tu protecci\u00f3n</a><a class="boton sec" href="/">Ir al inicio</a></div></div>
<div id="viaje" style="display:none">
<div class="tarjeta" id="relojCard"><div id="destino" style="font-weight:700;font-size:1.15rem"></div><div id="detalle" class="suave"></div>
<div id="reloj" style="font-size:2.6rem;font-weight:800;margin:14px 0 4px"></div><div id="pausaTxt" style="display:none;color:#f0c75a;font-weight:700;margin:0 0 6px"></div><div id="finalTxt" style="display:none;color:#ff5a4d;font-weight:700;margin:0 0 6px"></div><div id="sonidoAviso" style="display:none;color:#e0806a;font-weight:700;margin:0 0 6px">Toc\u00e1 la pantalla para que suenen los pitidos.</div><div id="estadoTxt"></div></div>
<div class="tarjeta" id="acciones">
<button class="grande" id="bLlegue">Llegu\u00e9</button>
<button class="grande sec" id="bSeguir" style="display:none;margin-top:10px">Ya sigo</button>
<div id="extBloque"><p class="suave" style="margin:16px 0 4px">\u00bfNecesit\u00e1s m\u00e1s tiempo?</p>
<div class="botones tres" style="margin-top:6px"><button class="sec" data-m="10">+10 min</button><button class="sec" data-m="20">+20 min</button><button class="sec" data-m="30">+30 min</button></div></div>
<div class="botones" style="margin-top:6px"><button class="sec" id="bFrenar">Voy a frenar un rato</button><button class="sec" id="bCambiar">Cambiar destino</button></div>
<div id="frenarPanel" class="subpanel" style="display:none"><p class="suave" id="frenarAyuda" style="margin:0 0 6px">\u00bfCu\u00e1nto vas a frenar? El reloj queda en pausa y no les avisamos a tus referentes.</p><div class="botones tres" style="margin:6px 0 0"><button class="sec" data-f="15">15 min</button><button class="sec" data-f="30">30 min</button><button class="sec" data-f="60">1 hora</button></div></div>
<div id="cambiarPanel" class="subpanel" style="display:none"><label style="margin-top:0">C\u00f3mo vas</label>${gdModosHtml("cmModos", "auto")}<label>A d\u00f3nde vas</label><select id="cmLugar"></select>
<div id="cmOtro" style="display:none"><label>Direcci\u00f3n o nombre del lugar</label><input id="cmTexto" maxlength="120" placeholder="Ej.: Kansas Cabildo, o Av. Cabildo 2359" autocomplete="off"><div id="cmSugerencias" class="botones" style="display:none;flex-direction:column;align-items:stretch;gap:6px;margin:8px 0 0"></div><small id="cmAyuda" class="suave"></small></div>
<div id="cmMinBloque" style="display:none"><label>Tiempo hasta ah\u00ed, en minutos</label><input id="cmMin" type="number" min="1" max="300" placeholder="Ej.: 20"></div>
<div class="botones"><button id="cmConfirmar">Cambiar destino</button></div><small class="suave">Recalculamos el tiempo desde donde est\u00e1s ahora.</small></div>
<div class="botones"><button class="sec" id="bAyuda" style="border-color:#e0806a;color:#e0806a">Necesito ayuda</button><button class="sec" id="bCancelar">Cancelar camino</button></div>
<small class="suave">Si no lleg\u00e1s a tiempo y no ped\u00eds m\u00e1s tiempo, les avisamos a tus referentes con tu \u00faltima ubicaci\u00f3n. \u201cNecesito ayuda\u201d les avisa ahora mismo.</small>
</div>
<div class="tarjeta" id="despues" style="display:none"><div class="botones" style="margin:0"><a class="boton" id="bVolver" href="/guardian">Volver a Tu protecci\u00f3n</a><a class="boton sec" id="bOtro" href="/guardian#guardian">Empezar otro camino</a><a class="boton sec" id="bInicio" href="/">Ir al inicio</a></div></div>
<div class="tarjeta" id="sonidoCard"><div class="botones" style="margin-top:0"><button class="sec" id="bSonido">Sonido: activado</button><button class="sec" id="bProbar">Probar sonido</button></div><small class="suave" id="sonidoTxt"></small></div>
</div>
<script>
(function(){
var $=function(i){return document.getElementById(i)};
var t=new URLSearchParams(location.search).get("t")||"";
var V=null,desfase=0,ultimoLimite="",ultimoPitido=0,sonoFinal=false,luz=null,AC=null,pausaVencida=false,POS=null;
var SONIDO=true,VIBRA=true,LUZ=true;try{SONIDO=localStorage.getItem("gdSonido")!=="0";VIBRA=localStorage.getItem("gdVibra")!=="0";LUZ=localStorage.getItem("gdLuz")!=="0"}catch(e){}
function audio(){try{if(!AC){var C=window.AudioContext||window.webkitAudioContext;if(C){AC=new C();try{if(navigator.audioSession)navigator.audioSession.type="playback"}catch(e){}}}if(AC&&AC.state==="suspended")AC.resume()}catch(e){}return AC} // "playback": en iPhone suena aunque el boton de silencio este puesto
function vibrar(ms){if(VIBRA&&navigator.vibrate){try{navigator.vibrate(ms)}catch(e){}}}
function pitido(largo){vibrar(largo?600:80);var a=audio();if(!a||a.state!=="running")return false;try{var o=a.createOscillator(),g=a.createGain();o.type="square";o.frequency.value=largo?660:1000;g.gain.value=largo?0.6:0.5;o.connect(g);g.connect(a.destination);o.start();o.stop(a.currentTime+(largo?0.9:0.14))}catch(e){}return true}
function sonidoListo(){return !!(AC&&AC.state==="running")}
function estadoSonido(){$("bSonido").textContent=SONIDO?"Sonido: activado":"Sonido: apagado";$("sonidoTxt").textContent=SONIDO?("En los \u00faltimos 15 segundos suena un pip por segundo para que no se te pase. La pantalla tiene que estar abierta"+(sonidoListo()?". Toc\u00e1 \u00abProbar sonido\u00bb para comprobar que lo escuch\u00e1s: si el tel\u00e9fono est\u00e1 conectado por Bluetooth (auriculares, parlante o auto), suena ah\u00ed.":" y tocarla una vez para habilitar el sonido.")):"Los pitidos de los \u00faltimos 15 segundos est\u00e1n apagados."}
$("bProbar").onclick=function(){var a=audio(),hecho=0;var sonar=function(){var ok=pitido(false);if(++hecho<3){setTimeout(sonar,350);return}$("sonidoTxt").textContent=sonidoListo()?"Sonaron tres pips (y vibr\u00f3, si tu tel\u00e9fono puede). Si no los escuchaste: sub\u00ed el volumen de contenido, fijate que el tel\u00e9fono no est\u00e9 conectado por Bluetooth (auriculares, parlante o auto: suena ah\u00ed) y, en iPhone, que el bot\u00f3n de silencio est\u00e9 apagado.":"El navegador todav\u00eda no dej\u00f3 que suene. Toc\u00e1 \u00abProbar sonido\u00bb otra vez."};var p=a&&a.resume?a.resume():null;if(p&&p.then)p.then(function(){setTimeout(sonar,60)},function(){sonar()});else setTimeout(sonar,120)};
function pantallaEncendida(){try{if(LUZ&&!luz&&navigator.wakeLock&&document.visibilityState==="visible"&&V&&(V.estado==="en_camino"||V.estado==="aviso")){navigator.wakeLock.request("screen").then(function(l){luz=l;l.addEventListener("release",function(){luz=null})}).catch(function(){})}}catch(e){}}
["pointerdown","touchstart","keydown"].forEach(function(e){document.addEventListener(e,function(){if(SONIDO)audio();estadoSonido()},{passive:true})});
document.addEventListener("visibilitychange",pantallaEncendida);
function aviso(x){$("aviso").textContent=x||""}
function api(c){c.t=t;return fetch("/api/guardian",{method:"POST",headers:{"content-type":"application/json"},body:JSON.stringify(c),credentials:"same-origin"}).then(function(r){return r.json().then(function(d){if(!r.ok){var e=new Error(d.error||"error");e.codigo=d.error;e.fallo=d.fallo;throw e}return d})})}
function hora(s){try{return new Date(s).toLocaleTimeString("es-AR",{timeZone:"America/Argentina/Buenos_Aires",hour:"2-digit",minute:"2-digit",hour12:false})}catch(e){return s}}
function reloj(ms){var s=Math.max(0,Math.floor(ms/1000));var h=Math.floor(s/3600),m=Math.floor((s%3600)/60),x=s%60;function d(n){return(n<10?"0":"")+n}return h>0?h+" h "+d(m)+" min":d(m)+":"+d(x)}
function enPausa(){return !!(V&&V.pausa&&Date.parse(V.pausa.hasta)>Date.now()+desfase)}
function pintar(d){
  V=d.viaje;desfase=Date.parse(d.ahora)-Date.now();pausaVencida=false;
  if(!V){$("vacio").style.display="block";$("viaje").style.display="none";return}
  $("vacio").style.display="none";$("viaje").style.display="block";
  $("destino").textContent="Vas a "+V.destino;
  $("detalle").textContent=V.modoTexto.charAt(0).toUpperCase()+V.modoTexto.slice(1)+" \u00b7 "+V.estimadoMin+" min + "+V.margenMin+" de margen";
  var activo=V.estado==="en_camino"||V.estado==="aviso"||V.estado==="alerta";
  $("acciones").style.display=activo?"block":"none";
  $("extBloque").style.display=V.extensionesMax>0&&!enPausa()?"block":"none";
  $("bSeguir").style.display=activo&&enPausa()?"block":"none";
  $("despues").style.display=activo?"none":"block";
  var botones=document.querySelectorAll("button[data-m]");
  Array.prototype.forEach.call(botones,function(b){b.disabled=!V.puedeExtender});
  $("bFrenar").style.display=V.paradasMax>0&&V.puedeCambiar?"inline-block":"none";$("bFrenar").disabled=!V.puedeParar;$("bFrenar").textContent=V.puedeParar?(enPausa()?"Frenar m\u00e1s tiempo":"Voy a frenar un rato"):"Ya frenaste "+V.paradasMax+(V.paradasMax===1?" vez":" veces");
  $("bCambiar").style.display=V.puedeCambiar?"inline-block":"none";
  $("frenarAyuda").textContent=(enPausa()?"\u00bfCu\u00e1nto m\u00e1s quer\u00e9s frenar? La pausa se alarga. ":"\u00bfCu\u00e1nto vas a frenar? El reloj queda en pausa. ")+"No les avisamos a tus referentes. Pod\u00e9s frenar "+(V.paradasMax===1?"1 vez":"hasta "+V.paradasMax+" veces")+(V.paradas>0?" (ya usaste "+V.paradas+")":"")+".";
  if(!V.puedeCambiar){$("frenarPanel").style.display="none";$("cambiarPanel").style.display="none"}
  $("bCancelar").style.display=V.estado==="alerta"?"none":"inline-block";
  var tx={en_camino:"Ten\u00e9s que llegar antes de las "+hora(V.deadlineAt)+"."+(V.ajusteAutoMin>0?" Sumamos "+V.ajusteAutoMin+" minutos por tr\u00e1nsito.":"")+" Cuando llegues, toc\u00e1 Llegu\u00e9.",aviso:"\u00bfSegu\u00eds en camino? Si no respond\u00e9s, les avisamos a tus referentes.",alerta:"Ya les avisamos a tus referentes. Toc\u00e1 Llegu\u00e9 cuando est\u00e9s bien.",llego:"Llegaste bien. \u00a1Gracias por avisar!",cancelado:"Camino cancelado.",cerrado:"Este camino se cerr\u00f3 solo."}[V.estado]||"";
  if(enPausa()&&V.estado==="en_camino")tx="En pausa hasta las "+hora(V.pausa.hasta)+". Cuando termine, el reloj sigue con los "+Math.ceil(V.pausa.restaMs/60000)+" minutos que te quedaban. No les avisamos a tus referentes.";
  var f=V.fin;
  if(V.estado==="llego"&&f){var n=Math.abs(f.despuesMin);tx="Tocaste Llegu\u00e9 a las "+f.hora+": "+(f.despuesMin===0?"justo en el l\u00edmite":n+(n===1?" minuto ":" minutos ")+(f.despuesMin<0?"antes":"despu\u00e9s")+" del l\u00edmite")+" ("+f.limiteHora+"). Tardaste "+f.duracionMin+" min; el c\u00e1lculo era de "+V.estimadoMin+" min + "+V.margenMin+" de margen"+(f.extraMin>0?" + "+f.extraMin+" que pediste":"")+(f.autoMin>0?" + "+f.autoMin+" por tr\u00e1nsito":"")+(f.paradaMin>0?" + "+f.paradaMin+" de parada":"")+"."}
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
  if(!activo){$("reloj").textContent=V.estado==="llego"?"Listo":"";$("reloj").style.opacity="1";$("reloj").className="";$("relojCard").className="tarjeta";$("finalTxt").style.display="none";$("pausaTxt").style.display="none";$("sonidoAviso").style.display="none";return}
  if(V.pausa&&!enPausa()&&!pausaVencida){pausaVencida=true;refrescar()} // se termino la pausa: el reloj sigue
  if(enPausa()){ // frenado: el reloj no baja, queda con lo que le faltaba
    $("reloj").textContent=reloj(V.pausa.restaMs);$("reloj").style.opacity=".55";
    $("reloj").className="";$("relojCard").className="tarjeta";$("finalTxt").style.display="none";$("sonidoAviso").style.display="none";$("pausaTxt").style.display="block";$("pausaTxt").textContent="EN PAUSA \u00b7 termina a las "+hora(V.pausa.hasta)+" (en "+reloj(Date.parse(V.pausa.hasta)-(Date.now()+desfase))+")";
    return}
  $("reloj").style.opacity="1";$("pausaTxt").style.display="none";
  var ms=Date.parse(V.deadlineAt)-(Date.now()+desfase);
  $("sonidoAviso").style.display=SONIDO&&ms>0&&ms<=60000&&!sonidoListo()?"block":"none";
  var urg=ms>0&&ms<=15000,ven=ms<=0; // ultimos 15 segundos: el reloj parpadea en rojo (no depende del sonido); despues, queda rojo
  $("reloj").className=urg?"urgente":ven?"vencido":"";$("relojCard").className=urg||ven?"tarjeta final":"tarjeta";
  $("finalTxt").style.display=urg?"block":"none";if(urg)$("finalTxt").textContent="Se termina el tiempo: toc\u00e1 Llegu\u00e9"+(V.puedeExtender?" o ped\u00ed m\u00e1s tiempo":"")+".";
  $("reloj").textContent=ms>0?reloj(ms):"Se pas\u00f3 el tiempo";
  if(SONIDO&&(V.estado==="en_camino"||V.estado==="aviso")){
    if(ms>0&&ms<=15000){var seg=Math.ceil(ms/1000);if(seg!==ultimoPitido){ultimoPitido=seg;pitido(false)}}
    else if(ms<=0&&!sonoFinal){sonoFinal=true;pitido(true)}
  }
}
function errorDe(e){return({ya_se_aviso:"Ya les avisamos a tus referentes: toc\u00e1 Llegu\u00e9 cuando est\u00e9s bien.",demasiadas_extensiones:"Ya extendiste el m\u00e1ximo de veces: toc\u00e1 Llegu\u00e9 o ped\u00ed ayuda.",demasiadas_paradas:"Ya frenaste el m\u00e1ximo de veces: toc\u00e1 Llegu\u00e9 o ped\u00ed ayuda.",sin_pausa:"Ya no estabas en pausa.",destino_muy_lejos:"Ese lugar queda a m\u00e1s de 5 horas: revis\u00e1 la direcci\u00f3n.",lugar_invalido:"Ese lugar no existe.",modo_invalido:"Eleg\u00ed c\u00f3mo vas.",destino_invalido:"Eleg\u00ed de nuevo la direcci\u00f3n.",falta_destino:"Escrib\u00ed a d\u00f3nde vas.",sin_extensiones:"En la configuraci\u00f3n del Modo Guardi\u00e1n no se puede pedir m\u00e1s tiempo.",enlace_invalido:"Este enlace no sirve.",camino_terminado:"Este camino ya termin\u00f3."})[e.codigo]||"No se pudo. Prob\u00e1 de nuevo."}
function hacer(c,ok){aviso("");return api(c).then(function(d){pintar(d);if(ok)aviso(ok)}).catch(function(e){aviso(errorDe(e))})}
$("bSonido").onclick=function(){SONIDO=!SONIDO;try{localStorage.setItem("gdSonido",SONIDO?"1":"0")}catch(e){}if(SONIDO)audio();estadoSonido()};
$("bLlegue").onclick=function(){hacer({accion:"llegue"},"Listo: avisamos que llegaste bien.")};
Array.prototype.forEach.call(document.querySelectorAll("button[data-m]"),function(b){b.onclick=function(){hacer({accion:"extender",minutos:Number(b.getAttribute("data-m"))},"Listo: ten\u00e9s "+b.getAttribute("data-m")+" minutos m\u00e1s.")}});
$("bAyuda").onclick=function(){if(confirm("\u00bfPedir ayuda? Les avisamos ahora mismo a tus referentes, con tu \u00faltima ubicaci\u00f3n."))hacer({accion:"ayuda"},"Les avisamos a tus referentes.")};
$("bCancelar").onclick=function(){if(confirm("\u00bfCancelar el camino? No se les avisa a tus referentes."))hacer({accion:"cancelar"})};
function limpiar(n){while(n.firstChild)n.removeChild(n.firstChild)}
$("bFrenar").onclick=function(){$("cambiarPanel").style.display="none";$("frenarPanel").style.display=$("frenarPanel").style.display==="none"?"block":"none"};
Array.prototype.forEach.call(document.querySelectorAll("button[data-f]"),function(b){b.onclick=function(){var n=Number(b.getAttribute("data-f")),mas=enPausa(),txt=n===60?"1 hora":n+" minutos";$("frenarPanel").style.display="none";hacer({accion:"parada",minutos:n},mas?"Listo: la pausa se alarg\u00f3 "+txt+".":"Listo: el reloj queda en pausa "+txt+". No les avisamos a tus referentes.")}});
$("bSeguir").onclick=function(){hacer({accion:"seguir"},"Listo: segu\u00eds en camino. El reloj sigue con lo que te quedaba.")};
var CMPLACE="",CMETIQUETA="",CMHAYSUG=false,CMTIMER=null,CMLUGARES=null;
function cmCambio(){$("cmOtro").style.display=$("cmLugar").value?"none":"block"}
function modosPoner(g,v){Array.prototype.forEach.call($(g).querySelectorAll("button.modo"),function(b){b.setAttribute("aria-checked",b.getAttribute("data-modo")===v?"true":"false")})}
function modosValor(g){var b=$(g).querySelector(''button.modo[aria-checked="true"]'');return b?b.getAttribute("data-modo"):"auto"}
Array.prototype.forEach.call($("cmModos").querySelectorAll("button.modo"),function(b){b.onclick=function(){modosPoner("cmModos",b.getAttribute("data-modo"))}});
function cmOpcion(v,t){var o=document.createElement("option");o.value=v;o.textContent=t;$("cmLugar").appendChild(o)}
function cmArmarOpciones(){limpiar($("cmLugar"));if(V&&V.destinoExacto)cmOpcion("__mismo","Seguir yendo a "+V.destino);(CMLUGARES||[]).forEach(function(l){cmOpcion(l.id,l.name)});cmOpcion("","Otro lugar\u2026");cmCambio()}
function cmCargarLugares(){if(CMLUGARES){cmArmarOpciones();return}api({accion:"lugares"}).then(function(d){CMLUGARES=d.lugares||[];cmArmarOpciones()}).catch(function(){CMLUGARES=[];cmArmarOpciones()})}
$("bCambiar").onclick=function(){$("frenarPanel").style.display="none";var abrir=$("cambiarPanel").style.display==="none";$("cambiarPanel").style.display=abrir?"block":"none";if(abrir){modosPoner("cmModos",V?V.modo:"auto");cmCargarLugares();ubicar(function(){})}};
$("cmLugar").onchange=cmCambio;
// donde esta la persona AHORA: la ubicacion del navegador de su telefono (se pide al abrir "Cambiar destino" y otra vez al confirmar); sirve para ordenar las sugerencias y para recalcular desde ahi
function ubicar(cb){if(POS&&Date.now()-POS.en<20000){cb(POS);return}
  var hecho=false,fin=function(o){if(!hecho){hecho=true;if(o)POS=o;cb(o)}};
  try{navigator.geolocation.getCurrentPosition(function(p){fin({lat:p.coords.latitude,lng:p.coords.longitude,precision:p.coords.accuracy,en:Date.now()})},function(){fin(null)},{enableHighAccuracy:true,timeout:10000,maximumAge:15000});setTimeout(function(){fin(null)},11000)}catch(e){fin(null)}}
function desde(o){return o&&o.fuente==="navegador"?" desde donde est\u00e1s ahora":o&&o.fuente==="telefono"?" desde la \u00faltima ubicaci\u00f3n de tu tel\u00e9fono (hace "+(o.haceMin||0)+" min)":""}
function cmSugerir(){var q=$("cmTexto").value.trim();var caja=$("cmSugerencias");limpiar(caja);caja.style.display="none";$("cmAyuda").textContent="";if(q.length<3){CMHAYSUG=false;return}
  $("cmAyuda").textContent="Buscando\u2026";
  var pedido={accion:"buscar",texto:q};if(POS)pedido.origen={lat:POS.lat,lng:POS.lng,precision:POS.precision};
  api(pedido).then(function(d){if($("cmTexto").value.trim()!==q)return;var lista=d.sugerencias||[];CMHAYSUG=lista.length>0;
    if(!lista.length){$("cmAyuda").textContent=d.fallo&&d.fallo!=="sin_clave"?"No pudimos buscar. Prob\u00e1 con otro nombre o escrib\u00ed la direcci\u00f3n completa.":"";return}
    lista.forEach(function(sg){var b=document.createElement("button");b.type="button";b.className="sec";b.style.textAlign="left";b.style.width="100%";b.textContent=sg.principal+(sg.secundario?" \u00b7 "+sg.secundario:"")+(sg.km!==null&&sg.km!==undefined?" \u00b7 a "+String(sg.km).replace(".",",")+" km":"");
      b.onclick=function(){CMPLACE=sg.placeId;CMETIQUETA=(sg.principal+(sg.secundario?", "+sg.secundario:"")).slice(0,80);$("cmTexto").value=CMETIQUETA;limpiar(caja);caja.style.display="none";$("cmAyuda").textContent="Elegiste: "+CMETIQUETA};caja.appendChild(b)});
    caja.style.display="flex";$("cmAyuda").textContent="Eleg\u00ed el lugar correcto."}).catch(function(){})}
$("cmTexto").oninput=function(){CMPLACE="";CMETIQUETA="";clearTimeout(CMTIMER);CMTIMER=setTimeout(cmSugerir,400)};
$("cmConfirmar").onclick=function(){
  var c={accion:"cambiar",modo:modosValor("cmModos")};
  if($("cmLugar").value==="__mismo"){c.mismo=true}else if($("cmLugar").value){c.lugarId=$("cmLugar").value}else if(CMPLACE){c.placeId=CMPLACE;c.texto=CMETIQUETA}else{c.texto=$("cmTexto").value.trim();if(!c.texto){aviso("Eleg\u00ed o escrib\u00ed el nuevo destino.");return}if(CMHAYSUG){aviso("Eleg\u00ed uno de los lugares que te sugerimos, as\u00ed sabemos bien a d\u00f3nde vas.");return}}
  if($("cmMinBloque").style.display!=="none")c.minutos=Number($("cmMin").value)||0;
  var boton=$("cmConfirmar"),listo=function(){boton.disabled=false;boton.textContent="Cambiar destino"};
  var enviar=function(){aviso("");api(c).then(function(d){listo();pintar(d);$("cambiarPanel").style.display="none";$("cmMinBloque").style.display="none";var det=d.minutos?" ("+d.minutos+" min "+({auto:"en auto",transporte:"en transporte p\u00fablico",caminando:"caminando"})[d.modo]+(d.km!==null&&d.km!==undefined?", "+String(d.km).replace(".",",")+" km":"")+")":"";aviso((c.mismo?"Listo: segu\u00eds yendo a "+V.destino:"Listo: cambiamos el destino")+det+" y recalculamos el tiempo"+desde(d.origen)+".")}).catch(function(e){listo();if(e.codigo==="faltan_minutos"){$("cmMinBloque").style.display="block";aviso(e.fallo==="ubicacion_vieja"||e.fallo==="sin_ubicacion"?"No sabemos d\u00f3nde est\u00e1s ahora: permit\u00ed la ubicaci\u00f3n en el navegador o pon\u00e9 cu\u00e1ntos minutos tard\u00e1s.":"No pudimos calcular el tiempo hasta ah\u00ed: pon\u00e9 cu\u00e1ntos minutos tard\u00e1s.")}else aviso(errorDe(e))})};
  boton.disabled=true;boton.textContent="Buscando tu ubicaci\u00f3n\u2026";
  ubicar(function(o){if(o)c.origen={lat:o.lat,lng:o.lng,precision:o.precision};enviar()})};
function refrescar(){api({accion:"estado"}).then(pintar).catch(function(e){if(e.codigo==="enlace_invalido"){$("vacio").style.display="block";$("viaje").style.display="none"}})}
refrescar();setInterval(refrescar,20000);setInterval(tick,1000);
})();
</script>`);
}

/** P\u00e1gina del due\u00f1o (/guardian y /por-las-dudas): tus referentes y los modos. */
function pldPaginaDuenio() {
  return pldPagina("Tu protecci\u00f3n \u00b7 Ojo Guard", `
<div class="arriba"><a class="atras" id="aInicio" href="/">\u2190 Ir al inicio</a><a class="atras" id="aHub" href="#" style="display:none">\u2190 Tu protecci\u00f3n</a></div>
<h1 id="titulo">Tu protecci\u00f3n</h1>
<div id="aviso"></div>
<div id="sinSesion" class="tarjeta" style="display:none"><h2>Falta entrar al panel</h2><p>Para ver y cambiar tus referentes ten\u00e9s que entrar al panel de Ojo Guard MS con tu cuenta, <b>en este mismo navegador</b>. Entr\u00e1, y despu\u00e9s volv\u00e9 a esta p\u00e1gina.</p><p><a class="boton" href="/acceso-v7">Entrar al panel</a> <button class="sec" onclick="location.reload()">Ya entr\u00e9, probar de nuevo</button></p></div>
<div id="contenido" style="opacity:.4;pointer-events:none">
<div id="paraQuien" class="tarjeta" style="display:none"><label style="margin-top:0">Est\u00e1s viendo la protecci\u00f3n de</label><select id="persona"></select></div>
<div id="soloLectura" class="tarjeta" style="display:none"><p style="margin:0"><b>Esto lo completa el administrador de tu familia.</b> Ac\u00e1 pod\u00e9s ver c\u00f3mo est\u00e1 armada tu protecci\u00f3n, pero no cambiarla.</p></div>
<div id="enNombreDe" class="tarjeta" style="display:none"></div>
<div id="vInicio">
<div id="avisoRef" class="tarjeta" style="display:none"><p style="margin:0 0 10px">Falta elegir al menos un referente: son las personas de confianza que se enteran si algo te pasa.</p><a class="boton" href="#config-referentes">Elegir referentes</a></div>
<div class="tarjeta modo-sw" id="tCautela"><a class="modo-txt" href="#cautela"><h2>Modo Cautela</h2><p>Por las dudas: si dejo de responder, mis referentes se enteran.</p><small id="tCautelaEstado" class="suave"></small></a><button class="sw" id="swCautelaInicio" role="switch" aria-checked="true" aria-label="Modo Cautela"></button></div>
<a class="tarjeta modo" id="tGuardian" href="#guardian"><h2>Modo Guardi\u00e1n</h2><p>Te acompa\u00f1a en el camino: si no lleg\u00e1s a tiempo, les avisa a tus referentes.</p><small id="tGuardianEstado" class="suave"></small></a>
<a class="tarjeta modo" id="tConfig" href="#configuracion"><h2>Configuraci\u00f3n</h2><p>Referentes, tiempos y avisos, ajustes y accesibilidad.</p></a>
</div>
<div id="vCautela" style="display:none">
<div class="tarjeta"><div class="fila-sw" style="border:0;padding:0"><div><h2>Modo Cautela</h2><div id="estadoModo" class="suave"></div></div><button class="sw" id="cEncender" role="switch" aria-checked="true" aria-label="Modo Cautela"></button></div>
<p class="suave" style="margin:12px 0 0">Por las dudas: si dejo de responder, mis referentes se enteran. Funciona de fondo y solo ven tu <b>\u00faltima se\u00f1al</b> si se cumplen las condiciones. Si lo apag\u00e1s no se manda ning\u00fan aviso autom\u00e1tico; el SOS sigue avisando.</p>
<p class="suave" id="refLineaC" style="margin:8px 0 0"></p></div>
<div class="tarjeta"><h2>Pausar los avisos</h2>
<p style="margin-top:0">Por un rato, por ejemplo si dorm\u00eds en otro lado. Cuando termina el tiempo, el Modo Cautela se prende solo. El SOS sigue avisando a tus referentes.</p>
<label>Pausar por</label><div class="botones tres" style="margin-top:6px"><button class="sec" data-h="8">8 horas</button><button class="sec" data-h="12">12 horas</button><button class="sec" data-h="24">24 horas</button></div>
<div class="dos"><div><label>Otro tiempo (horas, de 1 a 72)</label><input id="pHoras" type="number" min="1" max="72" placeholder="Ej.: 36"></div><div><label>&nbsp;</label><button class="sec" id="pOtro">Pausar ese tiempo</button></div></div>
<p><button class="sec" data-h="0">Quitar pausa</button></p><div id="pausa" class="suave"></div></div>
<a class="tarjeta modo" href="#config-cautela"><h2>Condiciones y estado del tel\u00e9fono</h2><p>Cu\u00e1ndo se avisa, qu\u00e9 se mira y c\u00f3mo est\u00e1 tu tel\u00e9fono hoy.</p></a>
</div>
<div id="vGuardian" style="display:none">
<div id="gdSeccion">
<p class="suave" style="margin:0 0 6px">Te acompa\u00f1a en el camino: eleg\u00eds a d\u00f3nde vas y cu\u00e1nto tard\u00e1s, y si no lleg\u00e1s a tiempo les avisa a tus referentes con tu \u00faltima ubicaci\u00f3n.</p>
<p class="suave" id="refLineaG" style="margin:0 0 6px"></p>
<div class="tarjeta" id="guardianCard"><div id="gdCarga" class="suave">Cargando\u2026</div>
<div id="gdActivo" style="display:none"><p id="gdActivoTxt" style="margin-top:0"></p><div class="botones"><a class="boton" id="gdAbrir" href="#">Abrir mi camino</a></div></div>
<div id="gdForm" style="display:none">
<label style="margin-top:0">A d\u00f3nde vas</label><select id="gdLugar"></select>
<div id="gdOtro" style="display:none"><label>Direcci\u00f3n o nombre del lugar</label><input id="gdTexto" maxlength="120" placeholder="Ej.: Kansas Cabildo, o Av. Cabildo 2359" autocomplete="off"><div id="gdSugerencias" class="botones" style="display:none;flex-direction:column;align-items:stretch;gap:6px;margin:8px 0 0"></div><small id="gdAyudaDir" class="suave"></small></div>
<label>C\u00f3mo vas</label>${gdModosHtml("gdModo", "auto")}
<label>Tiempo del camino, en minutos <span class="suave" id="gdAyudaMin"></span></label><input id="gdMin" type="number" min="1" max="300" placeholder="Ej.: 20">
<div class="botones"><button id="gdEmpezar">Empezar camino</button></div>
<small class="suave" id="gdPie">Ten\u00e9s 2 minutos de margen. Si no lleg\u00e1s ni ped\u00eds m\u00e1s tiempo, les avisamos a tus referentes. Pod\u00e9s extender 10, 20 o 30 minutos, hasta 3 veces.</small>
</div>
<div id="gdSinRef" style="display:none"><p class="suave" style="margin:0">Para usar el Modo Guardi\u00e1n ten\u00e9s que tener al menos un referente que haya aceptado. Elegilo en <a href="#config-referentes" style="color:#f0c75a">Referentes</a>.</p></div>
</div>
</div>
</div>
<div id="vConfig" style="display:none">
<p class="suave" style="margin-top:0">Ac\u00e1 est\u00e1 lo que se cambia de vez en cuando. Todo viene con valores recomendados; lo de todos los d\u00edas est\u00e1 en cada modo.</p>
<div class="lista">
<a class="item" href="#config-referentes"><span><b>Referentes</b><small id="cfRef" class="suave"></small></span></a>
<a class="item" href="#config-cautela"><span><b>Modo Cautela</b><small class="suave">Condiciones y estado del tel\u00e9fono</small></span></a>
<a class="item" id="cfGuardianFila" href="#config-guardian"><span><b>Modo Guardi\u00e1n</b><small class="suave">Margen de tiempo y avisos</small></span></a>
<a class="item" href="#config-ajustes"><span><b>Ajustes</b><small class="suave">C\u00f3mo te llaman tus referentes</small></span></a>
<a class="item" href="#config-accesibilidad"><span><b>Accesibilidad</b><small class="suave">Texto, contraste, sonido</small></span></a>
<a class="item" href="#config-registro"><span><b>Registro</b><small class="suave">Lo que fue pasando</small></span></a>
</div>
</div>
<div id="vCfgRef" style="display:none">
<p style="margin-top:0">Eleg\u00ed una vez a las personas de confianza, tus <b>referentes</b>: se enteran si algo te pasa. Valen para el SOS y para los dos modos.</p>
<div class="tarjeta"><div id="referentes" class="suave">Cargando\u2026</div>
<label>Nombre</label><input id="rNombre" maxlength="60" placeholder="Mam\u00e1"><label>Correo</label><input id="rCorreo" type="email" placeholder="mama@correo.com">
<p><button id="rAgregar">Elegir referente</button></p><div id="invitacion"></div><small class="suave">Hasta 5. Le llega un mail con su enlace personal y tiene que aceptar. Si apret\u00e1s el SOS, tambi\u00e9n se les avisa a ellos.</small>
<p id="dondeBoton" class="suave"><b>\u00bfD\u00f3nde est\u00e1 el bot\u00f3n \u201cNo lo encuentro\u201d?</b> Lo ve solo tu referente, en su enlace personal, despu\u00e9s de aceptar. Vos no ten\u00e9s que apretar nada. Para probarlo, abr\u00ed su enlace en otro navegador (o en una ventana privada) y acept\u00e1.</p></div>
</div>
<div id="vCfgCaut" style="display:none">
<p class="suave" style="margin-top:0">Un referente solo ve tu \u00faltima se\u00f1al si se cumplen al menos estas se\u00f1ales a la vez. Cuando se cumplen, te mandamos un \u201c\u00bfEst\u00e1s bien?\u201d (mail y aviso en el tel\u00e9fono) y, si en unos 15 minutos no respond\u00e9s, les avisamos a tus referentes por mail.</p>
<div class="tarjeta"><h2>Estado de tu tel\u00e9fono</h2><small id="hoyResumen" class="suave" style="display:block;margin:-6px 0 8px"></small><div id="hoy" class="suave">Cargando\u2026</div></div>
<div class="tarjeta"><h2>Condiciones</h2>
<div class="dos"><div><label>De noche desde (hora)</label><input id="cDesde" type="number" min="0" max="23"></div><div><label>hasta (hora)</label><input id="cHasta" type="number" min="0" max="23"></div></div>
<div class="dos"><div><label>Sin se\u00f1al de noche (min)</label><input id="cSilNoche" type="number" min="10"></div><div><label>Sin se\u00f1al de d\u00eda (min)</label><input id="cSilDia" type="number" min="10"></div></div>
<div class="dos"><div><label>Lejos de casa (km)</label><input id="cKm" type="number" min="0.5" step="0.5"></div><div><label>Bater\u00eda baja (%)</label><input id="cBat" type="number" min="1" max="50"></div></div>
<div class="dos"><div><label>Se\u00f1ales necesarias (de 4)</label><select id="cMin"><option>2</option><option>3</option><option>4</option></select></div><div><label>Emergencia tras (horas)</label><input id="cEmer" type="number" min="1" max="48"></div></div>
<div class="botones"><button id="cGuardar">Guardar condiciones</button><button class="sec" id="cCasa">Mi casa es donde est\u00e1 mi tel\u00e9fono ahora</button></div><div id="casa" class="suave"></div>
<p style="margin-bottom:0"><button class="sec" id="cReset">Volver a los valores recomendados</button> <small class="suave" id="cRecomendado" style="display:block;margin-top:6px"></small></p></div>
</div>
<div id="vCfgGuard" style="display:none">
<p class="suave" style="margin-top:0">El Modo Guardi\u00e1n viene con valores recomendados. Si quer\u00e9s, los cambi\u00e1s ac\u00e1. Lo de todos los d\u00edas (a d\u00f3nde vas, c\u00f3mo vas, cu\u00e1nto tard\u00e1s) est\u00e1 en el Modo Guardi\u00e1n.</p>
<div id="gdCfgBloqueo" class="tarjeta" style="display:none"><p style="margin:0">Hay un camino en marcha. Los tiempos y avisos se cambian cuando termine.</p></div>
<div class="tarjeta"><h2>Tiempos</h2>
<label>Margen extra: minutos que se suman a lo que tard\u00e1s</label><input id="gMargen" type="number" min="1" max="15">
<label>Preguntarme \u201c\u00bfSegu\u00eds en camino?\u201d cuando falten (min)</label><input id="gAviso" type="number" min="1" max="10">
<label>Veces que puedo pedir m\u00e1s tiempo (0 = ninguna)</label><input id="gExt" type="number" min="0" max="5">
<label>Sumar tiempo si hay m\u00e1s tr\u00e1nsito, hasta (min; 0 = no sumar)</label><input id="gAuto" type="number" min="0" max="180">
<small class="suave" style="display:block;margin-top:6px">Solo cuando te ven\u00eds acercando y faltan pocos minutos: si el tr\u00e1nsito te hace tardar m\u00e1s, sumamos ese atraso al l\u00edmite. Si est\u00e1s frenado, no suma nada.</small></div>
<div class="tarjeta"><h2>Avisos a tus referentes si no lleg\u00e1s</h2>
<label>Repetir el aviso cada (min)</label><input id="gEntre" type="number" min="5" max="60">
<label>Cantidad m\u00e1xima de avisos</label><input id="gMaxAv" type="number" min="1" max="5">
<small class="suave" style="display:block;margin-top:8px">El primer aviso sale cuando se pasa el tiempo y despu\u00e9s se repite hasta ese m\u00e1ximo. Si toc\u00e1s \u201cLlegu\u00e9\u201d, dejan de salir.</small></div>
<div class="botones"><button id="gGuardar">Guardar</button><button class="sec" id="gReset">Volver a los valores recomendados</button></div>
<small class="suave" id="gRecomendado"></small>
</div>
<div id="vCfgAjustes" style="display:none">
<div class="tarjeta"><h2>C\u00f3mo te llaman tus referentes</h2><p class="suave" style="margin-top:0">El nombre con el que aparec\u00e9s en los avisos y mails.</p><input id="cNombre" maxlength="60"><div class="botones" style="margin-bottom:0"><button id="cNombreGuardar">Guardar nombre</button></div></div>
<div class="tarjeta"><h2>Acerca de Tu protecci\u00f3n</h2><p class="suave" style="margin:0">Esta funci\u00f3n est\u00e1 en validaci\u00f3n: ya la probamos de punta a punta con mails reales, pero todav\u00eda no en el d\u00eda a d\u00eda.</p></div>
</div>
<div id="vCfgAcc" style="display:none">
<p class="suave" style="margin-top:0">Estos ajustes se guardan en este tel\u00e9fono (o navegador) y valen para todas las pantallas de Ojo Guard. No cambian nada de lo que ven tus referentes.</p>
<div class="tarjeta"><h2>Tama\u00f1o del texto</h2><div class="botones tres" style="margin-bottom:0"><button data-t="">Normal</button><button class="sec" data-t="g">Grande</button><button class="sec" data-t="x">Muy grande</button></div></div>
<div class="tarjeta">
<div class="fila-sw"><div><h2>Alto contraste</h2><small class="suave">Letras m\u00e1s claras y bordes m\u00e1s marcados.</small></div><button class="sw" id="aaContraste" role="switch" aria-checked="false" aria-label="Alto contraste"></button></div>
<div class="fila-sw"><div><h2>Botones m\u00e1s grandes</h2><small class="suave">M\u00e1s f\u00e1ciles de tocar.</small></div><button class="sw" id="aaBotones" role="switch" aria-checked="false" aria-label="Botones m\u00e1s grandes"></button></div></div>
<div class="tarjeta"><h2>Cuando vas en camino</h2>
<div class="fila-sw"><div><h2>Sonido de la cuenta regresiva</h2><small class="suave">Un pip por segundo en los \u00faltimos 15 segundos.</small></div><button class="sw" id="aaSonido" role="switch" aria-checked="true" aria-label="Sonido de la cuenta regresiva"></button></div>
<div class="fila-sw"><div><h2>Vibraci\u00f3n</h2><small class="suave">Vibra con cada pip.</small></div><button class="sw" id="aaVibra" role="switch" aria-checked="true" aria-label="Vibraci\u00f3n"></button></div>
<div class="fila-sw"><div><h2>Mantener la pantalla encendida</h2><small class="suave">Mientras hay un camino en marcha.</small></div><button class="sw" id="aaLuz" role="switch" aria-checked="true" aria-label="Mantener la pantalla encendida"></button></div></div>
</div>
<div id="vCfgReg" style="display:none">
<div class="tarjeta"><div id="registro" class="suave">Cargando\u2026</div></div>
</div>
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
var VISTAS={"":"vInicio",cautela:"vCautela",guardian:"vGuardian",configuracion:"vConfig","config-referentes":"vCfgRef","config-cautela":"vCfgCaut","config-guardian":"vCfgGuard","config-ajustes":"vCfgAjustes","config-accesibilidad":"vCfgAcc","config-registro":"vCfgReg"};
var TITULOS={"":"Tu protecci\u00f3n",cautela:"Modo Cautela",guardian:"Modo Guardi\u00e1n",configuracion:"Configuraci\u00f3n","config-referentes":"Referentes","config-cautela":"Modo Cautela","config-guardian":"Modo Guardi\u00e1n","config-ajustes":"Ajustes","config-accesibilidad":"Accesibilidad","config-registro":"Registro"};
var PADRES={cautela:"",guardian:"",configuracion:"","config-referentes":"configuracion","config-cautela":"configuracion","config-guardian":"configuracion","config-ajustes":"configuracion","config-accesibilidad":"configuracion","config-registro":"configuracion"};
var PROPIA=true,RO=false,NOMBREPERSONA="",DEF=null,GDDEF=null;
function vistaActual(){var h=(location.hash||"").replace(/^#/,"");if(h==="gdSeccion")h="guardian";if(h==="tus-referentes")h="config-referentes";if(!Object.prototype.hasOwnProperty.call(VISTAS,h))h="";if(!PROPIA&&h==="guardian")h="";if(!PROPIA&&h==="config-guardian")h="configuracion";return h}
function titulo(){var v=vistaActual();var t=TITULOS[v];if(NOMBREPERSONA)t=v?t+" \u00b7 "+NOMBREPERSONA:"Protecci\u00f3n de "+NOMBREPERSONA;$("titulo").textContent=t}
function mostrarVista(arriba){var v=vistaActual();Object.keys(VISTAS).forEach(function(k){$(VISTAS[k]).style.display=k===v?"block":"none"});var h=$("aHub"),p=PADRES[v];if(p===undefined){h.style.display="none"}else{h.style.display="inline-block";h.setAttribute("href","#"+p);h.textContent=p==="configuracion"?"\u2190 Configuraci\u00f3n":"\u2190 Tu protecci\u00f3n"}titulo();if(arriba){aviso("");window.scrollTo(0,0)}}
window.addEventListener("hashchange",function(){mostrarVista(true)});
function sw(b,on){b.setAttribute("aria-checked",on?"true":"false")}
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
  var nombres=d.referentes.map(function(x){return x.name+(x.status==="aceptado"?"":" (falta que acepte)")});
  $("cfRef").textContent=nombres.length?nombres.join(", "):"Todav\u00eda no elegiste a nadie.";$("avisoRef").style.display=nombres.length?"none":"block";DEF=d.defaults||DEF;
  ["refLineaC","refLineaG"].forEach(function(id){var n=$(id);limpiar(n);texto(n,nombres.length?"Se avisa a: "+nombres.join(", ")+". ":"Todav\u00eda no elegiste a nadie. ");var a=document.createElement("a");a.href="#config-referentes";a.style.color="#f0c75a";a.textContent=nombres.length?"Cambiar":"Elegir referentes";n.appendChild(a)});
  $("refLineaG").style.display=nombres.length?"block":"none";
  var c=d.config;$("cNombre").value=c.displayName||"";$("cDesde").value=c.nightFrom;$("cHasta").value=c.nightTo;$("cSilNoche").value=c.silenceNightMin;$("cSilDia").value=c.silenceDayMin;$("cKm").value=c.farKm;$("cBat").value=c.batteryPct;$("cMin").value=String(c.minSignals);$("cEmer").value=c.emergencyHours;encendido=!!c.enabled;
  $("casa").textContent=c.homeLat===null?"Todav\u00eda no marcaste d\u00f3nde est\u00e1 tu casa: sin eso, la se\u00f1al \u201clejos de casa\u201d no cuenta.":"Casa marcada ("+Number(c.homeLat).toFixed(4)+", "+Number(c.homeLng).toFixed(4)+").";
  var enPausa=!!(c.pausedUntil&&c.pausedUntil>new Date().toISOString());
  $("pausa").textContent=enPausa?"En pausa hasta "+fecha(c.pausedUntil):"Sin pausa.";
  var em=$("estadoModo");em.className=!c.enabled?"mal":(enPausa?"suave":"ok");
  em.textContent=!c.enabled?"Ahora: apagado. No se manda ning\u00fan aviso autom\u00e1tico.":(enPausa?"Ahora: encendido, pero en pausa hasta "+fecha(c.pausedUntil):"Ahora: encendido.");
  var tc=$("tCautelaEstado");tc.className=!c.enabled?"mal":(enPausa?"suave":"ok");tc.textContent=!c.enabled?"Apagado":(enPausa?"Encendido, en pausa hasta "+fecha(c.pausedUntil):"Encendido");
  sw($("cEncender"),!!c.enabled);sw($("swCautelaInicio"),!!c.enabled);
  if(DEF)$("cRecomendado").textContent="Recomendado: de noche "+DEF.nightFrom+" a "+DEF.nightTo+" h, sin se\u00f1al "+DEF.silenceNightMin+" min de noche y "+DEF.silenceDayMin+" de d\u00eda, lejos de casa "+DEF.farKm+" km, bater\u00eda "+DEF.batteryPct+" %, "+DEF.minSignals+" se\u00f1ales, emergencia a las "+DEF.emergencyHours+" h.";
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
  if(pe.propia===false){nd.style.display="block";nd.textContent="Est\u00e1s armando la protecci\u00f3n de "+nom+". Los referentes que elijas son los de "+nom+": a cada uno le llega un mail para aceptar, y si "+nom+" aprieta el SOS tambi\u00e9n les avisamos.";NOMBREPERSONA=nom;$("cCasa").textContent="La casa de "+nom+" es donde est\u00e1 su tel\u00e9fono ahora"}
  else{nd.style.display="none";NOMBREPERSONA="";$("cCasa").textContent="Mi casa es donde est\u00e1 mi tel\u00e9fono ahora"}
  PROPIA=pe.propia!==false;RO=!!pe.soloLectura;
  $("gdSeccion").style.display=PROPIA?"block":"none";$("tGuardian").style.display=PROPIA?"block":"none";$("cfGuardianFila").style.display=PROPIA?"flex":"none";mostrarVista(false);
  var ro=!!pe.soloLectura;$("soloLectura").style.display=ro?"block":"none";
  if(ro){Array.prototype.forEach.call(document.querySelectorAll("#contenido input,#contenido select,#contenido button"),function(e){if(!$("gdSeccion").contains(e)&&!$("vCfgAcc").contains(e))e.disabled=true})}
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
$("cGuardar").onclick=function(){accion({accion:"config",config:{nightFrom:$("cDesde").value,nightTo:$("cHasta").value,silenceNightMin:$("cSilNoche").value,silenceDayMin:$("cSilDia").value,farKm:$("cKm").value,batteryPct:$("cBat").value,minSignals:$("cMin").value,emergencyHours:$("cEmer").value}},"Condiciones guardadas.")};
function gdPost(c){return fetch("/api/guardian",{method:"POST",headers:{"content-type":"application/json"},body:JSON.stringify(c),credentials:"same-origin"}).then(function(r){return r.json().then(function(d){return{ok:r.ok,d:d}},function(){return{ok:false,d:{error:"respuesta_"+r.status}}})})}
function gdCargar(){return gdPost({accion:"estado"}).then(function(x){
  var d=x.d;$("gdCarga").style.display="none";var tg=$("tGuardianEstado");
  if(x.ok&&d.ok&&d.config){GDDEF=d.defaults||GDDEF;gdCfgPintar(d.config,!!d.viaje)}
  if(!x.ok||!d.ok){$("gdCarga").style.display="block";$("gdCarga").textContent="No se pudo cargar el Modo Guardi\u00e1n.";tg.textContent="";return}
  if(d.viaje){$("gdForm").style.display="none";$("gdSinRef").style.display="none";$("gdActivo").style.display="block";$("gdActivoTxt").textContent="Hay un camino en marcha: vas a "+d.viaje.destino+(d.viaje.pausa?" (en pausa)":"")+".";$("gdAbrir").href=d.viaje.enlace;tg.className="ok";tg.textContent="Hay un camino en marcha: vas a "+d.viaje.destino+(d.viaje.pausa?" (en pausa)":"");return}
  $("gdActivo").style.display="none";
  if(!d.referentes){$("gdForm").style.display="none";$("gdSinRef").style.display="block";tg.className="suave";tg.textContent="Primero eleg\u00ed un referente que haya aceptado.";return}
  $("gdSinRef").style.display="none";$("gdForm").style.display="block";tg.className="suave";tg.textContent="Sin camino en marcha.";
  var sel=$("gdLugar");limpiar(sel);
  d.lugares.forEach(function(l){var o=document.createElement("option");o.value=l.id;o.textContent=l.name;sel.appendChild(o)});
  var o2=document.createElement("option");o2.value="";o2.textContent="Otro lugar\u2026";sel.appendChild(o2);
  gdCambio();
}).catch(function(){$("gdCarga").style.display="block";$("gdCarga").textContent="No se pudo cargar el Modo Guardi\u00e1n."})}
var GDPLACE="",GDETIQUETA="",GDHAYSUG=false,GDTIMER=null;
function gdCfgPintar(c,enMarcha){
  $("gMargen").value=c.margenMin;$("gAviso").value=c.avisoMin;$("gExt").value=c.maxExtensiones;$("gEntre").value=c.entreAlertasMin;$("gMaxAv").value=c.maxAlertas;$("gAuto").value=c.autoAjusteMin;
  $("gdCfgBloqueo").style.display=enMarcha?"block":"none";
  ["gMargen","gAviso","gExt","gEntre","gMaxAv","gAuto","gGuardar","gReset"].forEach(function(i){$(i).disabled=enMarcha||!PROPIA||RO});
  if(GDDEF)$("gRecomendado").textContent="Recomendado: margen de "+GDDEF.margenMin+" min, preguntar "+GDDEF.avisoMin+" min antes, "+GDDEF.maxExtensiones+" veces m\u00e1s tiempo, avisos cada "+GDDEF.entreAlertasMin+" min (hasta "+GDDEF.maxAlertas+") y hasta "+GDDEF.autoAjusteMin+" min m\u00e1s por tr\u00e1nsito.";
  $("gdPie").textContent="Ten\u00e9s "+c.margenMin+" minutos de margen. Si no lleg\u00e1s ni ped\u00eds m\u00e1s tiempo, les avisamos a tus referentes. "+(c.maxExtensiones>0?"Pod\u00e9s extender 10, 20 o 30 minutos, hasta "+c.maxExtensiones+(c.maxExtensiones===1?" vez.":" veces."):"En tu configuraci\u00f3n no se puede pedir m\u00e1s tiempo.")+(c.autoAjusteMin>0?" Si hay m\u00e1s tr\u00e1nsito y te ven\u00eds acercando, el l\u00edmite se acomoda solo (hasta "+c.autoAjusteMin+" min).":"")}
function gdCfgRespuesta(x,ok){if(x.ok&&x.d.ok){aviso(ok);gdCfgPintar(x.d.config,false)}else aviso(({camino_en_marcha:"Hay un camino en marcha: cambialo cuando termine.",solo_administrador:"Esto lo completa el administrador de tu familia."})[x.d.error]||"No se pudo guardar.")}
$("gGuardar").onclick=function(){gdPost({accion:"config",config:{margenMin:$("gMargen").value,avisoMin:$("gAviso").value,maxExtensiones:$("gExt").value,entreAlertasMin:$("gEntre").value,maxAlertas:$("gMaxAv").value,autoAjusteMin:$("gAuto").value}}).then(function(x){gdCfgRespuesta(x,"Cambios guardados.")}).catch(function(){aviso("No se pudo guardar.")})};
$("gReset").onclick=function(){if(!confirm("\u00bfVolver los tiempos y avisos del Modo Guardi\u00e1n a los valores recomendados?"))return;gdPost({accion:"config",config:{restablecer:true}}).then(function(x){gdCfgRespuesta(x,"Valores recomendados restablecidos.")}).catch(function(){aviso("No se pudo guardar.")})};
// accesibilidad: se guarda en este telefono y vale para todas las pantallas de Ojo Guard
function accLeer(){try{return JSON.parse(localStorage.getItem("ogAcc")||"{}")||{}}catch(e){return{}}}
function accGuardar(p){try{localStorage.setItem("ogAcc",JSON.stringify(p))}catch(e){}}
function accAplicar(p){var r=document.documentElement;r.style.fontSize=({g:"118%",x:"136%"})[p.t]||"";r.classList.toggle("ac",!!p.c);r.classList.toggle("ab",!!p.b)}
function lsLeer(k){try{return localStorage.getItem(k)!=="0"}catch(e){return true}}
function lsGuardar(k,v){try{localStorage.setItem(k,v?"1":"0")}catch(e){}}
function accPintar(){var p=accLeer();
  Array.prototype.forEach.call(document.querySelectorAll("button[data-t]"),function(b){b.className=b.getAttribute("data-t")===(p.t||"")?"":"sec"});
  sw($("aaContraste"),!!p.c);sw($("aaBotones"),!!p.b);sw($("aaSonido"),lsLeer("gdSonido"));sw($("aaVibra"),lsLeer("gdVibra"));sw($("aaLuz"),lsLeer("gdLuz"))}
Array.prototype.forEach.call(document.querySelectorAll("button[data-t]"),function(b){b.onclick=function(){var p=accLeer();p.t=b.getAttribute("data-t")||"";accGuardar(p);accAplicar(p);accPintar()}});
$("aaContraste").onclick=function(){var p=accLeer();p.c=!p.c;accGuardar(p);accAplicar(p);accPintar()};
$("aaBotones").onclick=function(){var p=accLeer();p.b=!p.b;accGuardar(p);accAplicar(p);accPintar()};
["aaSonido:gdSonido","aaVibra:gdVibra","aaLuz:gdLuz"].forEach(function(x){var par=x.split(":");$(par[0]).onclick=function(){lsGuardar(par[1],!lsLeer(par[1]));accPintar()}});
accPintar();
function gdDestinoCuerpo(c){if($("gdLugar").value){c.lugarId=$("gdLugar").value}else if(GDPLACE){c.placeId=GDPLACE;c.texto=GDETIQUETA}else{c.texto=$("gdTexto").value.trim()}return c}
function gdFalloTexto(d){var m=({http_403:"Google no deja usar esta clave todav\u00eda",http_400:"Google rechaz\u00f3 el pedido",http_404:"Google no encontr\u00f3 ese lugar",sin_ruta:"Google no encontr\u00f3 una ruta",red:"no hubo conexi\u00f3n con Google",sin_ubicacion:"no sabemos d\u00f3nde est\u00e1s: permit\u00ed la ubicaci\u00f3n en el navegador",ubicacion_vieja:"no sabemos d\u00f3nde est\u00e1s ahora (la \u00faltima ubicaci\u00f3n de tu tel\u00e9fono es de hace un rato): permit\u00ed la ubicaci\u00f3n en el navegador",sin_resultados:"Google no encontr\u00f3 lugares con ese texto"})[d.fallo]||"Google no pudo calcularlo";return m+(d.detalle?" ("+d.detalle.slice(0,260)+")":"")}
// donde esta la persona AHORA: la ubicacion del navegador de su telefono (se pide al calcular y al empezar); si no la da, el panel usa la ultima del telefono solo si es de los ultimos minutos
var GDSEQ=0,GDPOS=null;
function gdUbicar(){return new Promise(function(res){
  if(GDPOS&&Date.now()-GDPOS.en<20000){res(GDPOS);return}
  var hecho=false,fin=function(o){if(!hecho){hecho=true;if(o)GDPOS=o;res(o)}};
  try{navigator.geolocation.getCurrentPosition(function(p){fin({lat:p.coords.latitude,lng:p.coords.longitude,precision:p.coords.accuracy,en:Date.now()})},function(){fin(null)},{enableHighAccuracy:true,timeout:10000,maximumAge:15000});setTimeout(function(){fin(null)},11000)}catch(e){fin(null)}})}
function gdOrigenCuerpo(o){return{lat:o.lat,lng:o.lng,precision:o.precision}}
function modosPoner(g,v){Array.prototype.forEach.call($(g).querySelectorAll("button.modo"),function(b){b.setAttribute("aria-checked",b.getAttribute("data-modo")===v?"true":"false")})}
function modosValor(g){var b=$(g).querySelector(''button.modo[aria-checked="true"]'');return b?b.getAttribute("data-modo"):"auto"}
function gdDesde(o){return o&&o.fuente==="navegador"?", desde donde est\u00e1s ahora":o&&o.fuente==="telefono"?", desde la \u00faltima ubicaci\u00f3n de tu tel\u00e9fono (hace "+(o.haceMin||0)+" min)":""}
function gdCambio(){
  var otro=!$("gdLugar").value;$("gdOtro").style.display=otro?"block":"none";$("gdAyudaMin").textContent="";
  $("gdMin").value="";$("gdMin").readOnly=false;
  if(otro&&!GDPLACE&&!$("gdTexto").value.trim()){$("gdAyudaMin").textContent="(eleg\u00ed a d\u00f3nde vas)";return}
  if(otro&&GDHAYSUG&&!GDPLACE){$("gdAyudaMin").textContent="(eleg\u00ed uno de los lugares sugeridos)";return}
  var mi=++GDSEQ,c=gdDestinoCuerpo({accion:"estimar",modo:modosValor("gdModo")});
  $("gdAyudaMin").textContent="(buscando d\u00f3nde est\u00e1s\u2026)";
  gdUbicar().then(function(o){if(mi!==GDSEQ)return null;if(o)c.origen=gdOrigenCuerpo(o);$("gdAyudaMin").textContent="(calculando con mapas\u2026)";return gdPost(c)}).then(function(x){if(!x||mi!==GDSEQ)return;var d=x.d||{};
    if(x.ok&&d.minutos){$("gdMin").value=d.minutos;$("gdMin").readOnly=d.fuente==="mapas";$("gdAyudaMin").textContent=d.fuente==="mapas"?"(calculado con mapas y el tr\u00e1nsito de ahora"+gdDesde(d.origen)+(d.km!==null&&d.km!==undefined?", "+String(d.km).replace(".",",")+" km":"")+")":"(estimado por la distancia: pod\u00e9s cambiarlo)"+(d.fallo?" \u2014 "+gdFalloTexto(d):"")}
    else{$("gdMin").readOnly=false;$("gdAyudaMin").textContent=d.error==="destino_muy_lejos"?"(ese lugar queda a m\u00e1s de 5 horas: revis\u00e1 la direcci\u00f3n)":"(no pudimos calcularlo: "+(d.fallo?gdFalloTexto(d):"pon\u00e9 cu\u00e1nto tard\u00e1s")+")"}
  }).catch(function(){if(mi===GDSEQ){$("gdMin").readOnly=false;$("gdAyudaMin").textContent="(no pudimos calcularlo: pon\u00e9 cu\u00e1nto tard\u00e1s)"}})}
function gdSugerir(){
  var t=$("gdTexto").value.trim();var caja=$("gdSugerencias");limpiar(caja);caja.style.display="none";$("gdAyudaDir").textContent="";
  if(t.length<3){GDHAYSUG=false;return}
  $("gdAyudaDir").textContent="Buscando\u2026";
  var pedido={accion:"buscar",texto:t};if(GDPOS)pedido.origen=gdOrigenCuerpo(GDPOS);
  gdPost(pedido).then(function(x){var d=x.d||{};
    if($("gdTexto").value.trim()!==t)return;
    var lista=d.sugerencias||[];GDHAYSUG=lista.length>0;
    if(!lista.length){var m="";
      if(!x.ok)m="No pudimos buscar: el panel contest\u00f3 con un error"+(d.error?" ("+d.error+")":"")+".";
      else if(d.fallo==="sin_clave")m="Al panel le falta la clave de Google, por eso no puede sugerir lugares.";
      else if(d.fallo==="sin_resultados")m=gdFalloTexto(d)+". Prob\u00e1 con otro nombre, o con la direcci\u00f3n y la ciudad.";
      else if(d.fallo)m="No pudimos buscar direcciones: "+gdFalloTexto(d)+". Escribila completa, con barrio y ciudad.";
      $("gdAyudaDir").textContent=m;return}
    lista.forEach(function(sg){var b=document.createElement("button");b.type="button";b.className="sec";b.style.textAlign="left";b.style.width="100%";b.textContent=sg.principal+(sg.secundario?" \u00b7 "+sg.secundario:"")+(sg.km!==null&&sg.km!==undefined?" \u00b7 a "+String(sg.km).replace(".",",")+" km":"");
      b.onclick=function(){GDPLACE=sg.placeId;GDETIQUETA=(sg.principal+(sg.secundario?", "+sg.secundario:"")).slice(0,80);$("gdTexto").value=GDETIQUETA;limpiar(caja);caja.style.display="none";$("gdAyudaDir").textContent="Elegiste: "+GDETIQUETA;gdCambio()};caja.appendChild(b)});
    caja.style.display="flex";$("gdAyudaDir").textContent="Eleg\u00ed el lugar correcto (mir\u00e1 el barrio, la ciudad y la distancia).";gdCambio();
  }).catch(function(e){if($("gdTexto").value.trim()===t)$("gdAyudaDir").textContent="No pudimos buscar: no hubo respuesta del panel."})}
$("gdTexto").oninput=function(){GDPLACE="";GDETIQUETA="";$("gdMin").value="";clearTimeout(GDTIMER);GDTIMER=setTimeout(gdSugerir,400)};
$("gdLugar").onchange=gdCambio;
Array.prototype.forEach.call($("gdModo").querySelectorAll("button.modo"),function(b){b.onclick=function(){modosPoner("gdModo",b.getAttribute("data-modo"));gdCambio()}});
$("gdEmpezar").onclick=function(){var c=gdDestinoCuerpo({accion:"empezar",modo:modosValor("gdModo"),minutos:Number($("gdMin").value)||0});if(!$("gdLugar").value&&GDHAYSUG&&!GDPLACE){aviso("Eleg\u00ed uno de los lugares que te sugerimos, as\u00ed sabemos bien a d\u00f3nde vas.");return}
  var enviar=function(){gdPost(c).then(function(x){if(x.ok&&x.d.viaje){location.href=x.d.viaje.enlace;return}aviso(({sin_referentes:"Primero eleg\u00ed un referente que haya aceptado.",ya_hay_camino:"Ya ten\u00e9s un camino en marcha.",falta_destino:"Escrib\u00ed a d\u00f3nde vas.",faltan_minutos:(x.d.fallo==="ubicacion_vieja"||x.d.fallo==="sin_ubicacion"?"No sabemos d\u00f3nde est\u00e1s ahora: permit\u00ed la ubicaci\u00f3n en el navegador o pon\u00e9 cu\u00e1ntos minutos tard\u00e1s.":"Pon\u00e9 cu\u00e1ntos minutos tard\u00e1s."),lugar_invalido:"Ese lugar no existe.",modo_invalido:"Eleg\u00ed c\u00f3mo vas.",destino_invalido:"Eleg\u00ed de nuevo la direcci\u00f3n.",destino_muy_lejos:"Ese lugar queda a m\u00e1s de 5 horas: revis\u00e1 la direcci\u00f3n."})[x.d.error]||"No se pudo empezar el camino.")})};
  $("gdEmpezar").disabled=true;$("gdEmpezar").textContent="Buscando tu ubicaci\u00f3n\u2026";
  gdUbicar().then(function(o){if(o)c.origen=gdOrigenCuerpo(o);$("gdEmpezar").disabled=false;$("gdEmpezar").textContent="Empezar camino";enviar()})};
$("persona").onchange=function(){location.search=this.value?"?persona="+encodeURIComponent(this.value):""};
$("cCasa").onclick=function(){accion({accion:"casa"},"Casa marcada.")};
Array.prototype.forEach.call(document.querySelectorAll("button[data-h]"),function(b){b.onclick=function(){accion({accion:"pausa",horas:Number(b.getAttribute("data-h"))},b.getAttribute("data-h")==="0"?"Pausa quitada.":"Pausa puesta por "+b.getAttribute("data-h")+" horas.")}});
$("pOtro").onclick=function(){var h=Number($("pHoras").value);if(!(h>=1&&h<=72)){aviso("Pon\u00e9 un n\u00famero de horas entre 1 y 72.");return}accion({accion:"pausa",horas:h},"Pausa puesta por "+h+(h===1?" hora.":" horas."))};
function alternarCautela(){if(encendido&&!confirm("\u00bfApagar el Modo Cautela? Mientras est\u00e9 apagado no se manda ning\u00fan aviso autom\u00e1tico a tus referentes. El SOS sigue avisando. Si es por un rato, mejor us\u00e1 la pausa."))return;accion({accion:"config",config:{enabled:!encendido}},encendido?"Modo Cautela apagado.":"Modo Cautela encendido.")}
$("cEncender").onclick=alternarCautela;$("swCautelaInicio").onclick=alternarCautela;
$("cNombreGuardar").onclick=function(){accion({accion:"config",config:{displayName:$("cNombre").value}},"Nombre guardado.")};
$("cReset").onclick=function(){if(!DEF)return;if(!confirm("\u00bfVolver las condiciones del Modo Cautela a los valores recomendados?"))return;accion({accion:"config",config:{nightFrom:DEF.nightFrom,nightTo:DEF.nightTo,silenceNightMin:DEF.silenceNightMin,silenceDayMin:DEF.silenceDayMin,farKm:DEF.farKm,batteryPct:DEF.batteryPct,minSignals:DEF.minSignals,emergencyHours:DEF.emergencyHours}},"Condiciones restablecidas.")};
mostrarVista(false);
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
$bien = ($v.texto.Length -eq $esperado) -and ((Contar $v.texto 'async function gdBuscarLugares(') -eq 1) -and ((Contar $v.texto 'id="vConfig"') -eq 1) -and ((Contar $v.texto 'async function gdAjustarPorTransito(') -eq 1) -and ((Contar $v.texto 'async function gdLeerProgreso(') -eq 1) -and ((Contar $v.texto 'id="bFrenar"') -eq 1) -and ((Contar $v.texto 'id="bCambiar"') -eq 1) -and ((Contar $v.texto 'id="gAuto"') -eq 1) -and ((Contar $v.texto 'async function gdCerrarPausa(') -eq 1) -and ((Contar $v.texto 'async function gdOrigenActual(') -eq 1) -and ((Contar $v.texto 'function gdModosHtml(') -eq 1) -and ((Contar $v.texto 'id="bSeguir"') -eq 1) -and ((Contar $v.texto 'gdModosHtml("cmModos", "auto")') -eq 1) -and ((Contar $v.texto 'id="bProbar"') -eq 1) -and ((Contar $v.texto 'id="finalTxt"') -eq 1) -and ((Contar $v.texto 'id="relojCard"') -eq 1) -and ((Contar $v.texto 'async function gdLeerConfig(') -eq 1) -and ((Contar $v.texto 'id="cReset"') -eq 1) -and ((Contar $v.texto 'async function gdRutaMapas(') -eq 1) -and ((Contar $v.texto 'function gdFin(') -eq 1) -and ((Contar $v.texto 'async function gdCron(') -eq 1) -and ((Contar $v.texto 'route === "GET /camino"') -eq 1) -and ((Contar $v.texto 'async function pldResolverPersona(') -eq 1) -and ((Contar $v.texto 'Estado de tu tel') -eq 1) -and ((Contar $v.texto 'id="gMargen"') -eq 1) -and ((Contar $v.texto 'id="pOtro"') -eq 1) -and ((Contar $v.texto 'async function pldCerrarEpisodio(') -eq 1) -and ((Contar $v.texto 'route === "GET /guardian"') -eq 1) -and ((Contar $v.texto 'async function pldAvisarSos(') -eq 1) -and ((Contar $v.texto 'async function nativeFamilySos') -eq 1) -and ((Contar $v.texto 'async function fetchCorreo') -eq 1)
if (-not $bien) {
    Mal "Algo no salio bien. Restauro src\index.ts desde el respaldo."
    Copy-Item -LiteralPath ($indice + ".bak-pldparpadeo") -Destination $indice -Force
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Ok ("src\index.ts: largo " + $v.texto.Length + " (esperado " + $esperado + ")")
Write-Host ""
Ok "Archivo listo. Ahora publico el panel..."
& npx.cmd wrangler deploy
if ($LASTEXITCODE -ne 0) { Mal "No se pudo publicar el panel. Mandame esta pantalla."; return }
Write-Host ""
Ok "LISTO: en los ultimos 15 segundos del camino el reloj parpadea en rojo. Abri el camino con Ctrl+F5 y proba."
Write-Host ""
