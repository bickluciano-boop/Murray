# aplicar-hacer-sonar-iphone-panel.ps1 - Ojo Guard MS (solo servidor, sin build): PRUEBA para "Hacer sonar" a un iPhone.
# Motivo (30/10/2026): con el iPhone bloqueado, la app cerrada y la llave lateral en silencio, el SOS suena y "Hacer sonar" no, aunque usan la misma sirena. Para iPhone, el aviso de Hacer sonar sale ahora como el del SOS: un envio aparte para el aviso visible, sin el campo "tag" (Android no cambia).
# Cambia SOLO src\index.ts (respaldo .bak-sonar-iphone). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
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
if (-not (Test-Path (Join-Path $raiz "src\index.ts"))) { Mal "No encuentro src\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'let ENV_PUSH') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
$cambios = @(
    @('src\index.ts', 'hacer sonar iPhone: guarda el pedido en curso', 'async function sendExpoCommandPush(
', '// La base de datos del pedido en curso, para que sendExpoCommandPush pueda saber si el token es de un iPhone sin cambiar las 12 llamadas.
let ENV_PUSH: Env | null = null;

async function sendExpoCommandPush(
'),
    @('src\index.ts', 'hacer sonar iPhone: pedido en curso (programado)', 'async scheduled(_controller: ScheduledController, env: Env, ctx: ExecutionContext) {
', 'async scheduled(_controller: ScheduledController, env: Env, ctx: ExecutionContext) {
    ENV_PUSH = env;
'),
    @('src\index.ts', 'hacer sonar iPhone: pedido en curso (fetch)', 'async fetch(request: Request, env: Env) {
', 'async fetch(request: Request, env: Env) {
    ENV_PUSH = env;
'),
    @('src\index.ts', 'hacer sonar iPhone: detectar iPhone', '  const message = content[type];
  const commandData = { commandId, kind: message.kind, deviceName };
', '  const message = content[type];
  const commandData = { commandId, kind: message.kind, deviceName };
  // PRUEBA (30/10/2026): en iPhone, "Hacer sonar" con la llave en silencio no sonaba y el SOS si. El SOS sale como un aviso solo y sin "tag"; este tambien lo hace asi para iPhone.
  const esIphone = type === "alarm" && ENV_PUSH
    ? await ENV_PUSH.DB.prepare("SELECT platform FROM devices WHERE push_token=? LIMIT 1").bind(pushToken).first<{ platform: string | null }>().then((fila) => fila?.platform === "ios").catch(() => false)
    : false;
'),
    @('src\index.ts', 'hacer sonar iPhone: sin tag en iPhone', '      tag: `ojo-guard-${message.kind}`,
', '      ...(esIphone ? {} : { tag: `ojo-guard-${message.kind}` }),
'),
    @('src\index.ts', 'hacer sonar iPhone: envios separados', '  const response = await fetch("https://exp.host/--/api/v2/push/send", {
    method: "POST",
    headers: { "content-type": "application/json", accept: "application/json" },
    body: JSON.stringify(messages),
', '  if (esIphone) {
    // Un envio por aviso, primero el visible (el que suena) y despues el que despierta la app, como sale el SOS.
    let alguno = false;
    for (const mensaje of [...messages].reverse()) {
      const r = await fetch("https://exp.host/--/api/v2/push/send", {
        method: "POST",
        headers: { "content-type": "application/json", accept: "application/json" },
        body: JSON.stringify([mensaje]),
      });
      if (!r.ok) throw new Error(`expo_push_${r.status}`);
      const res = await r.json<{ data?: Array<{ status?: string }> }>();
      if (Array.isArray(res.data) && res.data.some((ticket) => ticket.status === "ok")) alguno = true;
    }
    return alguno;
  }
  const response = await fetch("https://exp.host/--/api/v2/push/send", {
    method: "POST",
    headers: { "content-type": "application/json", accept: "application/json" },
    body: JSON.stringify(messages),
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
    if (Test-Path ($ruta + ".bak-sonar-iphone")) { Mal ("Ya existe " + $t + ".bak-sonar-iphone. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-sonar-iphone"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-sonar-iphone): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-sonar-iphone") -Destination $ruta -Force }
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
Ok "LISTO: el aviso de Hacer sonar a un iPhone sale como el del SOS (prueba)."
Write-Host ""
