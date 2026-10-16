# aplicar-mapa-tarjeta-fila-panel.ps1 - La tarjeta del equipo (en la app) empieza en UNA FILA y se abre al tocarla.
# Luciano (16/10/2026), viendo la tarjeta de "LB iPhone": "podria ser mas chico, ocupando como una hilera, y que sea grande cuando lo tocas".
# Ahora, al elegir un equipo o una persona (de la lista o tocando su pin), la tarjeta muestra una sola fila: el dibujo o la inicial, el nombre,
# como esta ("activo hace 17 s - 100 % - 26 m") y la cruz. Un toque en la fila (o deslizar hacia arriba la manija) la abre con todos los botones
# (Hacer sonar, Ubicar, Evidencia, Como llegar, Seguir en vivo) y los datos; otro toque la vuelve a cerrar. Nada se pierde, solo queda mas mapa.
# Requiere aplicar-mapa-app-tarjeta-panel.ps1. Va en la carpeta del PANEL (la que tiene wrangler.toml). Toca src\panel-mapa.txt y
# src\panel-explanations.css. Respaldo .bak-tarjetafila. Al final publica el panel solo. No hace falta build.
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
if ((Contar $mapaTexto 'toggle("ogm-plegada", EN_APP)') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $mapaTexto 'function soltar()') -eq 0) { Mal "Falta aplicar antes aplicar-mapa-app-tarjeta-panel.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\panel-explanations.css")).texto '/* Botones en pastilla (como el dibujo de la consola). */') -ne 1) { Mal "Falta aplicar antes los pasos de la consola (pestanas, ayudas, equipos)."; return }
$cambios = @(
    @('src\panel-mapa.txt', 'tarjeta: al elegir empieza plegada en la app', '    estado.elegido = id;
    estado.recorrido = [];
    $("#og-mapa")?.classList.remove("ogm-plegada");', '    estado.elegido = id;
    estado.recorrido = [];
    // En la app la tarjeta empieza en una sola fila y se abre tocandola; en la compu sigue abierta como siempre.
    $("#og-mapa")?.classList.toggle("ogm-plegada", EN_APP);'),
    @('src\panel-explanations.css', 'mapa: tarjeta en una fila', '/* Botones en pastilla (como el dibujo de la consola). */', '/* Tarjeta del equipo en la app: al elegir un equipo o una persona empieza en UNA FILA (avatar, nombre y como esta, y la cruz) y se abre tocandola
   (o deslizando hacia arriba la manija); tocar de nuevo la vuelve a cerrar. Asi queda casi todo el mapa a la vista. (Pedido de Luciano, 16/10/2026.) */
@media (max-width: 899px) {
  html.app-mapa #og-mapa.ogm-plegada .ogm-tarjeta { max-height: none; padding: 0 10px 7px; }
  html.app-mapa #og-mapa.ogm-plegada .ogm-asa { height: 12px; margin: 0 -10px 0; width: calc(100% + 20px); }
  html.app-mapa #og-mapa.ogm-plegada .ogm-asa::before { top: 4px; }
  html.app-mapa #og-mapa.ogm-plegada .ogm-cab-app { gap: 8px; }
  html.app-mapa #og-mapa.ogm-plegada .ogm-cab-app .ogm-av.grande { width: 28px; height: 28px; }
  html.app-mapa #og-mapa.ogm-plegada .ogm-cab-app .ogm-foto:not(:disabled)::after { display: none; }
  html.app-mapa #og-mapa.ogm-plegada .ogm-cab-app > div { display: flex; align-items: baseline; gap: 8px; }
  html.app-mapa #og-mapa.ogm-plegada .ogm-nom { flex: 0 1 auto; }
  html.app-mapa #og-mapa.ogm-plegada .ogm-nom .ogm-rol { display: none; }
  html.app-mapa #og-mapa.ogm-plegada .ogm-cab-app small:not(.ogm-donde) { flex: 1 1 0; min-width: 0; white-space: nowrap; font-size: 0.7rem; }
  html.app-mapa #og-mapa.ogm-plegada .ogm-cab-app .ogm-donde { display: none; }
  html.app-mapa #og-mapa.ogm-plegada .ogm-cerrar { width: 24px; height: 24px; font-size: 0.75rem; }
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
    if (Test-Path ($ruta + ".bak-tarjetafila")) { Mal ("Ya existe " + $t + ".bak-tarjetafila. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-tarjetafila"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-tarjetafila): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-tarjetafila") -Destination $ruta -Force }
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
Ok "LISTO: el panel quedo publicado. Cerra la app y abrila de nuevo: al elegir un equipo, la tarjeta es una sola fila y se abre al tocarla."
Write-Host ""
