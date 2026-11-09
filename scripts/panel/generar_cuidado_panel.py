# Genera scripts/aplicar-cuidado-panel.ps1: servicios de cuidado OPCIONALES que activa la propia persona: aviso de bateria baja / sin senal y "Buen dia".
import re
R = '/home/user/Murray/scripts/'
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"

BLOQUE = r'''// ---------------------------------------------------------------------------
// Cuidado (Familia y amigos > Cuidado). Servicios OPCIONALES que activa la propia persona: la app no decide por nadie y no juzga.
//  - Bateria baja y "sin senal": se avisa a quienes reciben SU SOS (familySosRecipients, con sus llaves de permisos).
//  - "Buen dia": un saludo diario a la hora que ella elige; si no contesta en el plazo que ella elige, se avisa a quienes reciben su SOS.
//   CREATE TABLE IF NOT EXISTS care_prefs (email TEXT PRIMARY KEY, battery_on INTEGER NOT NULL DEFAULT 1, buen_on INTEGER NOT NULL DEFAULT 0,
//     buen_hora TEXT NOT NULL DEFAULT '09:00', buen_limite_min INTEGER NOT NULL DEFAULT 60, tz_min INTEGER NOT NULL DEFAULT -180, updated_at TEXT NOT NULL);
//   CREATE TABLE IF NOT EXISTS care_state (email TEXT PRIMARY KEY, bat_low INTEGER NOT NULL DEFAULT 0, silence_at TEXT, bd_day TEXT,
//     bd_sent_at TEXT, bd_ok_at TEXT, bd_alert_at TEXT);
// ---------------------------------------------------------------------------
type CuidadoPrefs = { bateria: boolean; buenDia: boolean; hora: string; limiteMin: number; tz: number };
const CUIDADO_BATERIA_BAJA = 15, CUIDADO_BATERIA_OK = 30, CUIDADO_SIN_SENAL_MIN = 180, CUIDADO_VENTANA_MIN = 240;
const CUIDADO_LIMITES = [30, 60, 90, 120];
let cuidadoTablaLista = false;
async function cuidadoTabla(env: Env) {
  if (cuidadoTablaLista) return;
  await env.DB.prepare("CREATE TABLE IF NOT EXISTS care_prefs (email TEXT PRIMARY KEY, battery_on INTEGER NOT NULL DEFAULT 1, buen_on INTEGER NOT NULL DEFAULT 0, buen_hora TEXT NOT NULL DEFAULT '09:00', buen_limite_min INTEGER NOT NULL DEFAULT 60, tz_min INTEGER NOT NULL DEFAULT -180, updated_at TEXT NOT NULL)").run();
  await env.DB.prepare("CREATE TABLE IF NOT EXISTS care_state (email TEXT PRIMARY KEY, bat_low INTEGER NOT NULL DEFAULT 0, silence_at TEXT, bd_day TEXT, bd_sent_at TEXT, bd_ok_at TEXT, bd_alert_at TEXT)").run();
  cuidadoTablaLista = true;
}
async function cuidadoPrefs(env: Env, email: string): Promise<CuidadoPrefs> {
  const f = await env.DB.prepare("SELECT battery_on AS bateria, buen_on AS buenDia, buen_hora AS hora, buen_limite_min AS limiteMin, tz_min AS tz FROM care_prefs WHERE email=?").bind(email).first<{ bateria: number; buenDia: number; hora: string; limiteMin: number; tz: number }>();
  return f ? { bateria: Boolean(f.bateria), buenDia: Boolean(f.buenDia), hora: f.hora, limiteMin: f.limiteMin, tz: f.tz } : { bateria: true, buenDia: false, hora: "09:00", limiteMin: 60, tz: -180 };
}
type CuidadoEstado = { bat_low: number; silence_at: string | null; bd_day: string | null; bd_sent_at: string | null; bd_ok_at: string | null; bd_alert_at: string | null };
async function cuidadoEstado(env: Env, email: string): Promise<CuidadoEstado> {
  const f = await env.DB.prepare("SELECT bat_low, silence_at, bd_day, bd_sent_at, bd_ok_at, bd_alert_at FROM care_state WHERE email=?").bind(email).first<CuidadoEstado>();
  return f ?? { bat_low: 0, silence_at: null, bd_day: null, bd_sent_at: null, bd_ok_at: null, bd_alert_at: null };
}
async function cuidadoGuardar(env: Env, email: string, e: CuidadoEstado) {
  await env.DB.prepare("INSERT INTO care_state (email,bat_low,silence_at,bd_day,bd_sent_at,bd_ok_at,bd_alert_at) VALUES (?,?,?,?,?,?,?) ON CONFLICT(email) DO UPDATE SET bat_low=excluded.bat_low, silence_at=excluded.silence_at, bd_day=excluded.bd_day, bd_sent_at=excluded.bd_sent_at, bd_ok_at=excluded.bd_ok_at, bd_alert_at=excluded.bd_alert_at")
    .bind(email, e.bat_low, e.silence_at, e.bd_day, e.bd_sent_at, e.bd_ok_at, e.bd_alert_at).run();
}
/** Fecha y hora de pared (HH:MM) de la persona, segun el huso que mando su telefono. */
function cuidadoLocal(ahoraMs: number, tzMin: number) {
  const iso = new Date(ahoraMs + tzMin * 60_000).toISOString();
  return { dia: iso.slice(0, 10), hhmm: iso.slice(11, 16), hora: Number(iso.slice(11, 13)) };
}
/** Un aviso a cada persona que recibe el SOS de `de`, con el nombre con que la ve cada una. */
async function cuidadoAvisar(env: Env, de: string, texto: (nombre: string) => string, motivo: string) {
  const destinos = await familySosRecipients(env, de);
  for (const quien of destinos) {
    const nombre = await familyNameSeenBy(env, de, quien);
    await Promise.all((await pushTokensOf(env, quien)).map((token) => sendExpoNoticeLogged(env, token, "Ojo Guard", texto(nombre), motivo, { channelId: "ojo-familia-aviso" }).catch(() => false)));
  }
  return destinos.length;
}

async function cuidadoCron(env: Env, ahoraMs = Date.now()) {
  await cuidadoTabla(env);
  // 1) Bateria y senal: cada 5 minutos alcanza.
  if (new Date(ahoraMs).getUTCMinutes() % 5 === 0) {
    const equipos = await env.DB.prepare("SELECT owner_email AS email, battery, last_seen_at AS lastSeenAt FROM devices WHERE approval_status='approved' AND device_role='primary'")
      .all<{ email: string; battery: number | null; lastSeenAt: string | null }>();
    for (const eq of equipos.results) {
      try {
        const prefs = await cuidadoPrefs(env, eq.email);
        if (!prefs.bateria) continue;
        const e = await cuidadoEstado(env, eq.email);
        let cambio = false;
        const visto = eq.lastSeenAt ? Date.parse(eq.lastSeenAt) : NaN;
        const calladoMin = Number.isFinite(visto) ? (ahoraMs - visto) / 60_000 : null;
        // Bateria baja: un aviso por bajada; se rearma cuando vuelve a subir.
        if (typeof eq.battery === "number") {
          if (eq.battery <= CUIDADO_BATERIA_BAJA && !e.bat_low && calladoMin !== null && calladoMin < 360) {
            const n = eq.battery;
            await cuidadoAvisar(env, eq.email, (nombre) => `${nombre} tiene la batería baja (${n}%).`, "cuidado bateria");
            e.bat_low = 1; cambio = true;
          } else if (eq.battery >= CUIDADO_BATERIA_OK && e.bat_low) { e.bat_low = 0; cambio = true; }
        }
        // Sin senal: de noche (23 a 7, hora de la persona) no se avisa; un aviso por silencio.
        if (calladoMin !== null) {
          if (e.silence_at && Number.isFinite(visto) && visto > Date.parse(e.silence_at)) { e.silence_at = null; cambio = true; }
          const hora = cuidadoLocal(ahoraMs, prefs.tz).hora;
          const deNoche = hora >= 23 || hora < 7;
          if (!e.silence_at && calladoMin >= CUIDADO_SIN_SENAL_MIN && !deNoche) {
            const horas = Math.floor(calladoMin / 60), bat = typeof eq.battery === "number" ? ` Su batería era ${eq.battery}%.` : "";
            await cuidadoAvisar(env, eq.email, (nombre) => `No tenemos señal de ${nombre} desde hace ${horas} h.${bat}`, "cuidado sin senal");
            e.silence_at = new Date(ahoraMs).toISOString(); cambio = true;
          }
        }
        if (cambio) await cuidadoGuardar(env, eq.email, e);
      } catch (error) {
        console.error("cuidado_equipo", String(error).slice(0, 120));
      }
    }
  }
  // 2) Buen dia.
  const personas = await env.DB.prepare("SELECT email, buen_hora AS hora, buen_limite_min AS limiteMin, tz_min AS tz FROM care_prefs WHERE buen_on=1")
    .all<{ email: string; hora: string; limiteMin: number; tz: number }>();
  for (const p of personas.results) {
    try {
      const e = await cuidadoEstado(env, p.email);
      const loc = cuidadoLocal(ahoraMs, p.tz);
      const minutosHora = Number(p.hora.slice(0, 2)) * 60 + Number(p.hora.slice(3, 5));
      const minutosAhora = Number(loc.hhmm.slice(0, 2)) * 60 + Number(loc.hhmm.slice(3, 5));
      // El saludo sale a la hora elegida (hasta 4 h despues: si se prendio mas tarde, empieza manana).
      if (e.bd_day !== loc.dia && minutosAhora >= minutosHora && minutosAhora < minutosHora + CUIDADO_VENTANA_MIN) {
        const nombre = (await nombrePerfil(env, p.email)) || p.email.split("@")[0].replace(/^./, (c) => c.toUpperCase());
        await Promise.all((await pushTokensOf(env, p.email)).map((token) => sendExpoNoticeLogged(env, token, "Buen día", `${nombre}, ¿todo bien? Tocá acá para avisar que estás bien.`, "buen dia", { channelId: "ojo-familia-aviso", data: { type: "buen-dia", day: loc.dia } }).catch(() => false)));
        e.bd_day = loc.dia; e.bd_sent_at = new Date(ahoraMs).toISOString(); e.bd_ok_at = null; e.bd_alert_at = null;
        await cuidadoGuardar(env, p.email, e);
        continue;
      }
      if (e.bd_day === loc.dia && e.bd_sent_at && !e.bd_ok_at && !e.bd_alert_at && ahoraMs >= Date.parse(e.bd_sent_at) + p.limiteMin * 60_000) {
        const hora = p.hora;
        await cuidadoAvisar(env, p.email, (nombre) => `${nombre} todavía no contestó su "Buen día" de las ${hora}.`, "cuidado buen dia");
        e.bd_alert_at = new Date(ahoraMs).toISOString();
        await cuidadoGuardar(env, p.email, e);
      }
    } catch (error) {
      console.error("cuidado_buen_dia", String(error).slice(0, 120));
    }
  }
}

/** GET /api/native/care: lo que la persona tiene prendido, como va el "Buen dia" de hoy y a quien se le avisa. */
async function nativeCare(request: Request, env: Env, url: URL) {
  const email = await nativeOwnerEmail(request, env, url.searchParams.get("deviceId") ?? "");
  if (!email) return json({ error: "unauthorized" }, 401);
  await cuidadoTabla(env);
  const prefs = await cuidadoPrefs(env, email), e = await cuidadoEstado(env, email);
  const hoy = cuidadoLocal(Date.now(), prefs.tz).dia;
  const destinos = await Promise.all((await familySosRecipients(env, email)).map((q) => familyNameSeenBy(env, q, email)));
  return json({ prefs: { bateria: prefs.bateria, buenDia: prefs.buenDia, hora: prefs.hora, limiteMin: prefs.limiteMin }, hoy: { enviado: e.bd_day === hoy && Boolean(e.bd_sent_at), contesto: e.bd_day === hoy && Boolean(e.bd_ok_at), alertado: e.bd_day === hoy && Boolean(e.bd_alert_at) }, destinatarios: destinos });
}

/** POST /api/native/care/prefs {deviceId, bateria?, buenDia?, hora?, limiteMin?, tzOffsetMin?}: la persona prende o apaga lo suyo. */
async function nativeCarePrefs(request: Request, env: Env) {
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const email = await nativeOwnerEmail(request, env, String(body.deviceId ?? ""));
  if (!email) return json({ error: "unauthorized" }, 401);
  await cuidadoTabla(env);
  const p = await cuidadoPrefs(env, email);
  if (body.bateria !== undefined) { if (typeof body.bateria !== "boolean") return json({ error: "invalid_request" }, 400); p.bateria = body.bateria; }
  if (body.buenDia !== undefined) { if (typeof body.buenDia !== "boolean") return json({ error: "invalid_request" }, 400); p.buenDia = body.buenDia; }
  if (body.hora !== undefined) { if (typeof body.hora !== "string" || !/^([01]\d|2[0-3]):[0-5]\d$/.test(body.hora)) return json({ error: "invalid_request" }, 400); p.hora = body.hora; }
  if (body.limiteMin !== undefined) { if (!CUIDADO_LIMITES.includes(Number(body.limiteMin))) return json({ error: "invalid_request" }, 400); p.limiteMin = Number(body.limiteMin); }
  if (body.tzOffsetMin !== undefined) { const tz = Number(body.tzOffsetMin); if (!Number.isFinite(tz) || tz < -720 || tz > 840) return json({ error: "invalid_request" }, 400); p.tz = Math.round(tz); }
  // El "Buen dia" avisa a quienes reciben tu SOS: sin nadie a quien avisar no tiene sentido prenderlo.
  if (p.buenDia && body.buenDia === true && (await familySosRecipients(env, email)).length === 0) return json({ error: "no_recipients" }, 409);
  await env.DB.prepare("INSERT INTO care_prefs (email,battery_on,buen_on,buen_hora,buen_limite_min,tz_min,updated_at) VALUES (?,?,?,?,?,?,?) ON CONFLICT(email) DO UPDATE SET battery_on=excluded.battery_on, buen_on=excluded.buen_on, buen_hora=excluded.buen_hora, buen_limite_min=excluded.buen_limite_min, tz_min=excluded.tz_min, updated_at=excluded.updated_at")
    .bind(email, p.bateria ? 1 : 0, p.buenDia ? 1 : 0, p.hora, p.limiteMin, p.tz, now()).run();
  return json({ ok: true });
}

/** POST /api/native/care/buen-dia/ok {deviceId, day?}: la persona contesta "estoy bien". */
async function nativeCareOk(request: Request, env: Env) {
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const email = await nativeOwnerEmail(request, env, String(body.deviceId ?? ""));
  if (!email) return json({ error: "unauthorized" }, 401);
  await cuidadoTabla(env);
  const e = await cuidadoEstado(env, email);
  if (!e.bd_sent_at || e.bd_ok_at) return json({ ok: true, unchanged: true });
  // Tocar el aviso de AYER no cuenta para hoy: el aviso trae el dia al que corresponde.
  if (typeof body.day === "string" && body.day !== e.bd_day) return json({ ok: true, unchanged: true });
  e.bd_ok_at = new Date().toISOString();
  await cuidadoGuardar(env, email, e);
  // Si ya se les habia avisado a los demas, se les dice que esta bien.
  if (e.bd_alert_at) await cuidadoAvisar(env, email, (nombre) => `${nombre} ya contestó su "Buen día": está bien.`, "cuidado buen dia ok").catch(() => 0);
  return json({ ok: true });
}

'''
A0 = 'async function nativeFamilyPause(request: Request, env: Env) {\n'
B0 = BLOQUE + A0
A1 = '      ctx.waitUntil(gdCron(env).catch((error) => console.error("gd_cron_failed", error)));\n'
B1 = A1 + '      ctx.waitUntil(cuidadoCron(env).catch((error) => console.error("cuidado_cron_failed", error)));\n'
A2 = '      if (route === "POST /api/native/family/perm") return nativeFamilyPerm(request, env);\n'
B2 = (A2 + '      if (route === "GET /api/native/care") return nativeCare(request, env, url);\n'
      '      if (route === "POST /api/native/care/prefs") return nativeCarePrefs(request, env);\n'
      '      if (route === "POST /api/native/care/buen-dia/ok") return nativeCareOk(request, env);\n')
