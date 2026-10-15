# aplicar-consola-pestanas2-panel.ps1 - Consola (Ojo Guard MS), paso 2: lo de arriba no tapa el texto, evidencias sin recuadros vacios, Cuenta en tarjetas y passkey a la vista.
#  - En una pantalla ancha, la franja de arriba (logo, pestanas y botones) queda fija y con fondo: al bajar, el contenido pasa por debajo y ya no queda detras de las pestanas.
#  - Evidencias: si una captura no tiene foto trasera (o delantera), ya no se muestra el recuadro gris que decia "No disponible". La linea "Delantera / Trasera / Audio" sigue diciendo que hay y que falta.
#  - Cuenta: el correo y la proteccion de ingreso quedan en tarjetas separadas, y todas las tarjetas se acomodan en dos columnas en la compu (una sola en el celular).
#  - Acceso: "Entrar con huella o Face ID" queda arriba de todo, a la vista; si ya entraste asi en ese equipo, aparece desplegado. El codigo por correo sigue justo debajo.
#  - En el celular, el logo y los dos botones de arriba entran en una sola linea.
# Ninguna funcion se saca ni cambia. Va en la carpeta del PANEL (la que tiene wrangler.toml). Toca src\panel-index.html, src\panel-app.txt y src\panel-explanations.css.
# Respaldo .bak-paso2. Al final publica el panel solo.
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
foreach ($f in @("src\panel-index.html", "src\panel-app.txt", "src\panel-explanations.css")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\panel-index.html")).texto 'id="passkey-details"') -ne 0) { Avi "El paso 2 ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\panel-index.html")).texto 'id="tab-evidence-count"') -ne 1) { Mal "Falta aplicar antes el paso 1 de la consola (aplicar-consola-pestanas-panel.ps1)."; return }
$cambios = @(
    @('src\panel-index.html', 'acceso: passkey arriba (se agrega)', ('        <form id="email-form">
          <label>Correo registrado<input id="email" type="email" autocomplete="email" placeholder="tu@correo.com" required /></label>
          <button>Enviar c' + [char]0x00f3 + 'digo de 6 n' + [char]0x00fa + 'meros</button>
        </form>'), ('        <details id="passkey-details" class="acceso-passkey">
          <summary>Entrar con huella o Face ID</summary>
        <form id="passkey-form">
          <label>Correo registrado<input id="passkey-email" type="email" autocomplete="username webauthn" placeholder="tu@correo.com" required /></label>
          <button>Entrar con la credencial guardada</button>
          <small>Us' + [char]0x00e1 + ' la huella, Face ID o el PIN de este dispositivo. Funciona ' + [char]0x00fa + 'nicamente si la configuraste antes en este mismo dispositivo y navegador; si no, us' + [char]0x00e1 + ' el c' + [char]0x00f3 + 'digo de abajo.</small>
        </form>
        </details>
        <form id="email-form">
          <label>Correo registrado<input id="email" type="email" autocomplete="email" placeholder="tu@correo.com" required /></label>
          <button>Enviar c' + [char]0x00f3 + 'digo de 6 n' + [char]0x00fa + 'meros</button>
        </form>')),
    @('src\panel-index.html', 'acceso: passkey arriba (se saca de abajo)', ('        <details>
          <summary>Ya configur' + [char]0x00e9 + ' acceso seguro en este dispositivo</summary>
        <form id="passkey-form">
          <label>Correo registrado<input id="passkey-email" type="email" autocomplete="username webauthn" placeholder="tu@correo.com" required /></label>
          <button class="ghost">Entrar con la credencial guardada</button>
          <small>Esta opci' + [char]0x00f3 + 'n funciona ' + [char]0x00fa + 'nicamente si la configuraste antes en este mismo dispositivo y navegador.</small>
        </form>
        </details>
        <details id="totp-login-details">'), '        <details id="totp-login-details">'),
    @('src\panel-app.txt', 'acceso: mensajes de la passkey (el codigo ahora esta abajo)', ('      ? "La verificaci' + [char]0x00f3 + 'n fue cancelada. Si apareci' + [char]0x00f3 + ' un QR, us' + [char]0x00e1 + ' el c' + [char]0x00f3 + 'digo de correo de arriba."
      : "Ese acceso no est' + [char]0x00e1 + ' guardado en este dispositivo. Us' + [char]0x00e1 + ' el c' + [char]0x00f3 + 'digo de correo de arriba.";'), ('      ? "La verificaci' + [char]0x00f3 + 'n fue cancelada. Si apareci' + [char]0x00f3 + ' un QR, us' + [char]0x00e1 + ' el c' + [char]0x00f3 + 'digo de correo de abajo."
      : "Ese acceso no est' + [char]0x00e1 + ' guardado en este dispositivo. Us' + [char]0x00e1 + ' el c' + [char]0x00f3 + 'digo de correo de abajo.";')),
    @('src\panel-app.txt', 'acceso: si ya la usaste aca, se muestra abierta', '  // La passkey anduvo: si habia una marca de "aca no sirve", ya no vale.
  olvidarQueNoHayPasskey();', ('  // La passkey anduvo: si habia una marca de "aca no sirve", ya no vale.
  olvidarQueNoHayPasskey();
  try { localStorage.setItem("ojo_ms_usa_passkey", "1"); } catch { /* navegaci' + [char]0x00f3 + 'n privada */ }')),
    @('src\panel-app.txt', 'acceso: abrir la passkey si ya anduvo en este equipo', 'if (authorizedEmail) { $("#email").value = authorizedEmail; $("#passkey-email").value = authorizedEmail; $("#totp-email").value = authorizedEmail; }', ('if (authorizedEmail) { $("#email").value = authorizedEmail; $("#passkey-email").value = authorizedEmail; $("#totp-email").value = authorizedEmail; }
try { if (localStorage.getItem("ojo_ms_usa_passkey") === "1") $("#passkey-details").open = true; } catch { /* navegaci' + [char]0x00f3 + 'n privada */ }')),
    @('src\panel-index.html', 'cuenta: correo y proteccion en dos tarjetas', ('<small>Las acciones importantes generan un aviso de seguridad por correo.</small><span>Protecci' + [char]0x00f3 + 'n de ingreso</span>'), ('<small>Las acciones importantes generan un aviso de seguridad por correo.</small></article><article class="account-card card"><span>Protecci' + [char]0x00f3 + 'n de ingreso</span>')),
    @('src\panel-app.txt', 'evidencia: solo se muestra lo que hay', '  return `<div class="evidence-placeholder ${available ? "pending-file" : "missing-file"}"><span>${available ? "Registrada por correo" : "No disponible"}</span><strong>${label}</strong></div>`;', ('  // Lo que no hay no ocupa lugar: la linea "Delantera ' + [char]0x2713 + ' ' + [char]0x00b7 + ' Trasera ' + [char]0x2014 + '" de abajo ya dice qu' + [char]0x00e9 + ' falta.
  if (!available) return "";
  return `<div class="evidence-placeholder pending-file"><span>Registrada por correo</span><strong>${label}</strong></div>`;')),
    @('src\panel-explanations.css', 'estilos del paso 2', '/* ---- Cuatro pestanas: Mapa y Familia, Mis Equipos, Evidencias, Cuenta ---- */', '/* ---- Paso 2: evidencia sin recuadros vacios, Cuenta en tarjetas, acceso con passkey arriba ---- */
.evidence-previews:empty { display: none; }
.evidence-previews:has(> :only-child) { grid-template-columns: 1fr; }
.evidence-previews:has(> :only-child) .evidence-image,
.evidence-previews:has(> :only-child) .evidence-placeholder { aspect-ratio: 16 / 9; }

#account { display: grid; grid-template-columns: minmax(0, 1fr); gap: 18px; align-items: start; }
#account > .section-head { margin-bottom: 4px; }
#account > .account-card { margin: 0; padding: clamp(20px, 3vw, 30px); }
#account .account-card button { justify-self: start; }
#account .account-card label { display: block; }
@media (min-width: 900px) {
  #account { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  #account > .section-head { grid-column: 1 / -1; }
}

#access .acceso-passkey { border: 1px solid #5a4818; border-radius: 18px; padding: 4px 16px 14px; margin: 0 0 20px; background: rgba(214, 173, 75, 0.07); }
#access .acceso-passkey > summary { font-weight: 850; color: var(--lime); padding: 12px 0; }
#access .acceso-passkey[open] > summary { padding-bottom: 8px; }
:root[data-theme="light"] #access .acceso-passkey { border-color: #d9c27f; background: #fbf3da; }
:root[data-theme="light"] #access .acceso-passkey > summary { color: var(--gold-text); }

/* En el celular, la franja de arriba (logo y dos botones) entra en una sola linea. */
@media (max-width: 520px) {
  .topbar .brand { white-space: nowrap; letter-spacing: 0.05em; font-size: 0.8rem; }
  .topbar .brand-logo { width: 42px; margin-right: 5px !important; }
  .topbar-actions { gap: 5px; }
  .topbar .topbar-actions #theme-toggle, .topbar .topbar-actions #logout { padding: 8px 9px; font-size: 0.72rem; white-space: nowrap; border-radius: 999px; }
}

/* ---- Cuatro pestanas: Mapa y Familia, Mis Equipos, Evidencias, Cuenta ---- */'),
    @('src\panel-explanations.css', 'barra de arriba fija con fondo (en pantalla ancha)', '  #og-mapa.ogm { top: 78px; height: calc(100vh - 78px); height: calc(100dvh - 78px); }', '  #og-mapa.ogm { top: 78px; height: calc(100vh - 78px); height: calc(100dvh - 78px); }
  /* La franja de arriba (logo, pestanas y botones) queda fija y con fondo: el contenido pasa por debajo sin quedar detras de las pestanas. */
  /* mobile-fixes.css esconde el desborde con overflow-x:hidden, y eso impide que algo quede "pegado" arriba: clip hace lo mismo sin ese efecto. */
  html:root, html:root body { overflow-x: clip; overflow-y: visible; }
  .shell:has(#dashboard:not(.hidden)) > .topbar {
    position: sticky; top: 0; z-index: 29;
    margin-bottom: 28px; padding: 12px 0; min-height: 70px;
    background: rgba(5, 6, 7, 0.94); border-bottom: 1px solid rgba(255, 255, 255, 0.07);
    -webkit-backdrop-filter: blur(10px); backdrop-filter: blur(10px);
    box-shadow: 0 0 0 100vmax rgba(5, 6, 7, 0.94); clip-path: inset(0 -100vmax);
  }
  :root[data-theme="light"] .shell:has(#dashboard:not(.hidden)) > .topbar { background: rgba(246, 244, 238, 0.95); border-bottom-color: rgba(70, 58, 20, 0.12); box-shadow: 0 0 0 100vmax rgba(246, 244, 238, 0.95); }
  nav.bottom-tabs { top: 12px; }')
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
    if (Test-Path ($ruta + ".bak-paso2")) { Mal ("Ya existe " + $t + ".bak-paso2. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-paso2"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-paso2): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-paso2") -Destination $ruta -Force }
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
Ok "LISTO: el panel quedo publicado. Abrilo y mandame fotos (en la compu y en el celular)."
Write-Host ""
