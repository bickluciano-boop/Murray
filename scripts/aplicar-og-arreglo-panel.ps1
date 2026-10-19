# aplicar-og-arreglo-panel.ps1 - Arregla el boton "OG" de la barra de arriba del panel en pantallas angostas (celular).
# Luciano (19/10/2026, foto en Android): el OG quedaba encima del nombre "ojo guard" y "Modo noche" / "Cerrar acceso" no entraban.
#  - En pantallas angostas (hasta 560 px) la barra pasa a dos filas: arriba el nombre "ojo guard"; abajo, alineados a la derecha, OG, Modo noche y Cerrar acceso.
#  - El menu del OG se abre justo debajo de esa fila, adentro de la pantalla, sin tapar los botones. En compu no cambia nada.
#  - Un solo cambio de texto: reemplaza una linea de estilo en src\panel-explanations.css. No toca nada mas del panel.
# Requiere aplicar-og-panel.ps1 (ya instalado). Va en la carpeta del PANEL (la que tiene wrangler.toml).
# Respaldo .bak-og2; si algo falla, se restaura. Al final publica el panel solo. No hace falta build de la app.
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
$css = Join-Path $raiz "src\panel-explanations.css"
if (-not (Test-Path $css)) { Mal "No encuentro src\panel-explanations.css en esta carpeta."; return }
$c = Leer $css
if ((Contar $c.texto 'header.topbar .topbar-actions { flex: 1 1 100% !important;') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $c.texto '.og-guardian summary') -lt 1) { Mal "Falta el boton OG. Primero hay que aplicar aplicar-og-panel.ps1. No toco nada."; return }
$anclaC = Ajustar '@media (max-width: 640px) { .og-menu { position: fixed; top: 64px; right: 12px; left: auto; } }' $c.crlf
$nuevoC = Ajustar '@media (max-width: 560px) {
  header.topbar { display: flex !important; flex-wrap: wrap !important; align-items: center; row-gap: 8px; }
  header.topbar .brand { flex: 1 1 auto; min-width: 0; }
  header.topbar .topbar-actions { flex: 1 1 100% !important; justify-content: flex-end; flex-wrap: wrap; position: relative; }
  .og-guardian { position: static; }
  .og-menu { position: absolute; right: 0; left: auto; top: calc(100% + 8px); }
}' $c.crlf
$nC = Contar $c.texto $anclaC
if ($nC -eq 1) { Ok "la regla del menu OG en el celular: 1" } else { Mal ("la regla del menu OG en el celular: " + $nC + " (esperaba 1). No toco nada. Mandame esta pantalla."); return }
if (Test-Path ($css + ".bak-og2")) { Mal "Ya existe un respaldo .bak-og2. No toco nada."; return }
Copy-Item -LiteralPath $css -Destination ($css + ".bak-og2")
Ok "Respaldo creado: panel-explanations.css.bak-og2"
$nuevoCss = $c.texto.Replace($anclaC, $nuevoC)
$esperadoC = $c.texto.Length + ($nuevoC.Length - $anclaC.Length)
[System.IO.File]::WriteAllText($css, $nuevoCss, (New-Object System.Text.UTF8Encoding($c.bom)))
$cv = Leer $css
$bien = ($cv.texto.Length -eq $esperadoC) -and ((Contar $cv.texto $nuevoC) -eq 1) -and ((Contar $cv.texto $anclaC) -eq 0)
if (-not $bien) {
    Mal "Algo no salio bien. Restauro el archivo desde el respaldo."
    Copy-Item -LiteralPath ($css + ".bak-og2") -Destination $css -Force
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Ok ("panel-explanations.css: largo " + $cv.texto.Length + " (esperado " + $esperadoC + ")")
Write-Host ""
Ok "Archivo listo. Ahora publico el panel..."
& npx.cmd wrangler deploy
if ($LASTEXITCODE -ne 0) { Mal "No se pudo publicar el panel. Mandame esta pantalla."; return }
Write-Host ""
Ok "LISTO: el boton OG ya no se pisa con el nombre en el celular. Recarga el panel con Ctrl+F5."
Write-Host ""
