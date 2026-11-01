# aplicar-sos-atajo-panel.ps1 - Ojo Guard MS: SOS desde el Apple Watch (o cualquier atajo) con un enlace secreto por persona que dispara el mismo SOS de siempre.
# Idea de Luciano (01/11/2026): que el ecosistema (iPhone, Android, Mac, reloj) conviva. PRUEBA: hay que ver en el reloj de Luciano si "Obtener contenido de URL" anda en la watchOS actual.
# Pagina para crear/revocar el enlace: ojoguard.app/atajo-sos (con la sesion del panel). Endpoint: POST /api/sos/atajo/<clave> (solo se guarda el hash). Cambia SOLO src\index.ts (el SOS del telefono se parte en dos funciones, sin cambiar lo que hace). Respaldo .bak-sosatajo. Va en la carpeta del PANEL. Sin build. Al final publica el panel solo.
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
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'async function sosAtajoDisparar') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
$cambios = @(
    @('src\index.ts', 'SOS: el SOS en si pasa a una funcion reutilizable', '  if (!email) return json({ error: "unauthorized" }, 401);
  const activo = await familySosOf(env, email);
  if (body.action === "cancel") {
', '  if (!email) return json({ error: "unauthorized" }, 401);
  return ejecutarFamilySos(env, email, deviceId, body);
}

/** El SOS en si (mandar o cancelar). Lo llaman el telefono (nativeFamilySos) y el enlace secreto del reloj (sosAtajoDisparar). */
async function ejecutarFamilySos(env: Env, email: string, deviceId: string, body: Record<string, unknown>) {
  const activo = await familySosOf(env, email);
  if (body.action === "cancel") {
'),
    @('src\index.ts', 'SOS del reloj: funciones y pagina', '/** El panel: quien recibio un SOS lo marca como atendido. */
async function remoteFamilySos(request: Request, env: Env) {
', '// ---------------------------------------------------------------------------
// SOS desde el reloj (Atajos): un enlace secreto por persona que dispara el mismo SOS de siempre. Solo se guarda el hash del enlace;
// se muestra una vez al crearlo y se puede revocar. Pagina para crearlo: /atajo-sos (con la sesion del panel).
// ---------------------------------------------------------------------------
let sosAtajoTablaLista = false;
async function sosAtajoTabla(env: Env) {
  if (sosAtajoTablaLista) return;
  await env.DB.prepare("CREATE TABLE IF NOT EXISTS sos_atajo (key_hash TEXT PRIMARY KEY, email TEXT NOT NULL, device_id TEXT NOT NULL, created_at INTEGER NOT NULL, last_used_at INTEGER, revoked_at INTEGER)").run();
  sosAtajoTablaLista = true;
}

/** El panel: ver, crear o revocar el enlace de SOS para el reloj de quien tiene la sesion. */
async function remoteSosAtajo(request: Request, env: Env) {
  const sessionInfo = await readSessionInfo(request, env.SESSION_SECRET);
  if (!sessionInfo) return json({ error: "unauthorized" }, 401);
  if (sessionInfo.method === "emergency") return json({ error: "not_allowed_in_emergency" }, 403);
  const email = sessionInfo.email;
  await sosAtajoTabla(env);
  const activo = await env.DB.prepare("SELECT created_at AS createdAt, last_used_at AS lastUsedAt FROM sos_atajo WHERE email=? AND revoked_at IS NULL ORDER BY created_at DESC LIMIT 1")
    .bind(email).first<{ createdAt: number; lastUsedAt: number | null }>();
  if (request.method === "GET") return json({ active: Boolean(activo), createdAt: activo?.createdAt ?? null, lastUsedAt: activo?.lastUsedAt ?? null });
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  if (body.action === "revoke") {
    await env.DB.prepare("UPDATE sos_atajo SET revoked_at=? WHERE email=? AND revoked_at IS NULL").bind(Date.now(), email).run();
    await sendSecurityNotice(env, email, "Se desactivó el enlace de SOS del reloj", "Se desactivó el enlace secreto para mandar un SOS desde el reloj (Atajos). Si no fuiste vos, entrá al panel y revisá tu cuenta.", "Ojo Guard").catch(() => undefined);
    return json({ revoked: true });
  }
  if (body.action !== "create") return json({ error: "invalid_action" }, 400);
  const equipo = await env.DB.prepare(
    "SELECT id FROM devices WHERE owner_email=? AND approval_status=''approved'' ORDER BY CASE WHEN platform IN (''ios'',''android'') THEN 0 ELSE 1 END, CASE WHEN device_role=''primary'' THEN 0 ELSE 1 END, COALESCE(last_seen_at,'''') DESC LIMIT 1",
  ).bind(email).first<{ id: string }>();
  if (!equipo) return json({ error: "no_device" }, 409);
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  const clave = btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  await env.DB.prepare("UPDATE sos_atajo SET revoked_at=? WHERE email=? AND revoked_at IS NULL").bind(Date.now(), email).run();
  await env.DB.prepare("INSERT INTO sos_atajo (key_hash,email,device_id,created_at) VALUES (?,?,?,?)").bind(await hash(clave), email, equipo.id, Date.now()).run();
  await sendSecurityNotice(env, email, "Se creó un enlace de SOS para el reloj", "Se creó un enlace secreto para mandar un SOS desde el reloj (Atajos). Quien lo tenga puede disparar un SOS en tu nombre: no lo compartas. Si no fuiste vos, entrá al panel y revocalo desde ojoguard.app/atajo-sos.", "Ojo Guard").catch(() => undefined);
  return json({ url: `${new URL(request.url).origin}/api/sos/atajo/${clave}` }, 201);
}

/** El enlace secreto del reloj: POST /api/sos/atajo/<clave>. Cuerpo opcional: {latitude, longitude, accuracy} o {action: "cancel"} para "Estoy bien". */
async function sosAtajoDisparar(request: Request, env: Env, clave: string) {
  if (!/^[A-Za-z0-9_-]{40,64}$/.test(clave)) return json({ error: "not_found" }, 404);
  await sosAtajoTabla(env);
  const claveHash = await hash(clave);
  const fila = await env.DB.prepare("SELECT email, device_id AS deviceId FROM sos_atajo WHERE key_hash=? AND revoked_at IS NULL").bind(claveHash).first<{ email: string; deviceId: string }>();
  if (!fila) return json({ error: "not_found" }, 404);
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const crudoLat = body.latitude ?? body.lat, crudoLng = body.longitude ?? body.lng;
  const hayCoordenadas = [crudoLat, crudoLng].every((v) => (typeof v === "number" || typeof v === "string") && String(v).trim() !== "");
  const latitud = hayCoordenadas ? Number(crudoLat) : NaN, longitud = hayCoordenadas ? Number(crudoLng) : NaN;
  const location = Number.isFinite(latitud) && Number.isFinite(longitud) && Math.abs(latitud) <= 90 && Math.abs(longitud) <= 180
    ? { latitude: latitud, longitude: longitud, accuracy: Number.isFinite(Number(body.accuracy)) ? Number(body.accuracy) : null, capturedAt: now() }
    : null;
  await env.DB.prepare("UPDATE sos_atajo SET last_used_at=? WHERE key_hash=?").bind(Date.now(), claveHash).run();
  return ejecutarFamilySos(env, fila.email, fila.deviceId, { action: body.action === "cancel" ? "cancel" : "send", location });
}

/** Pagina /atajo-sos: crear el enlace, copiarlo y armar el atajo en el iPhone para mostrarlo en el Apple Watch. */
function sosAtajoPagina() {
  return pldPagina("SOS desde el reloj · Ojo Guard", `
<h1>SOS desde el reloj</h1>
<p>Un enlace secreto para mandar tu SOS con un toque desde el Apple Watch (o con la voz: "Oye Siri, SOS Ojo Guard"). Avisa a tu familia igual que el botón de la app.</p>
<div id="aviso"></div>
<div class="tarjeta"><h2>Tu enlace</h2>
<p id="estado" class="suave">Mirando…</p>
<div id="nuevo" style="display:none"><p><b>Copialo ahora:</b> por seguridad no se vuelve a mostrar.</p><p><input id="enlace" readonly style="width:100%;font-size:.85rem"></p><p><button class="boton" id="copiar">Copiar enlace</button></p></div>
<p><button class="boton" id="crear">Crear enlace nuevo</button> <button class="boton sec" id="revocar" style="display:none">Desactivar enlace</button></p>
<p class="suave">Quien tenga este enlace puede disparar un SOS en tu nombre: no lo compartas. Si creás uno nuevo, el anterior deja de servir.</p></div>
<div class="tarjeta"><h2>Armar el atajo (en el iPhone)</h2><ol>
<li>Abrí la app <b>Atajos</b> y tocá <b>+</b>.</li>
<li>Agregá la acción <b>Obtener contenido de URL</b>. En la URL pegá el enlace. Tocala para abrir los detalles y elegí Método <b>POST</b>.</li>
<li>Ponele de nombre <b>SOS Ojo Guard</b>. En los detalles del atajo (la "i") activá <b>Mostrar en Apple Watch</b>.</li>
<li>En el reloj abrí Atajos y tocá el atajo, o decí "Oye Siri, SOS Ojo Guard".</li></ol>
<p><b>Para cancelar ("Estoy bien"):</b> otro atajo igual, pero en <b>Cuerpo de la solicitud</b> elegí JSON y agregá un campo de texto <b>action</b> con el valor <b>cancel</b>.</p>
<p class="suave">Usa tu última ubicación conocida. Probalo avisando antes a tu familia: les va a sonar la sirena.</p></div>
<p><a class="boton sec" href="/">Volver al panel</a></p>
<script>
(function(){
var estado=document.getElementById("estado"),nuevo=document.getElementById("nuevo"),enlace=document.getElementById("enlace"),crear=document.getElementById("crear"),revocar=document.getElementById("revocar"),aviso=document.getElementById("aviso");
function pedir(m,cuerpo){return fetch("/api/remote/sos-atajo",{method:m,credentials:"same-origin",headers:{"content-type":"application/json"},body:cuerpo?JSON.stringify(cuerpo):undefined}).then(function(r){return r.json().then(function(d){if(!r.ok){var e=new Error(d.error||"error");e.estado=r.status;throw e}return d})})}
function fecha(t){return t?new Date(t).toLocaleString("es-AR"):""}
function mirar(){pedir("GET").then(function(d){revocar.style.display=d.active?"":"none";crear.textContent=d.active?"Crear enlace nuevo (reemplaza al actual)":"Crear enlace";estado.textContent=d.active?"Tenés un enlace activo (creado el "+fecha(d.createdAt)+(d.lastUsedAt?"; último uso: "+fecha(d.lastUsedAt):"; todavía sin usar")+").":"Todavía no creaste un enlace."}).catch(function(e){crear.disabled=true;estado.textContent=e.estado===401?"Entrá primero al panel (ojoguard.app) con tu correo y volvé a esta página.":"No se pudo ver el estado."})}
crear.onclick=function(){crear.disabled=true;aviso.textContent="";pedir("POST",{action:"create"}).then(function(d){enlace.value=d.url;nuevo.style.display="";mirar()}).catch(function(e){aviso.textContent=e.estado===409?"No hay un teléfono vinculado a tu cuenta.":"No se pudo crear el enlace."}).then(function(){crear.disabled=false})};
document.getElementById("copiar").onclick=function(){enlace.select();try{navigator.clipboard.writeText(enlace.value)}catch(e){document.execCommand("copy")}this.textContent="Copiado"};
revocar.onclick=function(){if(!confirm("¿Desactivar el enlace? El atajo del reloj deja de funcionar."))return;pedir("POST",{action:"revoke"}).then(function(){nuevo.style.display="none";mirar()}).catch(function(){aviso.textContent="No se pudo desactivar."})};
mirar();
})();
</script>`);
}

/** El panel: quien recibio un SOS lo marca como atendido. */
async function remoteFamilySos(request: Request, env: Env) {
'),
    @('src\index.ts', 'SOS del reloj: rutas', '      if (route === "GET /camino") return gdPaginaCamino();
', '      if (route === "GET /atajo-sos") return sosAtajoPagina();
      if (route === "GET /api/remote/sos-atajo" || route === "POST /api/remote/sos-atajo") return remoteSosAtajo(request, env);
      if (request.method === "POST" && url.pathname.startsWith("/api/sos/atajo/")) return sosAtajoDisparar(request, env, url.pathname.slice("/api/sos/atajo/".length));
      if (route === "GET /camino") return gdPaginaCamino();
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
    if (Test-Path ($ruta + ".bak-sosatajo")) { Mal ("Ya existe " + $t + ".bak-sosatajo. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-sosatajo"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-sosatajo): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-sosatajo") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "Archivos listos. Ahora publico el panel..."
& npx.cmd wrangler deploy
if ($LASTEXITCODE -ne 0) { Mal "No se pudo publicar el panel. Mandame esta pantalla."; return }
Write-Host ""
Ok "LISTO: abri ojoguard.app/atajo-sos con tu sesion para crear el enlace del SOS del reloj."
Write-Host ""
