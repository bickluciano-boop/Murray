# aplicar-mapa-evidencia-panel.ps1 - La evidencia de un equipo se ve en su tarjeta del mapa de la app.
# Pregunta de Luciano (16/10/2026): pidio evidencia a la notebook, la notebook saco la foto, y en Ajustes no habia nada. Es asi: Ajustes > Fotos de
# Intrusos muestra los intentos de ESTE telefono; lo que sacan otros equipos queda en la pestana Evidencias del panel (y llega por mail).
#  - Ahora, en el mapa de la app, la tarjeta de cada equipo trae "Ultima evidencia": la foto (un toque la agranda sobre el mapa, otro la cierra) y el
#    audio con su reproductor. Al pedir evidencia, cuando llega, la tarjeta baja sola hasta ella.
#  - La tarjeta ya no vuelve arriba cada vez que se actualiza (cada pocos segundos): queda donde la dejaste.
# La pestana Evidencias del panel sigue igual. Requiere aplicar-mapa-app-sumar-panel.ps1. Va en la carpeta del PANEL (la que tiene wrangler.toml).
# Toca src\panel-mapa.txt y src\panel-explanations.css. Respaldo .bak-evidencia. Al final publica el panel solo.
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
foreach ($f in @("src\panel-mapa.txt", "src\panel-explanations.css")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
$mapaTexto = (Leer (Join-Path $raiz "src\panel-mapa.txt")).texto
if ((Contar $mapaTexto 'function htmlEvidenciaApp') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $mapaTexto 'ogm-corto') -eq 0) { Mal "Falta aplicar antes aplicar-mapa-app-sumar-panel.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\panel-explanations.css")).texto '/* Botones en pastilla (como el dibujo de la consola). */') -ne 1) { Mal "Falta aplicar antes los pasos de la consola (pestanas, ayudas, equipos)."; return }
$cambios = @(
    @('src\panel-mapa.txt', 'evidencia: guardar las que ya hay en la cuenta', '  if (!cuenta.authenticated) throw Object.assign(new Error("sin_sesion"), { status: 401 });
  const equipos = normalizarEquipos(cuenta);', '  if (!cuenta.authenticated) throw Object.assign(new Error("sin_sesion"), { status: 401 });
  // La evidencia que sacaron los equipos (la misma de la pestana Evidencias): la tarjeta de cada equipo muestra la ultima.
  estado.evidencias = Array.isArray(cuenta.evidence) ? cuenta.evidence : [];
  const equipos = normalizarEquipos(cuenta);'),
    @('src\panel-mapa.txt', 'evidencia: la ultima en la tarjeta y la foto en grande', 'function htmlEvidencia(ev, equipo) {', ('/** Dentro de la app: la evidencia de ese equipo (la que acaba de llegar o la ultima guardada), con la foto que se agranda ahi mismo y el audio. */
function htmlEvidenciaApp(e) {
  const nueva = estado.evidencia?.id === e.id ? estado.evidencia : null;
  const guardada = (estado.evidencias || [])
    .filter((x) => x.frontUrl && (x.deviceId === e.id || (!x.deviceId && x.device === e.nombre)))
    .sort((a, b) => new Date(b.occurredAt) - new Date(a.occurredAt))[0];
  const ev = nueva ? { front: nueva.front, audio: nueva.audio, en: nueva.en } : guardada ? { front: guardada.frontUrl, audio: guardada.audioUrl, en: guardada.occurredAt } : null;
  if (!ev || !ev.front) return "";
  return `<div class="ogm-evidencia ogm-ultima">
    <button type="button" class="ogm-ev-foto" data-accion="ampliar" data-url="${esc(ev.front)}" aria-label="Ver la foto en grande"><img src="${esc(ev.front)}" alt="Foto de ${esc(e.nombre)}"></button>
    <div><strong>' + [char]0x00da + 'ltima evidencia</strong><small>${esc(haceCuanto(ev.en))} ' + [char]0x00b7 + ' tambi' + [char]0x00e9 + 'n en Evidencias del panel</small>${ev.audio ? `<audio controls preload="none" src="${esc(ev.audio)}"></audio>` : ""}</div>
  </div>`;
}

/** La foto se agranda sobre el mapa (un enlace la abriria en la misma pantalla y se perderia el mapa). Un toque la cierra. */
function ampliarFoto(url) {
  const raiz = $("#og-mapa");
  if (!raiz || !url) return;
  const visor = document.createElement("button");
  visor.type = "button";
  visor.className = "ogm-visor";
  visor.dataset.accion = "cerrar-visor";
  visor.setAttribute("aria-label", "Cerrar la foto");
  const img = document.createElement("img");
  img.src = url;
  img.alt = "Foto de la evidencia";
  visor.append(img);
  raiz.append(visor);
}

function htmlEvidencia(ev, equipo) {')),
    @('src\panel-mapa.txt', 'evidencia: acciones de ampliar y cerrar la foto', '    if (accion === "soltar") return soltar();', '    if (accion === "ampliar") return ampliarFoto(boton.dataset.url);
    if (accion === "cerrar-visor") return boton.remove();
    if (accion === "soltar") return soltar();'),
    @('src\panel-mapa.txt', 'evidencia: la tarjeta de la app muestra la ultima evidencia', '    ${estado.evidencia?.id === e.id ? htmlEvidencia(estado.evidencia, e) : ""}', '    ${htmlEvidenciaApp(e)}'),
    @('src\panel-mapa.txt', 'evidencia: al llegar, se actualiza la tarjeta', ('        avisar(c.evidence ? "Llegaron la foto y el audio. Tambi' + [char]0x00e9 + 'n te los mandamos por mail." : esPersona(equipo.id) ? "El tel' + [char]0x00e9 + 'fono sac' + [char]0x00f3 + ' la foto y el audio. Te llegan por mail." : "El tel' + [char]0x00e9 + 'fono sac' + [char]0x00f3 + ' la foto y el audio. Quedan en Evidencias y te llegan por mail.");'), ('        if (!esPersona(equipo.id)) { await refrescar(true); estado.verEvidencia = true; }
        avisar(c.evidence ? "Llegaron la foto y el audio. Tambi' + [char]0x00e9 + 'n te los mandamos por mail." : esPersona(equipo.id) ? "El tel' + [char]0x00e9 + 'fono sac' + [char]0x00f3 + ' la foto y el audio. Te llegan por mail." : "Lleg' + [char]0x00f3 + ' la evidencia: abajo, en ' + [char]0x00ab + '' + [char]0x00da + 'ltima evidencia' + [char]0x00bb + ' (si todav' + [char]0x00ed + 'a no aparece, est' + [char]0x00e1 + ' en Evidencias del panel). Tambi' + [char]0x00e9 + 'n te llega por mail.");')),
    @('src\panel-mapa.txt', 'tarjeta: no volver arriba cada vez que se redibuja', '  tarjeta.classList.remove("hidden");
  tarjeta.innerHTML = EN_APP ? htmlTarjetaApp(', '  tarjeta.classList.remove("hidden");
  // La tarjeta se redibuja cada pocos segundos: se conserva lo desplazado (y, cuando llega una evidencia, se baja hasta ella).
  const desplazado = tarjeta.scrollTop;
  queueMicrotask(() => {
    const ultima = estado.verEvidencia ? tarjeta.querySelector(".ogm-ultima") : null;
    tarjeta.scrollTop = ultima ? Math.max(0, ultima.offsetTop - 8) : desplazado;
    if (ultima) estado.verEvidencia = false;
  });
  tarjeta.innerHTML = EN_APP ? htmlTarjetaApp('),
    @('src\panel-explanations.css', 'mapa: foto de la evidencia en grande y audio', '/* Botones en pastilla (como el dibujo de la consola). */', '/* La ultima evidencia de un equipo, en su tarjeta: miniatura (se agranda sobre el mapa) y audio. */
#og-mapa .ogm-ev-foto { flex: none; border-radius: 10px; }
#og-mapa .ogm-ultima audio { width: 100%; height: 34px; margin-top: 4px; }
#og-mapa .ogm-visor { position: absolute; inset: 0; z-index: 12; display: grid; place-items: center; padding: 12px; background: rgba(0, 0, 0, 0.9); }
#og-mapa .ogm-visor img { display: block; max-width: 100%; max-height: 100%; border-radius: 12px; object-fit: contain; }

/* Botones en pastilla (como el dibujo de la consola). */')
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
    if (Test-Path ($ruta + ".bak-evidencia")) { Mal ("Ya existe " + $t + ".bak-evidencia. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-evidencia"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-evidencia): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-evidencia") -Destination $ruta -Force }
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
Ok "LISTO: el panel quedo publicado. Cerra la app y abrila de nuevo: la tarjeta de cada equipo muestra su ultima evidencia."
Write-Host ""
