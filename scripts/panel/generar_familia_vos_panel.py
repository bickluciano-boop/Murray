# Genera scripts/aplicar-familia-vos-panel.ps1: GET /api/native/family/me dice quien es "vos" y en que familia estas.
import re
R = '/home/user/Murray/scripts/'
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
BLOQUE = r'''/** GET /api/native/family/me: quien sos "vos" en Familia y amigos: tu nombre, si sos titular y en que familias estas (con tu rol y el nombre del titular). */
async function nativeFamilyMe(request: Request, env: Env, url: URL) {
  const email = await nativeOwnerEmail(request, env, url.searchParams.get("deviceId") ?? "");
  if (!email) return json({ error: "unauthorized" }, 401);
  const equipo = await env.DB.prepare("SELECT name FROM devices WHERE owner_email=? AND approval_status='approved' ORDER BY CASE WHEN device_role='primary' THEN 0 ELSE 1 END, COALESCE(last_seen_at,'') DESC LIMIT 1").bind(email).first<{ name: string | null }>();
  const nombre = (await nombrePerfil(env, email)) || equipo?.name || email.split("@")[0].replace(/^./, (c) => c.toUpperCase());
  const comoIntegrante = await env.DB.prepare("SELECT owner_email AS ownerEmail, role FROM family_members WHERE member_email=? AND status='activo'").bind(email).all<{ ownerEmail: string; role: string }>();
  const familias: { titular: string; rol: string }[] = [];
  for (const f of comoIntegrante.results) familias.push({ titular: await familyNameSeenBy(env, f.ownerEmail, email), rol: f.role });
  const titular = await env.DB.prepare("SELECT 1 AS x FROM family_members WHERE owner_email=? AND status='activo' LIMIT 1").bind(email).first<{ x: number }>();
  return json({ nombre, esTitular: Boolean(titular), familias });
}

'''
A0 = 'async function nativeFamilyPause(request: Request, env: Env) {\n'
B0 = BLOQUE + A0
A1 = '      if (route === "POST /api/native/family/perm") return nativeFamilyPerm(request, env);\n'
B1 = A1 + '      if (route === "GET /api/native/family/me") return nativeFamilyMe(request, env, url);\n'
pares = [A0, A1]; nuevos = [B0, B1]
filas = [('src\\index.ts', 'familia: quien sos vos', A0, B0), ('src\\index.ts', 'familia: ruta de "vos"', A1, B1)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-familia-vos-panel.ps1 - Ojo Guard MS: la app puede preguntar "quien soy yo" en Familia y amigos.
# Luciano (09/11/2026, con capturas): "no logro entender cual es mi familia": la lista solo muestra a las OTRAS personas, nunca a vos, ni de quien es la familia.
# Ruta nueva GET /api/native/family/me: tu nombre, si sos titular y en que familias estas (con tu rol y el nombre del titular). Solo lee. Requiere aplicar-permisos-ojo-panel.ps1. Cambia SOLO src\\index.ts (respaldo .bak-vos). Va en la carpeta del PANEL. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'async function nativeFamilyPerm') -eq 0) { Mal "Falta aplicar primero aplicar-permisos-ojo-panel.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'async function nativeFamilyMe') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-vos')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: la app ya puede decir quien sos vos en la familia."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + tpl[i:j] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›✓']
assert not bad, set(bad)
open(R + 'aplicar-familia-vos-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
t = open(S + 'index-sosoff.ts', encoding='utf-8').read()
for a in pares:
    assert t.count(a) == 1, (t.count(a), a[:60])
for a, b in zip(pares, nuevos):
    t = t.replace(a, b)
open(S + 'index-vos.ts', 'w', encoding='utf-8').write(t)
print('ok', len(total))
