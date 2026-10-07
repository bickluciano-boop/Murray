# aplicar-mapa.ps1 - Pantalla "Mapa" del panel (base v1): todos los dispositivos en Google Maps, recorrido, paradas y foto de cada equipo
# Va en la carpeta del PANEL (la que tiene wrangler.toml).
# Agrega src\panel-mapa.txt y src\panel-mapa.css (descargados y verificados) y conecta index.ts y panel-index.html.
# Respaldos: index.ts.bak-mapa y panel-index.html.bak-mapa. Si algo falla, se restaura todo.
$ErrorActionPreference = "Continue"
function Ok($t)  { Write-Host ("OK    " + $t) -ForegroundColor Green }
function Mal($t) { Write-Host ("MAL   " + $t) -ForegroundColor Red }
function Avi($t) { Write-Host ("AVISO " + $t) -ForegroundColor Yellow }
$raiz = (Get-Location).Path
if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
function Contar([string]$donde, [string]$que) {
    if ([string]::IsNullOrEmpty($que)) { return 0 }
    $n = 0
    $i = 0
    while ($true) {
        $i = $donde.IndexOf($que, $i, [System.StringComparison]::Ordinal)
        if ($i -lt 0) { break }
        $n = $n + 1
        $i = $i + $que.Length
    }
    return $n
}
function Leer([string]$ruta) {
    $bytes = [System.IO.File]::ReadAllBytes($ruta)
    $bom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    $texto = [System.IO.File]::ReadAllText($ruta, [System.Text.Encoding]::UTF8)
    return @{ texto = $texto; bom = $bom; crlf = $texto.Contains("`r`n") }
}
function Ajustar([string]$t, [bool]$crlf) {
    $x = ($t -replace "`r`n", "`n")
    if ($crlf) { $x = $x -replace "`n", "`r`n" }
    return $x
}
function Lineas([string]$t) { return @($t -split "`r`n|`n").Count }
function Sha([string]$ruta) { return (Get-FileHash -Algorithm SHA256 -LiteralPath $ruta).Hash.ToLower() }

$archIdx = Join-Path $raiz "src\index.ts"
$archHtml = Join-Path $raiz "src\panel-index.html"
$archJs = Join-Path $raiz "src\panel-mapa.txt"
$archCss = Join-Path $raiz "src\panel-mapa.css"
foreach ($a in @($archIdx, $archHtml)) { if (-not (Test-Path $a)) { Mal ("No encuentro " + $a); return } }
$fi = Leer $archIdx
$fh = Leer $archHtml
if ((Contar $fi.texto 'panel-mapa.txt') -ne 0 -or (Contar $fh.texto 'mapa-v1.js') -ne 0) { Avi "El mapa ya estaba aplicado. No toco nada."; return }
if ((Test-Path $archJs) -or (Test-Path $archCss)) { Mal "Ya existen src\panel-mapa.txt o src\panel-mapa.css de un intento anterior. No toco nada. Mandame esta pantalla."; return }

