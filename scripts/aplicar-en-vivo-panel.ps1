# aplicar-en-vivo-panel.ps1 - Modo EN VIVO, parte del servidor y del panel (boton "Seguir en vivo" en el mapa)
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Respaldos .bak-envivo; si algo falla, se restaura todo.
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
if (-not (Test-Path (Join-Path $raiz "src\panel-mapa.txt"))) { Mal "Falta el mapa del panel: primero corre aplicar-mapa.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'async function remoteLive') -ne 0) { Avi "El modo en vivo ya estaba aplicado en el servidor. No toco nada."; return }
$cambios = @(
    @('src\index.ts', 'tipo de orden en vivo', 'type CommandType = "alarm" | "stop-ring" | "lost" | "lost-off" | "locate" | "capture-evidence" | "scan-nearby" | "auto-locate";', 'type CommandType = "alarm" | "stop-ring" | "lost" | "lost-off" | "locate" | "capture-evidence" | "scan-nearby" | "auto-locate" | "live";'),
    @('src\index.ts', 'aviso push en vivo', '    "auto-locate": { title: "", body: "", kind: "locate" },', '    "auto-locate": { title: "", body: "", kind: "locate" },
    // En vivo: el aviso visible lo pone el propio telefono (la notificacion fija del seguimiento).
    live: { title: "", body: "", kind: "live" },'),
    @('src\index.ts', 'push silencioso en vivo', '  if (type !== "auto-locate") {', '  if (type !== "auto-locate" && type !== "live") {'),
    @('src\index.ts', 'avisos por correo', '    "auto-locate": ["", ""],', '    "auto-locate": ["", ""],
    // Se crea desde remoteLive(), no desde aca.
    live: ["", ""],'),
    @('src\index.ts', 'rutas en vivo', '      if (route === "POST /api/native/device/status") return nativeDeviceStatus(request, env);', '      if (route === "POST /api/native/device/status") return nativeDeviceStatus(request, env);
      if (route === "POST /api/native/location") return nativeLiveLocation(request, env);
      if (route === "POST /api/remote/live") return remoteLive(request, env);'),
    @('src\index.ts', 'funciones en vivo', 'async function nativeDeviceStatus(request: Request, env: Env) {', '// ---------------------------------------------------------------------------
// Ubicacion EN VIVO (mapa del panel -> "Seguir en vivo").
// El panel abre una sesion de unos minutos; el telefono recibe una orden `live`
// (push silencioso, como la ubicacion automatica) y desde ahi manda un punto cada
// pocos segundos a /api/native/location. Mientras el mapa siga abierto, el panel
// la renueva; al cerrarlo la corta. Cada punto vuelve con `live` y `until`, asi el
// telefono sabe solo cuando apagar el GPS.
const LIVE_MINUTES = 10;
// El recorrido no necesita un punto cada 5 segundos: se guarda uno cada 30 s o
// cada 25 m de movimiento. La ultima ubicacion (la del marcador) se pisa siempre.
const LIVE_HISTORY_SECONDS = 30;
const LIVE_HISTORY_METERS = 25;

function metersBetween(a: { latitude: number; longitude: number }, b: { latitude: number; longitude: number }) {
  const R = 6371000, rad = Math.PI / 180;
  const dLat = (b.latitude - a.latitude) * rad, dLng = (b.longitude - a.longitude) * rad;
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(a.latitude * rad) * Math.cos(b.latitude * rad) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

async function remoteLive(request: Request, env: Env) {
  const sessionInfo = await readSessionInfo(request, env.SESSION_SECRET);
  if (!sessionInfo) return json({ error: "unauthorized" }, 401);
  const { email } = sessionInfo;
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const deviceId = String(body.deviceId ?? "");
  const device = await env.DB.prepare("SELECT id,name,push_token AS pushToken FROM devices WHERE id=? AND owner_email=? AND approval_status=''approved''")
    .bind(deviceId, email).first<{ id: string; name: string; pushToken: string | null }>();
  if (!device) return json({ error: "device_not_found" }, 404);
  const ahora = now();
  if (body.action === "stop") {
    await env.DB.prepare("UPDATE commands SET expires_at=? WHERE device_id=? AND owner_email=? AND type=''live'' AND expires_at>?")
      .bind(ahora, deviceId, email, ahora).run();
    return json({ live: false });
  }
  const until = plusMinutes(LIVE_MINUTES);
  const activa = await env.DB.prepare("SELECT id,status,created_at AS createdAt FROM commands WHERE device_id=? AND owner_email=? AND type=''live'' AND status<>''failed'' AND expires_at>? ORDER BY created_at DESC LIMIT 1")
    .bind(deviceId, email, ahora).first<{ id: string; status: string; createdAt: string }>();
  if (activa) {
    await env.DB.prepare("UPDATE commands SET expires_at=? WHERE id=?").bind(until, activa.id).run();
    // Si el telefono todavia no la vio (push perdido, reposo de Android), se le vuelve a avisar.
    const pushSent = activa.status === "pending"
      ? await sendExpoCommandPush(device.pushToken, "live", activa.id, device.name).catch(() => false)
      : false;
    return json({ live: true, until, commandId: activa.id, status: activa.status, renewed: true, pushSent });
  }
  const id = randomId("cmd");
  await env.DB.prepare("INSERT INTO commands (id,device_id,owner_email,type,status,created_at,expires_at) VALUES (?,?,?,?,?,?,?)")
    .bind(id, deviceId, email, "live", "pending", ahora, until).run();
  const pushSent = await sendExpoCommandPush(device.pushToken, "live", id, device.name).catch(() => false);
  return json({ live: true, until, commandId: id, status: "pending", pushSent }, 202);
}

async function nativeLiveLocation(request: Request, env: Env) {
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const deviceId = String(body.deviceId ?? "");
  if (!deviceId || !await requireNative(request, env, deviceId)) return json({ error: "unauthorized" }, 401);
  const ahora = now();
  const location = body.location && typeof body.location === "object" ? body.location as Record<string, unknown> : null;
  const row = location ? locationHistoryRow(location) : null;
  if (location && row) {
    await env.DB.prepare("UPDATE devices SET last_location_json=?,last_location_at=?,last_seen_at=? WHERE id=?")
      .bind(JSON.stringify(location), ahora, ahora, deviceId).run();
    const previo = await env.DB.prepare("SELECT latitude,longitude,captured_at AS capturedAt FROM location_history WHERE device_id=? ORDER BY captured_at DESC LIMIT 1")
      .bind(deviceId).first<{ latitude: number; longitude: number; capturedAt: string }>();
    const guardar = !previo
      || Date.parse(String(row.capturedAt)) - Date.parse(previo.capturedAt) >= LIVE_HISTORY_SECONDS * 1000
      || metersBetween(previo, { latitude: Number(row.latitude), longitude: Number(row.longitude) }) >= LIVE_HISTORY_METERS;
    if (guardar) {
      await env.DB.prepare(
        "INSERT INTO location_history (id,device_id,latitude,longitude,accuracy,altitude,heading,address,captured_at,created_at) VALUES (?,?,?,?,?,?,?,?,?,?)",
      ).bind(
        randomId("loc"), deviceId, row.latitude, row.longitude,
        row.accuracy, row.altitude, row.heading, row.address, row.capturedAt, ahora,
      ).run();
    }
  }
  const activa = await env.DB.prepare("SELECT expires_at AS expiresAt FROM commands WHERE device_id=? AND type=''live'' AND status<>''failed'' AND expires_at>? ORDER BY expires_at DESC LIMIT 1")
    .bind(deviceId, ahora).first<{ expiresAt: string }>();
  return json({ live: Boolean(activa), until: activa?.expiresAt ?? null });
}

async function nativeDeviceStatus(request: Request, env: Env) {')
)
$descargas = @(
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/a4264a8/scripts/mapa/panel-mapa.txt", "src\panel-mapa.txt", "d0483f483b23a974567c4427001c09f5be0a8fc3da4ff9f1b0bafaf849d92bdb"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/a4264a8/scripts/mapa/panel-mapa.css", "src\panel-mapa.css", "c2aeeff51b44d40e33d547c050b853a2a7c81d69ac00ff6851f456377f53b074")
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
    if (Test-Path ($ruta + ".bak-envivo")) { Mal ("Ya existe " + $t + ".bak-envivo. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-envivo"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-envivo): " + ($respaldados -join ", "))

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
Chk "index.ts: correos, mapa y fotos siguen" (((Contar $vi 'function fetchCorreo') -eq 1) -and ((Contar $vi 'panel-mapa.txt') -eq 1) -and ((Contar $vi 'async function saveDevicePhoto') -eq 1))

if (-not $todoBien) {
    Mal "Algo no salio bien. Restauro todo desde los respaldos."
    foreach ($t in $tocados) {
        $ruta = Join-Path $raiz $t
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-envivo") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "TODO BIEN en los archivos. Falta PUBLICAR: powershell -ExecutionPolicy Bypass -Command ""npx wrangler deploy"""
Write-Host ""
