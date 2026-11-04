# Genera scripts/aplicar-permisos-ojo-panel.ps1: permisos entre dos personas de la familia (Familia y amigos > Permisos, el ojo).
import re
R = '/home/user/Murray/scripts/'
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"

# ---- 1) bloque nuevo: tabla, lectura de permisos, corte de ubicacion y endpoint ----
BLOQUE = r'''// ---------------------------------------------------------------------------
// Permisos entre dos personas de la familia (Familia y amigos > Permisos, "el ojo"). Cada una decide por su lado y alcanza con que UNA
// corte. Fila (de, a), todo prendido si no hay fila:
//   loc_share: `de` comparte su ubicacion con `a`      loc_view: `de` mira la ubicacion de `a`
//   sos_send:  el SOS de `de` le suena a `a`           sos_recv: `de` recibe el SOS de `a`
// Una cosa se ve/suena si los dos lados estan prendidos. REGLA (Luciano, 04/11/2026): siempre queda al menos UNA persona que reciba el SOS de
// cada uno; los referentes de "Por las dudas" (solo mail) no cuentan, porque pueden no verlo a tiempo. Con un menor no se puede cortar nada.
//   CREATE TABLE IF NOT EXISTS family_perms (from_email TEXT NOT NULL, to_email TEXT NOT NULL, loc_share INTEGER NOT NULL DEFAULT 1,
//     loc_view INTEGER NOT NULL DEFAULT 1, sos_send INTEGER NOT NULL DEFAULT 1, sos_recv INTEGER NOT NULL DEFAULT 1,
//     updated_at TEXT NOT NULL, PRIMARY KEY (from_email, to_email));
// ---------------------------------------------------------------------------
type PermFila = { loc_share: number; loc_view: number; sos_send: number; sos_recv: number };
const PERM_TODO: PermFila = { loc_share: 1, loc_view: 1, sos_send: 1, sos_recv: 1 };
let permTablaLista = false;
async function permTabla(env: Env) {
  if (permTablaLista) return;
  await env.DB.prepare("CREATE TABLE IF NOT EXISTS family_perms (from_email TEXT NOT NULL, to_email TEXT NOT NULL, loc_share INTEGER NOT NULL DEFAULT 1, loc_view INTEGER NOT NULL DEFAULT 1, sos_send INTEGER NOT NULL DEFAULT 1, sos_recv INTEGER NOT NULL DEFAULT 1, updated_at TEXT NOT NULL, PRIMARY KEY (from_email, to_email))").run();
  permTablaLista = true;
}
/** Las filas donde `email` es una de las dos puntas, por clave "de|a". */
async function permsDe(env: Env, email: string) {
  await permTabla(env);
  const filas = await env.DB.prepare("SELECT from_email AS de, to_email AS a, loc_share, loc_view, sos_send, sos_recv FROM family_perms WHERE from_email=? OR to_email=?")
    .bind(email, email).all<PermFila & { de: string; a: string }>();
  const mapa = new Map<string, PermFila>();
  for (const f of filas.results) mapa.set(`${f.de}|${f.a}`, f);
  return mapa;
}
const permDe = (mapa: Map<string, PermFila>, de: string, a: string): PermFila => mapa.get(`${de}|${a}`) ?? PERM_TODO;
/** true si `quienMira` NO puede ver la ubicacion de `persona` porque alguno de los dos lo corto. */
async function permCorte(env: Env, persona: string, quienMira: string) {
  try {
    const mapa = await permsDe(env, quienMira);
    return !(permDe(mapa, persona, quienMira).loc_share && permDe(mapa, quienMira, persona).loc_view);
  } catch (error) {
    console.error("perms_corte", String(error).slice(0, 120));
    return false;
  }
}

/** POST /api/native/family/perm {deviceId, personId, key, on}: prende o apaga UNA llave de esta persona con otra. */
async function nativeFamilyPerm(request: Request, env: Env) {
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const email = await nativeOwnerEmail(request, env, String(body.deviceId ?? ""));
  if (!email) return json({ error: "unauthorized" }, 401);
  const COLUMNAS: Record<string, "loc_share" | "loc_view" | "sos_send" | "sos_recv"> = { teVe: "loc_share", recibeTuSos: "sos_send", loVes: "loc_view", recibisSuSos: "sos_recv" };
  const col = COLUMNAS[String(body.key ?? "")];
  if (!col || typeof body.on !== "boolean") return json({ error: "invalid_request" }, 400);
  const prender = body.on;
  const personId = String(body.personId ?? "");
  const persona = (await familyPeopleFor(env, email)).find((p) => p.id === personId);
  const otro = persona ? await familyPersonEmail(env, personId) : null;
  if (!persona || !otro || otro === email) return json({ error: "not_found" }, 404);
  // Con un menor (o siendo menor) no se corta nada: su ubicacion y su SOS son justamente lo que cuida la familia.
  const soyMenor = await env.DB.prepare("SELECT 1 AS m FROM family_members WHERE member_email=? AND status='activo' AND role='menor' LIMIT 1").bind(email).first<{ m: number }>();
  if (soyMenor || persona.role === "menor") return json({ error: "minor_locked" }, 403);
  const mapa = await permsDe(env, email);
  const mia: PermFila = { ...permDe(mapa, email, otro) };
  if (Boolean(mia[col]) === prender) return json({ ok: true, unchanged: true });
  // Siempre queda al menos una persona que reciba el SOS: no se puede apagar al ULTIMO.
  if (!prender && (col === "sos_send" || col === "sos_recv")) {
    const emisor = col === "sos_send" ? email : otro;
    const receptor = col === "sos_send" ? otro : email;
    const actuales = await familySosRecipients(env, emisor);
    if (actuales.length === 1 && actuales[0] === receptor) return json({ error: emisor === email ? "last_recipient_me" : "last_recipient_other" }, 409);
  }
  mia[col] = prender ? 1 : 0;
  await env.DB.prepare("INSERT INTO family_perms (from_email,to_email,loc_share,loc_view,sos_send,sos_recv,updated_at) VALUES (?,?,?,?,?,?,?) ON CONFLICT(from_email,to_email) DO UPDATE SET loc_share=excluded.loc_share, loc_view=excluded.loc_view, sos_send=excluded.sos_send, sos_recv=excluded.sos_recv, updated_at=excluded.updated_at")
    .bind(email, otro, mia.loc_share, mia.loc_view, mia.sos_send, mia.sos_recv, now()).run();
  // Aviso a la otra persona (nunca falla el cambio por esto).
  try {
    const yo = await familyNameSeenBy(env, email, otro);
    const textos: Record<string, [string, string]> = {
      loc_share: [`${yo} dejó de compartirte su ubicación.`, `${yo} volvió a compartirte su ubicación.`],
      loc_view: [`${yo} dejó de ver tu ubicación.`, `${yo} volvió a ver tu ubicación.`],
      sos_send: [`${yo} te sacó de su SOS.`, `${yo} te sumó a su SOS.`],
      sos_recv: [`${yo} dejó de recibir tu SOS.`, `${yo} volvió a recibir tu SOS.`],
    };
    let texto = (textos[col] as [string, string])[prender ? 1 : 0];
    if (col === "sos_recv") {
      const quedan = await familySosRecipients(env, otro);
      const nombres = await Promise.all(quedan.map((q) => familyNameSeenBy(env, q, otro)));
      texto += nombres.length ? ` Hoy tu SOS le llega a: ${nombres.join(", ")}.` : " Hoy tu SOS no le llega a nadie.";
    }
    for (const token of await pushTokensOf(env, otro)) await sendExpoNoticeLogged(env, token, "Ojo Guard", texto, "permiso", { channelId: "ojo-familia-aviso" }).catch(() => false);
  } catch (error) {
    console.error("perm_aviso", String(error).slice(0, 120));
  }
  return json({ ok: true });
}

'''

