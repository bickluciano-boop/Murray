# Genera scripts/aplicar-aviso-historial-panel.ps1: un tilde por persona ("Avisarle cuando miro su recorrido") que decide el titular. Si esta tildado, cuando un adulto mira el recorrido de esa persona le llega un aviso sin sonido (como mucho una vez cada 6 horas por adulto).
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"

# --- servidor (src\index.ts) ---
FUNCIONES = '''// "Avisarle cuando miro su recorrido": un tilde por persona que decide el titular (family_members.id). Apagado por defecto: si esta tildado, cuando un adulto mira el recorrido
// de esa persona le llega un aviso sin sonido, como mucho una vez cada 6 horas por adulto (el mapa pide el historial cada vez que se elige a la persona).
let historialAvisoTablaLista = false;
async function historialAvisoTabla(env: Env) {
  if (historialAvisoTablaLista) return;
  await env.DB.prepare("CREATE TABLE IF NOT EXISTS family_history_notice (person_id TEXT PRIMARY KEY, notify INTEGER NOT NULL DEFAULT 0, updated_at INTEGER NOT NULL)").run();
  await env.DB.prepare("CREATE TABLE IF NOT EXISTS family_history_seen (person_id TEXT NOT NULL, viewer_email TEXT NOT NULL, last_at INTEGER NOT NULL, PRIMARY KEY (person_id, viewer_email))").run();
  historialAvisoTablaLista = true;
}

async function avisoHistorialActivo(env: Env, personId: string): Promise<boolean> {
  try {
    await historialAvisoTabla(env);
    const fila = await env.DB.prepare("SELECT notify FROM family_history_notice WHERE person_id=?").bind(personId).first<{ notify: number }>();
    return fila?.notify === 1;
  } catch {
    return false;
  }
}

/** Si el titular lo pidio, le avisa a la persona (sin sonido) que `viewer` miro su recorrido. Nunca frena el historial. */
async function avisarHistorialMirado(env: Env, viewer: string, personId: string, personEmail: string) {
  try {
    if (!(await avisoHistorialActivo(env, personId))) return;
    const ahora = Date.now();
    const previo = await env.DB.prepare("SELECT last_at AS t FROM family_history_seen WHERE person_id=? AND viewer_email=?").bind(personId, viewer).first<{ t: number }>();
    if (previo && ahora - previo.t < 6 * 3_600_000) return;
    await env.DB.prepare("INSERT INTO family_history_seen (person_id,viewer_email,last_at) VALUES (?,?,?) ON CONFLICT(person_id,viewer_email) DO UPDATE SET last_at=excluded.last_at").bind(personId, viewer, ahora).run();
    const quien = (await familyNameSeenBy(env, viewer, personEmail)) || viewer.split("@")[0];
    for (const token of await pushTokensOf(env, personEmail)) {
      await sendExpoNoticeLogged(env, token, "Ojo Guard", `${quien} mir\\u00f3 tu recorrido.`, "historial", { sinSonido: true, ttl: 3600 }).catch(() => false);
    }
  } catch (error) {
    console.error("history_notice_failed", error);
  }
}

// El titular prende o apaga ese aviso para una persona de su familia.
async function remoteFamilyHistoryNotice(request: Request, env: Env) {
  const sessionInfo = await readSessionInfo(request, env.SESSION_SECRET);
  if (!sessionInfo) return json({ error: "unauthorized" }, 401);
  if (sessionInfo.method === "emergency") return json({ error: "not_allowed_in_emergency" }, 403);
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const id = String(body.id ?? "");
  const propia = await env.DB.prepare("SELECT id FROM family_members WHERE id=? AND owner_email=? AND status='activo'").bind(id, sessionInfo.email).first();
  if (!propia) return json({ error: "not_found" }, 404);
  await historialAvisoTabla(env);
  const notify = body.notify === true ? 1 : 0;
  await env.DB.prepare("INSERT INTO family_history_notice (person_id,notify,updated_at) VALUES (?,?,?) ON CONFLICT(person_id) DO UPDATE SET notify=excluded.notify, updated_at=excluded.updated_at").bind(id, notify, Date.now()).run();
  return json({ saved: true, notify: notify === 1 });
}

'''
s1a = 'async function deviceLocationHistory(request: Request, env: Env, url: URL) {\n'
s1b = FUNCIONES + s1a
s2a = '  if (!miembro?.email) return json({ error: "not_found" }, 404);\n'
s2b = s2a + '  await avisarHistorialMirado(env, sessionInfo.email, personId, miembro.email);\n'
s3a = '      photo: await fotoVersion(env, p.email),\n    });\n'
s3b = '      photo: await fotoVersion(env, p.email),\n      // Solo para quien administra a esa persona (el titular): si le avisa cuando mira su recorrido.\n      notifyHistory: p.gestionable ? await avisoHistorialActivo(env, p.id) : undefined,\n    });\n'
s4a = '      if (route === "GET /api/remote/family") return remoteFamily(request, env);\n'
s4b = s4a + '      if (route === "POST /api/remote/family/history-notice") return remoteFamilyHistoryNotice(request, env);\n'

# --- mapa (src\panel-mapa.txt) ---
CSS = ('#og-mapa .ogm-aviso-hist{display:flex;gap:10px;align-items:flex-start;width:100%;text-align:left;padding:10px;margin:8px 0;border:1px solid var(--ogm-linea);border-radius:12px;background:transparent;color:var(--ogm-texto)}'
       '#og-mapa .ogm-aviso-hist i{flex:none;width:22px;height:22px;border:2px solid var(--ogm-oro-vivo);border-radius:6px;display:grid;place-items:center;font-style:normal;font-weight:700;color:var(--ogm-oro-vivo)}'
       '#og-mapa .ogm-aviso-hist.on i{background:var(--ogm-oro-fondo)}'
       '#og-mapa .ogm-aviso-hist strong{display:block;font-size:.9rem}'
       '#og-mapa .ogm-aviso-hist small{display:block;font-size:.76rem;color:var(--ogm-suave);margin-top:2px}')
