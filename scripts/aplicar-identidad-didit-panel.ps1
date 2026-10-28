# aplicar-identidad-didit-panel.ps1 - Ojo Guard MS: verificacion de identidad con Didit + RENAPER (servidor).
# Luciano (28/10/2026): "Didit renaper"; la verificacion se puede omitir para usar la app, pero sin verificar no se puede pedir foto y audio a otras personas.
# Agrega GET /api/native/identity y POST /api/native/identity/verify (DNI + sexo + selfie, la clave DIDIT_API_KEY queda en el servidor), la tabla identity_checks (se crea sola)
# y el bloqueo en "pedir foto y audio" a otras personas de la familia. Cambia src\index.ts y src\panel-mapa.txt (respaldo .bak-identidad). Va en la carpeta del PANEL. Al final publica el panel solo.
# ANTES hay que cargar la clave: npx.cmd wrangler secret put DIDIT_API_KEY (sin la clave, la verificacion contesta "identity_not_configured" y nada mas cambia).
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
if (-not (Test-Path (Join-Path $raiz "src\panel-mapa.txt"))) { Mal "No encuentro src\panel-mapa.txt en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'nativeIdentityVerify') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
$cambios = @(
    @('src\index.ts', 'clave de Didit en el entorno', '  AWS_REGION?: string;
}', '  AWS_REGION?: string;
  /** Clave de Didit (verificacion de identidad). Se carga con `wrangler secret put DIDIT_API_KEY`. */
  DIDIT_API_KEY?: string;
}'),
    @('src\index.ts', 'funciones de verificacion de identidad', 'export default {
  async scheduled(_controller', '// ---------------------------------------------------------------------------
// Verificacion de identidad (Didit + RENAPER). La persona manda su numero de DNI, su sexo y una selfie;
// Didit confirma el DNI contra el registro oficial y compara la cara con la foto que tiene RENAPER.
// No se guarda la selfie ni el numero completo: solo el resultado, los ultimos 3 digitos y una huella.
// Mientras no este verificada, una persona no puede pedir foto y audio a OTRAS personas
// (ver remoteFamilyCommand); sus propios equipos no se tocan.
// ---------------------------------------------------------------------------
const ID_INTENTOS_POR_DIA = 5;

async function idTabla(env: Env) {
  await env.DB.prepare("CREATE TABLE IF NOT EXISTS identity_checks (email TEXT PRIMARY KEY, status TEXT NOT NULL, outcome TEXT, score INTEGER, doc_last3 TEXT, doc_hash TEXT, attempts INTEGER NOT NULL DEFAULT 0, attempts_day TEXT, verified_at TEXT, updated_at TEXT NOT NULL)").run();
}

async function identidadVerificada(env: Env, email: string) {
  await idTabla(env);
  const fila = await env.DB.prepare("SELECT status FROM identity_checks WHERE email=?").bind(email).first<{ status: string }>();
  return fila?.status === "verificada";
}

async function nativeIdentityStatus(request: Request, env: Env, url: URL) {
  const email = await nativeOwnerEmail(request, env, url.searchParams.get("deviceId") ?? "");
  if (!email) return json({ error: "unauthorized" }, 401);
  await idTabla(env);
  const fila = await env.DB.prepare("SELECT status, outcome, verified_at AS verifiedAt FROM identity_checks WHERE email=?")
    .bind(email).first<{ status: string; outcome: string | null; verifiedAt: string | null }>();
  return json({ verified: fila?.status === "verificada", status: fila?.status ?? "sin_verificar", outcome: fila?.outcome ?? null, verifiedAt: fila?.verifiedAt ?? null });
}

async function nativeIdentityVerify(request: Request, env: Env) {
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const email = await nativeOwnerEmail(request, env, String(body.deviceId ?? ""));
  if (!email) return json({ error: "unauthorized" }, 401);
  if (!env.DIDIT_API_KEY) return json({ error: "identity_not_configured" }, 503);
  const documento = String(body.documentNumber ?? "").replace(/[\s.\-]/g, "").toUpperCase();
  if (!/^[MF]?\d{7,8}$/.test(documento)) return json({ error: "invalid_document" }, 400);
  const sexo = String(body.gender ?? "").toUpperCase();
  if (!["M", "F", "X"].includes(sexo)) return json({ error: "invalid_gender" }, 400);
  const selfie = String(body.selfieBase64 ?? "").replace(/^data:[^,]+,/, "");
  if (selfie.length < 2_000 || selfie.length > 7_000_000) return json({ error: "invalid_selfie" }, 400);
  let bytes: Uint8Array;
  try {
    bytes = Uint8Array.from(atob(selfie), (c) => c.charCodeAt(0));
  } catch {
    return json({ error: "invalid_selfie" }, 400);
  }
  await idTabla(env);
  const hoy = now().slice(0, 10);
  const previo = await env.DB.prepare("SELECT status, attempts, attempts_day AS day FROM identity_checks WHERE email=?")
    .bind(email).first<{ status: string; attempts: number; day: string | null }>();
  if (previo?.status === "verificada") return json({ verified: true, outcome: "MATCH", already: true });
  const intentos = previo && previo.day === hoy ? previo.attempts : 0;
  if (intentos >= ID_INTENTOS_POR_DIA) return json({ error: "too_many_attempts" }, 429);

  const form = new FormData();
  form.append("issuing_state", "ARG");
  form.append("services", "arg_renaper");
  form.append("document_number", documento);
  form.append("gender", sexo);
  form.append("vendor_data", (await hash(`ojo-guard:${email}`)).slice(0, 24));
  form.append("selfie", new Blob([bytes], { type: "image/jpeg" }), "selfie.jpg");
  const control = new AbortController();
  const corte = setTimeout(() => control.abort(), 25_000);
  let respuesta: Response;
  try {
    respuesta = await fetch("https://verification.didit.me/v3/database-validation/", { method: "POST", headers: { "x-api-key": env.DIDIT_API_KEY }, body: form, signal: control.signal });
  } catch {
    return json({ error: "identity_unreachable" }, 502);
  } finally {
    clearTimeout(corte);
  }
  const datos = await respuesta.json<Record<string, unknown>>().catch(() => null);
  if (!respuesta.ok || !datos) {
    console.error("didit_failed", respuesta.status);
    return json({ error: "identity_provider_error", status: respuesta.status }, 502);
  }
  const validaciones = Array.isArray(datos.validations) ? (datos.validations as Array<Record<string, unknown>>) : [];
  const primera = validaciones[0] ?? {};
  const outcome = String(primera.outcome_code ?? "UNKNOWN");
  const origen = (primera.source_data ?? {}) as Record<string, unknown>;
  const puntaje = Number.parseInt(String(origen.face_match_score ?? ""), 10);
  const verificada = outcome === "MATCH";
  // Si el registro no contesto no se cobro y no cuenta como intento.
  const nuevosIntentos = outcome === "REGISTRY_UNAVAILABLE" ? intentos : intentos + 1;
  const huella = await hash(`${env.SESSION_SECRET}:dni:${documento.replace(/^[MF]/, "")}`);
  await env.DB.prepare("INSERT INTO identity_checks (email,status,outcome,score,doc_last3,doc_hash,attempts,attempts_day,verified_at,updated_at) VALUES (?,?,?,?,?,?,?,?,?,?) ON CONFLICT(email) DO UPDATE SET status=excluded.status,outcome=excluded.outcome,score=excluded.score,doc_last3=excluded.doc_last3,doc_hash=excluded.doc_hash,attempts=excluded.attempts,attempts_day=excluded.attempts_day,verified_at=excluded.verified_at,updated_at=excluded.updated_at")
    .bind(email, verificada ? "verificada" : "no_verificada", outcome, Number.isFinite(puntaje) ? puntaje : null, documento.slice(-3), huella, nuevosIntentos, hoy, verificada ? now() : null, now()).run();
  return json({
    verified: verificada,
    outcome,
    retry: outcome === "BIOMETRIC_IMAGE_UNUSABLE" || outcome === "REGISTRY_UNAVAILABLE",
    attemptsLeft: Math.max(0, ID_INTENTOS_POR_DIA - nuevosIntentos),
  });
}

export default {
  async scheduled(_controller'),
    @('src\index.ts', 'rutas de verificacion de identidad', '      if (route === "GET /api/app/version") return apkVersionJson(env);', '      if (route === "GET /api/app/version") return apkVersionJson(env);
      if (route === "GET /api/native/identity") return nativeIdentityStatus(request, env, url);
      if (route === "POST /api/native/identity/verify") return nativeIdentityVerify(request, env);'),
    @('src\index.ts', 'bloqueo de foto y audio a otras personas sin verificar', '  if (!target) return json({ error: "not_allowed" }, 403);
  // Si un adulto pauso', '  if (!target) return json({ error: "not_allowed" }, 403);
  // Pedir foto y audio a otra persona exige haber verificado la propia identidad (los equipos propios no).
  if (type === "capture-evidence" && !await identidadVerificada(env, email)) return json({ error: "identity_required" }, 403);
  // Si un adulto pauso'),
    @('src\panel-mapa.txt', 'mensaje del mapa cuando falta verificar', 'avisar(error.status === 409 ? "Paus', 'avisar(error.message === "identity_required" ? "Para pedirle foto y audio a otra persona primero hay que verificar tu identidad desde la app: Configuración, Verificar mi identidad." : error.status === 409 ? "Paus')
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
    if (Test-Path ($ruta + ".bak-identidad")) { Mal ("Ya existe " + $t + ".bak-identidad. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-identidad"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-identidad): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-identidad") -Destination $ruta -Force }
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
Ok "LISTO: el servidor ya puede verificar identidades (falta cargar DIDIT_API_KEY si no lo hiciste)."
Write-Host ""
