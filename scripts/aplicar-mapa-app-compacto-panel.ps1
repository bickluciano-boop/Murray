# aplicar-mapa-app-compacto-panel.ps1 - El mapa dentro de la app: la tarjeta del equipo elegido, mas baja y compacta.
# Pedido de Luciano (15/10/2026) al probar el mapa en el telefono: al tocar a alguien aparecia una tarjeta demasiado grande que tapaba la mitad
# del mapa. Dentro de la app (?app=mapa) la tarjeta queda pegada abajo, con un maximo del 44 % del alto, letras y espacios mas chicos y los
# datos (margen de error, bateria, hoy, de vos) ordenados en una fila. Lo que no entra se recorre dentro de la tarjeta; no se saca nada.
# La consola de siempre y el mapa del navegador no cambian. Requiere aplicar-mapa-en-app-panel.ps1. Va en la carpeta del PANEL (la que tiene
# wrangler.toml). Toca src\panel-explanations.css. Respaldo .bak-compacto. Al final publica el panel solo.
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
foreach ($f in @("src\panel-explanations.css")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\panel-explanations.css")).texto 'html.app-mapa #og-mapa .ogm-tarjeta') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\panel-explanations.css")).texto 'html.app-mapa .topbar') -eq 0) { Mal "Falta aplicar antes el mapa dentro de la app (aplicar-mapa-en-app-panel.ps1)."; return }
if ((Contar (Leer (Join-Path $raiz "src\panel-explanations.css")).texto '/* Botones en pastilla (como el dibujo de la consola). */') -ne 1) { Mal "Falta aplicar antes los pasos anteriores de la consola."; return }
$cambios = @(
    ,@('src\panel-explanations.css', 'mapa en la app: tarjeta compacta', '/* Botones en pastilla (como el dibujo de la consola). */', '/* Dentro de la app (?app=mapa): el mapa es mas chico que una pantalla de celular, asi que la tarjeta del equipo elegido es mas baja y compacta
   (pegada abajo, sin el hueco de las pestanas que aca no hay, con letras y espacios mas chicos y los datos en una sola fila ordenada). */
@media (max-width: 899px) {
  html.app-mapa #og-mapa .ogm-tarjeta { left: 8px; right: 8px; bottom: 8px; max-height: 44%; border-radius: 18px; padding: 4px 12px 10px; }
  html.app-mapa #og-mapa .ogm-asa { height: 20px; margin: -4px -12px 2px; width: calc(100% + 24px); }
  html.app-mapa #og-mapa .ogm-asa::before { top: 7px; }
  html.app-mapa #og-mapa .ogm-cab { gap: 10px; }
  html.app-mapa #og-mapa .ogm-cab strong { font-size: 0.98rem; }
  html.app-mapa #og-mapa .ogm-cab small { font-size: 0.72rem; line-height: 1.3; }
  html.app-mapa #og-mapa .ogm-direc { margin: 6px 0 6px; font-size: 0.84rem; }
  html.app-mapa #og-mapa .ogm-datos { display: grid; grid-template-columns: repeat(4, auto); justify-content: space-between; gap: 4px 8px; margin-bottom: 8px; }
  html.app-mapa #og-mapa .ogm-datos span { font-size: 0.8rem; white-space: nowrap; }
  html.app-mapa #og-mapa .ogm-datos em { font-size: 0.54rem; letter-spacing: 0.04em; white-space: nowrap; }
  html.app-mapa #og-mapa .ogm-botones { gap: 6px; }
  html.app-mapa #og-mapa .ogm-botones button { padding: 7px 10px; font-size: 0.8rem; }
  html.app-mapa #og-mapa .ogm-paradas { margin-bottom: 8px; padding-top: 8px; }
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
    if (Test-Path ($ruta + ".bak-compacto")) { Mal ("Ya existe " + $t + ".bak-compacto. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-compacto"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-compacto): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-compacto") -Destination $ruta -Force }
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
Ok "LISTO: el panel quedo publicado. Abrilo y mandame fotos (en la compu y en el celular)."
Write-Host ""
