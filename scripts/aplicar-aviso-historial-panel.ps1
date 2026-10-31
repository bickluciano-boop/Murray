# aplicar-aviso-historial-panel.ps1 - Ojo Guard MS: en "Administrar" a cada persona de la familia, un tilde "Avisarle cuando miro su recorrido". Lo decide el titular; apagado por defecto.
# Idea de Luciano (31/10/2026): "es una opcion en configuraciones, un tilde que se marca si queres que reciba notificaciones o no. Y lo decide el adulto".
# Si esta tildado, cuando un adulto mira el recorrido de esa persona le llega un aviso sin sonido ("<Nombre> miro tu recorrido."), como mucho una vez cada 6 horas por adulto.
# Cambia src\index.ts (dos tablas nuevas que se crean solas, una ruta y el aviso), src\panel-mapa.txt y src\panel-index.html (v=11). Respaldo .bak-avisohist. Va en la carpeta del PANEL. Sin build. Al final publica el panel solo.
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
foreach ($f in @("src\index.ts", "src\panel-mapa.txt", "src\panel-index.html")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'family_history_notice') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'familyLocationHistory') -lt 1) { Mal "Falta aplicar primero aplicar-historial-familia-panel.ps1. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\panel-index.html")).texto '/mapa-v1.js?v=10') -ne 1) { Mal "El mapa no esta en v=10 (falta aplicar primero aplicar-historial-familia-panel.ps1). No toco nada."; return }
$cambios = @(
    @('src\index.ts', 'servidor: funciones del aviso de historial', 'async function deviceLocationHistory(request: Request, env: Env, url: URL) {
', '// "Avisarle cuando miro su recorrido": un tilde por persona que decide el titular (family_members.id). Apagado por defecto: si esta tildado, cuando un adulto mira el recorrido
// de esa persona le llega un aviso sin sonido, como mucho una vez cada 6 horas por adulto (el mapa pide el historial cada vez que se elige a la persona).
let historialAvisoTablaLista = false;
async function historialAvisoTabla(env: Env) {
  if (historialAvisoTablaLista) return;
  await env.DB.prepare("CREATE TABLE IF NOT EXISTS family_history_notice (person_id TEXT PRIMARY KEY, notify INTEGER NOT NULL DEFAULT 0, updated_at INTEGER NOT NULL)").run();
  await env.DB.prepare("CREATE TABLE IF NOT EXISTS family_history_seen (person_id TEXT NOT NULL, viewer_email TEXT NOT NULL, last_at INTEGER NOT NULL, PRIMARY KEY (person_id, viewer_email))").run();
  historialAvisoTablaLista = true;
}

async function avisoHistorialActivo(env: Env, personId: string): Promise<boolean> {
  try {
    await historialAvisoTabla(env);
    const fila = await env.DB.prepare("SELECT notify FROM family_history_notice WHERE person_id=?").bind(personId).first<{ notify: number }>();
    return fila?.notify === 1;
  } catch {
    return false;
  }
}

/** Si el titular lo pidio, le avisa a la persona (sin sonido) que `viewer` miro su recorrido. Nunca frena el historial. */
async function avisarHistorialMirado(env: Env, viewer: string, personId: string, personEmail: string) {
  try {
    if (!(await avisoHistorialActivo(env, personId))) return;
    const ahora = Date.now();
    const previo = await env.DB.prepare("SELECT last_at AS t FROM family_history_seen WHERE person_id=? AND viewer_email=?").bind(personId, viewer).first<{ t: number }>();
    if (previo && ahora - previo.t < 6 * 3_600_000) return;
    await env.DB.prepare("INSERT INTO family_history_seen (person_id,viewer_email,last_at) VALUES (?,?,?) ON CONFLICT(person_id,viewer_email) DO UPDATE SET last_at=excluded.last_at").bind(personId, viewer, ahora).run();
    const quien = (await familyNameSeenBy(env, viewer, personEmail)) || viewer.split("@")[0];
    for (const token of await pushTokensOf(env, personEmail)) {
      await sendExpoNoticeLogged(env, token, "Ojo Guard", `${quien} mir\u00f3 tu recorrido.`, "historial", { sinSonido: true, ttl: 3600 }).catch(() => false);
    }
  } catch (error) {
    console.error("history_notice_failed", error);
  }
}

// El titular prende o apaga ese aviso para una persona de su familia.
async function remoteFamilyHistoryNotice(request: Request, env: Env) {
  const sessionInfo = await readSessionInfo(request, env.SESSION_SECRET);
  if (!sessionInfo) return json({ error: "unauthorized" }, 401);
  if (sessionInfo.method === "emergency") return json({ error: "not_allowed_in_emergency" }, 403);
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const id = String(body.id ?? "");
  const propia = await env.DB.prepare("SELECT id FROM family_members WHERE id=? AND owner_email=? AND status=''activo''").bind(id, sessionInfo.email).first();
  if (!propia) return json({ error: "not_found" }, 404);
  await historialAvisoTabla(env);
  const notify = body.notify === true ? 1 : 0;
  await env.DB.prepare("INSERT INTO family_history_notice (person_id,notify,updated_at) VALUES (?,?,?) ON CONFLICT(person_id) DO UPDATE SET notify=excluded.notify, updated_at=excluded.updated_at").bind(id, notify, Date.now()).run();
  return json({ saved: true, notify: notify === 1 });
}

async function deviceLocationHistory(request: Request, env: Env, url: URL) {
'),
    @('src\index.ts', 'servidor: avisar al mirar el recorrido', '  if (!miembro?.email) return json({ error: "not_found" }, 404);
', '  if (!miembro?.email) return json({ error: "not_found" }, 404);
  await avisarHistorialMirado(env, sessionInfo.email, personId, miembro.email);
'),
    @('src\index.ts', 'servidor: la lista de la familia trae el tilde', '      photo: await fotoVersion(env, p.email),
    });
', '      photo: await fotoVersion(env, p.email),
      // Solo para quien administra a esa persona (el titular): si le avisa cuando mira su recorrido.
      notifyHistory: p.gestionable ? await avisoHistorialActivo(env, p.id) : undefined,
    });
'),
    @('src\index.ts', 'servidor: ruta del tilde', '      if (route === "GET /api/remote/family") return remoteFamily(request, env);
', '      if (route === "GET /api/remote/family") return remoteFamily(request, env);
      if (route === "POST /api/remote/family/history-notice") return remoteFamilyHistoryNotice(request, env);
'),
    @('src\panel-mapa.txt', 'mapa: estilo del tilde', '</style>
      <div class="ogm-dia hidden" data-ogm="dia-barra">', '#og-mapa .ogm-aviso-hist{display:flex;gap:10px;align-items:flex-start;width:100%;text-align:left;padding:10px;margin:8px 0;border:1px solid var(--ogm-linea);border-radius:12px;background:transparent;color:var(--ogm-texto)}#og-mapa .ogm-aviso-hist i{flex:none;width:22px;height:22px;border:2px solid var(--ogm-oro-vivo);border-radius:6px;display:grid;place-items:center;font-style:normal;font-weight:700;color:var(--ogm-oro-vivo)}#og-mapa .ogm-aviso-hist.on i{background:var(--ogm-oro-fondo)}#og-mapa .ogm-aviso-hist strong{display:block;font-size:.9rem}#og-mapa .ogm-aviso-hist small{display:block;font-size:.76rem;color:var(--ogm-suave);margin-top:2px}</style>
      <div class="ogm-dia hidden" data-ogm="dia-barra">'),
    @('src\panel-mapa.txt', 'mapa: la persona trae el tilde', '      gestionable: Boolean(p.canManage),
', '      gestionable: Boolean(p.canManage),
      avisoHistorial: p.notifyHistory === true,
'),
    @('src\panel-mapa.txt', 'mapa: el cuadro de administrar parte con el tilde', 'rol: equipo.rol, rolActual: equipo.rol, confirmarQuitar: false, error: "" };', 'rol: equipo.rol, rolActual: equipo.rol, avisoHistorial: Boolean(equipo.avisoHistorial), confirmarQuitar: false, error: "" };'),
    @('src\panel-mapa.txt', 'mapa: el tilde en el cuadro de administrar', '      <div class="ogm-dlg-botones"><button type="button" class="oro" data-accion="gestion-guardar" ${d.rol === d.rolActual ? "disabled" : ""}>Guardar</button>', '      ${d.rol !== "amigo" ? `<button type="button" class="ogm-aviso-hist${d.avisoHistorial ? " on" : ""}" data-accion="gestion-aviso" aria-pressed="${d.avisoHistorial ? "true" : "false"}"><i>${d.avisoHistorial ? "✓" : ""}</i><span><strong>Avisarle cuando miro su recorrido</strong><small>Le llega un aviso sin sonido, como mucho una vez cada 6 horas. Si lo dejás apagado, no se entera.</small></span></button>` : ""}
      <div class="ogm-dlg-botones"><button type="button" class="oro" data-accion="gestion-guardar" ${d.rol === d.rolActual ? "disabled" : ""}>Guardar</button>'),
    @('src\panel-mapa.txt', 'mapa: tocar el tilde', '    if (accion === "gestion-guardar") return guardarGestion(boton);
', '    if (accion === "gestion-guardar") return guardarGestion(boton);
    if (accion === "gestion-aviso") return cambiarAvisoHistorial();
'),
    @('src\panel-mapa.txt', 'mapa: guardar el tilde', 'async function quitarGestion(boton) {
', '// El tilde "Avisarle cuando miro su recorrido": se guarda al tocarlo.
async function cambiarAvisoHistorial() {
  const d = estado.dialogo;
  if (!d || d.paso !== "gestion") return;
  const nuevo = !d.avisoHistorial;
  d.avisoHistorial = nuevo;
  d.error = "";
  dibujarDialogo();
  try {
    await pedir("/api/remote/family/history-notice", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ id: d.id, notify: nuevo }) });
    const persona = estado.equipos.find((e) => e.id === d.equipoId);
    if (persona) persona.avisoHistorial = nuevo;
  } catch (error) {
    d.avisoHistorial = !nuevo;
    d.error = errorGestion(error, "guardar este aviso");
    dibujarDialogo();
  }
}

async function quitarGestion(boton) {
'),
    @('src\panel-index.html', 'recargar el mapa nuevo (v=11)', '<script type="module" src="/mapa-v1.js?v=10"></script>', '<script type="module" src="/mapa-v1.js?v=11"></script>')
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
    if (Test-Path ($ruta + ".bak-avisohist")) { Mal ("Ya existe " + $t + ".bak-avisohist. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-avisohist"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-avisohist): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-avisohist") -Destination $ruta -Force }
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
Ok "LISTO: en Administrar a cada persona hay un tilde para avisarle cuando miras su recorrido. Cerra y abri la app (o recarga la pagina del mapa)."
Write-Host ""
