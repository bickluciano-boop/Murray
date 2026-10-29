# aplicar-borrar-cuenta-panel.ps1 - Ojo Guard MS: POST /api/native/account/delete, para "Borrar mi cuenta" dentro de la app (Apple lo exige).
# Pide confirm="BORRAR" y borra todo lo de esa cuenta: equipos, ubicaciones, evidencias (y sus archivos), familia, avisos, verificacion de identidad y foto de perfil. Avisa por correo que la cuenta se borro.
# Cambia SOLO src\index.ts (respaldo .bak-borrar-cuenta). Va en la carpeta del PANEL. Requiere aplicar-foto-perfil-panel.ps1. Al final publica el panel solo.
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
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'nativeAccountDelete') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'nativeProfilePhotoDelete') -eq 0) { Mal "Falta aplicar primero aplicar-foto-perfil-panel.ps1. No toco nada."; return }
$cambios = @(
    @('src\index.ts', 'funcion de borrado de cuenta', 'export default {
  async scheduled(_controller', '// ---- Borrar mi cuenta (Apple exige poder hacerlo desde la app) ----
// Borra TODOS los datos de quien lo pide: equipos, ubicaciones, evidencias (y sus archivos), familia, avisos, verificacion y foto de perfil.
async function nativeAccountDelete(request: Request, env: Env) {
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const email = await nativeOwnerEmail(request, env, String(body.deviceId ?? ""));
  if (!email) return json({ error: "unauthorized" }, 401);
  if (String(body.confirm ?? "") !== "BORRAR") return json({ error: "confirm_required" }, 400);
  const fallos: string[] = [];

  // 1) Archivos de evidencia y fotos de equipos guardados aparte.
  if (env.EVIDENCE_FILES) {
    try {
      const filas = await env.DB.prepare("SELECT front_object_key AS a, rear_object_key AS b, audio_object_key AS c FROM evidence_attempts WHERE owner_email=?")
        .bind(email).all<{ a: string | null; b: string | null; c: string | null }>();
      for (const fila of filas.results) {
        for (const clave of [fila.a, fila.b, fila.c]) if (clave) await env.EVIDENCE_FILES.delete(clave);
      }
    } catch (error) {
      fallos.push("archivos_evidencia");
      console.error("account_delete", "archivos_evidencia", String(error).slice(0, 120));
    }
    try {
      const prefijo = `fotos-equipos/${email.replace(/[^a-z0-9@._-]/gi, "_")}/`;
      let cursor: string | undefined;
      do {
        const lista = await env.EVIDENCE_FILES.list({ prefix: prefijo, ...(cursor ? { cursor } : {}) });
        for (const clave of lista.keys) await env.EVIDENCE_FILES.delete(clave.name);
        cursor = lista.list_complete ? undefined : lista.cursor;
      } while (cursor);
    } catch (error) {
      fallos.push("fotos_equipos");
      console.error("account_delete", "fotos_equipos", String(error).slice(0, 120));
    }
  }

  // 2) Filas de la base de datos. Cada una por separado: si una tabla no existe o falla, las demas igual se borran y queda anotado.
  const borrar = async (nombre: string, sql: string, enlaces: number) => {
    try {
      await env.DB.prepare(sql).bind(...Array(enlaces).fill(email)).run();
    } catch (error) {
      fallos.push(nombre);
      console.error("account_delete", nombre, String(error).slice(0, 120));
    }
  };
  await borrar("commands", "DELETE FROM commands WHERE device_id IN (SELECT id FROM devices WHERE owner_email=?)", 1);
  await borrar("location_history", "DELETE FROM location_history WHERE device_id IN (SELECT id FROM devices WHERE owner_email=?)", 1);
  await borrar("evidence_attempts", "DELETE FROM evidence_attempts WHERE owner_email=?", 1);
  await borrar("gd_progreso", "DELETE FROM gd_progreso WHERE viaje_id IN (SELECT id FROM gd_viajes WHERE owner_email=?)", 1);
  await borrar("gd_viajes", "DELETE FROM gd_viajes WHERE owner_email=?", 1);
  await borrar("gd_config", "DELETE FROM gd_config WHERE owner_email=?", 1);
  await borrar("family_sos_to", "DELETE FROM family_sos_to WHERE email=? OR sos_id IN (SELECT id FROM family_sos WHERE person_email=?)", 2);
  await borrar("family_sos", "DELETE FROM family_sos WHERE person_email=?", 1);
  await borrar("family_place_states", "DELETE FROM family_place_states WHERE person_email=? OR place_id IN (SELECT id FROM family_places WHERE owner_email=?)", 2);
  await borrar("family_places", "DELETE FROM family_places WHERE owner_email=?", 1);
  await borrar("family_alerts", "DELETE FROM family_alerts WHERE watcher_email=? OR target_email=?", 2);
  await borrar("family_members", "DELETE FROM family_members WHERE owner_email=? OR member_email=?", 2);
  await borrar("pld_checkins", "DELETE FROM pld_checkins WHERE owner_email=?", 1);
  await borrar("pld_log", "DELETE FROM pld_log WHERE owner_email=?", 1);
  await borrar("pld_referentes", "DELETE FROM pld_referentes WHERE owner_email=?", 1);
  await borrar("pld_episodios", "DELETE FROM pld_episodios WHERE owner_email=?", 1);
  await borrar("pld_config", "DELETE FROM pld_config WHERE owner_email=?", 1);
  await borrar("face_search_runs", "DELETE FROM face_search_runs WHERE owner_email=?", 1);
  await borrar("face_search_purchases", "DELETE FROM face_search_purchases WHERE owner_email=?", 1);
  await borrar("face_search_credits", "DELETE FROM face_search_credits WHERE owner_email=?", 1);
  await borrar("emergency_answers", "DELETE FROM emergency_answers WHERE owner_email=?", 1);
  await borrar("emergency_answer_attempts", "DELETE FROM emergency_answer_attempts WHERE email=?", 1);
  await borrar("totp_credentials", "DELETE FROM totp_credentials WHERE owner_email=?", 1);
  await borrar("passkey_credentials", "DELETE FROM passkey_credentials WHERE owner_email=?", 1);
  await borrar("passkey_bootstrap_requests", "DELETE FROM passkey_bootstrap_requests WHERE owner_email=?", 1);
  await borrar("access_codes", "DELETE FROM access_codes WHERE email=?", 1);
  await borrar("access_rate_limits", "DELETE FROM access_rate_limits WHERE email=?", 1);
  await borrar("panel_handoff", "DELETE FROM panel_handoff WHERE owner_email=?", 1);
  await borrar("notification_prefs", "DELETE FROM notification_prefs WHERE owner_email=?", 1);
  await borrar("profile_photos", "DELETE FROM profile_photos WHERE email=?", 1);
  await borrar("identity_checks", "DELETE FROM identity_checks WHERE email=?", 1);
  await borrar("devices", "DELETE FROM devices WHERE owner_email=?", 1);

  // 3) Aviso por correo de que la cuenta se borro (si falla, no cambia nada).
  try {
    await fetchCorreo("https://api.resend.com/emails", {
      method: "POST",
      headers: { authorization: `Bearer ${env.RESEND_API_KEY}`, "content-type": "application/json" },
      body: JSON.stringify({
        from: env.MAIL_FROM,
        reply_to: env.SUPPORT_EMAIL,
        to: [email],
        subject: "Tu cuenta de Ojo Guard se borr\u00f3",
        html: "<div style=\"font-family:Arial,sans-serif;max-width:560px;margin:auto;padding:24px\"><h2>Tu cuenta de Ojo Guard se borr\u00f3</h2><p>Borramos tus equipos, ubicaciones, evidencias, familia, avisos y foto de perfil. Si no fuiste vos, escribinos cuanto antes respondiendo este correo.</p></div>",
      }),
    });
  } catch {
    // El aviso es un extra.
  }
  return json({ ok: true, parcial: fallos.length > 0, fallos });
}

export default {
  async scheduled(_controller'),
    @('src\index.ts', 'ruta de borrado de cuenta', 'if (route === "POST /api/native/profile-photo/delete") return nativeProfilePhotoDelete(request, env);', 'if (route === "POST /api/native/profile-photo/delete") return nativeProfilePhotoDelete(request, env);
      if (route === "POST /api/native/account/delete") return nativeAccountDelete(request, env);')
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
    if (Test-Path ($ruta + ".bak-borrar-cuenta")) { Mal ("Ya existe " + $t + ".bak-borrar-cuenta. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-borrar-cuenta"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-borrar-cuenta): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-borrar-cuenta") -Destination $ruta -Force }
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
Ok "LISTO: el servidor ya puede borrar una cuenta completa."
Write-Host ""
