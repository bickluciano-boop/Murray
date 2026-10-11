# aplicar-familia-avisos-persona.ps1 - Avisos de ubicacion por persona, como en Buscar: desde la tarjeta de alguien de la
# familia, "Avisarme cuando X llegue o salga de tal lugar". El aviso te llega a vos y esa persona se entera de que lo
# armaste. Reemplaza a "Lugares que avisan" (aplicar-familia-lugares.ps1), que queda como lista de atajos guardados.
# Incluye la calle y la altura al elegir un punto (aplicar-lugares-direccion.ps1): sirve se haya corrido o no.
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Toca src\index.ts y actualiza src\panel-mapa.txt y
# src\panel-mapa.css. Respaldos .bak-avisospersona. Base de datos: una tabla nueva (family_alerts).
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
if ((Contar $indexTexto 'async function remoteFamilyAlerts') -ne 0) { Avi "Los avisos por persona ya estaban aplicados. No toco nada."; return }
if ((Contar $indexTexto 'async function familyPlacesCheck') -eq 0) { Mal "Primero corre aplicar-familia-lugares.ps1."; return }
$mapaSha = Sha (Join-Path $raiz "src\panel-mapa.txt")
if (($mapaSha -ne "68c2984532b4e87b55c66023f0027c9e9506a8a2b000e2e7b0ab0fb50f3dc4a6") -and ($mapaSha -ne "ff7cc3450e3688f509aef8a5c6ad85f9cbe09c19c08801469b7250559197c6bc")) { Mal "src\panel-mapa.txt no es la version que espero. Primero corre aplicar-familia-lugares.ps1."; return }
$cambiosConDireccion = @(
    @('src\index.ts', 'lugares guardados y helpers de avisos', 'const PLACE_RADII = [100, 200, 300, 500];
const PLACE_MAX = 10;
// Para salir hay que alejarse 50 m mas que el radio: asi un GPS que baila en el borde no
// manda "llego" y "se fue" cada pocos minutos.
const PLACE_EXIT_MARGIN = 50;
// Con una ubicacion tan imprecisa no se decide nada.
const PLACE_MAX_ACCURACY = 300;
// Entre dos avisos del mismo lugar y la misma persona, al menos 5 minutos.
const PLACE_NOTICE_GAP_MS = 5 * 60_000;

/** Los lugares que ve `viewer`: los de su familia y los de las familias donde es adulto o menor. */
async function familyPlacesFor(env: Env, viewer: string) {
  const filas = await env.DB.prepare(
    "SELECT id,owner_email AS ownerEmail,name,latitude,longitude,radius FROM family_places WHERE owner_email=? OR owner_email IN (SELECT owner_email FROM family_members WHERE member_email=? AND status=''activo'' AND role<>''amigo'') ORDER BY created_at",
  ).bind(viewer, viewer).all<{ id: string; ownerEmail: string; name: string; latitude: number; longitude: number; radius: number }>();
  return filas.results.map((p) => ({ id: p.id, name: p.name, latitude: p.latitude, longitude: p.longitude, radius: p.radius, canEdit: p.ownerEmail === viewer }));
}

async function pushTokensOf(env: Env, email: string) {
  const filas = await env.DB.prepare("SELECT DISTINCT push_token AS pushToken FROM devices WHERE owner_email=? AND approval_status=''approved'' AND push_token IS NOT NULL")
    .bind(email).all<{ pushToken: string }>();
  return filas.results.map((f) => f.pushToken);
}', 'const PLACE_RADII = [100, 200, 300, 500];
// Como mucho 20 lugares guardados y 30 avisos por persona.
const PLACE_MAX = 20;
const ALERTAS_MAX = 30;
// Para salir hay que alejarse 50 m mas que el radio: asi un GPS que baila en el borde no
// manda "llego" y "se fue" cada pocos minutos.
const PLACE_EXIT_MARGIN = 50;
// Con una ubicacion tan imprecisa no se decide nada.
const PLACE_MAX_ACCURACY = 300;
// Entre dos avisos del mismo aviso, al menos 5 minutos (para "cada vez").
const PLACE_NOTICE_GAP_MS = 5 * 60_000;

/** Los lugares guardados de `viewer` (atajos propios para armar un aviso rapido). */
async function familyPlacesFor(env: Env, viewer: string) {
  const filas = await env.DB.prepare(
    "SELECT id,name,latitude,longitude,radius FROM family_places WHERE owner_email=? ORDER BY created_at",
  ).bind(viewer).all<{ id: string; name: string; latitude: number; longitude: number; radius: number }>();
  return filas.results.map((p) => ({ id: p.id, name: p.name, latitude: p.latitude, longitude: p.longitude, radius: p.radius, canEdit: true }));
}

async function pushTokensOf(env: Env, email: string) {
  const filas = await env.DB.prepare("SELECT DISTINCT push_token AS pushToken FROM devices WHERE owner_email=? AND approval_status=''approved'' AND push_token IS NOT NULL")
    .bind(email).all<{ pushToken: string }>();
  return filas.results.map((f) => f.pushToken);
}

/** Como ve `porQuien` a `aQuien` (el nombre que le pusieron en la familia), para los avisos. */
async function familyNameSeenBy(env: Env, aQuien: string, porQuien: string) {
  const comoDuenio = await env.DB.prepare("SELECT owner_name AS name FROM family_members WHERE owner_email=? AND member_email=? AND status=''activo'' AND owner_name IS NOT NULL AND owner_name<>'''' LIMIT 1")
    .bind(aQuien, porQuien).first<{ name: string }>();
  if (comoDuenio?.name) return comoDuenio.name;
  const comoMiembro = await env.DB.prepare("SELECT w.name AS name FROM family_members w JOIN family_members t ON w.owner_email=t.owner_email WHERE w.member_email=? AND t.member_email=? AND w.status=''activo'' AND t.status=''activo'' AND w.role<>''amigo'' AND t.role<>''amigo'' AND w.name IS NOT NULL AND w.name<>'''' LIMIT 1")
    .bind(aQuien, porQuien).first<{ name: string }>();
  if (comoMiembro?.name) return comoMiembro.name;
  return aQuien.split("@")[0].replace(/^./, (c) => c.toUpperCase());
}

/** Los avisos que arme `watcher` (los que le llegan a el). */
async function familyAlertsBy(env: Env, watcher: string) {
  const filas = await env.DB.prepare(
    "SELECT id,person_id AS personId,target_name AS targetName,name,latitude,longitude,radius,on_arrive AS onArrive,frequency FROM family_alerts WHERE watcher_email=? ORDER BY created_at",
  ).bind(watcher).all<{ id: string; personId: string; targetName: string; name: string; latitude: number; longitude: number; radius: number; onArrive: number; frequency: string }>();
  return filas.results.map((a) => ({ id: a.id, personId: a.personId, targetName: a.targetName, name: a.name, latitude: a.latitude, longitude: a.longitude, radius: a.radius, onArrive: Boolean(a.onArrive), frequency: a.frequency }));
}

/** La persona (de las que `viewer` ve en su mapa) sobre la que se quiere armar un aviso. */
async function familyAlertTarget(env: Env, viewer: string, personId: string) {
  const persona = (await familyPeopleFor(env, viewer)).find((p) => p.id === personId);
  if (!persona) return null;
  let email: string | null = personId.startsWith("titular:") ? personId.slice("titular:".length) : null;
  if (!email) {
    const fila = await env.DB.prepare("SELECT member_email AS email FROM family_members WHERE id=? AND status=''activo''").bind(personId).first<{ email: string | null }>();
    email = fila?.email ?? null;
  }
  if (!email || email === viewer) return null;
  return { email, name: String(persona.name) };
}'),
    @('src\index.ts', 'crear lugar sin avisar a la familia', '  const cuantos = await env.DB.prepare("SELECT COUNT(*) AS n FROM family_places WHERE owner_email=?").bind(email).first<{ n: number }>();
  if ((cuantos?.n ?? 0) >= PLACE_MAX) return json({ error: "too_many_places" }, 409);
  const id = randomId("lugar");
  await env.DB.prepare("INSERT INTO family_places (id,owner_email,name,latitude,longitude,radius,created_at) VALUES (?,?,?,?,?,?,?)")
    .bind(id, email, name, latitude, longitude, radius, now()).run();
  // Se les avisa a todos los que van a quedar cubiertos por el lugar.
  const integrantes = await env.DB.prepare("SELECT member_email AS memberEmail,owner_name AS ownerName FROM family_members WHERE owner_email=? AND status=''activo'' AND role<>''amigo'' AND member_email IS NOT NULL")
    .bind(email).all<{ memberEmail: string; ownerName: string | null }>();
  for (const integrante of integrantes.results) {
    const quien = integrante.ownerName || email.split("@")[0].replace(/^./, (c) => c.toUpperCase());
    const texto = `${quien} agreg\u00f3 el lugar \u00ab${name}\u00bb a la familia: le llega un aviso cuando lleg\u00e1s o te vas de ah\u00ed.`;
    for (const token of await pushTokensOf(env, integrante.memberEmail)) await sendExpoNotice(token, "Ojo Guard", texto).catch(() => false);
  }
  return json({ created: true, place: { id, name, latitude, longitude, radius, canEdit: true } }, 201);
}', '  const cuantos = await env.DB.prepare("SELECT COUNT(*) AS n FROM family_places WHERE owner_email=?").bind(email).first<{ n: number }>();
  if ((cuantos?.n ?? 0) >= PLACE_MAX) return json({ error: "too_many_places" }, 409);
  const id = randomId("lugar");
  await env.DB.prepare("INSERT INTO family_places (id,owner_email,name,latitude,longitude,radius,created_at) VALUES (?,?,?,?,?,?,?)")
    .bind(id, email, name, latitude, longitude, radius, now()).run();
  return json({ created: true, place: { id, name, latitude, longitude, radius, canEdit: true } }, 201);
}'),
    @('src\index.ts', 'avisos por persona en vez de lugares que avisan', '/**
 * Cada ubicacion nueva de un telefono: si es el telefono de la persona (el mismo que muestra el
 * mapa) y la persona esta en una familia con lugares, se fija si entro o salio de alguno y le
 * avisa al titular. La primera vez solo anota donde esta, sin avisar.
 */
async function familyPlacesCheck(env: Env, deviceId: string, location: Record<string, unknown>) {
  const latitude = Number(location.latitude), longitude = Number(location.longitude), accuracy = Number(location.accuracy);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return;
  if (Number.isFinite(accuracy) && accuracy > PLACE_MAX_ACCURACY) return;
  const device = await env.DB.prepare("SELECT owner_email AS email FROM devices WHERE id=? AND approval_status=''approved''").bind(deviceId).first<{ email: string }>();
  if (!device) return;
  const lugares = await env.DB.prepare(
    "SELECT p.id,p.owner_email AS ownerEmail,p.name,p.latitude,p.longitude,p.radius,f.name AS personName,f.paused_until AS pausedUntil FROM family_places p JOIN family_members f ON f.owner_email=p.owner_email AND f.member_email=? AND f.status=''activo'' AND f.role<>''amigo''",
  ).bind(device.email).all<{ id: string; ownerEmail: string; name: string; latitude: number; longitude: number; radius: number; personName: string; pausedUntil: string | null }>();
  if (!lugares.results.length) return;
  const principal = await env.DB.prepare("SELECT id FROM devices WHERE owner_email=? AND approval_status=''approved'' ORDER BY CASE WHEN device_role=''primary'' THEN 0 ELSE 1 END, COALESCE(last_location_at,'''') DESC LIMIT 1")
    .bind(device.email).first<{ id: string }>();
  if (principal?.id !== deviceId) return;
  const ahora = Date.now();
  for (const lugar of lugares.results) {
    if (lugar.pausedUntil && Date.parse(lugar.pausedUntil) > ahora) continue;
    const distancia = metersBetween({ latitude, longitude }, { latitude: lugar.latitude, longitude: lugar.longitude });
    const previo = await env.DB.prepare("SELECT inside,changed_at AS changedAt FROM family_place_states WHERE place_id=? AND person_email=?")
      .bind(lugar.id, device.email).first<{ inside: number; changedAt: string }>();
    const adentro = previo?.inside ? distancia <= lugar.radius + PLACE_EXIT_MARGIN : distancia <= lugar.radius;
    if (previo && Boolean(previo.inside) === adentro) continue;
    // La primera vez (lugar nuevo) solo se anota donde esta, con una fecha vieja para que el
    // primer cambio de verdad avise aunque pase enseguida.
    await env.DB.prepare("INSERT INTO family_place_states (place_id,person_email,inside,changed_at) VALUES (?,?,?,?) ON CONFLICT(place_id,person_email) DO UPDATE SET inside=excluded.inside,changed_at=excluded.changed_at")
      .bind(lugar.id, device.email, adentro ? 1 : 0, previo ? new Date(ahora).toISOString() : "1970-01-01T00:00:00.000Z").run();
    if (!previo || ahora - Date.parse(previo.changedAt) < PLACE_NOTICE_GAP_MS) continue;
    const texto = `${lugar.personName || device.email.split("@")[0]} ${adentro ? "lleg\u00f3 a" : "sali\u00f3 de"} ${lugar.name}.`;
    for (const token of await pushTokensOf(env, lugar.ownerEmail)) await sendExpoNotice(token, "Ojo Guard", texto).catch(() => false);
  }
}', '// ---------------------------------------------------------------------------
// Avisos de ubicacion por persona (como "Buscar"): cada aviso cuelga de una persona que `watcher`
// ve en su mapa. Cuando esa persona llega o sale del lugar, le llega el aviso a quien lo armo. La
// persona se entera cuando le ponen un aviso (nada oculto). Tabla creada a mano el 11/10/2026:
//   CREATE TABLE IF NOT EXISTS family_alerts (id TEXT PRIMARY KEY, watcher_email TEXT NOT NULL,
//     person_id TEXT NOT NULL, target_email TEXT NOT NULL, target_name TEXT NOT NULL, name TEXT NOT NULL,
//     latitude REAL NOT NULL, longitude REAL NOT NULL, radius INTEGER NOT NULL, on_arrive INTEGER NOT NULL,
//     frequency TEXT NOT NULL, inside INTEGER, last_fired_at TEXT, created_at TEXT NOT NULL);
// ---------------------------------------------------------------------------
async function remoteFamilyAlerts(request: Request, env: Env) {
  const sessionInfo = await readSessionInfo(request, env.SESSION_SECRET);
  if (!sessionInfo) return json({ error: "unauthorized" }, 401);
  const { email } = sessionInfo;
  if (request.method === "GET") return json({ alerts: await familyAlertsBy(env, email) });
  if (sessionInfo.method === "emergency") return json({ error: "not_allowed_in_emergency" }, 403);
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  if (body.action === "delete") {
    const borrado = await env.DB.prepare("DELETE FROM family_alerts WHERE id=? AND watcher_email=?").bind(String(body.id ?? ""), email).run();
    return borrado.meta.changes ? json({ deleted: true }) : json({ error: "not_found" }, 404);
  }
  const target = await familyAlertTarget(env, email, String(body.personId ?? ""));
  if (!target) return json({ error: "not_allowed" }, 403);
  const name = String(body.name ?? "").trim().slice(0, 30);
  const latitude = Number(body.latitude), longitude = Number(body.longitude), radius = Number(body.radius);
  const onArrive = body.onArrive === true;
  const frequency = body.frequency === "always" ? "always" : "once";
  if (!name || !Number.isFinite(latitude) || !Number.isFinite(longitude) || Math.abs(latitude) > 90 || Math.abs(longitude) > 180 || !PLACE_RADII.includes(radius)) {
    return json({ error: "invalid_alert" }, 400);
  }
  const cuantos = await env.DB.prepare("SELECT COUNT(*) AS n FROM family_alerts WHERE watcher_email=?").bind(email).first<{ n: number }>();
  if ((cuantos?.n ?? 0) >= ALERTAS_MAX) return json({ error: "too_many_alerts" }, 409);
  // Estado inicial: donde esta la persona ahora, para que el primer cambio avise bien.
  const dispositivo = await env.DB.prepare("SELECT last_location_json AS loc FROM devices WHERE owner_email=? AND approval_status=''approved'' ORDER BY CASE WHEN device_role=''primary'' THEN 0 ELSE 1 END, COALESCE(last_location_at,'''') DESC LIMIT 1")
    .bind(target.email).first<{ loc: string | null }>();
  let inside: number | null = null;
  try {
    const loc = dispositivo?.loc ? JSON.parse(dispositivo.loc) as Record<string, unknown> : null;
    if (loc && Number.isFinite(Number(loc.latitude)) && Number.isFinite(Number(loc.longitude))) {
      inside = metersBetween({ latitude: Number(loc.latitude), longitude: Number(loc.longitude) }, { latitude, longitude }) <= radius ? 1 : 0;
    }
  } catch { /* sin ubicacion previa: se define con el primer reporte */ }
  const id = randomId("aviso");
  await env.DB.prepare("INSERT INTO family_alerts (id,watcher_email,person_id,target_email,target_name,name,latitude,longitude,radius,on_arrive,frequency,inside,last_fired_at,created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)")
    .bind(id, email, String(body.personId), target.email, target.name, name, latitude, longitude, radius, onArrive ? 1 : 0, frequency, inside, null, now()).run();
  // La persona se entera de que le pusieron un aviso (como en Buscar).
  const comoMeVe = await familyNameSeenBy(env, email, target.email);
  const texto = `${comoMeVe} va a recibir un aviso cuando ${onArrive ? "llegues a" : "salgas de"} ${name}.`;
  for (const token of await pushTokensOf(env, target.email)) await sendExpoNotice(token, "Ojo Guard", texto).catch(() => false);
  return json({ created: true, alert: { id, personId: String(body.personId), targetName: target.name, name, latitude, longitude, radius, onArrive, frequency } }, 201);
}

/**
 * Cada ubicacion nueva del telefono principal de una persona: se fija en los avisos que la vigilan
 * y, si entro o salio de alguno, le avisa a quien lo armo. La primera vez solo anota donde esta.
 */
async function familyAlertsCheck(env: Env, deviceId: string, location: Record<string, unknown>) {
  const latitude = Number(location.latitude), longitude = Number(location.longitude), accuracy = Number(location.accuracy);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return;
  if (Number.isFinite(accuracy) && accuracy > PLACE_MAX_ACCURACY) return;
  const device = await env.DB.prepare("SELECT owner_email AS email FROM devices WHERE id=? AND approval_status=''approved''").bind(deviceId).first<{ email: string }>();
  if (!device) return;
  const avisos = await env.DB.prepare(
    "SELECT id,watcher_email AS watcherEmail,person_id AS personId,target_name AS targetName,name,latitude,longitude,radius,on_arrive AS onArrive,frequency,inside,last_fired_at AS lastFiredAt FROM family_alerts WHERE target_email=?",
  ).bind(device.email).all<{ id: string; watcherEmail: string; personId: string; targetName: string; name: string; latitude: number; longitude: number; radius: number; onArrive: number; frequency: string; inside: number | null; lastFiredAt: string | null }>();
  if (!avisos.results.length) return;
  const principal = await env.DB.prepare("SELECT id FROM devices WHERE owner_email=? AND approval_status=''approved'' ORDER BY CASE WHEN device_role=''primary'' THEN 0 ELSE 1 END, COALESCE(last_location_at,'''') DESC LIMIT 1")
    .bind(device.email).first<{ id: string }>();
  if (principal?.id !== deviceId) return;
  const ahora = Date.now();
  // Con la ubicacion en pausa (adultos y amigos pueden) no se avisa nada.
  const pausa = await env.DB.prepare("SELECT 1 AS p FROM family_members WHERE member_email=? AND status=''activo'' AND paused_until IS NOT NULL AND paused_until>? LIMIT 1")
    .bind(device.email, new Date(ahora).toISOString()).first<{ p: number }>();
  if (pausa) return;
  for (const aviso of avisos.results) {
    const distancia = metersBetween({ latitude, longitude }, { latitude: aviso.latitude, longitude: aviso.longitude });
    const adentro = aviso.inside ? distancia <= aviso.radius + PLACE_EXIT_MARGIN : distancia <= aviso.radius;
    if (aviso.inside !== null && Boolean(aviso.inside) === adentro) continue;
    const primeraVez = aviso.inside === null;
    await env.DB.prepare("UPDATE family_alerts SET inside=? WHERE id=?").bind(adentro ? 1 : 0, aviso.id).run();
    if (primeraVez) continue;
    if (adentro ? !aviso.onArrive : Boolean(aviso.onArrive)) continue;
    if (aviso.lastFiredAt && ahora - Date.parse(aviso.lastFiredAt) < PLACE_NOTICE_GAP_MS) continue;
    // Si la persona ya no esta en la familia de quien armo el aviso (salio o la quitaron), el aviso se borra.
    const sigueVisible = (await familyPeopleFor(env, aviso.watcherEmail)).some((p) => p.id === aviso.personId);
    if (!sigueVisible) { await env.DB.prepare("DELETE FROM family_alerts WHERE id=?").bind(aviso.id).run(); continue; }
    const texto = `${aviso.targetName} ${adentro ? "lleg\u00f3 a" : "sali\u00f3 de"} ${aviso.name}.`;
    for (const token of await pushTokensOf(env, aviso.watcherEmail)) await sendExpoNotice(token, "Ojo Guard", texto).catch(() => false);
    if (aviso.frequency === "once") await env.DB.prepare("DELETE FROM family_alerts WHERE id=?").bind(aviso.id).run();
    else await env.DB.prepare("UPDATE family_alerts SET last_fired_at=? WHERE id=?").bind(new Date(ahora).toISOString(), aviso.id).run();
  }
}'),
    @('src\index.ts', 'avisos en la respuesta de familia', '    places: await familyPlacesFor(env, email).catch(() => []),
  });
', '    places: await familyPlacesFor(env, email).catch(() => []),
    alerts: await familyAlertsBy(env, email).catch(() => []),
  });