A0 = 'async function nativeFamilyPause(request: Request, env: Env) {\n'
B0 = BLOQUE + A0

# ---- 2) familyPeopleFor: lee los permisos, corta la ubicacion y manda los permisos de cada persona ----
A2 = '  const destinoSos = new Set(await familySosRecipients(env, viewer).catch(() => [] as string[]));\n'
B2 = A2 + '  const perms = await permsDe(env, viewer).catch(() => new Map<string, PermFila>());\n'
A3 = '    const paused = Boolean(p.pausedUntil && Date.parse(p.pausedUntil) > ahora);\n'
B3 = A3 + r'''    // Permisos con esta persona: cada llave vale si los DOS lados estan prendidos (`mine` es el mio, `theirs` el de ella).
    const mia = permDe(perms, viewer, p.email), suya = permDe(perms, p.email, viewer);
    const corte = !(suya.loc_share && mia.loc_view);
    const par = (m: number, s: number) => ({ on: Boolean(m && s), mine: Boolean(m), theirs: Boolean(s), ultimo: false });
    const permisos = {
      locked: p.role === "menor" || rows.results.some((r) => r.memberEmail === viewer && r.role === "menor"),
      teVe: par(mia.loc_share, suya.loc_view),
      recibeTuSos: par(mia.sos_send, suya.sos_recv),
      loVes: par(mia.loc_view, suya.loc_share),
      recibisSuSos: par(mia.sos_recv, suya.sos_send),
    };
    // "El ultimo": si apago esto, a alguien se le queda el SOS sin nadie que lo reciba (se avisa en la pantalla en vez de dejar apagarlo).
    permisos.recibeTuSos.ultimo = permisos.recibeTuSos.on && destinoSos.size === 1 && destinoSos.has(p.email);
    if (permisos.recibisSuSos.on && personas.size <= 12) {
      const susDestinos = await familySosRecipients(env, p.email).catch(() => [] as string[]);
      permisos.recibisSuSos.ultimo = susDestinos.length === 1 && susDestinos[0] === viewer;
    }
'''
A4 = '      lastLocation: !paused && device?.lastLocationJson ? JSON.parse(device.lastLocationJson) : null,\n      lastLocationAt: !paused ? device?.lastLocationAt ?? null : null,\n'
B4 = '      lastLocation: !paused && !corte && device?.lastLocationJson ? JSON.parse(device.lastLocationJson) : null,\n      lastLocationAt: !paused && !corte ? device?.lastLocationAt ?? null : null,\n'
A5 = '      sosTo: destinoSos.has(p.email),\n'
B5 = A5 + '      locCut: corte,\n      permisos,\n'

