# aplicar-huella-equipo-panel.ps1 - Boton "Agregar huella o Face ID en este equipo" en Configuracion > Cuenta y seguridad.
# Luciano (23/10/2026): el acceso seguro (passkey) solo se podia crear desde el boton de la app del telefono. Para entrar al panel desde la
# notebook o la Mac con la huella (Windows Hello, Touch ID) hacia falta poder crearlo desde el propio panel.
# Como funciona: el panel pide al servidor el mismo permiso de un solo uso que da el telefono principal (POST /api/passkeys/bootstrap), y con
# ese permiso registra la huella/Face ID/PIN de ESTE equipo con el mismo codigo de siempre. El servidor exige sesion fuerte (acceso seguro
# o codigo de verificacion de los ultimos 5 minutos): agregar una llave nueva no se puede hacer solo con el codigo del correo. Si hace
# falta, el panel pide confirmar la identidad (huella o codigo de Google Authenticator). Cada alta manda un aviso de seguridad por correo.
# La huella NO se guarda en Ojo Guard: queda en el aparato. Tiene que estar configurada antes en Windows Hello o Touch ID.
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Toca src\index.ts, src\panel-app.txt y src\panel-index.html. Respaldo
# .bak-huellaequipo. Al final publica el panel solo. No hace falta build.
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
if ((Contar (Leer (Join-Path $raiz 'src\index.ts')).texto 'function panelPasskeyBootstrap') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
foreach ($f in @('src\index.ts','src\panel-app.txt','src\panel-index.html')) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz 'src\panel-app.txt')).texto 'async function confirmarIdentidad') -ne 1) { Mal "No encuentro confirmarIdentidad en panel-app.txt. Mandame esta pantalla."; return }
$cambios = @(
    @('src\index.ts', 'ruta nueva: permiso para agregar una huella desde el panel', '      if (route === "POST /api/passkeys/register/options") return registrationOptions(request, env);', '      if (route === "POST /api/passkeys/bootstrap") return panelPasskeyBootstrap(request, env);
      if (route === "POST /api/passkeys/register/options") return registrationOptions(request, env);'),
    @('src\index.ts', 'funcion nueva: panelPasskeyBootstrap', 'async function authenticationOptions(request: Request, env: Env) {', '// Desde el panel (sesion con acceso completo): pide el permiso de un solo uso para registrar una huella, Face ID o PIN en ESTE equipo
// (la computadora o el celular desde el que se mira el panel). Es el mismo permiso que da el telefono principal (el alta no usa el dispositivo
// de referencia; el aviso de seguridad lo manda registrationVerify). Exige sesion fuerte (acceso seguro o codigo de verificacion de los ultimos 5 minutos): agregar una llave nueva a la cuenta no
// se puede hacer solo con el codigo del correo.
async function panelPasskeyBootstrap(request: Request, env: Env) {
  const sessionInfo = await readSessionInfo(request, env.SESSION_SECRET);
  if (!sessionInfo) return json({ error: "unauthorized" }, 401);
  if (sessionInfo.method === "emergency") return json({ error: "emergency_admin_not_allowed" }, 403);
  const { email } = sessionInfo;
  if (!await hasFreshStrongSession(request, env.SESSION_SECRET)) return json({ error: "step_up_required" }, 403);
  return json(await issuePasskeyBootstrap(env, email, "panel-web"), 201);
}

async function authenticationOptions(request: Request, env: Env) {'),
    @('src\panel-app.txt', 'boton: agregar huella en este equipo', 'totpLoginForm.addEventListener("submit", async (event) => {', '// Configuracion > Cuenta y seguridad: agrega la huella, Face ID o PIN de ESTE equipo (la compu o el celular desde el que se mira el panel).
// La huella no viaja ni se guarda en Ojo Guard: queda en el aparato (Windows Hello, Touch ID, huella del celular).
$("#add-passkey-here")?.addEventListener("click", async () => {
  const aviso = $("#add-passkey-message");
  const decir = (texto) => { if (aviso) aviso.textContent = texto; };
  const boton = $("#add-passkey-here");
  boton.disabled = true;
  decir("Preparando…");
  try {
    if (!window.PublicKeyCredential) { decir("Este navegador no permite huella ni Face ID. Probá con Chrome, Edge o Safari actualizados."); return; }
    const pedirPermiso = () => api("/api/passkeys/bootstrap", { method: "POST", headers: { "content-type": "application/json" }, body: "{}" });
    let permiso;
    try {
      permiso = await pedirPermiso();
    } catch (error) {
      if (error?.status !== 403) throw error;
      decir("Confirmá que sos vos (huella o código del autenticador)…");
      await confirmarIdentidad();
      permiso = await pedirPermiso();
    }
    const token = new URL(permiso.registrationUrl).searchParams.get("bootstrap");
    const start = await api("/api/passkeys/register/options", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ bootstrap: token }) });
    decir("Ahora poné la huella, Face ID o el PIN de este equipo.");
    const credential = await navigator.credentials.create({ publicKey: creationOptions(start.options) });
    const nombre = /Mac/i.test(navigator.platform || "") ? "Huella en la Mac" : /Win/i.test(navigator.platform || "") ? "Huella en Windows" : "Huella en este equipo";
    await api("/api/passkeys/register/verify", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ bootstrap: token, challengeId: start.challengeId, response: registrationJSON(credential), displayName: nombre }) });
    olvidarQueNoHayPasskey();
    try { localStorage.setItem("ojo_ms_usa_passkey", "1"); } catch { /* navegación privada */ }
    decir(credential.authenticatorAttachment === "platform"
      ? "Listo. La próxima vez podés entrar con la huella o Face ID de este equipo desde ojoguard.app."
      : "Se guardó, pero en un administrador de contraseñas (por ejemplo el de Google) y no en la huella de este equipo.");
    loadSession();
  } catch (error) {
    decir(error?.name === "NotAllowedError"
      ? "Se canceló o demoró demasiado. Probá de nuevo."
      : error?.message === "second_factor_cancelled"
        ? "No se confirmó tu identidad. No se agregó nada."
        : error?.status === 409
          ? "Primero hay que vincular el teléfono principal."
          : "No pudimos agregarlo. Probá de nuevo en unos segundos.");
  } finally {
    boton.disabled = false;
  }
});

totpLoginForm.addEventListener("submit", async (event) => {'),
    @('src\panel-index.html', 'tarjeta: huella o Face ID en este equipo', '<article class="account-card card" id="totp-card">', '<article class="account-card card" id="passkey-here-card">
          <span>Huella o Face ID en este equipo</span>
          <strong>Entrar sin c&oacute;digos desde ac&aacute;</strong>
          <small>Agrega la huella, el reconocimiento facial o el PIN de este aparato (la computadora o el celular desde el que mir&aacute;s esto). La huella no se guarda en Ojo Guard: queda en el aparato. Tiene que estar configurada antes en Windows Hello o Touch ID.</small>
          <button id="add-passkey-here" class="ghost" type="button">Agregar huella o Face ID en este equipo</button>
          <small id="add-passkey-message" role="status"></small>
        </article>
        <article class="account-card card" id="totp-card">')
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
    if (Test-Path ($ruta + ".bak-huellaequipo")) { Mal ("Ya existe " + $t + ".bak-huellaequipo. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-huellaequipo"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-huellaequipo): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-huellaequipo") -Destination $ruta -Force }
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
Ok "LISTO: el panel quedo publicado. Abri ojoguard.app en la compu, entra a Configuracion > Cuenta y seguridad y toca Agregar huella o Face ID en este equipo."
Write-Host ""
