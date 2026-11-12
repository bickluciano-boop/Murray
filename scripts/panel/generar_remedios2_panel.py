# Genera scripts/aplicar-remedios2-panel.ps1: REMEDIOS v2 (servidor), a pedido de Luciano (12/11/2026) tras probar la 199:
#  - Varios remedios a la misma hora: UN solo aviso con todos ("Es hora de tus remedios: A y B"), un solo "Lo tome" y un solo aviso a la familia.
#  - Frecuencia: todos los dias / algunos dias de la semana / una vez al mes (un dia del mes; si el mes no lo tiene, el ultimo).
import re
R = '/home/user/Murray/scripts/'
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
g1 = open(R + 'panel/generar_remedios_panel.py', encoding='utf-8').read()
OLD = g1[g1.index("BLOQUE = r'''") + len("BLOQUE = r'''"): g1.index("'''\n\nA0 = ")]
NEW = OLD
def rep(a, b, veces=1):
    global NEW
    assert NEW.count(a) == veces, (NEW.count(a), a[:90])
    NEW = NEW.replace(a, b)

# --- tablas / tipos ---
rep('CREATE TABLE IF NOT EXISTS med_items (id TEXT PRIMARY KEY, email TEXT NOT NULL, nombre TEXT NOT NULL, horas TEXT NOT NULL, dias TEXT NOT NULL, activo INTEGER NOT NULL DEFAULT 1, created_at TEXT NOT NULL)").run();',
    'CREATE TABLE IF NOT EXISTS med_items (id TEXT PRIMARY KEY, email TEXT NOT NULL, nombre TEXT NOT NULL, horas TEXT NOT NULL, dias TEXT NOT NULL, activo INTEGER NOT NULL DEFAULT 1, created_at TEXT NOT NULL, dia_mes INTEGER)").run();', 1)
rep('  await env.DB.prepare("CREATE INDEX IF NOT EXISTS med_items_email ON med_items (email)").run();\n',
    '  await env.DB.prepare("CREATE INDEX IF NOT EXISTS med_items_email ON med_items (email)").run();\n  // Bases que ya tenian la tabla (sin la columna del dia del mes): se agrega; si ya esta, da error y se ignora.\n  await env.DB.prepare("ALTER TABLE med_items ADD COLUMN dia_mes INTEGER").run().catch(() => undefined);\n')
rep('type MedItem = { id: string; email: string; nombre: string; horas: string[]; dias: number[]; activo: boolean };\ntype MedFila = { id: string; email: string; nombre: string; horas: string; dias: string; activo: number };',
    'type MedItem = { id: string; email: string; nombre: string; horas: string[]; dias: number[]; activo: boolean; diaMes: number | null };\ntype MedFila = { id: string; email: string; nombre: string; horas: string; dias: string; activo: number; diaMes: number | null };')
rep('  return { id: f.id, email: f.email, nombre: f.nombre, horas, dias, activo: Boolean(f.activo) };',
    '  const diaMes = Number.isInteger(f.diaMes) && Number(f.diaMes) >= 1 && Number(f.diaMes) <= 31 ? Number(f.diaMes) : null;\n  return { id: f.id, email: f.email, nombre: f.nombre, horas, dias, activo: Boolean(f.activo), diaMes };')
rep('"SELECT id,email,nombre,horas,dias,activo FROM med_items WHERE email=? ORDER BY created_at, id"', '"SELECT id,email,nombre,horas,dias,activo,dia_mes AS diaMes FROM med_items WHERE email=? ORDER BY created_at, id"')
# --- toca hoy + nombres ---
rep('/** Las tomas de hoy de una persona:', '''/** ¿Toca este remedio hoy? Por dias de la semana (dias) o una vez al mes (diaMes; si el mes no tiene ese dia, el ultimo del mes). */
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
/** Las tomas de hoy de una persona:''')
rep('function medHoy(items: MedItem[], dosis: MedDosis[], hhmmAhora: string, dow: number) {', 'function medHoy(items: MedItem[], dosis: MedDosis[], hhmmAhora: string, dow: number, dia: string) {')
rep('    if (!it.activo || !it.dias.includes(dow)) continue;', '    if (!it.activo || !medToca(it, dow, dia)) continue;')
rep('const hoy = medHoy(items, await medDosisDelDia(env, email, loc.dia), loc.hhmm, dow).filter((x) => x.estado !== "sin_aviso");', 'const hoy = medHoy(items, await medDosisDelDia(env, email, loc.dia), loc.hhmm, dow, loc.dia).filter((x) => x.estado !== "sin_aviso");')
rep('const hoy = medHoy(items, await medDosisDelDia(env, email, loc.dia), loc.hhmm, dow);', 'const hoy = medHoy(items, await medDosisDelDia(env, email, loc.dia), loc.hhmm, dow, loc.dia);')
rep('items: items.map((i) => ({ id: i.id, nombre: i.nombre, horas: i.horas, dias: i.dias, activo: i.activo })),', 'items: items.map((i) => ({ id: i.id, nombre: i.nombre, horas: i.horas, dias: i.dias, activo: i.activo, diaMes: i.diaMes })),')

