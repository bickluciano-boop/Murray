# aplicar-registro-avisos.ps1 - Anota en la base lo que contesta el servicio de avisos cada vez que el servidor manda un aviso
# de lugar ("X llego a / salio de Casa"). No cambia como funcionan los avisos: solo deja un registro para ver por que uno no llega.
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Toca src\index.ts. Respaldo .bak-registro.
# Base de datos: una tabla nueva (push_log) con lo ultimo de los ultimos 7 dias.
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
$indexTexto = (Leer (Join-Path $raiz "src\index.ts")).texto
if ((Contar $indexTexto 'async function sendExpoNoticeLogged') -ne 0) { Avi "El registro de avisos ya estaba aplicado. No toco nada."; return }
if ((Contar $indexTexto 'async function remoteFamilyAlerts') -eq 0) { Mal "Primero corre aplicar-familia-avisos-persona.ps1."; return }
$cambios = @(
    @('src\index.ts', 'registro de avisos', 'async function pushTokensOf(env: Env, email: string) {
', '/**
 * Manda un aviso comun por Expo y deja anotado en la tabla push_log lo que contesto el servicio de avisos
 * (aceptado o rechazado, y por que). Sirve para saber, cuando un aviso no llega, si fallo el envio o la entrega.
 * La tabla se crea a mano (ver el script); si no existe, el aviso sale igual y no se anota nada.
 */
async function sendExpoNoticeLogged(env: Env, pushToken: string | null, title: string, body: string, motivo: string) {
  let http = 0, estado = "sin enviar", detalle = "", ok = false;
  try {
    if (!pushToken || !/^(ExponentPushToken|ExpoPushToken)\[.+\]$/.test(pushToken)) {
      detalle = "token con formato invalido";
    } else {
      const respuesta = await fetch("https://exp.host/--/api/v2/push/send", {
        method: "POST",
        headers: { "content-type": "application/json", accept: "application/json" },
        body: JSON.stringify([{ to: pushToken, title, body, sound: "default", priority: "high", ttl: 86_400, data: {} }]),
      });
      http = respuesta.status;
      const cuerpo = await respuesta.json().catch(() => null) as { data?: unknown } | null;
      const ticket = (Array.isArray(cuerpo?.data) ? cuerpo?.data[0] : cuerpo?.data) as { status?: string; id?: string } | undefined;
      estado = ticket?.status ?? "sin ticket";
      detalle = ticket?.status === "ok" ? String(ticket.id ?? "") : JSON.stringify(ticket ?? cuerpo).slice(0, 300);
      ok = respuesta.ok && ticket?.status === "ok";
    }
  } catch (error) {
    estado = "error";
    detalle = String(error).slice(0, 300);
  }
  try {
    const sinCierre = (pushToken ?? "").replace(/\]$/, "");
    await env.DB.prepare("INSERT INTO push_log (at,motivo,titulo,texto,token_fin,http,estado,detalle) VALUES (?,?,?,?,?,?,?,?)")
      .bind(new Date().toISOString(), motivo, title, body, sinCierre.slice(-6), http, estado, detalle).run();
    await env.DB.prepare("DELETE FROM push_log WHERE at<?").bind(new Date(Date.now() - 7 * 86_400_000).toISOString()).run();
  } catch { /* la tabla todavia no existe: no pasa nada */ }
  return ok;
}

async function pushTokensOf(env: Env, email: string) {
'),
    @('src\index.ts', 'aviso de lugar con registro', '    for (const token of await pushTokensOf(env, aviso.watcherEmail)) await sendExpoNotice(token, "Ojo Guard", texto).catch(() => false);
', '    for (const token of await pushTokensOf(env, aviso.watcherEmail)) await sendExpoNoticeLogged(env, token, "Ojo Guard", texto, "aviso de lugar").catch(() => false);
')
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
    if (Test-Path ($ruta + ".bak-registro")) { Mal ("Ya existe " + $t + ".bak-registro. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-registro"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-registro): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-registro") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "TODO BIEN en los archivos. Faltan dos pasos, en este orden:"
Write-Host "  1) npx.cmd wrangler d1 execute ojo-guard-ms --remote --command ""CREATE TABLE IF NOT EXISTS push_log (id INTEGER PRIMARY KEY AUTOINCREMENT, at TEXT NOT NULL, motivo TEXT NOT NULL, titulo TEXT, texto TEXT, token_fin TEXT, http INTEGER, estado TEXT, detalle TEXT);"""
Write-Host "  2) npx.cmd wrangler deploy"
Write-Host ""
