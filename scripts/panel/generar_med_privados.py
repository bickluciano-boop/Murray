# Genera scripts/aplicar-medicamentos-privados-panel.ps1 (servidor).
# Luciano (16/11/2026): "Guido me dice que no le paran de llegar mensajes de medicamentos... le llegan los mios porque el ni sabia que existia".
# Causa: los avisos y la lista de medicamentos se buscaban por el CORREO de la cuenta, y en la cuenta de Luciano estan vinculados varios telefonos
# (Xiaomi de Luciano, Samsung de Guido, Android de papa): todos recibian los avisos de medicamentos de Luciano (datos de salud). Antes no se notaba porque salian en silencio;
# al ponerles sonido (orden-sonido) empezaron a sonar.
# Arreglo: cada medicamento es de UN telefono (el que lo cargo; tabla med_dueno item -> telefono). Solo ese telefono lo ve en su tarjeta y recibe sus avisos.
# Los medicamentos ya cargados se asignan, antes de publicar, a los telefonos de Luciano ("Android Luciano (Xiaomi)" y "iPhone Luciano"). Un medicamento sin telefono dueno no avisa a nadie.
import re
R = '/home/user/Murray/scripts/'
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/priv/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
IDX = 'src\\index.ts'

filas = []
def fila(nombre, viejo, nuevo):
    filas.append((IDX, nombre, viejo, nuevo))

fila('privados: tabla med_dueno (de que telefono es cada medicamento)',
     '  await env.DB.prepare("ALTER TABLE med_items ADD COLUMN dia_mes INTEGER").run().catch(() => undefined);\n',
     '  await env.DB.prepare("ALTER TABLE med_items ADD COLUMN dia_mes INTEGER").run().catch(() => undefined);\n  await env.DB.prepare("CREATE TABLE IF NOT EXISTS med_dueno (item_id TEXT PRIMARY KEY, device_id TEXT NOT NULL)").run();\n')

AYUDAS = '''/** Cada medicamento es de UN telefono: el que lo cargo. Los demas telefonos de la cuenta (por ejemplo los de la familia) no lo ven ni reciben sus avisos: son datos de salud. */
async function medDuenos(env: Env, email: string): Promise<Map<string, string>> {
  const r = await env.DB.prepare("SELECT o.item_id AS itemId, o.device_id AS deviceId FROM med_dueno o JOIN med_items i ON i.id=o.item_id WHERE i.email=?").bind(email).all<{ itemId: string; deviceId: string }>();
  return new Map(r.results.map((x) => [x.itemId, x.deviceId] as [string, string]));
}
async function medDuenosTodos(env: Env): Promise<Map<string, string>> {
  const r = await env.DB.prepare("SELECT item_id AS itemId, device_id AS deviceId FROM med_dueno").all<{ itemId: string; deviceId: string }>();
  return new Map(r.results.map((x) => [x.itemId, x.deviceId] as [string, string]));
}
/** Aviso de medicamentos SOLO al telefono dueno. Si no se sabe cual es, no se manda a nadie. */
async function medAvisarA(env: Env, dispositivo: string, email: string, titulo: string, texto: string, motivo: string, data: Record<string, unknown>) {
  if (!dispositivo) return;
  const filasTokens = await env.DB.prepare("SELECT DISTINCT push_token AS pushToken FROM devices WHERE id=? AND owner_email=? AND approval_status='approved' AND push_token IS NOT NULL").bind(dispositivo, email).all<{ pushToken: string }>();
  await Promise.all(filasTokens.results.map((f) => sendExpoNoticeLogged(env, f.pushToken, titulo, texto, motivo, { channelId: "ojo-medicamentos", data }).catch(() => false)));
}
'''
A_AV = 'async function medAvisar(env: Env, email: string, titulo: string, texto: string, motivo: string, data: Record<string, unknown>) {\n'
fila('privados: funciones del telefono dueno y aviso solo a ese telefono', A_AV, AYUDAS + A_AV)

fila('privados: el cron junta los medicamentos por cuenta Y telefono dueno',
     '  const porPersona = new Map<string, MedItem[]>();\n  for (const f of filas.results) {\n    const m = medParse(f);\n    porPersona.set(m.email, [...(porPersona.get(m.email) ?? []), m]);\n  }\n  for (const [email, items] of porPersona) {\n    try {\n',
     '  const duenosCron = await medDuenosTodos(env);\n  const porPersona = new Map<string, MedItem[]>();\n  for (const f of filas.results) {\n    const m = medParse(f);\n    const clave = `${m.email}\\u0000${duenosCron.get(m.id) ?? ""}`;\n    porPersona.set(clave, [...(porPersona.get(clave) ?? []), m]);\n  }\n  for (const [clavePersona, items] of porPersona) {\n    const [email = "", dispositivo = ""] = clavePersona.split("\\u0000");\n    // Un medicamento sin telefono dueno no avisa a nadie.\n    if (!dispositivo) continue;\n    try {\n')

