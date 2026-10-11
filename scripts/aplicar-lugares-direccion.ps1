# aplicar-lugares-direccion.ps1 - Lugares: mientras se mueve el mapa para elegir el punto, muestra la calle y la
# altura de donde esta la mira (OpenStreetMap, la misma fuente que usa la notebook). Va en la carpeta del PANEL
# (la que tiene wrangler.toml). Toca src\index.ts y actualiza src\panel-mapa.txt y src\panel-mapa.css.
# Respaldos .bak-direccion. No cambia la base de datos.
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
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'async function remoteAddress') -ne 0) { Avi "La direccion al elegir un lugar ya estaba aplicada. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'async function familyPlacesCheck') -eq 0) { Mal "Primero corre aplicar-familia-lugares.ps1."; return }
if ((Sha (Join-Path $raiz "src\panel-mapa.txt")) -ne "68c2984532b4e87b55c66023f0027c9e9506a8a2b000e2e7b0ab0fb50f3dc4a6") { Mal "src\panel-mapa.txt no es la version que espero. Primero corre aplicar-familia-lugares.ps1."; return }
$cambios = @(
    @('src\index.ts', 'direccion de un punto', '/** Crear o quitar un lugar de tu familia (solo el titular). */
', '/** Calle y altura de un punto (OpenStreetMap), para elegir un lugar justo en el mapa. Solo con sesion. */
async function remoteAddress(request: Request, env: Env, url: URL) {
  const sessionInfo = await readSessionInfo(request, env.SESSION_SECRET);
  if (!sessionInfo) return json({ error: "unauthorized" }, 401);
  const lat = Number(url.searchParams.get("lat")), lng = Number(url.searchParams.get("lng"));
  if (!Number.isFinite(lat) || !Number.isFinite(lng) || Math.abs(lat) > 90 || Math.abs(lng) > 180) return json({ error: "invalid_point" }, 400);
  try {
    // La misma fuente que usa la notebook (ojo_guard_compu.py). Pide identificarse con un User-Agent.
    const respuesta = await fetch(`https://nominatim.openstreetmap.org/reverse?format=jsonv2&zoom=18&addressdetails=1&accept-language=es&lat=${lat.toFixed(6)}&lon=${lng.toFixed(6)}`, {
      headers: { "user-agent": "OjoGuardMS/1.0 (soporte@ojoguard.app)" },
    });
    if (!respuesta.ok) return json({ address: null });
    const datos = await respuesta.json<{ address?: Record<string, string>; display_name?: string }>();
    const a = datos.address ?? {};
    const calle = [a.road || a.pedestrian || a.footway, a.house_number].filter(Boolean).join(" ");
    const barrio = a.suburb || a.neighbourhood || a.city_district || a.city || a.town || "";
    return json({ address: [calle, barrio].filter(Boolean).join(", ") || datos.display_name || null });
  } catch {
    return json({ address: null });
  }
}

/** Crear o quitar un lugar de tu familia (solo el titular). */
'),
    @('src\index.ts', 'ruta de la direccion', '      if (route === "GET /api/remote/family/places" || route === "POST /api/remote/family/places") return remoteFamilyPlaces(request, env);
', '      if (route === "GET /api/remote/family/places" || route === "POST /api/remote/family/places") return remoteFamilyPlaces(request, env);
      if (route === "GET /api/remote/address") return remoteAddress(request, env, url);
')
)
$descargas = @(
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/fb0e511/scripts/mapa/panel-mapa.txt", "src\panel-mapa.txt", "ff7cc3450e3688f509aef8a5c6ad85f9cbe09c19c08801469b7250559197c6bc"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/fb0e511/scripts/mapa/panel-mapa.css", "src\panel-mapa.css", "854defa8badba480f67b51c6cb7c81d7630fa3010250be8a9e3fa472e4dcf152")
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
    if (Test-Path ($ruta + ".bak-direccion")) { Mal ("Ya existe " + $t + ".bak-direccion. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-direccion"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-direccion): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-direccion") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "TODO BIEN en los archivos. Falta publicar:  npx.cmd wrangler deploy"
Write-Host ""
