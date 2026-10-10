# aplicar-avisos-correo.ps1 - Cuenta > Avisos de seguridad: elegir que avisos por correo llegan (confirmaciones
# de ordenes, resultado de Ubicar, familia). Los de seguridad llegan siempre, y se suma un aviso obligatorio
# cuando se entra al panel desde un equipo nuevo. Va en la carpeta del PANEL (la que tiene wrangler.toml).
# Toca src\index.ts y src\panel-index.html y agrega src\panel-avisos.txt. Respaldos .bak-avisoscorreo.
# Base de datos: antes de publicar, agregar una columna (el script lo recuerda al final).
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
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'async function emailCategoriesHandler') -ne 0) { Avi "Los avisos por correo ya estaban aplicados. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'async function familyEvidenceMail') -eq 0) { Mal "Primero corre aplicar-menores-evidencia.ps1."; return }
if (Test-Path (Join-Path $raiz "src\panel-avisos.txt")) { Mal "Ya existe src\panel-avisos.txt de un intento anterior. No toco nada. Mandame esta pantalla."; return }
$cambios = @(
    @('src\index.ts', 'importar la pieza de avisos', 'import mapaCss from "./panel-mapa.css";
', 'import mapaCss from "./panel-mapa.css";
import avisosJs from "./panel-avisos.txt";
'),
    @('src\index.ts', 'servir la pieza de avisos', '      if (url.pathname === "/mapa-v1.css") return staticResponse(mapaCss, "text/css; charset=utf-8");
', '      if (url.pathname === "/mapa-v1.css") return staticResponse(mapaCss, "text/css; charset=utf-8");
      if (url.pathname === "/avisos-v1.js") return staticResponse(avisosJs, "application/javascript; charset=utf-8");
'),
    @('src\index.ts', 'ruta de los avisos por correo', '      if ((request.method === "GET" || request.method === "POST") && url.pathname === "/api/notification-prefs") return notificationPrefsHandler(request, env);
', '      if ((request.method === "GET" || request.method === "POST") && url.pathname === "/api/notification-prefs") return notificationPrefsHandler(request, env);
      if ((request.method === "GET" || request.method === "POST") && url.pathname === "/api/notification-categories") return emailCategoriesHandler(request, env);
'),
    @('src\index.ts', 'avisos que se pueden apagar y equipo nuevo', 'async function notificationPrefsHandler(request: Request, env: Env) {
', '// Avisos por correo que la persona puede apagar (Cuenta > Avisos de seguridad, panel-avisos.txt).
// Los de seguridad no estan aca: llegan siempre (intentos de entrada, ingresos desde un equipo
// nuevo, Modo perdido, dispositivos, accesos y los avisos de familia que protegen). Columna
// agregada a mano el 10/10/2026: ALTER TABLE notification_prefs ADD COLUMN email_off TEXT;
const EMAIL_OPCIONALES = ["ordenes", "ubicacion", "familia"] as const;
type EmailOpcional = typeof EMAIL_OPCIONALES[number];
const esEmailOpcional = (valor: string): valor is EmailOpcional => (EMAIL_OPCIONALES as readonly string[]).includes(valor);

async function emailsApagados(env: Env, email: string): Promise<EmailOpcional[]> {
  try {
    const fila = await env.DB.prepare("SELECT email_off AS off FROM notification_prefs WHERE owner_email=?").bind(email).first<{ off: string | null }>();
    return String(fila?.off ?? "").split(",").filter(esEmailOpcional);
  } catch {
    return []; // Sin la columna todavia: llega todo, como antes.
  }
}

const quiereEmail = async (env: Env, email: string, tipo: EmailOpcional) => !(await emailsApagados(env, email)).includes(tipo);

async function emailCategoriesHandler(request: Request, env: Env) {
  const sessionInfo = await readSessionInfo(request, env.SESSION_SECRET);
  if (!sessionInfo) return json({ error: "unauthorized" }, 401);
  if (request.method === "GET") return json({ off: await emailsApagados(env, sessionInfo.email) });
  // Con el acceso de emergencia no se pueden apagar avisos.
  if (sessionInfo.method === "emergency") return json({ error: "not_allowed_in_emergency" }, 403);
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const off = [...new Set((Array.isArray(body.off) ? body.off : []).map(String).filter(esEmailOpcional))];
  const d = DEFAULT_NOTIFICATION_PREFS;
  try {
    await env.DB.prepare("INSERT INTO notification_prefs (owner_email,notify_email,notify_sms,phone_number,notify_silence,updated_at,email_off) VALUES (?,?,?,?,?,?,?) ON CONFLICT(owner_email) DO UPDATE SET email_off=excluded.email_off,updated_at=excluded.updated_at")
      .bind(sessionInfo.email, d.notifyEmail ? 1 : 0, d.notifySms ? 1 : 0, d.phoneNumber ?? null, d.notifySilence ? 1 : 0, now(), off.join(",") || null).run();
  } catch (error) {
    // Falta la columna email_off (ver arriba): se avisa en lugar de romper.
    console.error("email_categories_unwritable", error);
    return json({ error: "email_categories_unavailable" }, 503);
  }
  return json({ off });
}

// Aviso obligatorio de ingreso desde un equipo nuevo: la cookie "ojo_eq" marca los navegadores
// desde los que ya se entro. Si no la trae, es la primera vez desde ahi (o se borraron los datos).
async function avisoEquipoNuevo(request: Request, env: Env, email: string) {
  if (/(?:^|;\s*)ojo_eq=1(?:;|$)/.test(request.headers.get("cookie") ?? "")) return;
  const ua = request.headers.get("user-agent") ?? "";
  const sistema = /iPhone|iPad/.test(ua) ? "iPhone" : /Android/.test(ua) ? "Android" : /Windows/.test(ua) ? "Windows" : /Mac OS/.test(ua) ? "Mac" : /Linux/.test(ua) ? "Linux" : "";
  const navegador = /Edg\//.test(ua) ? "Edge" : /Firefox\//.test(ua) ? "Firefox" : /Chrome\//.test(ua) ? "Chrome" : /Safari\//.test(ua) ? "Safari" : "";
  const equipo = [navegador, sistema].filter(Boolean).join(" en ") || "un navegador desconocido";
  await sendSecurityNotice(env, email, "Ingreso desde un equipo nuevo", `Se entr\u00f3 a Ojo Guard MS desde ${equipo}, un equipo que no se hab\u00eda usado antes. Si fuiste vos, no hace falta hacer nada.`);
}

function conEquipoConocido(respuesta: Response) {
  respuesta.headers.append("set-cookie", "ojo_eq=1; HttpOnly; Secure; SameSite=Lax; Path=/; Max-Age=31536000");
  return respuesta;
}

async function notificationPrefsHandler(request: Request, env: Env) {
'),
    @('src\index.ts', 'confirmaciones de ordenes (se pueden apagar)', '  await sendSecurityNotice(env, email, noticeTitle, noticeDetail, owns.name);
', '  // La confirmacion se puede apagar (Cuenta > Avisos), salvo Modo perdido, que llega siempre.
  if (type === "lost" || type === "lost-off" || await quiereEmail(env, email, "ordenes")) await sendSecurityNotice(env, email, noticeTitle, noticeDetail, owns.name);
'),
    @('src\index.ts', 'resultado de Ubicar (se puede apagar)', '  resultKind: "current" | "last" = "current",
) {
  const detail = locationDetails(location);
  if (!detail) return;
', '  resultKind: "current" | "last" = "current",
) {
  const detail = locationDetails(location);
  if (!detail) return;
  if (!await quiereEmail(env, email, "ubicacion")) return;
'),
    @('src\index.ts', 'sin ubicacion (se puede apagar)', '  await sendSecurityNotice(
    env,
    failedLocate.ownerEmail,
', '  if (await quiereEmail(env, failedLocate.ownerEmail, "ubicacion")) await sendSecurityNotice(
    env,
    failedLocate.ownerEmail,
'),
    @('src\index.ts', 'alguien salio de la familia (se puede apagar)', '  await sendSecurityNotice(env, ownerEmail, `${nombre} sali\u00f3 de tu familia`', '  if (await quiereEmail(env, ownerEmail, "familia")) await sendSecurityNotice(env, ownerEmail, `${nombre} sali\u00f3 de tu familia`'),
    @('src\index.ts', 'ingreso con passkey: aviso de equipo nuevo', '  const sessionToken = await signSession(result.email, env.SESSION_SECRET, "passkey");
  return json(
    { authenticated: true },
    200,
    { "set-cookie": `ojo_ms=${encodeURIComponent(sessionToken)}; HttpOnly; Secure; SameSite=Strict; Path=/; Max-Age=1800` },
  );
}
', '  const sessionToken = await signSession(result.email, env.SESSION_SECRET, "passkey");
  await avisoEquipoNuevo(request, env, result.email);
  return conEquipoConocido(json(
    { authenticated: true },
    200,
    { "set-cookie": `ojo_ms=${encodeURIComponent(sessionToken)}; HttpOnly; Secure; SameSite=Strict; Path=/; Max-Age=1800` },
  ));
}
'),
    @('src\index.ts', 'ingreso con codigo: aviso de equipo nuevo', '  const sessionToken = await signSession(email, env.SESSION_SECRET, "totp");
  return json(
    { authenticated: true },
    200,
    { "set-cookie": `ojo_ms=${encodeURIComponent(sessionToken)}; HttpOnly; Secure; SameSite=Strict; Path=/; Max-Age=1800` },
  );
}
', '  const sessionToken = await signSession(email, env.SESSION_SECRET, "totp");
  await avisoEquipoNuevo(request, env, email);
  return conEquipoConocido(json(
    { authenticated: true },
    200,
    { "set-cookie": `ojo_ms=${encodeURIComponent(sessionToken)}; HttpOnly; Secure; SameSite=Strict; Path=/; Max-Age=1800` },
  ));
}
'),
    @('src\panel-index.html', 'cargar la pieza de avisos', 'import("/mapa-v1.js?t=" + v);</script>', 'import("/mapa-v1.js?t=" + v); import("/avisos-v1.js?t=" + v);</script>')
)
$descargas = @(
    ,@("https://raw.githubusercontent.com/bickluciano-boop/Murray/0867649/scripts/avisos/panel-avisos.txt", "src\panel-avisos.txt", "4dcb16eed2349f9046a9be39ecc63c12a0b7e3969e48bd204be236563264e010")
)

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
    if (Test-Path ($ruta + ".bak-avisoscorreo")) { Mal ("Ya existe " + $t + ".bak-avisoscorreo. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-avisoscorreo"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-avisoscorreo): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-avisoscorreo") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "TODO BIEN en los archivos. Faltan dos pasos, en este orden:"
Write-Host "  1) npx.cmd wrangler d1 execute ojo-guard-ms --remote --command ""ALTER TABLE notification_prefs ADD COLUMN email_off TEXT;"""
Write-Host "  2) npx.cmd wrangler deploy"
Write-Host ""
