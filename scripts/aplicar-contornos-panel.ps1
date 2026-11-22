# aplicar-contornos-panel.ps1 - Ojo Guard MS (panel): ruta GET /api/rvi/buildings que consulta los contornos de edificios de OpenStreetMap y los guarda en cache 30 dias.
# Para que el visor de prueba con Google 3D (visor-3d-real.html) no dependa del servicio publico de OpenStreetMap, que a veces esta saturado.
#  - Solo agrega una ruta nueva. No toca el mapa, los pines, los equipos ni nada de lo existente. No guarda datos de nadie: solo formas de edificios.
#  - Pide un codigo propio (secreto RVI_TOKEN) que este instalador inventa al azar, guarda en el panel y deja COPIADO en el portapapeles (no se muestra). Se pega en el visor.
#  - Cambia SOLO src\index.ts (respaldo .bak-contornos). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final carga el secreto y publica el panel solo.
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
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'async function rviContornos') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
$cambios = @(
    @('src\index.ts', 'contornos: funcion que consulta y guarda en cache', 'async function deviceLocationHistory(request: Request, env: Env, url: URL) {
', '// Contornos de edificios para el visor de prueba con Google 3D. Consulta OpenStreetMap (Overpass) una sola vez por zona de ~100 m y guarda la respuesta 30 dias en la cache del Worker:
// asi el visor no depende de que el servicio publico este libre. Pide el codigo propio RVI_TOKEN (secreto, no es la clave de Google). No guarda nada de nadie: solo formas de edificios.
const RVI_SERVIDORES = ["https://overpass-api.de/api/interpreter", "https://overpass.private.coffee/api/interpreter", "https://overpass.kumi.systems/api/interpreter"];
function rviRespuesta(cuerpo: unknown, status: number, extra: Record<string, string> = {}) {
  return new Response(JSON.stringify(cuerpo), { status, headers: { "content-type": "application/json; charset=utf-8", "access-control-allow-origin": "*", "cache-control": "no-store", ...extra } });
}
async function rviContornos(request: Request, env: Env, url: URL) {
  const secreto = String((env as unknown as { RVI_TOKEN?: string }).RVI_TOKEN ?? "");
  if (secreto.length < 16) return rviRespuesta({ error: "not_configured" }, 404);
  const dado = String(url.searchParams.get("k") ?? "");
  let dif = secreto.length ^ dado.length;
  for (let i = 0; i < secreto.length; i++) dif |= secreto.charCodeAt(i) ^ (dado.charCodeAt(i) || 0);
  if (dif !== 0) return rviRespuesta({ error: "forbidden" }, 403);
  const lat = Number(url.searchParams.get("lat")), lon = Number(url.searchParams.get("lon"));
  if (!Number.isFinite(lat) || !Number.isFinite(lon) || lat < -56 || lat > -21 || lon < -74 || lon > -53) return rviRespuesta({ error: "out_of_range" }, 400);
  const la = Math.round(lat * 1000) / 1000, lo = Math.round(lon * 1000) / 1000;
  const llave = new Request("https://cache.ojoguard.app/rvi/contornos?lat=" + la + "&lon=" + lo);
  const cache = (caches as unknown as { default: Cache }).default;
  const guardado = await cache.match(llave);
  if (guardado) return rviRespuesta(await guardado.json(), 200, { "x-rvi-cache": "hit" });
  const consulta = "[out:json][timeout:20];way[\"building\"](around:130," + la + "," + lo + ");out tags geom;";
  const motivos: string[] = [];
  for (const servidor of RVI_SERVIDORES) {
    const host = servidor.split("/")[2];
    try {
      const ctl = new AbortController();
      const reloj = setTimeout(() => ctl.abort(), 14000);
      const r = await fetch(servidor, { method: "POST", headers: { "content-type": "application/x-www-form-urlencoded", "user-agent": "OjoGuardPanel/1.0 (contornos de edificios, uso interno)" }, body: "data=" + encodeURIComponent(consulta), signal: ctl.signal });
      clearTimeout(reloj);
      if (!r.ok) { motivos.push(host + " " + r.status); continue; }
      const datos = await r.json<{ elements?: Array<{ id?: number; tags?: Record<string, string>; geometry?: Array<{ lat: number; lon: number }> }> }>();
      const permitidos = ["building", "building:levels", "height", "name", "addr:housename"];
      const elements = (datos.elements ?? []).filter((e) => e.geometry && e.geometry.length >= 3).map((e) => ({
        id: e.id,
        tags: Object.fromEntries(Object.entries(e.tags ?? {}).filter(([k]) => permitidos.includes(k))),
        geometry: e.geometry,
      }));
      const cuerpo = { elements };
      await cache.put(llave, new Response(JSON.stringify(cuerpo), { headers: { "content-type": "application/json", "cache-control": "public, max-age=2592000" } }));
      return rviRespuesta(cuerpo, 200, { "x-rvi-cache": "miss" });
    } catch (e) { motivos.push(host + (e instanceof Error && e.name === "AbortError" ? " tardo demasiado" : " no respondio")); }
  }
  return rviRespuesta({ error: "overpass_busy", detail: motivos.join("; ") }, 503);
}

async function deviceLocationHistory(request: Request, env: Env, url: URL) {
'),
    @('src\index.ts', 'contornos: ruta GET /api/rvi/buildings', '      if (route === "GET /api/remote/location-history") return deviceLocationHistory(request, env, url);
', '      if (route === "GET /api/remote/location-history") return deviceLocationHistory(request, env, url);
      if (route === "GET /api/rvi/buildings") return rviContornos(request, env, url);
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
    if (Test-Path ($ruta + ".bak-contornos")) { Mal ("Ya existe " + $t + ".bak-contornos. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-contornos"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-contornos): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-contornos") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "Archivos listos. Ahora publico el panel..."
Write-Host "Creando el codigo propio del visor (secreto RVI_TOKEN)..."
$bytesRvi = New-Object byte[] 24
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create(); $rng.GetBytes($bytesRvi); $rng.Dispose()
$codigoRvi = ([System.BitConverter]::ToString($bytesRvi)).Replace("-", "").ToLower()
$salidaSecreto = ($codigoRvi | & npx.cmd wrangler secret put RVI_TOKEN 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0) {
    Write-Host $salidaSecreto
    foreach ($t in $tocados) { $ruta = Join-Path $raiz $t; if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-contornos") -Destination $ruta -Force } }
    Mal "No se pudo guardar el secreto. Deje todo como estaba. Mandame esta pantalla."; return
}
Ok "Secreto guardado"
& npx.cmd wrangler deploy
if ($LASTEXITCODE -ne 0) { Mal "No se pudo publicar el panel. Mandame esta pantalla."; return }
Write-Host ""
try { Set-Clipboard -Value $codigoRvi } catch { }
Write-Host ""
Write-Host "Probando la ruta nueva (sin mostrar el codigo)..."
$estadoRvi = "sin respuesta"
for ($intento = 1; $intento -le 4; $intento++) {
    try {
        $resp = Invoke-WebRequest -UseBasicParsing -TimeoutSec 40 -Uri ("https://ojoguard.app/api/rvi/buildings?lat=-34.6037&lon=-58.3816&k=" + $codigoRvi)
        $estadoRvi = "HTTP " + $resp.StatusCode + " (cache: " + $resp.Headers["x-rvi-cache"] + ")"; break
    } catch {
        $codigoHttp = ""; try { $codigoHttp = [int]$_.Exception.Response.StatusCode } catch { }
        $estadoRvi = "HTTP " + $codigoHttp; if ($codigoHttp -eq 403 -or $codigoHttp -eq 404) { break }
        Start-Sleep -Seconds 5
    }
}
Write-Host ("      Prueba de la ruta: " + $estadoRvi)
Ok "LISTO: el panel ya tiene la ruta de contornos."
Write-Host "      El codigo del visor quedo COPIADO en el portapapeles (no se muestra aca)." -ForegroundColor Cyan
Write-Host "      Abri el visor nuevo y pegalo en el campo 'Codigo del panel'. No me lo mandes por el chat." -ForegroundColor Yellow
Write-Host ""
