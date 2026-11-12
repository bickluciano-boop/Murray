# aplicar-remedios2-panel.ps1 - Ojo Guard MS: REMEDIOS v2 (servidor). A pedido de Luciano (12/11/2026) tras probar la 199:
#  - Varios remedios a la misma hora: UN solo aviso con todos ("Es hora de tus remedios: A y B"), un solo "Lo tome" y un solo aviso a la familia.
#  - Frecuencia: todos los dias / algunos dias de la semana / una vez al mes (un dia del mes; si el mes no lo tiene, el ultimo del mes).
# Requiere aplicar-remedios-panel.ps1 (ya aplicado). Cambia SOLO src\index.ts (respaldo .bak-remedios2). Va en la carpeta del PANEL (la que tiene wrangler.toml). Sin build. Al final publica el panel solo.
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
if (-not (Test-Path (Join-Path $raiz "src\index.ts"))) { Mal "No encuentro src\index.ts en esta carpeta."; return }
$indexTexto = (Leer (Join-Path $raiz "src\index.ts")).texto
if ((Contar $indexTexto 'function medToca') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $indexTexto 'async function remediosCron') -eq 0) { Mal "Falta aplicar primero aplicar-remedios-panel.ps1. No toco nada."; return }
$cambios = @(
    ,@('src\index.ts', 'remedios v2: varios a la misma hora, semana y mes', '// ---------------------------------------------------------------------------
// Remedios (Familia y amigos > Cuidado). OPCIONAL: los carga, los prende y los apaga la propia persona (ella decide; la app no).
//  - A la hora de cada remedio le llega un aviso; "Lo tomé" lo marca. Si no lo confirma en 15 minutos se le avisa una vez mas.
//  - Opcional y APAGADO por defecto: "Avisar a mi familia si no lo confirmo". Si pasa el plazo que elige, se avisa a quienes reciben SU SOS, sin decir el nombre del remedio.
//  - Los nombres de los remedios son datos de salud: solo los ve la propia persona. A los demas (panel) se les muestra cuantos tomo hoy.
//   CREATE TABLE IF NOT EXISTS med_items (id TEXT PRIMARY KEY, email TEXT NOT NULL, nombre TEXT NOT NULL, horas TEXT NOT NULL, dias TEXT NOT NULL, activo INTEGER NOT NULL DEFAULT 1, created_at TEXT NOT NULL);
//   CREATE TABLE IF NOT EXISTS med_dosis (id TEXT PRIMARY KEY, email TEXT NOT NULL, item_id TEXT NOT NULL, day TEXT NOT NULL, hhmm TEXT NOT NULL, sent_at TEXT, rem_at TEXT, ok_at TEXT, alert_at TEXT);
//   CREATE TABLE IF NOT EXISTS med_prefs (email TEXT PRIMARY KEY, avisar INTEGER NOT NULL DEFAULT 0, limite_min INTEGER NOT NULL DEFAULT 60, updated_at TEXT NOT NULL);
// ---------------------------------------------------------------------------
const MED_MAX_ITEMS = 8, MED_MAX_HORAS = 6, MED_VENTANA_MIN = 20, MED_REAVISO_MIN = 15;
const MED_LIMITES = [30, 60, 90, 120];
let medTablaLista = false;
async function medTabla(env: Env) {
  if (medTablaLista) return;
  await env.DB.prepare("CREATE TABLE IF NOT EXISTS med_items (id TEXT PRIMARY KEY, email TEXT NOT NULL, nombre TEXT NOT NULL, horas TEXT NOT NULL, dias TEXT NOT NULL, activo INTEGER NOT NULL DEFAULT 1, created_at TEXT NOT NULL)").run();
  await env.DB.prepare("CREATE TABLE IF NOT EXISTS med_dosis (id TEXT PRIMARY KEY, email TEXT NOT NULL, item_id TEXT NOT NULL, day TEXT NOT NULL, hhmm TEXT NOT NULL, sent_at TEXT, rem_at TEXT, ok_at TEXT, alert_at TEXT)").run();
  await env.DB.prepare("CREATE UNIQUE INDEX IF NOT EXISTS med_dosis_unica ON med_dosis (item_id, day, hhmm)").run();
  await env.DB.prepare("CREATE INDEX IF NOT EXISTS med_items_email ON med_items (email)").run();
  await env.DB.prepare("CREATE TABLE IF NOT EXISTS med_prefs (email TEXT PRIMARY KEY, avisar INTEGER NOT NULL DEFAULT 0, limite_min INTEGER NOT NULL DEFAULT 60, updated_at TEXT NOT NULL)").run();
  medTablaLista = true;
}
type MedItem = { id: string; email: string; nombre: string; horas: string[]; dias: number[]; activo: boolean };
type MedFila = { id: string; email: string; nombre: string; horas: string; dias: string; activo: number };
function medParse(f: MedFila): MedItem {
  let horas: string[] = [];
  let dias: number[] = [];
  try { horas = (JSON.parse(f.horas) as unknown[]).map(String).filter((h) => /^([01]\d|2[0-3]):[0-5]\d$/.test(h)); } catch { /* fila vieja */ }
  try { dias = (JSON.parse(f.dias) as unknown[]).map(Number).filter((d) => Number.isInteger(d) && d >= 0 && d <= 6); } catch { /* fila vieja */ }
  return { id: f.id, email: f.email, nombre: f.nombre, horas, dias, activo: Boolean(f.activo) };
}
async function medItems(env: Env, email: string): Promise<MedItem[]> {
  const r = await env.DB.prepare("SELECT id,email,nombre,horas,dias,activo FROM med_items WHERE email=? ORDER BY created_at, id").bind(email).all<MedFila>();
  return r.results.map(medParse);
}
async function medPrefs(env: Env, email: string) {
  const f = await env.DB.prepare("SELECT avisar, limite_min AS limiteMin FROM med_prefs WHERE email=?").bind(email).first<{ avisar: number; limiteMin: number }>();
  return { avisar: Boolean(f?.avisar), limiteMin: Number(f?.limiteMin) || 60 };
}
type MedDosis = { id: string; itemId: string; hhmm: string; sentAt: string | null; okAt: string | null; alertAt: string | null };
async function medDosisDelDia(env: Env, email: string, dia: string): Promise<MedDosis[]> {
  const r = await env.DB.prepare("SELECT id, item_id AS itemId, hhmm, sent_at AS sentAt, ok_at AS okAt, alert_at AS alertAt FROM med_dosis WHERE email=? AND day=?").bind(email, dia).all<MedDosis>();
  return r.results;
}
/** Las tomas de hoy de una persona: programado (todavia no es la hora) | esperando (aviso enviado, sin confirmar) | tomado | sin_confirmar (ya se aviso a la familia) | sin_aviso (la hora paso antes de cargarlo: no cuenta). */
function medHoy(items: MedItem[], dosis: MedDosis[], hhmmAhora: string, dow: number) {
  const lista: { itemId: string; nombre: string; hhmm: string; dosisId: string | null; estado: string }[] = [];
  for (const it of items) {
    if (!it.activo || !it.dias.includes(dow)) continue;
    for (const hhmm of it.horas) {
      const d = dosis.find((x) => x.itemId === it.id && x.hhmm === hhmm);
      const estado = d?.okAt ? "tomado" : d?.alertAt ? "sin_confirmar" : d?.sentAt ? "esperando" : hhmm > hhmmAhora ? "programado" : "sin_aviso";
      lista.push({ itemId: it.id, nombre: it.nombre, hhmm, dosisId: d?.id ?? null, estado });
    }
  }
  return lista.sort((a, b) => a.hhmm.localeCompare(b.hhmm));
}
/** Para el panel y para quienes reciben su SOS: cuantos remedios de hoy tomo, SIN nombres (datos de salud). null si no usa remedios. */
async function remediosResumen(env: Env, email: string) {
  await medTabla(env);
  await cuidadoTabla(env);
  const [items, prefs, medP] = await Promise.all([medItems(env, email), cuidadoPrefs(env, email), medPrefs(env, email)]);
  if (!items.some((i) => i.activo)) return null;
  const loc = cuidadoLocal(Date.now(), prefs.tz);
  const dow = new Date(Date.now() + prefs.tz * 60_000).getUTCDay();
  const hoy = medHoy(items, await medDosisDelDia(env, email, loc.dia), loc.hhmm, dow).filter((x) => x.estado !== "sin_aviso");
  return {
    total: hoy.length,
    tomadas: hoy.filter((x) => x.estado === "tomado").length,
    esperando: hoy.filter((x) => x.estado === "esperando").length,
    sinConfirmar: hoy.filter((x) => x.estado === "sin_confirmar").length,
    avisa: medP.avisar,
  };
}
async function medAvisar(env: Env, email: string, titulo: string, texto: string, motivo: string, data: Record<string, unknown>) {
  await Promise.all((await pushTokensOf(env, email)).map((token) => sendExpoNoticeLogged(env, token, titulo, texto, motivo, { channelId: "ojo-familia-aviso", data }).catch(() => false)));
}

/** Cada minuto: avisa los remedios que tocan ahora, repite una vez a los 15 minutos y (solo si la persona lo prendio) avisa a su familia si no confirmo. */
async function remediosCron(env: Env, ahoraMs = Date.now()) {
  await medTabla(env);
  await cuidadoTabla(env);
  const filas = await env.DB.prepare("SELECT id,email,nombre,horas,dias,activo FROM med_items WHERE activo=1").all<MedFila>();
  const porPersona = new Map<string, MedItem[]>();
  for (const f of filas.results) {
    const m = medParse(f);
    porPersona.set(m.email, [...(porPersona.get(m.email) ?? []), m]);
  }
  for (const [email, items] of porPersona) {
    try {
      const prefs = await cuidadoPrefs(env, email);
      const loc = cuidadoLocal(ahoraMs, prefs.tz);
      const dow = new Date(ahoraMs + prefs.tz * 60_000).getUTCDay();
      const minutosAhora = Number(loc.hhmm.slice(0, 2)) * 60 + Number(loc.hhmm.slice(3, 5));
      for (const it of items) {
        if (!it.dias.includes(dow)) continue;
        for (const hhmm of it.horas) {
          const minutosHora = Number(hhmm.slice(0, 2)) * 60 + Number(hhmm.slice(3, 5));
          // Solo a la hora (con unos minutos de margen): un remedio cargado despues de su hora no avisa para atras.
          if (minutosAhora < minutosHora || minutosAhora >= minutosHora + MED_VENTANA_MIN) continue;
          const id = crypto.randomUUID();
          const r = await env.DB.prepare("INSERT OR IGNORE INTO med_dosis (id,email,item_id,day,hhmm,sent_at) VALUES (?,?,?,?,?,?)").bind(id, email, it.id, loc.dia, hhmm, new Date(ahoraMs).toISOString()).run();
          if (!r.meta.changes) continue;
          await medAvisar(env, email, "Remedio", `Es hora de tu remedio: ${it.nombre}. Tocá para confirmar.`, "remedio", { type: "remedio", dosisId: id, day: loc.dia, hhmm });
        }
      }
    } catch (error) {
      console.error("remedios_persona", String(error).slice(0, 120));
    }
  }
  const desde = new Date(ahoraMs - 24 * 3600_000).toISOString();
  const pendientes = await env.DB.prepare(
    "SELECT d.id AS id, d.email AS email, d.hhmm AS hhmm, d.sent_at AS sentAt, d.rem_at AS remAt, d.alert_at AS alertAt, i.nombre AS nombre, COALESCE(p.avisar,0) AS avisar, COALESCE(p.limite_min,60) AS limiteMin " +
    "FROM med_dosis d JOIN med_items i ON i.id=d.item_id LEFT JOIN med_prefs p ON p.email=d.email WHERE d.ok_at IS NULL AND d.sent_at IS NOT NULL AND d.sent_at>?",
  ).bind(desde).all<{ id: string; email: string; hhmm: string; sentAt: string; remAt: string | null; alertAt: string | null; nombre: string; avisar: number; limiteMin: number }>();
  for (const d of pendientes.results) {
    try {
      const enviado = Date.parse(d.sentAt);
      if (!d.remAt && ahoraMs >= enviado + MED_REAVISO_MIN * 60_000) {
        const m = await env.DB.prepare("UPDATE med_dosis SET rem_at=? WHERE id=? AND rem_at IS NULL").bind(new Date(ahoraMs).toISOString(), d.id).run();
        if (m.meta.changes) await medAvisar(env, d.email, "Remedio", `¿Ya tomaste ${d.nombre}? Tocá para confirmar.`, "remedio repetido", { type: "remedio", dosisId: d.id, hhmm: d.hhmm });
      }
      if (d.avisar && !d.alertAt && ahoraMs >= enviado + d.limiteMin * 60_000) {
        const m = await env.DB.prepare("UPDATE med_dosis SET alert_at=? WHERE id=? AND alert_at IS NULL").bind(new Date(ahoraMs).toISOString(), d.id).run();
        // Si el servidor estuvo caido mucho rato, no se avisa de algo viejo.
        if (m.meta.changes && ahoraMs < enviado + (d.limiteMin + 180) * 60_000) {
          const hhmm = d.hhmm;
          await cuidadoAvisar(env, d.email, (nombre) => `${nombre} todavía no confirmó su remedio de las ${hhmm}.`, "cuidado remedio");
        }
      }
    } catch (error) {
      console.error("remedios_pendiente", String(error).slice(0, 120));
    }
  }
}

/** Anota la zona horaria de la persona sin tocar lo demas de Cuidado (los remedios avisan a SU hora). */
async function medGuardarZona(env: Env, email: string, tz: unknown) {
  const n = Number(tz);
  if (!Number.isFinite(n) || n < -720 || n > 840) return;
  await env.DB.prepare("INSERT INTO care_prefs (email,battery_on,buen_on,buen_hora,buen_limite_min,tz_min,updated_at) VALUES (?,1,0,''09:00'',60,?,?) ON CONFLICT(email) DO UPDATE SET tz_min=excluded.tz_min").bind(email, Math.round(n), now()).run();
}

/** GET /api/native/care/med: mis remedios, como van hoy y a quien se le avisaria. */
async function nativeMed(request: Request, env: Env, url: URL) {
  const email = await nativeOwnerEmail(request, env, url.searchParams.get("deviceId") ?? "");
  if (!email) return json({ error: "unauthorized" }, 401);
  await medTabla(env);
  await cuidadoTabla(env);
  const [items, prefs, medP] = await Promise.all([medItems(env, email), cuidadoPrefs(env, email), medPrefs(env, email)]);
  const loc = cuidadoLocal(Date.now(), prefs.tz);
  const dow = new Date(Date.now() + prefs.tz * 60_000).getUTCDay();
  const hoy = medHoy(items, await medDosisDelDia(env, email, loc.dia), loc.hhmm, dow);
  const destinos = await Promise.all((await familySosRecipients(env, email)).map((q) => familyNameSeenBy(env, q, email)));
  return json({
    items: items.map((i) => ({ id: i.id, nombre: i.nombre, horas: i.horas, dias: i.dias, activo: i.activo })),
    prefs: { avisar: medP.avisar, limiteMin: medP.limiteMin },
    hoy,
    destinatarios: destinos,
    max: { items: MED_MAX_ITEMS, horas: MED_MAX_HORAS },
  });
}

/** POST /api/native/care/med/item {deviceId, id?, nombre, horas[], dias[]?, activo?, tzOffsetMin?}: crea o cambia uno de MIS remedios. */
async function nativeMedItem(request: Request, env: Env) {
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const email = await nativeOwnerEmail(request, env, String(body.deviceId ?? ""));
  if (!email) return json({ error: "unauthorized" }, 401);
  await medTabla(env);
  const nombre = String(body.nombre ?? "").replace(/[\u0000-\u001f\u007f]/g, " ").replace(/\s+/g, " ").trim().slice(0, 40);
  if (!nombre) return json({ error: "invalid_request" }, 400);
  const horasEntrada = Array.isArray(body.horas) ? body.horas.map(String) : [];
  const horas = [...new Set(horasEntrada)].filter((h) => /^([01]\d|2[0-3]):[0-5]\d$/.test(h)).sort();
  if (!horas.length || horas.length !== new Set(horasEntrada).size || horas.length > MED_MAX_HORAS) return json({ error: "invalid_request" }, 400);
  const diasEntrada = Array.isArray(body.dias) ? body.dias.map(Number) : [0, 1, 2, 3, 4, 5, 6];
  const dias = [...new Set(diasEntrada)].filter((d) => Number.isInteger(d) && d >= 0 && d <= 6).sort();
  if (!dias.length) return json({ error: "invalid_request" }, 400);
  const activo = body.activo === false ? 0 : 1;
  let id = typeof body.id === "string" ? body.id : "";
  if (id) {
    const existe = await env.DB.prepare("SELECT id FROM med_items WHERE id=? AND email=?").bind(id, email).first<{ id: string }>();
    if (!existe) return json({ error: "not_found" }, 404);
    await env.DB.prepare("UPDATE med_items SET nombre=?, horas=?, dias=?, activo=? WHERE id=? AND email=?").bind(nombre, JSON.stringify(horas), JSON.stringify(dias), activo, id, email).run();
  } else {
    const n = await env.DB.prepare("SELECT COUNT(*) AS n FROM med_items WHERE email=?").bind(email).first<{ n: number }>();
    if (Number(n?.n ?? 0) >= MED_MAX_ITEMS) return json({ error: "too_many" }, 409);
    id = crypto.randomUUID();
    await env.DB.prepare("INSERT INTO med_items (id,email,nombre,horas,dias,activo,created_at) VALUES (?,?,?,?,?,?,?)").bind(id, email, nombre, JSON.stringify(horas), JSON.stringify(dias), activo, now()).run();
  }
  if (body.tzOffsetMin !== undefined) await cuidadoTabla(env).then(() => medGuardarZona(env, email, body.tzOffsetMin)).catch(() => undefined);
  return json({ ok: true, id });
}

/** POST /api/native/care/med/item/delete {deviceId, id}: borra uno de MIS remedios (y sus tomas). */
async function nativeMedItemDelete(request: Request, env: Env) {
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const email = await nativeOwnerEmail(request, env, String(body.deviceId ?? ""));
  if (!email) return json({ error: "unauthorized" }, 401);
  await medTabla(env);
  const id = String(body.id ?? "");
  const existe = await env.DB.prepare("SELECT id FROM med_items WHERE id=? AND email=?").bind(id, email).first<{ id: string }>();
  if (!existe) return json({ error: "not_found" }, 404);
  await env.DB.prepare("DELETE FROM med_dosis WHERE item_id=? AND email=?").bind(id, email).run();
  await env.DB.prepare("DELETE FROM med_items WHERE id=? AND email=?").bind(id, email).run();
  return json({ ok: true });
}

/** POST /api/native/care/med/prefs {deviceId, avisar?, limiteMin?}: "Avisar a mi familia si no lo confirmo" (apagado por defecto). */
async function nativeMedPrefs(request: Request, env: Env) {
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const email = await nativeOwnerEmail(request, env, String(body.deviceId ?? ""));
  if (!email) return json({ error: "unauthorized" }, 401);
  await medTabla(env);
  const p = await medPrefs(env, email);
  if (body.avisar !== undefined) { if (typeof body.avisar !== "boolean") return json({ error: "invalid_request" }, 400); p.avisar = body.avisar; }
  if (body.limiteMin !== undefined) { if (!MED_LIMITES.includes(Number(body.limiteMin))) return json({ error: "invalid_request" }, 400); p.limiteMin = Number(body.limiteMin); }
  // Sin nadie a quien avisar no tiene sentido prenderlo.
  if (p.avisar && body.avisar === true && (await familySosRecipients(env, email)).length === 0) return json({ error: "no_recipients" }, 409);
  await env.DB.prepare("INSERT INTO med_prefs (email,avisar,limite_min,updated_at) VALUES (?,?,?,?) ON CONFLICT(email) DO UPDATE SET avisar=excluded.avisar, limite_min=excluded.limite_min, updated_at=excluded.updated_at").bind(email, p.avisar ? 1 : 0, p.limiteMin, now()).run();
  return json({ ok: true });
}

/** POST /api/native/care/med/ok {deviceId, dosisId} o {deviceId, itemId, hhmm}: "Lo tomé". La segunda forma marca una toma que todavia no tenia aviso (por ejemplo, la tomo antes de hora). */
async function nativeMedOk(request: Request, env: Env) {
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const email = await nativeOwnerEmail(request, env, String(body.deviceId ?? ""));
  if (!email) return json({ error: "unauthorized" }, 401);
  await medTabla(env);
  await cuidadoTabla(env);
  const ahora = new Date().toISOString();
  type Fila = { id: string; okAt: string | null; alertAt: string | null };
  let d: Fila | null = null;
  if (typeof body.dosisId === "string") {
    d = await env.DB.prepare("SELECT id, ok_at AS okAt, alert_at AS alertAt FROM med_dosis WHERE id=? AND email=?").bind(body.dosisId, email).first<Fila>();
  } else if (typeof body.itemId === "string" && typeof body.hhmm === "string" && /^([01]\d|2[0-3]):[0-5]\d$/.test(body.hhmm)) {
    const item = await env.DB.prepare("SELECT id FROM med_items WHERE id=? AND email=?").bind(body.itemId, email).first<{ id: string }>();
    if (!item) return json({ error: "not_found" }, 404);
    const prefs = await cuidadoPrefs(env, email);
    const loc = cuidadoLocal(Date.now(), prefs.tz);
    await env.DB.prepare("INSERT OR IGNORE INTO med_dosis (id,email,item_id,day,hhmm,sent_at) VALUES (?,?,?,?,?,?)").bind(crypto.randomUUID(), email, body.itemId, loc.dia, body.hhmm, ahora).run();
    d = await env.DB.prepare("SELECT id, ok_at AS okAt, alert_at AS alertAt FROM med_dosis WHERE item_id=? AND day=? AND hhmm=? AND email=?").bind(body.itemId, loc.dia, body.hhmm, email).first<Fila>();
  }
  if (!d) return json({ error: "not_found" }, 404);
  if (d.okAt) return json({ ok: true, unchanged: true });
  await env.DB.prepare("UPDATE med_dosis SET ok_at=? WHERE id=? AND ok_at IS NULL").bind(ahora, d.id).run();
  // Si ya se les habia avisado a los demas, se les dice que lo confirmo.
  if (d.alertAt) await cuidadoAvisar(env, email, (nombre) => `${nombre} ya confirmó su remedio.`, "cuidado remedio ok").catch(() => 0);
  return json({ ok: true });
}

', '// ---------------------------------------------------------------------------
// Remedios (Familia y amigos > Cuidado). OPCIONAL: los carga, los prende y los apaga la propia persona (ella decide; la app no).
//  - A la hora de cada remedio le llega un aviso; "Lo tomé" lo marca. Si no lo confirma en 15 minutos se le avisa una vez mas.
//  - Opcional y APAGADO por defecto: "Avisar a mi familia si no lo confirmo". Si pasa el plazo que elige, se avisa a quienes reciben SU SOS, sin decir el nombre del remedio.
//  - Los nombres de los remedios son datos de salud: solo los ve la propia persona. A los demas (panel) se les muestra cuantos tomo hoy.
//   CREATE TABLE IF NOT EXISTS med_items (id TEXT PRIMARY KEY, email TEXT NOT NULL, nombre TEXT NOT NULL, horas TEXT NOT NULL, dias TEXT NOT NULL, activo INTEGER NOT NULL DEFAULT 1, created_at TEXT NOT NULL);
//   CREATE TABLE IF NOT EXISTS med_dosis (id TEXT PRIMARY KEY, email TEXT NOT NULL, item_id TEXT NOT NULL, day TEXT NOT NULL, hhmm TEXT NOT NULL, sent_at TEXT, rem_at TEXT, ok_at TEXT, alert_at TEXT);
//   CREATE TABLE IF NOT EXISTS med_prefs (email TEXT PRIMARY KEY, avisar INTEGER NOT NULL DEFAULT 0, limite_min INTEGER NOT NULL DEFAULT 60, updated_at TEXT NOT NULL);
// ---------------------------------------------------------------------------
const MED_MAX_ITEMS = 8, MED_MAX_HORAS = 6, MED_VENTANA_MIN = 20, MED_REAVISO_MIN = 15;
const MED_LIMITES = [30, 60, 90, 120];
let medTablaLista = false;
async function medTabla(env: Env) {
  if (medTablaLista) return;
  await env.DB.prepare("CREATE TABLE IF NOT EXISTS med_items (id TEXT PRIMARY KEY, email TEXT NOT NULL, nombre TEXT NOT NULL, horas TEXT NOT NULL, dias TEXT NOT NULL, activo INTEGER NOT NULL DEFAULT 1, created_at TEXT NOT NULL, dia_mes INTEGER)").run();
  await env.DB.prepare("CREATE TABLE IF NOT EXISTS med_dosis (id TEXT PRIMARY KEY, email TEXT NOT NULL, item_id TEXT NOT NULL, day TEXT NOT NULL, hhmm TEXT NOT NULL, sent_at TEXT, rem_at TEXT, ok_at TEXT, alert_at TEXT)").run();
  await env.DB.prepare("CREATE UNIQUE INDEX IF NOT EXISTS med_dosis_unica ON med_dosis (item_id, day, hhmm)").run();
  await env.DB.prepare("CREATE INDEX IF NOT EXISTS med_items_email ON med_items (email)").run();
  // Bases que ya tenian la tabla (sin la columna del dia del mes): se agrega; si ya esta, da error y se ignora.
  await env.DB.prepare("ALTER TABLE med_items ADD COLUMN dia_mes INTEGER").run().catch(() => undefined);
  await env.DB.prepare("CREATE TABLE IF NOT EXISTS med_prefs (email TEXT PRIMARY KEY, avisar INTEGER NOT NULL DEFAULT 0, limite_min INTEGER NOT NULL DEFAULT 60, updated_at TEXT NOT NULL)").run();
  medTablaLista = true;
}
type MedItem = { id: string; email: string; nombre: string; horas: string[]; dias: number[]; activo: boolean; diaMes: number | null };
type MedFila = { id: string; email: string; nombre: string; horas: string; dias: string; activo: number; diaMes: number | null };
function medParse(f: MedFila): MedItem {
  let horas: string[] = [];
  let dias: number[] = [];
  try { horas = (JSON.parse(f.horas) as unknown[]).map(String).filter((h) => /^([01]\d|2[0-3]):[0-5]\d$/.test(h)); } catch { /* fila vieja */ }
  try { dias = (JSON.parse(f.dias) as unknown[]).map(Number).filter((d) => Number.isInteger(d) && d >= 0 && d <= 6); } catch { /* fila vieja */ }
  const diaMes = Number.isInteger(f.diaMes) && Number(f.diaMes) >= 1 && Number(f.diaMes) <= 31 ? Number(f.diaMes) : null;
  return { id: f.id, email: f.email, nombre: f.nombre, horas, dias, activo: Boolean(f.activo), diaMes };
}
async function medItems(env: Env, email: string): Promise<MedItem[]> {
  const r = await env.DB.prepare("SELECT id,email,nombre,horas,dias,activo,dia_mes AS diaMes FROM med_items WHERE email=? ORDER BY created_at, id").bind(email).all<MedFila>();
  return r.results.map(medParse);
}
async function medPrefs(env: Env, email: string) {
  const f = await env.DB.prepare("SELECT avisar, limite_min AS limiteMin FROM med_prefs WHERE email=?").bind(email).first<{ avisar: number; limiteMin: number }>();
  return { avisar: Boolean(f?.avisar), limiteMin: Number(f?.limiteMin) || 60 };
}
type MedDosis = { id: string; itemId: string; hhmm: string; sentAt: string | null; okAt: string | null; alertAt: string | null };
async function medDosisDelDia(env: Env, email: string, dia: string): Promise<MedDosis[]> {
  const r = await env.DB.prepare("SELECT id, item_id AS itemId, hhmm, sent_at AS sentAt, ok_at AS okAt, alert_at AS alertAt FROM med_dosis WHERE email=? AND day=?").bind(email, dia).all<MedDosis>();
  return r.results;
}
/** ¿Toca este remedio hoy? Por dias de la semana (dias) o una vez al mes (diaMes; si el mes no tiene ese dia, el ultimo del mes). */
function medToca(it: MedItem, dow: number, dia: string) {
  if (it.diaMes !== null) {
    const y = Number(dia.slice(0, 4)), m = Number(dia.slice(5, 7)), d = Number(dia.slice(8, 10));
    const ultimo = new Date(Date.UTC(y, m, 0)).getUTCDate();
    return d === Math.min(it.diaMes, ultimo);
  }
  return it.dias.includes(dow);
}
/** "A", "A y B", "A, B y C". */
function medNombres(nombres: string[]) {
  return nombres.length > 1 ? `${nombres.slice(0, -1).join(", ")} y ${nombres[nombres.length - 1]}` : (nombres[0] ?? "");
}
/** Las tomas de hoy de una persona: programado (todavia no es la hora) | esperando (aviso enviado, sin confirmar) | tomado | sin_confirmar (ya se aviso a la familia) | sin_aviso (la hora paso antes de cargarlo: no cuenta). */
function medHoy(items: MedItem[], dosis: MedDosis[], hhmmAhora: string, dow: number, dia: string) {
  const lista: { itemId: string; nombre: string; hhmm: string; dosisId: string | null; estado: string }[] = [];
  for (const it of items) {
    if (!it.activo || !medToca(it, dow, dia)) continue;
    for (const hhmm of it.horas) {
      const d = dosis.find((x) => x.itemId === it.id && x.hhmm === hhmm);
      const estado = d?.okAt ? "tomado" : d?.alertAt ? "sin_confirmar" : d?.sentAt ? "esperando" : hhmm > hhmmAhora ? "programado" : "sin_aviso";
      lista.push({ itemId: it.id, nombre: it.nombre, hhmm, dosisId: d?.id ?? null, estado });
    }
  }
  return lista.sort((a, b) => a.hhmm.localeCompare(b.hhmm));
}
/** Para el panel y para quienes reciben su SOS: cuantos remedios de hoy tomo, SIN nombres (datos de salud). null si no usa remedios. */
async function remediosResumen(env: Env, email: string) {
  await medTabla(env);
  await cuidadoTabla(env);
  const [items, prefs, medP] = await Promise.all([medItems(env, email), cuidadoPrefs(env, email), medPrefs(env, email)]);
  if (!items.some((i) => i.activo)) return null;
  const loc = cuidadoLocal(Date.now(), prefs.tz);
  const dow = new Date(Date.now() + prefs.tz * 60_000).getUTCDay();
  const hoy = medHoy(items, await medDosisDelDia(env, email, loc.dia), loc.hhmm, dow, loc.dia).filter((x) => x.estado !== "sin_aviso");
  return {
    total: hoy.length,
    tomadas: hoy.filter((x) => x.estado === "tomado").length,
    esperando: hoy.filter((x) => x.estado === "esperando").length,
    sinConfirmar: hoy.filter((x) => x.estado === "sin_confirmar").length,
    avisa: medP.avisar,
  };
}
async function medAvisar(env: Env, email: string, titulo: string, texto: string, motivo: string, data: Record<string, unknown>) {
  await Promise.all((await pushTokensOf(env, email)).map((token) => sendExpoNoticeLogged(env, token, titulo, texto, motivo, { channelId: "ojo-familia-aviso", data }).catch(() => false)));
}

/** Cada minuto: avisa los remedios que tocan ahora (los de la misma hora, en UN solo aviso), repite una vez a los 15 minutos y (solo si la persona lo prendio) avisa a su familia si no confirmo. */
async function remediosCron(env: Env, ahoraMs = Date.now()) {
  await medTabla(env);
  await cuidadoTabla(env);
  const filas = await env.DB.prepare("SELECT id,email,nombre,horas,dias,activo,dia_mes AS diaMes FROM med_items WHERE activo=1").all<MedFila>();
  const porPersona = new Map<string, MedItem[]>();
  for (const f of filas.results) {
    const m = medParse(f);
    porPersona.set(m.email, [...(porPersona.get(m.email) ?? []), m]);
  }
  for (const [email, items] of porPersona) {
    try {
      const prefs = await cuidadoPrefs(env, email);
      const loc = cuidadoLocal(ahoraMs, prefs.tz);
      const dow = new Date(ahoraMs + prefs.tz * 60_000).getUTCDay();
      const minutosAhora = Number(loc.hhmm.slice(0, 2)) * 60 + Number(loc.hhmm.slice(3, 5));
      // Los remedios que tocan a la misma hora van en UN solo aviso.
      const porHora = new Map<string, MedItem[]>();
      for (const it of items) {
        if (!medToca(it, dow, loc.dia)) continue;
        for (const hhmm of it.horas) {
          const minutosHora = Number(hhmm.slice(0, 2)) * 60 + Number(hhmm.slice(3, 5));
          // Solo a la hora (con unos minutos de margen): un remedio cargado despues de su hora no avisa para atras.
          if (minutosAhora < minutosHora || minutosAhora >= minutosHora + MED_VENTANA_MIN) continue;
          porHora.set(hhmm, [...(porHora.get(hhmm) ?? []), it]);
        }
      }
      for (const [hhmm, lista] of porHora) {
        const nuevos: { id: string; nombre: string }[] = [];
        for (const it of lista) {
          const id = crypto.randomUUID();
          const r = await env.DB.prepare("INSERT OR IGNORE INTO med_dosis (id,email,item_id,day,hhmm,sent_at) VALUES (?,?,?,?,?,?)").bind(id, email, it.id, loc.dia, hhmm, new Date(ahoraMs).toISOString()).run();
          if (r.meta.changes) nuevos.push({ id, nombre: it.nombre });
        }
        if (!nuevos.length) continue;
        const nombres = medNombres(nuevos.map((n) => n.nombre));
        const varios = nuevos.length > 1;
        await medAvisar(env, email, varios ? "Remedios" : "Remedio", `Es hora de ${varios ? "tus remedios" : "tu remedio"}: ${nombres}. Tocá para confirmar.`, "remedio", { type: "remedio", dosisId: nuevos[0]?.id, dosisIds: nuevos.map((n) => n.id), day: loc.dia, hhmm });
      }
    } catch (error) {
      console.error("remedios_persona", String(error).slice(0, 120));
    }
  }
  const desde = new Date(ahoraMs - 24 * 3600_000).toISOString();
  const pendientes = await env.DB.prepare(
    "SELECT d.id AS id, d.email AS email, d.hhmm AS hhmm, d.sent_at AS sentAt, d.rem_at AS remAt, d.alert_at AS alertAt, i.nombre AS nombre, COALESCE(p.avisar,0) AS avisar, COALESCE(p.limite_min,60) AS limiteMin " +
    "FROM med_dosis d JOIN med_items i ON i.id=d.item_id LEFT JOIN med_prefs p ON p.email=d.email WHERE d.ok_at IS NULL AND d.sent_at IS NOT NULL AND d.sent_at>?",
  ).bind(desde).all<{ id: string; email: string; hhmm: string; sentAt: string; remAt: string | null; alertAt: string | null; nombre: string; avisar: number; limiteMin: number }>();
  // Los de la misma persona, dia y hora se tratan juntos: un solo recordatorio y un solo aviso a la familia.
  const grupos = new Map<string, typeof pendientes.results>();
  for (const d of pendientes.results) {
    const k = `${d.email}|${d.sentAt.slice(0, 10)}|${d.hhmm}`;
    grupos.set(k, [...(grupos.get(k) ?? []), d]);
  }
  for (const lista of grupos.values()) {
    try {
      const primero = lista[0];
      if (!primero) continue;
      const enviado = Math.min(...lista.map((d) => Date.parse(d.sentAt)));
      const sinRecordar = lista.filter((d) => !d.remAt);
      if (sinRecordar.length && ahoraMs >= enviado + MED_REAVISO_MIN * 60_000) {
        const marcadas: typeof lista = [];
        for (const d of sinRecordar) {
          const m = await env.DB.prepare("UPDATE med_dosis SET rem_at=? WHERE id=? AND rem_at IS NULL").bind(new Date(ahoraMs).toISOString(), d.id).run();
          if (m.meta.changes) marcadas.push(d);
        }
        if (marcadas.length) await medAvisar(env, primero.email, "Remedio", `¿Ya tomaste ${medNombres(marcadas.map((d) => d.nombre))}? Tocá para confirmar.`, "remedio repetido", { type: "remedio", dosisId: marcadas[0]?.id, dosisIds: marcadas.map((d) => d.id), hhmm: primero.hhmm });
      }
      const sinAvisar = lista.filter((d) => !d.alertAt);
      if (primero.avisar && sinAvisar.length && ahoraMs >= enviado + primero.limiteMin * 60_000) {
        let marcadas = 0;
        for (const d of sinAvisar) {
          const m = await env.DB.prepare("UPDATE med_dosis SET alert_at=? WHERE id=? AND alert_at IS NULL").bind(new Date(ahoraMs).toISOString(), d.id).run();
          if (m.meta.changes) marcadas++;
        }
        // Si el servidor estuvo caido mucho rato, no se avisa de algo viejo. Un solo aviso por hora, sin decir cuales ni cuantos remedios son (datos de salud).
        if (marcadas && ahoraMs < enviado + (primero.limiteMin + 180) * 60_000) {
          const hhmm = primero.hhmm;
          await cuidadoAvisar(env, primero.email, (nombre) => `${nombre} todavía no confirmó su remedio de las ${hhmm}.`, "cuidado remedio");
        }
      }
    } catch (error) {
      console.error("remedios_pendiente", String(error).slice(0, 120));
    }
  }
}

/** Anota la zona horaria de la persona sin tocar lo demas de Cuidado (los remedios avisan a SU hora). */
async function medGuardarZona(env: Env, email: string, tz: unknown) {
  const n = Number(tz);
  if (!Number.isFinite(n) || n < -720 || n > 840) return;
  await env.DB.prepare("INSERT INTO care_prefs (email,battery_on,buen_on,buen_hora,buen_limite_min,tz_min,updated_at) VALUES (?,1,0,''09:00'',60,?,?) ON CONFLICT(email) DO UPDATE SET tz_min=excluded.tz_min").bind(email, Math.round(n), now()).run();
}

/** GET /api/native/care/med: mis remedios, como van hoy y a quien se le avisaria. */
async function nativeMed(request: Request, env: Env, url: URL) {
  const email = await nativeOwnerEmail(request, env, url.searchParams.get("deviceId") ?? "");
  if (!email) return json({ error: "unauthorized" }, 401);
  await medTabla(env);
  await cuidadoTabla(env);
  const [items, prefs, medP] = await Promise.all([medItems(env, email), cuidadoPrefs(env, email), medPrefs(env, email)]);
  const loc = cuidadoLocal(Date.now(), prefs.tz);
  const dow = new Date(Date.now() + prefs.tz * 60_000).getUTCDay();
  const hoy = medHoy(items, await medDosisDelDia(env, email, loc.dia), loc.hhmm, dow, loc.dia);
  const destinos = await Promise.all((await familySosRecipients(env, email)).map((q) => familyNameSeenBy(env, q, email)));
  return json({
    items: items.map((i) => ({ id: i.id, nombre: i.nombre, horas: i.horas, dias: i.dias, activo: i.activo, diaMes: i.diaMes })),
    prefs: { avisar: medP.avisar, limiteMin: medP.limiteMin },
    hoy,
    destinatarios: destinos,
    max: { items: MED_MAX_ITEMS, horas: MED_MAX_HORAS },
  });
}

/** POST /api/native/care/med/item {deviceId, id?, nombre, horas[], dias[]? | diaMes?, activo?, tzOffsetMin?}: crea o cambia uno de MIS remedios (por dias de la semana, o una vez al mes con diaMes). */
async function nativeMedItem(request: Request, env: Env) {
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const email = await nativeOwnerEmail(request, env, String(body.deviceId ?? ""));
  if (!email) return json({ error: "unauthorized" }, 401);
  await medTabla(env);
  const nombre = String(body.nombre ?? "").replace(/[\u0000-\u001f\u007f]/g, " ").replace(/\s+/g, " ").trim().slice(0, 40);
  if (!nombre) return json({ error: "invalid_request" }, 400);
  const horasEntrada = Array.isArray(body.horas) ? body.horas.map(String) : [];
  const horas = [...new Set(horasEntrada)].filter((h) => /^([01]\d|2[0-3]):[0-5]\d$/.test(h)).sort();
  if (!horas.length || horas.length > MED_MAX_HORAS) return json({ error: "invalid_request" }, 400);
  const diaMes = body.diaMes === undefined || body.diaMes === null ? null : Number(body.diaMes);
  if (diaMes !== null && (!Number.isInteger(diaMes) || diaMes < 1 || diaMes > 31)) return json({ error: "invalid_request" }, 400);
  const diasEntrada = Array.isArray(body.dias) ? body.dias.map(Number) : [0, 1, 2, 3, 4, 5, 6];
  const dias = diaMes !== null ? [0, 1, 2, 3, 4, 5, 6] : [...new Set(diasEntrada)].filter((d) => Number.isInteger(d) && d >= 0 && d <= 6).sort();
  if (!dias.length) return json({ error: "invalid_request" }, 400);
  const activo = body.activo === false ? 0 : 1;
  let id = typeof body.id === "string" ? body.id : "";
  if (id) {
    const existe = await env.DB.prepare("SELECT id FROM med_items WHERE id=? AND email=?").bind(id, email).first<{ id: string }>();
    if (!existe) return json({ error: "not_found" }, 404);
    await env.DB.prepare("UPDATE med_items SET nombre=?, horas=?, dias=?, activo=?, dia_mes=? WHERE id=? AND email=?").bind(nombre, JSON.stringify(horas), JSON.stringify(dias), activo, diaMes, id, email).run();
  } else {
    const n = await env.DB.prepare("SELECT COUNT(*) AS n FROM med_items WHERE email=?").bind(email).first<{ n: number }>();
    if (Number(n?.n ?? 0) >= MED_MAX_ITEMS) return json({ error: "too_many" }, 409);
    id = crypto.randomUUID();
    await env.DB.prepare("INSERT INTO med_items (id,email,nombre,horas,dias,activo,created_at,dia_mes) VALUES (?,?,?,?,?,?,?,?)").bind(id, email, nombre, JSON.stringify(horas), JSON.stringify(dias), activo, now(), diaMes).run();
  }
  if (body.tzOffsetMin !== undefined) await cuidadoTabla(env).then(() => medGuardarZona(env, email, body.tzOffsetMin)).catch(() => undefined);
  return json({ ok: true, id });
}

/** POST /api/native/care/med/item/delete {deviceId, id}: borra uno de MIS remedios (y sus tomas). */
async function nativeMedItemDelete(request: Request, env: Env) {
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const email = await nativeOwnerEmail(request, env, String(body.deviceId ?? ""));
  if (!email) return json({ error: "unauthorized" }, 401);
  await medTabla(env);
  const id = String(body.id ?? "");
  const existe = await env.DB.prepare("SELECT id FROM med_items WHERE id=? AND email=?").bind(id, email).first<{ id: string }>();
  if (!existe) return json({ error: "not_found" }, 404);
  await env.DB.prepare("DELETE FROM med_dosis WHERE item_id=? AND email=?").bind(id, email).run();
  await env.DB.prepare("DELETE FROM med_items WHERE id=? AND email=?").bind(id, email).run();
  return json({ ok: true });
}

/** POST /api/native/care/med/prefs {deviceId, avisar?, limiteMin?}: "Avisar a mi familia si no lo confirmo" (apagado por defecto). */
async function nativeMedPrefs(request: Request, env: Env) {
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const email = await nativeOwnerEmail(request, env, String(body.deviceId ?? ""));
  if (!email) return json({ error: "unauthorized" }, 401);
  await medTabla(env);
  const p = await medPrefs(env, email);
  if (body.avisar !== undefined) { if (typeof body.avisar !== "boolean") return json({ error: "invalid_request" }, 400); p.avisar = body.avisar; }
  if (body.limiteMin !== undefined) { if (!MED_LIMITES.includes(Number(body.limiteMin))) return json({ error: "invalid_request" }, 400); p.limiteMin = Number(body.limiteMin); }
  // Sin nadie a quien avisar no tiene sentido prenderlo.
  if (p.avisar && body.avisar === true && (await familySosRecipients(env, email)).length === 0) return json({ error: "no_recipients" }, 409);
  await env.DB.prepare("INSERT INTO med_prefs (email,avisar,limite_min,updated_at) VALUES (?,?,?,?) ON CONFLICT(email) DO UPDATE SET avisar=excluded.avisar, limite_min=excluded.limite_min, updated_at=excluded.updated_at").bind(email, p.avisar ? 1 : 0, p.limiteMin, now()).run();
  return json({ ok: true });
}

/** POST /api/native/care/med/ok {deviceId, dosisId | dosisIds[]} o {deviceId, itemId, hhmm}: "Lo tomé" (uno o todos los de una hora). La segunda forma marca una toma que todavia no tenia aviso (por ejemplo, la tomo antes de hora). */
async function nativeMedOk(request: Request, env: Env) {
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const email = await nativeOwnerEmail(request, env, String(body.deviceId ?? ""));
  if (!email) return json({ error: "unauthorized" }, 401);
  await medTabla(env);
  await cuidadoTabla(env);
  const ahora = new Date().toISOString();
  type Fila = { id: string; okAt: string | null; alertAt: string | null };
  const filas: Fila[] = [];
  const ids = [...new Set([...(typeof body.dosisId === "string" ? [body.dosisId] : []), ...(Array.isArray(body.dosisIds) ? body.dosisIds.map(String) : [])])].slice(0, 20);
  if (ids.length) {
    for (const id of ids) {
      const f = await env.DB.prepare("SELECT id, ok_at AS okAt, alert_at AS alertAt FROM med_dosis WHERE id=? AND email=?").bind(id, email).first<Fila>();
      if (f) filas.push(f);
    }
  } else if (typeof body.itemId === "string" && typeof body.hhmm === "string" && /^([01]\d|2[0-3]):[0-5]\d$/.test(body.hhmm)) {
    const item = await env.DB.prepare("SELECT id FROM med_items WHERE id=? AND email=?").bind(body.itemId, email).first<{ id: string }>();
    if (!item) return json({ error: "not_found" }, 404);
    const prefs = await cuidadoPrefs(env, email);
    const loc = cuidadoLocal(Date.now(), prefs.tz);
    await env.DB.prepare("INSERT OR IGNORE INTO med_dosis (id,email,item_id,day,hhmm,sent_at) VALUES (?,?,?,?,?,?)").bind(crypto.randomUUID(), email, body.itemId, loc.dia, body.hhmm, ahora).run();
    const f = await env.DB.prepare("SELECT id, ok_at AS okAt, alert_at AS alertAt FROM med_dosis WHERE item_id=? AND day=? AND hhmm=? AND email=?").bind(body.itemId, loc.dia, body.hhmm, email).first<Fila>();
    if (f) filas.push(f);
  }
  if (!filas.length) return json({ error: "not_found" }, 404);
  let confirmadas = 0;
  let habiaAlerta = false;
  for (const d of filas) {
    if (d.okAt) continue;
    await env.DB.prepare("UPDATE med_dosis SET ok_at=? WHERE id=? AND ok_at IS NULL").bind(ahora, d.id).run();
    confirmadas++;
    if (d.alertAt) habiaAlerta = true;
  }
  if (!confirmadas) return json({ ok: true, unchanged: true });
  // Si ya se les habia avisado a los demas, se les dice que lo confirmo.
  if (habiaAlerta) await cuidadoAvisar(env, email, (nombre) => `${nombre} ya confirmó su remedio.`, "cuidado remedio ok").catch(() => 0);
  return json({ ok: true, confirmadas });
}

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
Ok "Archivos listos. Ahora publico el panel..."
& npx.cmd wrangler deploy
if ($LASTEXITCODE -ne 0) { Mal "No se pudo publicar el panel. Mandame esta pantalla."; return }
Write-Host ""
Ok "LISTO: los remedios de la misma hora van en un solo aviso, y se pueden cargar por dias de la semana o una vez al mes."
Write-Host ""
