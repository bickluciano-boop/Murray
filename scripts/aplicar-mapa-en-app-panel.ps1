# aplicar-mapa-en-app-panel.ps1 - El mapa de Ojo Guard MS adentro de la app Ojo Guard (modo "solo mapa").
# La app (en una proxima build) va a mostrar, apenas se abre, el mismo mapa con tus equipos y tu familia que ya tiene el panel, sin barra de
# arriba ni pestanas. Para eso el panel:
#  - Acepta un enlace de acceso directo "para el mapa" (la app lo pide con destino "mapa"), que abre /acceso-v7?app=mapa con la sesion ya iniciada.
#  - Muestra en ese modo solo el mapa, a pantalla completa. Si no hay sesion, avisa a la app para que muestre otra cosa.
#  - Manda el aviso de seguridad por correo de ese acceso como mucho una vez cada 12 horas por telefono (abrir la app es algo de todos los dias).
#    El boton "Abrir Ojo Guard MS" (la consola completa) sigue avisando siempre.
# Nada cambia en la consola de siempre. Requiere el acceso directo (aplicar-acceso-directo-panel.ps1) y los pasos de la consola.
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Toca src\index.ts, src\panel-index.html, src\panel-app.txt y src\panel-explanations.css.
# Las tablas nuevas las crea el propio panel. Respaldo .bak-mapaapp. Al final publica el panel solo.
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
foreach ($f in @("src\index.ts", "src\panel-index.html", "src\panel-app.txt", "src\panel-explanations.css")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
$indexTexto = (Leer (Join-Path $raiz "src\index.ts")).texto
if ((Contar $indexTexto 'panel_handoff_aviso') -ne 0) { Avi "El mapa dentro de la app ya estaba aplicado en el panel. No toco nada."; return }
if ((Contar $indexTexto 'async function nativePanelHandoff') -eq 0) { Mal "Falta aplicar antes el acceso directo (aplicar-acceso-directo-panel.ps1)."; return }
if ((Contar (Leer (Join-Path $raiz "src\panel-explanations.css")).texto '/* Botones en pastilla (como el dibujo de la consola). */') -ne 1) { Mal "Falta aplicar antes los pasos de la consola (pestanas, ayudas, equipos)."; return }
$cambios = @(
    @('src\index.ts', 'tabla del acceso directo: para que sirve cada enlace', 'used_at INTEGER)").run();
  panelHandoffTable = true;', 'used_at INTEGER)").run();
  // purpose: para que sirve el enlace ("mapa": el mapa dentro de la app). Si la columna ya esta, el ALTER falla y se ignora.
  await env.DB.prepare("ALTER TABLE panel_handoff ADD COLUMN purpose TEXT").run().catch(() => undefined);
  await env.DB.prepare("CREATE TABLE IF NOT EXISTS panel_handoff_aviso (device_id TEXT PRIMARY KEY, noticed_at INTEGER NOT NULL)").run();
  panelHandoffTable = true;'),
    @('src\index.ts', 'pedir el enlace: guardar el destino', '  await env.DB.prepare("INSERT INTO panel_handoff (token_hash,owner_email,device_id,expires_at) VALUES (?,?,?,?)").bind(await hash(token), normalizeEmail(device.ownerEmail), deviceId, ahora + 60_000).run();', '  // destino "mapa": el mapa dentro de la app (se abre cada vez que se abre la app, por eso el aviso por correo se limita, ver abajo).
  const purpose = body.destino === "mapa" ? "mapa" : "consola";
  await env.DB.prepare("INSERT INTO panel_handoff (token_hash,owner_email,device_id,expires_at,purpose) VALUES (?,?,?,?,?)").bind(await hash(token), normalizeEmail(device.ownerEmail), deviceId, ahora + 60_000, purpose).run();'),
    @('src\index.ts', 'canjear el enlace: leer el destino', 'RETURNING owner_email AS ownerEmail, device_id AS deviceId").bind(ahora, await hash(token), ahora).first<{ ownerEmail: string; deviceId: string }>();', 'RETURNING owner_email AS ownerEmail, device_id AS deviceId, purpose").bind(ahora, await hash(token), ahora).first<{ ownerEmail: string; deviceId: string; purpose: string | null }>();'),
    @('src\index.ts', 'canjear el enlace: aviso por correo una vez cada 12 horas para el mapa', '  await sendSecurityNotice(
    env,
    fila.ownerEmail,
    "Ingreso desde la app del tel\u00e9fono",', '  // Abrir el mapa dentro de la app es algo de todos los dias: el aviso por correo sale como mucho una vez cada 12 horas por telefono.
  // Abrir la consola completa (el boton "Abrir Ojo Guard MS") avisa siempre.
  let avisar = true;
  if (fila.purpose === "mapa") {
    const previo = await env.DB.prepare("SELECT noticed_at AS noticedAt FROM panel_handoff_aviso WHERE device_id=?").bind(fila.deviceId).first<{ noticedAt: number }>();
    avisar = !previo || ahora - previo.noticedAt > 12 * 3_600_000;
    if (avisar) await env.DB.prepare("INSERT OR REPLACE INTO panel_handoff_aviso (device_id,noticed_at) VALUES (?,?)").bind(fila.deviceId, ahora).run();
  }
  if (avisar) await sendSecurityNotice(
    env,
    fila.ownerEmail,
    "Ingreso desde la app del tel\u00e9fono",'),
    @('src\index.ts', 'canjear el enlace: ir al mapa solo', '      location: entrada,
      "cache-control": "no-store",
      "set-cookie"', '      location: fila.purpose === "mapa" ? "/acceso-v7?app=mapa" : entrada,
      "cache-control": "no-store",
      "set-cookie"'),
    @('src\panel-index.html', 'modo solo mapa: se marca con ?app=mapa', '/* Tema: claro por defecto; oscuro ("Modo noche") solo si la persona lo eligio con el boton. */', '/* Dentro de la app Ojo Guard (WebView): ?app=mapa muestra solo el mapa, sin barra de arriba ni pestanas. */
      if (/[?&]app=mapa(&|$)/.test(location.search)) document.documentElement.classList.add("app-mapa");
      /* Tema: claro por defecto; oscuro ("Modo noche") solo si la persona lo eligio con el boton. */'),
    @('src\panel-explanations.css', 'modo solo mapa: estilos', '/* Botones en pastilla (como el dibujo de la consola). */', '/* Dentro de la app Ojo Guard (?app=mapa): solo el mapa, ocupando toda la pantalla. */
html.app-mapa .topbar,
html.app-mapa nav.bottom-tabs,
html.app-mapa .dashboard-title,
html.app-mapa .summary-grid,
html.app-mapa .dashboard-section,
html.app-mapa footer { display: none !important; }
html.app-mapa #og-mapa.ogm { top: 0 !important; height: 100vh !important; height: 100dvh !important; }

/* Botones en pastilla (como el dibujo de la consola). */'),
    @('src\panel-app.txt', 'modo solo mapa: avisar a la app si no hay sesion', '} catch { access.classList.remove("hidden"); dashboard.classList.add("hidden"); logout.classList.add("hidden"); }', '} catch {
    access.classList.remove("hidden"); dashboard.classList.add("hidden"); logout.classList.add("hidden");
    // Dentro de la app (WebView) la sesion se abre con el acceso directo: si no hay sesion, la app lo sabe y muestra otra cosa.
    try { window.ReactNativeWebView?.postMessage(JSON.stringify({ tipo: "sin_sesion" })); } catch { /* en el navegador no existe */ }
  }')
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
    if (Test-Path ($ruta + ".bak-mapaapp")) { Mal ("Ya existe " + $t + ".bak-mapaapp. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-mapaapp"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-mapaapp): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-mapaapp") -Destination $ruta -Force }
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
Ok "LISTO: el panel quedo publicado. La app lo va a usar en la proxima build."
Write-Host ""
