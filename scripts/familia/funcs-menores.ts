// ---------------------------------------------------------------------------
// Familia y amigos (etapa A): invitar con un codigo y ver a la familia en el mapa.
// Una "familia" es el titular (owner_email) mas las personas activas que invito.
// Adultos y menores de una misma familia se ven entre si. Un amigo se ve solo con
// el titular que lo invito, no con el resto. Los menores no pueden pausar su
// ubicacion; adultos y amigos si.
// ---------------------------------------------------------------------------
const FAMILY_ROLES = ["adulto", "menor", "amigo"] as const;
const FAMILY_INVITE_DAYS = 7;
// Sin 0/O ni 1/I/L para que el codigo no se confunda al dictarlo o copiarlo a mano.
const FAMILY_CODE_CHARS = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";

function familyCode() {
  const bytes = crypto.getRandomValues(new Uint8Array(6));
  return [...bytes].map((b) => FAMILY_CODE_CHARS[b % FAMILY_CODE_CHARS.length]).join("");
}

function familyInviteUrl(env: Env, code: string) {
  return `${env.PANEL_URL || DEFAULT_PANEL_URL}unirme?codigo=${code}`;
}

/**
 * Las personas que `viewer` puede ver: las de cada familia donde es titular o
 * integrante activo, mas los titulares de esas familias (con un amigo, solo el
 * titular y el amigo se ven). Para cada una se toma la ultima ubicacion de su
 * telefono principal (o del equipo mas reciente).
 */
async function familyPeopleFor(env: Env, viewer: string) {
  const rows = await env.DB.prepare(
    "SELECT f.id,f.owner_email AS ownerEmail,f.member_email AS memberEmail,f.name,f.role,f.paused_until AS pausedUntil,f.owner_name AS ownerName FROM family_members f WHERE f.status='activo' AND (f.owner_email=? OR f.owner_email IN (SELECT owner_email FROM family_members WHERE member_email=? AND status='activo'))",
  ).bind(viewer, viewer).all<{ id: string; ownerEmail: string; memberEmail: string; name: string; role: string; pausedUntil: string | null; ownerName: string | null }>();
  // Como ve `viewer` a cada titular: el nombre que ese titular eligio al invitarlo
  // ("Papa", "Luciano"). Sale de la fila de la invitacion de `viewer`, igual que el
  // rol que tiene `viewer` en esa familia.
  const nombreDelTitular = new Map<string, string>();
  const miRol = new Map<string, string>();
  for (const r of rows.results) {
    if (r.memberEmail !== viewer) continue;
    miRol.set(r.ownerEmail, r.role);
    if (r.ownerName) nombreDelTitular.set(r.ownerEmail, r.ownerName);
  }
  // tutor: `viewer` puede ubicar, hacer sonar y seguir en vivo a esta persona (es un
  // menor de una familia donde `viewer` es el titular o un adulto).
  type Persona = { id: string; email: string; name: string; role: string; pausedUntil: string | null; owner: boolean; tutor: boolean };
  const personas = new Map<string, Persona>();
  for (const r of rows.results) {
    // Un amigo se ve solo con el titular: en una familia ajena, ni el amigo ve al
    // resto ni el resto lo ve a el. El titular ve a todos los suyos.
    const seVen = r.ownerEmail === viewer || (miRol.get(r.ownerEmail) !== "amigo" && r.role !== "amigo");
    if (seVen && r.memberEmail && r.memberEmail !== viewer && !personas.has(r.memberEmail)) {
      const tutor = r.role === "menor" && (r.ownerEmail === viewer || miRol.get(r.ownerEmail) === "adulto");
      personas.set(r.memberEmail, { id: r.id, email: r.memberEmail, name: r.name, role: r.role, pausedUntil: r.pausedUntil, owner: false, tutor });
    }
    if (r.ownerEmail !== viewer && !personas.has(r.ownerEmail)) {
      // El titular de una familia ajena: con el nombre que eligio al invitar (si no puso
      // ninguno, mas abajo se usa el de su correo).
      personas.set(r.ownerEmail, { id: `titular:${r.ownerEmail}`, email: r.ownerEmail, name: nombreDelTitular.get(r.ownerEmail) ?? "", role: "adulto", pausedUntil: null, owner: true, tutor: false });
    }
  }
  const ahora = Date.now();
  const people: Record<string, unknown>[] = [];
  for (const p of personas.values()) {
    const device = await env.DB.prepare(
      "SELECT id,name,platform,battery,last_seen_at AS lastSeenAt,last_location_json AS lastLocationJson,last_location_at AS lastLocationAt FROM devices WHERE owner_email=? AND approval_status='approved' ORDER BY CASE WHEN device_role='primary' THEN 0 ELSE 1 END, COALESCE(last_location_at,'') DESC LIMIT 1",
    ).bind(p.email).first<{ id: string; name: string; platform: string; battery: number | null; lastSeenAt: string | null; lastLocationJson: string | null; lastLocationAt: string | null }>();
    const paused = Boolean(p.pausedUntil && Date.parse(p.pausedUntil) > ahora);
    people.push({
      id: p.id,
      // Si el titular no eligio como lo ven, se usa el de su correo ("Bickluciano").
      name: p.name || (p.owner ? p.email.split("@")[0].replace(/^./, (c) => c.toUpperCase()) : device?.name || p.email.split("@")[0]),
      role: p.role,
      owner: p.owner,
      canCommand: p.tutor,
      platform: device?.platform ?? null,
      paused,
      pausedUntil: paused ? p.pausedUntil : null,
      battery: device?.battery ?? null,
      online: typeof device?.lastSeenAt === "string" && ahora - Date.parse(device.lastSeenAt) <= 2 * 60_000,
      lastSeenAt: device?.lastSeenAt ?? null,
      // Con la ubicacion pausada no se manda nada de donde esta.
      lastLocation: !paused && device?.lastLocationJson ? JSON.parse(device.lastLocationJson) : null,
      lastLocationAt: !paused ? device?.lastLocationAt ?? null : null,
    });
  }
  return people;
}

