# aplicar-mapa-textos-compu-panel.ps1 - Los mensajes de las ordenes dicen "la computadora" cuando el equipo es una computadora (antes siempre decian "el telefono").
# Luciano (23/10/2026): al pedir Evidencia a la Mac aparecia "Orden guardada - se ejecuta cuando el telefono se conecte".
# Solo cambia textos de la tarjeta (Hacer sonar, Ubicar ahora, Evidencia). No cambia lo que hacen las ordenes.
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Toca solo src\panel-mapa.txt. Respaldo .bak-textoscompu. Al final publica el panel solo. No hace falta build.
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
if ((Contar $mapaTexto 'function esCompu') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $mapaTexto 'async function ordenar(tipo, boton, equipo = equipoElegido())') -ne 1) { Mal "No encuentro la funcion ordenar en el mapa. Mandame esta pantalla."; return }
$cambios = @(
    @('src\panel-mapa.txt', 'textos: ordenar sabe si es computadora', 'async function ordenar(tipo, boton, equipo = equipoElegido()) {
  if (!equipo) return;
  const avisar = (texto) => mensajeTarjeta(texto, equipo.id);', '/** Computadora (Windows o Mac): los avisos dicen "la computadora" y no "el telefono". */
function esCompu(equipo) {
  return /windows|mac ?os|\bmac\b|linux|computadora|notebook|\bpc\b/i.test(`${equipo.plataforma} ${equipo.nombre}`);
}

async function ordenar(tipo, boton, equipo = equipoElegido()) {
  if (!equipo) return;
  const avisar = (texto) => mensajeTarjeta(texto, equipo.id);
  const compu = esCompu(equipo);
  const aparato = compu ? "la computadora" : "el teléfono";
  const Aparato = compu ? "La computadora" : "El teléfono";'),
    @('src\panel-mapa.txt', 'textos: orden enviada o guardada', 'avisar(r.pushSent ? "Orden enviada · esperando al teléfono." : "Orden guardada · se ejecuta cuando el teléfono se conecte.");', 'avisar(r.pushSent ? `Orden enviada · esperando ${compu ? "a la computadora" : "al teléfono"}.` : `Orden guardada · se ejecuta cuando ${aparato} se conecte.`);'),
    @('src\panel-mapa.txt', 'textos: evidencia sacada', '"El teléfono sacó la foto y el audio. Te llegan por mail."', '`${Aparato} sacó la foto y el audio. Te llegan por mail.`'),
    @('src\panel-mapa.txt', 'textos: no se pudo sacar la foto', '|| "el teléfono no pudo sacar la foto."', '|| `${aparato} no pudo sacar la foto.`'),
    @('src\panel-mapa.txt', 'textos: sonando', '"El teléfono está sonando. Se corta solo al minuto."', '`${Aparato} está sonando. Se corta solo al minuto.`'),
    @('src\panel-mapa.txt', 'textos: orden fallida', '"El teléfono no pudo completar la orden."', '`${Aparato} no pudo completar la orden.`'),
    @('src\panel-mapa.txt', 'textos: pedido de evidencia pendiente', 'avisar("Pedido enviado. La foto y el audio se sacan cuando el teléfono puede (en iPhone, al abrir Ojo Guard) y te llegan por mail.");', 'avisar(compu ? "Pedido enviado. La foto y el audio se sacan cuando la computadora puede y te llegan por mail." : "Pedido enviado. La foto y el audio se sacan cuando el teléfono puede (en iPhone, al abrir Ojo Guard) y te llegan por mail.");')
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
    if (Test-Path ($ruta + ".bak-textoscompu")) { Mal ("Ya existe " + $t + ".bak-textoscompu. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-textoscompu"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-textoscompu): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-textoscompu") -Destination $ruta -Force }
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
Ok "LISTO: el panel quedo publicado. Cerra la app y abrila de nuevo: al pedirle algo a la Mac, los avisos dicen la computadora."
Write-Host ""
