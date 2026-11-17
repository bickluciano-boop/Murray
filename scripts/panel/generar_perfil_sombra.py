# Genera scripts/aplicar-perfil-sombra-panel.ps1 (servidor): MOTOR DE PERFIL EN MODO SOMBRA.
# Luciano (17/11/2026): "los datos los tenemos en el recorrido de cada uno por fecha. Si la frecuencia es diaria, no mandar alerta; si es un recorrido habitual (2 veces por semana a un horario),
# se detecta como ocupado; es como Waze, que sabe segun la hora a donde vas a ir: las probabilidades que hace el sistema" ... "si, modo sombra, como motor de busqueda interno".
# Que hace:
#  1) Cada 15 minutos, un telefono por vez (el que lleva mas de 20 h sin recalcular) se revisa su historial de las ultimas 8 semanas (location_history) y se arma su PERFIL:
#     lugares donde se queda 30+ min (estadias), cuantos dias distintos fue, que dias de la semana y a que horas (matriz dia x hora), clase: diario / habitual / ocasional / nuevo,
#     y los huecos de senal habituales (dia de la semana x franja de 4 h). Tabla perfil_persona.
#  2) Motor de consulta: "donde suele estar un martes a las 15?" -> lugares probables con su probabilidad (como Waze). GET /api/remote/perfil (solo con la sesion del panel, solo telefonos propios).
#  3) MODO SOMBRA: cuando el aviso de sin senal evalua (6 h despierto), ademas anota en perfil_sombra que habria decidido el perfil ("espera" o "avisa" y por que) junto con lo que hizo la regla real.
#     NO cambia ningun aviso. Despues de ~2 semanas se comparan las dos columnas.
# Requiere cuidado-lugares (usa cuidadoLugarConocido). No se muestra a nadie fuera de la sesion del propio titular del panel.
import re
R = '/home/user/Murray/scripts/'
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/priv/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
IDX = 'src\\index.ts'
filas = []
def fila(nombre, viejo, nuevo):
    filas.append((IDX, nombre, viejo, nuevo))

