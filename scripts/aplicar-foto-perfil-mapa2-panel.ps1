# aplicar-foto-perfil-mapa2-panel.ps1 - Ojo Guard MS: tu celular, en el mapa y en la lista, muestra tu foto de perfil (si no le pusiste una foto propia con el lapiz).
# Luciano (28/10/2026): "si no aparece aca, mucho sentido no tiene". Requiere aplicar-foto-perfil-mapa-panel.ps1. Cambia src\panel-mapa.txt y src\panel-index.html (solo sube a v=3 el numero del script; respaldo .bak-foto-perfil-mapa2). Va en la carpeta del PANEL. Al final publica el panel solo.
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
foreach ($f in @("src\panel-mapa.txt", "src\panel-index.html")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\panel-mapa.txt")).texto 'SIN_FOTO_EQUIPO') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\panel-mapa.txt")).texto 'fotoV') -eq 0) { Mal "Falta aplicar primero aplicar-foto-perfil-mapa-panel.ps1. No toco nada."; return }
$cambios = @(
    @('src\panel-mapa.txt', 'tu celular muestra tu foto de perfil (aviso de equipos sin foto)', '  if (equipo.tipo !== "telefono") return null;
', '  if (equipo.tipo !== "telefono") return null;
  // Un celular tuyo sin foto propia muestra tu foto de perfil (la de la app). Se anota cuales no tienen foto propia para no pedirla en cada dibujo.
  if (SIN_FOTO_EQUIPO.has(equipo.id)) return fotoPerfilPropia();
'),
    @('src\panel-mapa.txt', 'funciones de la foto de perfil propia', 'function urlFoto(equipo) {
', 'const SIN_FOTO_EQUIPO = (window.__ogmSinFoto = window.__ogmSinFoto || new Set());
function fotoPerfilPropia() {
  return `/api/remote/profile-photo?person=me&v=${Math.floor(Date.now() / 60000)}`;
}
function urlFoto(equipo) {
'),
    @('src\panel-mapa.txt', 'si falla la foto del equipo se prueba la de perfil', '${foto ? `<img src="${foto}" alt="" onerror="this.remove()">` : ""}', '${foto ? `<img src="${esc(foto)}" alt="" onerror="${esc(errorFoto(equipo, dibujo))}">` : ""}'),
    @('src\panel-mapa.txt', 'funcion errorFoto', 'function avatarHtml(equipo, clase = "") {
', '/** Si la foto del equipo no esta: en un celular se prueba con la foto de perfil de la cuenta; si tampoco esta, se saca la imagen y queda el dibujo. */
function errorFoto(equipo, dibujo) {
  if (equipo.tipo === "telefono" && dibujo === DIBUJO_CELULAR && !SIN_FOTO_EQUIPO.has(equipo.id)) {
    return `window.__ogmSinFoto.add(${JSON.stringify(equipo.id)});this.onerror=function(){this.remove()};this.src=${JSON.stringify(fotoPerfilPropia())}`;
  }
  return "this.remove()";
}

function avatarHtml(equipo, clase = "") {
'),
    @('src\panel-index.html', 'recargar el mapa nuevo (v=3)', '<script type="module" src="/mapa-v1.js?v=2"></script>', '<script type="module" src="/mapa-v1.js?v=3"></script>')
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
    if (Test-Path ($ruta + ".bak-foto-perfil-mapa2")) { Mal ("Ya existe " + $t + ".bak-foto-perfil-mapa2. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-foto-perfil-mapa2"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-foto-perfil-mapa2): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-foto-perfil-mapa2") -Destination $ruta -Force }
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
Ok "LISTO: tu celular muestra tu foto de perfil en el mapa y la lista."
Write-Host ""