async function remoteFamily(request: Request, env: Env) {
  const sessionInfo = await readSessionInfo(request, env.SESSION_SECRET);
  if (!sessionInfo) return json({ error: "unauthorized" }, 401);
  const { email } = sessionInfo;
  const people = await familyPeopleFor(env, email);
  const invites = await env.DB.prepare(
    "SELECT id,name,role,invite_code AS code,invite_expires_at AS expiresAt FROM family_members WHERE owner_email=? AND status='invitado' AND invite_expires_at>? ORDER BY created_at DESC",
  ).bind(email, now()).all<{ id: string; name: string; role: string; code: string; expiresAt: string }>();
  // El ultimo "como te ve" que uso el titular, para completar solo el dialogo de invitar.
  const ultimo = await env.DB.prepare(
    "SELECT owner_name AS ownerName FROM family_members WHERE owner_email=? AND owner_name IS NOT NULL AND owner_name<>'' ORDER BY created_at DESC LIMIT 1",
  ).bind(email).first<{ ownerName: string }>();
  return json({
    people,
    invites: invites.results.map((i) => ({ ...i, link: familyInviteUrl(env, i.code) })),
    ownerName: ultimo?.ownerName ?? "",
  });
}

async function remoteFamilyInvite(request: Request, env: Env) {
  const sessionInfo = await readSessionInfo(request, env.SESSION_SECRET);
  if (!sessionInfo) return json({ error: "unauthorized" }, 401);
  if (sessionInfo.method === "emergency") return json({ error: "not_allowed_in_emergency" }, 403);
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const name = String(body.name ?? "").trim().slice(0, 40);
  const role = String(body.role ?? "");
  // Como va a ver al titular la persona invitada ("Papa", "Luciano"). Columna owner_name,
  // agregada a mano el 08/10/2026 con ALTER TABLE family_members ADD COLUMN owner_name TEXT.
  const ownerName = String(body.ownerName ?? "").trim().slice(0, 40);
  if (!name || !(FAMILY_ROLES as readonly string[]).includes(role)) return json({ error: "invalid_invite" }, 400);
  const id = randomId("fam"), expiresAt = plusMinutes(FAMILY_INVITE_DAYS * 24 * 60);
  // El codigo es unico: si por azar ya existe, se prueba otro.
  for (let intento = 0; intento < 5; intento += 1) {
    const code = familyCode();
    try {
      await env.DB.prepare("INSERT INTO family_members (id,owner_email,name,role,status,invite_code,invite_expires_at,created_at,owner_name) VALUES (?,?,?,?,?,?,?,?,?)")
        .bind(id, sessionInfo.email, name, role, "invitado", code, expiresAt, now(), ownerName || null).run();
      return json({ id, name, role, code, expiresAt, ownerName, link: familyInviteUrl(env, code) }, 201);
    } catch (error) {
      if (!String(error).includes("UNIQUE")) throw error;
    }
  }
  return json({ error: "invite_code_unavailable" }, 503);
}

