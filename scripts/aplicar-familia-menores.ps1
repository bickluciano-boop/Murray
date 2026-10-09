# aplicar-familia-menores.ps1 - Familia, menores (parte 1): el titular y los adultos de la familia pueden Ubicar ahora,
# Hacer sonar y Seguir en vivo el telefono de un MENOR desde el mapa. El menor recibe un aviso con el nombre de quien lo pidio.
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Toca src\index.ts y actualiza el mapa. Respaldos .bak-menores; si algo falla, se restaura todo.
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
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'async function remoteFamilyCommand') -ne 0) { Avi "Lo de menores ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'miRol.get(r.ownerEmail)') -eq 0) { Mal "Primero corre aplicar-familia-amigo.ps1 (y aplicar-familia-nombre.ps1 si tampoco lo corriste)."; return }
$cambios = @(
    @('src\index.ts', 'familia: quien es tutor', '  }
  type Persona = { id: string; email: string; name: string; role: string; pausedUntil: string | null; owner: boolean };
  const personas = new Map<string, Persona>();', '  }
  // tutor: `viewer` puede ubicar, hacer sonar y seguir en vivo a esta persona (es un
  // menor de una familia donde `viewer` es el titular o un adulto).
  type Persona = { id: string; email: string; name: string; role: string; pausedUntil: string | null; owner: boolean; tutor: boolean };
  const personas = new Map<string, Persona>();'),
    @('src\index.ts', 'familia: tutor de un menor', '    if (seVen && r.memberEmail && r.memberEmail !== viewer && !personas.has(r.memberEmail)) {
      personas.set(r.memberEmail, { id: r.id, email: r.memberEmail, name: r.name, role: r.role, pausedUntil: r.pausedUntil, owner: false });
    }', '    if (seVen && r.memberEmail && r.memberEmail !== viewer && !personas.has(r.memberEmail)) {
      const tutor = r.role === "menor" && (r.ownerEmail === viewer || miRol.get(r.ownerEmail) === "adulto");
      personas.set(r.memberEmail, { id: r.id, email: r.memberEmail, name: r.name, role: r.role, pausedUntil: r.pausedUntil, owner: false, tutor });
    }'),
    @('src\index.ts', 'familia: el titular no es tutor', '      // ninguno, mas abajo se usa el de su correo).
      personas.set(r.ownerEmail, { id: `titular:${r.ownerEmail}`, email: r.ownerEmail, name: nombreDelTitular.get(r.ownerEmail) ?? "", role: "adulto", pausedUntil: null, owner: true });
    }', '      // ninguno, mas abajo se usa el de su correo).
      personas.set(r.ownerEmail, { id: `titular:${r.ownerEmail}`, email: r.ownerEmail, name: nombreDelTitular.get(r.ownerEmail) ?? "", role: "adulto", pausedUntil: null, owner: true, tutor: false });
    }'),
    @('src\index.ts', 'familia: avisar al panel', '      owner: p.owner,
      paused,', '      owner: p.owner,
      canCommand: p.tutor,
      platform: device?.platform ?? null,
      paused,'),
    @('src\index.ts', 'familia: ordenes a menores', '
const HISTORY_EMAIL_POINT_COUNT = 10;', '
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
    "SELECT owner_email AS ownerEmail,member_email AS memberEmail,owner_name AS ownerName FROM family_members WHERE id=? AND status=''activo'' AND role=''menor''",
  ).bind(personId).first<{ ownerEmail: string; memberEmail: string | null; ownerName: string | null }>();
  if (!fila?.memberEmail || fila.memberEmail === viewer) return null;
  let quien = "";
  if (fila.ownerEmail === viewer) {
    quien = fila.ownerName || "";
  } else {
    const adulto = await env.DB.prepare("SELECT name FROM family_members WHERE owner_email=? AND member_email=? AND status=''activo'' AND role=''adulto''")
      .bind(fila.ownerEmail, viewer).first<{ name: string }>();
    if (!adulto) return null;
    quien = adulto.name;
  }
  // El mismo telefono que muestra el mapa (ver familyPeopleFor).
  const device = await env.DB.prepare(
    "SELECT id,name,push_token AS pushToken FROM devices WHERE owner_email=? AND approval_status=''approved'' ORDER BY CASE WHEN device_role=''primary'' THEN 0 ELSE 1 END, COALESCE(last_location_at,'''') DESC LIMIT 1",
  ).bind(fila.memberEmail).first<{ id: string; name: string; pushToken: string | null }>();
  if (!device) return null;
  return { minorEmail: fila.memberEmail, device, quien: quien || viewer.split("@")[0].replace(/^./, (c) => c.toUpperCase()) };
}

/** Si `viewer` es tutor del menor duenio de la orden (para consultar como va). */
async function familyIsTutorOf(env: Env, viewer: string, minorEmail: string) {
  const fila = await env.DB.prepare(
    "SELECT 1 AS ok FROM family_members f WHERE f.member_email=? AND f.status=''activo'' AND f.role=''menor'' AND (f.owner_email=? OR f.owner_email IN (SELECT owner_email FROM family_members WHERE member_email=? AND status=''activo'' AND role=''adulto'')) LIMIT 1",
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
      await env.DB.prepare("UPDATE commands SET status=''failed'',failed_at=?,error=''location_timeout'' WHERE id=? AND status IN (''pending'',''received'')").bind(failedAt, id).run();
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
    await env.DB.prepare("UPDATE commands SET status=''failed'', failed_at=?, error=''cancelada_por_orden_opuesta'' WHERE device_id=? AND status IN (''pending'',''received'') AND type=''alarm''")
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
    await env.DB.prepare("UPDATE commands SET expires_at=? WHERE device_id=? AND type=''live'' AND expires_at>?").bind(ahora, deviceId, ahora).run();
    return json({ live: false });
  }
  const until = plusMinutes(LIVE_MINUTES);
  const activa = await env.DB.prepare("SELECT id,status FROM commands WHERE device_id=? AND type=''live'' AND status<>''failed'' AND expires_at>? ORDER BY created_at DESC LIMIT 1")
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

const HISTORY_EMAIL_POINT_COUNT = 10;'),
    @('src\index.ts', 'push: aviso propio (1)', '  commandId: string,
  deviceName: string,
) {
  if (!pushToken || !/^(ExponentPushToken|ExpoPushToken)\[.+\]$/.test(pushToken)) return false;', '  commandId: string,
  deviceName: string,
  aviso?: { title: string; body: string },
) {
  if (!pushToken || !/^(ExponentPushToken|ExpoPushToken)\[.+\]$/.test(pushToken)) return false;'),
    @('src\index.ts', 'push: aviso propio (2)', '  if (type !== "auto-locate" && type !== "live") {
    messages.push({
      to: pushToken,
      title: message.title,
      body: message.body,', '  // `aviso`: texto propio para el aviso visible (Familia: "Luciano pidio tu ubicacion"),
  // que ademas sale aunque la orden sea de las que normalmente no muestran nada.
  if (aviso || (type !== "auto-locate" && type !== "live")) {
    messages.push({
      to: pushToken,
      title: aviso?.title ?? message.title,
      body: aviso?.body ?? message.body,'),
    @('src\index.ts', 'rutas de menores', '      if (route === "POST /api/remote/family/remove") return remoteFamilyRemove(request, env);', '      if (route === "POST /api/remote/family/remove") return remoteFamilyRemove(request, env);
      if (route === "GET /api/remote/family/command" || route === "POST /api/remote/family/command") return remoteFamilyCommand(request, env, url);
      if (route === "POST /api/remote/family/live") return remoteFamilyLive(request, env);')
)
$descargas = @(
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/3571e4d/scripts/mapa/panel-mapa.txt", "src\panel-mapa.txt", "a48633c49c40c5fe7424f9119e668417c6f94be9aa992b619be3b6f7310a12ed"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/3571e4d/scripts/mapa/panel-mapa.css", "src\panel-mapa.css", "9b15fc26cae5170f820a37cfc4c423b8f01ff32bd12d23c564dad00917f429e2")
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
    if (Test-Path ($ruta + ".bak-menores")) { Mal ("Ya existe " + $t + ".bak-menores. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-menores"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-menores): " + ($respaldados -join ", "))

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
$vi = (Leer (Join-Path $raiz "src\index.ts")).texto
Chk "index.ts: familia, en vivo y mapa siguen" (((Contar $vi 'async function remoteFamily(') -eq 1) -and ((Contar $vi 'async function remoteLive') -eq 1) -and ((Contar $vi 'panel-mapa.txt') -eq 1))

if (-not $todoBien) {
    Mal "Algo no salio bien. Restauro todo desde los respaldos."
    foreach ($t in $tocados) {
        $ruta = Join-Path $raiz $t
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-menores") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "TODO BIEN en los archivos. Falta publicar:  npx.cmd wrangler deploy"
Write-Host ""