m1a = '</style>\n      <div class="ogm-dia hidden" data-ogm="dia-barra">'
m1b = CSS + m1a
m2a = '      gestionable: Boolean(p.canManage),\n'
m2b = m2a + '      avisoHistorial: p.notifyHistory === true,\n'
m3a = 'rol: equipo.rol, rolActual: equipo.rol, confirmarQuitar: false, error: "" };'
m3b = 'rol: equipo.rol, rolActual: equipo.rol, avisoHistorial: Boolean(equipo.avisoHistorial), confirmarQuitar: false, error: "" };'
m4a = '      <div class="ogm-dlg-botones"><button type="button" class="oro" data-accion="gestion-guardar" ${d.rol === d.rolActual ? "disabled" : ""}>Guardar</button>'
m4b = ('      ${d.rol !== "amigo" ? `<button type="button" class="ogm-aviso-hist${d.avisoHistorial ? " on" : ""}" data-accion="gestion-aviso" aria-pressed="${d.avisoHistorial ? "true" : "false"}"><i>${d.avisoHistorial ? "✓" : ""}</i><span><strong>Avisarle cuando miro su recorrido</strong><small>Le llega un aviso sin sonido, como mucho una vez cada 6 horas. Si lo dejás apagado, no se entera.</small></span></button>` : ""}\n') + m4a
m5a = '    if (accion === "gestion-guardar") return guardarGestion(boton);\n'
m5b = m5a + '    if (accion === "gestion-aviso") return cambiarAvisoHistorial();\n'
m6a = 'async function quitarGestion(boton) {\n'
m6b = '''// El tilde "Avisarle cuando miro su recorrido": se guarda al tocarlo.
async function cambiarAvisoHistorial() {
  const d = estado.dialogo;
  if (!d || d.paso !== "gestion") return;
  const nuevo = !d.avisoHistorial;
  d.avisoHistorial = nuevo;
  d.error = "";
  dibujarDialogo();
  try {
    await pedir("/api/remote/family/history-notice", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ id: d.id, notify: nuevo }) });
    const persona = estado.equipos.find((e) => e.id === d.equipoId);
    if (persona) persona.avisoHistorial = nuevo;
  } catch (error) {
    d.avisoHistorial = !nuevo;
    d.error = errorGestion(error, "guardar este aviso");
    dibujarDialogo();
  }
}

''' + m6a
h1a = '<script type="module" src="/mapa-v1.js?v=10"></script>'
h1b = '<script type="module" src="/mapa-v1.js?v=11"></script>'

filas = [
    ('src\\index.ts', 'servidor: funciones del aviso de historial', s1a, s1b),
    ('src\\index.ts', 'servidor: avisar al mirar el recorrido', s2a, s2b),
    ('src\\index.ts', 'servidor: la lista de la familia trae el tilde', s3a, s3b),
    ('src\\index.ts', 'servidor: ruta del tilde', s4a, s4b),
    ('src\\panel-mapa.txt', 'mapa: estilo del tilde', m1a, m1b),
    ('src\\panel-mapa.txt', 'mapa: la persona trae el tilde', m2a, m2b),
    ('src\\panel-mapa.txt', 'mapa: el cuadro de administrar parte con el tilde', m3a, m3b),
    ('src\\panel-mapa.txt', 'mapa: el tilde en el cuadro de administrar', m4a, m4b),
    ('src\\panel-mapa.txt', 'mapa: tocar el tilde', m5a, m5b),
    ('src\\panel-mapa.txt', 'mapa: guardar el tilde', m6a, m6b),
    ('src\\panel-index.html', 'recargar el mapa nuevo (v=11)', h1a, h1b),
]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-aviso-historial-panel.ps1 - Ojo Guard MS: en "Administrar" a cada persona de la familia, un tilde "Avisarle cuando miro su recorrido". Lo decide el titular; apagado por defecto.
# Idea de Luciano (31/10/2026): "es una opcion en configuraciones, un tilde que se marca si queres que reciba notificaciones o no. Y lo decide el adulto".
# Si esta tildado, cuando un adulto mira el recorrido de esa persona le llega un aviso sin sonido ("<Nombre> miro tu recorrido."), como mucho una vez cada 6 horas por adulto.
# Cambia src\\index.ts (dos tablas nuevas que se crean solas, una ruta y el aviso), src\\panel-mapa.txt y src\\panel-index.html (v=11). Respaldo .bak-avisohist. Va en la carpeta del PANEL. Sin build. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
foreach ($f in @("src\\index.ts", "src\\panel-mapa.txt", "src\\panel-index.html")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'family_history_notice') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'familyLocationHistory') -lt 1) { Mal "Falta aplicar primero aplicar-historial-familia-panel.ps1. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-index.html")).texto '/mapa-v1.js?v=10') -ne 1) { Mal "El mapa no esta en v=10 (falta aplicar primero aplicar-historial-familia-panel.ps1). No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-avisohist')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: en Administrar a cada persona hay un tilde para avisarle cuando miras su recorrido. Cerra y abri la app (o recarga la pagina del mapa)."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›✓']
assert not bad, set(bad)
open(R + 'aplicar-aviso-historial-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
