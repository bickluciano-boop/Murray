# aplicar-mapa-cerrar-pc-panel.ps1 - Ojo Guard MS: en el panel de la compu la tarjeta del equipo o la persona (la que abre un pin o una fila de la lista) se puede cerrar.
# Luciano (03/11/2026): "me quedo en esta pantalla y no tengo manera de salir; toco en el mapa y no se va, toco en la parte blanca y tampoco". Era cierto: la X de cerrar solo existia en la app; en la compu la tarjeta quedaba abierta para siempre (solo cambiaba al elegir otra).
# Ahora: una X arriba a la derecha de la tarjeta, la tecla Esc y un clic en el mapa vacio. Cerrar la tarjeta deja de seguir en vivo, igual que en la app. No se cierra mientras hay un cuadro abierto (aviso de lugar, invitacion) ni al elegir el punto de un aviso. La app no cambia.
# Cambia SOLO src\panel-mapa.txt (respaldo .bak-cerrarpc). Va en la carpeta del PANEL (la que tiene wrangler.toml). No necesita build. Al final publica el panel solo.
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
if ((Contar (Leer (Join-Path $raiz "src\panel-mapa.txt")).texto 'ogm-cerrar-pc') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
$cambios = @(
    @('src\panel-mapa.txt', 'mapa: boton X para cerrar la tarjeta en la compu', '    </div>
    <p class="ogm-direc">', '      <button type="button" class="ogm-cerrar-pc" data-accion="soltar" aria-label="Cerrar la tarjeta" title="Cerrar (Esc)" style="position:absolute;top:8px;right:10px;z-index:2;width:30px;height:30px;border-radius:50%;border:1px solid rgba(128,128,128,.45);background:rgba(128,128,128,.16);color:inherit;font-size:.9rem;line-height:1;cursor:pointer;display:grid;place-items:center">&#10005;</button>
    </div>
    <p class="ogm-direc">'),
    @('src\panel-mapa.txt', 'mapa: clic en el mapa vacio y Esc cierran la tarjeta', 'estado.proveedor.alTocarMapa(() => { if (esCelular()) plegar(true); });', '// En la compu la tarjeta se cierra con un clic en el mapa vacio o con Esc (en el celular el clic la pliega). El clic de un pin no la cierra: elegir() anota cuando se eligio.
      estado.proveedor.alTocarMapa(() => {
        if (esCelular()) return plegar(true);
        if (!EN_APP && estado.elegido && !estado.dialogo && !estado.eligiendoLugar && Date.now() - (estado.ultimaEleccion || 0) > 400) soltar();
      });
      document.addEventListener("keydown", (evento) => {
        if (evento.key === "Escape" && !EN_APP && estado.elegido && !estado.dialogo && !estado.eligiendoLugar) soltar();
      });'),
    @('src\panel-mapa.txt', 'mapa: anotar cuando se eligio un equipo', 'async function elegir(id, centrar) {
  if (estado.elegido !== id) {', 'async function elegir(id, centrar) {
  estado.ultimaEleccion = Date.now();
  if (estado.elegido !== id) {')
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
    if (Test-Path ($ruta + ".bak-cerrarpc")) { Mal ("Ya existe " + $t + ".bak-cerrarpc. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-cerrarpc"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-cerrarpc): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-cerrarpc") -Destination $ruta -Force }
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
Ok "LISTO: la tarjeta del mapa ya se cierra con la X, con Esc o con un clic en el mapa vacio (recarga la pagina con Ctrl+F5)."
Write-Host ""
