# aplicar-mapa-latido-panel.ps1 - Ojo Guard MS: el mapa (en el panel y dentro de la app) trabaja menos y avisa que esta vivo.
# Luciano (11/11/2026): "muchas veces el mapa se tilda y no podes hacer nada, ni zoom ni moverlo; tengo que tocar otro boton de abajo para que vuelva".
# 1) El GPS de quien mira redibujaba todo el mapa cada segundo: ahora solo si te moviste 25 m o pasaron 15 s. 2) Un dibujo que falla ya no corta la actualizacion. 3) Latido hacia la app (la app nueva recarga sola un mapa colgado; la vieja lo ignora).
# Cambia SOLO src\panel-mapa.txt (respaldo .bak-mapa-latido). Va en la carpeta del PANEL (la que tiene wrangler.toml). No necesita build. Al final publica el panel solo.
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
if (-not (Test-Path (Join-Path $raiz "src\panel-mapa.txt"))) { Mal "No encuentro src\panel-mapa.txt en esta carpeta."; return }
$mapaTexto = (Leer (Join-Path $raiz "src\panel-mapa.txt")).texto
if ((Contar $mapaTexto '__ogmLatido') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
$cambios = @(
    @('src\panel-mapa.txt', 'mapa: un dibujo que falla no corta la actualizacion', '  dibujar();
  document.documentElement.classList.remove("abriendo");
  if (!estado.encuadrado && conUbicacion.length) { encuadrarTodo(); estado.encuadrado = true; }
', '  // Si un dibujo falla, la actualizacion automatica igual sigue (antes un solo error cortaba el reloj para siempre).
  try { dibujar(); } catch (error) { console.error("dibujar", error); }
  document.documentElement.classList.remove("abriendo");
  try { if (!estado.encuadrado && conUbicacion.length) { encuadrarTodo(); estado.encuadrado = true; } } catch (error) { console.error("encuadrar", error); }
'),
    @('src\panel-mapa.txt', 'mapa: centrar en el seguido sin cortar la actualizacion', '  if (seguido) estado.proveedor?.centrar(seguido);
', '  try { if (seguido) estado.proveedor?.centrar(seguido); } catch (error) { console.error("centrar", error); }
'),
    @('src\panel-mapa.txt', 'mapa: el GPS de quien mira ya no redibuja sin parar', '      if (!redibujoPendiente) redibujoPendiente = setTimeout(() => { redibujoPendiente = null; dibujar(); }, 800);
', '      // El GPS avisa cada segundo: se redibuja solo si te moviste 25 m o pasaron 15 s (antes era sin parar y en celulares modestos trababa el mapa).
      const antes = estado.yoDibujado;
      const movio = !antes || Math.hypot((pos.coords.latitude - antes.lat) * 111_000, (pos.coords.longitude - antes.lng) * 111_000 * Math.cos((pos.coords.latitude * Math.PI) / 180)) > 25;
      if (!redibujoPendiente && (movio || Date.now() - antes.en > 15_000)) {
        redibujoPendiente = setTimeout(() => {
          redibujoPendiente = null;
          estado.yoDibujado = { lat: pos.coords.latitude, lng: pos.coords.longitude, en: Date.now() };
          dibujar();
        }, 800);
      }
'),
    @('src\panel-mapa.txt', 'mapa: latido para la app', '  activarArrastre(raiz);
  activarAyudaTactil(raiz);
', '  activarArrastre(raiz);
  activarAyudaTactil(raiz);
  // Latido para la app: cada 5 s avisa que la pagina sigue viva. Si deja de llegar, la app vuelve a cargar el mapa sola.
  if (EN_APP && !window.__ogmLatido && window.ReactNativeWebView?.postMessage) {
    window.__ogmLatido = setInterval(() => { try { window.ReactNativeWebView.postMessage(JSON.stringify({ tipo: "latido" })); } catch { /* sigue */ } }, 5000);
  }
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
    if (Test-Path ($ruta + ".bak-mapa-latido")) { Mal ("Ya existe " + $t + ".bak-mapa-latido. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-mapa-latido"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-mapa-latido): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-mapa-latido") -Destination $ruta -Force }
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
Ok "LISTO: el mapa trabaja menos y avisa que esta vivo (recarga la pagina con Ctrl+F5)."
Write-Host ""
