# Genera scripts/aplicar-identidad-didit-panel.ps1: verificacion de identidad con Didit + RENAPER (servidor) y bloqueo de "pedir foto y audio" a otras personas hasta verificarse.
import re
R = '/home/user/Murray/scripts/'
U = '/root/.claude/uploads/459a989e-0585-521a-8ee1-3a385ef7024a/'
tpl = open(R + 'aplicar-raiz-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
fx = open(U + '61ee18a5-index.ts', encoding='utf-8').read().replace('\r\n', '\n')
fm = open(U + '7bfd7b7d-panel-mapa.txt', encoding='utf-8').read().replace('\r\n', '\n')
filas = []
def cambio(archivo, fuente, rotulo, viejo, nuevo):
    assert fuente.count(viejo) == 1, (rotulo, fuente.count(viejo))
    filas.append((archivo, rotulo, viejo, nuevo))

cambio('src\\index.ts', fx, 'clave de Didit en el entorno',
 '  AWS_REGION?: string;\n}',
 '  AWS_REGION?: string;\n  /** Clave de Didit (verificacion de identidad). Se carga con `wrangler secret put DIDIT_API_KEY`. */\n  DIDIT_API_KEY?: string;\n}')

FUNCIONES = r'''// ---------------------------------------------------------------------------
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

'''
cambio('src\\index.ts', fx, 'funciones de verificacion de identidad',
 'export default {\n  async scheduled(_controller',
 FUNCIONES + 'export default {\n  async scheduled(_controller')
cambio('src\\index.ts', fx, 'rutas de verificacion de identidad',
 '      if (route === "GET /api/app/version") return apkVersionJson(env);',
 '      if (route === "GET /api/app/version") return apkVersionJson(env);\n      if (route === "GET /api/native/identity") return nativeIdentityStatus(request, env, url);\n      if (route === "POST /api/native/identity/verify") return nativeIdentityVerify(request, env);')
cambio('src\\index.ts', fx, 'bloqueo de foto y audio a otras personas sin verificar',
 '  if (!target) return json({ error: "not_allowed" }, 403);\n  // Si un adulto pauso',
 '  if (!target) return json({ error: "not_allowed" }, 403);\n  // Pedir foto y audio a otra persona exige haber verificado la propia identidad (los equipos propios no).\n  if (type === "capture-evidence" && !await identidadVerificada(env, email)) return json({ error: "identity_required" }, 403);\n  // Si un adulto pauso')
cambio('src\\panel-mapa.txt', fm, 'mensaje del mapa cuando falta verificar',
 'avisar(error.status === 409 ? "Paus',
 'avisar(error.message === "identity_required" ? "Para pedirle foto y audio a otra persona primero hay que verificar tu identidad desde la app: Configuración, Verificar mi identidad." : error.status === 409 ? "Paus')

cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-identidad-didit-panel.ps1 - Ojo Guard MS: verificacion de identidad con Didit + RENAPER (servidor).
# Luciano (28/10/2026): "Didit renaper"; la verificacion se puede omitir para usar la app, pero sin verificar no se puede pedir foto y audio a otras personas.
# Agrega GET /api/native/identity y POST /api/native/identity/verify (DNI + sexo + selfie, la clave DIDIT_API_KEY queda en el servidor), la tabla identity_checks (se crea sola)
# y el bloqueo en "pedir foto y audio" a otras personas de la familia. Cambia src\\index.ts y src\\panel-mapa.txt (respaldo .bak-identidad). Va en la carpeta del PANEL. Al final publica el panel solo.
# ANTES hay que cargar la clave: npx.cmd wrangler secret put DIDIT_API_KEY (sin la clave, la verificacion contesta "identity_not_configured" y nada mas cambia).
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if (-not (Test-Path (Join-Path $raiz "src\\panel-mapa.txt"))) { Mal "No encuentro src\\panel-mapa.txt en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'nativeIdentityVerify') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-raiz', '.bak-identidad')
cola = re.sub(r'Ok "LISTO: el panel se abre en.*"\n', 'Ok "LISTO: el servidor ya puede verificar identidades (falta cargar DIDIT_API_KEY si no lo hiciste)."\n', cola)
assert 'bak-raiz' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
open(R + 'aplicar-identidad-didit-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
# copia probada: index.ts resultante para chequear tipos
out = fx
for a, _, v, n in filas:
    if a.endswith('index.ts'): out = out.replace(v, n)
open('/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/index-identidad.ts', 'w', encoding='utf-8').write(out)
print('ok', len(total), len(filas))