$TA1 = 'import panelJs from "./panel-app.txt";'
$TB1 = Ajustar 'import panelJs from "./panel-app.txt";
import mapaJs from "./panel-mapa.txt";
import mapaCss from "./panel-mapa.css";' $fi.crlf
$TA2 = '      if (["/app.js", "/app-v5.js",'
$TB2 = Ajustar '      if (url.pathname === "/mapa-v1.js") return staticResponse(mapaJs, "application/javascript; charset=utf-8");
      if (url.pathname === "/mapa-v1.css") return staticResponse(mapaCss, "text/css; charset=utf-8");
      if (["/app.js", "/app-v5.js",' $fi.crlf
$TA3 = '      if (route === "GET /api/remote/location-history") return deviceLocationHistory(request, env, url);'
$TB3 = Ajustar '      if (route === "GET /api/remote/location-history") return deviceLocationHistory(request, env, url);
      if (route === "GET /api/remote/devices/photo") return devicePhoto(request, env, url);
      if (route === "POST /api/remote/devices/photo") return saveDevicePhoto(request, env);' $fi.crlf
$TA4 = 'const HISTORY_EMAIL_POINT_COUNT = 10;'
$TB4 = Ajustar '// Foto de cada dispositivo para el mapa del panel (256x256, JPEG). Se guarda en el
// mismo KV de las evidencias, separada por titular, sin tocar la base de datos.
const devicePhotoKey = (email: string, deviceId: string) => `fotos-equipos/${email.replace(/[^a-z0-9@._-]/gi, "_")}/${deviceId.replace(/[^a-z0-9_-]/gi, "_")}`;

async function devicePhoto(request: Request, env: Env, url: URL) {
  const email = await readSession(request, env.SESSION_SECRET);
  if (!email) return json({ error: "unauthorized" }, 401);
  const deviceId = url.searchParams.get("deviceId") ?? "";
  const owns = await env.DB.prepare("SELECT id FROM devices WHERE id=? AND owner_email=?").bind(deviceId, email).first();
  if (!owns || !env.EVIDENCE_FILES) return json({ error: "photo_not_found" }, 404);
  const bytes = await env.EVIDENCE_FILES.get(devicePhotoKey(email, deviceId), "arrayBuffer");
  if (!bytes) return json({ error: "photo_not_found" }, 404);
  return new Response(bytes, { headers: { "content-type": "image/jpeg", "cache-control": "private, max-age=86400", "x-content-type-options": "nosniff" } });
}

async function saveDevicePhoto(request: Request, env: Env) {
  const sessionInfo = await readSessionInfo(request, env.SESSION_SECRET);
  if (!sessionInfo) return json({ error: "unauthorized" }, 401);
  if (sessionInfo.method === "emergency") return json({ error: "not_allowed_in_emergency" }, 403);
  if (!env.EVIDENCE_FILES) return json({ error: "storage_unavailable" }, 503);
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const deviceId = String(body.deviceId ?? "");
  const owns = await env.DB.prepare("SELECT id FROM devices WHERE id=? AND owner_email=?").bind(deviceId, sessionInfo.email).first();
  if (!owns) return json({ error: "device_not_found" }, 404);
  const key = devicePhotoKey(sessionInfo.email, deviceId);
  if (body.remove === true) {
    await env.EVIDENCE_FILES.delete(key);
    return json({ removed: true });
  }
  const match = String(body.image ?? "").match(/^data:image\/jpeg;base64,([A-Za-z0-9+/=]+)$/);
  if (!match || match[1].length > 400_000) return json({ error: "invalid_image" }, 400);
  await env.EVIDENCE_FILES.put(key, decodeBase64(match[1]));
  return json({ saved: true });
}

const HISTORY_EMAIL_POINT_COUNT = 10;' $fi.crlf
$Tpares = @(@("modulos del mapa", $TA1, $TB1), @("archivos del mapa", $TA2, $TB2), @("rutas de fotos", $TA3, $TB3), @("funciones de fotos", $TA4, $TB4))
$HA1 = '    <link rel="stylesheet" href="/theme-light-v1.css" />'
$HB1 = Ajustar '    <link rel="stylesheet" href="/theme-light-v1.css" />
    <link rel="stylesheet" href="/mapa-v1.css" />' $fh.crlf
$HA2 = '    <script type="module" src="/app-v9.js?v=7"></script>'
$HB2 = Ajustar '    <script type="module" src="/app-v9.js?v=7"></script>
    <script type="module" src="/mapa-v1.js?v=1"></script>' $fh.crlf
$Hpares = @(@("estilos del mapa", $HA1, $HB1), @("script del mapa", $HA2, $HB2))
$ok = $true
foreach ($p in $Tpares) { $cuantos = Contar $fi.texto $p[1]; if ($cuantos -eq 1) { Ok ("index.ts: " + $p[0] + ": 1") } else { Mal ("index.ts: " + $p[0] + ": " + $cuantos + " (esperaba 1)"); $ok = $false } }
foreach ($p in $Hpares) { $cuantos = Contar $fh.texto $p[1]; if ($cuantos -eq 1) { Ok ("panel-index.html: " + $p[0] + ": 1") } else { Mal ("panel-index.html: " + $p[0] + ": " + $cuantos + " (esperaba 1)"); $ok = $false } }
if (-not $ok) { Mal "Alguna ancla no coincide. No toco nada. Mandame esta pantalla."; return }

# Descargar los dos archivos nuevos y verificar que llegaron completos
$base = "https://raw.githubusercontent.com/bickluciano-boop/Murray/2c308df/scripts/mapa/"
$descargas = @(@("panel-mapa.txt", $archJs, "7c1cc331240cbf25299b1d7151c3360bb0da9ff9901dcbf99912256e6cd88b7a"), @("panel-mapa.css", $archCss, "dd344822bd52c044c59bf8813413e41d40f7af107eedf686f5ea5ebb45d1b9ad"))
foreach ($d in $descargas) {
    try { Invoke-WebRequest -UseBasicParsing ($base + $d[0]) -OutFile $d[1] } catch { }
    if ((Test-Path $d[1]) -and ((Sha $d[1]) -eq $d[2])) { Ok ("Descargado y verificado: src\" + $d[0]) }
    else {
        Mal ("No se pudo descargar bien " + $d[0] + ". No toco nada mas.")
        foreach ($x in $descargas) { if (Test-Path $x[1]) { Remove-Item -LiteralPath $x[1] -Force } }
        return
    }
}

$bakI = $archIdx + ".bak-mapa"
$bakH = $archHtml + ".bak-mapa"
if ((Test-Path $bakI) -or (Test-Path $bakH)) { Mal "Ya existe un respaldo .bak-mapa. No toco nada."; foreach ($x in $descargas) { Remove-Item -LiteralPath $x[1] -Force }; return }
Copy-Item -LiteralPath $archIdx -Destination $bakI
Copy-Item -LiteralPath $archHtml -Destination $bakH
Ok "Respaldos creados (index.ts.bak-mapa, panel-index.html.bak-mapa)"

$nuevoI = $fi.texto; $espI = 0
foreach ($p in $Tpares) { $nuevoI = $nuevoI.Replace($p[1], $p[2]); $espI = $espI + ($p[2].Length - $p[1].Length) }
$nuevoH = $fh.texto; $espH = 0
foreach ($p in $Hpares) { $nuevoH = $nuevoH.Replace($p[1], $p[2]); $espH = $espH + ($p[2].Length - $p[1].Length) }
[System.IO.File]::WriteAllText($archIdx, $nuevoI, (New-Object System.Text.UTF8Encoding($fi.bom)))
[System.IO.File]::WriteAllText($archHtml, $nuevoH, (New-Object System.Text.UTF8Encoding($fh.bom)))

$vi = Leer $archIdx
$vh = Leer $archHtml
$todoBien = $true
function Chk([string]$que, [bool]$cond) { if ($cond) { Ok $que } else { Mal $que; $script:todoBien = $false } }
foreach ($p in $Tpares) { Chk ("index.ts: " + $p[0] + " aplicado") ((Contar $vi.texto $p[2]) -eq 1) }
foreach ($p in $Hpares) { Chk ("panel-index.html: " + $p[0] + " aplicado") ((Contar $vh.texto $p[2]) -eq 1) }
Chk "index.ts: correos y panel siguen" (((Contar $vi.texto 'function fetchCorreo') -eq 1) -and ((Contar $vi.texto 'function fechaCorreo') -eq 1) -and ((Contar $vi.texto 'import panelHtml from') -eq 1))
Chk ("index.ts: largo +" + ($vi.texto.Length - $fi.texto.Length) + " (esperado +" + $espI + ")") (($vi.texto.Length - $fi.texto.Length) -eq $espI)
Chk ("index.ts: lineas +" + ((Lineas $vi.texto) - (Lineas $fi.texto)) + " (esperado +41)") (((Lineas $vi.texto) - (Lineas $fi.texto)) -eq 41)
Chk ("panel-index.html: largo +" + ($vh.texto.Length - $fh.texto.Length) + " (esperado +" + $espH + ")") (($vh.texto.Length - $fh.texto.Length) -eq $espH)
Chk ("panel-index.html: lineas +" + ((Lineas $vh.texto) - (Lineas $fh.texto)) + " (esperado +2)") (((Lineas $vh.texto) - (Lineas $fh.texto)) -eq 2)
if (-not $todoBien) {
    Mal "Algo no salio bien. Restauro todo desde los respaldos."
    Copy-Item -LiteralPath $bakI -Destination $archIdx -Force
    Copy-Item -LiteralPath $bakH -Destination $archHtml -Force
    foreach ($x in $descargas) { if (Test-Path $x[1]) { Remove-Item -LiteralPath $x[1] -Force } }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "TODO BIEN en los archivos. Falta PUBLICAR: powershell -ExecutionPolicy Bypass -Command ""npx wrangler deploy"""
Write-Host ""
