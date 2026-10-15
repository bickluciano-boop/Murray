# aplicar-panel-sin-saltos-panel.ps1 - Abrir el panel desde la app, sin los saltos que se veian.
# Pedido de Luciano (15/10/2026): al apretar "Abrir panel" en la app se veia un instante la pantalla de acceso ("Entra a tu cuenta") y despues el
# panel con el mapa todavia vacio, antes de llegar al mapa con la gente. Ahora, cuando se entra directo desde la app, se muestra una pantalla
# "Abriendo Ojo Guard MS..." (sin parpadeos) hasta que el mapa dibuja. Si no hubiera sesion, desaparece sola y queda el acceso de siempre.
# Vale para el boton "Panel" (consola completa, que ahora entra como /acceso-v7?directo=1) y para el mapa dentro de la app (?app=mapa).
# Nada cambia al entrar por tu cuenta (sin "directo"). Requiere aplicar-mapa-en-app-panel.ps1. Va en la carpeta del PANEL (la que tiene
# wrangler.toml). Toca src\index.ts, src\panel-index.html, src\panel-app.txt, src\panel-mapa.txt y src\panel-explanations.css. Respaldo
# .bak-sinpasos. Al final publica el panel solo.
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
foreach ($f in @("src\index.ts", "src\panel-index.html", "src\panel-app.txt", "src\panel-mapa.txt", "src\panel-explanations.css")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
$indexTexto = (Leer (Join-Path $raiz "src\index.ts")).texto
if ((Contar $indexTexto '/acceso-v7?directo=1') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $indexTexto 'panel_handoff_aviso') -eq 0) { Mal "Falta aplicar antes el mapa dentro de la app (aplicar-mapa-en-app-panel.ps1)."; return }
if ((Contar (Leer (Join-Path $raiz "src\panel-explanations.css")).texto '/* Botones en pastilla (como el dibujo de la consola). */') -ne 1) { Mal "Falta aplicar antes los pasos de la consola (pestanas, ayudas, equipos)."; return }
$cambios = @(
    @('src\index.ts', 'acceso directo a la consola: entra marcado como directo', '      location: fila.purpose === "mapa" ? "/acceso-v7?app=mapa" : entrada,', '      location: fila.purpose === "mapa" ? "/acceso-v7?app=mapa" : "/acceso-v7?directo=1",'),
    @('src\panel-index.html', 'pantalla de espera mientras se entra directo', 'if (/[?&]app=mapa(&|$)/.test(location.search)) document.documentElement.classList.add("app-mapa");', 'if (/[?&]app=mapa(&|$)/.test(location.search)) document.documentElement.classList.add("app-mapa");
      /* Entrando directo desde la app (?directo=1 o ?app=mapa): se muestra "Abriendo Ojo Guard MS..." hasta que el mapa dibuja, en vez de dejar ver
         un instante la pantalla de acceso y el panel vacio. Si algo tarda de mas, a los 6 segundos se saca sola. */
      if (/[?&](directo|app)=/.test(location.search)) {
        document.documentElement.classList.add("abriendo");
        setTimeout(function () { document.documentElement.classList.remove("abriendo"); }, 6000);
        if (/[?&]directo=1(&|$)/.test(location.search)) { try { history.replaceState(null, "", location.pathname); } catch (e) { /* sin historial */ } }
      }'),
    @('src\panel-app.txt', 'pantalla de espera: se saca si no hay sesion', '    try { window.ReactNativeWebView?.postMessage(JSON.stringify({ tipo: "sin_sesion" })); } catch { /* en el navegador no existe */ }', '    try { window.ReactNativeWebView?.postMessage(JSON.stringify({ tipo: "sin_sesion" })); } catch { /* en el navegador no existe */ }
    document.documentElement.classList.remove("abriendo");'),
    @('src\panel-mapa.txt', 'pantalla de espera: se saca cuando el mapa dibuja', '  dibujar();
  if (!estado.encuadrado && conUbicacion.length) { encuadrarTodo(); estado.encuadrado = true; }', '  dibujar();
  document.documentElement.classList.remove("abriendo");
  if (!estado.encuadrado && conUbicacion.length) { encuadrarTodo(); estado.encuadrado = true; }'),
    @('src\panel-explanations.css', 'pantalla de espera: estilos', '/* Botones en pastilla (como el dibujo de la consola). */', '/* Entrando directo desde la app: "Abriendo Ojo Guard MS..." hasta que el mapa dibuja (sin el parpadeo del acceso ni del panel vacio). */
html.abriendo #access,
html.abriendo #dashboard { visibility: hidden; }
html.abriendo body::after {
  content: "Abriendo Ojo Guard MS\2026";
  position: fixed; inset: 0; z-index: 90;
  display: grid; place-items: center;
  background: #050607; color: #d9b24c;
  font-size: 1.05rem; font-weight: 600; letter-spacing: 0.04em;
}
html[data-theme="light"].abriendo body::after { background: #f6f4ee; color: #7f6727; }

/* Botones en pastilla (como el dibujo de la consola). */')
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
    if (Test-Path ($ruta + ".bak-sinpasos")) { Mal ("Ya existe " + $t + ".bak-sinpasos. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-sinpasos"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-sinpasos): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-sinpasos") -Destination $ruta -Force }
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
Ok "LISTO: el panel quedo publicado. Probalo apretando Abrir panel en la app."
Write-Host ""