async function remoteFamilyRemove(request: Request, env: Env) {
  const sessionInfo = await readSessionInfo(request, env.SESSION_SECRET);
  if (!sessionInfo) return json({ error: "unauthorized" }, 401);
  if (sessionInfo.method === "emergency") return json({ error: "not_allowed_in_emergency" }, 403);
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const updated = await env.DB.prepare("UPDATE family_members SET status='quitado', invite_code=NULL WHERE id=? AND owner_email=? AND status<>'quitado'")
    .bind(String(body.id ?? ""), sessionInfo.email).run();
  return updated.meta.changes ? json({ removed: true }) : json({ error: "not_found" }, 404);
}

async function nativeOwnerEmail(request: Request, env: Env, deviceId: string) {
  if (!deviceId || !await requireNative(request, env, deviceId)) return null;
  const device = await env.DB.prepare("SELECT owner_email AS ownerEmail FROM devices WHERE id=? AND approval_status='approved'")
    .bind(deviceId).first<{ ownerEmail: string }>();
  return device?.ownerEmail ?? null;
}

async function nativeFamily(request: Request, env: Env, url: URL) {
  const email = await nativeOwnerEmail(request, env, url.searchParams.get("deviceId") ?? "");
  if (!email) return json({ error: "unauthorized" }, 401);
  const mine = await env.DB.prepare("SELECT role,paused_until AS pausedUntil FROM family_members WHERE member_email=? AND status='activo'")
    .bind(email).all<{ role: string; pausedUntil: string | null }>();
  return json({
    people: await familyPeopleFor(env, email),
    // Lo que la app necesita para mostrarle a la persona con quien comparte y si puede pausar.
    me: { memberships: mine.results.length, isMinor: mine.results.some((m) => m.role === "menor") },
  });
}

async function nativeFamilyJoin(request: Request, env: Env) {
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const email = await nativeOwnerEmail(request, env, String(body.deviceId ?? ""));
  if (!email) return json({ error: "unauthorized" }, 401);
  const code = String(body.code ?? "").trim().toUpperCase().replace(/[^A-Z0-9]/g, "");
  if (code.length !== 6) return json({ error: "invalid_code" }, 400);
  const invite = await env.DB.prepare("SELECT id,owner_email AS ownerEmail,name,role FROM family_members WHERE invite_code=? AND status='invitado' AND invite_expires_at>?")
    .bind(code, now()).first<{ id: string; ownerEmail: string; name: string; role: string }>();
  if (!invite) return json({ error: "code_not_found_or_expired" }, 404);
  if (invite.ownerEmail === email) return json({ error: "own_family" }, 409);
  // Si ya estaba en esa familia (por otra invitacion), se reemplaza la vieja.
  await env.DB.prepare("UPDATE family_members SET status='quitado' WHERE owner_email=? AND member_email=? AND status='activo'")
    .bind(invite.ownerEmail, email).run();
  await env.DB.prepare("UPDATE family_members SET member_email=?, status='activo', joined_at=?, invite_code=NULL WHERE id=?")
    .bind(email, now(), invite.id).run();
  return json({ joined: true, name: invite.name, role: invite.role });
}