fila('privados: el aviso a la hora va solo al telefono dueno',
     '        await medAvisar(env, email, varios ? "Medicamentos" : "Medicamento", ',
     '        await medAvisarA(env, dispositivo, email, varios ? "Medicamentos" : "Medicamento", ')

fila('privados: el recordatorio repetido sabe de que medicamento es (telefono dueno)',
     '  const desde = new Date(ahoraMs - 24 * 3600_000).toISOString();\n  const pendientes = await env.DB.prepare(\n    "SELECT d.id AS id, d.email AS email,',
     '  const duenosRec = await medDuenosTodos(env);\n  const desde = new Date(ahoraMs - 24 * 3600_000).toISOString();\n  const pendientes = await env.DB.prepare(\n    "SELECT d.id AS id, d.item_id AS itemId, d.email AS email,')
fila('privados: tipo de la consulta de pendientes con itemId',
     '.all<{ id: string; email: string; hhmm: string; sentAt: string;',
     '.all<{ id: string; itemId: string; email: string; hhmm: string; sentAt: string;')
fila('privados: sin telefono dueno no hay recordatorio ni aviso a la familia',
     '      const primero = lista[0];\n      if (!primero) continue;\n',
     '      const primero = lista[0];\n      if (!primero) continue;\n      if (!duenosRec.get(primero.itemId)) continue;\n')
fila('privados: el recordatorio repetido va solo al telefono dueno',
     'if (marcadas.length) await medAvisar(env, primero.email, "Medicamento", ',
     'if (marcadas.length) await medAvisarA(env, duenosRec.get(primero.itemId) ?? "", primero.email, "Medicamento", ')

fila('privados: cada telefono ve solo SUS medicamentos en la tarjeta',
     '  const [items, prefs, medP] = await Promise.all([medItems(env, email), cuidadoPrefs(env, email), medPrefs(env, email)]);\n  const loc = cuidadoLocal(Date.now(), prefs.tz);\n',
     '  const [todos, prefs, medP] = await Promise.all([medItems(env, email), cuidadoPrefs(env, email), medPrefs(env, email)]);\n  // Cada telefono ve solo SUS medicamentos: los otros telefonos de la cuenta (por ejemplo la familia) no los ven.\n  const dispositivoPedido = url.searchParams.get("deviceId") ?? "";\n  const duenos = await medDuenos(env, email);\n  const items = todos.filter((i) => duenos.get(i.id) === dispositivoPedido);\n  const loc = cuidadoLocal(Date.now(), prefs.tz);\n')
fila('privados: las tomas atrasadas tambien son solo del telefono dueno',
     'WHERE d.email=? AND d.ok_at IS NULL AND d.sent_at IS NOT NULL AND d.day<? AND d.day>=? ORDER BY d.day ASC, d.hhmm ASC LIMIT 20",\n  ).bind(email, loc.dia, desdeDia)',
     'WHERE d.email=? AND d.item_id IN (SELECT item_id FROM med_dueno WHERE device_id=?) AND d.ok_at IS NULL AND d.sent_at IS NOT NULL AND d.day<? AND d.day>=? ORDER BY d.day ASC, d.hhmm ASC LIMIT 20",\n  ).bind(email, dispositivoPedido, loc.dia, desdeDia)')

fila('privados: al cambiar un medicamento, solo su telefono dueno puede',
     '    if (!existe) return json({ error: "not_found" }, 404);\n    await env.DB.prepare("UPDATE med_items SET',
     '    if (!existe) return json({ error: "not_found" }, 404);\n    const duenoActual = (await medDuenos(env, email)).get(id);\n    if (duenoActual && duenoActual !== String(body.deviceId ?? "")) return json({ error: "not_found" }, 404);\n    await env.DB.prepare("UPDATE med_items SET')
fila('privados: el limite de medicamentos se cuenta por telefono',
     'const n = await env.DB.prepare("SELECT COUNT(*) AS n FROM med_items WHERE email=?").bind(email).first<{ n: number }>();',
     'const n = await env.DB.prepare("SELECT COUNT(*) AS n FROM med_items WHERE email=? AND id IN (SELECT item_id FROM med_dueno WHERE device_id=?)").bind(email, String(body.deviceId ?? "")).first<{ n: number }>();')
fila('privados: al guardar un medicamento queda como de este telefono',
     '  if (body.tzOffsetMin !== undefined) await cuidadoTabla(env).then(() => medGuardarZona(env, email, body.tzOffsetMin)).catch(() => undefined);\n  return json({ ok: true, id });',
     '  await env.DB.prepare("INSERT OR REPLACE INTO med_dueno (item_id, device_id) VALUES (?,?)").bind(id, String(body.deviceId ?? "")).run();\n  if (body.tzOffsetMin !== undefined) await cuidadoTabla(env).then(() => medGuardarZona(env, email, body.tzOffsetMin)).catch(() => undefined);\n  return json({ ok: true, id });')

