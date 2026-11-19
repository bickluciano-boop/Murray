# aplicar-orden-sin-respuesta-panel.ps1 - Ojo Guard MS (panel, pestana Dispositivos): si el telefono no toma la orden (Modo Perdido, evidencia, alarma...), el panel dice la verdad en la tarjeta del equipo:
# ultima conexion + "suele pasar cuando Android duerme la app; si alguien lo tiene cerca, que desbloquee la pantalla". Antes prometia que el Modo Perdido "se va a ejecutar sola apenas se conecte".
# Luciano (19/11/2026): "hacelo, pero sin textos ni mails": SOLO texto dentro del panel. Cambia src\panel-app.txt (respaldo .bak-sinrespuesta). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
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
if (-not (Test-Path (Join-Path $raiz "src\panel-app.txt"))) { Mal "No encuentro src\panel-app.txt en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\panel-app.txt")).texto 'sinRespuestaTexto') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
$cambios = @(
    @('src\panel-app.txt', 'orden sin respuesta: guardar el ultimo estado de la orden', 'async function pollCommand(commandId, card, type, deviceId) {
  const status = $(".command-status", card);
  for (let attempt = 0; attempt < 20; attempt += 1) {', 'async function pollCommand(commandId, card, type, deviceId) {
  const status = $(".command-status", card);
  let ultimo = ""; // estado de la orden en la ultima consulta (si el telefono todavia no la tomo, "pending")
  for (let attempt = 0; attempt < 20; attempt += 1) {'),
    @('src\panel-app.txt', 'orden sin respuesta: a los ~12 s sin respuesta, el texto honesto', '    const location = command.location;
    if (command.status === "executed" && Number.isFinite(Number(location?.latitude))', '    ultimo = command.status;
    if (command.status === "pending" && attempt >= 4) status.textContent = sinRespuestaTexto(card, false);
    const location = command.location;
    if (command.status === "executed" && Number.isFinite(Number(location?.latitude))'),
    @('src\panel-app.txt', 'orden sin respuesta: al cumplirse el tiempo, el texto honesto y la funcion', 'La orden no se considera ejecutada.";
}

function nearbySummary(entries) {', 'La orden no se considera ejecutada.";
  if (ultimo === "pending") status.textContent = sinRespuestaTexto(card, true);
}

// El telefono todavia no tomo la orden: no se promete que "se va a ejecutar sola". Con la app dormida puede tardar horas (18/11/2026: ~5 h) hasta que alguien desbloquea el telefono. Solo texto en la tarjeta.
function sinRespuestaTexto(card, final) {
  const visto = (($(".device-last-seen", card) || {}).textContent || "").replace("Actualizado ", "").split(" · ")[0].trim();
  const cuando = visto && !visto.startsWith("Esperando") ? ` Última conexión: ${visto}.` : "";
  return `El teléfono todavía no tomó la orden.${cuando} Suele pasar cuando Android duerme la app. Si alguien lo tiene cerca, que desbloquee la pantalla: la orden se ejecuta en segundos.${final ? " La orden queda guardada y se ejecuta apenas el teléfono la tome." : ""}`;
}

function nearbySummary(entries) {')
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
    if (Test-Path ($ruta + ".bak-sinrespuesta")) { Mal ("Ya existe " + $t + ".bak-sinrespuesta. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-sinrespuesta"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-sinrespuesta): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-sinrespuesta") -Destination $ruta -Force }
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
Ok "LISTO: si el telefono no toma la orden, el panel dice la ultima conexion y que hacer (desbloquear el telefono). Solo texto, sin SMS ni mails."
Write-Host ""
