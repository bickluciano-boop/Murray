# aplicar-mapa-centrar-mi-panel.ps1 - El boton circulo de arriba a la derecha del mapa va a donde estas VOS, como el de Google Maps.
# Luciano (23/10/2026): "apretando el boton no se acomoda ni te pone el cursor; en Google Maps si". Antes el boton era solo "Ver todos": volvia a encuadrar a
# todos los equipos, y como el mapa ya estaba encuadrado asi no se notaba nada. Ahora: primer toque = va a tu ubicacion y se acerca; el siguiente = muestra
# a todos los equipos con ubicacion RECIENTE (menos de 6 horas) y no solo aproximada por internet (maximo 1500 m de margen), para que un equipo viejo o mal
# ubicado (por ejemplo la Mac por IP) no aleje el mapa. Si ninguno es confiable, usa todos como antes. Tocar el mapa o a un equipo vuelve a "mi ubicacion".
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Toca solo src\panel-mapa.txt. Respaldo .bak-centrarmi. Al final publica el panel solo. No hace falta build.
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
if (-not (Test-Path (Join-Path $raiz "src\panel-mapa.txt"))) { Mal "No encuentro src\panel-mapa.txt en esta carpeta."; return }
$mapaTexto = (Leer (Join-Path $raiz "src\panel-mapa.txt")).texto
if ((Contar $mapaTexto 'function botonCentrar') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $mapaTexto 'function encuadrarTodo') -ne 1) { Mal "No encuentro la funcion encuadrarTodo en el mapa. Mandame esta pantalla."; return }
$cambios = @(
    @('src\panel-mapa.txt', 'boton centrar: va a mi ubicacion y luego a todos', '      return encuadrarTodo();', '      return botonCentrar();'),
    @('src\panel-mapa.txt', 'encuadre: solo equipos con ubicacion reciente y no aproximada', 'function encuadrarTodo() {
  const puntos = estado.equipos.filter((e) => e.lat !== null);
  estado.proveedor?.encuadrar(puntos, margenMapa());
}', '/** Cuenta para el encuadre un equipo con ubicacion de menos de 6 horas y que no sea solo aproximada (por internet: miles de metros de margen). */
function ubicacionConfiable(e) {
  const edad = e.ubicadoEn ? Date.now() - new Date(e.ubicadoEn).getTime() : Infinity;
  return e.lat !== null && edad < 6 * 3600000 && (e.precision === null || e.precision <= 1500);
}

function encuadrarTodo() {
  const conUbicacion = estado.equipos.filter((e) => e.lat !== null);
  const confiables = conUbicacion.filter(ubicacionConfiable);
  estado.proveedor?.encuadrar(confiables.length ? confiables : conUbicacion, margenMapa());
}

/** El boton circulo, como el de Google Maps: el primer toque va a donde estas vos y se acerca; el siguiente muestra a todos los equipos recientes. */
function botonCentrar() {
  if (estado.yo && !estado.enMi) {
    estado.enMi = true;
    return estado.proveedor?.centrar(estado.yo, CONFIG.zoomMaximo);
  }
  estado.enMi = false;
  return encuadrarTodo();
}'),
    @('src\panel-mapa.txt', 'tocar el mapa vuelve a "mi ubicacion"', '  raiz.addEventListener("click", (evento) => {', '  // Tocar o arrastrar el mapa (o cualquier otra cosa menos el boton circulo) hace que el proximo toque del boton vuelva a llevarte a tu ubicacion.
  raiz.addEventListener("pointerdown", (evento) => { if (!evento.target.closest("[data-ogm=centrar]")) estado.enMi = false; });
  raiz.addEventListener("click", (evento) => {')
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
    if (Test-Path ($ruta + ".bak-centrarmi")) { Mal ("Ya existe " + $t + ".bak-centrarmi. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-centrarmi"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-centrarmi): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-centrarmi") -Destination $ruta -Force }
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
Ok "LISTO: el panel quedo publicado. Cerra la app y abrila de nuevo: el boton circulo del mapa va a tu ubicacion (primer toque) y despues muestra a todos (segundo toque)."
Write-Host ""