async function nativeFamilyPause(request: Request, env: Env) {
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const email = await nativeOwnerEmail(request, env, String(body.deviceId ?? ""));
  if (!email) return json({ error: "unauthorized" }, 401);
  const minutes = Math.max(0, Math.min(24 * 60, Math.round(Number(body.minutes) || 0)));
  // Los menores no pueden pausar: su ubicacion es justamente lo que cuida el tutor.
  const updated = await env.DB.prepare("UPDATE family_members SET paused_until=? WHERE member_email=? AND status='activo' AND role<>'menor'")
    .bind(minutes ? plusMinutes(minutes) : null, email).run();
  if (minutes > 0 && !updated.meta.changes) return json({ error: "minor_cannot_pause" }, 403);
  return json({ paused: minutes > 0, until: minutes ? plusMinutes(minutes) : null });
}

/** Pagina que abre el link de invitacion (WhatsApp, mail): muestra el codigo y como usarlo. */
function familyJoinPage(url: URL) {
  const code = (url.searchParams.get("codigo") ?? "").toUpperCase().replace(/[^A-Z0-9]/g, "").slice(0, 6);
  const html = `<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Unirte a una familia en Ojo Guard</title>
<style>body{margin:0;min-height:100vh;display:grid;place-items:center;background:#0b0c0e;color:#f3f1ea;font-family:system-ui,-apple-system,Segoe UI,sans-serif;padding:24px}main{max-width:420px;text-align:center}img{height:34px;margin-bottom:22px}h1{font-size:26px;margin:0 0 10px}p{color:#a29e92;line-height:1.55}.codigo{font-size:40px;letter-spacing:.22em;font-weight:700;color:#f0c75a;background:#211d12;border:1px solid #4a3f1f;border-radius:16px;padding:16px 10px;margin:22px 0}ol{text-align:left;color:#d6d2c6;line-height:1.7;padding-left:22px}a.boton{display:inline-block;margin-top:16px;background:#d9b24c;color:#111;border-radius:12px;padding:12px 18px;font-weight:700;text-decoration:none}</style></head>
<body><main><img src="/marca/logo-correo.png" alt="ojo guard"><h1>Te invitaron a una familia</h1><p>Vas a compartir tu ubicaci&oacute;n con esa familia y ver la de ellos en el mapa.</p>
<div class="codigo">${code || "------"}</div>
<ol><li>Instal&aacute; Ojo Guard en tu tel&eacute;fono y entr&aacute; con tu correo.</li><li>And&aacute; a <b>Familia</b> &rsaquo; <b>Unirme con un c&oacute;digo</b>.</li><li>Escrib&iacute; el c&oacute;digo de arriba.</li></ol>
<a class="boton" href="ojoguard://familia?codigo=${code}">Abrir Ojo Guard</a></main></body></html>`;
  return new Response(html, { headers: { "content-type": "text/html; charset=utf-8", "cache-control": "no-store" } });
}

// ---------------------------------------------------------------------------
// Menores (etapa C, parte 1): sus tutores -el titular de la familia y los adultos
// que invito- pueden ubicar, hacer sonar y seguir en vivo el telefono del menor.
// Los amigos no. Cada pedido le avisa al menor quien lo hizo (push y correo a su
// cuenta): no hay modo oculto, como promete el rol ("siempre ve quien lo mira").
// ---------------------------------------------------------------------------
const FAMILY_MINOR_COMMANDS: readonly CommandType[] = ["locate", "alarm", "stop-ring"];

