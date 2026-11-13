# aplicar-ingreso-sin-aviso-panel.ps1 - Ojo Guard MS: (1) ya no se avisa cuando alguien entra con su propia app (el aviso "Ingreso desde la app del telefono", ni SMS ni correo); (2) SI se avisa cuando alguien puso mal el codigo 3 veces seguidas.
# Luciano (13/11/2026): "si alguien entro con su clave esta bien; en todo caso tendria que mandar cuando alguien quiso entrar y tres veces puso mal". Tambien corrige el contador de intentos fallidos, que se reiniciaba en 1 en cada intento (el bloqueo de 15 minutos a los 8 intentos nunca se activaba).
# Funciona haya o no aplicado antes aplicar-sin-sms-ingreso-panel.ps1. Cambia src\index.ts (respaldo .bak-ingreso-sin-aviso). Va en la carpeta del PANEL (la que tiene wrangler.toml). Sin build. Al final publica el panel solo.
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
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'AVISAR_INGRESO_DESDE_APP') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
$cambios = @(
    @('src\index.ts', 'acceso: constantes (aviso a los 3 intentos y aviso de ingreso apagado)', 'const CODE_LOCKOUT_THRESHOLD = 8;
', '// A la 3.a vez seguida que alguien pone mal el codigo de una cuenta que existe, a su dueno le llega un aviso (1 vez por tanda de intentos).
const CODE_AVISO_INTENTOS = 3;
// El aviso "Ingreso desde la app del telefono" (abrir el mapa o la consola desde la app) esta apagado: quien entra con su propia app entro bien. Para volver a recibirlo: true.
const AVISAR_INGRESO_DESDE_APP = false;
const CODE_LOCKOUT_THRESHOLD = 8;
'),
    @('src\index.ts', 'acceso: aviso "Ingreso desde la app del telefono" apagado', '  if (avisar) await sendSecurityNotice(
    env,
    fila.ownerEmail,
', '  if (AVISAR_INGRESO_DESDE_APP && avisar) await sendSecurityNotice(
    env,
    fila.ownerEmail,
'),
    @('src\index.ts', 'acceso: el contador de intentos fallidos suma de verdad', '    "SELECT failed_attempts AS failedAttempts, locked_until AS lockedUntil FROM access_rate_limits WHERE email=?",
  ).bind(email).first<{ failedAttempts: number; lockedUntil: string | null }>();
  // Un bloqueo vencido arranca una ventana nueva; uno vigente sigue sumando.
  const expired = !row?.lockedUntil || Date.parse(row.lockedUntil) <= Date.now();
  const failedAttempts = (expired ? 0 : row!.failedAttempts) + 1;
  const lockedUntil = failedAttempts >= CODE_LOCKOUT_THRESHOLD
    ? plusMinutes(CODE_LOCKOUT_MINUTES)
    : (expired ? null : row!.lockedUntil);
', '    "SELECT failed_attempts AS failedAttempts, locked_until AS lockedUntil, last_attempt_at AS lastAttemptAt FROM access_rate_limits WHERE email=?",
  ).bind(email).first<{ failedAttempts: number; lockedUntil: string | null; lastAttemptAt: string | null }>();
  // Los intentos suman mientras el ultimo haya sido hace menos de CODE_LOCKOUT_MINUTES; pasado ese tiempo arranca una tanda nueva.
  // (Antes se reiniciaba en 1 en cada intento y el bloqueo nunca llegaba a activarse.)
  const tandaViva = Boolean(row?.lastAttemptAt) && Date.now() - Date.parse(row!.lastAttemptAt!) < CODE_LOCKOUT_MINUTES * 60_000;
  const failedAttempts = (tandaViva ? row!.failedAttempts : 0) + 1;
  const lockedUntil = failedAttempts >= CODE_LOCKOUT_THRESHOLD
    ? plusMinutes(CODE_LOCKOUT_MINUTES)
    : (row?.lockedUntil && Date.parse(row.lockedUntil) > Date.now() ? row.lockedUntil : null);
'),
    @('src\index.ts', 'acceso: aviso al dueno a los 3 intentos fallidos', '  ).bind(email, failedAttempts, lockedUntil, now()).run();
}
', '  ).bind(email, failedAttempts, lockedUntil, now()).run();
  // Aviso al dueno: solo si la cuenta existe (no se le escribe a cualquier direccion que alguien tipee) y una sola vez por tanda.
  if (failedAttempts === CODE_AVISO_INTENTOS) {
    const cuenta = await env.DB.prepare("SELECT 1 AS existe FROM devices WHERE owner_email=? LIMIT 1").bind(email).first<{ existe: number }>().catch(() => null);
    if (cuenta) {
      await sendSecurityNotice(
        env,
        email,
        "Intentaron entrar a tu cuenta",
        `Alguien puso mal el c\u00f3digo para entrar a Ojo Guard MS ${CODE_AVISO_INTENTOS} veces seguidas con tu correo. Si fuiste vos, no pasa nada. Si no fuiste vos, revis\u00e1 los dispositivos del panel. Con ${CODE_LOCKOUT_THRESHOLD} intentos fallidos el acceso se bloquea ${CODE_LOCKOUT_MINUTES} minutos.`,
      ).catch(() => undefined);
    }
  }
}
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
    if (Test-Path ($ruta + ".bak-ingreso-sin-aviso")) { Mal ("Ya existe " + $t + ".bak-ingreso-sin-aviso. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-ingreso-sin-aviso"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-ingreso-sin-aviso): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-ingreso-sin-aviso") -Destination $ruta -Force }
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
Ok "LISTO: ya no avisa cuando alguien entra bien; avisa a los 3 intentos fallidos."
Write-Host ""