MOTOR = r'''// ---------------------------------------------------------------------------
// PERFIL de cada persona a partir de su recorrido (location_history), en MODO SOMBRA: aprende y anota, pero NO cambia ningun aviso.
//  - perfil_persona: lugares (estadias de 30+ min, agrupados a 150 m) con dias distintos, dia de la semana x hora y clase (diario / habitual / ocasional / nuevo); huecos de senal habituales.
//  - perfil_sombra: por cada silencio evaluado, que hizo la regla real y que habria decidido el perfil.
//  - GET /api/remote/perfil: consulta "donde suele estar a tal dia/hora" solo para el titular del panel y sus propios telefonos.
// ---------------------------------------------------------------------------
type PerfilPunto = { latitude: number; longitude: number; acc: number; t: number; dir: string | null };
type PerfilLugar = { latitude: number; longitude: number; direccion: string | null; dias: number; visitas: number; minutos: number; primera: string; ultima: string; clase: string; presencia: number[] };
type PerfilDatos = { semanas: number; diasConDatos: number; fiable: boolean; diasPorDow: number[]; lugares: PerfilLugar[]; huecos: Record<string, number> };
let perfilTablaLista = false;
async function perfilTabla(env: Env) {
  if (perfilTablaLista) return;
  await env.DB.prepare("CREATE TABLE IF NOT EXISTS perfil_persona (device_id TEXT PRIMARY KEY, email TEXT NOT NULL, actualizado_at TEXT NOT NULL, datos TEXT NOT NULL)").run();
  await env.DB.prepare("CREATE TABLE IF NOT EXISTS perfil_sombra (device_id TEXT NOT NULL, visto_at TEXT NOT NULL, evaluado_at TEXT NOT NULL, real TEXT NOT NULL, sombra TEXT NOT NULL, motivo TEXT NOT NULL, PRIMARY KEY (device_id, visto_at))").run();
  perfilTablaLista = true;
}
function perfilLocal(t: number, tzMin: number) {
  const d = new Date(t + tzMin * 60_000);
  return { fecha: d.toISOString().slice(0, 10), dow: d.getUTCDay(), hora: d.getUTCHours() };
}
/** Arma el perfil a partir de los puntos del recorrido (ordenados o no). tzMin = zona horaria de la persona. */
function perfilCalcular(puntos: PerfilPunto[], tzMin: number, ahoraMs: number): PerfilDatos {
  const pts = puntos.filter((p) => Number.isFinite(p.latitude) && Number.isFinite(p.longitude) && !(p.acc > 150)).sort((a, b) => a.t - b.t);
  const fechas = new Set<string>();
  const porDow: Array<Set<string>> = [0, 1, 2, 3, 4, 5, 6].map(() => new Set<string>());
  for (const p of pts) {
    const l = perfilLocal(p.t, tzMin);
    fechas.add(l.fecha);
    porDow[l.dow]?.add(l.fecha);
  }
  const primeraT = pts[0]?.t ?? ahoraMs;
  const semanas = Math.max(0.1, Math.min(8, (ahoraMs - primeraT) / (7 * 86_400_000)));
  // 1) Estadias: puntos seguidos a menos de 120 m del primero, sin huecos de mas de 4 h, que duran 30+ min.
  const estadias: Array<{ ini: number; fin: number; latitude: number; longitude: number; dir: string | null }> = [];
  let i = 0;
  while (i < pts.length) {
    const ancla = pts[i] as PerfilPunto;
    let j = i;
    while (j + 1 < pts.length && (pts[j + 1] as PerfilPunto).t - (pts[j] as PerfilPunto).t <= 4 * 3_600_000 && metersBetween(ancla, pts[j + 1] as PerfilPunto) <= 120) j++;
    const ultimo = pts[j] as PerfilPunto;
    if (ultimo.t - ancla.t >= 30 * 60_000) {
      let la = 0, lo = 0, dir: string | null = null;
      for (let k = i; k <= j; k++) { la += (pts[k] as PerfilPunto).latitude; lo += (pts[k] as PerfilPunto).longitude; dir = (pts[k] as PerfilPunto).dir ?? dir; }
      estadias.push({ ini: ancla.t, fin: ultimo.t, latitude: la / (j - i + 1), longitude: lo / (j - i + 1), dir });
      i = j + 1;
    } else i++;
  }
  // 2) Lugares: las estadias a menos de 150 m se juntan en un mismo lugar.
  type Acum = { latitude: number; longitude: number; n: number; direccion: string | null; fechas: Set<string>; visitas: number; minutos: number; primera: number; ultima: number; celdas: Array<Set<string>> };
  const acums: Acum[] = [];
  for (const e of estadias) {
    let a = acums.find((x) => metersBetween(x, e) <= 150);
    if (!a) { a = { latitude: e.latitude, longitude: e.longitude, n: 0, direccion: null, fechas: new Set(), visitas: 0, minutos: 0, primera: e.ini, ultima: e.fin, celdas: Array.from({ length: 168 }, () => new Set<string>()) }; acums.push(a); }
    a.latitude = (a.latitude * a.n + e.latitude) / (a.n + 1); a.longitude = (a.longitude * a.n + e.longitude) / (a.n + 1); a.n++;
    a.direccion = e.dir ?? a.direccion; a.visitas++; a.minutos += Math.round((e.fin - e.ini) / 60_000);
    a.primera = Math.min(a.primera, e.ini); a.ultima = Math.max(a.ultima, e.fin);
    for (let t = e.ini; t <= e.fin; t += 30 * 60_000) {
      const l = perfilLocal(t, tzMin);
      a.fechas.add(l.fecha);
      a.celdas[l.dow * 24 + l.hora]?.add(l.fecha);
    }
  }
  const diasConDatos = fechas.size;
  const lugares: PerfilLugar[] = acums.map((a) => {
    const dias = a.fechas.size;
    const clase = dias >= 5 && dias / Math.max(1, diasConDatos) >= 0.7 ? "diario" : dias >= Math.max(4, 1.5 * semanas) ? "habitual" : dias >= 2 ? "ocasional" : "nuevo";
    return { latitude: Math.round(a.latitude * 1e5) / 1e5, longitude: Math.round(a.longitude * 1e5) / 1e5, direccion: a.direccion ? a.direccion.slice(0, 120) : null, dias, visitas: a.visitas, minutos: a.minutos,
      primera: new Date(a.primera).toISOString().slice(0, 10), ultima: new Date(a.ultima).toISOString().slice(0, 10), clase, presencia: a.celdas.map((c) => c.size) };
  }).sort((x, y) => y.dias - x.dias).slice(0, 25);
  // 3) Huecos de senal habituales: puntos separados por mas de 2 h (y menos de 12 h), por dia de la semana x franja de 4 h del inicio; cuenta fechas distintas.
  const huecosSet: Record<string, Set<string>> = {};
  for (let k = 1; k < pts.length; k++) {
    const a = pts[k - 1] as PerfilPunto, b = pts[k] as PerfilPunto;
    const dt = b.t - a.t;
    if (dt > 2 * 3_600_000 && dt < 12 * 3_600_000) {
      const l = perfilLocal(a.t, tzMin);
      const clave = `${l.dow}-${Math.floor(l.hora / 4)}`;
      (huecosSet[clave] ??= new Set<string>()).add(l.fecha);
    }
  }
  const huecos: Record<string, number> = {};
  for (const [k, v] of Object.entries(huecosSet)) huecos[k] = v.size;
  return { semanas: Math.round(semanas * 10) / 10, diasConDatos, fiable: semanas >= 2 && diasConDatos >= 10, diasPorDow: porDow.map((s) => s.size), lugares, huecos };
}
/** Motor de consulta (como Waze): donde suele estar la persona un dia de la semana (0=domingo) y una hora, con su probabilidad. */
function perfilConsultar(datos: PerfilDatos, dow: number, hora: number) {
  const base = Math.max(1, datos.diasPorDow[dow] ?? 1);
  return datos.lugares
    .map((l) => ({ direccion: l.direccion, clase: l.clase, latitude: l.latitude, longitude: l.longitude, probabilidad: Math.round(((l.presencia[dow * 24 + hora] ?? 0) / base) * 100) / 100 }))
    .filter((x) => x.probabilidad >= 0.1)
    .sort((a, b) => b.probabilidad - a.probabilidad)
    .slice(0, 3);
}
/** MODO SOMBRA: que decidiria el perfil ante un silencio. espera = no alarmar; avisa = avisar. No cambia ningun aviso. */
function perfilDecidir(datos: PerfilDatos | null, ultima: { latitude: number; longitude: number } | null, visto: number, tzMin: number, calladoMin: number, real: string) {
  if (calladoMin >= 24 * 60) return { sombra: "avisa", motivo: "tope_24h" };
  if (!datos || !datos.fiable) return { sombra: real, motivo: "sin_perfil_fiable" };
  const l = perfilLocal(visto, tzMin);
  if ((datos.huecos[`${l.dow}-${Math.floor(l.hora / 4)}`] ?? 0) >= 3) return { sombra: "espera", motivo: "hueco_habitual" };
  const lugar = ultima ? datos.lugares.find((x) => metersBetween(ultima, x) <= 150) : undefined;
  if (!lugar) return { sombra: "avisa", motivo: "lugar_desconocido" };
  if (lugar.clase === "diario") return { sombra: "espera", motivo: "lugar_diario" };
  if (lugar.clase === "habitual") {
    const prob = (lugar.presencia[l.dow * 24 + l.hora] ?? 0) / Math.max(1, datos.diasPorDow[l.dow] ?? 1);
    return prob >= 0.4 ? { sombra: "espera", motivo: "habitual_en_su_franja" } : { sombra: "avisa", motivo: "habitual_fuera_de_horario" };
  }
  return { sombra: "avisa", motivo: lugar.clase === "nuevo" ? "lugar_nuevo" : "lugar_ocasional" };
}
async function perfilSombra(env: Env, eq: { id: string; email: string }, visto: number, ahoraMs: number, tzMin: number, calladoMin: number, avisariaLaRegla: boolean) {
  await perfilTabla(env);
  const fila = await env.DB.prepare("SELECT datos FROM perfil_persona WHERE device_id=?").bind(eq.id).first<{ datos: string }>();
  let datos: PerfilDatos | null = null;
  try { datos = fila ? (JSON.parse(fila.datos) as PerfilDatos) : null; } catch { datos = null; }
  const ult = await env.DB.prepare("SELECT latitude, longitude FROM location_history WHERE device_id=? ORDER BY captured_at DESC LIMIT 1").bind(eq.id).first<{ latitude: number; longitude: number }>();
  const real = avisariaLaRegla ? "avisa" : "espera";
  const d = perfilDecidir(datos, ult ? { latitude: Number(ult.latitude), longitude: Number(ult.longitude) } : null, visto, tzMin, calladoMin, real);
  await env.DB.prepare("INSERT INTO perfil_sombra (device_id, visto_at, evaluado_at, real, sombra, motivo) VALUES (?,?,?,?,?,?) ON CONFLICT(device_id, visto_at) DO UPDATE SET evaluado_at=excluded.evaluado_at, real=excluded.real, sombra=excluded.sombra, motivo=excluded.motivo")
    .bind(eq.id, new Date(visto).toISOString(), new Date(ahoraMs).toISOString(), real, d.sombra, d.motivo).run();
}
/** Cada 15 minutos recalcula el perfil de UN telefono (el que lleva mas de 20 h sin recalcular y tiene recorrido reciente). */
async function perfilCron(env: Env, ahoraMs = Date.now()) {
  if (new Date(ahoraMs).getUTCMinutes() % 15 !== 7) return;
  await perfilTabla(env);
  const hace20h = new Date(ahoraMs - 20 * 3_600_000).toISOString();
  const hace8sem = new Date(ahoraMs - 56 * 86_400_000).toISOString();
  const tel = await env.DB.prepare("SELECT d.id AS id, d.owner_email AS email FROM devices d WHERE d.approval_status='approved' AND d.id NOT IN (SELECT device_id FROM perfil_persona WHERE actualizado_at>?) AND EXISTS (SELECT 1 FROM location_history h WHERE h.device_id=d.id AND h.captured_at>?) LIMIT 1")
    .bind(hace20h, hace8sem).first<{ id: string; email: string }>();
  if (!tel) return;
  const r = await env.DB.prepare("SELECT latitude, longitude, accuracy, address, captured_at AS at FROM location_history WHERE device_id=? AND captured_at>=? ORDER BY captured_at ASC LIMIT 7000")
    .bind(tel.id, hace8sem).all<{ latitude: number; longitude: number; accuracy: number | null; address: string | null; at: string }>();
  const prefs = await cuidadoPrefs(env, tel.email);
  const puntos: PerfilPunto[] = r.results.map((p) => ({ latitude: Number(p.latitude), longitude: Number(p.longitude), acc: p.accuracy === null ? 0 : Number(p.accuracy), t: Date.parse(p.at), dir: p.address })).filter((p) => Number.isFinite(p.t));
  const datos = perfilCalcular(puntos, prefs.tz, ahoraMs);
  await env.DB.prepare("INSERT OR REPLACE INTO perfil_persona (device_id, email, actualizado_at, datos) VALUES (?,?,?,?)").bind(tel.id, tel.email, new Date(ahoraMs).toISOString(), JSON.stringify(datos)).run();
}
/** GET /api/remote/perfil[?deviceId=&dow=&hora=]: sin deviceId lista los telefonos propios con su perfil; con deviceId devuelve el perfil y, si se pide dow (0=domingo) y hora, donde suele estar. Solo el titular del panel. */
async function remotePerfil(request: Request, env: Env, url: URL) {
  const sessionInfo = await readSessionInfo(request, env.SESSION_SECRET);
  if (!sessionInfo) return json({ error: "unauthorized" }, 401);
  if (sessionInfo.method === "emergency") return json({ error: "not_allowed_in_emergency" }, 403);
  await perfilTabla(env);
  const deviceId = url.searchParams.get("deviceId") ?? "";
  if (!deviceId) {
    const lista = await env.DB.prepare("SELECT d.id AS id, d.name AS name, p.actualizado_at AS actualizado, p.datos AS datos FROM devices d LEFT JOIN perfil_persona p ON p.device_id=d.id WHERE d.owner_email=? AND d.approval_status='approved'")
      .bind(sessionInfo.email).all<{ id: string; name: string; actualizado: string | null; datos: string | null }>();
    return json({ telefonos: lista.results.map((x) => { let d: PerfilDatos | null = null; try { d = x.datos ? (JSON.parse(x.datos) as PerfilDatos) : null; } catch { d = null; } return { id: x.id, nombre: x.name, actualizado: x.actualizado, fiable: d?.fiable ?? false, semanas: d?.semanas ?? 0, lugares: d?.lugares.length ?? 0 }; }) });
  }
  const mio = await env.DB.prepare("SELECT id FROM devices WHERE id=? AND owner_email=?").bind(deviceId, sessionInfo.email).first<{ id: string }>();
  if (!mio) return json({ error: "not_found" }, 404);
  const fila = await env.DB.prepare("SELECT actualizado_at AS actualizado, datos FROM perfil_persona WHERE device_id=?").bind(deviceId).first<{ actualizado: string; datos: string }>();
  if (!fila) return json({ error: "sin_perfil" }, 404);
  const datos = JSON.parse(fila.datos) as PerfilDatos;
  const dow = Number(url.searchParams.get("dow")), hora = Number(url.searchParams.get("hora"));
  const consulta = url.searchParams.has("dow") && url.searchParams.has("hora") && Number.isInteger(dow) && dow >= 0 && dow <= 6 && Number.isInteger(hora) && hora >= 0 && hora <= 23 ? perfilConsultar(datos, dow, hora) : undefined;
  const sombra = await env.DB.prepare("SELECT visto_at AS vistoAt, evaluado_at AS evaluadoAt, real, sombra, motivo FROM perfil_sombra WHERE device_id=? ORDER BY visto_at DESC LIMIT 30").bind(deviceId).all();
  return json({ actualizado: fila.actualizado, fiable: datos.fiable, semanas: datos.semanas, diasConDatos: datos.diasConDatos, lugares: datos.lugares.map((l) => ({ direccion: l.direccion, clase: l.clase, dias: l.dias, visitas: l.visitas, minutos: l.minutos, primera: l.primera, ultima: l.ultima })), huecos: datos.huecos, consulta, sombra: sombra.results });
}

'''
C_A = '/** Minutos de silencio contando solo las horas despierto (de 7 a 23, hora de la persona): de 23 a 7 el reloj se pausa. */\n'
fila('perfil: motor del perfil, consulta y modo sombra', C_A, MOTOR + C_A)

