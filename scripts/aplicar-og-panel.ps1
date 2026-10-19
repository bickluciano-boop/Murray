# aplicar-og-panel.ps1 - Un boton "OG" en la barra de arriba del panel: entrada a "Tu proteccion" (Modo Cautela y Modo Guardian).
# Luciano (19/10/2026): "y si le ponemos OG, y cuando pones el mouse o el dedo te dice abajo: Modo Guardian / Modo Cautela". OG = Ojo Guard.
#  - Solo aparece con la sesion abierta (junto a "Cerrar acceso"). Con el mouse encima dice "Modo Guardian - Modo Cautela"; al tocarlo se abre un menu
#    con los dos modos y "Abrir Tu proteccion", que lleva a /guardian. En el celular el menu queda pegado al borde derecho, debajo de la barra.
#  - Dos cambios de texto: una linea de HTML en src\panel-index.html y unas reglas de estilo en src\panel-explanations.css. No toca nada mas del panel.
# Requiere aplicar-guardian-modo-cautela-panel.ps1 (la pagina /guardian). Va en la carpeta del PANEL (la que tiene wrangler.toml).
# Respaldos .bak-og de los dos archivos; si algo falla, se restauran. Al final publica el panel solo. No hace falta build de la app.
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
if ((Contar $h.texto 'class="og-guardian"') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
$anclaH = Ajustar '<button id="logout" class="ghost hidden">Cerrar acceso</button>' $h.crlf
$nuevoH = Ajustar '<button id="logout" class="ghost hidden">Cerrar acceso</button>
          <details class="og-guardian">
            <summary class="ghost" title="Modo Guardi&#225;n &middot; Modo Cautela" aria-label="Tu protecci&#243;n: Modo Cautela y Modo Guardi&#225;n">OG</summary>
            <div class="og-menu">
              <a href="/guardian"><strong>Modo Cautela</strong><span>Por las dudas: si dejo de responder, mis referentes se enteran.</span></a>
              <a href="/guardian"><strong>Modo Guardi&#225;n</strong><span>Te acompa&#241;a en el camino. Pr&#243;ximamente.</span></a>
              <a class="og-ir" href="/guardian">Abrir Tu protecci&#243;n &#8594;</a>
            </div>
          </details>' $h.crlf
$anclaC = Ajustar '.topbar-actions { gap: 5px; }' $c.crlf
$nuevoC = Ajustar '.topbar-actions { gap: 5px; }
/* OG: entrada a Tu proteccion (Modo Cautela y Modo Guardian). Solo se ve con la sesion abierta (cuando "Cerrar acceso" se muestra). */
.og-guardian { display: none; position: relative; order: -1; }
#logout:not(.hidden) + .og-guardian { display: block; }
.og-guardian summary { list-style: none; cursor: pointer; padding: 8px 10px; font-size: 0.72rem; font-weight: 800; letter-spacing: 0.08em; border-radius: 999px; border: 1px solid #d9b24c; color: #d9b24c; background: transparent; user-select: none; white-space: nowrap; }
.og-guardian summary::-webkit-details-marker { display: none; }
.og-guardian[open] summary { background: #d9b24c; color: #111; }
.og-menu { position: absolute; right: 0; top: calc(100% + 8px); z-index: 80; width: min(290px, 86vw); display: grid; gap: 6px; padding: 10px; border-radius: 16px; background: #14151a; color: #f3f1ea; border: 1px solid #4a3f1f; box-shadow: 0 14px 40px rgba(0, 0, 0, 0.45); }
.og-menu a { display: grid; gap: 2px; color: inherit; text-decoration: none; padding: 8px 10px; border-radius: 12px; }
.og-menu a:hover, .og-menu a:focus-visible { background: #211d12; }
.og-menu strong { color: #f0c75a; font-size: 0.9rem; }
.og-menu span { color: #a29e92; font-size: 0.78rem; line-height: 1.35; }
.og-menu .og-ir { color: #f0c75a; font-weight: 700; font-size: 0.82rem; text-align: right; }
@media (max-width: 640px) { .og-menu { position: fixed; top: 64px; right: 12px; left: auto; } }' $c.crlf
$ok = $true
$nH = Contar $h.texto $anclaH
if ($nH -eq 1) { Ok "el boton Cerrar acceso en panel-index.html: 1" } else { Mal ("el boton Cerrar acceso en panel-index.html: " + $nH + " (esperaba 1)"); $ok = $false }
$nC = Contar $c.texto $anclaC
if ($nC -eq 1) { Ok "la regla .topbar-actions en panel-explanations.css: 1" } else { Mal ("la regla .topbar-actions en panel-explanations.css: " + $nC + " (esperaba 1)"); $ok = $false }
if (-not $ok) { Mal "Alguna ancla no coincide. No toco nada. Mandame esta pantalla."; return }
if ((Test-Path ($html + ".bak-og")) -or (Test-Path ($css + ".bak-og"))) { Mal "Ya existe un respaldo .bak-og. No toco nada."; return }
Copy-Item -LiteralPath $html -Destination ($html + ".bak-og")
Copy-Item -LiteralPath $css -Destination ($css + ".bak-og")
Ok "Respaldos creados: panel-index.html.bak-og y panel-explanations.css.bak-og"
$nuevoHtml = $h.texto.Replace($anclaH, $nuevoH)
$nuevoCss = $c.texto.Replace($anclaC, $nuevoC)
$esperadoH = $h.texto.Length + ($nuevoH.Length - $anclaH.Length)
$esperadoC = $c.texto.Length + ($nuevoC.Length - $anclaC.Length)
[System.IO.File]::WriteAllText($html, $nuevoHtml, (New-Object System.Text.UTF8Encoding($h.bom)))
[System.IO.File]::WriteAllText($css, $nuevoCss, (New-Object System.Text.UTF8Encoding($c.bom)))
$hv = Leer $html
$cv = Leer $css
$bien = ($hv.texto.Length -eq $esperadoH) -and ($cv.texto.Length -eq $esperadoC) -and ((Contar $hv.texto 'class="og-guardian"') -eq 1) -and ((Contar $cv.texto '.og-guardian summary') -ge 1)
if (-not $bien) {
    Mal "Algo no salio bien. Restauro los dos archivos desde los respaldos."
    Copy-Item -LiteralPath ($html + ".bak-og") -Destination $html -Force
    Copy-Item -LiteralPath ($css + ".bak-og") -Destination $css -Force
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
Ok "LISTO: ya esta el boton OG arriba (con la sesion abierta). Recarga el panel con Ctrl+F5."
Write-Host ""
