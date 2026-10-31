# aplicar-historial-familia-panel.ps1 - Ojo Guard MS: el recorrido (En vivo, Hoy, 7 dias y Un dia, con las paradas) tambien para las personas de la familia.
# Pedido de Luciano (31/10/2026): los padres (los dos mayores de la cuenta principal) tienen que poder ver el recorrido de sus hijos, igual que el de sus propios telefonos.
# Regla: la de siempre para dar ordenes. El titular y los adultos ven a los menores; el titular ve tambien a los adultos; nadie ve al titular; con la ubicacion pausada no se ve nada.
# Cambia src\index.ts (ruta nueva GET /api/remote/family/location-history), src\panel-mapa.txt y src\panel-index.html (v=10). Respaldo .bak-histfamilia. Va en la carpeta del PANEL. Sin build. Al final publica el panel solo.
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
foreach ($f in @("src\index.ts", "src\panel-mapa.txt", "src\panel-index.html")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'familyLocationHistory') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\panel-index.html")).texto '/mapa-v1.js?v=9') -ne 1) { Mal "El mapa no esta en v=9 (falta aplicar primero aplicar-mapa-otro-dia-v5-panel.ps1). No toco nada."; return }
$cambios = @(
    @('src\index.ts', 'servidor: historial de una persona de la familia', 'async function deviceLocationHistory(request: Request, env: Env, url: URL) {
', '// Historial de ubicaciones de una persona de la familia (mismo formato que location-history). Solo lo ve quien puede darle ordenes a esa persona
// (el titular y los adultos ven a los menores; el titular ve tambien a los adultos; nadie ve al titular) y no si tiene la ubicacion pausada.
// Parametros: personId y limit (hasta 200) o from / to (ISO, hasta 2 dias, hasta 1500 puntos).
async function familyLocationHistory(request: Request, env: Env, url: URL) {
  const sessionInfo = await readSessionInfo(request, env.SESSION_SECRET);
  if (!sessionInfo) return json({ error: "unauthorized" }, 401);
  if (sessionInfo.method === "emergency") return json({ error: "not_allowed_in_emergency" }, 403);
  const personId = url.searchParams.get("personId") ?? "";
  const persona = (await familyPeopleFor(env, sessionInfo.email)).find((p) => p.id === personId);
  if (!persona || persona.canCommand !== true) return json({ error: "not_found" }, 404);
  if (persona.paused) return json({ points: [], paused: true });
  const miembro = await env.DB.prepare("SELECT member_email AS email FROM family_members WHERE id=? AND status=''activo''").bind(personId).first<{ email: string | null }>();
  if (!miembro?.email) return json({ error: "not_found" }, 404);
  const equipo = await env.DB.prepare(
    "SELECT id FROM devices WHERE owner_email=? AND approval_status=''approved'' ORDER BY CASE WHEN device_role=''primary'' THEN 0 ELSE 1 END, COALESCE(last_location_at,'''') DESC LIMIT 1",
  ).bind(miembro.email).first<{ id: string }>();
  if (!equipo) return json({ points: [] });
  const limitParamRaw = url.searchParams.get("limit");
  const limitParam = limitParamRaw === null ? NaN : Number(limitParamRaw);
  const desdeTramo = Date.parse(url.searchParams.get("from") ?? ""), hastaTramo = Date.parse(url.searchParams.get("to") ?? "");
  if (Number.isFinite(desdeTramo) && Number.isFinite(hastaTramo) && hastaTramo > desdeTramo && hastaTramo - desdeTramo <= 2 * 86_400_000) {
    const tope = Number.isFinite(limitParam) ? Math.max(1, Math.min(1500, Math.trunc(limitParam))) : 1500;
    const tramo = await env.DB.prepare(
      "SELECT latitude,longitude,accuracy,altitude,heading,address,captured_at AS capturedAt FROM location_history WHERE device_id=? AND captured_at>=? AND captured_at<? ORDER BY captured_at ASC LIMIT ?",
    ).bind(equipo.id, new Date(desdeTramo).toISOString(), new Date(hastaTramo).toISOString(), tope).all();
    return json({ points: tramo.results });
  }
  const limit = Number.isFinite(limitParam) ? Math.max(1, Math.min(200, Math.trunc(limitParam))) : 50;
  const result = await env.DB.prepare(
    "SELECT latitude,longitude,accuracy,altitude,heading,address,captured_at AS capturedAt FROM location_history WHERE device_id=? ORDER BY captured_at DESC LIMIT ?",
  ).bind(equipo.id, limit).all();
  return json({ points: result.results });
}

async function deviceLocationHistory(request: Request, env: Env, url: URL) {
'),
    @('src\index.ts', 'servidor: ruta del historial de la familia', '      if (route === "GET /api/remote/location-history") return deviceLocationHistory(request, env, url);
', '      if (route === "GET /api/remote/location-history") return deviceLocationHistory(request, env, url);
      if (route === "GET /api/remote/family/location-history") return familyLocationHistory(request, env, url);
'),
    @('src\panel-mapa.txt', 'mapa: las personas que puedes ver tienen recorrido', '      conRecorrido: false,
      pausado: Boolean(p.paused),
', '      // Con el recorrido: quien puede darle ordenes a esa persona (ver familyLocationHistory) y mientras no tenga la ubicacion pausada.
      conRecorrido: Boolean(p.canCommand) && !p.paused,
      pausado: Boolean(p.paused),
'),
    @('src\panel-mapa.txt', 'mapa: de donde se pide el historial', 'async function cargarRecorrido(equipo) {
', '// De donde se pide el historial: tus telefonos o una persona de tu familia.
const rutaHistorial = (equipo) => (esPersona(equipo.id)
  ? `/api/remote/family/location-history?personId=${encodeURIComponent(equipo.id.slice(8))}`
  : `/api/remote/location-history?deviceId=${encodeURIComponent(equipo.id)}`);

async function cargarRecorrido(equipo) {
'),
    @('src\panel-mapa.txt', 'mapa: recorrido (En vivo, Hoy, 7 dias)', '  const datos = await pedir(`/api/remote/location-history?deviceId=${encodeURIComponent(equipo.id)}&limit=${CONFIG.puntosRecorrido}`);
', '  const datos = await pedir(`${rutaHistorial(equipo)}&limit=${CONFIG.puntosRecorrido}`);
'),
    @('src\panel-mapa.txt', 'mapa: recorrido de Un dia', '  const datos = await pedir(`/api/remote/location-history?deviceId=${encodeURIComponent(equipo.id)}&from=${encodeURIComponent(desde.toISOString())}&to=${encodeURIComponent(hasta.toISOString())}&limit=1500`);
', '  const datos = await pedir(`${rutaHistorial(equipo)}&from=${encodeURIComponent(desde.toISOString())}&to=${encodeURIComponent(hasta.toISOString())}&limit=1500`);
'),
    @('src\panel-index.html', 'recargar el mapa nuevo (v=10)', '<script type="module" src="/mapa-v1.js?v=9"></script>', '<script type="module" src="/mapa-v1.js?v=10"></script>')
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
    if (Test-Path ($ruta + ".bak-histfamilia")) { Mal ("Ya existe " + $t + ".bak-histfamilia. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-histfamilia"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-histfamilia): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-histfamilia") -Destination $ruta -Force }
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
Ok "LISTO: el recorrido tambien para las personas de la familia que podes ver. Cerra y abri la app (o recarga la pagina del mapa)."
Write-Host ""
