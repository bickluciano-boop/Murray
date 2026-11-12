# Genera scripts/aplicar-remedios-panel.ps1: RECORDATORIOS DE REMEDIOS (servidor + linea en el panel).
# Luciano (12/11/2026): "despues ponemos lo de los recordatorios de remedios". Version 1 aprobada: los carga la PROPIA persona (nadie decide por ella), opcional.
#  - A la hora de cada remedio le llega un aviso; "Lo tomé" lo marca. Si no confirma en 15 min se le avisa una vez mas.
#  - Opcional y APAGADO por defecto: "Avisar a mi familia si no lo confirmo" (como el Buen dia): si pasa el plazo que elige, se avisa a quienes reciben SU SOS, SIN decir el nombre del remedio.
#  - Los nombres de los remedios son datos de salud: solo los ve la propia persona. El panel muestra cuantos tomo hoy.
import re
R = '/home/user/Murray/scripts/'
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"

BLOQUE = r'''// ---------------------------------------------------------------------------
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
  await env.DB.prepare("INSERT INTO care_prefs (email,battery_on,buen_on,buen_hora,buen_limite_min,tz_min,updated_at) VALUES (?,1,0,'09:00',60,?,?) ON CONFLICT(email) DO UPDATE SET tz_min=excluded.tz_min").bind(email, Math.round(n), now()).run();
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

'''

A0 = '/** GET /api/native/care: lo que la persona tiene prendido,'
B0 = BLOQUE + A0
A1 = '      ctx.waitUntil(cuidadoCron(env).catch((error) => console.error("cuidado_cron_failed", error)));\n'
B1 = A1 + '      ctx.waitUntil(remediosCron(env).catch((error) => console.error("remedios_cron_failed", error)));\n'
A2 = '      if (route === "POST /api/native/care/buen-dia/ok") return nativeCareOk(request, env);\n'
B2 = (A2 + '      if (route === "GET /api/native/care/med") return nativeMed(request, env, url);\n'
      '      if (route === "POST /api/native/care/med/item") return nativeMedItem(request, env);\n'
      '      if (route === "POST /api/native/care/med/item/delete") return nativeMedItemDelete(request, env);\n'
      '      if (route === "POST /api/native/care/med/prefs") return nativeMedPrefs(request, env);\n'
      '      if (route === "POST /api/native/care/med/ok") return nativeMedOk(request, env);\n')
A3 = '  await borrar("care_state", "DELETE FROM care_state WHERE email=?", 1);\n'
B3 = (A3 + '  await borrar("med_items", "DELETE FROM med_items WHERE email=?", 1);\n'
      '  await borrar("med_dosis", "DELETE FROM med_dosis WHERE email=?", 1);\n'
      '  await borrar("med_prefs", "DELETE FROM med_prefs WHERE email=?", 1);\n')
A4 = '  const [prefs, e, apagado] = await Promise.all([cuidadoPrefs(env, email), cuidadoEstado(env, email), sosApagado(env, email)]);\n'
B4 = '  const [prefs, e, apagado, remedios] = await Promise.all([cuidadoPrefs(env, email), cuidadoEstado(env, email), sosApagado(env, email), remediosResumen(env, email).catch(() => null)]);\n'
A5 = '    buenDiaHoy,\n  };\n}\n'
B5 = '    buenDiaHoy,\n    remedios,\n  };\n}\n'
pares = [(A0, B0), (A1, B1), (A2, B2), (A3, B3), (A4, B4), (A5, B5)]
nombres = ['remedios: funciones y rutas', 'remedios: aviso cada minuto', 'remedios: rutas', 'remedios: se borran con la cuenta', 'remedios: resumen en Cuidado (consulta)', 'remedios: resumen en Cuidado (resultado)']
filas = [('src\\index.ts', n, a, b) for n, (a, b) in zip(nombres, pares)]

# ---- panel (src\panel-mapa.txt): una linea mas en "Cuidado de X" ----
P1a = '  else filas.push(["suave", `Buen día: hoy a las ${hora}`]);\n  const color = {'
P1b = ('  else filas.push(["suave", `Buen día: hoy a las ${hora}`]);\n'
       '  // Remedios (solo si la persona los usa): cuantos tomo hoy, sin nombres (son datos de salud).\n'
       '  const rem = c.remedios;\n'
       '  if (rem && rem.total > 0) {\n'
       '    const texto = `Remedios: ${rem.tomadas} de ${rem.total} tomados hoy`;\n'
       '    if (rem.sinConfirmar > 0) filas.push(["off", `${texto} · ${rem.sinConfirmar} sin confirmar`]);\n'
       '    else filas.push([rem.tomadas === rem.total ? "ok" : "suave", rem.esperando > 0 ? `${texto} · ${rem.esperando} esperando` : texto]);\n'
       '  }\n'
       '  const color = {')
filas.append(('src\\panel-mapa.txt', 'mapa: linea de remedios en Cuidado', P1a, P1b))
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-remedios-panel.ps1 - Ojo Guard MS: RECORDATORIOS DE REMEDIOS (servidor) y una linea en la tarjeta de Cuidado del panel.
# Luciano (12/11/2026): "despues ponemos lo de los recordatorios de remedios". Opcional: los carga y los apaga la propia persona. A la hora le llega un aviso ("Lo tome"); si no confirma en 15 min se le avisa una vez mas.
# "Avisar a mi familia si no lo confirmo" (apagado por defecto) avisa a quienes reciben SU SOS, sin decir el nombre del remedio (son datos de salud). El panel muestra cuantos tomo hoy.
# Requiere aplicar-cuidado-estado-panel.ps1 y aplicar-family-rapido-panel.ps1 (ya aplicados). Cambia src\\index.ts y src\\panel-mapa.txt (respaldo .bak-remedios). Va en la carpeta del PANEL (la que tiene wrangler.toml). Sin build. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
foreach ($f in @("src\\index.ts", "src\\panel-mapa.txt")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
$indexTexto = (Leer (Join-Path $raiz "src\\index.ts")).texto
if ((Contar $indexTexto 'async function remediosCron') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $indexTexto 'const [prefs, e, apagado]') -eq 0) { Mal "Falta aplicar primero aplicar-family-rapido-panel.ps1. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-remedios')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: el servidor ya tiene los recordatorios de remedios (la app los muestra en la proxima build)."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + tpl[i:j] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›✓']
assert not bad, set(bad)
open(R + 'aplicar-remedios-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
t = open(S + 'index-rapido.ts', encoding='utf-8').read()
for a, _ in pares:
    assert t.count(a) == 1, (t.count(a), a[:70])
for a, b in pares:
    t = t.replace(a, b)
open(S + 'index-remedios.ts', 'w', encoding='utf-8').write(t)
m = open(S + 'panel-mapa-paralela.txt', encoding='utf-8').read().replace('\r\n', '\n')
assert m.count(P1a) == 1, m.count(P1a)
open(S + 'panel-mapa-remedios.txt', 'w', encoding='utf-8').write(m.replace(P1a, P1b))
print('ok', len(total))