# ---- 3) el SOS: no le suena a quien se saco ni a quien apago "Recibo su SOS" ----
A6 = '  destinatarios.delete(person);\n  return [...destinatarios];\n'
B6 = ('  destinatarios.delete(person);\n'
      '  // Permisos: no le suena a quien la persona saco de su SOS ni a quien apago "Recibo su SOS".\n'
      '  try {\n'
      '    const mapa = await permsDe(env, person);\n'
      '    for (const b of [...destinatarios]) {\n'
      '      if (!permDe(mapa, person, b).sos_send || !permDe(mapa, b, person).sos_recv) destinatarios.delete(b);\n'
      '    }\n'
      '  } catch (error) {\n'
      '    console.error("perms_sos", String(error).slice(0, 120));\n'
      '  }\n'
      '  return [...destinatarios];\n')

# ---- 4) ordenes de ubicar / seguir en vivo: con la ubicacion cortada cuentan como pausada ----
A7 = '    pausada: Boolean(fila.pausedUntil && Date.parse(fila.pausedUntil) > Date.now()),\n'
B7 = '    pausada: Boolean(fila.pausedUntil && Date.parse(fila.pausedUntil) > Date.now()) || await permCorte(env, fila.memberEmail, viewer),\n'

# ---- 5) avisos de llegada/salida de un lugar: no salen si la ubicacion esta cortada ----
A8 = '    const sigueVisible = (await familyPeopleFor(env, aviso.watcherEmail)).some((p) => p.id === aviso.personId);\n    if (!sigueVisible) { await env.DB.prepare("DELETE FROM family_alerts WHERE id=?").bind(aviso.id).run(); continue; }\n'
B8 = ('    const personaDelAviso = (await familyPeopleFor(env, aviso.watcherEmail)).find((p) => p.id === aviso.personId);\n'
      '    if (!personaDelAviso) { await env.DB.prepare("DELETE FROM family_alerts WHERE id=?").bind(aviso.id).run(); continue; }\n'
      '    if (personaDelAviso.locCut) continue;\n')

# ---- 6) ruta y borrado de cuenta ----
A9 = '      if (route === "POST /api/native/family/pause") return nativeFamilyPause(request, env);\n'
B9 = A9 + '      if (route === "POST /api/native/family/perm") return nativeFamilyPerm(request, env);\n'
A10 = '  await borrar("family_members", "DELETE FROM family_members WHERE owner_email=? OR member_email=?", 2);\n'
B10 = '  await borrar("family_perms", "DELETE FROM family_perms WHERE from_email=? OR to_email=?", 2);\n' + A10

pares = [A0, A2, A3, A4, A5, A6, A7, A8, A9, A10]
nombres = ['permisos: tabla, lectura, corte y endpoint', 'permisos: leer los permisos de quien mira', 'permisos: llaves de cada persona', 'permisos: ubicacion cortada no se manda',
           'permisos: locCut y permisos en la lista', 'permisos: el SOS respeta las llaves', 'permisos: ubicar/en vivo con la ubicacion cortada',
           'permisos: avisos de lugar con la ubicacion cortada', 'permisos: ruta', 'permisos: borrar cuenta']
nuevos = [B0, B2, B3, B4, B5, B6, B7, B8, B9, B10]
filas = [('src\\index.ts', n, a, b) for n, a, b in zip(nombres, pares, nuevos)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-permisos-ojo-panel.ps1 - Ojo Guard MS: permisos entre dos personas de la familia (Familia y amigos > Permisos, "el ojo").
# Luciano (04/11/2026): que cada uno pueda cortar por su lado (ubicacion y SOS) y que la otra persona reciba el aviso; y que SIEMPRE quede al menos una persona que reciba el SOS (los referentes por mail no cuentan).
# Tabla nueva family_perms (se crea sola). La lista de familia trae locCut y permisos por persona; el SOS, las ordenes de ubicar y los avisos de lugar respetan las llaves. Con un menor no se puede cortar nada.
# Requiere haber aplicado antes aplicar-familia-sos-nombres-panel.ps1. Cambia SOLO src\\index.ts (respaldo .bak-permisos). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'const destinoSos') -eq 0) { Mal "Falta aplicar primero aplicar-familia-sos-nombres-panel.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'async function nativeFamilyPerm') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-permisos')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: los permisos (el ojo) ya estan en el servidor."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + tpl[i:j] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›✓']
assert not bad, set(bad)
open(R + 'aplicar-permisos-ojo-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
t = open(S + 'index-sosnombres.ts', encoding='utf-8').read()
for a in pares:
    assert t.count(a) == 1, (t.count(a), a[:70])
for a, b in zip(pares, nuevos):
    t = t.replace(a, b)
open(S + 'index-permisos.ts', 'w', encoding='utf-8').write(t)
print('ok', len(total), len(t))
