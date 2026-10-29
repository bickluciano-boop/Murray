# Genera scripts/aplicar-mi-nombre-panel.ps1: "Mi nombre" (como te ven los demas). Cada persona elige el nombre con el que aparece en el mapa y las listas de su circulo;
# si no eligio ninguno se usa el que escribio quien la invito. Se guarda en profile_names y se borra al borrar la cuenta.
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"

BLOQUE = r'''// ---- "Mi nombre": como te ven los demas ----
// Cada persona elige el nombre con el que aparece en el mapa y en las listas de su circulo. Si no eligio ninguno, familyPeopleFor usa el que escribio quien la invito.
let nombreTablaLista = false;
async function nombreTabla(env: Env) {
  if (nombreTablaLista) return;
  await env.DB.prepare("CREATE TABLE IF NOT EXISTS profile_names (email TEXT PRIMARY KEY, name TEXT NOT NULL, updated_at INTEGER NOT NULL)").run();
  nombreTablaLista = true;
}

async function nombrePerfil(env: Env, email: string): Promise<string | null> {
  try {
    await nombreTabla(env);
    const fila = await env.DB.prepare("SELECT name FROM profile_names WHERE email=?").bind(email).first<{ name: string }>();
    return String(fila?.name ?? "").trim() || null;
  } catch {
    return null;
  }
}

async function nativeProfileNameGet(request: Request, env: Env, url: URL) {
  const email = await nativeOwnerEmail(request, env, url.searchParams.get("deviceId") ?? "");
  if (!email) return json({ error: "unauthorized" }, 401);
  return json({ name: await nombrePerfil(env, email) });
}

async function nativeProfileNameSave(request: Request, env: Env) {
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const email = await nativeOwnerEmail(request, env, String(body.deviceId ?? ""));
  if (!email) return json({ error: "unauthorized" }, 401);
  const name = String(body.name ?? "").replace(/[\u0000-\u001f\u007f]/g, " ").replace(/\s+/g, " ").trim();
  if (name.length > 30) return json({ error: "invalid_name" }, 400);
  await nombreTabla(env);
  // Vacio = quitar el nombre: vuelve a verse con el que puso quien la invito.
  if (!name) {
    await env.DB.prepare("DELETE FROM profile_names WHERE email=?").bind(email).run();
    return json({ ok: true, name: null });
  }
  await env.DB.prepare("INSERT INTO profile_names (email,name,updated_at) VALUES (?,?,?) ON CONFLICT(email) DO UPDATE SET name=excluded.name,updated_at=excluded.updated_at")
    .bind(email, name, Date.now()).run();
  return json({ ok: true, name });
}

'''
s1a = '// ---- Foto de perfil visible para el circulo ----\n'
s1b = BLOQUE + s1a
s2a = '      name: p.name || (p.owner ? p.email.split("@")[0].replace(/^./, (c) => c.toUpperCase()) : device?.name || p.email.split("@")[0]),\n'
s2b = '      // El nombre que la persona eligio para si (Perfil > Mi nombre) gana; si no puso ninguno, el que escribio quien la invito.\n      name: (await nombrePerfil(env, p.email)) || p.name || (p.owner ? p.email.split("@")[0].replace(/^./, (c) => c.toUpperCase()) : device?.name || p.email.split("@")[0]),\n'
s3a = '      if (route === "POST /api/native/profile-photo/delete") return nativeProfilePhotoDelete(request, env);\n'
s3b = s3a + '      if (route === "GET /api/native/profile-name") return nativeProfileNameGet(request, env, url);\n      if (route === "POST /api/native/profile-name") return nativeProfileNameSave(request, env);\n'
s4a = '  await borrar("profile_photos", "DELETE FROM profile_photos WHERE email=?", 1);\n'
s4b = s4a + '  await nombreTabla(env).catch(() => undefined);\n  await borrar("profile_names", "DELETE FROM profile_names WHERE email=?", 1);\n'
filas = [
    ('src\\index.ts', 'servidor: funciones de Mi nombre', s1a, s1b),
    ('src\\index.ts', 'servidor: la lista del circulo usa Mi nombre', s2a, s2b),
    ('src\\index.ts', 'servidor: rutas de Mi nombre', s3a, s3b),
    ('src\\index.ts', 'servidor: Borrar mi cuenta tambien borra Mi nombre', s4a, s4b),
]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-mi-nombre-panel.ps1 - Ojo Guard MS: "Mi nombre" = como te ven las personas de tu circulo en el mapa y las listas (idea de Luciano, 29/10/2026).
# Hasta ahora cada persona se veia con el nombre que escribio quien la invito. Ahora, si la persona eligio su nombre (desde la app, Perfil > Mi nombre), ese gana; si no, se usa el de la invitacion.
# Cambia SOLO src\\index.ts (respaldo .bak-mi-nombre). Requiere aplicar-foto-perfil-panel.ps1 y aplicar-borrar-cuenta-panel.ps1. Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
$txt = (Leer (Join-Path $raiz "src\\index.ts")).texto
if ((Contar $txt 'nombrePerfil') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $txt 'nativeAccountDelete') -eq 0 -or (Contar $txt 'nativeProfilePhotoDelete') -eq 0) { Mal "Faltan aplicar primero aplicar-foto-perfil-panel.ps1 y aplicar-borrar-cuenta-panel.ps1. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-mi-nombre')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: el servidor ya guarda Mi nombre. Falta la app (aplicar-mi-nombre-app.ps1) para poder elegirlo."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127]
assert not bad, set(bad)
open(R + 'aplicar-mi-nombre-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
