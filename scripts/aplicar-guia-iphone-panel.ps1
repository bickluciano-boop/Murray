# aplicar-guia-iphone-panel.ps1 - Ojo Guard MS: guia de 4 pasos para instalar en iPhone (TestFlight) en la pagina de entrada de https://ojoguard.app, en /descargar y en /unirme.
# 28/10/2026: la mama de Luciano (iPhone) se confundio con TestFlight ("se descarga este TestFlight, no se descarga el Ojo Guard"). Se monta sobre los botones de Android e iPhone que ya estan instalados.
# Cambia src\panel-index.html y src\index.ts (respaldo .bak-guia-iphone). Va en la carpeta del PANEL (la que tiene wrangler.toml). Requiere aplicar-testflight-panel.ps1 y los botones de la entrada. Al final publica el panel solo.
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
foreach ($f in @("src\panel-index.html", "src\index.ts")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\panel-index.html")).texto 'acceso-guia') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\panel-index.html")).texto 'acceso-apps') -eq 0) { Mal "Faltan los botones de la pagina de entrada. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'const URL_TESTFLIGHT') -eq 0) { Mal "Falta aplicar primero aplicar-testflight-panel.ps1. No toco nada."; return }
$cambios = @(
    @('src\panel-index.html', 'estilo de la guia de iPhone', '@media (max-width:420px){#access .acceso-apps-fila{grid-template-columns:1fr}}
', '#access .acceso-guia{margin-top:14px}
#access .acceso-guia ol{margin:0;padding-left:22px;line-height:1.65;color:var(--e-texto2)}
#access .acceso-guia li{margin-bottom:8px}
@media (max-width:420px){#access .acceso-apps-fila{grid-template-columns:1fr}}
'),
    @('src\panel-index.html', 'guia de iPhone en la pagina de entrada', '<span>iPhone<small>Descargar</small></span></a>
          </div>
        </div>
        <section id="passkey-setup" class="hidden">', '<span>iPhone<small>Descargar</small></span></a>
          </div>
          <details class="acceso-guia"><summary>&#191;C&#243;mo se instala en iPhone?</summary><ol><li>Toc&#225; <strong>Instalar en iPhone</strong>. Se abre la App Store con <strong>TestFlight</strong>, la app de Apple para probar versiones nuevas. Es normal: primero se instala esa.</li><li>Toc&#225; <strong>Obtener</strong> para instalar TestFlight y despu&#233;s volv&#233; a tocar <strong>Instalar en iPhone</strong>.</li><li>Acept&#225; los t&#233;rminos de TestFlight y toc&#225; <strong>Instalar</strong> en la pantalla de Ojo Guard. Si el bot&#243;n est&#225; gris, esper&#225; unos segundos.</li><li>Abr&#237; <strong>Ojo Guard</strong>: es el &#237;cono con un ojo dorado sobre fondo azul. Dej&#225; TestFlight instalada: es la que te avisa cuando hay versiones nuevas.</li></ol></details>
        </div>
        <section id="passkey-setup" class="hidden">'),
    @('src\index.ts', 'pagina de descarga: guia de 4 pasos para iPhone', '<div class="tarjeta"><h2>En iPhone</h2><p>Se instala con TestFlight, la app de Apple para probar versiones nuevas. Si no la ten&eacute;s, el enlace te lleva a bajarla.</p><p><a class="boton" href="${URL_TESTFLIGHT}">Instalar en iPhone</a></p></div>', '<div class="tarjeta"><h2>En iPhone</h2><p>Se instala en 4 pasos con TestFlight, la app de Apple para probar versiones nuevas.</p><ol style="margin:8px 0 14px;padding-left:22px;line-height:1.65"><li>Toc&#225; <strong>Instalar en iPhone</strong>. Se abre la App Store con <strong>TestFlight</strong>, la app de Apple para probar versiones nuevas. Es normal: primero se instala esa.</li><li>Toc&#225; <strong>Obtener</strong> para instalar TestFlight y despu&#233;s volv&#233; a tocar <strong>Instalar en iPhone</strong>.</li><li>Acept&#225; los t&#233;rminos de TestFlight y toc&#225; <strong>Instalar</strong> en la pantalla de Ojo Guard. Si el bot&#243;n est&#225; gris, esper&#225; unos segundos.</li><li>Abr&#237; <strong>Ojo Guard</strong>: es el &#237;cono con un ojo dorado sobre fondo azul. Dej&#225; TestFlight instalada: es la que te avisa cuando hay versiones nuevas.</li></ol><p><a class="boton" href="${URL_TESTFLIGHT}">Instalar en iPhone</a></p></div>'),
    @('src\index.ts', 'pagina de invitacion: guia de 4 pasos para iPhone', '<div class="tarjeta"><h2>&iquest;Ten&eacute;s iPhone?</h2><p>Se instala con TestFlight, la app de Apple para probar versiones nuevas.</p><p><a class="boton" href="${URL_TESTFLIGHT}">Instalar en iPhone</a></p></div>', '<div class="tarjeta"><h2>&iquest;Ten&eacute;s iPhone?</h2><p>Se instala en 4 pasos con TestFlight, la app de Apple para probar versiones nuevas.</p><ol style="margin:8px 0 14px;padding-left:22px;line-height:1.65"><li>Toc&#225; <strong>Instalar en iPhone</strong>. Se abre la App Store con <strong>TestFlight</strong>, la app de Apple para probar versiones nuevas. Es normal: primero se instala esa.</li><li>Toc&#225; <strong>Obtener</strong> para instalar TestFlight y despu&#233;s volv&#233; a tocar <strong>Instalar en iPhone</strong>.</li><li>Acept&#225; los t&#233;rminos de TestFlight y toc&#225; <strong>Instalar</strong> en la pantalla de Ojo Guard. Si el bot&#243;n est&#225; gris, esper&#225; unos segundos.</li><li>Abr&#237; <strong>Ojo Guard</strong>: es el &#237;cono con un ojo dorado sobre fondo azul. Dej&#225; TestFlight instalada: es la que te avisa cuando hay versiones nuevas.</li></ol><p><a class="boton" href="${URL_TESTFLIGHT}">Instalar en iPhone</a></p></div>')
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
    if (Test-Path ($ruta + ".bak-guia-iphone")) { Mal ("Ya existe " + $t + ".bak-guia-iphone. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-guia-iphone"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-guia-iphone): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-guia-iphone") -Destination $ruta -Force }
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
Ok "LISTO: la pagina de entrada, la descarga y la invitacion ya tienen la guia de 4 pasos para iPhone."
Write-Host ""