fila('privados: solo el telefono dueno puede borrar un medicamento',
     '  const id = String(body.id ?? "");\n  const existe = await env.DB.prepare("SELECT id FROM med_items WHERE id=? AND email=?").bind(id, email).first<{ id: string }>();\n  if (!existe) return json({ error: "not_found" }, 404);\n',
     '  const id = String(body.id ?? "");\n  const existe = await env.DB.prepare("SELECT id FROM med_items WHERE id=? AND email=?").bind(id, email).first<{ id: string }>();\n  if (!existe) return json({ error: "not_found" }, 404);\n  const duenoBorrar = (await medDuenos(env, email)).get(id);\n  if (duenoBorrar && duenoBorrar !== String(body.deviceId ?? "")) return json({ error: "not_found" }, 404);\n')
fila('privados: al borrar un medicamento se borra su dueno',
     '  await env.DB.prepare("DELETE FROM med_items WHERE id=? AND email=?").bind(id, email).run();\n',
     '  await env.DB.prepare("DELETE FROM med_items WHERE id=? AND email=?").bind(id, email).run();\n  await env.DB.prepare("DELETE FROM med_dueno WHERE item_id=?").bind(id).run();\n')

def cambios_ps(fs):
    return "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in fs) + "\n)\n"

SQL_TABLA = "CREATE TABLE IF NOT EXISTS med_dueno (item_id TEXT PRIMARY KEY, device_id TEXT NOT NULL)"
SQL_ASIGNAR = "INSERT OR IGNORE INTO med_dueno (item_id, device_id) SELECT i.id, d.id FROM med_items i JOIN devices d ON d.owner_email=i.email AND d.approval_status='approved' AND d.name IN ('Android Luciano (Xiaomi)','iPhone Luciano')"
SQL_CONTROL = "SELECT i.nombre, d.name AS telefono FROM med_dueno o JOIN med_items i ON i.id=o.item_id JOIN devices d ON d.id=o.device_id ORDER BY d.name, i.nombre"
SQL_SIN_DUENO = "SELECT COUNT(*) AS sin_telefono_dueno FROM med_items WHERE id NOT IN (SELECT item_id FROM med_dueno)"

i0 = tpl.index('$ErrorActionPreference'); j0 = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-privados')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
MENSAJE = 'LISTO: cada medicamento es solo del telefono que lo cargo. Los demas telefonos de la cuenta ya no los ven ni reciben sus avisos.'
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "%s"\n' % MENSAJE, cola)
assert MENSAJE in cola
ANTES_DEPLOY = 'Ok "Archivos listos. Ahora publico el panel..."\n'
assert cola.count(ANTES_DEPLOY) == 1
BACKFILL = '''Ok "Archivos listos. Primero asigno cada medicamento ya cargado a su telefono..."
# (Si al final de cada paso aparece 'Assertion failed UV_HANDLE_CLOSING', es inofensivo en Windows.)
& npx.cmd wrangler d1 execute ojo-guard-ms --remote --command "%s"
& npx.cmd wrangler d1 execute ojo-guard-ms --remote --command "%s"
Write-Host ""
Write-Host "Medicamentos y el telefono al que quedaron asignados:" -ForegroundColor Cyan
& npx.cmd wrangler d1 execute ojo-guard-ms --remote --command "%s"
& npx.cmd wrangler d1 execute ojo-guard-ms --remote --command "%s"
Write-Host ""
Ok "Ahora publico el panel..."
''' % (SQL_TABLA, SQL_ASIGNAR, SQL_CONTROL, SQL_SIN_DUENO)
cola = cola.replace(ANTES_DEPLOY, BACKFILL)
cabeza = '''# aplicar-medicamentos-privados-panel.ps1 - Ojo Guard MS (servidor): cada medicamento es solo del TELEFONO que lo cargo. Los otros telefonos de la cuenta (por ejemplo Guido o papa) ya no ven la lista ni reciben los avisos.
# Luciano (16/11/2026): "Guido me dice que no le paran de llegar mensajes de medicamentos... le llegan los mios porque el ni sabia que existia". Cambia src\\index.ts (respaldo .bak-privados). Va en la carpeta del PANEL (la que tiene wrangler.toml).
# Antes de publicar, asigna los medicamentos ya cargados a "Android Luciano (Xiaomi)" y "iPhone Luciano" (sin telefono dueno un medicamento no avisa a nadie). Al final publica el panel solo.
'''
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'async function medDuenos(') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'filasAtrasadas') -eq 0) { Mal "Falta aplicar primero aplicar-medicamentos-pendientes-panel.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto '"ojo-medicamentos"') -eq 0) { Mal "Falta aplicar primero aplicar-orden-sonido-panel.ps1."; return }
'''
total = cabeza + tpl[i0:j0] + guardas + cambios_ps(filas) + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕‹›']
assert not bad, set(bad)
open(R + 'aplicar-medicamentos-privados-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
# replica
t = open(S + 'med-actual.ts', encoding='utf-8').read()
for a, n, v, nv in filas:
    assert t.count(v) == 1, (n, t.count(v))
for a, n, v, nv in filas:
    t = t.replace(v, nv)
open(S + 'med-privados.ts', 'w', encoding='utf-8').write(t)
print('ok', len(total), len(filas), 'filas')
