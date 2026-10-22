# aplicar-consola-pines-panel.ps1 - Consola (Ojo Guard MS): los pines del mapa. Las personas con su cara (o la inicial) y aro blanco; los equipos con su icono blanco sobre azul; el elegido se agranda y se marca en azul; el nombre en una pastilla.
# Luciano (22/10/2026): "lo bueno es o los dispositivos o nombres o caras". Solo APARIENCIA: se agrega un bloque <style id="estetica-v5">. Ninguna funcion cambia (ni que pin se elige, ni a donde lleva).
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Toca solo src\panel-index.html, y solo si es el que dejo aplicar-consola-mapa-panel.ps1 (huella SHA-256 antes y despues). Respaldo .bak-consolapines. Al final publica
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
if ((Contar (Leer (Join-Path $raiz "src\panel-index.html")).texto 'id="estetica-v5"') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
function ShaTexto([string]$t) {
    $h = [System.Security.Cryptography.SHA256]::Create()
    return ([System.BitConverter]::ToString($h.ComputeHash([System.Text.Encoding]::UTF8.GetBytes(($t -replace "`r`n", "`n"))))).Replace("-", "").ToLower()
}
$originales = @{
    'src\panel-index.html' = 'a0173c4ca326b2ee832ffaf6b6ce02ce9075e99226855b33bd993f262663ae35'
}
$finales = @{
    'src\panel-index.html' = '918d50cb0777e328dc31665b80b0c1cdd5d09e8dfe158ba52bae5b99c6a3be72'
}
foreach ($k in $originales.Keys) {
    $huella = ShaTexto (Leer (Join-Path $raiz $k)).texto
    if ($huella -ne $originales[$k]) { Mal ($k + " no es el que dejo aplicar-consola-mapa-panel.ps1 (huella " + $huella + "). No toco nada. Mandame esta pantalla."); return }
}
Ok "src\panel-index.html es el de la consola con el mapa nuevo"
$cambios = @(
    ,@('src\panel-index.html', 'pines del mapa (cara o inicial, icono del equipo, nombre en pastilla)', '  </head>', '    <style id="estetica-v5">
/* estetica-v5: pines del mapa. Personas: cara (o inicial) con aro blanco. Equipos: icono blanco sobre azul. El elegido se agranda y se marca en azul; el nombre va en una pastilla. */
#og-mapa .ogm-pin .ogm-av{background:var(--e-azul-suave) !important;color:var(--e-azul) !important;border:3px solid #fff !important;box-shadow:0 6px 18px rgba(20,33,61,.30) !important}
#og-mapa .ogm-pin .ogm-av.ogm-av-dibujo{background:var(--e-azul) !important;color:#fff !important}
#og-mapa .ogm-pin.sel .ogm-av{border-color:var(--e-azul) !important}
#og-mapa .ogm-pin.sel .ogm-av.ogm-av-dibujo{border-color:#fff !important;box-shadow:0 0 0 4px var(--e-azul),0 6px 18px rgba(20,33,61,.30) !important}
#og-mapa .ogm-pin.off .ogm-av{filter:grayscale(1);opacity:.85}
#og-mapa .ogm-halo{background:radial-gradient(circle,rgba(31,79,209,.34),rgba(31,79,209,0) 70%) !important}
#og-mapa .ogm-etq{background:var(--e-tarjeta) !important;color:var(--e-texto) !important;border:0 !important;border-radius:999px !important;padding:4px 12px !important;box-shadow:0 4px 14px rgba(20,33,61,.22) !important}
#og-mapa .ogm-etq em{color:var(--e-suave) !important}
#og-mapa .ogm-pin .ogm-marca{display:none}
#og-mapa .ogm-pin.sel .ogm-etq{background:var(--e-azul) !important;color:#fff !important}
#og-mapa .ogm-pin.sel .ogm-etq em{color:rgba(255,255,255,.82) !important}
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
    if (Test-Path ($ruta + ".bak-consolapines")) { Mal ("Ya existe " + $t + ".bak-consolapines. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-consolapines"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-consolapines): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-consolapines") -Destination $ruta -Force }
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
Ok "LISTO: los pines del mapa quedaron con el estilo nuevo. Abrila con Ctrl+F5."
Write-Host ""