H_A = '            const lugar = await cuidadoLugarConocido(env, eq.id, eq.email);\n'
H_B = H_A + '            // MODO SOMBRA: anota que habria decidido el perfil aprendido (no cambia el aviso).\n            await perfilSombra(env, eq, visto, ahoraMs, prefs.tz, calladoMin, !lugar.conocido || despiertoMin >= CUIDADO_SIN_SENAL_CONOCIDO_MIN).catch(() => undefined);\n'
fila('perfil: el aviso de sin senal anota la decision en modo sombra', H_A, H_B)

K_A = '      ctx.waitUntil(cuidadoCron(env).catch((error) => console.error("cuidado_cron_failed", error)));\n'
fila('perfil: cada 15 minutos recalcula el perfil de un telefono', K_A, K_A + '      ctx.waitUntil(perfilCron(env).catch((error) => console.error("perfil_cron_failed", error)));\n')

R_A = '      if (route === "POST /api/remote/family/remove") return remoteFamilyRemove(request, env);\n'
fila('perfil: ruta de consulta del perfil (solo titular del panel)', R_A, R_A + '      if (route === "GET /api/remote/perfil") return remotePerfil(request, env, url);\n')

def cambios_ps(fs):
    return "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in fs) + "\n)\n"
i0 = tpl.index('$ErrorActionPreference'); j0 = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-perfil')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
MENSAJE = 'LISTO: el motor de perfil esta en modo sombra (aprende y anota; no cambia ningun aviso).'
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "%s"\n' % MENSAJE, cola)
assert MENSAJE in cola
cabeza = '''# aplicar-perfil-sombra-panel.ps1 - Ojo Guard MS (servidor): MOTOR DE PERFIL EN MODO SOMBRA. Aprende de cada recorrido (lugares diarios / habituales / ocasionales / nuevos, dia x hora, huecos de senal habituales)
# y anota en una tabla aparte que habria decidido ante un "sin senal", sin cambiar ningun aviso. Incluye la consulta "donde suele estar a tal dia y hora" (como Waze), solo para el titular del panel.
# Luciano (17/11/2026): "modo sombra, como motor de busqueda interno". Requiere aplicar-cuidado-lugares-panel.ps1. Cambia src\\index.ts (respaldo .bak-perfil). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
'''
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'async function perfilCron') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'cuidadoLugarConocido') -eq 0) { Mal "Falta aplicar primero aplicar-cuidado-lugares-panel.ps1."; return }
'''
total = cabeza + tpl[i0:j0] + guardas + cambios_ps(filas) + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕‹›']
assert not bad, set(bad)
open(R + 'aplicar-perfil-sombra-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
# replica: base = cuidado-lugares.ts + un router y un cron simulados para comprobar que las anclas existen una sola vez
t = open(S + 'cuidado-lugares.ts', encoding='utf-8').read()
for a, n, v, nv in filas[:2]:
    assert t.count(v) == 1, (n, t.count(v))
for a, n, v, nv in filas[:2]:
    t = t.replace(v, nv)
open(S + 'cuidado-perfil.ts', 'w', encoding='utf-8').write(t)
open(S + 'perfil-motor.ts', 'w', encoding='utf-8').write(MOTOR)
print('ok', len(total), len(filas), 'filas')
