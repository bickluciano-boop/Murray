# aplicar-mapa-lista-fila-panel.ps1 - La lista de abajo (Familia y equipos) empieza en UNA FILA, y sin En vivo/Hoy/7 dias mientras no hay nadie elegido.
# Luciano (16/10/2026), mirando el Inicio con la lista abierta (casi un tercio del mapa): eligio "Lista en una fila" y "Ocultar En vivo/Hoy/7 dias".
#  - Al abrir el mapa en la app, la lista muestra una sola fila: "Familia y equipos" y el boton Sumar. Un toque en la fila (o en la manija) abre la
#    lista completa con todas las personas y equipos, y otro la vuelve a cerrar. Al cerrar la tarjeta de un equipo (la cruz) se vuelve a la fila.
#  - La fila En vivo / Hoy / 7 dias solo sirve para el recorrido del equipo elegido: se esconde mientras no hay nadie elegido y aparece al elegir uno.
# Nada se pierde; la lista, los botones de sonar y Sumar siguen igual al abrirla. Tocar un pin del mapa sigue eligiendo a ese equipo sin abrir la lista.
# Requiere aplicar-mapa-tarjeta-fila-panel.ps1. Va en la carpeta del PANEL (la que tiene wrangler.toml). Toca src\panel-mapa.txt y
# src\panel-explanations.css. Respaldo .bak-listafila. Al final publica el panel solo. No hace falta build.
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
foreach ($f in @("src\panel-mapa.txt", "src\panel-explanations.css")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
$mapaTexto = (Leer (Join-Path $raiz "src\panel-mapa.txt")).texto
if ((Contar $mapaTexto '"ogm hidden ogm-plegada"') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $mapaTexto 'toggle("ogm-plegada", EN_APP)') -ne 1) { Mal "Falta aplicar antes aplicar-mapa-tarjeta-fila-panel.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\panel-explanations.css")).texto '/* Botones en pastilla (como el dibujo de la consola). */') -ne 1) { Mal "Falta aplicar antes los pasos de la consola (pestanas, ayudas, equipos)."; return }
$cambios = @(
    @('src\panel-mapa.txt', 'lista: empieza plegada en la app', '  raiz.className = "ogm hidden";', '  // En la app la lista de abajo empieza plegada en una fila (se abre tocandola); en la compu sigue abierta como siempre.
  raiz.className = EN_APP ? "ogm hidden ogm-plegada" : "ogm hidden";'),
    @('src\panel-mapa.txt', 'lista: al cerrar la tarjeta vuelve plegada', '  estado.mensajeVivo = "";
  $("#og-mapa")?.classList.remove("ogm-plegada");
  dibujar();', '  estado.mensajeVivo = "";
  // Al cerrar la tarjeta se vuelve a la lista, plegada en una fila.
  $("#og-mapa")?.classList.toggle("ogm-plegada", EN_APP);
  dibujar();'),
    @('src\panel-mapa.txt', 'lista: un toque en el titulo la abre o la cierra', 'if (esCelular() && evento.target.closest(".ogm-cab, .ogm-direc")) plegar(!raiz.classList.contains("ogm-plegada"));', 'if (esCelular() && evento.target.closest(".ogm-cab, .ogm-direc, .ogm-lado h2")) plegar(!raiz.classList.contains("ogm-plegada"));'),
    @('src\panel-explanations.css', 'mapa: lista en una fila', '/* Botones en pastilla (como el dibujo de la consola). */', '/* Lista de abajo (Familia y equipos) en UNA FILA, igual que la tarjeta de un equipo: empieza plegada con el titulo y el boton Sumar, y se abre tocandola
   (o con la manija); mientras no hay nadie elegido no se muestra En vivo / Hoy / 7 dias (solo sirve para el recorrido del equipo elegido). */
@media (max-width: 899px) {
  html.app-mapa #og-mapa.ogm-plegada.ogm-sin-elegir .ogm-lado > .ogm-invitar.ogm-invitar.ogm-invitar { display: inline-flex; }
  html.app-mapa #og-mapa.ogm-plegada.ogm-sin-elegir .ogm-lado { padding-bottom: 6px; overflow: hidden; }
  html.app-mapa #og-mapa.ogm-plegada.ogm-sin-elegir .ogm-asa-lista { height: 14px; }
  html.app-mapa #og-mapa.ogm-plegada.ogm-sin-elegir .ogm-asa-lista::before { top: 4px; }
  html.app-mapa #og-mapa.ogm-sin-elegir .ogm-seg { display: none; }
}

/* Botones en pastilla (como el dibujo de la consola). */')
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
    if (Test-Path ($ruta + ".bak-listafila")) { Mal ("Ya existe " + $t + ".bak-listafila. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-listafila"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-listafila): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-listafila") -Destination $ruta -Force }
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
Ok "LISTO: el panel quedo publicado. Cerra la app y abrila de nuevo: la lista de abajo es una fila y se abre al tocarla."
Write-Host ""
