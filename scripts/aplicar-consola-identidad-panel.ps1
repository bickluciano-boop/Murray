# aplicar-consola-identidad-panel.ps1 - Consola (Ojo Guard MS): identidad. Logo mas grande, botones principales en azul (el dorado queda de detalle), Modo noche tambien dentro del panel,
# el logo nuevo en el icono de cada equipo (Mis Equipos), la palabra AJUSTES completa en Configuracion, tarjetas de Evidencias y fondo del mapa en los colores nuevos (claro y noche).
# Luciano (21/10/2026): "no rompamos ningun codigo y no saquemos nada nuestro". Solo APARIENCIA: se agrega un bloque <style id="estetica-v2"> y se cambia el dibujo del icono del equipo. Ninguna funcion cambia.
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Toca solo src\panel-index.html, y solo si es el que dejo aplicar-consola-logo-panel.ps1 (huella SHA-256 antes y despues). Respaldo .bak-consolaidentidad. Al final publica el panel solo.
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
if ((Contar (Leer (Join-Path $raiz "src\panel-index.html")).texto 'id="estetica-v2"') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
function ShaTexto([string]$t) {
    $h = [System.Security.Cryptography.SHA256]::Create()
    return ([System.BitConverter]::ToString($h.ComputeHash([System.Text.Encoding]::UTF8.GetBytes(($t -replace "`r`n", "`n"))))).Replace("-", "").ToLower()
}
$originales = @{
    'src\panel-index.html' = 'f4dc3514839fe27e5d1dfcc1c0c43b11f04a396b379259360e8978d19ef4f784'
}
$finales = @{
    'src\panel-index.html' = '05329440636d1747943c5a63fdece20c274e546b6c1aca68f380f1cc74a71664'
}
foreach ($k in $originales.Keys) {
    $huella = ShaTexto (Leer (Join-Path $raiz $k)).texto
    if ($huella -ne $originales[$k]) { Mal ($k + " no es el que dejo el logo de la consola (huella " + $huella + "). No toco nada. Mandame esta pantalla."); return }
}
Ok "src\panel-index.html es el de la consola con el logo nuevo"
$cambios = @(
    @('src\panel-index.html', 'logo nuevo en el icono del equipo', '<svg viewBox="0 40 226 120" aria-hidden="true"><path d="M8,100 C48,71.4 84,48 154,48 A64,52 0 0 1 154,152 C84,152 48,128.6 8,100 Z" fill="none" stroke="#e2a93a" stroke-width="10" stroke-linejoin="round"/><path d="M60,100 C90,63 166,63 196,100 C166,137 90,137 60,100 Z" fill="#050505" stroke="#e2a93a" stroke-width="7"/><circle cx="128" cy="100" r="29" fill="#d9a441"/><circle cx="128" cy="100" r="29" fill="none" stroke="#7a5212" stroke-width="3"/><circle cx="128" cy="100" r="12" fill="#070707"/><circle cx="122.6" cy="94" r="3.6" fill="#fff" fill-opacity=".85"/></svg>', '<svg viewBox="0 0 120 72"  aria-hidden="true" focusable="false"><defs><linearGradient id="ogOroC" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#F1D58A"/><stop offset=".5" stop-color="#D4A94D"/><stop offset="1" stop-color="#A67C32"/></linearGradient></defs><path d="M4 36C30 10 62 6 84 8C104 10 116 22 116 36C116 50 104 62 84 64C62 66 30 62 4 36Z" fill="#0F1A3A" stroke="#B48A3C" stroke-width="1"/><path d="M10 36C32 15 60 12 82 14C98 16 107 25 107 36C107 47 98 56 82 58C60 60 32 57 10 36Z" fill="none" stroke="url(#ogOroC)" stroke-width="3.4" stroke-linejoin="round"/><path d="M30 36Q66 -6 101 36Q66 78 30 36Z" fill="none" stroke="url(#ogOroC)" stroke-width="2.6" stroke-linejoin="round"/><circle cx="66" cy="36" r="17" fill="#1B2D5E" stroke="url(#ogOroC)" stroke-width="2.2"/><circle cx="66" cy="36" r="8.6" fill="#05060B"/><circle cx="60.6" cy="30.2" r="2.8" fill="#EEF2FF" fill-opacity=".92"/></svg>'),
    @('src\panel-index.html', 'estilos de identidad (azul, Modo noche, logo grande)', '  </head>', '    <style id="estetica-v2">
/* Estetica v2 (identidad): logo mas grande, azul para lo principal, el dorado de detalle y el Modo noche tambien dentro del panel. Solo apariencia. */
.brand-logo{width:66px !important;height:auto !important;margin-right:12px !important}
.brand strong{font-size:1.45em !important}
.shell:has(#dashboard:not(.hidden)) #theme-toggle{display:inline-flex !important}
.device button:not([class]),.account-card button:not([class]),#access button:not([class]),button[data-command]{background:var(--e-azul) !important;color:#fff !important;border:0 !important;border-radius:999px !important;box-shadow:0 8px 20px rgba(31,79,209,.22) !important}
.device button:not([class]):hover,button[data-command]:hover{filter:brightness(1.08)}
.bottom-tab.active,button.on,[data-rango].on,[data-capa].on{background:var(--e-azul-suave) !important;color:var(--e-azul-link) !important}
#cfg-lista>.section-head,#cfg-lista .section-head{padding:22px 24px 10px !important}
.device-icon.device-icon-ojo{background:transparent !important;border:0 !important;padding:0 !important;width:92px !important;height:56px !important;display:flex;align-items:center}
.device-icon-ojo svg{width:100% !important;height:auto !important}
.eyebrow{font-weight:700}
.ogm,.ogm-lienzo{background:var(--e-fondo) !important}
.topbar{background:var(--e-fondo) !important;border-color:var(--e-linea) !important}
.topbar-actions{gap:8px !important}
.topbar-actions>.ghost{padding-left:14px !important;padding-right:14px !important;font-size:.92rem !important}
.bottom-tab{padding-left:10px !important;padding-right:10px !important}
@media (max-width:1180px){.brand-logo{width:48px !important}.brand strong{font-size:1.2em !important}}
.topbar{box-shadow:0 0 0 1280px var(--e-fondo) !important}
.evidence-card{background:var(--e-tarjeta) !important;border:1px solid var(--e-linea) !important;border-radius:24px !important;box-shadow:var(--e-sombra) !important}
.evidence-placeholder{background:var(--e-azul-suave) !important;color:var(--e-suave) !important;border-radius:18px !important}
@media (min-width:1181px){.bottom-tabs{width:auto !important;min-width:0 !important}.bottom-tab span:last-child{font-size:.84rem}}
@media (min-width:1181px) and (max-width:1366px){.bottom-tab{padding-left:8px !important;padding-right:8px !important}.topbar-actions{gap:6px !important}}
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
    if (Test-Path ($ruta + ".bak-consolaidentidad")) { Mal ("Ya existe " + $t + ".bak-consolaidentidad. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-consolaidentidad"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-consolaidentidad): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-consolaidentidad") -Destination $ruta -Force }
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
Ok "LISTO: la consola quedo con la identidad nueva. Abrila con Ctrl+F5."
Write-Host ""
