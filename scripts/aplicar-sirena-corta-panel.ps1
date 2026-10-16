# aplicar-sirena-corta-panel.ps1 - Hacer sonar y SOS en iPhone: la sirena del aviso corta (10 segundos), urgente, y sin sonido si se repite enseguida.
# Pedido de Luciano (16/10/2026): con la app cerrada, el aviso de "Hacer sonar" suena 28 segundos y no se puede cortar. Con la sirena corta dura 10, y como
# aviso urgente (Time Sensitive) no lo frenan los modos de concentracion. En silencio sigue sin sonar hasta que Apple apruebe las Alertas criticas.
#  - SOS (Luciano, 16/10/2026: "si"): la sirena de aviso del SOS tambien dura 10 segundos en iPhone (en Android sigue la de 28: sale del canal de la app). Y si la
#    misma persona vuelve a pedir SOS dentro de los 40 segundos del anterior (aunque lo haya cancelado con "Estoy bien"), el aviso nuevo llega igual, visible y
#    urgente, pero SIN sonido: en iPhone una sirena de aviso no se puede cortar y se superponian dos. Nunca se bloquea un SOS: siempre llega.
# SE CORRE DESPUES de instalar la app nueva (la que trae la sirena corta; en el iPhone, la build nueva): antes, el iPhone tocaria el sonido comun.
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Toca src\index.ts. Respaldo .bak-sirenacorta. Al final publica el panel solo.
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
foreach ($f in @("src\index.ts")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
$indexTexto = (Leer (Join-Path $raiz "src\index.ts")).texto
if ((Contar $indexTexto 'ojo_sirena_corta.wav') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
$cambios = @(
    @('src\index.ts', 'hacer sonar: sirena corta y aviso urgente', '      sound: aviso?.silencioso ? undefined : type === "alarm" ? "ojo_sirena.wav" : "default",', '      sound: aviso?.silencioso ? undefined : type === "alarm" ? "ojo_sirena_corta.wav" : "default",
      // "Hacer sonar" como aviso urgente: atraviesa los modos de concentracion del iPhone (hace falta la build con el permiso Time Sensitive).
      ...(type === "alarm" ? { interruptionLevel: "time-sensitive" } : {}),'),
    @('src\index.ts', 'SOS: el aviso admite ir sin sonido', 'async function sendExpoNoticeLogged(env: Env, pushToken: string | null, title: string, body: string, motivo: string, opciones?: { sound?: string;', 'async function sendExpoNoticeLogged(env: Env, pushToken: string | null, title: string, body: string, motivo: string, opciones?: { sinSonido?: boolean; sound?: string;'),
    @('src\index.ts', 'SOS: sin sonido si corresponde', 'body: JSON.stringify([{ to: pushToken, title, body, sound: opciones?.sound ?? "default", priority: "high", ttl: opciones?.ttl ?? 86_400, channelId: opciones?.channelId, interruptionLevel: opciones?.interruptionLevel,', 'body: JSON.stringify([{ to: pushToken, title, body, sound: opciones?.sinSonido ? null : opciones?.sound ?? "default", priority: "high", ttl: opciones?.ttl ?? 86_400, channelId: opciones?.channelId, interruptionLevel: opciones?.interruptionLevel,'),
    @('src\index.ts', 'SOS: mirar si ya hubo uno hace menos de 40 segundos', '  const destinatarios = await familySosRecipients(env, email);
  if (!destinatarios.length) return json({ error: "no_recipients" }, 409);
  const id = randomId("sos");', '  const destinatarios = await familySosRecipients(env, email);
  if (!destinatarios.length) return json({ error: "no_recipients" }, 409);
  // Si esta persona ya pidio un SOS hace menos de 40 segundos (aunque lo haya cancelado), la sirena anterior puede seguir sonando en el iPhone de quien lo
  // recibio, y un aviso con sonido se superpondria (en iPhone una sirena de aviso no se puede cortar). El aviso nuevo llega igual, visible y urgente, pero sin sonido.
  const sirenaAnteriorSonando = Boolean(await env.DB.prepare("SELECT 1 AS ok FROM family_sos WHERE person_email=? AND created_at>? LIMIT 1")
    .bind(email, new Date(Date.now() - 40_000).toISOString()).first<{ ok: number }>().catch(() => null));
  const id = randomId("sos");'),
    @('src\index.ts', 'SOS: sirena corta y, si se repite enseguida, sin sonido', '"sos", { sound: "ojo_sirena.wav", channelId: "ojo-sos", ttl: 600, interruptionLevel: "time-sensitive", data: { type: "sos"', '"sos", { sinSonido: sirenaAnteriorSonando, sound: "ojo_sirena_corta.wav", channelId: "ojo-sos", ttl: 600, interruptionLevel: "time-sensitive", data: { type: "sos"')
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
    if (Test-Path ($ruta + ".bak-sirenacorta")) { Mal ("Ya existe " + $t + ".bak-sirenacorta. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-sirenacorta"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-sirenacorta): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-sirenacorta") -Destination $ruta -Force }
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
Ok "LISTO: el panel quedo publicado. Proba Hacer sonar con el iPhone bloqueado (y el interruptor lateral en sonido)."
Write-Host ""
