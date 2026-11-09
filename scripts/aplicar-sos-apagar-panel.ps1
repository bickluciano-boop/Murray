# aplicar-sos-apagar-panel.ps1 - Ojo Guard MS: un adulto puede APAGAR su SOS del todo (desde un lugar deliberado de la app) y volver a prenderlo.
# Luciano (09/11/2026, "si, dejalo asi"): la regla "siempre queda alguien que reciba el SOS" se mantiene en las llaves rapidas de PERMISOS, pero un adulto decide por si mismo: puede apagarlo del todo con confirmacion fuerte y aviso a quienes lo recibian.
# Apagado: el SOS no sale (error sos_off) ni a la familia ni a los referentes; los avisos de bateria y "Buen dia" tampoco (van a quienes reciben tu SOS). Un menor no puede apagarlo. Requiere aplicar-cuidado-panel.ps1.
# Tabla nueva sos_prefs (se crea sola). Cambia SOLO src\index.ts (respaldo .bak-sosoff). Va en la carpeta del PANEL. Al final publica el panel solo.
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
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'async function cuidadoCron') -eq 0) { Mal "Falta aplicar primero aplicar-cuidado-panel.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'aplicarLlaves = true') -eq 0) { Mal "Falta aplicar primero aplicar-permisos-ojo4-panel.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'async function nativeCareSos') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
$cambios = @(
    @('src\index.ts', 'sos apagado: tabla y endpoint', 'async function nativeFamilyPause(request: Request, env: Env) {
', '// ---------------------------------------------------------------------------
// SOS apagado del todo (Luciano, 09/11/2026): en las llaves rapidas de PERMISOS siempre queda alguien que reciba el SOS, pero un adulto
// (que decide por si mismo) puede apagarlo del todo desde un lugar DELIBERADO de la app, con confirmacion fuerte y aviso a quienes lo recibian.
// Apagado: el SOS no sale (409 sos_off) y no le llega a nadie; tampoco avisan bateria ni "Buen dia" (todo cuidado va a quienes reciben tu SOS).
// Un menor no puede apagarlo.   CREATE TABLE IF NOT EXISTS sos_prefs (email TEXT PRIMARY KEY, off INTEGER NOT NULL DEFAULT 0, updated_at TEXT NOT NULL);
// ---------------------------------------------------------------------------
let sosOffTablaLista = false;
async function sosOffTabla(env: Env) {
  if (sosOffTablaLista) return;
  await env.DB.prepare("CREATE TABLE IF NOT EXISTS sos_prefs (email TEXT PRIMARY KEY, off INTEGER NOT NULL DEFAULT 0, updated_at TEXT NOT NULL)").run();
  sosOffTablaLista = true;
}
async function sosApagado(env: Env, email: string) {
  try {
    await sosOffTabla(env);
    const f = await env.DB.prepare("SELECT off FROM sos_prefs WHERE email=?").bind(email).first<{ off: number }>();
    return Boolean(f?.off);
  } catch (error) {
    console.error("sos_apagado", String(error).slice(0, 120));
    return false;
  }
}

/** POST /api/native/care/sos {deviceId, off}: apaga o vuelve a prender MI SOS. */
async function nativeCareSos(request: Request, env: Env) {
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const email = await nativeOwnerEmail(request, env, String(body.deviceId ?? ""));
  if (!email) return json({ error: "unauthorized" }, 401);
  if (typeof body.off !== "boolean") return json({ error: "invalid_request" }, 400);
  await sosOffTabla(env);
  if ((await sosApagado(env, email)) === body.off) return json({ ok: true, unchanged: true });
  const soyMenor = await env.DB.prepare("SELECT 1 AS m FROM family_members WHERE member_email=? AND status=''activo'' AND role=''menor'' LIMIT 1").bind(email).first<{ m: number }>();
  if (soyMenor) return json({ error: "minor_locked" }, 403);
  const avisar = async (texto: (nombre: string) => string) => {
    for (const quien of await familySosRecipients(env, email)) {
      const nombre = await familyNameSeenBy(env, email, quien);
      await Promise.all((await pushTokensOf(env, quien)).map((token) => sendExpoNoticeLogged(env, token, "Ojo Guard", texto(nombre), "sos apagado", { channelId: "ojo-familia-aviso" }).catch(() => false)));
    }
  };
  const guardar = () => env.DB.prepare("INSERT INTO sos_prefs (email,off,updated_at) VALUES (?,?,?) ON CONFLICT(email) DO UPDATE SET off=excluded.off, updated_at=excluded.updated_at").bind(email, body.off ? 1 : 0, now()).run();
  // Apagar: se avisa ANTES (despues ya no habria a quien); prender: se avisa DESPUES (recien ahi vuelve a haber destinatarios).
  if (body.off) {
    await avisar((nombre) => `${nombre} apagó su SOS. Ya no vas a recibir sus alertas.`).catch((error) => console.error("sos_off_aviso", String(error).slice(0, 120)));
    await guardar();
  } else {
    await guardar();
    await avisar((nombre) => `${nombre} volvió a prender su SOS.`).catch((error) => console.error("sos_on_aviso", String(error).slice(0, 120)));
  }
  return json({ ok: true });
}

async function nativeFamilyPause(request: Request, env: Env) {
'),
    @('src\index.ts', 'sos apagado: nadie lo recibe', '  if (!aplicarLlaves) return [...destinatarios];
', '  if (!aplicarLlaves) return [...destinatarios];
  // SOS apagado del todo por la propia persona: no le llega a nadie.
  if (await sosApagado(env, person)) return [];
'),
    @('src\index.ts', 'sos apagado: el SOS no sale', '  const destinatarios = await familySosRecipients(env, email);
  if (!destinatarios.length && !(await pldTieneGuardianes(env, email))) return json({ error: "no_recipients" }, 409);
', '  // Apagado del todo por la propia persona (decision suya): el SOS no sale, ni a la familia ni a los referentes.
  if (await sosApagado(env, email)) return json({ error: "sos_off" }, 409);
  const destinatarios = await familySosRecipients(env, email);
  if (!destinatarios.length && !(await pldTieneGuardianes(env, email))) return json({ error: "no_recipients" }, 409);
'),
    @('src\index.ts', 'sos apagado: lo dice el cuidado', 'destinatarios: destinos });
', 'destinatarios: destinos, sosOff: await sosApagado(env, email) });
'),
    @('src\index.ts', 'sos apagado: ruta', '      if (route === "POST /api/native/care/buen-dia/ok") return nativeCareOk(request, env);
', '      if (route === "POST /api/native/care/buen-dia/ok") return nativeCareOk(request, env);
      if (route === "POST /api/native/care/sos") return nativeCareSos(request, env);
'),
    @('src\index.ts', 'sos apagado: borrar cuenta', '  await borrar("care_state", "DELETE FROM care_state WHERE email=?", 1);
', '  await borrar("care_state", "DELETE FROM care_state WHERE email=?", 1);
  await borrar("sos_prefs", "DELETE FROM sos_prefs WHERE email=?", 1);
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
    if (Test-Path ($ruta + ".bak-sosoff")) { Mal ("Ya existe " + $t + ".bak-sosoff. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-sosoff"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-sosoff): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-sosoff") -Destination $ruta -Force }
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
Ok "LISTO: el SOS se puede apagar del todo (y volver a prender)."
Write-Host ""
