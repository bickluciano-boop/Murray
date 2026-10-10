# aplicar-menores-evidencia.ps1 - Familia: el tutor pide una foto y un audio del telefono de un menor (el menor
# siempre recibe el aviso), aviso a la persona cuando le cambian el rol, y salir de una familia.
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Toca src\index.ts y actualiza src\panel-mapa.txt y
# src\panel-mapa.css. Respaldos .bak-fotomenor; si algo falla, se restaura todo.
# Base de datos: antes de publicar, agregar dos columnas (el script lo recuerda al final).
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
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'async function familyEvidenceMail') -ne 0) { Avi "La foto y audio para menores ya estaba aplicada. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'async function remoteFamilyRole') -eq 0) { Mal "Primero corre aplicar-familia-gestion.ps1."; return }
if ((Sha (Join-Path $raiz "src\panel-mapa.txt")) -ne "1447595b876bdf9e93a56e9cc5eba90e25bf071da9e17ba3b480493eb8f97e56") { Mal "src\panel-mapa.txt no es la version que espero. Primero corre aplicar-familia-gestion.ps1."; return }
$cambios = @(
    @('src\index.ts', 'aviso simple por push', 'const escapeHtml = (value: unknown) => String(value ?? "")
', '/** Aviso visible simple, sin orden (Familia: "te cambiaron el rol"). Al tocarlo, la app solo se sincroniza. */
async function sendExpoNotice(pushToken: string | null, title: string, body: string) {
  if (!pushToken || !/^(ExponentPushToken|ExpoPushToken)\[.+\]$/.test(pushToken)) return false;
  const response = await fetch("https://exp.host/--/api/v2/push/send", {
    method: "POST",
    headers: { "content-type": "application/json", accept: "application/json" },
    body: JSON.stringify([{ to: pushToken, title, body, sound: "default", priority: "high", ttl: 86_400, data: {} }]),
  });
  return response.ok;
}

const escapeHtml = (value: unknown) => String(value ?? "")
'),
    @('src\index.ts', 'correo al menor: quien pidio la captura', '    const alertDeviceName = (await env.DB.prepare("SELECT name FROM devices WHERE id=?").bind(deviceId).first<{ name: string | null }>())?.name || "Tel\u00e9fono principal";
', '    const alertDeviceName = (await env.DB.prepare("SELECT name FROM devices WHERE id=?").bind(deviceId).first<{ name: string | null }>())?.name || "Tel\u00e9fono principal";
    // Familia (menores, parte 2): si un tutor pidio una foto y un audio de este telefono, el
    // correo al menor lo dice, en lugar de hablar de un intento de acceso. SELECT * para no
    // romper nada si todavia no se agregaron las columnas requested_by.
    const pedidoFamilia = await env.DB.prepare("SELECT * FROM commands WHERE device_id=? AND type=''capture-evidence'' AND status IN (''pending'',''received'') AND expires_at>? ORDER BY created_at DESC LIMIT 1")
      .bind(deviceId, now()).first<Record<string, unknown>>().catch(() => null);
    const quienPidio = pedidoFamilia?.requested_by ? String(pedidoFamilia.requested_by_name || "tu familia") : "";
'),
    @('src\index.ts', 'correo al menor: asunto', '        subject: `Intento de acceso detectado \u00b7 ${alertDeviceName}`,
', '        subject: quienPidio ? `Foto y audio que pidi\u00f3 ${quienPidio}` : `Intento de acceso detectado \u00b7 ${alertDeviceName}`,
'),
    @('src\index.ts', 'correo al menor: titulo', '<h1 style="font-size:26px;margin:10px 0 18px">Se detect&#243; un intento de acceso</h1>', '<h1 style="font-size:26px;margin:10px 0 18px">${quienPidio ? "Se tom&#243; una foto y un audio de tu tel&#233;fono" : "Se detect&#243; un intento de acceso"}</h1>${quienPidio ? `<p style="color:#d2d2ce">Los pidi&#243; ${escapeHtml(quienPidio)} desde Ojo Guard MS y tambi&#233;n le llegan por correo.</p>` : ""}'),
    @('src\index.ts', 'aviso al cambiar el rol', '    .bind(role, role, String(body.id ?? ""), sessionInfo.email).run();
  return updated.meta.changes ? json({ updated: true, role }) : json({ error: "not_found" }, 404);
}
', '    .bind(role, role, String(body.id ?? ""), sessionInfo.email).run();
  if (!updated.meta.changes) return json({ error: "not_found" }, 404);
  // La persona se entera (push y correo) de que rol tiene ahora y de que puede salir de la
  // familia: asi nadie queda como Menor sin saberlo.
  const fila = await env.DB.prepare("SELECT member_email AS memberEmail,owner_name AS ownerName FROM family_members WHERE id=?")
    .bind(String(body.id ?? "")).first<{ memberEmail: string | null; ownerName: string | null }>();
  if (fila?.memberEmail) {
    const quien = fila.ownerName || sessionInfo.email.split("@")[0].replace(/^./, (c) => c.toUpperCase());
    const texto = familyRoleNotice(role, quien);
    const device = await env.DB.prepare("SELECT name,push_token AS pushToken FROM devices WHERE owner_email=? AND approval_status=''approved'' ORDER BY CASE WHEN device_role=''primary'' THEN 0 ELSE 1 END, COALESCE(last_location_at,'''') DESC LIMIT 1")
      .bind(fila.memberEmail).first<{ name: string; pushToken: string | null }>();
    await sendExpoNotice(device?.pushToken ?? null, "Ojo Guard", texto).catch(() => false);
    await sendSecurityNotice(env, fila.memberEmail, "Cambi\u00f3 tu rol en una familia", texto, device?.name);
  }
  return json({ updated: true, role });
}

function familyRoleNotice(role: string, quien: string) {
  if (role === "menor") return `${quien} te puso como Menor en su familia: puede ver d\u00f3nde est\u00e1s, hacer sonar tu tel\u00e9fono y pedir una foto y un audio. Si no corresponde, pod\u00e9s salir de la familia desde Ojo Guard.`;
  if (role === "amigo") return `${quien} te puso como Amigo en su familia: solo se ven ustedes dos.`;
  return `${quien} te puso como Adulto en su familia: ves a toda la familia y pod\u00e9s pausar tu ubicaci\u00f3n.`;
}

/** Salir de una familia. Cualquiera puede, tambien un menor; al titular le llega un correo. */
async function familyLeave(env: Env, email: string, personId: string) {
  if (!personId.startsWith("titular:")) return json({ error: "not_found" }, 404);
  const ownerEmail = personId.slice("titular:".length);
  const fila = await env.DB.prepare("SELECT id,name FROM family_members WHERE owner_email=? AND member_email=? AND status=''activo''")
    .bind(ownerEmail, email).first<{ id: string; name: string }>();
  if (!fila) return json({ error: "not_found" }, 404);
  await env.DB.prepare("UPDATE family_members SET status=''quitado'', invite_code=NULL WHERE owner_email=? AND member_email=? AND status=''activo''")
    .bind(ownerEmail, email).run();
  const nombre = fila.name || email.split("@")[0];
  await sendSecurityNotice(env, ownerEmail, `${nombre} sali\u00f3 de tu familia`, `${nombre} sali\u00f3 de tu familia en Ojo Guard: ya no se ven en el mapa. Para volver a sumarlo, mandale una invitaci\u00f3n nueva.`);
  return json({ left: true });
}

async function remoteFamilyLeave(request: Request, env: Env) {
  const sessionInfo = await readSessionInfo(request, env.SESSION_SECRET);
  if (!sessionInfo) return json({ error: "unauthorized" }, 401);
  if (sessionInfo.method === "emergency") return json({ error: "not_allowed_in_emergency" }, 403);
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  return familyLeave(env, sessionInfo.email, String(body.personId ?? ""));
}

async function nativeFamilyLeave(request: Request, env: Env) {
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const email = await nativeOwnerEmail(request, env, String(body.deviceId ?? ""));
  if (!email) return json({ error: "unauthorized" }, 401);
  return familyLeave(env, email, String(body.personId ?? ""));
}
'),
    @('src\index.ts', 'orden de foto y audio para menores', 'const FAMILY_MINOR_COMMANDS: readonly CommandType[] = ["locate", "alarm", "stop-ring"];', 'const FAMILY_MINOR_COMMANDS: readonly CommandType[] = ["locate", "alarm", "stop-ring", "capture-evidence"];'),
    @('src\index.ts', 'aviso al menor por foto y audio', '  if (type === "stop-ring") return { titulo: "Ojo Guard", texto: `${quien} detuvo el sonido.`, asunto: null, silencioso: true };
', '  if (type === "stop-ring") return { titulo: "Ojo Guard", texto: `${quien} detuvo el sonido.`, asunto: null, silencioso: true };
  if (type === "capture-evidence") return { titulo: "Ojo Guard", texto: `${quien} pidi\u00f3 una foto y un audio de tu tel\u00e9fono.`, asunto: "Pidieron una foto y un audio de tu tel\u00e9fono", silencioso: false };
'),
    @('src\index.ts', 'estado de la orden con la foto y el audio', '    if (command.locationJson) command.location = JSON.parse(String(command.locationJson));
    delete command.locationJson;
    delete command.ownerEmail;
', '    if (command.locationJson) command.location = JSON.parse(String(command.locationJson));
    delete command.locationJson;
    // Foto y audio: solo los ve quien los pidio (ver remoteFamilyEvidence).
    if (command.type === "capture-evidence" && command.status === "executed") {
      const ev = await familyEvidenceOf(env, id);
      if (ev && ev.tutor === email) {
        const base = `/api/remote/family/evidence?commandId=${encodeURIComponent(id)}`;
        command.evidence = { front: ev.frontKey ? `${base}&kind=front` : null, audio: ev.audioKey ? `${base}&kind=audio` : null };
      }
    }
    delete command.ownerEmail;
'),
    @('src\index.ts', 'guardar quien pidio la orden', '  await env.DB.prepare("INSERT INTO commands (id,device_id,owner_email,type,status,created_at,expires_at) VALUES (?,?,?,?,?,?,?)")
    .bind(id, target.device.id, target.minorEmail, type, "pending", createdAt, plusMinutes(60)).run();
', '  // requested_by: quien la pidio. La foto y el audio se le muestran y se le mandan solo a esa
  // persona. Si la base todavia no tiene esas columnas, la orden se guarda igual sin ellas.
  try {
    await env.DB.prepare("INSERT INTO commands (id,device_id,owner_email,type,status,created_at,expires_at,requested_by,requested_by_name) VALUES (?,?,?,?,?,?,?,?,?)")
      .bind(id, target.device.id, target.minorEmail, type, "pending", createdAt, plusMinutes(60), email, target.quien).run();
  } catch (error) {
    if (!String(error).includes("requested_by")) throw error;
    await env.DB.prepare("INSERT INTO commands (id,device_id,owner_email,type,status,created_at,expires_at) VALUES (?,?,?,?,?,?,?)")
      .bind(id, target.device.id, target.minorEmail, type, "pending", createdAt, plusMinutes(60)).run();
  }
'),
    @('src\index.ts', 'foto y audio: archivos y correo al tutor', '/** "Seguir en vivo" sobre el telefono de un menor: como remoteLive(), con aviso al menor al empezar. */
', '// Menores, parte 2: foto y audio. Un tutor los pide desde el mapa (orden "capture-evidence"
// con requested_by); el menor recibe el aviso y el telefono los saca como la evidencia de
// siempre. Le llegan por correo solo a quien los pidio, que los ve en el mapa mientras siga
// siendo su tutor. Columnas agregadas a mano el 10/10/2026:
//   ALTER TABLE commands ADD COLUMN requested_by TEXT; ALTER TABLE commands ADD COLUMN requested_by_name TEXT;

/** La foto y el audio de una orden pedida por un tutor (null si no es eso o todavia no llegaron). */
async function familyEvidenceOf(env: Env, commandId: string) {
  const orden = await env.DB.prepare("SELECT * FROM commands WHERE id=? AND type=''capture-evidence'' AND status=''executed''")
    .bind(commandId).first<Record<string, unknown>>();
  if (!orden?.requested_by || !orden.evidence_attempt_id) return null;
  const intento = await env.DB.prepare("SELECT front_object_key AS frontKey,audio_object_key AS audioKey,location_json AS locationJson,occurred_at AS occurredAt FROM evidence_attempts WHERE id=? AND device_id=?")
    .bind(String(orden.evidence_attempt_id), String(orden.device_id)).first<{ frontKey: string | null; audioKey: string | null; locationJson: string | null; occurredAt: string }>();
  if (!intento) return null;
  return { tutor: String(orden.requested_by), menor: String(orden.owner_email), ...intento };
}

/** La foto o el audio, para quien los pidio y mientras siga siendo tutor de ese menor. */
async function remoteFamilyEvidence(request: Request, env: Env, url: URL) {
  const sessionInfo = await readSessionInfo(request, env.SESSION_SECRET);
  if (!sessionInfo) return json({ error: "unauthorized" }, 401);
  if (sessionInfo.method === "emergency") return json({ error: "not_allowed_in_emergency" }, 403);
  const ev = await familyEvidenceOf(env, url.searchParams.get("commandId") ?? "");
  if (!ev || ev.tutor !== sessionInfo.email || !await familyIsTutorOf(env, sessionInfo.email, ev.menor)) return json({ error: "not_found" }, 404);
  const audio = url.searchParams.get("kind") === "audio";
  const key = audio ? ev.audioKey : ev.frontKey;
  const object = key && env.EVIDENCE_FILES ? await env.EVIDENCE_FILES.getWithMetadata<{ contentType?: string }>(key, "arrayBuffer") : null;
  if (!object?.value) return json({ error: "not_found" }, 404);
  return new Response(object.value, { headers: { "content-type": object.metadata?.contentType || (audio ? "audio/mp4" : "image/jpeg"), "cache-control": "private, max-age=3600", "x-content-type-options": "nosniff" } });
}

function base64DeBytes(bytes: ArrayBuffer) {
  const datos = new Uint8Array(bytes);
  let texto = "";
  for (let i = 0; i < datos.length; i += 0x8000) texto += String.fromCharCode(...datos.subarray(i, i + 0x8000));
  return btoa(texto);
}

/** Cuando llegan la foto y el audio que pidio un tutor, se los manda por correo a esa persona. */
async function familyEvidenceMail(env: Env, commandId: string) {
  const ev = await familyEvidenceOf(env, commandId);
  if (!ev || !env.EVIDENCE_FILES) return;
  const fila = await env.DB.prepare("SELECT name FROM family_members WHERE member_email=? AND status=''activo'' AND role=''menor'' ORDER BY CASE WHEN owner_email=? THEN 0 ELSE 1 END LIMIT 1")
    .bind(ev.menor, ev.tutor).first<{ name: string }>();
  const nombre = fila?.name || ev.menor.split("@")[0];
  const attachments: { filename: string; content: string }[] = [];
  for (const [key, filename] of [[ev.frontKey, "foto.jpg"], [ev.audioKey, "audio.m4a"]] as const) {
    if (!key) continue;
    const object = await env.EVIDENCE_FILES.getWithMetadata<{ contentType?: string }>(key, "arrayBuffer");
    if (!object?.value) continue;
    const wav = String(object.metadata?.contentType ?? "").includes("wav");
    attachments.push({ filename: wav ? "audio.wav" : filename, content: base64DeBytes(object.value) });
  }
  const ubic = ev.locationJson ? JSON.parse(ev.locationJson) as Record<string, unknown> : null;
  const lat = Number(ubic?.latitude), lng = Number(ubic?.longitude);
  const lugar = Number.isFinite(lat) && Number.isFinite(lng)
    ? `<p style="color:#d2d2ce"><strong style="color:#fff">D&#243;nde:</strong> ${escapeHtml(ubic?.address || `${lat}, ${lng}`)}</p><p style="margin:20px 0"><a style="display:inline-block;background:#d9b24c;color:#111;padding:12px 16px;border-radius:10px;text-decoration:none;font-weight:700" href="https://www.google.com/maps/search/?api=1&query=${lat},${lng}">Abrir en el mapa</a></p>`
    : "";
  const response = await fetchCorreo("https://api.resend.com/emails", {
    method: "POST",
    headers: { authorization: `Bearer ${env.RESEND_API_KEY}`, "content-type": "application/json" },
    body: JSON.stringify({
      from: env.MAIL_FROM,
      reply_to: env.SUPPORT_EMAIL,
      to: [ev.tutor],
      subject: `Foto y audio de ${nombre}`,
      html: `<div style="font-family:Arial,sans-serif;max-width:620px;margin:auto;background:#0c0d0f;color:#f6f6f2;padding:28px;border-radius:20px"><p style="color:#f4c64e;font-size:12px;font-weight:800;letter-spacing:.16em">OJO GUARD &#183; FAMILIA</p><h1 style="font-size:26px;margin:10px 0 18px">Foto y audio de ${escapeHtml(nombre)}</h1><p style="color:#d2d2ce;line-height:1.55">Los pediste desde el mapa de Ojo Guard MS. Van adjuntos. ${escapeHtml(nombre)} recibi&#243; el aviso de tu pedido en su tel&#233;fono.</p><p style="color:#d2d2ce"><strong style="color:#fff">Fecha y hora:</strong> ${escapeHtml(fechaCorreo(ev.occurredAt))} &#183; Buenos Aires</p>${lugar}</div>`,
      attachments,
    }),
  });
  if (!response.ok) console.error("family_evidence_mail_failed", response.status, await response.text());
}

/** "Seguir en vivo" sobre el telefono de un menor: como remoteLive(), con aviso al menor al empezar. */
'),
    @('src\index.ts', 'correo al tutor cuando llega la captura', '  if (!updated.meta.changes) return json({ error: "command_not_found_or_finished" }, 409);
', '  if (!updated.meta.changes) return json({ error: "command_not_found_or_finished" }, 409);
  // Foto y audio que pidio un tutor (Familia, menores parte 2): le llegan por correo.
  if (status === "executed" && body.evidenceAttemptId) await familyEvidenceMail(env, commandId).catch((error) => console.error("family_evidence_mail_failed", error));
'),
    @('src\index.ts', 'rutas nuevas', '      if (route === "POST /api/remote/family/role") return remoteFamilyRole(request, env);
', '      if (route === "POST /api/remote/family/role") return remoteFamilyRole(request, env);
      if (route === "POST /api/remote/family/leave") return remoteFamilyLeave(request, env);
      if (route === "GET /api/remote/family/evidence") return remoteFamilyEvidence(request, env, url);
'),
    @('src\index.ts', 'ruta para salir desde la app', '      if (route === "POST /api/native/family/pause") return nativeFamilyPause(request, env);
', '      if (route === "POST /api/native/family/pause") return nativeFamilyPause(request, env);
      if (route === "POST /api/native/family/leave") return nativeFamilyLeave(request, env);
')
)
$descargas = @(
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/31f440b/scripts/mapa/panel-mapa.txt", "src\panel-mapa.txt", "d4131d6b0569b21037f6e26e5fba2382b8e758fdbdd142fc2b94ce621666c2bb"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/31f440b/scripts/mapa/panel-mapa.css", "src\panel-mapa.css", "d47429522cb332ee08153dbe0cbc00ec23fd57fab48a1c7c14c8f8974e706e65")
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
    if (Test-Path ($ruta + ".bak-fotomenor")) { Mal ("Ya existe " + $t + ".bak-fotomenor. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-fotomenor"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-fotomenor): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-fotomenor") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "TODO BIEN en los archivos. Faltan dos pasos, en este orden:"
Write-Host "  1) npx.cmd wrangler d1 execute ojo-guard-ms --remote --command ""ALTER TABLE commands ADD COLUMN requested_by TEXT; ALTER TABLE commands ADD COLUMN requested_by_name TEXT;"""
Write-Host "  2) npx.cmd wrangler deploy"
Write-Host ""
