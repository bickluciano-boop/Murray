# Genera scripts/aplicar-familia-tope-adultos-panel.ps1: SOS desde el Apple Watch (o cualquier atajo) con un enlace secreto por persona que dispara el mismo SOS de siempre.
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"




a1 = 'async function remoteFamilyInvite(request: Request, env: Env) {\n'
b1 = (
'// Tope de adultos por familia: el titular mas FAMILY_MAX_ADULTOS (su pareja); los hijos no tienen tope por ahora.\n'
'// Mientras dure la beta con la familia de Luciano el tope esta APAGADO (FAMILY_TOPE_ADULTOS_ACTIVO = false). Al lanzar: ponerlo en true.\n'
'const FAMILY_TOPE_ADULTOS_ACTIVO = false;\n'
'const FAMILY_MAX_ADULTOS = 1;\n'
'/** true si el titular ya llego al tope de adultos (cuentan los activos y las invitaciones vigentes; `excluirId` es la fila que se esta cambiando). */\n'
'async function familyTopeAdultos(env: Env, owner: string, excluirId = "") {\n'
'  if (!FAMILY_TOPE_ADULTOS_ACTIVO) return false;\n'
'  const fila = await env.DB.prepare("SELECT COUNT(*) AS n FROM family_members WHERE owner_email=? AND role=\'adulto\' AND id<>? AND (status=\'activo\' OR (status=\'invitado\' AND invite_expires_at>?))")\n'
'    .bind(owner, excluirId, now()).first<{ n: number }>();\n'
'  return Number(fila?.n ?? 0) >= FAMILY_MAX_ADULTOS;\n'
'}\n\n' + a1)
a2 = '  if (!name || !(FAMILY_ROLES as readonly string[]).includes(role)) return json({ error: "invalid_invite" }, 400);\n'
b2 = a2 + '  if (role === "adulto" && await familyTopeAdultos(env, sessionInfo.email)) return json({ error: "adult_limit", max: FAMILY_MAX_ADULTOS }, 409);\n'
a3 = '  if (!(FAMILY_ROLES as readonly string[]).includes(role)) return json({ error: "invalid_role" }, 400);\n'
b3 = a3 + '  if (role === "adulto" && await familyTopeAdultos(env, sessionInfo.email, String(body.id ?? ""))) return json({ error: "adult_limit", max: FAMILY_MAX_ADULTOS }, 409);\n'
filas = [('src\\index.ts', 'Familia: tope de adultos (funcion e interruptor, apagado)', a1, b1),
         ('src\\index.ts', 'Familia: tope al invitar un adulto', a2, b2),
         ('src\\index.ts', 'Familia: tope al cambiarle el rol a adulto', a3, b3)]
cambios = "$cambios = @(\n" + ',\n'.join(("    ,@(%s, %s, %s, %s)" if len(filas) == 1 else "    @(%s, %s, %s, %s)") % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-familia-tope-adultos-panel.ps1 - Ojo Guard MS: tope de adultos por familia (el titular + 1 adulto, su pareja; los hijos sin tope por ahora), con un interruptor APAGADO para la beta.
# Regla de Luciano (03/11/2026): el plan lleva como maximo dos mayores y despues los hijos. Mientras se prueba con su familia (padres y hermanos) el tope NO se aplica: FAMILY_TOPE_ADULTOS_ACTIVO = false. Al lanzar se pone en true (y se agrega el texto en las pantallas: el servidor contesta 409 adult_limit).
# Cambia SOLO src\\index.ts (respaldo .bak-topeadultos). Va en la carpeta del PANEL (la que tiene wrangler.toml). No cambia la app. Instalarlo hoy no cambia nada. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'FAMILY_TOPE_ADULTOS_ACTIVO') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-topeadultos')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: el tope de adultos por familia quedo instalado y APAGADO (beta)."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›✓']
assert not bad, set(bad)
open(R + 'aplicar-familia-tope-adultos-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