'),
    @('src\index.ts', 'revisar avisos (orden)', '    await familyPlacesCheck(env, deviceId, body.location as Record<string, unknown>).catch((error) => console.error("family_places_check_failed", error));
', '    await familyAlertsCheck(env, deviceId, body.location as Record<string, unknown>).catch((error) => console.error("family_alerts_check_failed", error));
'),
    @('src\index.ts', 'revisar avisos (suelta o en vivo)', '    await familyPlacesCheck(env, deviceId, location).catch((error) => console.error("family_places_check_failed", error));
', '    await familyAlertsCheck(env, deviceId, location).catch((error) => console.error("family_alerts_check_failed", error));
'),
    @('src\index.ts', 'ruta de los avisos', '      if (route === "GET /api/remote/family/places" || route === "POST /api/remote/family/places") return remoteFamilyPlaces(request, env);
', '      if (route === "GET /api/remote/family/places" || route === "POST /api/remote/family/places") return remoteFamilyPlaces(request, env);
      if (route === "GET /api/remote/family/alerts" || route === "POST /api/remote/family/alerts") return remoteFamilyAlerts(request, env);
')
)
$cambiosSinDireccion = @(
    @('src\index.ts', 'lugares guardados y helpers de avisos', 'const PLACE_RADII = [100, 200, 300, 500];
const PLACE_MAX = 10;
// Para salir hay que alejarse 50 m mas que el radio: asi un GPS que baila en el borde no
// manda "llego" y "se fue" cada pocos minutos.
const PLACE_EXIT_MARGIN = 50;
// Con una ubicacion tan imprecisa no se decide nada.
const PLACE_MAX_ACCURACY = 300;
// Entre dos avisos del mismo lugar y la misma persona, al menos 5 minutos.
const PLACE_NOTICE_GAP_MS = 5 * 60_000;

/** Los lugares que ve `viewer`: los de su familia y los de las familias donde es adulto o menor. */
async function familyPlacesFor(env: Env, viewer: string) {
  const filas = await env.DB.prepare(
    "SELECT id,owner_email AS ownerEmail,name,latitude,longitude,radius FROM family_places WHERE owner_email=? OR owner_email IN (SELECT owner_email FROM family_members WHERE member_email=? AND status=''activo'' AND role<>''amigo'') ORDER BY created_at",
  ).bind(viewer, viewer).all<{ id: string; ownerEmail: string; name: string; latitude: number; longitude: number; radius: number }>();
  return filas.results.map((p) => ({ id: p.id, name: p.name, latitude: p.latitude, longitude: p.longitude, radius: p.radius, canEdit: p.ownerEmail === viewer }));
}

async function pushTokensOf(env: Env, email: string) {
  const filas = await env.DB.prepare("SELECT DISTINCT push_token AS pushToken FROM devices WHERE owner_email=? AND approval_status=''approved'' AND push_token IS NOT NULL")
    .bind(email).all<{ pushToken: string }>();
  return filas.results.map((f) => f.pushToken);
}', 'const PLACE_RADII = [100, 200, 300, 500];
// Como mucho 20 lugares guardados y 30 avisos por persona.
const PLACE_MAX = 20;
const ALERTAS_MAX = 30;
// Para salir hay que alejarse 50 m mas que el radio: asi un GPS que baila en el borde no
// manda "llego" y "se fue" cada pocos minutos.
const PLACE_EXIT_MARGIN = 50;
// Con una ubicacion tan imprecisa no se decide nada.
const PLACE_MAX_ACCURACY = 300;
// Entre dos avisos del mismo aviso, al menos 5 minutos (para "cada vez").
const PLACE_NOTICE_GAP_MS = 5 * 60_000;

/** Los lugares guardados de `viewer` (atajos propios para armar un aviso rapido). */
async function familyPlacesFor(env: Env, viewer: string) {
  const filas = await env.DB.prepare(
    "SELECT id,name,latitude,longitude,radius FROM family_places WHERE owner_email=? ORDER BY created_at",
  ).bind(viewer).all<{ id: string; name: string; latitude: number; longitude: number; radius: number }>();
  return filas.results.map((p) => ({ id: p.id, name: p.name, latitude: p.latitude, longitude: p.longitude, radius: p.radius, canEdit: true }));
}

async function pushTokensOf(env: Env, email: string) {
  const filas = await env.DB.prepare("SELECT DISTINCT push_token AS pushToken FROM devices WHERE owner_email=? AND approval_status=''approved'' AND push_token IS NOT NULL")
    .bind(email).all<{ pushToken: string }>();
  return filas.results.map((f) => f.pushToken);
}

/** Como ve `porQuien` a `aQuien` (el nombre que le pusieron en la familia), para los avisos. */
async function familyNameSeenBy(env: Env, aQuien: string, porQuien: string) {
  const comoDuenio = await env.DB.prepare("SELECT owner_name AS name FROM family_members WHERE owner_email=? AND member_email=? AND status=''activo'' AND owner_name IS NOT NULL AND owner_name<>'''' LIMIT 1")
    .bind(aQuien, porQuien).first<{ name: string }>();
  if (comoDuenio?.name) return comoDuenio.name;
  const comoMiembro = await env.DB.prepare("SELECT w.name AS name FROM family_members w JOIN family_members t ON w.owner_email=t.owner_email WHERE w.member_email=? AND t.member_email=? AND w.status=''activo'' AND t.status=''activo'' AND w.role<>''amigo'' AND t.role<>''amigo'' AND w.name IS NOT NULL AND w.name<>'''' LIMIT 1")
    .bind(aQuien, porQuien).first<{ name: string }>();
  if (comoMiembro?.name) return comoMiembro.name;
  return aQuien.split("@")[0].replace(/^./, (c) => c.toUpperCase());
}

/** Los avisos que arme `watcher` (los que le llegan a el). */
async function familyAlertsBy(env: Env, watcher: string) {
  const filas = await env.DB.prepare(
    "SELECT id,person_id AS personId,target_name AS targetName,name,latitude,longitude,radius,on_arrive AS onArrive,frequency FROM family_alerts WHERE watcher_email=? ORDER BY created_at",
  ).bind(watcher).all<{ id: string; personId: string; targetName: string; name: string; latitude: number; longitude: number; radius: number; onArrive: number; frequency: string }>();
  return filas.results.map((a) => ({ id: a.id, personId: a.personId, targetName: a.targetName, name: a.name, latitude: a.latitude, longitude: a.longitude, radius: a.radius, onArrive: Boolean(a.onArrive), frequency: a.frequency }));
}

/** La persona (de las que `viewer` ve en su mapa) sobre la que se quiere armar un aviso. */
async function familyAlertTarget(env: Env, viewer: string, personId: string) {
  const persona = (await familyPeopleFor(env, viewer)).find((p) => p.id === personId);
  if (!persona) return null;
  let email: string | null = personId.startsWith("titular:") ? personId.slice("titular:".length) : null;
  if (!email) {
    const fila = await env.DB.prepare("SELECT member_email AS email FROM family_members WHERE id=? AND status=''activo''").bind(personId).first<{ email: string | null }>();
    email = fila?.email ?? null;
  }
  if (!email || email === viewer) return null;
  return { email, name: String(persona.name) };
}'),
    @('src\index.ts', 'crear lugar sin avisar a la familia', '  const cuantos = await env.DB.prepare("SELECT COUNT(*) AS n FROM family_places WHERE owner_email=?").bind(email).first<{ n: number }>();
  if ((cuantos?.n ?? 0) >= PLACE_MAX) return json({ error: "too_many_places" }, 409);
  const id = randomId("lugar");
  await env.DB.prepare("INSERT INTO family_places (id,owner_email,name,latitude,longitude,radius,created_at) VALUES (?,?,?,?,?,?,?)")
    .bind(id, email, name, latitude, longitude, radius, now()).run();
  // Se les avisa a todos los que van a quedar cubiertos por el lugar.
  const integrantes = await env.DB.prepare("SELECT member_email AS memberEmail,owner_name AS ownerName FROM family_members WHERE owner_email=? AND status=''activo'' AND role<>''amigo'' AND member_email IS NOT NULL")
    .bind(email).all<{ memberEmail: string; ownerName: string | null }>();
  for (const integrante of integrantes.results) {
    const quien = integrante.ownerName || email.split("@")[0].replace(/^./, (c) => c.toUpperCase());
    const texto = `${quien} agreg\u00f3 el lugar \u00ab${name}\u00bb a la familia: le llega un aviso cuando lleg\u00e1s o te vas de ah\u00ed.`;
    for (const token of await pushTokensOf(env, integrante.memberEmail)) await sendExpoNotice(token, "Ojo Guard", texto).catch(() => false);
  }
  return json({ created: true, place: { id, name, latitude, longitude, radius, canEdit: true } }, 201);
}', '  const cuantos = await env.DB.prepare("SELECT COUNT(*) AS n FROM family_places WHERE owner_email=?").bind(email).first<{ n: number }>();
  if ((cuantos?.n ?? 0) >= PLACE_MAX) return json({ error: "too_many_places" }, 409);
  const id = randomId("lugar");
  await env.DB.prepare("INSERT INTO family_places (id,owner_email,name,latitude,longitude,radius,created_at) VALUES (?,?,?,?,?,?,?)")
    .bind(id, email, name, latitude, longitude, radius, now()).run();
  return json({ created: true, place: { id, name, latitude, longitude, radius, canEdit: true } }, 201);
}'),
    @('src\index.ts', 'avisos por persona en vez de lugares que avisan', '/**
 * Cada ubicacion nueva de un telefono: si es el telefono de la persona (el mismo que muestra el
 * mapa) y la persona esta en una familia con lugares, se fija si entro o salio de alguno y le
 * avisa al titular. La primera vez solo anota donde esta, sin avisar.
 */
async function familyPlacesCheck(env: Env, deviceId: string, location: Record<string, unknown>) {
  const latitude = Number(location.latitude), longitude = Number(location.longitude), accuracy = Number(location.accuracy);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return;
  if (Number.isFinite(accuracy) && accuracy > PLACE_MAX_ACCURACY) return;
  const device = await env.DB.prepare("SELECT owner_email AS email FROM devices WHERE id=? AND approval_status=''approved''").bind(deviceId).first<{ email: string }>();
  if (!device) return;
  const lugares = await env.DB.prepare(
    "SELECT p.id,p.owner_email AS ownerEmail,p.name,p.latitude,p.longitude,p.radius,f.name AS personName,f.paused_until AS pausedUntil FROM family_places p JOIN family_members f ON f.owner_email=p.owner_email AND f.member_email=? AND f.status=''activo'' AND f.role<>''amigo''",
  ).bind(device.email).all<{ id: string; ownerEmail: string; name: string; latitude: number; longitude: number; radius: number; personName: string; pausedUntil: string | null }>();
  if (!lugares.results.length) return;
  const principal = await env.DB.prepare("SELECT id FROM devices WHERE owner_email=? AND approval_status=''approved'' ORDER BY CASE WHEN device_role=''primary'' THEN 0 ELSE 1 END, COALESCE(last_location_at,'''') DESC LIMIT 1")
    .bind(device.email).first<{ id: string }>();
  if (principal?.id !== deviceId) return;
  const ahora = Date.now();
  for (const lugar of lugares.results) {
    if (lugar.pausedUntil && Date.parse(lugar.pausedUntil) > ahora) continue;
    const distancia = metersBetween({ latitude, longitude }, { latitude: lugar.latitude, longitude: lugar.longitude });
    const previo = await env.DB.prepare("SELECT inside,changed_at AS changedAt FROM family_place_states WHERE place_id=? AND person_email=?")
      .bind(lugar.id, device.email).first<{ inside: number; changedAt: string }>();
    const adentro = previo?.inside ? distancia <= lugar.radius + PLACE_EXIT_MARGIN : distancia <= lugar.radius;
    if (previo && Boolean(previo.inside) === adentro) continue;
    // La primera vez (lugar nuevo) solo se anota donde esta, con una fecha vieja para que el
    // primer cambio de verdad avise aunque pase enseguida.
    await env.DB.prepare("INSERT INTO family_place_states (place_id,person_email,inside,changed_at) VALUES (?,?,?,?) ON CONFLICT(place_id,person_email) DO UPDATE SET inside=excluded.inside,changed_at=excluded.changed_at")
      .bind(lugar.id, device.email, adentro ? 1 : 0, previo ? new Date(ahora).toISOString() : "1970-01-01T00:00:00.000Z").run();
    if (!previo || ahora - Date.parse(previo.changedAt) < PLACE_NOTICE_GAP_MS) continue;
    const texto = `${lugar.personName || device.email.split("@")[0]} ${adentro ? "lleg\u00f3 a" : "sali\u00f3 de"} ${lugar.name}.`;
    for (const token of await pushTokensOf(env, lugar.ownerEmail)) await sendExpoNotice(token, "Ojo Guard", texto).catch(() => false);
  }
}', '// ---------------------------------------------------------------------------
// Avisos de ubicacion por persona (como "Buscar"): cada aviso cuelga de una persona que `watcher`
// ve en su mapa. Cuando esa persona llega o sale del lugar, le llega el aviso a quien lo armo. La
// persona se entera cuando le ponen un aviso (nada oculto). Tabla creada a mano el 11/10/2026:
//   CREATE TABLE IF NOT EXISTS family_alerts (id TEXT PRIMARY KEY, watcher_email TEXT NOT NULL,
//     person_id TEXT NOT NULL, target_email TEXT NOT NULL, target_name TEXT NOT NULL, name TEXT NOT NULL,
//     latitude REAL NOT NULL, longitude REAL NOT NULL, radius INTEGER NOT NULL, on_arrive INTEGER NOT NULL,
//     frequency TEXT NOT NULL, inside INTEGER, last_fired_at TEXT, created_at TEXT NOT NULL);
// ---------------------------------------------------------------------------
async function remoteFamilyAlerts(request: Request, env: Env) {
  const sessionInfo = await readSessionInfo(request, env.SESSION_SECRET);
  if (!sessionInfo) return json({ error: "unauthorized" }, 401);
  const { email } = sessionInfo;
  if (request.method === "GET") return json({ alerts: await familyAlertsBy(env, email) });
  if (sessionInfo.method === "emergency") return json({ error: "not_allowed_in_emergency" }, 403);
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  if (body.action === "delete") {
    const borrado = await env.DB.prepare("DELETE FROM family_alerts WHERE id=? AND watcher_email=?").bind(String(body.id ?? ""), email).run();
    return borrado.meta.changes ? json({ deleted: true }) : json({ error: "not_found" }, 404);
  }
  const target = await familyAlertTarget(env, email, String(body.personId ?? ""));
  if (!target) return json({ error: "not_allowed" }, 403);
  const name = String(body.name ?? "").trim().slice(0, 30);
  const latitude = Number(body.latitude), longitude = Number(body.longitude), radius = Number(body.radius);
  const onArrive = body.onArrive === true;
  const frequency = body.frequency === "always" ? "always" : "once";
  if (!name || !Number.isFinite(latitude) || !Number.isFinite(longitude) || Math.abs(latitude) > 90 || Math.abs(longitude) > 180 || !PLACE_RADII.includes(radius)) {
    return json({ error: "invalid_alert" }, 400);
  }
  const cuantos = await env.DB.prepare("SELECT COUNT(*) AS n FROM family_alerts WHERE watcher_email=?").bind(email).first<{ n: number }>();
  if ((cuantos?.n ?? 0) >= ALERTAS_MAX) return json({ error: "too_many_alerts" }, 409);
  // Estado inicial: donde esta la persona ahora, para que el primer cambio avise bien.
  const dispositivo = await env.DB.prepare("SELECT last_location_json AS loc FROM devices WHERE owner_email=? AND approval_status=''approved'' ORDER BY CASE WHEN device_role=''primary'' THEN 0 ELSE 1 END, COALESCE(last_location_at,'''') DESC LIMIT 1")
    .bind(target.email).first<{ loc: string | null }>();
  let inside: number | null = null;
  try {
    const loc = dispositivo?.loc ? JSON.parse(dispositivo.loc) as Record<string, unknown> : null;
    if (loc && Number.isFinite(Number(loc.latitude)) && Number.isFinite(Number(loc.longitude))) {
      inside = metersBetween({ latitude: Number(loc.latitude), longitude: Number(loc.longitude) }, { latitude, longitude }) <= radius ? 1 : 0;
    }
  } catch { /* sin ubicacion previa: se define con el primer reporte */ }
  const id = randomId("aviso");
  await env.DB.prepare("INSERT INTO family_alerts (id,watcher_email,person_id,target_email,target_name,name,latitude,longitude,radius,on_arrive,frequency,inside,last_fired_at,created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)")
    .bind(id, email, String(body.personId), target.email, target.name, name, latitude, longitude, radius, onArrive ? 1 : 0, frequency, inside, null, now()).run();
  // La persona se entera de que le pusieron un aviso (como en Buscar).
  const comoMeVe = await familyNameSeenBy(env, email, target.email);
  const texto = `${comoMeVe} va a recibir un aviso cuando ${onArrive ? "llegues a" : "salgas de"} ${name}.`;
  for (const token of await pushTokensOf(env, target.email)) await sendExpoNotice(token, "Ojo Guard", texto).catch(() => false);
  return json({ created: true, alert: { id, personId: String(body.personId), targetName: target.name, name, latitude, longitude, radius, onArrive, frequency } }, 201);
}

/**
 * Cada ubicacion nueva del telefono principal de una persona: se fija en los avisos que la vigilan
 * y, si entro o salio de alguno, le avisa a quien lo armo. La primera vez solo anota donde esta.
 */
async function familyAlertsCheck(env: Env, deviceId: string, location: Record<string, unknown>) {
  const latitude = Number(location.latitude), longitude = Number(location.longitude), accuracy = Number(location.accuracy);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return;
  if (Number.isFinite(accuracy) && accuracy > PLACE_MAX_ACCURACY) return;
  const device = await env.DB.prepare("SELECT owner_email AS email FROM devices WHERE id=? AND approval_status=''approved''").bind(deviceId).first<{ email: string }>();
  if (!device) return;
  const avisos = await env.DB.prepare(
    "SELECT id,watcher_email AS watcherEmail,person_id AS personId,target_name AS targetName,name,latitude,longitude,radius,on_arrive AS onArrive,frequency,inside,last_fired_at AS lastFiredAt FROM family_alerts WHERE target_email=?",
  ).bind(device.email).all<{ id: string; watcherEmail: string; personId: string; targetName: string; name: string; latitude: number; longitude: number; radius: number; onArrive: number; frequency: string; inside: number | null; lastFiredAt: string | null }>();
  if (!avisos.results.length) return;
  const principal = await env.DB.prepare("SELECT id FROM devices WHERE owner_email=? AND approval_status=''approved'' ORDER BY CASE WHEN device_role=''primary'' THEN 0 ELSE 1 END, COALESCE(last_location_at,'''') DESC LIMIT 1")
    .bind(device.email).first<{ id: string }>();
  if (principal?.id !== deviceId) return;
  const ahora = Date.now();
  // Con la ubicacion en pausa (adultos y amigos pueden) no se avisa nada.
  const pausa = await env.DB.prepare("SELECT 1 AS p FROM family_members WHERE member_email=? AND status=''activo'' AND paused_until IS NOT NULL AND paused_until>? LIMIT 1")
    .bind(device.email, new Date(ahora).toISOString()).first<{ p: number }>();
  if (pausa) return;
  for (const aviso of avisos.results) {
    const distancia = metersBetween({ latitude, longitude }, { latitude: aviso.latitude, longitude: aviso.longitude });
    const adentro = aviso.inside ? distancia <= aviso.radius + PLACE_EXIT_MARGIN : distancia <= aviso.radius;
    if (aviso.inside !== null && Boolean(aviso.inside) === adentro) continue;
    const primeraVez = aviso.inside === null;
    await env.DB.prepare("UPDATE family_alerts SET inside=? WHERE id=?").bind(adentro ? 1 : 0, aviso.id).run();
    if (primeraVez) continue;
    if (adentro ? !aviso.onArrive : Boolean(aviso.onArrive)) continue;
    if (aviso.lastFiredAt && ahora - Date.parse(aviso.lastFiredAt) < PLACE_NOTICE_GAP_MS) continue;
    // Si la persona ya no esta en la familia de quien armo el aviso (salio o la quitaron), el aviso se borra.
    const sigueVisible = (await familyPeopleFor(env, aviso.watcherEmail)).some((p) => p.id === aviso.personId);
    if (!sigueVisible) { await env.DB.prepare("DELETE FROM family_alerts WHERE id=?").bind(aviso.id).run(); continue; }
    const texto = `${aviso.targetName} ${adentro ? "lleg\u00f3 a" : "sali\u00f3 de"} ${aviso.name}.`;
    for (const token of await pushTokensOf(env, aviso.watcherEmail)) await sendExpoNotice(token, "Ojo Guard", texto).catch(() => false);
    if (aviso.frequency === "once") await env.DB.prepare("DELETE FROM family_alerts WHERE id=?").bind(aviso.id).run();
    else await env.DB.prepare("UPDATE family_alerts SET last_fired_at=? WHERE id=?").bind(new Date(ahora).toISOString(), aviso.id).run();
  }
}'),
    @('src\index.ts', 'avisos en la respuesta de familia', '    places: await familyPlacesFor(env, email).catch(() => []),
  });
', '    places: await familyPlacesFor(env, email).catch(() => []),
    alerts: await familyAlertsBy(env, email).catch(() => []),
  });
'),
    @('src\index.ts', 'revisar avisos (orden)', '    await familyPlacesCheck(env, deviceId, body.location as Record<string, unknown>).catch((error) => console.error("family_places_check_failed", error));
', '    await familyAlertsCheck(env, deviceId, body.location as Record<string, unknown>).catch((error) => console.error("family_alerts_check_failed", error));
'),
    @('src\index.ts', 'revisar avisos (suelta o en vivo)', '    await familyPlacesCheck(env, deviceId, location).catch((error) => console.error("family_places_check_failed", error));
', '    await familyAlertsCheck(env, deviceId, location).catch((error) => console.error("family_alerts_check_failed", error));
'),
    @('src\index.ts', 'direccion de un punto', '/** Crear o quitar un lugar de tu familia (solo el titular). */
', '/** Calle y altura de un punto (OpenStreetMap), para elegir un lugar justo en el mapa. Solo con sesion. */
async function remoteAddress(request: Request, env: Env, url: URL) {
  const sessionInfo = await readSessionInfo(request, env.SESSION_SECRET);
  if (!sessionInfo) return json({ error: "unauthorized" }, 401);
  const lat = Number(url.searchParams.get("lat")), lng = Number(url.searchParams.get("lng"));
  if (!Number.isFinite(lat) || !Number.isFinite(lng) || Math.abs(lat) > 90 || Math.abs(lng) > 180) return json({ error: "invalid_point" }, 400);
  try {
    // La misma fuente que usa la notebook (ojo_guard_compu.py). Pide identificarse con un User-Agent.
    const respuesta = await fetch(`https://nominatim.openstreetmap.org/reverse?format=jsonv2&zoom=18&addressdetails=1&accept-language=es&lat=${lat.toFixed(6)}&lon=${lng.toFixed(6)}`, {
      headers: { "user-agent": "OjoGuardMS/1.0 (soporte@ojoguard.app)" },
    });
    if (!respuesta.ok) return json({ address: null });
    const datos = await respuesta.json<{ address?: Record<string, string>; display_name?: string }>();
    const a = datos.address ?? {};
    const calle = [a.road || a.pedestrian || a.footway, a.house_number].filter(Boolean).join(" ");
    const barrio = a.suburb || a.neighbourhood || a.city_district || a.city || a.town || "";
    return json({ address: [calle, barrio].filter(Boolean).join(", ") || datos.display_name || null });
  } catch {
    return json({ address: null });
  }
}

/** Crear o quitar un lugar de tu familia (solo el titular). */
'),
    @('src\index.ts', 'ruta de los avisos y de la direccion', '      if (route === "GET /api/remote/family/places" || route === "POST /api/remote/family/places") return remoteFamilyPlaces(request, env);
', '      if (route === "GET /api/remote/family/places" || route === "POST /api/remote/family/places") return remoteFamilyPlaces(request, env);
      if (route === "GET /api/remote/address") return remoteAddress(request, env, url);
      if (route === "GET /api/remote/family/alerts" || route === "POST /api/remote/family/alerts") return remoteFamilyAlerts(request, env);
')
)
if ((Contar $indexTexto 'async function remoteAddress') -ne 0) { Ok "La calle y la altura ya estaban: sumo solo los avisos"; $cambios = $cambiosConDireccion } else { $cambios = $cambiosSinDireccion }
$descargas = @(
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/d91d854/scripts/mapa/panel-mapa.txt", "src\panel-mapa.txt", "2b3025a7e441b75a7896864f7da7e8e53bc582ed47eab4160bfe5a64705a295a"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/d91d854/scripts/mapa/panel-mapa.css", "src\panel-mapa.css", "c768dab8db16af6ee4feb497694ee6cd2b41d8d8a65d663710258fcf4942fcac")
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
    if (Test-Path ($ruta + ".bak-avisospersona")) { Mal ("Ya existe " + $t + ".bak-avisospersona. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-avisospersona"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-avisospersona): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-avisospersona") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "TODO BIEN en los archivos. Faltan dos pasos, en este orden:"
Write-Host "  1) npx.cmd wrangler d1 execute ojo-guard-ms --remote --command ""CREATE TABLE IF NOT EXISTS family_alerts (id TEXT PRIMARY KEY, watcher_email TEXT NOT NULL, person_id TEXT NOT NULL, target_email TEXT NOT NULL, target_name TEXT NOT NULL, name TEXT NOT NULL, latitude REAL NOT NULL, longitude REAL NOT NULL, radius INTEGER NOT NULL, on_arrive INTEGER NOT NULL, frequency TEXT NOT NULL, inside INTEGER, last_fired_at TEXT, created_at TEXT NOT NULL);"""
Write-Host "  2) npx.cmd wrangler deploy"
Write-Host ""
