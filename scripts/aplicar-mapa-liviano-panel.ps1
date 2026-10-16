# aplicar-mapa-liviano-panel.ps1 - El mapa de la app, menos cargado de informacion.
# Luciano (16/10/2026), con el mapa ya girando: "esta sobrecargado; seguir reduciendo los iconos de abajo y tambien los del mapa; el satelite
# reubicarlo en otro lado". Cambios (solo panel, se ve al instante, nada se pierde):
#  - Los pines del mapa son mas chicos y la etiqueta dice solo el nombre; la hora y la marca (Android, iPhone...) se ven al elegir el equipo.
#  - Los botones de arriba (En vivo/Hoy/7 dias y la columna de la derecha) son mas chicos.
#  - Mapa/Satelite deja de ser un cuadro suelto sobre el mapa: pasa a ser un icono de capas en la columna de botones de la derecha, junto a la
#    brujula (que aparece solo cuando el mapa esta girado).
#  - La tarjeta de abajo: botones y letra mas chicos. (Los botones de la barra de abajo de la app son de la app: van en la proxima build.)
# Requiere aplicar-mapa-rotar-panel.ps1. Va en la carpeta del PANEL (la que tiene wrangler.toml). Toca src\panel-mapa.txt y
# src\panel-explanations.css. Respaldo .bak-liviano. Al final publica el panel solo. No hace falta build.
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
foreach ($f in @("src\panel-mapa.txt", "src\panel-explanations.css")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
$mapaTexto = (Leer (Join-Path $raiz "src\panel-mapa.txt")).texto
if ((Contar $mapaTexto 'columnaBotones') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $mapaTexto 'heading_changed') -ne 1) { Mal "Falta aplicar antes aplicar-mapa-rotar-panel.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\panel-explanations.css")).texto '/* Botones en pastilla (como el dibujo de la consola). */') -ne 1) { Mal "Falta aplicar antes los pasos de la consola (pestanas, ayudas, equipos)."; return }
$cambios = @(
    @('src\panel-mapa.txt', 'liviano: Mapa/Satelite como icono en la columna de botones', '  brujula.addEventListener("click", () => mapa.setHeading(0));', ('  brujula.addEventListener("click", () => mapa.setHeading(0));
  // Mapa/Satelite pasa a ser un icono en la columna de botones de arriba (en la app), para no tapar el mapa. La brujula va con el.
  const columnaBotones = $(".ogm-ctrl");
  const cajaCapas = $(".ogm-capas");
  if (EN_APP && columnaBotones && cajaCapas && !columnaBotones.contains(cajaCapas)) {
    columnaBotones.appendChild(cajaCapas);
    cajaCapas.querySelectorAll("[data-capa]").forEach((b) => {
      b.title = b.dataset.capa === "satelite" ? "Ver el mapa en sat' + [char]0x00e9 + 'lite" : "Ver el mapa normal";
      b.setAttribute("aria-label", b.title);
      b.innerHTML = ''<svg viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round" stroke-linecap="round"><path d="M12 3.5l8.5 4.7-8.5 4.7-8.5-4.7z"/><path d="M3.5 12.4l8.5 4.7 8.5-4.7"/><path d="M3.5 16.4l8.5 4.7 8.5-4.7" opacity="0.55"/></svg>'';
    });
  }')),
    @('src\panel-explanations.css', 'mapa: mas liviano', '/* Botones en pastilla (como el dibujo de la consola). */', '/* Mapa de la app mas liviano (pedido de Luciano, 16/10/2026: "esta sobrecargado"): pines y etiquetas mas chicos (la etiqueta solo dice el nombre; la hora
   y la marca se ven al elegir el equipo), botones de arriba mas chicos, Mapa/Satelite y la brujula dentro de la columna de botones de arriba (como un
   icono), y la tarjeta con botones y letra mas chicos. */
@media (max-width: 899px) {
  html.app-mapa #og-mapa .ogm-pin .ogm-av { width: 30px; height: 30px; border-width: 2px; box-shadow: 0 3px 10px rgba(0, 0, 0, 0.35); }
  html.app-mapa #og-mapa .ogm-pin.sel .ogm-av { width: 36px; height: 36px; }
  html.app-mapa #og-mapa .ogm-halo { width: 64px; height: 64px; margin: -32px 0 0 -32px; }
  html.app-mapa #og-mapa .ogm-etq { margin-top: 3px; padding: 2px 7px; border-radius: 8px; font-size: 0.62rem; }
  html.app-mapa #og-mapa .ogm-etq .ogm-marca, html.app-mapa #og-mapa .ogm-etq em { display: none; }
  html.app-mapa #og-mapa .ogm-pin.sel .ogm-etq em { display: inline; font-size: 0.58rem; }
  html.app-mapa #og-mapa .ogm-seg { padding: 3px; gap: 1px; border-radius: 12px; }
  html.app-mapa #og-mapa .ogm-seg button { padding: 5px 9px; gap: 5px; border-radius: 9px; font-size: 0.72rem; }
  html.app-mapa #og-mapa .ogm-ctrl { border-radius: 12px; }
  html.app-mapa #og-mapa .ogm-ctrl button { width: 34px; height: 34px; font-size: 1rem; }
  html.app-mapa #og-mapa .ogm-ctrl button svg { width: 17px; height: 17px; }
  html.app-mapa #og-mapa .ogm-ctrl .ogm-capas { position: static; display: flex; flex-direction: column; padding: 0; border: 0; border-radius: 0; box-shadow: none; background: transparent; }
  html.app-mapa #og-mapa .ogm-ctrl .ogm-capas button { display: grid; place-items: center; width: 34px; height: 34px; padding: 0; border-radius: 0; color: var(--ogm-oro-vivo); }
  html.app-mapa #og-mapa .ogm-ctrl .ogm-capas button.on { display: none; }
  html.app-mapa #og-mapa .ogm-ctrl .ogm-capas button.ogm-brujula.hidden { display: none; }
  html.app-mapa #og-mapa .ogm-tiles { gap: 4px; margin: 4px 0 2px; }
  html.app-mapa #og-mapa .ogm-tile { gap: 1px; padding: 4px 1px 3px; border-radius: 10px; }
  html.app-mapa #og-mapa .ogm-tile svg { width: 15px; height: 15px; }
  html.app-mapa #og-mapa .ogm-tile span { font-size: 0.56rem; }
  html.app-mapa #og-mapa .ogm-cab-app .ogm-av.grande { width: 34px; height: 34px; }
  html.app-mapa #og-mapa .ogm-nom strong { font-size: 0.92rem; }
}

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
    if (Test-Path ($ruta + ".bak-liviano")) { Mal ("Ya existe " + $t + ".bak-liviano. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-liviano"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-liviano): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-liviano") -Destination $ruta -Force }
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
Ok "LISTO: el panel quedo publicado. Cerra la app y abrila de nuevo: el mapa queda mas liviano y Mapa/Satelite es un icono de capas arriba a la derecha."
Write-Host ""