/** El telefono de un menor sobre el que `viewer` es tutor, y con que nombre ve el menor a `viewer`. */
async function familyMinorTarget(env: Env, viewer: string, personId: string) {
  const fila = await env.DB.prepare(
    "SELECT owner_email AS ownerEmail,member_email AS memberEmail,owner_name AS ownerName FROM family_members WHERE id=? AND status='activo' AND role='menor'",
  ).bind(personId).first<{ ownerEmail: string; memberEmail: string | null; ownerName: string | null }>();
  if (!fila?.memberEmail || fila.memberEmail === viewer) return null;
  let quien = "";
  if (fila.ownerEmail === viewer) {
    quien = fila.ownerName || "";
  } else {
    const adulto = await env.DB.prepare("SELECT name FROM family_members WHERE owner_email=? AND member_email=? AND status='activo' AND role='adulto'")
      .bind(fila.ownerEmail, viewer).first<{ name: string }>();
    if (!adulto) return null;
    quien = adulto.name;
  }
  // El mismo telefono que muestra el mapa (ver familyPeopleFor).
  const device = await env.DB.prepare(
    "SELECT id,name,push_token AS pushToken FROM devices WHERE owner_email=? AND approval_status='approved' ORDER BY CASE WHEN device_role='primary' THEN 0 ELSE 1 END, COALESCE(last_location_at,'') DESC LIMIT 1",
  ).bind(fila.memberEmail).first<{ id: string; name: string; pushToken: string | null }>();
  if (!device) return null;
  return { minorEmail: fila.memberEmail, device, quien: quien || viewer.split("@")[0].replace(/^./, (c) => c.toUpperCase()) };
}

/** Si `viewer` es tutor del menor duenio de la orden (para consultar como va). */
async function familyIsTutorOf(env: Env, viewer: string, minorEmail: string) {
  const fila = await env.DB.prepare(
    "SELECT 1 AS ok FROM family_members f WHERE f.member_email=? AND f.status='activo' AND f.role='menor' AND (f.owner_email=? OR f.owner_email IN (SELECT owner_email FROM family_members WHERE member_email=? AND status='activo' AND role='adulto')) LIMIT 1",
  ).bind(minorEmail, viewer, viewer).first<{ ok: number }>();
  return Boolean(fila);
}

function familyMinorNotice(type: CommandType | "live", quien: string): [string, string] {
  if (type === "locate") return ["Ojo Guard \u2014 Pidieron tu ubicaci\u00f3n", `${quien} pidi\u00f3 tu ubicaci\u00f3n desde Ojo Guard MS.`];
  if (type === "alarm") return ["Ojo Guard \u2014 Buscando este tel\u00e9fono", `${quien} hizo sonar tu tel\u00e9fono para encontrarlo.`];
  if (type === "stop-ring") return ["Ojo Guard \u2014 Sonido detenido", `${quien} detuvo el sonido.`];
  return ["Ojo Guard \u2014 Ubicaci\u00f3n en vivo", `${quien} est\u00e1 viendo tu ubicaci\u00f3n en vivo.`];
}

