# aplicar-permisos-ojo-panel.ps1 - Ojo Guard MS: permisos entre dos personas de la familia (Familia y amigos > Permisos, "el ojo").
# Luciano (04/11/2026): que cada uno pueda cortar por su lado (ubicacion y SOS) y que la otra persona reciba el aviso; y que SIEMPRE quede al menos una persona que reciba el SOS (los referentes por mail no cuentan).
# Tabla nueva family_perms (se crea sola). La lista de familia trae locCut y permisos por persona; el SOS, las ordenes de ubicar y los avisos de lugar respetan las llaves. Con un menor no se puede cortar nada.
# Requiere haber aplicado antes aplicar-familia-sos-nombres-panel.ps1. Cambia SOLO src\index.ts (respaldo .bak-permisos). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
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
if (-not (Test-Path (Join-Path $raiz "src\index.ts"))) { Mal "No encuentro src\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'const destinoSos') -eq 0) { Mal "Falta aplicar primero aplicar-familia-sos-nombres-panel.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'async function nativeFamilyPerm') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
$cambios = @(
    @('src\index.ts', 'permisos: tabla, lectura, corte y endpoint', 'async function nativeFamilyPause(request: Request, env: Env) {
', '// ---------------------------------------------------------------------------
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
  const soyMenor = await env.DB.prepare("SELECT 1 AS m FROM family_members WHERE member_email=? AND status=''activo'' AND role=''menor'' LIMIT 1").bind(email).first<{ m: number }>();
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

async function nativeFamilyPause(request: Request, env: Env) {
'),
    @('src\index.ts', 'permisos: leer los permisos de quien mira', '  const destinoSos = new Set(await familySosRecipients(env, viewer).catch(() => [] as string[]));
', '  const destinoSos = new Set(await familySosRecipients(env, viewer).catch(() => [] as string[]));
  const perms = await permsDe(env, viewer).catch(() => new Map<string, PermFila>());
'),
    @('src\index.ts', 'permisos: llaves de cada persona', '    const paused = Boolean(p.pausedUntil && Date.parse(p.pausedUntil) > ahora);
', '    const paused = Boolean(p.pausedUntil && Date.parse(p.pausedUntil) > ahora);
    // Permisos con esta persona: cada llave vale si los DOS lados estan prendidos (`mine` es el mio, `theirs` el de ella).
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
'),
    @('src\index.ts', 'permisos: ubicacion cortada no se manda', '      lastLocation: !paused && device?.lastLocationJson ? JSON.parse(device.lastLocationJson) : null,
      lastLocationAt: !paused ? device?.lastLocationAt ?? null : null,
', '      lastLocation: !paused && !corte && device?.lastLocationJson ? JSON.parse(device.lastLocationJson) : null,
      lastLocationAt: !paused && !corte ? device?.lastLocationAt ?? null : null,
'),
    @('src\index.ts', 'permisos: locCut y permisos en la lista', '      sosTo: destinoSos.has(p.email),
', '      sosTo: destinoSos.has(p.email),
      locCut: corte,
      permisos,
'),
    @('src\index.ts', 'permisos: el SOS respeta las llaves', '  destinatarios.delete(person);
  return [...destinatarios];
', '  destinatarios.delete(person);
  // Permisos: no le suena a quien la persona saco de su SOS ni a quien apago "Recibo su SOS".
  try {
    const mapa = await permsDe(env, person);
    for (const b of [...destinatarios]) {
      if (!permDe(mapa, person, b).sos_send || !permDe(mapa, b, person).sos_recv) destinatarios.delete(b);
    }
  } catch (error) {
    console.error("perms_sos", String(error).slice(0, 120));
  }
  return [...destinatarios];
'),
    @('src\index.ts', 'permisos: ubicar/en vivo con la ubicacion cortada', '    pausada: Boolean(fila.pausedUntil && Date.parse(fila.pausedUntil) > Date.now()),
', '    pausada: Boolean(fila.pausedUntil && Date.parse(fila.pausedUntil) > Date.now()) || await permCorte(env, fila.memberEmail, viewer),
'),
    @('src\index.ts', 'permisos: avisos de lugar con la ubicacion cortada', '    const sigueVisible = (await familyPeopleFor(env, aviso.watcherEmail)).some((p) => p.id === aviso.personId);
    if (!sigueVisible) { await env.DB.prepare("DELETE FROM family_alerts WHERE id=?").bind(aviso.id).run(); continue; }
', '    const personaDelAviso = (await familyPeopleFor(env, aviso.watcherEmail)).find((p) => p.id === aviso.personId);
    if (!personaDelAviso) { await env.DB.prepare("DELETE FROM family_alerts WHERE id=?").bind(aviso.id).run(); continue; }
    if (personaDelAviso.locCut) continue;
'),
    @('src\index.ts', 'permisos: ruta', '      if (route === "POST /api/native/family/pause") return nativeFamilyPause(request, env);
', '      if (route === "POST /api/native/family/pause") return nativeFamilyPause(request, env);
      if (route === "POST /api/native/family/perm") return nativeFamilyPerm(request, env);
'),
    @('src\index.ts', 'permisos: borrar cuenta', '  await borrar("family_members", "DELETE FROM family_members WHERE owner_email=? OR member_email=?", 2);
', '  await borrar("family_perms", "DELETE FROM family_perms WHERE from_email=? OR to_email=?", 2);
  await borrar("family_members", "DELETE FROM family_members WHERE owner_email=? OR member_email=?", 2);
')
)
$descargas = @()

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
    if (Test-Path ($ruta + ".bak-permisos")) { Mal ("Ya existe " + $t + ".bak-permisos. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-permisos"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-permisos): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-permisos") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "Archivos listos. Ahora publico el panel..."
& npx.cmd wrangler deploy
if ($LASTEXITCODE -ne 0) { Mal "No se pudo publicar el panel. Mandame esta pantalla."; return }
Write-Host ""
Ok "LISTO: los permisos (el ojo) ya estan en el servidor."
Write-Host ""