# --- cron ---
a = NEW.index('/** Cada minuto: avisa los remedios que tocan ahora')
b = NEW.index('/** Anota la zona horaria')
CRON = r'''/** Cada minuto: avisa los remedios que tocan ahora (los de la misma hora, en UN solo aviso), repite una vez a los 15 minutos y (solo si la persona lo prendio) avisa a su familia si no confirmo. */
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

'''
NEW = NEW[:a] + CRON + NEW[b:]

# --- guardar un remedio (con dia del mes) ---
a = NEW.index('/** POST /api/native/care/med/item {deviceId, id?')
b = NEW.index('/** POST /api/native/care/med/item/delete')
ITEM = r'''/** POST /api/native/care/med/item {deviceId, id?, nombre, horas[], dias[]? | diaMes?, activo?, tzOffsetMin?}: crea o cambia uno de MIS remedios (por dias de la semana, o una vez al mes con diaMes). */
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

'''
NEW = NEW[:a] + ITEM + NEW[b:]

# --- Lo tome: uno o varios ---
a = NEW.index('/** POST /api/native/care/med/ok')
OK = r'''/** POST /api/native/care/med/ok {deviceId, dosisId | dosisIds[]} o {deviceId, itemId, hhmm}: "Lo tomé" (uno o todos los de una hora). La segunda forma marca una toma que todavia no tenia aviso (por ejemplo, la tomo antes de hora). */
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

'''
NEW = NEW[:a] + OK
assert NEW.endswith('}\n\n')
open(S + 'med-bloque-v1.ts', 'w', encoding='utf-8').write(OLD)
open(S + 'med-bloque-v2.ts', 'w', encoding='utf-8').write(NEW)
filas = [('src\\index.ts', 'remedios v2: varios a la misma hora, semana y mes', OLD, NEW)]
# Con UNA sola fila, PowerShell aplana el arreglo: la coma delante lo evita.
cambios = "$cambios = @(\n" + ',\n'.join("    ,@(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-remedios2-panel.ps1 - Ojo Guard MS: REMEDIOS v2 (servidor). A pedido de Luciano (12/11/2026) tras probar la 199:
#  - Varios remedios a la misma hora: UN solo aviso con todos ("Es hora de tus remedios: A y B"), un solo "Lo tome" y un solo aviso a la familia.
#  - Frecuencia: todos los dias / algunos dias de la semana / una vez al mes (un dia del mes; si el mes no lo tiene, el ultimo del mes).
# Requiere aplicar-remedios-panel.ps1 (ya aplicado). Cambia SOLO src\\index.ts (respaldo .bak-remedios2). Va en la carpeta del PANEL (la que tiene wrangler.toml). Sin build. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
$indexTexto = (Leer (Join-Path $raiz "src\\index.ts")).texto
if ((Contar $indexTexto 'function medToca') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $indexTexto 'async function remediosCron') -eq 0) { Mal "Falta aplicar primero aplicar-remedios-panel.ps1. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-remedios2')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: los remedios de la misma hora van en un solo aviso, y se pueden cargar por dias de la semana o una vez al mes."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + tpl[i:j] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›✓']
assert not bad, set(bad)
open(R + 'aplicar-remedios2-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
t = open(S + 'index-menos.ts', encoding='utf-8').read()
assert t.count(OLD) == 1, t.count(OLD)
open(S + 'index-remedios2.ts', 'w', encoding='utf-8').write(t.replace(OLD, NEW))
print('ok', len(total))
