# aplicar-mapa-carga-paralela-panel.ps1 - Ojo Guard MS: el mapa abre mas rapido porque sus pasos dejan de ir en fila.
# Luciano (12/11/2026): el mapa tarda 9 s en abrir en el Android. Antes: Google Maps -> /session -> /family -> recorrido -> dibujar, uno detras del otro. Ahora Google Maps, /session y /family arrancan juntos y se dibuja apenas hay personas; el recorrido llega despues.
# Cambia SOLO src\panel-mapa.txt (respaldo .bak-carga-paralela). Va en la carpeta del PANEL (la que tiene wrangler.toml). No necesita build. Al final publica el panel solo.
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
if ((Contar $mapaTexto 'estado.precarga') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
$cambios = @(
    @('src\panel-mapa.txt', 'mapa: /family junto con /session', '  const cuenta = await pedir("/api/remote/session");
  if (!cuenta.authenticated) throw Object.assign(new Error("sin_sesion"), { status: 401 });
', '  // /family no depende de /session: se piden juntos (antes uno detras del otro).
  const familiaP = pedir("/api/remote/family");
  familiaP.catch(() => undefined);
  const cuenta = await pedir("/api/remote/session");
  if (!cuenta.authenticated) throw Object.assign(new Error("sin_sesion"), { status: 401 });
'),
    @('src\panel-mapa.txt', 'mapa: usar /family ya pedido', '    const familia = await pedir("/api/remote/family");
    estado.invitaciones = familia.invites || [];
', '    const familia = await familiaP;
    estado.invitaciones = familia.invites || [];
'),
    @('src\panel-mapa.txt', 'mapa: pedir los datos mientras carga Google Maps', '  if (!estado.proveedor) {
    try {
      estado.proveedor = await proveedorGoogle(', '  // Los datos (personas, equipos) se piden YA, mientras carga Google Maps (antes se esperaba a Google y recien despues se pedian).
  if (!estado.proveedor && !DEMO) { estado.precarga = cargarEquipos(); estado.precarga.catch(() => undefined); }
  if (!estado.proveedor) {
    try {
      estado.proveedor = await proveedorGoogle('),
    @('src\panel-mapa.txt', 'mapa: usar los datos ya pedidos', '    estado.equipos = await cargarEquipos();
    completarDirecciones(estado.equipos);
', '    const adelantado = estado.precarga;
    estado.precarga = null;
    estado.equipos = adelantado ? await adelantado : await cargarEquipos();
    completarDirecciones(estado.equipos);
'),
    @('src\panel-mapa.txt', 'mapa: dibujar apenas hay personas', '  const equipo = equipoElegido();
  if (equipo && (forzarRecorrido || Date.now() - estado.ultimoRecorrido > (estado.vivo ? 10_000 : 30_000))) {
    try { estado.recorrido = await cargarRecorrido(equipo); }', '  // La primera vez se dibujan ya las personas y los equipos; el recorrido (otro pedido) llega despues y se redibuja.
  if (!estado.primerDibujo) { estado.primerDibujo = true; try { dibujar(); document.documentElement.classList.remove("abriendo"); } catch (error) { console.error("dibujar", error); } }
  const equipo = equipoElegido();
  if (equipo && (forzarRecorrido || Date.now() - estado.ultimoRecorrido > (estado.vivo ? 10_000 : 30_000))) {
    try { estado.recorrido = await cargarRecorrido(equipo); }')
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
    if (Test-Path ($ruta + ".bak-carga-paralela")) { Mal ("Ya existe " + $t + ".bak-carga-paralela. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-carga-paralela"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-carga-paralela): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-carga-paralela") -Destination $ruta -Force }
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
Ok "LISTO: el mapa arranca mas rapido (recarga la pagina con Ctrl+F5)."
Write-Host ""
