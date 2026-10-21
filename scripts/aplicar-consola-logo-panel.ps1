# aplicar-consola-logo-panel.ps1 - Consola (Ojo Guard MS): logo nuevo (el ojo dorado en gota con fondo azul marino, y el nombre "Ojo Guard" con el punto dorado en la O).
# Luciano (21/10/2026): "no rompamos ningun codigo y no saquemos nada nuestro". Solo cambia la APARIENCIA: se reemplaza el dibujo del ojo del encabezado y el de la pantalla "Entra a tu cuenta" por el logo nuevo
# (dibujado en SVG, se ve nitido en cualquier tamano, en claro y en noche) y se agrega un bloque de estilos <style id="logo-v1">. No se toca ningun boton, campo, id ni programa.
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Toca solo src\panel-index.html, y solo si es el que dejo aplicar-consola-estetica-panel.ps1 (se comprueba con una huella SHA-256 antes y despues). Respaldo .bak-logoconsola. Al final publica el panel solo.
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
if ((Contar (Leer (Join-Path $raiz "src\panel-index.html")).texto 'id="logo-v1"') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
function ShaTexto([string]$t) {
    $h = [System.Security.Cryptography.SHA256]::Create()
    return ([System.BitConverter]::ToString($h.ComputeHash([System.Text.Encoding]::UTF8.GetBytes(($t -replace "`r`n", "`n"))))).Replace("-", "").ToLower()
}
$originales = @{
    'src\panel-index.html' = 'e3d6cb3d30c44e97ee6cdbea1d8aa1730d0353305955d6419dbe1032e10146b1'
}
$finales = @{
    'src\panel-index.html' = 'f4dc3514839fe27e5d1dfcc1c0c43b11f04a396b379259360e8978d19ef4f784'
}
foreach ($k in $originales.Keys) {
    $huella = ShaTexto (Leer (Join-Path $raiz $k)).texto
    if ($huella -ne $originales[$k]) { Mal ($k + " no es el que dejo la estetica de la consola (huella " + $huella + "). No toco nada. Mandame esta pantalla."); return }
}
Ok "src\panel-index.html es el de la consola con el estilo nuevo"
$cambios = @(
    @('src\panel-index.html', 'logo nuevo en el encabezado', '<svg class="brand-logo" viewBox="0 40 226 120" width="53" height="28" aria-hidden="true" style="vertical-align:middle;margin-right:8px;flex:none"><defs><linearGradient id="ogLogoGold" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffd978"/><stop offset=".5" stop-color="#e2a93a"/><stop offset="1" stop-color="#9c6a1a"/></linearGradient><radialGradient id="ogLogoIris"><stop offset="0" stop-color="#3a2606"/><stop offset=".35" stop-color="#b9851f"/><stop offset=".75" stop-color="#f2c45a"/><stop offset="1" stop-color="#8a5f14"/></radialGradient></defs><path d="M8,100 C48,71.4 84,48 154,48 A64,52 0 0 1 154,152 C84,152 48,128.6 8,100 Z" fill="none" stroke="url(#ogLogoGold)" stroke-width="8" stroke-linejoin="round"/><path d="M60,100 C90,63 166,63 196,100 C166,137 90,137 60,100 Z" fill="#0b0b0b" stroke="url(#ogLogoGold)" stroke-width="5.5"/><circle cx="128" cy="100" r="29" fill="url(#ogLogoIris)"/><circle cx="128" cy="100" r="11.5" fill="#070707"/><circle cx="122.8" cy="94.2" r="3.2" fill="#fff" fill-opacity=".85"/></svg><strong style="font-weight:300;letter-spacing:.1em;text-transform:none">ojo guard</strong>', '<svg class="brand-logo" viewBox="0 0 120 72" width="44" height="26" aria-hidden="true" focusable="false"><defs><linearGradient id="ogOroA" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#F1D58A"/><stop offset=".5" stop-color="#D4A94D"/><stop offset="1" stop-color="#A67C32"/></linearGradient></defs><path d="M4 36C30 10 62 6 84 8C104 10 116 22 116 36C116 50 104 62 84 64C62 66 30 62 4 36Z" fill="#0F1A3A" stroke="#B48A3C" stroke-width="1"/><path d="M10 36C32 15 60 12 82 14C98 16 107 25 107 36C107 47 98 56 82 58C60 60 32 57 10 36Z" fill="none" stroke="url(#ogOroA)" stroke-width="3.4" stroke-linejoin="round"/><path d="M30 36Q66 -6 101 36Q66 78 30 36Z" fill="none" stroke="url(#ogOroA)" stroke-width="2.6" stroke-linejoin="round"/><circle cx="66" cy="36" r="17" fill="#1B2D5E" stroke="url(#ogOroA)" stroke-width="2.2"/><circle cx="66" cy="36" r="8.6" fill="#05060B"/><circle cx="60.6" cy="30.2" r="2.8" fill="#EEF2FF" fill-opacity=".92"/></svg><strong style="font-weight:600;letter-spacing:-.01em;text-transform:none;font-size:1.15em;color:var(--e-texto)"><i class="o">O</i>jo Guard</strong>'),
    @('src\panel-index.html', 'logo nuevo en la pantalla de acceso', '<svg class="acceso-marca" viewBox="0 40 226 120" width="168" height="89" aria-hidden="true"><defs><linearGradient id="ogAccGold" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffd978"/><stop offset=".5" stop-color="#e2a93a"/><stop offset="1" stop-color="#9c6a1a"/></linearGradient><radialGradient id="ogAccIris"><stop offset="0" stop-color="#3a2606"/><stop offset=".35" stop-color="#b9851f"/><stop offset=".75" stop-color="#f2c45a"/><stop offset="1" stop-color="#8a5f14"/></radialGradient></defs><path d="M8,100 C48,71.4 84,48 154,48 A64,52 0 0 1 154,152 C84,152 48,128.6 8,100 Z" fill="none" stroke="url(#ogAccGold)" stroke-width="6.5" stroke-linejoin="round"/><path d="M60,100 C90,63 166,63 196,100 C166,137 90,137 60,100 Z" fill="#0b0b0b" stroke="url(#ogAccGold)" stroke-width="4.5"/><circle cx="128" cy="100" r="29" fill="url(#ogAccIris)"/><line x1="140.5" y1="100.0" x2="155.0" y2="100.0" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="140.3" y1="102.2" x2="154.6" y2="104.7" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="139.7" y1="104.3" x2="153.4" y2="109.2" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="138.8" y1="106.2" x2="151.4" y2="113.5" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="137.6" y1="108.0" x2="148.7" y2="117.4" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="136.0" y1="109.6" x2="145.4" y2="120.7" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="134.2" y1="110.8" x2="141.5" y2="123.4" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="132.3" y1="111.7" x2="137.2" y2="125.4" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="130.2" y1="112.3" x2="132.7" y2="126.6" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="128.0" y1="112.5" x2="128.0" y2="127.0" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="125.8" y1="112.3" x2="123.3" y2="126.6" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="123.7" y1="111.7" x2="118.8" y2="125.4" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="121.8" y1="110.8" x2="114.5" y2="123.4" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="120.0" y1="109.6" x2="110.6" y2="120.7" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="118.4" y1="108.0" x2="107.3" y2="117.4" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="117.2" y1="106.2" x2="104.6" y2="113.5" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="116.3" y1="104.3" x2="102.6" y2="109.2" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="115.7" y1="102.2" x2="101.4" y2="104.7" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="115.5" y1="100.0" x2="101.0" y2="100.0" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="115.7" y1="97.8" x2="101.4" y2="95.3" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="116.3" y1="95.7" x2="102.6" y2="90.8" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="117.2" y1="93.8" x2="104.6" y2="86.5" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="118.4" y1="92.0" x2="107.3" y2="82.6" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="120.0" y1="90.4" x2="110.6" y2="79.3" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="121.8" y1="89.2" x2="114.5" y2="76.6" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="123.7" y1="88.3" x2="118.8" y2="74.6" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="125.8" y1="87.7" x2="123.3" y2="73.4" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="128.0" y1="87.5" x2="128.0" y2="73.0" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="130.2" y1="87.7" x2="132.7" y2="73.4" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="132.3" y1="88.3" x2="137.2" y2="74.6" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="134.2" y1="89.2" x2="141.5" y2="76.6" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="136.0" y1="90.4" x2="145.4" y2="79.3" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="137.6" y1="92.0" x2="148.7" y2="82.6" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="138.8" y1="93.8" x2="151.4" y2="86.5" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="139.7" y1="95.7" x2="153.4" y2="90.8" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="140.3" y1="97.8" x2="154.6" y2="95.3" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><circle cx="128" cy="100" r="29" fill="none" stroke="#5a3d0c" stroke-width="2"/><circle cx="128" cy="100" r="11.5" fill="#070707"/><circle cx="122.8" cy="94.2" r="3.2" fill="#fff" fill-opacity=".85"/></svg>', '<svg class="acceso-marca" viewBox="0 0 120 72" width="168" height="101" aria-hidden="true" focusable="false"><defs><linearGradient id="ogOroB" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#F1D58A"/><stop offset=".5" stop-color="#D4A94D"/><stop offset="1" stop-color="#A67C32"/></linearGradient></defs><path d="M4 36C30 10 62 6 84 8C104 10 116 22 116 36C116 50 104 62 84 64C62 66 30 62 4 36Z" fill="#0F1A3A" stroke="#B48A3C" stroke-width="1"/><path d="M10 36C32 15 60 12 82 14C98 16 107 25 107 36C107 47 98 56 82 58C60 60 32 57 10 36Z" fill="none" stroke="url(#ogOroB)" stroke-width="3.4" stroke-linejoin="round"/><path d="M30 36Q66 -6 101 36Q66 78 30 36Z" fill="none" stroke="url(#ogOroB)" stroke-width="2.6" stroke-linejoin="round"/><circle cx="66" cy="36" r="17" fill="#1B2D5E" stroke="url(#ogOroB)" stroke-width="2.2"/><circle cx="66" cy="36" r="8.6" fill="#05060B"/><circle cx="60.6" cy="30.2" r="2.8" fill="#EEF2FF" fill-opacity=".92"/></svg>'),
    @('src\panel-index.html', 'estilos del logo', '  </head>', '    <style id="logo-v1">
      .brand-logo{vertical-align:middle;margin-right:10px;flex:none}
      .brand .o{font-style:normal;position:relative;display:inline-block;line-height:1}
      .brand .o::after{content:"";position:absolute;left:50%;top:54%;width:.2em;height:.2em;border-radius:50%;background:var(--e-dorado);transform:translate(-50%,-50%)}
      .acceso-marca{filter:none !important;width:168px;height:auto}
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
    if (Test-Path ($ruta + ".bak-logoconsola")) { Mal ("Ya existe " + $t + ".bak-logoconsola. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-logoconsola"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-logoconsola): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-logoconsola") -Destination $ruta -Force }
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
Ok "LISTO: la consola quedo con el logo nuevo. Abrila con Ctrl+F5."
Write-Host ""
