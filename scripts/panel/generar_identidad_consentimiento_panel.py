# Genera scripts/aplicar-identidad-consentimiento-panel.ps1: el servidor guarda que version del texto de consentimiento biometrico acepto la persona (y cuando) antes de mandar la selfie a Didit.
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"


a1 = (
'async function idTabla(env: Env) {\n'
'  await env.DB.prepare("CREATE TABLE IF NOT EXISTS identity_checks (email TEXT PRIMARY KEY, status TEXT NOT NULL, outcome TEXT, score INTEGER, doc_last3 TEXT, doc_hash TEXT, attempts INTEGER NOT NULL DEFAULT 0, attempts_day TEXT, verified_at TEXT, updated_at TEXT NOT NULL)").run();\n'
'}\n'
)
b1 = (
'// Consentimiento biometrico (03/11/2026): antes de mandar la selfie a Didit la app muestra el texto de consentimiento y manda su version (`consentVersion`).\n'
'// El servidor guarda esa version y cuando la vio por primera vez (columnas consent_version y consent_at de identity_checks).\n'
'// IDENTIDAD_CONSENTIMIENTO_OBLIGATORIO = false: mientras queden telefonos con la app vieja, que no manda la version, se sigue verificando sin ella (queda un registro `identity_sin_consentimiento`).\n'
'// Al abrir Ojo Guard al publico, o cuando todos los telefonos tengan la app nueva: ponerlo en true; el servidor contesta 400 consent_required ANTES de llamar a Didit.\n'
'const IDENTIDAD_CONSENTIMIENTO_OBLIGATORIO = false;\n'
'let idColumnasListas = false;\n'
'\n'
'async function idAgregarColumna(env: Env, definicion: string) {\n'
'  try {\n'
'    await env.DB.prepare(`ALTER TABLE identity_checks ADD COLUMN ${definicion}`).run();\n'
'  } catch (error) {\n'
'    // Si la columna ya estaba no pasa nada; cualquier otro error se deja pasar para no seguir sin la columna.\n'
'    if (!/duplicate column/i.test(String(error))) throw error;\n'
'  }\n'
'}\n'
'\n'
'async function idTabla(env: Env) {\n'
'  await env.DB.prepare("CREATE TABLE IF NOT EXISTS identity_checks (email TEXT PRIMARY KEY, status TEXT NOT NULL, outcome TEXT, score INTEGER, doc_last3 TEXT, doc_hash TEXT, attempts INTEGER NOT NULL DEFAULT 0, attempts_day TEXT, verified_at TEXT, updated_at TEXT NOT NULL)").run();\n'
'  if (idColumnasListas) return;\n'
'  await idAgregarColumna(env, "consent_version TEXT");\n'
'  await idAgregarColumna(env, "consent_at TEXT");\n'
'  idColumnasListas = true;\n'
'}\n'
)
a2 = '  if (intentos >= ID_INTENTOS_POR_DIA) return json({ error: "too_many_attempts" }, 429);\n'
b2 = (
a2 +
'  // Consentimiento: la app manda la version del texto que la persona acepto. Con el interruptor prendido, sin consentimiento no se manda nada a Didit.\n'
'  const consentimiento = String(body.consentVersion ?? "").trim();\n'
'  const consentimientoValido = /^\\d{4}-\\d{2}-\\d{2}(\\.[a-z0-9]{1,8})?$/i.test(consentimiento);\n'
'  if (!consentimientoValido) console.error("identity_sin_consentimiento");\n'
'  if (IDENTIDAD_CONSENTIMIENTO_OBLIGATORIO && !consentimientoValido) return json({ error: "consent_required" }, 400);\n'
'  if (consentimientoValido) {\n'
'    const ahora = now();\n'
'    await env.DB.prepare("INSERT INTO identity_checks (email,status,attempts,updated_at,consent_version,consent_at) VALUES (?,?,0,?,?,?) ON CONFLICT(email) DO UPDATE SET consent_at=CASE WHEN identity_checks.consent_version IS excluded.consent_version THEN COALESCE(identity_checks.consent_at, excluded.consent_at) ELSE excluded.consent_at END, consent_version=excluded.consent_version")\n'
'      .bind(email, "sin_verificar", ahora, consentimiento, ahora).run();\n'
'  }\n'
)
filas = [('src\\index.ts', 'Identidad: columnas del consentimiento e interruptor (apagado)', a1, b1),
         ('src\\index.ts', 'Identidad: guardar la version del consentimiento antes de llamar a Didit', a2, b2)]
cambios = "$cambios = @(\n" + ',\n'.join(("    ,@(%s, %s, %s, %s)" if len(filas) == 1 else "    @(%s, %s, %s, %s)") % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-identidad-consentimiento-panel.ps1 - Ojo Guard MS: el servidor guarda que version del texto de consentimiento biometrico acepto la persona, y cuando, antes de mandar la selfie a Didit.
# La app nueva (proxima build) muestra el texto de consentimiento antes del DNI y la selfie y manda `consentVersion`. Con IDENTIDAD_CONSENTIMIENTO_OBLIGATORIO = false (hoy) la app vieja sigue verificando sin mandarla; al lanzar se pone en true.
# Cambia SOLO src\\index.ts (respaldo .bak-consentimiento). Va en la carpeta del PANEL (la que tiene wrangler.toml). No cambia la app. Instalarlo hoy no cambia nada para nadie. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'IDENTIDAD_CONSENTIMIENTO_OBLIGATORIO') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-consentimiento')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: el servidor ya guarda la version del consentimiento (todavia no lo exige)."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›✓']
assert not bad, set(bad)
open(R + 'aplicar-identidad-consentimiento-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
