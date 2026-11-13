# aplicar-mapa-diagnostico-panel.ps1 - Ojo Guard MS: DIAGNOSTICO del mapa dentro de la app (solo panel, sin build).
# Luciano (13/11/2026): en su Android el mapa de la app queda en "Cargando el mapa" y la app lo pide de nuevo cada 15 segundos; el servidor contesta todo bien.
# Hace que la pagina del mapa, solo cuando esta dentro de la app, avise al servidor como va (inicio, Google listo, mapa creado, errores de JS, memoria, si sigue viva). El servidor solo lo escribe en el registro (se ve con wrangler tail): no guarda nada.
# Cambia src\index.ts y src\panel-mapa.txt (respaldo .bak-mapadiag). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
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
foreach ($f in @("src\index.ts", "src\panel-mapa.txt")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'async function mapaDiag') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
$cambios = @(
    @('src\index.ts', 'diagnostico: ruta del mapa en la app', '      if (url.pathname === "/api/remote/por-las-dudas") return pldApiDuenio(request, env);
', '      if (request.method === "POST" && url.pathname === "/api/remote/mapa-diag") return mapaDiag(request, env);
      if (url.pathname === "/api/remote/por-las-dudas") return pldApiDuenio(request, env);
'),
    @('src\index.ts', 'diagnostico: funcion que lo escribe en el registro', 'async function panelHandoffRedeem(request: Request, env: Env, url: URL) {
', '/**
 * POST /api/remote/mapa-diag: diagnostico del mapa dentro de la app. La pagina del mapa (solo dentro de la app) avisa como va la carga y el servidor
 * solo lo escribe en el registro (se ve con `wrangler tail`). Pide sesion, no guarda nada y siempre contesta 204.
 */
async function mapaDiag(request: Request, env: Env) {
  const email = await readSession(request, env.SESSION_SECRET);
  if (email) console.log("mapa-diag", (await request.text().catch(() => "")).slice(0, 600));
  return new Response(null, { status: 204 });
}

async function panelHandoffRedeem(request: Request, env: Env, url: URL) {
'),
    @('src\panel-mapa.txt', 'diagnostico: aviso de inicio, errores y memoria', 'const EN_APP = document.documentElement.classList.contains("app-mapa");
', 'const EN_APP = document.documentElement.classList.contains("app-mapa");
// Diagnostico (solo dentro de la app): la pagina avisa al servidor como va la carga del mapa; se ve con `wrangler tail`. No guarda nada.
const DIAG_T0 = Date.now();
function diag(evento, dato) {
  if (!EN_APP) return;
  try {
    const memoria = performance.memory ? Math.round(performance.memory.usedJSHeapSize / 1048576) : null;
    navigator.sendBeacon("/api/remote/mapa-diag", new Blob([JSON.stringify({ evento, ms: Date.now() - DIAG_T0, dato: String(dato ?? "").slice(0, 200), memMB: memoria })], { type: "application/json" }));
  } catch { /* sigue */ }
}
if (EN_APP) {
  window.addEventListener("error", (e) => diag("error", `${e.message} ${(e.filename || "").split("/").pop()}:${e.lineno}`));
  window.addEventListener("unhandledrejection", (e) => diag("promesa", e.reason?.message ?? e.reason));
  window.gm_authFailure = () => diag("google_clave_rechazada");
  document.addEventListener("visibilitychange", () => diag("visibilidad", document.visibilityState));
  diag("pagina_inicio", navigator.userAgent.slice(0, 120));
  let vivo = 0;
  const relojDiag = setInterval(() => { vivo += 1; diag("vivo", vivo); if (vivo >= 12) clearInterval(relojDiag); }, 5000);
}
'),
    @('src\panel-mapa.txt', 'diagnostico: Google no cargo', '      if (Date.now() - inicio > maxMs) return rechazar(new Error("google_maps_no_cargo"));
', '      if (Date.now() - inicio > maxMs) { diag("google_no_cargo"); return rechazar(new Error("google_maps_no_cargo")); }
'),
    @('src\panel-mapa.txt', 'diagnostico: Google listo', '  const g = await esperarGoogle();
  class Marcador extends g.OverlayView {
', '  const g = await esperarGoogle();
  diag("google_listo");
  class Marcador extends g.OverlayView {
'),
    @('src\panel-mapa.txt', 'diagnostico: mapa creado y tiles', '    backgroundColor: temaInicial === "claro" ? "#f2efe9" : "#16181c",
  });
  const marcadores = new Map();
', '    backgroundColor: temaInicial === "claro" ? "#f2efe9" : "#16181c",
  });
  diag("mapa_creado");
  g.event.addListenerOnce(mapa, "tilesloaded", () => diag("tiles_cargados"));
  const marcadores = new Map();
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
    if (Test-Path ($ruta + ".bak-mapadiag")) { Mal ("Ya existe " + $t + ".bak-mapadiag. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-mapadiag"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-mapadiag): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-mapadiag") -Destination $ruta -Force }
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
Ok "LISTO: el mapa de la app ya avisa como va la carga (se ve con wrangler tail)."
Write-Host ""
