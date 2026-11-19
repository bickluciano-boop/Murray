# Genera scripts/aplicar-cuidado-principal-panel.ps1 (servidor). Requiere aplicar-cuidado-panel.ps1.
# Luciano (19/11/2026): la alerta "Luciano todavia no contesto su Buen dia" (motivo "cuidado buen dia", 3 veces desde el 12/11) salia a TODOS los telefonos de la cuenta que es su referente (su Xiaomi y los de Guido y su papa),
# porque pushTokensOf devuelve todos los telefonos aprobados de la cuenta. Los telefonos "additional" (hijos, padres) no tienen por que recibir avisos de la persona titular.
# Ahora el Buen dia y sus alertas (cuidadoAvisar) van a los telefonos PRINCIPALES (device_role='primary') de la cuenta; si no hay ninguno con aviso, a todos como antes. El SOS NO cambia: sigue yendo a todos.
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
F = 'src\\index.ts'
# los textos originales se LEEN del generador del cuidado (no se copian a mano)
g = open(R + 'panel/generar_cuidado_panel.py', encoding='utf-8').read()
BLOQUE = g[g.index("BLOQUE = r'''") + len("BLOQUE = r'''"): g.index("'''\nA0 = ")]
FN_A = 'async function cuidadoAvisar(env: Env, de: string, texto: (nombre: string) => string, motivo: string) {'
FN_B = '''/** Los avisos de cuidado (el "Buen dia" y sus alertas) van a los telefonos PRINCIPALES de la cuenta, no a todos: los "additional" (hijos, padres) no tienen por que recibir avisos de la persona titular
 *  (19/11/2026: la alerta "Luciano no contesto su Buen dia" le llego tambien a Guido y a su papa). Si la cuenta no tiene ningun principal con aviso, se manda a todos como antes. El SOS NO usa esto: sigue yendo a todos. */
async function pushTokensPrincipales(env: Env, email: string) {
  try {
    const filas = await env.DB.prepare("SELECT push_token AS token FROM devices WHERE LOWER(owner_email)=? AND approval_status='approved' AND device_role='primary' AND push_token IS NOT NULL AND push_token<>''")
      .bind(email.trim().toLowerCase()).all<{ token: string }>();
    const tokens = [...new Set(filas.results.map((fila) => fila.token))];
    if (tokens.length) return tokens;
  } catch {
    // Sin poder leer los roles: se manda a todos como antes.
  }
  return pushTokensOf(env, email);
}

''' + FN_A
P1_A = 'await Promise.all((await pushTokensOf(env, quien)).map((token) => sendExpoNoticeLogged(env, token, "Ojo Guard", texto(nombre), motivo'
P1_B = P1_A.replace('pushTokensOf(env, quien)', 'pushTokensPrincipales(env, quien)')
P2_A = 'await Promise.all((await pushTokensOf(env, p.email)).map((token) => sendExpoNoticeLogged(env, token, "Buen d'
P2_B = P2_A.replace('pushTokensOf(env, p.email)', 'pushTokensPrincipales(env, p.email)')
for v in (FN_A, P1_A, P2_A):
    assert BLOQUE.count(v) == 1, (v[:60], BLOQUE.count(v))
filas = [(F, 'cuidado: funcion que elige los telefonos principales', FN_A, FN_B),
         (F, 'cuidado: las alertas a los referentes van a su telefono principal', P1_A, P1_B),
         (F, 'cuidado: el saludo Buen dia va al telefono principal de la persona', P2_A, P2_B)]
def cambios_ps(fs):
    return "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in fs) + "\n)\n"
i0 = tpl.index('$ErrorActionPreference'); j0 = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-cuidadoprincipal')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
MENSAJE = 'LISTO: el Buen dia y sus alertas van al telefono principal de cada cuenta (no a todos). El SOS sigue yendo a todos.'
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "%s"\n' % MENSAJE, cola)
assert MENSAJE in cola
cabeza = '''# aplicar-cuidado-principal-panel.ps1 - Ojo Guard MS (servidor): el "Buen dia" y sus alertas ("X todavia no contesto su Buen dia", "sin senal"...) van al telefono PRINCIPAL de cada cuenta y no a todos los telefonos de la cuenta.
# Luciano (19/11/2026): la alerta le llegaba tambien a Guido y a su papa (telefonos "additional" de la misma cuenta). Si la cuenta no tiene principal con aviso, a todos como antes. El SOS NO cambia. Requiere aplicar-cuidado-panel.ps1.
# Cambia src\\index.ts (respaldo .bak-cuidadoprincipal). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
'''
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'pushTokensPrincipales') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'async function cuidadoAvisar') -eq 0) { Mal "Falta aplicar primero aplicar-cuidado-panel.ps1."; return }
'''
total = cabeza + tpl[i0:j0] + guardas + cambios_ps(filas) + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕‹›']
assert not bad, set(bad)
open(R + 'aplicar-cuidado-principal-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
open(S + 'filas_principal.json', 'w', encoding='utf-8').write(__import__('json').dumps(filas))
open(S + 'cuidado_bloque.ts', 'w', encoding='utf-8').write(BLOQUE)
print('ok', len(total))
