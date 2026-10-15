# aplicar-acceso-directo-panel.ps1 - Acceso directo al panel (consola general) desde la app del propio telefono.
# Cuando alguien aprieta "Abrir Ojo Guard MS" en la app Ojo Guard de un telefono ya vinculado, el servidor le da un enlace de un solo uso
# (vence en 1 minuto) y el navegador abre la consola con la sesion iniciada, sin pedir codigo por correo ni passkey. Entrar desde otro
# dispositivo sigue pidiendo todo como siempre. Cada acceso directo manda un aviso de seguridad por correo y esa sesion cuenta como
# fuerte (no pide passkey para las acciones sensibles mientras dure, 30 minutos).
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Toca src\index.ts. Respaldo .bak-directo. La tabla que necesita
# (panel_handoff) la crea el propio panel la primera vez. Al final publica el panel solo.
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
if ((Contar $indexTexto 'async function nativePanelHandoff') -ne 0) { Avi "El acceso directo ya estaba aplicado en el panel. No toco nada."; return }
if ((Contar $indexTexto 'async function nativePasskeyBootstrap') -eq 0) { Mal "No encuentro el acceso seguro (passkeys) en este panel. Mandame esta pantalla."; return }
$cambios = @(
    @('src\index.ts', 'tipo de sesion: device', 'type SessionMethod = "email" | "passkey" | "totp" | "emergency";', 'type SessionMethod = "email" | "passkey" | "totp" | "emergency" | "device";'),
    @('src\index.ts', 'lectura de la sesion: device', '        : method === "emergency"
          ? "emergency"
          : "email";', '        : method === "emergency"
          ? "emergency"
          : method === "device"
            ? "device"
            : "email";'),
    @('src\index.ts', 'sesion fuerte: tambien la abierta desde el telefono', '  return Boolean(
    session &&
    (session.method === "passkey" || session.method === "totp") &&
    Date.now() - session.authenticatedAt <= 5 * 60_000,
  );', '  // Una sesion abierta desde la app del propio telefono ("device") cuenta como fuerte mientras dure: el telefono vinculado, con la clave
  // de administrador de la app, ya es la prueba. Entrar desde otro equipo sigue pidiendo codigo y passkey.
  return Boolean(
    session &&
    (session.method === "device" ||
      ((session.method === "passkey" || session.method === "totp") && Date.now() - session.authenticatedAt <= 5 * 60_000)),
  );'),
    @('src\index.ts', 'rutas del acceso directo', '      if (route === "POST /api/native/passkeys/bootstrap") return nativePasskeyBootstrap(request, env);
', '      if (route === "POST /api/native/passkeys/bootstrap") return nativePasskeyBootstrap(request, env);
      if (route === "POST /api/native/panel-handoff") return nativePanelHandoff(request, env);
      if (route === "GET /auth/device") return panelHandoffRedeem(request, env, url);
'),
    @('src\index.ts', 'funciones del acceso directo', 'async function registrationOptions(request: Request, env: Env) {
', '// Acceso directo al panel desde la app del propio telefono. La app (que ya entro con la clave de administrador) pide un enlace de un solo
// uso que vence en 1 minuto; al abrirlo, el navegador queda con la sesion abierta, sin pedir codigo ni passkey. Entrar desde otro
// dispositivo sigue pidiendo todo como siempre. Cada acceso manda un aviso de seguridad por correo.
let panelHandoffTable = false;
async function ensurePanelHandoffTable(env: Env) {
  if (panelHandoffTable) return;
  await env.DB.prepare("CREATE TABLE IF NOT EXISTS panel_handoff (token_hash TEXT PRIMARY KEY, owner_email TEXT NOT NULL, device_id TEXT NOT NULL, expires_at INTEGER NOT NULL, used_at INTEGER)").run();
  panelHandoffTable = true;
}

async function nativePanelHandoff(request: Request, env: Env) {
  const body = await request.json<Record<string, unknown>>().catch(() => ({}) as Record<string, unknown>);
  const deviceId = String(body.deviceId ?? "");
  if (!deviceId || !await requireNative(request, env, deviceId)) return json({ error: "unauthorized" }, 401);
  const device = await env.DB.prepare("SELECT owner_email AS ownerEmail FROM devices WHERE id=? AND approval_status=''approved''").bind(deviceId).first<{ ownerEmail: string }>();
  if (!device) return json({ error: "unauthorized" }, 401);
  await ensurePanelHandoffTable(env);
  const token = [...crypto.getRandomValues(new Uint8Array(32))].map((byte) => byte.toString(16).padStart(2, "0")).join("");
  const ahora = Date.now();
  await env.DB.prepare("DELETE FROM panel_handoff WHERE expires_at<?").bind(ahora - 86_400_000).run();
  await env.DB.prepare("INSERT INTO panel_handoff (token_hash,owner_email,device_id,expires_at) VALUES (?,?,?,?)").bind(await hash(token), normalizeEmail(device.ownerEmail), deviceId, ahora + 60_000).run();
  return json({ url: `${new URL(request.url).origin}/auth/device?t=${token}`, expiresInSeconds: 60 }, 201);
}

async function panelHandoffRedeem(request: Request, env: Env, url: URL) {
  const entrada = "/acceso-v7";
  const aLaEntrada = () => new Response(null, { status: 302, headers: { location: entrada, "cache-control": "no-store" } });
  const token = url.searchParams.get("t") ?? "";
  if (!/^[0-9a-f]{64}$/.test(token)) return aLaEntrada();
  await ensurePanelHandoffTable(env);
  const ahora = Date.now();
  const fila = await env.DB.prepare("UPDATE panel_handoff SET used_at=? WHERE token_hash=? AND used_at IS NULL AND expires_at>? RETURNING owner_email AS ownerEmail, device_id AS deviceId").bind(ahora, await hash(token), ahora).first<{ ownerEmail: string; deviceId: string }>();
  if (!fila) return aLaEntrada();
  const sessionToken = await signSession(fila.ownerEmail, env.SESSION_SECRET, "device");
  const equipo = await env.DB.prepare("SELECT name FROM devices WHERE id=?").bind(fila.deviceId).first<{ name: string }>();
  await sendSecurityNotice(
    env,
    fila.ownerEmail,
    "Ingreso desde la app del tel\u00e9fono",
    "Se abri\u00f3 Ojo Guard MS desde la app Ojo Guard de un tel\u00e9fono vinculado, sin pedir c\u00f3digo ni passkey. Si no fuiste vos, revis\u00e1 los dispositivos del panel.",
    equipo?.name || "Tel\u00e9fono principal",
  ).catch(() => undefined);
  return new Response(null, {
    status: 302,
    headers: {
      location: entrada,
      "cache-control": "no-store",
      "set-cookie": `ojo_ms=${encodeURIComponent(sessionToken)}; HttpOnly; Secure; SameSite=Lax; Path=/; Max-Age=1800`,
    },
  });
}

async function registrationOptions(request: Request, env: Env) {
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
    if (Test-Path ($ruta + ".bak-directo")) { Mal ("Ya existe " + $t + ".bak-directo. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-directo"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-directo): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-directo") -Destination $ruta -Force }
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
Ok "LISTO: el panel quedo publicado. Falta el script de la app (aplicar-acceso-directo-app.ps1) y la build."
Write-Host ""
