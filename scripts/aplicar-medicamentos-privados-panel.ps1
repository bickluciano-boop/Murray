# aplicar-medicamentos-privados-panel.ps1 - Ojo Guard MS (servidor): cada medicamento es solo del TELEFONO que lo cargo. Los otros telefonos de la cuenta (por ejemplo Guido o papa) ya no ven la lista ni reciben los avisos.
# Luciano (16/11/2026): "Guido me dice que no le paran de llegar mensajes de medicamentos... le llegan los mios porque el ni sabia que existia". Cambia src\index.ts (respaldo .bak-privados). Va en la carpeta del PANEL (la que tiene wrangler.toml).
# Antes de publicar, asigna los medicamentos ya cargados a "Android Luciano (Xiaomi)" y "iPhone Luciano" (sin telefono dueno un medicamento no avisa a nadie). Al final publica el panel solo.
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
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'async function medDuenos(') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'filasAtrasadas') -eq 0) { Mal "Falta aplicar primero aplicar-medicamentos-pendientes-panel.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto '"ojo-medicamentos"') -eq 0) { Mal "Falta aplicar primero aplicar-orden-sonido-panel.ps1."; return }
$cambios = @(
    @('src\index.ts', 'privados: tabla med_dueno (de que telefono es cada medicamento)', '  await env.DB.prepare("ALTER TABLE med_items ADD COLUMN dia_mes INTEGER").run().catch(() => undefined);
', '  await env.DB.prepare("ALTER TABLE med_items ADD COLUMN dia_mes INTEGER").run().catch(() => undefined);
  await env.DB.prepare("CREATE TABLE IF NOT EXISTS med_dueno (item_id TEXT PRIMARY KEY, device_id TEXT NOT NULL)").run();
'),
    @('src\index.ts', 'privados: funciones del telefono dueno y aviso solo a ese telefono', 'async function medAvisar(env: Env, email: string, titulo: string, texto: string, motivo: string, data: Record<string, unknown>) {
', '/** Cada medicamento es de UN telefono: el que lo cargo. Los demas telefonos de la cuenta (por ejemplo los de la familia) no lo ven ni reciben sus avisos: son datos de salud. */
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
  const filasTokens = await env.DB.prepare("SELECT DISTINCT push_token AS pushToken FROM devices WHERE id=? AND owner_email=? AND approval_status=''approved'' AND push_token IS NOT NULL").bind(dispositivo, email).all<{ pushToken: string }>();
  await Promise.all(filasTokens.results.map((f) => sendExpoNoticeLogged(env, f.pushToken, titulo, texto, motivo, { channelId: "ojo-medicamentos", data }).catch(() => false)));
}
async function medAvisar(env: Env, email: string, titulo: string, texto: string, motivo: string, data: Record<string, unknown>) {
'),
    @('src\index.ts', 'privados: el cron junta los medicamentos por cuenta Y telefono dueno', '  const porPersona = new Map<string, MedItem[]>();
  for (const f of filas.results) {
    const m = medParse(f);
    porPersona.set(m.email, [...(porPersona.get(m.email) ?? []), m]);
  }
  for (const [email, items] of porPersona) {
    try {
', '  const duenosCron = await medDuenosTodos(env);
  const porPersona = new Map<string, MedItem[]>();
  for (const f of filas.results) {
    const m = medParse(f);
    const clave = `${m.email}\u0000${duenosCron.get(m.id) ?? ""}`;
    porPersona.set(clave, [...(porPersona.get(clave) ?? []), m]);
  }
  for (const [clavePersona, items] of porPersona) {
    const [email = "", dispositivo = ""] = clavePersona.split("\u0000");
    // Un medicamento sin telefono dueno no avisa a nadie.
    if (!dispositivo) continue;
    try {
'),
    @('src\index.ts', 'privados: el aviso a la hora va solo al telefono dueno', '        await medAvisar(env, email, varios ? "Medicamentos" : "Medicamento", ', '        await medAvisarA(env, dispositivo, email, varios ? "Medicamentos" : "Medicamento", '),
    @('src\index.ts', 'privados: el recordatorio repetido sabe de que medicamento es (telefono dueno)', '  const desde = new Date(ahoraMs - 24 * 3600_000).toISOString();
  const pendientes = await env.DB.prepare(
    "SELECT d.id AS id, d.email AS email,', '  const duenosRec = await medDuenosTodos(env);
  const desde = new Date(ahoraMs - 24 * 3600_000).toISOString();
  const pendientes = await env.DB.prepare(
    "SELECT d.id AS id, d.item_id AS itemId, d.email AS email,'),
    @('src\index.ts', 'privados: tipo de la consulta de pendientes con itemId', '.all<{ id: string; email: string; hhmm: string; sentAt: string;', '.all<{ id: string; itemId: string; email: string; hhmm: string; sentAt: string;'),
    @('src\index.ts', 'privados: sin telefono dueno no hay recordatorio ni aviso a la familia', '      const primero = lista[0];
      if (!primero) continue;
', '      const primero = lista[0];
      if (!primero) continue;
      if (!duenosRec.get(primero.itemId)) continue;
'),
    @('src\index.ts', 'privados: el recordatorio repetido va solo al telefono dueno', 'if (marcadas.length) await medAvisar(env, primero.email, "Medicamento", ', 'if (marcadas.length) await medAvisarA(env, duenosRec.get(primero.itemId) ?? "", primero.email, "Medicamento", '),
    @('src\index.ts', 'privados: cada telefono ve solo SUS medicamentos en la tarjeta', '  const [items, prefs, medP] = await Promise.all([medItems(env, email), cuidadoPrefs(env, email), medPrefs(env, email)]);
  const loc = cuidadoLocal(Date.now(), prefs.tz);
', '  const [todos, prefs, medP] = await Promise.all([medItems(env, email), cuidadoPrefs(env, email), medPrefs(env, email)]);
  // Cada telefono ve solo SUS medicamentos: los otros telefonos de la cuenta (por ejemplo la familia) no los ven.
  const dispositivoPedido = url.searchParams.get("deviceId") ?? "";
  const duenos = await medDuenos(env, email);
  const items = todos.filter((i) => duenos.get(i.id) === dispositivoPedido);
  const loc = cuidadoLocal(Date.now(), prefs.tz);
'),
    @('src\index.ts', 'privados: las tomas atrasadas tambien son solo del telefono dueno', 'WHERE d.email=? AND d.ok_at IS NULL AND d.sent_at IS NOT NULL AND d.day<? AND d.day>=? ORDER BY d.day ASC, d.hhmm ASC LIMIT 20",
  ).bind(email, loc.dia, desdeDia)', 'WHERE d.email=? AND d.item_id IN (SELECT item_id FROM med_dueno WHERE device_id=?) AND d.ok_at IS NULL AND d.sent_at IS NOT NULL AND d.day<? AND d.day>=? ORDER BY d.day ASC, d.hhmm ASC LIMIT 20",
  ).bind(email, dispositivoPedido, loc.dia, desdeDia)'),
    @('src\index.ts', 'privados: al cambiar un medicamento, solo su telefono dueno puede', '    if (!existe) return json({ error: "not_found" }, 404);
    await env.DB.prepare("UPDATE med_items SET', '    if (!existe) return json({ error: "not_found" }, 404);
    const duenoActual = (await medDuenos(env, email)).get(id);
    if (duenoActual && duenoActual !== String(body.deviceId ?? "")) return json({ error: "not_found" }, 404);
    await env.DB.prepare("UPDATE med_items SET'),
    @('src\index.ts', 'privados: el limite de medicamentos se cuenta por telefono', 'const n = await env.DB.prepare("SELECT COUNT(*) AS n FROM med_items WHERE email=?").bind(email).first<{ n: number }>();', 'const n = await env.DB.prepare("SELECT COUNT(*) AS n FROM med_items WHERE email=? AND id IN (SELECT item_id FROM med_dueno WHERE device_id=?)").bind(email, String(body.deviceId ?? "")).first<{ n: number }>();'),
    @('src\index.ts', 'privados: al guardar un medicamento queda como de este telefono', '  if (body.tzOffsetMin !== undefined) await cuidadoTabla(env).then(() => medGuardarZona(env, email, body.tzOffsetMin)).catch(() => undefined);
  return json({ ok: true, id });', '  await env.DB.prepare("INSERT OR REPLACE INTO med_dueno (item_id, device_id) VALUES (?,?)").bind(id, String(body.deviceId ?? "")).run();
  if (body.tzOffsetMin !== undefined) await cuidadoTabla(env).then(() => medGuardarZona(env, email, body.tzOffsetMin)).catch(() => undefined);
  return json({ ok: true, id });'),
    @('src\index.ts', 'privados: solo el telefono dueno puede borrar un medicamento', '  const id = String(body.id ?? "");
  const existe = await env.DB.prepare("SELECT id FROM med_items WHERE id=? AND email=?").bind(id, email).first<{ id: string }>();
  if (!existe) return json({ error: "not_found" }, 404);
', '  const id = String(body.id ?? "");
  const existe = await env.DB.prepare("SELECT id FROM med_items WHERE id=? AND email=?").bind(id, email).first<{ id: string }>();
  if (!existe) return json({ error: "not_found" }, 404);
  const duenoBorrar = (await medDuenos(env, email)).get(id);
  if (duenoBorrar && duenoBorrar !== String(body.deviceId ?? "")) return json({ error: "not_found" }, 404);
'),
    @('src\index.ts', 'privados: al borrar un medicamento se borra su dueno', '  await env.DB.prepare("DELETE FROM med_items WHERE id=? AND email=?").bind(id, email).run();
', '  await env.DB.prepare("DELETE FROM med_items WHERE id=? AND email=?").bind(id, email).run();
  await env.DB.prepare("DELETE FROM med_dueno WHERE item_id=?").bind(id).run();
')
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
    if (Test-Path ($ruta + ".bak-privados")) { Mal ("Ya existe " + $t + ".bak-privados. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-privados"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-privados): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-privados") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "Archivos listos. Primero asigno cada medicamento ya cargado a su telefono..."
# (Si al final de cada paso aparece 'Assertion failed UV_HANDLE_CLOSING', es inofensivo en Windows.)
& npx.cmd wrangler d1 execute ojo-guard-ms --remote --command "CREATE TABLE IF NOT EXISTS med_dueno (item_id TEXT PRIMARY KEY, device_id TEXT NOT NULL)"
& npx.cmd wrangler d1 execute ojo-guard-ms --remote --command "INSERT OR IGNORE INTO med_dueno (item_id, device_id) SELECT i.id, d.id FROM med_items i JOIN devices d ON d.owner_email=i.email AND d.approval_status='approved' AND d.name IN ('Android Luciano (Xiaomi)','iPhone Luciano')"
Write-Host ""
Write-Host "Medicamentos y el telefono al que quedaron asignados:" -ForegroundColor Cyan
& npx.cmd wrangler d1 execute ojo-guard-ms --remote --command "SELECT i.nombre, d.name AS telefono FROM med_dueno o JOIN med_items i ON i.id=o.item_id JOIN devices d ON d.id=o.device_id ORDER BY d.name, i.nombre"
& npx.cmd wrangler d1 execute ojo-guard-ms --remote --command "SELECT COUNT(*) AS sin_telefono_dueno FROM med_items WHERE id NOT IN (SELECT item_id FROM med_dueno)"
Write-Host ""
Ok "Ahora publico el panel..."
& npx.cmd wrangler deploy
if ($LASTEXITCODE -ne 0) { Mal "No se pudo publicar el panel. Mandame esta pantalla."; return }
Write-Host ""
Ok "LISTO: cada medicamento es solo del telefono que lo cargo. Los demas telefonos de la cuenta ya no los ven ni reciben sus avisos."
Write-Host ""