A3 = '  await borrar("family_perms", "DELETE FROM family_perms WHERE from_email=? OR to_email=?", 2);\n'
B3 = A3 + '  await borrar("care_prefs", "DELETE FROM care_prefs WHERE email=?", 1);\n  await borrar("care_state", "DELETE FROM care_state WHERE email=?", 1);\n'
pares = [A0, A1, A2, A3]; nuevos = [B0, B1, B2, B3]
nombres = ['cuidado: tablas, avisos, Buen dia y endpoints', 'cuidado: cron de cada minuto', 'cuidado: rutas', 'cuidado: borrar cuenta']
filas = [('src\\index.ts', n, a, b) for n, a, b in zip(nombres, pares, nuevos)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-cuidado-panel.ps1 - Ojo Guard MS: servicios de cuidado OPCIONALES (los activa la propia persona): aviso de bateria baja / sin senal y "Buen dia".
# Luciano (09/11/2026): ecosistema de familia y cuidado de personas mayores o con incapacidad motriz; "el mayor sigue siendo adulto, uno no puede decidir por el". Por eso todo es opcional y lo prende quien se cuida; los avisos van a quienes reciben SU SOS.
#  - Bateria baja (<= 15%) y sin senal (>= 3 h, no de noche): un aviso por episodio. Viene prendido y se apaga desde la app.
#  - "Buen dia": a la hora elegida le llega un saludo; si no contesta en el plazo elegido (30 min a 2 h) se avisa a quienes reciben su SOS; si contesta despues, se les avisa que esta bien. Viene apagado.
# Tablas nuevas care_prefs y care_state (se crean solas). Requiere aplicar-permisos-ojo-panel.ps1. Cambia SOLO src\\index.ts (respaldo .bak-cuidado). Va en la carpeta del PANEL. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'async function nativeFamilyPerm') -eq 0) { Mal "Falta aplicar primero aplicar-permisos-ojo-panel.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'async function cuidadoCron') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-cuidado')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: el cuidado (bateria, sin senal y Buen dia) ya esta en el servidor."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + tpl[i:j] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›✓']
assert not bad, set(bad)
open(R + 'aplicar-cuidado-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
t = open(S + 'index-permisos4.ts', encoding='utf-8').read()
for a in pares:
    assert t.count(a) == 1, (t.count(a), a[:60])
for a, b in zip(pares, nuevos):
    t = t.replace(a, b)
open(S + 'index-cuidado.ts', 'w', encoding='utf-8').write(t)
print('ok', len(total), len(t))
