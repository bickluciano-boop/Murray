# aplicar-familia-sos-panel.ps1 - SOS de Familia, parte del servidor y del panel. Cuando alguien de la familia pide ayuda (desde la app),
# le llega al titular y a los adultos de su familia (a un amigo, solo al titular que lo invito): aviso con sirena, mail, SMS si lo
# tiene activado, y su ubicacion en vivo durante 10 minutos. Quien lo manda ve a quien le aviso y lo puede cancelar ("Estoy bien").
# En el mapa del panel aparece un cartel rojo con "Ver en el mapa" y "Atendido".
# De paso: el nombre que ve el titular de un integrante ya no sale del correo ("Mama") sino el que le puso.
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Toca src\index.ts y actualiza src\panel-mapa.txt y src\panel-mapa.css.
# Respaldos .bak-sos. Base de datos: dos tablas nuevas (family_sos y family_sos_to). Al final crea las tablas y publica el panel solo.
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
$indexTexto = (Leer (Join-Path $raiz "src\index.ts")).texto
if ((Contar $indexTexto 'async function nativeFamilySos') -ne 0) { Avi "El SOS ya estaba aplicado en el servidor. No toco nada."; return }
if ((Contar $indexTexto 'async function remoteFamilyAlerts') -eq 0) { Mal "Primero corre aplicar-familia-avisos-persona.ps1."; return }
$cambios = @(
    @('src\index.ts', 'aviso simple con opciones', '/** Aviso visible simple, sin orden (Familia: "te cambiaron el rol"). Al tocarlo, la app solo se sincroniza. */
async function sendExpoNotice(pushToken: string | null, title: string, body: string) {
  if (!pushToken || !/^(ExponentPushToken|ExpoPushToken)\[.+\]$/.test(pushToken)) return false;
  const response = await fetch("https://exp.host/--/api/v2/push/send", {
    method: "POST",
    headers: { "content-type": "application/json", accept: "application/json" },
    body: JSON.stringify([{ to: pushToken, title, body, sound: "default", priority: "high", ttl: 86_400, data: {} }]),
  });
  return response.ok;
}', '/** Aviso visible simple, sin orden (Familia: "te cambiaron el rol"). Al tocarlo, la app solo se sincroniza. */
async function sendExpoNotice(pushToken: string | null, title: string, body: string, opciones?: { sound?: string; channelId?: string; ttl?: number }) {
  if (!pushToken || !/^(ExponentPushToken|ExpoPushToken)\[.+\]$/.test(pushToken)) return false;
  const response = await fetch("https://exp.host/--/api/v2/push/send", {
    method: "POST",
    headers: { "content-type": "application/json", accept: "application/json" },
    body: JSON.stringify([{ to: pushToken, title, body, sound: opciones?.sound ?? "default", priority: "high", ttl: opciones?.ttl ?? 86_400, ...(opciones?.channelId ? { channelId: opciones.channelId } : {}), data: {} }]),
  });
  return response.ok;
}'),
    @('src\index.ts', 'nombre del integrante visto por el titular', '  if (comoMiembro?.name) return comoMiembro.name;
  return aQuien.split("@")[0].replace(/^./, (c) => c.toUpperCase());
', '  if (comoMiembro?.name) return comoMiembro.name;
  // `porQuien` es el titular y `aQuien` un integrante de su familia: el nombre con que lo cargo.
  const comoTitular = await env.DB.prepare("SELECT name FROM family_members WHERE owner_email=? AND member_email=? AND status=''activo'' AND name IS NOT NULL AND name<>'''' LIMIT 1")
    .bind(porQuien, aQuien).first<{ name: string }>();
  if (comoTitular?.name) return comoTitular.name;
  return aQuien.split("@")[0].replace(/^./, (c) => c.toUpperCase());
'),
    @('src\index.ts', 'SOS: funciones', '/** Pagina que abre el link de invitacion (WhatsApp, mail): muestra el codigo y como usarlo. */
', '// ---------------------------------------------------------------------------
// SOS (Familia, etapa C): la persona pide ayuda desde su telefono (el boton de la app y, sin abrirla,
// los disparadores del sistema). Le llega a los adultos y al titular de su familia (a un amigo, solo
// al titular que lo invito), con su ubicacion; la ubicacion en vivo corre 10 minutos. Quien lo manda
// ve a quien le aviso y lo puede cancelar ("Estoy bien"). Tablas creadas a mano el 11/10/2026:
//   CREATE TABLE IF NOT EXISTS family_sos (id TEXT PRIMARY KEY, person_email TEXT NOT NULL,
//     status TEXT NOT NULL, location_json TEXT, created_at TEXT NOT NULL, resolved_at TEXT, resolved_by TEXT);
//   CREATE TABLE IF NOT EXISTS family_sos_to (sos_id TEXT NOT NULL, email TEXT NOT NULL,
//     person_id TEXT, person_name TEXT, PRIMARY KEY (sos_id, email));
// ---------------------------------------------------------------------------
const SOS_LIVE_MINUTES = 10;
const SOS_ACTIVE_MS = 3 * 3600_000;

const sosDesde = () => new Date(Date.now() - SOS_ACTIVE_MS).toISOString();

/** A quien le llega el SOS de `person`: el titular y los adultos de cada familia donde esta (un amigo, solo el titular). */
async function familySosRecipients(env: Env, person: string) {
  const destinatarios = new Set<string>();
  const comoIntegrante = await env.DB.prepare("SELECT owner_email AS ownerEmail,role FROM family_members WHERE member_email=? AND status=''activo''")
    .bind(person).all<{ ownerEmail: string; role: string }>();
  const adultosDe = async (titular: string) => (await env.DB.prepare("SELECT member_email AS email FROM family_members WHERE owner_email=? AND status=''activo'' AND role=''adulto'' AND member_email IS NOT NULL")
    .bind(titular).all<{ email: string }>()).results.map((f) => f.email);
  for (const f of comoIntegrante.results) {
    destinatarios.add(f.ownerEmail);
    if (f.role !== "amigo") for (const adulto of await adultosDe(f.ownerEmail)) destinatarios.add(adulto);
  }
  // Si la persona es titular de una familia, le llega a sus adultos.
  for (const adulto of await adultosDe(person)) destinatarios.add(adulto);
  destinatarios.delete(person);
  return [...destinatarios];
}

/** El correo de la persona que ve `viewer` con ese id (family_members.id o "titular:correo"). */
async function familyPersonEmail(env: Env, personId: string) {
  if (personId.startsWith("titular:")) return personId.slice("titular:".length);
  const fila = await env.DB.prepare("SELECT member_email AS email FROM family_members WHERE id=? AND status=''activo''").bind(personId).first<{ email: string | null }>();
  return fila?.email ?? null;
}

/** Como ve `viewer` a la persona de correo `email` en su mapa: su id y su nombre (null si no la ve). */
async function familyPersonSeenBy(env: Env, viewer: string, email: string) {
  for (const p of await familyPeopleFor(env, viewer)) {
    if ((await familyPersonEmail(env, String(p.id))) === email) return { id: String(p.id), name: String(p.name) };
  }
  return null;
}

/** El SOS activo de `person` (el que mando ella): id, cuando y a quien le aviso (con los nombres que ella les da). */
async function familySosOf(env: Env, person: string) {
  const sos = await env.DB.prepare("SELECT id,created_at AS createdAt FROM family_sos WHERE person_email=? AND status=''activo'' AND created_at>? ORDER BY created_at DESC LIMIT 1")
    .bind(person, sosDesde()).first<{ id: string; createdAt: string }>();
  if (!sos) return null;
  const para = await env.DB.prepare("SELECT email FROM family_sos_to WHERE sos_id=?").bind(sos.id).all<{ email: string }>();
  const to: string[] = [];
  for (const r of para.results) to.push(await familyNameSeenBy(env, r.email, person));
  return { id: sos.id, createdAt: sos.createdAt, to };
}

/** Los SOS activos que le llegaron a `viewer` (el cartel rojo del mapa). */
async function familySosFor(env: Env, viewer: string) {
  const filas = await env.DB.prepare(
    "SELECT s.id,s.location_json AS locationJson,s.created_at AS createdAt,t.person_id AS personId,t.person_name AS personName FROM family_sos s JOIN family_sos_to t ON t.sos_id=s.id WHERE t.email=? AND s.status=''activo'' AND s.created_at>? ORDER BY s.created_at DESC",
  ).bind(viewer, sosDesde()).all<{ id: string; locationJson: string | null; createdAt: string; personId: string | null; personName: string | null }>();
  return filas.results.map((f) => ({ id: f.id, personId: f.personId, personName: f.personName, createdAt: f.createdAt, location: f.locationJson ? JSON.parse(f.locationJson) : null }));
}

async function familySosMail(env: Env, to: string, nombre: string, location: Record<string, unknown> | null) {
  const lat = Number(location?.latitude), lng = Number(location?.longitude);
  const hayMapa = Number.isFinite(lat) && Number.isFinite(lng);
  const donde = hayMapa ? `<p style="color:#d2d2ce"><strong style="color:#fff">D&#243;nde:</strong> ${escapeHtml(location?.address || `${lat}, ${lng}`)}</p><p style="margin:20px 0"><a style="display:inline-block;background:#d9b24c;color:#111;padding:12px 16px;border-radius:10px;text-decoration:none;font-weight:700" href="https://www.google.com/maps/search/?api=1&query=${lat},${lng}">Abrir en el mapa</a></p>` : `<p style="color:#d2d2ce">No lleg&#243; una ubicaci&#243;n nueva: en el mapa de Ojo Guard MS ves la &#250;ltima conocida.</p>`;
  const response = await fetchCorreo("https://api.resend.com/emails", {
    method: "POST",
    headers: { authorization: `Bearer ${env.RESEND_API_KEY}`, "content-type": "application/json" },
    body: JSON.stringify({
      from: env.MAIL_FROM,
      reply_to: env.SUPPORT_EMAIL,
      to: [to],
      subject: `SOS: ${nombre} pidi\u00f3 ayuda`,
      html: `<div style="font-family:Arial,sans-serif;max-width:620px;margin:auto;background:#0c0d0f;color:#f6f6f2;padding:28px;border-radius:20px"><p style="color:#ff8a7a;font-size:12px;font-weight:800;letter-spacing:.16em">OJO GUARD &#183; SOS</p><h1 style="font-size:26px;margin:10px 0 18px">${escapeHtml(nombre)} pidi&#243; ayuda</h1><p style="color:#d2d2ce;line-height:1.55">Mandaron este aviso desde su tel&#233;fono. Llamala o llam&#225; a quien pueda ir. En el mapa de <a style="color:#d9b24c" href="${env.PANEL_URL || DEFAULT_PANEL_URL}">Ojo Guard MS</a> la ves moverse durante los pr&#243;ximos ${SOS_LIVE_MINUTES} minutos.</p>${donde}</div>`,
    }),
  });
  if (!response.ok) console.error("family_sos_mail_failed", response.status, await response.text());
}

/** "Seguir en vivo" para el telefono de quien pidio ayuda: la ubicacion llega cada pocos segundos al mapa. */
async function familySosLive(env: Env, deviceId: string) {
  const hasta = plusMinutes(SOS_LIVE_MINUTES);
  const viva = await env.DB.prepare("SELECT id FROM commands WHERE device_id=? AND type=''live'' AND status<>''failed'' AND expires_at>? ORDER BY created_at DESC LIMIT 1")
    .bind(deviceId, now()).first<{ id: string }>();
  if (viva) {
    await env.DB.prepare("UPDATE commands SET expires_at=? WHERE id=? AND expires_at<?").bind(hasta, viva.id, hasta).run();
    return hasta;
  }
  const duenio = await env.DB.prepare("SELECT owner_email AS email,name,push_token AS pushToken FROM devices WHERE id=?").bind(deviceId).first<{ email: string; name: string; pushToken: string | null }>();
  if (!duenio) return hasta;
  const id = randomId("cmd");
  await env.DB.prepare("INSERT INTO commands (id,device_id,owner_email,type,status,created_at,expires_at) VALUES (?,?,?,?,?,?,?)").bind(id, deviceId, duenio.email, "live", "pending", now(), hasta).run();
  await sendExpoCommandPush(duenio.pushToken, "live", id, duenio.name).catch(() => false);
  return hasta;
}

/** El telefono de una persona manda o cancela su SOS (el boton de la app o un disparador del sistema). */
async function nativeFamilySos(request: Request, env: Env) {
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const deviceId = String(body.deviceId ?? "");
  const email = await nativeOwnerEmail(request, env, deviceId);
  if (!email) return json({ error: "unauthorized" }, 401);
  const activo = await familySosOf(env, email);
  if (body.action === "cancel") {
    if (!activo) return json({ cancelled: false });
    await env.DB.prepare("UPDATE family_sos SET status=''cancelado'', resolved_at=?, resolved_by=? WHERE id=?").bind(now(), email, activo.id).run();
    await env.DB.prepare("UPDATE commands SET expires_at=? WHERE device_id=? AND type=''live'' AND expires_at>?").bind(now(), deviceId, now()).run();
    const para = await env.DB.prepare("SELECT email,person_name AS name FROM family_sos_to WHERE sos_id=?").bind(activo.id).all<{ email: string; name: string | null }>();
    for (const r of para.results) {
      for (const token of await pushTokensOf(env, r.email)) await sendExpoNotice(token, "Ojo Guard", `${r.name || "Esa persona"} cancel\u00f3 el SOS: est\u00e1 bien.`).catch(() => false);
    }
    return json({ cancelled: true });
  }
  const location = body.location && typeof body.location === "object" ? body.location as Record<string, unknown> : null;
  const tieneUbicacion = Boolean(location && Number.isFinite(Number(location.latitude)) && Number.isFinite(Number(location.longitude)));
  if (tieneUbicacion) {
    await env.DB.prepare("UPDATE devices SET last_location_json=?,last_location_at=?,last_seen_at=? WHERE id=?").bind(JSON.stringify(location), now(), now(), deviceId).run();
  }
  // Si ya hay un SOS en curso no se avisa de nuevo (nadie recibe dos veces lo mismo): se renueva la ubicacion en vivo.
  if (activo) return json({ sent: true, repeated: true, id: activo.id, to: activo.to, until: await familySosLive(env, deviceId) });
  const destinatarios = await familySosRecipients(env, email);
  if (!destinatarios.length) return json({ error: "no_recipients" }, 409);
  const id = randomId("sos");
  const ubicacion = tieneUbicacion ? JSON.stringify(location) : (await env.DB.prepare("SELECT last_location_json AS loc FROM devices WHERE id=?").bind(deviceId).first<{ loc: string | null }>())?.loc ?? null;
  await env.DB.prepare("INSERT INTO family_sos (id,person_email,status,location_json,created_at) VALUES (?,?,?,?,?)").bind(id, email, "activo", ubicacion, now()).run();
  const ubicacionObj = ubicacion ? JSON.parse(ubicacion) as Record<string, unknown> : null;
  const to: string[] = [];
  for (const r of destinatarios) {
    const comoLaVe = await familyPersonSeenBy(env, r, email);
    const nombre = comoLaVe?.name || await familyNameSeenBy(env, email, r);
    await env.DB.prepare("INSERT INTO family_sos_to (sos_id,email,person_id,person_name) VALUES (?,?,?,?)").bind(id, r, comoLaVe?.id ?? null, nombre).run();
    to.push(await familyNameSeenBy(env, r, email));
    // Con sonido propio y por el canal de alta prioridad. En iPhone suena si no esta en silencio.
    for (const token of await pushTokensOf(env, r)) await sendExpoNotice(token, "SOS", `${nombre} pidi\u00f3 ayuda. Abr\u00ed el mapa para ver d\u00f3nde est\u00e1.`, { sound: "ojo_sirena.wav", channelId: "ojo-busqueda-v2", ttl: 600 }).catch(() => false);
    await familySosMail(env, r, nombre, ubicacionObj).catch((error) => console.error("family_sos_mail_failed", error));
    const prefs = await getNotificationPrefs(env, r);
    if (prefs.notifySms && prefs.phoneNumber) await sendSms(env, prefs.phoneNumber, `Ojo Guard SOS: ${nombre} pidi\u00f3 ayuda. Mapa: ${env.PANEL_URL || DEFAULT_PANEL_URL}`);
  }
  return json({ sent: true, id, to, until: await familySosLive(env, deviceId) }, 201);
}

/** El panel: quien recibio un SOS lo marca como atendido. */
async function remoteFamilySos(request: Request, env: Env) {
  const sessionInfo = await readSessionInfo(request, env.SESSION_SECRET);
  if (!sessionInfo) return json({ error: "unauthorized" }, 401);
  const { email } = sessionInfo;
  if (request.method === "GET") return json({ sos: await familySosFor(env, email) });
  if (sessionInfo.method === "emergency") return json({ error: "not_allowed_in_emergency" }, 403);
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const sosId = String(body.id ?? "");
  const fila = await env.DB.prepare("SELECT s.person_email AS personEmail FROM family_sos s JOIN family_sos_to t ON t.sos_id=s.id WHERE s.id=? AND t.email=? AND s.status=''activo''")
    .bind(sosId, email).first<{ personEmail: string }>();
  if (!fila) return json({ error: "not_found" }, 404);
  await env.DB.prepare("UPDATE family_sos SET status=''atendido'', resolved_at=?, resolved_by=? WHERE id=?").bind(now(), email, sosId).run();
  const quien = await familyNameSeenBy(env, email, fila.personEmail);
  for (const token of await pushTokensOf(env, fila.personEmail)) await sendExpoNotice(token, "Ojo Guard", `${quien} vio tu SOS y lo marc\u00f3 como atendido.`).catch(() => false);
  return json({ resolved: true });
}

/** Pagina que abre el link de invitacion (WhatsApp, mail): muestra el codigo y como usarlo. */
'),
    @('src\index.ts', 'SOS para la app', '    me: { memberships: mine.results.length, isMinor: mine.results.some((m) => m.role === "menor") },
', '    me: { memberships: mine.results.length, isMinor: mine.results.some((m) => m.role === "menor"), sos: await familySosOf(env, email).catch(() => null) },
'),
    @('src\index.ts', 'SOS para el panel', '    alerts: await familyAlertsBy(env, email).catch(() => []),
  });
', '    alerts: await familyAlertsBy(env, email).catch(() => []),
    sos: await familySosFor(env, email).catch(() => []),
  });
'),
    @('src\index.ts', 'ruta del SOS (app)', '      if (route === "POST /api/native/family/leave") return nativeFamilyLeave(request, env);
', '      if (route === "POST /api/native/family/leave") return nativeFamilyLeave(request, env);
      if (route === "POST /api/native/family/sos") return nativeFamilySos(request, env);
'),
    @('src\index.ts', 'ruta del SOS (panel)', '      if (route === "GET /api/remote/family/alerts" || route === "POST /api/remote/family/alerts") return remoteFamilyAlerts(request, env);
', '      if (route === "GET /api/remote/family/alerts" || route === "POST /api/remote/family/alerts") return remoteFamilyAlerts(request, env);
      if (route === "GET /api/remote/family/sos" || route === "POST /api/remote/family/sos") return remoteFamilySos(request, env);
')
)
$descargas = @(
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/b0b7b84/scripts/mapa/panel-mapa.txt", "src\panel-mapa.txt", "c490d501f1d437b75e82bc05549abf667663f6431c62256115c8ec6a2795ac8a"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/b0b7b84/scripts/mapa/panel-mapa.css", "src\panel-mapa.css", "2cdd37c2b6ca9593701a2fbb87766d8f60e1fa8af8808af43f51d2b3f9762474")
)

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
    if (Test-Path ($ruta + ".bak-sos")) { Mal ("Ya existe " + $t + ".bak-sos. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-sos"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-sos): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-sos") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "Archivos listos. Ahora creo las dos tablas del SOS en la base y publico el panel (todo solo)..."
$sqlSos = 'CREATE TABLE IF NOT EXISTS family_sos (id TEXT PRIMARY KEY, person_email TEXT NOT NULL, status TEXT NOT NULL, location_json TEXT, created_at TEXT NOT NULL, resolved_at TEXT, resolved_by TEXT); CREATE TABLE IF NOT EXISTS family_sos_to (sos_id TEXT NOT NULL, email TEXT NOT NULL, person_id TEXT, person_name TEXT, PRIMARY KEY (sos_id, email));'
& npx.cmd wrangler d1 execute ojo-guard-ms --remote --command $sqlSos
if ($LASTEXITCODE -ne 0) { Mal "No se pudieron crear las tablas, asi que no publique nada. Mandame esta pantalla."; return }
Ok "Tablas creadas"
& npx.cmd wrangler deploy
if ($LASTEXITCODE -ne 0) { Mal "No se pudo publicar el panel. Mandame esta pantalla."; return }
Write-Host ""
Ok "LISTO: el panel quedo publicado con el SOS."
Write-Host ""
