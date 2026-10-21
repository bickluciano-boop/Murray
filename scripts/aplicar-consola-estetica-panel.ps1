# aplicar-consola-estetica-panel.ps1 - Consola (Ojo Guard MS): estilo nuevo en azul, blanco y dorado, igual al de las paginas Tu proteccion y del camino.
# Luciano (21/10/2026): "no rompamos ningun codigo y no saquemos nada nuestro". Por eso solo cambia la APARIENCIA: se agrega un bloque de estilos al final de la cabecera de src\panel-index.html;
# no se toca ningun boton, campo, id ni programa. Ni una funcion cambia ni se saca: Mapa y Familia, Mis Equipos, Evidencias, Configuracion, el boton OG y todo lo demas siguen igual.
# Que se ve distinto: fondo marfil con tarjetas blancas redondeadas (en modo noche, azul tinta con marfil y dorado; el boton de modo claro / noche de siempre elige cual), botones de borde suave en forma de
# pastilla, listas de Configuracion y barra de abajo mas redondeadas, campos mas suaves y la tipografia mas clara (Plus Jakarta Sans y Outfit, de Google Fonts; si no cargan, la del sistema).
# Si algo no te gusta, se vuelve atras con el respaldo .bak-esteticaconsola (o se borra el bloque <style id="estetica-v1">).
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Toca solo src\panel-index.html, y solo si es el que dejo aplicar-consola-configuracion-panel.ps1 (se comprueba con una huella SHA-256 antes y despues). Al final publica el panel solo.
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
if ((Contar (Leer (Join-Path $raiz "src\panel-index.html")).texto 'id="estetica-v1"') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
function ShaTexto([string]$t) {
    $h = [System.Security.Cryptography.SHA256]::Create()
    return ([System.BitConverter]::ToString($h.ComputeHash([System.Text.Encoding]::UTF8.GetBytes(($t -replace "`r`n", "`n"))))).Replace("-", "").ToLower()
}
$originales = @{
    'src\panel-index.html' = '2bf2d1bc38ad184c3dfb097f9f40998c6480333426816ccce94f3b90470f8f37'
}
$finales = @{
    'src\panel-index.html' = 'e3d6cb3d30c44e97ee6cdbea1d8aa1730d0353305955d6419dbe1032e10146b1'
}
foreach ($k in $originales.Keys) {
    $huella = ShaTexto (Leer (Join-Path $raiz $k)).texto
    if ($huella -ne $originales[$k]) { Mal ($k + " no es el que dejo la consola con Configuracion (huella " + $huella + "). No toco nada. Mandame esta pantalla."); return }
}
Ok "src\panel-index.html es el de la consola con Configuracion"
$cambios = @(
    ,@('src\panel-index.html', 'estilo nuevo (azul, blanco y dorado), solo apariencia', '  </head>', '    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500&family=Plus+Jakarta+Sans:wght@400;500;600;700&display=swap">
    <style id="estetica-v1">
/* Estetica nueva (azul, blanco y dorado): solo apariencia, ningun id, boton ni funcion cambia */
:root{--e-fondo:#FAF8F3;--e-tarjeta:#fff;--e-linea:#E3E7F1;--e-texto:#14213D;--e-texto2:#3E4A6B;--e-suave:#5B6580;--e-azul:#1F4FD1;--e-azul-link:#1F4FD1;--e-azul-suave:#EEF2FB;--e-dorado:#E3A92B;--e-dorado-suave:#FFF3D6;--e-dorado-texto:#7A5200;--e-sombra:0 6px 24px rgba(20,33,61,.08)}
:root:not([data-theme="light"]){--e-fondo:#0B1020;--e-tarjeta:#121A33;--e-linea:rgba(255,255,255,.12);--e-texto:#F5F0E6;--e-texto2:#D5DBEC;--e-suave:#A9B3CE;--e-azul:#3D6BEA;--e-azul-link:#9DBBFF;--e-azul-suave:rgba(255,255,255,.07);--e-dorado:#FFC247;--e-dorado-suave:rgba(255,194,71,.16);--e-dorado-texto:#FFD477;--e-sombra:0 6px 24px rgba(0,0,0,.35)}
html,body{background:var(--e-fondo) !important;color:var(--e-texto) !important;font-family:"Plus Jakarta Sans",Inter,"Segoe UI",system-ui,sans-serif !important}
h1,h2,h3,.dashboard-title{color:var(--e-texto) !important;letter-spacing:-.01em}
p,.section-copy,.message,small{color:var(--e-texto2)}
.eyebrow{color:var(--e-dorado-texto) !important;letter-spacing:.08em}
.account-card,.device,.list-card{background:var(--e-tarjeta) !important;border:1px solid var(--e-linea) !important;border-radius:24px !important;box-shadow:var(--e-sombra) !important;color:var(--e-texto) !important}
.cfg-lista,#cfg-lista{border-radius:24px !important;border-color:var(--e-linea) !important;background:var(--e-tarjeta) !important;box-shadow:var(--e-sombra) !important;overflow:hidden}
.cfg-item{border-color:var(--e-linea) !important;color:var(--e-texto) !important}
.cfg-item:hover,.cfg-item:focus-visible{background:var(--e-azul-suave) !important}
button.ghost,.ghost,.secondary,.accion-secundaria,.icon-button{background:var(--e-tarjeta) !important;color:var(--e-texto) !important;border:1.5px solid var(--e-linea) !important;box-shadow:none !important}
input,select,textarea{background:var(--e-tarjeta) !important;color:var(--e-texto) !important;border:1.5px solid var(--e-linea) !important;border-radius:16px !important}
input:focus-visible,select:focus-visible,textarea:focus-visible,button:focus-visible,a:focus-visible{outline:3px solid var(--e-azul-link) !important;outline-offset:2px}
.bottom-tabs{background:var(--e-tarjeta) !important;border:1px solid var(--e-linea) !important;border-radius:28px !important;box-shadow:0 10px 34px rgba(20,33,61,.14) !important}
.status-tag,.status-tag-core{background:var(--e-dorado-suave) !important;color:var(--e-dorado-texto) !important;border:0 !important;border-radius:999px !important}
.og-guardian>summary.ghost{background:var(--e-dorado) !important;color:#3A2A05 !important;border-color:var(--e-dorado) !important}
.og-menu{border-radius:20px !important;background:var(--e-tarjeta) !important;border:1px solid var(--e-linea) !important;box-shadow:0 14px 40px rgba(20,33,61,.18) !important}
.og-menu a{color:var(--e-texto) !important}
.brand,.brand span{color:var(--e-azul-link) !important;font-weight:300;letter-spacing:.06em}
.device-name{color:var(--e-texto) !important}.device-meta,.device-state{color:var(--e-suave) !important}

button.ghost,a.ghost,summary.ghost{border-radius:999px !important}
.cfg-item{background:transparent !important;border-radius:0 !important}
#actualizar,#refresh,.dashboard-tools .ghost{font-weight:700}
.account-state{background:var(--e-tarjeta) !important;border-color:var(--e-linea) !important;color:var(--e-texto2) !important;border-radius:999px !important}

.bottom-tab{border-radius:22px !important}
.status-grid>*,.summary-grid>*,.health-row{background:var(--e-azul-suave) !important;border-color:var(--e-linea) !important;color:var(--e-texto) !important}
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
    if (Test-Path ($ruta + ".bak-esteticaconsola")) { Mal ("Ya existe " + $t + ".bak-esteticaconsola. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-esteticaconsola"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-esteticaconsola): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-esteticaconsola") -Destination $ruta -Force }
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
Ok "LISTO: la consola quedo con el estilo nuevo. Abrila con Ctrl+F5."
Write-Host ""
