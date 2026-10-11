# aplicar-familia-lugares.ps1 - Familia, etapa B: lugares. El titular marca Casa, Colegio, etc. en el mapa del panel
# y le llega un aviso al telefono cuando alguien de su familia llega o se va. Los de la familia ven los lugares y
# reciben un aviso cuando se crea uno. Va en la carpeta del PANEL (la que tiene wrangler.toml). Toca src\index.ts y
# actualiza src\panel-mapa.txt y src\panel-mapa.css. Respaldos .bak-lugares. Base de datos: dos tablas nuevas.
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
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'async function familyPlacesCheck') -ne 0) { Avi "Los lugares ya estaban aplicados. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'async function familyEvidenceMail') -eq 0) { Mal "Primero corre aplicar-menores-evidencia.ps1."; return }
if ((Sha (Join-Path $raiz "src\panel-mapa.txt")) -ne "d4131d6b0569b21037f6e26e5fba2382b8e758fdbdd142fc2b94ce621666c2bb") { Mal "src\panel-mapa.txt no es la version que espero. Primero corre aplicar-menores-evidencia.ps1."; return }
$cambios = @(
    @('src\index.ts', 'lugares: funciones', '/** Pagina que abre el link de invitacion (WhatsApp, mail): muestra el codigo y como usarlo. */
', '// ---------------------------------------------------------------------------
// Familia, etapa B: lugares. El titular marca lugares (Casa, Colegio) en el mapa del panel y le
// llega un aviso al telefono cuando alguien de su familia (adultos y menores; los amigos no)
// llega o se va. Todos los de la familia ven los lugares en su mapa y reciben un aviso cuando se
// crea uno: nadie queda vigilado sin saberlo. Tablas creadas a mano el 11/10/2026:
//   CREATE TABLE IF NOT EXISTS family_places (id TEXT PRIMARY KEY, owner_email TEXT NOT NULL,
//     name TEXT NOT NULL, latitude REAL NOT NULL, longitude REAL NOT NULL, radius INTEGER NOT NULL,
//     created_at TEXT NOT NULL);
//   CREATE TABLE IF NOT EXISTS family_place_states (place_id TEXT NOT NULL, person_email TEXT NOT NULL,
//     inside INTEGER NOT NULL, changed_at TEXT NOT NULL, PRIMARY KEY (place_id, person_email));
// ---------------------------------------------------------------------------
const PLACE_RADII = [100, 200, 300, 500];
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
}

/** Crear o quitar un lugar de tu familia (solo el titular). */
async function remoteFamilyPlaces(request: Request, env: Env) {
  const sessionInfo = await readSessionInfo(request, env.SESSION_SECRET);
  if (!sessionInfo) return json({ error: "unauthorized" }, 401);
  const { email } = sessionInfo;
  if (request.method === "GET") return json({ places: await familyPlacesFor(env, email) });
  if (sessionInfo.method === "emergency") return json({ error: "not_allowed_in_emergency" }, 403);
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  if (body.action === "delete") {
    const id = String(body.id ?? "");
    const borrado = await env.DB.prepare("DELETE FROM family_places WHERE id=? AND owner_email=?").bind(id, email).run();
    if (!borrado.meta.changes) return json({ error: "not_found" }, 404);
    await env.DB.prepare("DELETE FROM family_place_states WHERE place_id=?").bind(id).run();
    return json({ deleted: true });
  }
  const name = String(body.name ?? "").trim().slice(0, 30);
  const latitude = Number(body.latitude), longitude = Number(body.longitude), radius = Number(body.radius);
  if (!name || !Number.isFinite(latitude) || !Number.isFinite(longitude) || Math.abs(latitude) > 90 || Math.abs(longitude) > 180 || !PLACE_RADII.includes(radius)) {
    return json({ error: "invalid_place" }, 400);
  }
  const cuantos = await env.DB.prepare("SELECT COUNT(*) AS n FROM family_places WHERE owner_email=?").bind(email).first<{ n: number }>();
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
}

/**
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
}

/** Pagina que abre el link de invitacion (WhatsApp, mail): muestra el codigo y como usarlo. */
'),
    @('src\index.ts', 'lugares en el mapa del panel', '    ownerName: ultimo?.ownerName ?? "",
  });
', '    ownerName: ultimo?.ownerName ?? "",
    // Sin las tablas de lugares todavia, el mapa sigue andando sin ellos.
    places: await familyPlacesFor(env, email).catch(() => []),
  });
'),
    @('src\index.ts', 'lugares para la app', '    people: await familyPeopleFor(env, email),
', '    people: await familyPeopleFor(env, email),
    places: await familyPlacesFor(env, email).catch(() => []),
'),
    @('src\index.ts', 'ruta de los lugares', '      if (route === "POST /api/remote/family/leave") return remoteFamilyLeave(request, env);
', '      if (route === "POST /api/remote/family/leave") return remoteFamilyLeave(request, env);
      if (route === "GET /api/remote/family/places" || route === "POST /api/remote/family/places") return remoteFamilyPlaces(request, env);
'),
    @('src\index.ts', 'revisar lugares (ubicacion de una orden)', '    ).bind(JSON.stringify(body.location), now(), now(), deviceId).run();
', '    ).bind(JSON.stringify(body.location), now(), now(), deviceId).run();
    await familyPlacesCheck(env, deviceId, body.location as Record<string, unknown>).catch((error) => console.error("family_places_check_failed", error));
'),
    @('src\index.ts', 'revisar lugares (ubicacion suelta o en vivo)', '    await env.DB.prepare("UPDATE devices SET last_location_json=?,last_location_at=?,last_seen_at=? WHERE id=?")
      .bind(JSON.stringify(location), ahora, ahora, deviceId).run();
', '    await env.DB.prepare("UPDATE devices SET last_location_json=?,last_location_at=?,last_seen_at=? WHERE id=?")
      .bind(JSON.stringify(location), ahora, ahora, deviceId).run();
    await familyPlacesCheck(env, deviceId, location).catch((error) => console.error("family_places_check_failed", error));
')
)
$descargas = @(
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/cfd56be/scripts/mapa/panel-mapa.txt", "src\panel-mapa.txt", "68c2984532b4e87b55c66023f0027c9e9506a8a2b000e2e7b0ab0fb50f3dc4a6"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/cfd56be/scripts/mapa/panel-mapa.css", "src\panel-mapa.css", "29361d649c7399bd4af22cdc6adedbc6742685429d487d616dc9a21e8a96882e")
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
    if (Test-Path ($ruta + ".bak-lugares")) { Mal ("Ya existe " + $t + ".bak-lugares. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-lugares"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-lugares): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-lugares") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "TODO BIEN en los archivos. Faltan dos pasos, en este orden:"
Write-Host "  1) npx.cmd wrangler d1 execute ojo-guard-ms --remote --command ""CREATE TABLE IF NOT EXISTS family_places (id TEXT PRIMARY KEY, owner_email TEXT NOT NULL, name TEXT NOT NULL, latitude REAL NOT NULL, longitude REAL NOT NULL, radius INTEGER NOT NULL, created_at TEXT NOT NULL); CREATE TABLE IF NOT EXISTS family_place_states (place_id TEXT NOT NULL, person_email TEXT NOT NULL, inside INTEGER NOT NULL, changed_at TEXT NOT NULL, PRIMARY KEY (place_id, person_email));"""
Write-Host "  2) npx.cmd wrangler deploy"
Write-Host ""