async function remoteFamilyCommand(request: Request, env: Env, url: URL) {
  const sessionInfo = await readSessionInfo(request, env.SESSION_SECRET);
  if (!sessionInfo) return json({ error: "unauthorized" }, 401);
  if (sessionInfo.method === "emergency") return json({ error: "not_allowed_in_emergency" }, 403);
  const { email } = sessionInfo;
  if (request.method === "GET") {
    const id = url.searchParams.get("commandId") ?? "";
    const command = await env.DB.prepare(
      "SELECT id,owner_email AS ownerEmail,type,status,created_at AS createdAt,executed_at AS executedAt,failed_at AS failedAt,error,location_json AS locationJson FROM commands WHERE id=?",
    ).bind(id).first<Record<string, unknown>>();
    if (!command || !await familyIsTutorOf(env, email, String(command.ownerEmail))) return json({ error: "not_found" }, 404);
    // Igual que con los equipos propios: si el telefono no contesta la ubicacion en
    // 45 segundos, se da por vencida y el mapa sigue con la ultima conocida.
    if (command.type === "locate" && ["pending", "received"].includes(String(command.status)) && Date.now() - Date.parse(String(command.createdAt)) >= 45_000) {
      const failedAt = now();
      await env.DB.prepare("UPDATE commands SET status='failed',failed_at=?,error='location_timeout' WHERE id=? AND status IN ('pending','received')").bind(failedAt, id).run();
      command.status = "failed";
      command.failedAt = failedAt;
      command.error = "location_timeout";
    }
    if (command.locationJson) command.location = JSON.parse(String(command.locationJson));
    delete command.locationJson;
    delete command.ownerEmail;
    return json({ command });
  }
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const type = String(body.type ?? "") as CommandType;
  if (!FAMILY_MINOR_COMMANDS.includes(type)) return json({ error: "invalid_command" }, 400);
  const target = await familyMinorTarget(env, email, String(body.personId ?? ""));
  if (!target) return json({ error: "not_allowed" }, 403);
  const id = randomId("cmd"), createdAt = now();
  if (type === "stop-ring") {
    await env.DB.prepare("UPDATE commands SET status='failed', failed_at=?, error='cancelada_por_orden_opuesta' WHERE device_id=? AND status IN ('pending','received') AND type='alarm'")
      .bind(createdAt, target.device.id).run();
  }
  await env.DB.prepare("INSERT INTO commands (id,device_id,owner_email,type,status,created_at,expires_at) VALUES (?,?,?,?,?,?,?)")
    .bind(id, target.device.id, target.minorEmail, type, "pending", createdAt, plusMinutes(60)).run();
  const [titulo, detalle] = familyMinorNotice(type, target.quien);
  const pushSent = await sendExpoCommandPush(target.device.pushToken, type, id, target.device.name, { title: titulo, body: detalle }).catch(() => false);
  await sendSecurityNotice(env, target.minorEmail, titulo.replace(/^Ojo Guard \u2014 /, ""), detalle, target.device.name);
  return json({ queued: true, commandId: id, status: "pending", pushSent }, 202);
}

/** "Seguir en vivo" sobre el telefono de un menor: como remoteLive(), con aviso al menor al empezar. */
async function remoteFamilyLive(request: Request, env: Env) {
  const sessionInfo = await readSessionInfo(request, env.SESSION_SECRET);
  if (!sessionInfo) return json({ error: "unauthorized" }, 401);
  if (sessionInfo.method === "emergency") return json({ error: "not_allowed_in_emergency" }, 403);
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const target = await familyMinorTarget(env, sessionInfo.email, String(body.personId ?? ""));
  if (!target) return json({ error: "not_allowed" }, 403);
  const deviceId = target.device.id;
  const ahora = now();
  if (body.action === "stop") {
    await env.DB.prepare("UPDATE commands SET expires_at=? WHERE device_id=? AND type='live' AND expires_at>?").bind(ahora, deviceId, ahora).run();
    return json({ live: false });
  }
  const until = plusMinutes(LIVE_MINUTES);
  const activa = await env.DB.prepare("SELECT id,status FROM commands WHERE device_id=? AND type='live' AND status<>'failed' AND expires_at>? ORDER BY created_at DESC LIMIT 1")
    .bind(deviceId, ahora).first<{ id: string; status: string }>();
  if (activa) {
    await env.DB.prepare("UPDATE commands SET expires_at=? WHERE id=?").bind(until, activa.id).run();
    const pushSent = activa.status === "pending"
      ? await sendExpoCommandPush(target.device.pushToken, "live", activa.id, target.device.name).catch(() => false)
      : false;
    return json({ live: true, until, commandId: activa.id, status: activa.status, renewed: true, pushSent });
  }
  const id = randomId("cmd");
  await env.DB.prepare("INSERT INTO commands (id,device_id,owner_email,type,status,created_at,expires_at) VALUES (?,?,?,?,?,?,?)")
    .bind(id, deviceId, target.minorEmail, "live", "pending", ahora, until).run();
  const [titulo, detalle] = familyMinorNotice("live", target.quien);
  const pushSent = await sendExpoCommandPush(target.device.pushToken, "live", id, target.device.name, { title: titulo, body: detalle }).catch(() => false);
  await sendSecurityNotice(env, target.minorEmail, titulo.replace(/^Ojo Guard \u2014 /, ""), detalle, target.device.name);
  return json({ live: true, until, commandId: id, status: "pending", pushSent }, 202);
}

const HISTORY_EMAIL_POINT_COUNT = 10;
