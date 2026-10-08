# aplicar-familia-panel.ps1 - Familia y amigos, etapa A (servidor y panel): invitar con un codigo y ver a la familia en el mapa
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Agrega migrations\0016_familia.sql (la tabla nueva),
# las rutas de familia en src\index.ts y la version nueva del mapa. Respaldos .bak-familia; si algo falla, se restaura todo.
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
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'async function remoteLive') -eq 0) { Mal "Falta el modo en vivo: primero corre aplicar-en-vivo-panel.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'async function remoteFamily(') -ne 0) { Avi "Familia ya estaba aplicada en el servidor. No toco nada."; return }
New-Item -ItemType Directory -Force -Path (Join-Path $raiz "migrations") | Out-Null
$cambios = @(
    @('src\index.ts', 'rutas de familia', '      if (route === "POST /api/remote/live") return remoteLive(request, env);', '      if (route === "POST /api/remote/live") return remoteLive(request, env);
      if (route === "GET /api/remote/family") return remoteFamily(request, env);
      if (route === "POST /api/remote/family/invite") return remoteFamilyInvite(request, env);
      if (route === "POST /api/remote/family/remove") return remoteFamilyRemove(request, env);
      if (route === "GET /api/native/family") return nativeFamily(request, env, url);
      if (route === "POST /api/native/family/join") return nativeFamilyJoin(request, env);
      if (route === "POST /api/native/family/pause") return nativeFamilyPause(request, env);'),
    @('src\index.ts', 'pagina de invitacion', '      if (route === "GET /marca/logo-correo.png") return logoCorreoResponse();', '      if (route === "GET /marca/logo-correo.png") return logoCorreoResponse();
      if (route === "GET /unirme") return familyJoinPage(url);'),
    @('src\index.ts', 'funciones de familia', 'const HISTORY_EMAIL_POINT_COUNT = 10;', '// ---------------------------------------------------------------------------
// Familia y amigos (etapa A): invitar con un codigo y ver a la familia en el mapa.
// Una "familia" es el titular (owner_email) mas las personas activas que invito.
// Todos los de una misma familia se ven entre si. Los menores no pueden pausar
// su ubicacion; adultos y amigos si.
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
 * integrante activo, mas los titulares de esas familias. Para cada una se toma la
 * ultima ubicacion de su telefono principal (o del equipo mas reciente).
 */
async function familyPeopleFor(env: Env, viewer: string) {
  const rows = await env.DB.prepare(
    "SELECT f.id,f.owner_email AS ownerEmail,f.member_email AS memberEmail,f.name,f.role,f.paused_until AS pausedUntil FROM family_members f WHERE f.status=''activo'' AND (f.owner_email=? OR f.owner_email IN (SELECT owner_email FROM family_members WHERE member_email=? AND status=''activo''))",
  ).bind(viewer, viewer).all<{ id: string; ownerEmail: string; memberEmail: string; name: string; role: string; pausedUntil: string | null }>();
  type Persona = { id: string; email: string; name: string; role: string; pausedUntil: string | null; owner: boolean };
  const personas = new Map<string, Persona>();
  for (const r of rows.results) {
    if (r.memberEmail && r.memberEmail !== viewer && !personas.has(r.memberEmail)) {
      personas.set(r.memberEmail, { id: r.id, email: r.memberEmail, name: r.name, role: r.role, pausedUntil: r.pausedUntil, owner: false });
    }
    if (r.ownerEmail !== viewer && !personas.has(r.ownerEmail)) {
      // El titular de una familia ajena: se muestra con el nombre de su equipo principal.
      personas.set(r.ownerEmail, { id: `titular:${r.ownerEmail}`, email: r.ownerEmail, name: "", role: "adulto", pausedUntil: null, owner: true });
    }
  }
  const ahora = Date.now();
  const people: Record<string, unknown>[] = [];
  for (const p of personas.values()) {
    const device = await env.DB.prepare(
      "SELECT id,name,platform,battery,last_seen_at AS lastSeenAt,last_location_json AS lastLocationJson,last_location_at AS lastLocationAt FROM devices WHERE owner_email=? AND approval_status=''approved'' ORDER BY CASE WHEN device_role=''primary'' THEN 0 ELSE 1 END, COALESCE(last_location_at,'''') DESC LIMIT 1",
    ).bind(p.email).first<{ id: string; name: string; platform: string; battery: number | null; lastSeenAt: string | null; lastLocationJson: string | null; lastLocationAt: string | null }>();
    const paused = Boolean(p.pausedUntil && Date.parse(p.pausedUntil) > ahora);
    people.push({
      id: p.id,
      // Al titular de otra familia no le pusieron nombre: se usa el de su correo ("lubick").
      name: p.name || (p.owner ? p.email.split("@")[0].replace(/^./, (c) => c.toUpperCase()) : device?.name || p.email.split("@")[0]),
      role: p.role,
      owner: p.owner,
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
    "SELECT id,name,role,invite_code AS code,invite_expires_at AS expiresAt FROM family_members WHERE owner_email=? AND status=''invitado'' AND invite_expires_at>? ORDER BY created_at DESC",
  ).bind(email, now()).all<{ id: string; name: string; role: string; code: string; expiresAt: string }>();
  return json({
    people,
    invites: invites.results.map((i) => ({ ...i, link: familyInviteUrl(env, i.code) })),
  });
}

async function remoteFamilyInvite(request: Request, env: Env) {
  const sessionInfo = await readSessionInfo(request, env.SESSION_SECRET);
  if (!sessionInfo) return json({ error: "unauthorized" }, 401);
  if (sessionInfo.method === "emergency") return json({ error: "not_allowed_in_emergency" }, 403);
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const name = String(body.name ?? "").trim().slice(0, 40);
  const role = String(body.role ?? "");
  if (!name || !(FAMILY_ROLES as readonly string[]).includes(role)) return json({ error: "invalid_invite" }, 400);
  const id = randomId("fam"), expiresAt = plusMinutes(FAMILY_INVITE_DAYS * 24 * 60);
  // El codigo es unico: si por azar ya existe, se prueba otro.
  for (let intento = 0; intento < 5; intento += 1) {
    const code = familyCode();
    try {
      await env.DB.prepare("INSERT INTO family_members (id,owner_email,name,role,status,invite_code,invite_expires_at,created_at) VALUES (?,?,?,?,?,?,?,?)")
        .bind(id, sessionInfo.email, name, role, "invitado", code, expiresAt, now()).run();
      return json({ id, name, role, code, expiresAt, link: familyInviteUrl(env, code) }, 201);
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
  const updated = await env.DB.prepare("UPDATE family_members SET status=''quitado'', invite_code=NULL WHERE id=? AND owner_email=? AND status<>''quitado''")
    .bind(String(body.id ?? ""), sessionInfo.email).run();
  return updated.meta.changes ? json({ removed: true }) : json({ error: "not_found" }, 404);
}

async function nativeOwnerEmail(request: Request, env: Env, deviceId: string) {
  if (!deviceId || !await requireNative(request, env, deviceId)) return null;
  const device = await env.DB.prepare("SELECT owner_email AS ownerEmail FROM devices WHERE id=? AND approval_status=''approved''")
    .bind(deviceId).first<{ ownerEmail: string }>();
  return device?.ownerEmail ?? null;
}

async function nativeFamily(request: Request, env: Env, url: URL) {
  const email = await nativeOwnerEmail(request, env, url.searchParams.get("deviceId") ?? "");
  if (!email) return json({ error: "unauthorized" }, 401);
  const mine = await env.DB.prepare("SELECT role,paused_until AS pausedUntil FROM family_members WHERE member_email=? AND status=''activo''")
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
  const invite = await env.DB.prepare("SELECT id,owner_email AS ownerEmail,name,role FROM family_members WHERE invite_code=? AND status=''invitado'' AND invite_expires_at>?")
    .bind(code, now()).first<{ id: string; ownerEmail: string; name: string; role: string }>();
  if (!invite) return json({ error: "code_not_found_or_expired" }, 404);
  if (invite.ownerEmail === email) return json({ error: "own_family" }, 409);
  // Si ya estaba en esa familia (por otra invitacion), se reemplaza la vieja.
  await env.DB.prepare("UPDATE family_members SET status=''quitado'' WHERE owner_email=? AND member_email=? AND status=''activo''")
    .bind(invite.ownerEmail, email).run();
  await env.DB.prepare("UPDATE family_members SET member_email=?, status=''activo'', joined_at=?, invite_code=NULL WHERE id=?")
    .bind(email, now(), invite.id).run();
  return json({ joined: true, name: invite.name, role: invite.role });
}

async function nativeFamilyPause(request: Request, env: Env) {
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const email = await nativeOwnerEmail(request, env, String(body.deviceId ?? ""));
  if (!email) return json({ error: "unauthorized" }, 401);
  const minutes = Math.max(0, Math.min(24 * 60, Math.round(Number(body.minutes) || 0)));
  // Los menores no pueden pausar: su ubicacion es justamente lo que cuida el tutor.
  const updated = await env.DB.prepare("UPDATE family_members SET paused_until=? WHERE member_email=? AND status=''activo'' AND role<>''menor''")
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

const HISTORY_EMAIL_POINT_COUNT = 10;')
)
$descargas = @(
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/6254880/scripts/familia/0016_familia.sql", "migrations\0016_familia.sql", "3381874e9942b209ae508a0a1fc776596370a0415268acead5c3363a778a74ba"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/6254880/scripts/mapa/panel-mapa.txt", "src\panel-mapa.txt", "c53f87e90e2ef32b9ca5295df44c7386876eb43413f1c163666ce925c7b83202"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/6254880/scripts/mapa/panel-mapa.css", "src\panel-mapa.css", "5b91f64a0c7de5701659620823367f761ce39cd1b43e715407131e8e0ea82a08")
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
    if (Test-Path ($ruta + ".bak-familia")) { Mal ("Ya existe " + $t + ".bak-familia. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-familia"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-familia): " + ($respaldados -join ", "))

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
Chk "index.ts: en vivo, correos y mapa siguen" (((Contar $vi 'async function remoteLive') -eq 1) -and ((Contar $vi 'function fetchCorreo') -eq 1) -and ((Contar $vi 'panel-mapa.txt') -eq 1))

if (-not $todoBien) {
    Mal "Algo no salio bien. Restauro todo desde los respaldos."
    foreach ($t in $tocados) {
        $ruta = Join-Path $raiz $t
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-familia") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "TODO BIEN en los archivos. Faltan 2 pasos:"
Write-Host "   1) Crear la tabla:  powershell -ExecutionPolicy Bypass -Command ""npx wrangler d1 execute ojo-guard-ms --remote --file migrations/0016_familia.sql"""
Write-Host "   2) Publicar:        powershell -ExecutionPolicy Bypass -Command ""npx wrangler deploy"""
Write-Host ""
