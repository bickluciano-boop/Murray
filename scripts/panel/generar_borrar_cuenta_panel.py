# Genera scripts/aplicar-borrar-cuenta-panel.ps1 (cuando Didit da 500 se prueban variantes). Antes: la clave DIDIT_API_KEY se limpia (espacios, comillas, "Bearer") y el registro anota su forma (largos), sin mostrarla. Didit contesta 400 vacio incluso con el pedido multipart bien armado.
import re
R = '/home/user/Murray/scripts/'
SC = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
tpl = open(R + 'aplicar-raiz-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
fi = open(SC + 'index-fotoperfil.ts', encoding='utf-8').read()
FUNCION = '''// ---- Borrar mi cuenta (Apple exige poder hacerlo desde la app) ----
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
        subject: "Tu cuenta de Ojo Guard se borr\\u00f3",
        html: "<div style=\\"font-family:Arial,sans-serif;max-width:560px;margin:auto;padding:24px\\"><h2>Tu cuenta de Ojo Guard se borr\\u00f3</h2><p>Borramos tus equipos, ubicaciones, evidencias, familia, avisos y foto de perfil. Si no fuiste vos, escribinos cuanto antes respondiendo este correo.</p></div>",
      }),
    });
  } catch {
    // El aviso es un extra.
  }
  return json({ ok: true, parcial: fallos.length > 0, fallos });
}

'''
a1 = 'export default {\n  async scheduled(_controller'
b1 = FUNCION + a1
a2 = 'if (route === "POST /api/native/profile-photo/delete") return nativeProfilePhotoDelete(request, env);'
b2 = a2 + '\n      if (route === "POST /api/native/account/delete") return nativeAccountDelete(request, env);'
for v in (a1, a2):
    assert fi.count(v) == 1, (v[:50], fi.count(v))
filas = [('src\\index.ts', 'funcion de borrado de cuenta', a1, b1), ('src\\index.ts', 'ruta de borrado de cuenta', a2, b2)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
open(SC + 'index-borrar.ts', 'w', encoding='utf-8').write(fi.replace(a1, b1).replace(a2, b2))
cabeza = '''# aplicar-borrar-cuenta-panel.ps1 - Ojo Guard MS: POST /api/native/account/delete, para "Borrar mi cuenta" dentro de la app (Apple lo exige).
# Pide confirm="BORRAR" y borra todo lo de esa cuenta: equipos, ubicaciones, evidencias (y sus archivos), familia, avisos, verificacion de identidad y foto de perfil. Avisa por correo que la cuenta se borro.
# Cambia SOLO src\\index.ts (respaldo .bak-borrar-cuenta). Va en la carpeta del PANEL. Requiere aplicar-foto-perfil-panel.ps1. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'nativeAccountDelete') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'nativeProfilePhotoDelete') -eq 0) { Mal "Falta aplicar primero aplicar-foto-perfil-panel.ps1. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-raiz', '.bak-borrar-cuenta')
cola = re.sub(r'Ok "LISTO: el panel se abre en.*"\n', 'Ok "LISTO: el servidor ya puede borrar una cuenta completa."\n', cola)
assert 'bak-raiz' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
open(R + 'aplicar-borrar-cuenta-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
