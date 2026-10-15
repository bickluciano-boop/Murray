# aplicar-consola-pestanas-panel.ps1 - Consola (Ojo Guard MS), paso 1: abre CLARA, cuatro pestanas y lo mismo de siempre, mas ordenado.
#  - Abre en claro (crema y dorado); el oscuro queda como "Modo noche" (el boton de arriba). Quien ya eligio un tema lo conserva.
#  - Cuatro pestanas: Mapa y Familia (es lo primero que se ve al entrar), Mis Equipos (los dispositivos, las pulseras y los articulos),
#    Evidencias (la ultima y el historial juntos) y Cuenta. Desaparecen la pestana Inicio y los cinco contadores: cada cosa queda en su
#    pestana. "Actualizar" y el estado de la cuenta siguen arriba. En una pantalla ancha las pestanas van arriba, en el medio.
#  - Lo que explica cada boton de un equipo se despliega con un "?" (en el celular no hay mouse para "pasar por encima").
# Ninguna funcion se saca ni cambia. Va en la carpeta del PANEL (la que tiene wrangler.toml). Toca src\panel-index.html, src\panel-app.txt,
# src\panel-mapa.txt y src\panel-explanations.css. Respaldo .bak-pestanas. Al final publica el panel solo.
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
foreach ($f in @("src\panel-index.html", "src\panel-app.txt", "src\panel-mapa.txt", "src\panel-explanations.css")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\panel-index.html")).texto 'id="tab-evidence-count"') -ne 0) { Avi "Las cuatro pestanas ya estaban aplicadas. No toco nada."; return }
$cambios = @(
    @('src\panel-index.html', 'tema: claro por defecto (comentario)', '/* Tema: oscuro por defecto; claro solo si la persona lo eligio con el boton. */', '/* Tema: claro por defecto; oscuro ("Modo noche") solo si la persona lo eligio con el boton. */'),
    @('src\panel-index.html', 'tema: claro por defecto (lectura)', 'function guardado() { try { return localStorage.getItem(CLAVE) === "claro" ? "claro" : "oscuro"; } catch (e) { return "oscuro"; } }', 'function guardado() { try { return localStorage.getItem(CLAVE) === "oscuro" ? "oscuro" : "claro"; } catch (e) { return "claro"; } }'),
    @('src\panel-index.html', 'tema: texto del boton', 'boton.textContent = claro ? "Fondo oscuro" : "Fondo blanco";', 'boton.textContent = claro ? "Modo noche" : "Modo claro";'),
    @('src\panel-index.html', 'tema: boton de la barra', '<button id="theme-toggle" class="ghost" type="button" aria-pressed="false" aria-label="Cambiar entre fondo oscuro y fondo blanco">Fondo blanco</button>', '<button id="theme-toggle" class="ghost" type="button" aria-pressed="false" aria-label="Cambiar entre modo claro y modo noche">Modo noche</button>'),
    @('src\panel-index.html', 'pestanas: cuatro', ('          <button class="bottom-tab active" data-view="home" type="button"><span class="tab-icon" aria-hidden="true">' + [char]0x2302 + '</span><span>Inicio</span></button>
          <button class="bottom-tab" data-view="history" type="button"><span class="tab-icon" aria-hidden="true">' + [char]0x25f7 + '</span><span>Historial</span></button>
          <button class="bottom-tab" data-view="devices" type="button"><span class="tab-icon" aria-hidden="true">' + [char]0x25af + '</span><span>Dispositivos</span></button>
          <button class="bottom-tab" data-view="watches" type="button"><span class="tab-icon" aria-hidden="true">' + [char]0x2665 + '</span><span>Pulseras</span></button>
          <button class="bottom-tab" data-view="account" type="button"><span class="tab-icon" aria-hidden="true">' + [char]0x25cb + '</span><span>Cuenta</span></button>'), ('          <button class="bottom-tab" data-mapa-tab type="button"><span class="tab-icon" aria-hidden="true">' + [char]0x25ce + '</span><span>Mapa y Familia</span></button>
          <button class="bottom-tab" data-view="devices" type="button"><span class="tab-icon" aria-hidden="true">' + [char]0x25af + '</span><span>Mis Equipos</span></button>
          <button class="bottom-tab" data-view="history" type="button"><span class="tab-icon" aria-hidden="true">' + [char]0x25f7 + '</span><span>Evidencias<span id="tab-evidence-count"></span></span></button>
          <button class="bottom-tab" data-view="account" type="button"><span class="tab-icon" aria-hidden="true">' + [char]0x25cb + '</span><span>Cuenta</span></button>')),
    @('src\panel-index.html', 'los cinco contadores ya no se muestran', '<nav class="summary-grid" aria-label="Resumen de la cuenta" data-views="home">', '<nav class="summary-grid" aria-label="Resumen de la cuenta" data-views="ninguna">'),
    @('src\panel-index.html', 'Evidencias: una sola pantalla', '<section id="evidence" class="dashboard-section" data-views="home,history">', '<section id="evidence" class="dashboard-section" data-views="history">'),
    @('src\panel-index.html', 'Pulseras: dentro de Mis Equipos', '<section id="watches" class="dashboard-section" data-views="watches">', '<section id="watches" class="dashboard-section" data-views="devices">'),
    @('src\panel-index.html', 'Mis Equipos: titulo', '<h2>Mis dispositivos</h2>', '<h2>Mis equipos</h2>'),
    @('src\panel-app.txt', 'vista inicial: Mis Equipos', 'let currentEvidence = [], historyExpanded = false, currentView = "home";', 'let currentEvidence = [], historyExpanded = false, currentView = "devices";'),
    @('src\panel-app.txt', 'vistas validas: Inicio pasa a Mis Equipos', '  currentView = ["home", "history", "devices", "watches", "account"].includes(view) ? view : "home";', '  const destino = view === "home" || view === "watches" ? "devices" : view;
  currentView = ["history", "devices", "account"].includes(destino) ? destino : "devices";'),
    @('src\panel-app.txt', 'Evidencias: titulo y texto', ('  $("#evidence-title").textContent = inHistory ? "Historial de evidencias" : "' + [char]0x00da + 'ltima evidencia";
  $("#evidence-copy").textContent = inHistory ? "Revis' + [char]0x00e1 + ' las evidencias anteriores, ordenadas desde la m' + [char]0x00e1 + 's reciente." : "La evidencia m' + [char]0x00e1 + 's reciente queda visible. Las anteriores se guardan en Historial.";'), ('  $("#evidence-title").textContent = "Evidencias";
  $("#evidence-copy").textContent = "La m' + [char]0x00e1 + 's reciente arriba; las anteriores, debajo.";')),
    @('src\panel-app.txt', 'pestana Evidencias: cantidad', '  renderDevices(devices); renderList($("#people-root")', '  { const cuantas = $("#tab-evidence-count"); if (cuantas) cuantas.textContent = evidence.length ? ` (${evidence.length})` : ""; }
  renderDevices(devices); renderList($("#people-root")'),
    @('src\panel-app.txt', 'explicaciones de los botones en un ?', '      applyActionPairStyles(card, device.id);
    }
    devicesRoot.append(card);', '      applyActionPairStyles(card, device.id);
    }
    agregarAyudas(card);
    devicesRoot.append(card);'),
    @('src\panel-app.txt', 'funcion de las ayudas', 'async function approveDevice(device, button, steppedUp = false) {', ('// Lo que explica cada boton se despliega con el "?": en el celular no hay mouse para "pasar por encima".
function agregarAyudas(card) {
  for (const caja of card.querySelectorAll(".actions > div")) {
    const explicacion = caja.querySelector("small");
    if (!explicacion || caja.querySelector(".hint")) continue;
    const ayuda = document.createElement("button");
    ayuda.type = "button"; ayuda.className = "hint"; ayuda.textContent = "?";
    ayuda.setAttribute("aria-label", "' + [char]0x00bf + 'Qu' + [char]0x00e9 + ' hace este bot' + [char]0x00f3 + 'n?"); ayuda.setAttribute("aria-expanded", "false");
    ayuda.addEventListener("click", () => { const abierta = caja.classList.toggle("hint-open"); ayuda.setAttribute("aria-expanded", abierta ? "true" : "false"); });
    caja.append(ayuda);
  }
}

async function approveDevice(device, button, steppedUp = false) {')),
    @('src\panel-mapa.txt', 'pestana Mapa: usa la que trae la barra', ('  if (!barra || $("[data-mapa-tab]", barra)) return;
  const boton = document.createElement("button");
  boton.type = "button";
  boton.className = "bottom-tab";
  boton.setAttribute("data-mapa-tab", "");
  boton.innerHTML = ''<span class="tab-icon" aria-hidden="true">' + [char]0x25ce + '</span><span>Mapa</span>'';
  const inicio = $(''[data-view="home"]'', barra);
  inicio ? inicio.after(boton) : barra.prepend(boton);
  barra.classList.add("ogm-con-mapa");'), ('  if (!barra || barra.dataset.mapaListo) return;
  barra.dataset.mapaListo = "1";
  let boton = $("[data-mapa-tab]", barra);
  if (!boton) {
    // Barra sin pestana de Mapa (versiones anteriores): se arma aca, como antes.
    boton = document.createElement("button");
    boton.type = "button";
    boton.className = "bottom-tab";
    boton.setAttribute("data-mapa-tab", "");
    boton.innerHTML = ''<span class="tab-icon" aria-hidden="true">' + [char]0x25ce + '</span><span>Mapa</span>'';
    const inicio = $(''[data-view="home"]'', barra);
    inicio ? inicio.after(boton) : barra.prepend(boton);
  }
  barra.classList.add("ogm-con-mapa");')),
    @('src\panel-mapa.txt', 'mapa: se abre solo al entrar al panel', 'function iniciar() {
  agregarPestana();', 'function iniciar() {
  agregarPestana();
  // Al entrar al panel, lo primero que se ve es el mapa con la familia.
  const tablero = $("#dashboard");
  const abrirAlEntrar = () => {
    if (estado.abrioAlEntrar || estado.abierto || !tablero || tablero.classList.contains("hidden")) return;
    estado.abrioAlEntrar = true;
    abrir();
  };
  if (tablero) {
    new MutationObserver(abrirAlEntrar).observe(tablero, { attributes: true, attributeFilter: ["class"] });
    abrirAlEntrar();
  }'),
    @('src\panel-explanations.css', 'estilos del paso 1', '.section-copy {
  margin: 0.45rem 0 0;
}
', '.section-copy {
  margin: 0.45rem 0 0;
}

/* ---- Cuatro pestanas: Mapa y Familia, Mis Equipos, Evidencias, Cuenta ---- */
nav.bottom-tabs,
nav.bottom-tabs.ogm-con-mapa {
  grid-template-columns: repeat(4, minmax(0, 1fr));
}

/* El titulo grande de la cuenta ya no se repite: queda el correo, el estado y "Actualizar" en una fila. */
.dashboard-title { padding: 6px 0 16px; }
.dashboard-title .eyebrow,
.dashboard-title h1 { display: none; }
#account-email { margin: 0; font-size: 0.95rem; }

/* "?" que despliega lo que hace cada boton (antes eran textos siempre a la vista). */
.actions > div { position: relative; }
.actions small { display: none; }
.actions > div.hint-open small { display: block; }
.actions .hint {
  position: absolute;
  top: 7px;
  right: 8px;
  width: 26px;
  height: 26px;
  padding: 0;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.55);
  color: #111;
  border: 1px solid rgba(0, 0, 0, 0.25);
  font-size: 0.8rem;
  line-height: 1;
}
.actions .hint:hover { transform: none; }
.actions button[data-command] { padding-right: 40px; padding-left: 40px; }

/* Botones en pastilla (como el dibujo de la consola). */
.actions button[data-command],
.map-button { border-radius: 999px; }

/* En una pantalla ancha las pestanas van arriba, en el medio de la barra, y el mapa deja ver esa barra. */
@media (min-width: 1280px) {
  nav.bottom-tabs {
    top: 12px;
    bottom: auto;
    width: min(520px, calc(100% - 700px));
    padding: 5px;
    border-radius: 999px;
  }
  nav.bottom-tabs .bottom-tab { display: flex; justify-content: center; border-radius: 999px; font-size: 0.84rem; padding: 10px 6px; white-space: nowrap; }
  nav.bottom-tabs .tab-icon { display: none; }
  #og-mapa.ogm { top: 78px; height: calc(100vh - 78px); height: calc(100dvh - 78px); }
  .shell { padding-bottom: 40px; }
  footer { margin-bottom: 20px; }
}
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
    if (Test-Path ($ruta + ".bak-pestanas")) { Mal ("Ya existe " + $t + ".bak-pestanas. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-pestanas"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-pestanas): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-pestanas") -Destination $ruta -Force }
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
