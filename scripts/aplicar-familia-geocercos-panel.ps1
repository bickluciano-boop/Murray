# aplicar-familia-geocercos-panel.ps1 - Avisos de llegada y salida confiables en iPhone, parte del servidor.
# Suma una direccion que le dice a cada telefono que circulos vigilar (los lugares de los avisos armados sobre esa persona)
# y evita que un aviso salga duplicado cuando el telefono manda la ubicacion por dos caminos a la vez.
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Toca src\index.ts. Respaldo .bak-geocercos.
# No cambia la base de datos. Despues hay que publicar (npx.cmd wrangler deploy).
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
if ((Contar $indexTexto 'async function nativeFamilyRegions') -ne 0) { Avi "Los geocercos ya estaban aplicados en el servidor. No toco nada."; return }
if ((Contar $indexTexto 'async function remoteFamilyAlerts') -eq 0) { Mal "Primero corre aplicar-familia-avisos-persona.ps1."; return }
$cambios = @(
    @('src\index.ts', 'lugares para vigilar', 'async function pushTokensOf(env: Env, email: string) {
', '/**
 * Los circulos que este telefono tiene que vigilar: los lugares de los avisos que alguien armo sobre esta persona
 * ("avisame cuando X llegue o salga de Casa"). El iPhone los registra como geocercos del sistema y despierta a la app
 * al cruzarlos, aunque este cerrada; la app manda entonces su ubicacion y el servidor decide si hay aviso (familyAlertsCheck).
 * Por cada lugar vuelve el circulo (para avisar al entrar) y uno un poco mas grande (para avisar al salir): el margen
 * es el mismo que usa familyAlertsCheck para dar por terminada la estadia. Solo el telefono principal de la persona,
 * que es el que cuenta para los avisos.
 */
async function nativeFamilyRegions(request: Request, env: Env, url: URL) {
  const deviceId = url.searchParams.get("deviceId") ?? "";
  if (!await requireNative(request, env, deviceId)) return json({ error: "unauthorized" }, 401);
  const device = await env.DB.prepare("SELECT owner_email AS email FROM devices WHERE id=? AND approval_status=''approved''").bind(deviceId).first<{ email: string }>();
  if (!device) return json({ regions: [] });
  const principal = await env.DB.prepare("SELECT id FROM devices WHERE owner_email=? AND approval_status=''approved'' ORDER BY CASE WHEN device_role=''primary'' THEN 0 ELSE 1 END, COALESCE(last_location_at,'''') DESC LIMIT 1")
    .bind(device.email).first<{ id: string }>();
  if (principal?.id !== deviceId) return json({ regions: [] });
  const avisos = await env.DB.prepare("SELECT id,latitude,longitude,radius FROM family_alerts WHERE target_email=? ORDER BY created_at LIMIT 40")
    .bind(device.email).all<{ id: string; latitude: number; longitude: number; radius: number }>();
  // Varios avisos sobre el mismo lugar (mismo centro y radio) comparten circulo.
  const vistos = new Set<string>();
  const regions: { id: string; latitude: number; longitude: number; radius: number; outerRadius: number }[] = [];
  for (const aviso of avisos.results) {
    const clave = `${aviso.latitude.toFixed(5)}|${aviso.longitude.toFixed(5)}|${aviso.radius}`;
    if (vistos.has(clave)) continue;
    vistos.add(clave);
    regions.push({ id: aviso.id, latitude: aviso.latitude, longitude: aviso.longitude, radius: aviso.radius, outerRadius: aviso.radius + PLACE_EXIT_MARGIN + 15 });
  }
  return json({ regions });
}

async function pushTokensOf(env: Env, email: string) {
'),
    @('src\index.ts', 'ruta de los lugares para vigilar', '      if (route === "GET /api/native/family") return nativeFamily(request, env, url);
', '      if (route === "GET /api/native/family") return nativeFamily(request, env, url);
      if (route === "GET /api/native/family/regions") return nativeFamilyRegions(request, env, url);
'),
    @('src\index.ts', 'un solo aviso por cambio', '    await env.DB.prepare("UPDATE family_alerts SET inside=? WHERE id=?").bind(adentro ? 1 : 0, aviso.id).run();
    if (primeraVez) continue;
', '    // Si dos pedidos llegan a la vez (el iPhone manda la misma ubicacion por dos caminos), solo el primero cambia el
    // estado y avisa: el segundo ya no encuentra el estado que leyo y sigue de largo.
    const cambio = await env.DB.prepare("UPDATE family_alerts SET inside=? WHERE id=? AND inside IS ?").bind(adentro ? 1 : 0, aviso.id, aviso.inside).run();
    if (!cambio.meta.changes) continue;
    if (primeraVez) continue;
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
    if (Test-Path ($ruta + ".bak-geocercos")) { Mal ("Ya existe " + $t + ".bak-geocercos. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-geocercos"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-geocercos): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-geocercos") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "TODO BIEN en los archivos. Falta un paso: npx.cmd wrangler deploy"
Write-Host ""
