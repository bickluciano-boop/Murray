# aplicar-og-importante-panel.ps1 - El boton OG de la barra de arriba del panel: mas importante, debajo del logo, y un menu mas ancho.
# Luciano (19/10/2026, fotos en Android): "yo pondria el OG debajo del logo y en la misma linea horizontal, y que se parezca mas a un boton de importancia" y
# "la carpeta negra la haria un poco mas ancha para que no quede abajo que se ven las palabras".
#  - OG pasa a ser un boton dorado macizo (mas grande, con sombra); abierto se invierte (oscuro con letras doradas). En el celular queda a la IZQUIERDA, debajo del logo,
#    en la misma fila que Modo noche y Cerrar acceso (que siguen a la derecha).
#  - El menu negro ocupa todo el ancho de la fila en el celular (y hasta 380 px en la compu) y el texto de Modo Cautela se acorta ("Si dejo de responder, mis referentes se enteran.")
#    para que no quede una palabra sola en la segunda linea.
#  - Cambia una linea de texto en src\panel-index.html y cinco lineas de estilo en src\panel-explanations.css. No toca nada mas del panel.
# Requiere aplicar-og-panel.ps1 y aplicar-og-arreglo-panel.ps1 (ya instalados). Va en la carpeta del PANEL (la que tiene wrangler.toml).
# Respaldos .bak-og3 de los dos archivos; si algo falla, se restauran. Al final publica el panel solo. No hace falta build de la app.
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
$html = Join-Path $raiz "src\panel-index.html"
$css = Join-Path $raiz "src\panel-explanations.css"
if (-not (Test-Path $html)) { Mal "No encuentro src\panel-index.html en esta carpeta."; return }
if (-not (Test-Path $css)) { Mal "No encuentro src\panel-explanations.css en esta carpeta."; return }
$h = Leer $html
$c = Leer $css
if ((Contar $c.texto 'details.og-guardian > summary.ghost') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $c.texto 'header.topbar .topbar-actions { flex: 1 1 100% !important;') -ne 1) { Mal "Falta aplicar antes aplicar-og-arreglo-panel.ps1. No toco nada."; return }
$anclaH = Ajustar '<span>Por las dudas: si dejo de responder, mis referentes se enteran.</span>' $h.crlf
$nuevoH = Ajustar '<span>Si dejo de responder, mis referentes se enteran.</span>' $h.crlf
$cambiosCss = @(
    @('el boton OG (aspecto)', '.og-guardian summary { list-style: none; cursor: pointer; padding: 8px 10px; font-size: 0.72rem; font-weight: 800; letter-spacing: 0.08em; border-radius: 999px; border: 1px solid #d9b24c; color: #d9b24c; background: transparent; user-select: none; white-space: nowrap; }', 'header.topbar .topbar-actions details.og-guardian > summary.ghost { list-style: none; cursor: pointer; padding: 10px 20px !important; font-size: 0.9rem !important; font-weight: 800 !important; letter-spacing: 0.12em; border-radius: 999px !important; border: 2px solid #b8932f !important; color: #1b1505 !important; background: #d9b24c !important; box-shadow: 0 3px 10px rgba(184, 147, 47, 0.45); user-select: none; white-space: nowrap; }'),
    @('el boton OG abierto', '.og-guardian[open] summary { background: #d9b24c; color: #111; }', 'header.topbar .topbar-actions details.og-guardian[open] > summary.ghost { background: #1b1505 !important; color: #f0c75a !important; border-color: #d9b24c !important; }'),
    @('el lugar del boton OG', '.og-guardian { display: none; position: relative; order: -1; }', '.og-guardian { display: none; position: relative; order: -1; margin-right: auto; }'),
    @('el ancho del menu', 'width: min(290px, 86vw);', 'width: min(380px, calc(100vw - 32px));'),
    @('el menu en el celular', '.og-menu { position: absolute; right: 0; left: auto; top: calc(100% + 8px); }', '.og-menu { position: absolute; left: 0; right: 0; width: auto; top: calc(100% + 8px); }')
)
$ok = $true
$nH = Contar $h.texto $anclaH
if ($nH -eq 1) { Ok "el texto de Modo Cautela en el menu OG (panel-index.html): 1" } else { Mal ("el texto de Modo Cautela en el menu OG (panel-index.html): " + $nH + " (esperaba 1)"); $ok = $false }
foreach ($x in $cambiosCss) {
    $n = Contar $c.texto (Ajustar $x[1] $c.crlf)
    if ($n -eq 1) { Ok ($x[0] + ": 1") } else { Mal ($x[0] + ": " + $n + " (esperaba 1)"); $ok = $false }
}
if (-not $ok) { Mal "Alguna ancla no coincide. No toco nada. Mandame esta pantalla."; return }
if ((Test-Path ($html + ".bak-og3")) -or (Test-Path ($css + ".bak-og3"))) { Mal "Ya existe un respaldo .bak-og3. No toco nada."; return }
Copy-Item -LiteralPath $html -Destination ($html + ".bak-og3")
Copy-Item -LiteralPath $css -Destination ($css + ".bak-og3")
Ok "Respaldos creados: panel-index.html.bak-og3 y panel-explanations.css.bak-og3"
$nuevoHtml = $h.texto.Replace($anclaH, $nuevoH)
$esperadoH = $h.texto.Length + ($nuevoH.Length - $anclaH.Length)
$nuevoCss = $c.texto
$esperadoC = $c.texto.Length
foreach ($x in $cambiosCss) {
    $v1 = Ajustar $x[1] $c.crlf; $v2 = Ajustar $x[2] $c.crlf
    $nuevoCss = $nuevoCss.Replace($v1, $v2)
    $esperadoC = $esperadoC + ($v2.Length - $v1.Length)
}
[System.IO.File]::WriteAllText($html, $nuevoHtml, (New-Object System.Text.UTF8Encoding($h.bom)))
[System.IO.File]::WriteAllText($css, $nuevoCss, (New-Object System.Text.UTF8Encoding($c.bom)))
$hv = Leer $html
$cv = Leer $css
$bien = ($hv.texto.Length -eq $esperadoH) -and ($cv.texto.Length -eq $esperadoC) -and ((Contar $hv.texto $nuevoH) -eq 1) -and ((Contar $hv.texto 'class="og-guardian"') -eq 1)
foreach ($x in $cambiosCss) {
    if ((Contar $cv.texto (Ajustar $x[2] $c.crlf)) -ne 1) { $bien = $false }
    if ((Contar $cv.texto (Ajustar $x[1] $c.crlf)) -ne 0) { $bien = $false }
}
if (-not $bien) {
    Mal "Algo no salio bien. Restauro los dos archivos desde los respaldos."
    Copy-Item -LiteralPath ($html + ".bak-og3") -Destination $html -Force
    Copy-Item -LiteralPath ($css + ".bak-og3") -Destination $css -Force
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Ok ("panel-index.html: largo " + $hv.texto.Length + " (esperado " + $esperadoH + ")")
Ok ("panel-explanations.css: largo " + $cv.texto.Length + " (esperado " + $esperadoC + ")")
Write-Host ""
Ok "Archivos listos. Ahora publico el panel..."
& npx.cmd wrangler deploy
if ($LASTEXITCODE -ne 0) { Mal "No se pudo publicar el panel. Mandame esta pantalla."; return }
Write-Host ""
Ok "LISTO: el boton OG ahora es dorado, queda debajo del logo y el menu es mas ancho. Recarga el panel con Ctrl+F5."
Write-Host ""
