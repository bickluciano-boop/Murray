# Genera scripts/aplicar-foto-perfil-panel.ps1 (cuando Didit da 500 se prueban variantes). Antes: la clave DIDIT_API_KEY se limpia (espacios, comillas, "Bearer") y el registro anota su forma (largos), sin mostrarla. Didit contesta 400 vacio incluso con el pedido multipart bien armado.
import re
R = '/home/user/Murray/scripts/'
SC = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
tpl = open(R + 'aplicar-raiz-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
fi = open(SC + 'index-variantes2.ts', encoding='utf-8').read()
FUNCIONES = '''// ---- Foto de perfil visible para el circulo ----
// Cada persona sube una foto chica (256 px, JPEG) y la ven solo quienes ya la ven en la lista de familia (familyPeopleFor decide quien ve a quien).
let fotoTablaLista = false;
async function fotoTabla(env: Env) {
  if (fotoTablaLista) return;
  await env.DB.prepare("CREATE TABLE IF NOT EXISTS profile_photos (email TEXT PRIMARY KEY, photo_b64 TEXT NOT NULL, updated_at INTEGER NOT NULL)").run();
  fotoTablaLista = true;
}

async function fotoVersion(env: Env, email: string): Promise<number | null> {
  try {
    await fotoTabla(env);
    const fila = await env.DB.prepare("SELECT updated_at AS v FROM profile_photos WHERE email=?").bind(email).first<{ v: number }>();
    return fila?.v ?? null;
  } catch {
    return null;
  }
}

async function nativeProfilePhotoSave(request: Request, env: Env) {
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const email = await nativeOwnerEmail(request, env, String(body.deviceId ?? ""));
  if (!email) return json({ error: "unauthorized" }, 401);
  const foto = String(body.photoBase64 ?? "").replace(/^data:[^,]+,/, "");
  // JPEG chico: unos 10-40 KB. Tope de 120 mil caracteres en base64 (unos 90 KB).
  if (foto.length < 500 || foto.length > 120_000 || !foto.startsWith("/9j/")) return json({ error: "invalid_photo" }, 400);
  try {
    atob(foto);
  } catch {
    return json({ error: "invalid_photo" }, 400);
  }
  await fotoTabla(env);
  const version = Date.now();
  await env.DB.prepare("INSERT INTO profile_photos (email,photo_b64,updated_at) VALUES (?,?,?) ON CONFLICT(email) DO UPDATE SET photo_b64=excluded.photo_b64,updated_at=excluded.updated_at")
    .bind(email, foto, version).run();
  return json({ ok: true, version });
}

async function nativeProfilePhotoDelete(request: Request, env: Env) {
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const email = await nativeOwnerEmail(request, env, String(body.deviceId ?? ""));
  if (!email) return json({ error: "unauthorized" }, 401);
  await fotoTabla(env);
  await env.DB.prepare("DELETE FROM profile_photos WHERE email=?").bind(email).run();
  return json({ ok: true });
}

// La foto de `personaId` (el id que trae la lista de familia, o "me") para `viewer`: solo si `viewer` ya la ve en esa lista.
async function fotoRespuesta(env: Env, viewer: string, personaId: string) {
  let email: string | null = null;
  if (personaId === "me") {
    email = viewer;
  } else {
    const personas = await familyPeopleFor(env, viewer);
    if (!personas.some((p) => String(p.id) === personaId)) return json({ error: "not_found" }, 404);
    if (personaId.startsWith("titular:")) {
      email = personaId.slice("titular:".length);
    } else {
      const fila = await env.DB.prepare("SELECT member_email AS e FROM family_members WHERE id=?").bind(personaId).first<{ e: string | null }>();
      email = fila?.e ?? null;
    }
  }
  if (!email) return json({ error: "not_found" }, 404);
  await fotoTabla(env);
  const foto = await env.DB.prepare("SELECT photo_b64 AS f FROM profile_photos WHERE email=?").bind(email).first<{ f: string }>();
  if (!foto) return json({ error: "not_found" }, 404);
  const bytes = Uint8Array.from(atob(foto.f), (c) => c.charCodeAt(0));
  return new Response(bytes, { headers: { "content-type": "image/jpeg", "cache-control": "private, max-age=86400" } });
}

async function nativeProfilePhotoGet(request: Request, env: Env, url: URL) {
  const email = await nativeOwnerEmail(request, env, url.searchParams.get("deviceId") ?? "");
  if (!email) return json({ error: "unauthorized" }, 401);
  return fotoRespuesta(env, email, url.searchParams.get("person") ?? "me");
}

async function remoteProfilePhotoGet(request: Request, env: Env, url: URL) {
  const sessionInfo = await readSessionInfo(request, env.SESSION_SECRET);
  if (!sessionInfo) return json({ error: "unauthorized" }, 401);
  return fotoRespuesta(env, sessionInfo.email, url.searchParams.get("person") ?? "me");
}

'''
a1 = 'export default {\n  async scheduled(_controller'
b1 = FUNCIONES + a1
a2 = 'if (route === "GET /api/app/version") return apkVersionJson(env);'
b2 = a2 + '\n      if (route === "GET /api/native/profile-photo") return nativeProfilePhotoGet(request, env, url);\n      if (route === "POST /api/native/profile-photo") return nativeProfilePhotoSave(request, env);\n      if (route === "POST /api/native/profile-photo/delete") return nativeProfilePhotoDelete(request, env);'
a3 = 'if (route === "GET /api/remote/family") return remoteFamily(request, env);'
b3 = a3 + '\n      if (route === "GET /api/remote/profile-photo") return remoteProfilePhotoGet(request, env, url);'
a4 = '      lastLocationAt: !paused ? device?.lastLocationAt ?? null : null,\n'
b4 = a4 + '      // Version de la foto de perfil (null si no tiene): el cliente la pide con GET /profile-photo?person=<id> solo cuando cambia.\n      photo: await fotoVersion(env, p.email),\n'
a5 = 'me: { memberships: mine.results.length,'
b5 = 'me: { photo: await fotoVersion(env, email), memberships: mine.results.length,'
filas = [('src\\index.ts', 'funciones de foto de perfil', a1, b1), ('src\\index.ts', 'rutas nativas de foto de perfil', a2, b2), ('src\\index.ts', 'ruta del panel para la foto de perfil', a3, b3), ('src\\index.ts', 'version de la foto en la lista de personas', a4, b4), ('src\\index.ts', 'version de la foto propia', a5, b5)]
for f in filas:
    assert fi.count(f[2]) == 1, (f[1], fi.count(f[2]))
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-foto-perfil-panel.ps1 - Ojo Guard MS: la foto de perfil la ve el circulo (servidor).
# Luciano (28/10/2026): "la foto de perfil tiene que verla la gente con la que ella comparte". Agrega la tabla profile_photos (se crea sola), POST /api/native/profile-photo (sube un JPEG chico) y /delete,
# GET /api/native/profile-photo y GET /api/remote/profile-photo (solo para quien ya ve a esa persona en la lista de familia) y el campo "photo" (version) en cada persona de la lista.
# Cambia SOLO src\\index.ts (respaldo .bak-foto-perfil). Va en la carpeta del PANEL. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'profile_photos') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-raiz', '.bak-foto-perfil')
cola = re.sub(r'Ok "LISTO: el panel se abre en.*"\n', 'Ok "LISTO: la foto de perfil ahora se puede subir y la ve el circulo."\n', cola)
assert 'bak-raiz' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
open(R + 'aplicar-foto-perfil-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
open(SC + 'index-fotoperfil.ts', 'w', encoding='utf-8').write(fi.replace(a1, b1).replace(a2, b2).replace(a3, b3).replace(a4, b4).replace(a5, b5))
print('ok', len(total))
