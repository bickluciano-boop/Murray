# Genera scripts/aplicar-sos-apagar-panel.ps1: un adulto puede APAGAR su SOS del todo desde un lugar deliberado (con aviso a quienes lo recibian).
import re
R = '/home/user/Murray/scripts/'
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"

BLOQUE = r'''// ---------------------------------------------------------------------------
// SOS apagado del todo (Luciano, 09/11/2026): en las llaves rapidas de PERMISOS siempre queda alguien que reciba el SOS, pero un adulto
// (que decide por si mismo) puede apagarlo del todo desde un lugar DELIBERADO de la app, con confirmacion fuerte y aviso a quienes lo recibian.
// Apagado: el SOS no sale (409 sos_off) y no le llega a nadie; tampoco avisan bateria ni "Buen dia" (todo cuidado va a quienes reciben tu SOS).
// Un menor no puede apagarlo.   CREATE TABLE IF NOT EXISTS sos_prefs (email TEXT PRIMARY KEY, off INTEGER NOT NULL DEFAULT 0, updated_at TEXT NOT NULL);
// ---------------------------------------------------------------------------
let sosOffTablaLista = false;
async function sosOffTabla(env: Env) {
  if (sosOffTablaLista) return;
  await env.DB.prepare("CREATE TABLE IF NOT EXISTS sos_prefs (email TEXT PRIMARY KEY, off INTEGER NOT NULL DEFAULT 0, updated_at TEXT NOT NULL)").run();
  sosOffTablaLista = true;
}
async function sosApagado(env: Env, email: string) {
  try {
    await sosOffTabla(env);
    const f = await env.DB.prepare("SELECT off FROM sos_prefs WHERE email=?").bind(email).first<{ off: number }>();
    return Boolean(f?.off);
  } catch (error) {
    console.error("sos_apagado", String(error).slice(0, 120));
    return false;
  }
}

/** POST /api/native/care/sos {deviceId, off}: apaga o vuelve a prender MI SOS. */
async function nativeCareSos(request: Request, env: Env) {
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const email = await nativeOwnerEmail(request, env, String(body.deviceId ?? ""));
  if (!email) return json({ error: "unauthorized" }, 401);
  if (typeof body.off !== "boolean") return json({ error: "invalid_request" }, 400);
  await sosOffTabla(env);
  if ((await sosApagado(env, email)) === body.off) return json({ ok: true, unchanged: true });
  const soyMenor = await env.DB.prepare("SELECT 1 AS m FROM family_members WHERE member_email=? AND status='activo' AND role='menor' LIMIT 1").bind(email).first<{ m: number }>();
  if (soyMenor) return json({ error: "minor_locked" }, 403);
  const avisar = async (texto: (nombre: string) => string) => {
    for (const quien of await familySosRecipients(env, email)) {
      const nombre = await familyNameSeenBy(env, email, quien);
      await Promise.all((await pushTokensOf(env, quien)).map((token) => sendExpoNoticeLogged(env, token, "Ojo Guard", texto(nombre), "sos apagado", { channelId: "ojo-familia-aviso" }).catch(() => false)));
    }
  };
  const guardar = () => env.DB.prepare("INSERT INTO sos_prefs (email,off,updated_at) VALUES (?,?,?) ON CONFLICT(email) DO UPDATE SET off=excluded.off, updated_at=excluded.updated_at").bind(email, body.off ? 1 : 0, now()).run();
  // Apagar: se avisa ANTES (despues ya no habria a quien); prender: se avisa DESPUES (recien ahi vuelve a haber destinatarios).
  if (body.off) {
    await avisar((nombre) => `${nombre} apagó su SOS. Ya no vas a recibir sus alertas.`).catch((error) => console.error("sos_off_aviso", String(error).slice(0, 120)));
    await guardar();
  } else {
    await guardar();
    await avisar((nombre) => `${nombre} volvió a prender su SOS.`).catch((error) => console.error("sos_on_aviso", String(error).slice(0, 120)));
  }
  return json({ ok: true });
}

'''
A0 = 'async function nativeFamilyPause(request: Request, env: Env) {\n'
B0 = BLOQUE + A0
A1 = '  if (!aplicarLlaves) return [...destinatarios];\n'
B1 = A1 + '  // SOS apagado del todo por la propia persona: no le llega a nadie.\n  if (await sosApagado(env, person)) return [];\n'
A2 = '  const destinatarios = await familySosRecipients(env, email);\n  if (!destinatarios.length && !(await pldTieneGuardianes(env, email))) return json({ error: "no_recipients" }, 409);\n'
B2 = '  // Apagado del todo por la propia persona (decision suya): el SOS no sale, ni a la familia ni a los referentes.\n  if (await sosApagado(env, email)) return json({ error: "sos_off" }, 409);\n' + A2
A3 = 'destinatarios: destinos });\n'
B3 = 'destinatarios: destinos, sosOff: await sosApagado(env, email) });\n'
A4 = '      if (route === "POST /api/native/care/buen-dia/ok") return nativeCareOk(request, env);\n'
B4 = A4 + '      if (route === "POST /api/native/care/sos") return nativeCareSos(request, env);\n'
A5 = '  await borrar("care_state", "DELETE FROM care_state WHERE email=?", 1);\n'
B5 = A5 + '  await borrar("sos_prefs", "DELETE FROM sos_prefs WHERE email=?", 1);\n'
pares = [A0, A1, A2, A3, A4, A5]; nuevos = [B0, B1, B2, B3, B4, B5]
nombres = ['sos apagado: tabla y endpoint', 'sos apagado: nadie lo recibe', 'sos apagado: el SOS no sale', 'sos apagado: lo dice el cuidado', 'sos apagado: ruta', 'sos apagado: borrar cuenta']
filas = [('src\\index.ts', n, a, b) for n, a, b in zip(nombres, pares, nuevos)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-sos-apagar-panel.ps1 - Ojo Guard MS: un adulto puede APAGAR su SOS del todo (desde un lugar deliberado de la app) y volver a prenderlo.
# Luciano (09/11/2026, "si, dejalo asi"): la regla "siempre queda alguien que reciba el SOS" se mantiene en las llaves rapidas de PERMISOS, pero un adulto decide por si mismo: puede apagarlo del todo con confirmacion fuerte y aviso a quienes lo recibian.
# Apagado: el SOS no sale (error sos_off) ni a la familia ni a los referentes; los avisos de bateria y "Buen dia" tampoco (van a quienes reciben tu SOS). Un menor no puede apagarlo. Requiere aplicar-cuidado-panel.ps1.
# Tabla nueva sos_prefs (se crea sola). Cambia SOLO src\\index.ts (respaldo .bak-sosoff). Va en la carpeta del PANEL. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'async function cuidadoCron') -eq 0) { Mal "Falta aplicar primero aplicar-cuidado-panel.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'aplicarLlaves = true') -eq 0) { Mal "Falta aplicar primero aplicar-permisos-ojo4-panel.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'async function nativeCareSos') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-sosoff')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: el SOS se puede apagar del todo (y volver a prender)."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + tpl[i:j] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›✓']
assert not bad, set(bad)
open(R + 'aplicar-sos-apagar-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
t = open(S + 'index-cuidado.ts', encoding='utf-8').read()
for a in pares:
    assert t.count(a) == 1, (t.count(a), a[:60])
for a, b in zip(pares, nuevos):
    t = t.replace(a, b)
open(S + 'index-sosoff.ts', 'w', encoding='utf-8').write(t)
print('ok', len(total))
