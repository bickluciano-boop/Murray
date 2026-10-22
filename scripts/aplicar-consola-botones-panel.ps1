# aplicar-consola-botones-panel.ps1 - Consola (Ojo Guard MS): lo ultimo que quedaba en mostaza pasa al azul de la identidad.
# Botones Ver mapa aca / Escanear ubicacion / Como llegar, iconos de los relojes, numeros y avisos, ventana del mapa y estados vacios, en claro y en noche. El boton OG de emergencia queda dorado a proposito.
# Luciano (22/10/2026): "todavia habia bastantes botones mostaza". Solo APARIENCIA: se agrega un bloque <style id="estetica-v3">. Ninguna funcion cambia.
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Toca solo src\panel-index.html, y solo si es el que dejo aplicar-consola-identidad-panel.ps1 (huella SHA-256 antes y despues). Respaldo .bak-consolabotones. Al final publica
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
if (-not (Test-Path (Join-Path $raiz "src\panel-index.html"))) { Mal "No encuentro src\panel-index.html en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\panel-index.html")).texto 'id="estetica-v3"') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
function ShaTexto([string]$t) {
    $h = [System.Security.Cryptography.SHA256]::Create()
    return ([System.BitConverter]::ToString($h.ComputeHash([System.Text.Encoding]::UTF8.GetBytes(($t -replace "`r`n", "`n"))))).Replace("-", "").ToLower()
}
$originales = @{
    'src\panel-index.html' = '05329440636d1747943c5a63fdece20c274e546b6c1aca68f380f1cc74a71664'
}
$finales = @{
    'src\panel-index.html' = '2fd4e5f96d77e016e625b4722e6ae4d6f8875459ebf89d36114c404901f14e3b'
}
foreach ($k in $originales.Keys) {
    $huella = ShaTexto (Leer (Join-Path $raiz $k)).texto
    if ($huella -ne $originales[$k]) { Mal ($k + " no es el que dejo la identidad de la consola (huella " + $huella + "). No toco nada. Mandame esta pantalla."); return }
}
Ok "src\panel-index.html es el de la consola con la identidad nueva"
$cambios = @(
    ,@('src\panel-index.html', 'estilos del ultimo dorado a azul', '  </head>', '    <style id="estetica-v3">
/* estetica-v3: lo que todavia quedaba en mostaza (--lime) pasa al azul de la identidad. Solo apariencia. */
.map-button,.location-history .map-button,.location-actions .map-button,.demo-banner,.pull-refresh-indicator{background:var(--e-azul) !important;color:#fff !important;border:0 !important;border-radius:999px !important}
.device-icon,.onboarding li>strong,.brand-eye{background:var(--e-azul) !important;color:#fff !important}
.summary-grid strong,.list-card>strong,.evidence-tags,.message,.privacy-note strong{color:var(--e-azul-link) !important}
.ms-mark{color:var(--e-azul-link) !important;border-color:var(--e-azul-link) !important}
.command-status{border-left-color:var(--e-azul) !important}
.summary-icon,.empty-icon{color:var(--e-azul-link) !important;background:var(--e-azul-suave) !important}
.privacy-note{background:var(--e-dorado-suave) !important;border-color:var(--e-linea) !important;color:var(--e-texto2) !important}
.empty-state{background:var(--e-azul-suave) !important;border-color:var(--e-linea) !important}
input:focus,input:focus-visible{border-color:var(--e-azul) !important;box-shadow:0 0 0 3px rgba(31,79,209,.18) !important}
.map-modal-card{background:var(--e-tarjeta) !important;border-color:var(--e-linea) !important;color:var(--e-texto) !important;border-radius:24px !important}
.map-modal-head{color:var(--e-texto) !important;border-color:var(--e-linea) !important}
.map-modal-canvas{background:var(--e-azul-suave) !important}
.scan-radar{background:conic-gradient(from 0deg,var(--e-azul),transparent 65%) !important}
.scan-radar::after{background:var(--e-tarjeta) !important}
.scan-loading,.scan-image-label{color:var(--e-suave) !important}
.location-history li{background:var(--e-azul-suave) !important;border-color:var(--e-linea) !important;color:var(--e-texto2) !important}
.secure-badge{background:var(--e-azul-suave) !important;border-color:var(--e-linea) !important;color:var(--e-azul-link) !important}
.evidence-image span,.evidence-placeholder strong{background:rgba(20,33,61,.78) !important;color:#fff !important}
    </style>
  </head>')
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
    if (Test-Path ($ruta + ".bak-consolabotones")) { Mal ("Ya existe " + $t + ".bak-consolabotones. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-consolabotones"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-consolabotones): " + ($respaldados -join ", "))

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
foreach ($k in $archivos.Keys) { Chk ($k + ": huella final") ((ShaTexto (Leer (Join-Path $raiz $k)).texto) -eq $finales[$k]) }
foreach ($d in $descargas) { Chk ($d[1] + ": verificado") ((Sha (Join-Path $raiz $d[1])) -eq $d[2]) }

if (-not $todoBien) {
    Mal "Algo no salio bien. Restauro todo desde los respaldos."
    foreach ($t in $tocados) {
        $ruta = Join-Path $raiz $t
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-consolabotones") -Destination $ruta -Force }
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
Ok "LISTO: la consola quedo sin botones mostaza. Abrila con Ctrl+F5."
Write-Host ""
