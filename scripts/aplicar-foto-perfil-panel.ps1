# aplicar-foto-perfil-panel.ps1 - Ojo Guard MS: la foto de perfil la ve el circulo (servidor).
# Luciano (28/10/2026): "la foto de perfil tiene que verla la gente con la que ella comparte". Agrega la tabla profile_photos (se crea sola), POST /api/native/profile-photo (sube un JPEG chico) y /delete,
# GET /api/native/profile-photo y GET /api/remote/profile-photo (solo para quien ya ve a esa persona en la lista de familia) y el campo "photo" (version) en cada persona de la lista.
# Cambia SOLO src\index.ts (respaldo .bak-foto-perfil). Va en la carpeta del PANEL. Al final publica el panel solo.
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
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'profile_photos') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
$cambios = @(
    @('src\index.ts', 'funciones de foto de perfil', 'export default {
  async scheduled(_controller', '// ---- Foto de perfil visible para el circulo ----
// Cada persona sube una foto chica (256 px, JPEG) y la ven solo quienes ya la ven en la lista de familia (familyPeopleFor decide quien ve a quien).
let fotoTablaLista = false;
async function fotoTabla(env: Env) {
  if (fotoTablaLista) return;
  await env.DB.prepare("CREATE TABLE IF NOT EXISTS profile_photos (email TEXT PRIMARY KEY, photo_b64 TEXT NOT NULL, updated_at INTEGER NOT NULL)").run();
  fotoTablaLista = true;
}

async function fotoVersion(env: Env, email: string): Promise<number | null> {
  try {
    await fotoTabla(env);
    const fila = await env.DB.prepare("SELECT updated_at AS v FROM profile_photos WHERE email=?").bind(email).first<{ v: number }>();
    return fila?.v ?? null;
  } catch {
    return null;
  }
}

async function nativeProfilePhotoSave(request: Request, env: Env) {
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const email = await nativeOwnerEmail(request, env, String(body.deviceId ?? ""));
  if (!email) return json({ error: "unauthorized" }, 401);
  const foto = String(body.photoBase64 ?? "").replace(/^data:[^,]+,/, "");
  // JPEG chico: unos 10-40 KB. Tope de 120 mil caracteres en base64 (unos 90 KB).
  if (foto.length < 500 || foto.length > 120_000 || !foto.startsWith("/9j/")) return json({ error: "invalid_photo" }, 400);
  try {
    atob(foto);
  } catch {
    return json({ error: "invalid_photo" }, 400);
  }
  await fotoTabla(env);
  const version = Date.now();
  await env.DB.prepare("INSERT INTO profile_photos (email,photo_b64,updated_at) VALUES (?,?,?) ON CONFLICT(email) DO UPDATE SET photo_b64=excluded.photo_b64,updated_at=excluded.updated_at")
    .bind(email, foto, version).run();
  return json({ ok: true, version });
}

async function nativeProfilePhotoDelete(request: Request, env: Env) {
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const email = await nativeOwnerEmail(request, env, String(body.deviceId ?? ""));
  if (!email) return json({ error: "unauthorized" }, 401);
  await fotoTabla(env);
  await env.DB.prepare("DELETE FROM profile_photos WHERE email=?").bind(email).run();
  return json({ ok: true });
}

// La foto de `personaId` (el id que trae la lista de familia, o "me") para `viewer`: solo si `viewer` ya la ve en esa lista.
async function fotoRespuesta(env: Env, viewer: string, personaId: string) {
  let email: string | null = null;
  if (personaId === "me") {
    email = viewer;
  } else {
    const personas = await familyPeopleFor(env, viewer);
    if (!personas.some((p) => String(p.id) === personaId)) return json({ error: "not_found" }, 404);
    if (personaId.startsWith("titular:")) {
      email = personaId.slice("titular:".length);
    } else {
      const fila = await env.DB.prepare("SELECT member_email AS e FROM family_members WHERE id=?").bind(personaId).first<{ e: string | null }>();
      email = fila?.e ?? null;
    }
  }
  if (!email) return json({ error: "not_found" }, 404);
  await fotoTabla(env);
  const foto = await env.DB.prepare("SELECT photo_b64 AS f FROM profile_photos WHERE email=?").bind(email).first<{ f: string }>();
  if (!foto) return json({ error: "not_found" }, 404);
  const bytes = Uint8Array.from(atob(foto.f), (c) => c.charCodeAt(0));
  return new Response(bytes, { headers: { "content-type": "image/jpeg", "cache-control": "private, max-age=86400" } });
}

async function nativeProfilePhotoGet(request: Request, env: Env, url: URL) {
  const email = await nativeOwnerEmail(request, env, url.searchParams.get("deviceId") ?? "");
  if (!email) return json({ error: "unauthorized" }, 401);
  return fotoRespuesta(env, email, url.searchParams.get("person") ?? "me");
}

async function remoteProfilePhotoGet(request: Request, env: Env, url: URL) {
  const sessionInfo = await readSessionInfo(request, env.SESSION_SECRET);
  if (!sessionInfo) return json({ error: "unauthorized" }, 401);
  return fotoRespuesta(env, sessionInfo.email, url.searchParams.get("person") ?? "me");
}

export default {
  async scheduled(_controller'),
    @('src\index.ts', 'rutas nativas de foto de perfil', 'if (route === "GET /api/app/version") return apkVersionJson(env);', 'if (route === "GET /api/app/version") return apkVersionJson(env);
      if (route === "GET /api/native/profile-photo") return nativeProfilePhotoGet(request, env, url);
      if (route === "POST /api/native/profile-photo") return nativeProfilePhotoSave(request, env);
      if (route === "POST /api/native/profile-photo/delete") return nativeProfilePhotoDelete(request, env);'),
    @('src\index.ts', 'ruta del panel para la foto de perfil', 'if (route === "GET /api/remote/family") return remoteFamily(request, env);', 'if (route === "GET /api/remote/family") return remoteFamily(request, env);
      if (route === "GET /api/remote/profile-photo") return remoteProfilePhotoGet(request, env, url);'),
    @('src\index.ts', 'version de la foto en la lista de personas', '      lastLocationAt: !paused ? device?.lastLocationAt ?? null : null,
', '      lastLocationAt: !paused ? device?.lastLocationAt ?? null : null,
      // Version de la foto de perfil (null si no tiene): el cliente la pide con GET /profile-photo?person=<id> solo cuando cambia.
      photo: await fotoVersion(env, p.email),
'),
    @('src\index.ts', 'version de la foto propia', 'me: { memberships: mine.results.length,', 'me: { photo: await fotoVersion(env, email), memberships: mine.results.length,')
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
    if (Test-Path ($ruta + ".bak-foto-perfil")) { Mal ("Ya existe " + $t + ".bak-foto-perfil. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-foto-perfil"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-foto-perfil): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-foto-perfil") -Destination $ruta -Force }
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
Ok "LISTO: la foto de perfil ahora se puede subir y la ve el circulo."
Write-Host ""
