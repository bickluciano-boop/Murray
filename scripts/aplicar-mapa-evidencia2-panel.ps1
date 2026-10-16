# aplicar-mapa-evidencia2-panel.ps1 - Evidencia en la tarjeta del mapa: tambien la camara trasera y el audio con un boton.
# Foto de Luciano (16/10/2026): "esta mostrando solo la delantera y el audio no sale".
#  - Se ven las dos fotos (Delantera y Trasera) cuando el equipo saco las dos; un toque agranda la que toques.
#  - El audio ya no es el reproductor directo (en la app no sonaba): ahora hay un boton "Escuchar el audio" que lo baja y lo reproduce. Si no se puede,
#    lo dice ("El audio llego vacio" o "No se pudo reproducir aca") y el audio sigue en Evidencias del panel.
# Requiere aplicar-mapa-evidencia-panel.ps1. Va en la carpeta del PANEL (la que tiene wrangler.toml). Toca src\panel-mapa.txt y
# src\panel-explanations.css. Respaldo .bak-evidencia2. Al final publica el panel solo.
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
if ((Contar $mapaTexto 'function escucharAudio') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $mapaTexto 'function htmlEvidenciaApp') -eq 0) { Mal "Falta aplicar antes aplicar-mapa-evidencia-panel.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\panel-explanations.css")).texto '/* Botones en pastilla (como el dibujo de la consola). */') -ne 1) { Mal "Falta aplicar antes los pasos de la consola (pestanas, ayudas, equipos)."; return }
$cambios = @(
    @('src\panel-mapa.txt', 'evidencia: tambien la trasera', '  const ev = nueva ? { front: nueva.front, audio: nueva.audio, en: nueva.en } : guardada ? { front: guardada.frontUrl, audio: guardada.audioUrl, en: guardada.occurredAt } : null;', '  const ev = nueva ? { front: nueva.front, audio: nueva.audio, en: nueva.en } : guardada ? { front: guardada.frontUrl, rear: guardada.rearUrl, audio: guardada.audioUrl, en: guardada.occurredAt } : null;'),
    @('src\panel-mapa.txt', 'evidencia: fotos delantera y trasera y boton para escuchar', ('  return `<div class="ogm-evidencia ogm-ultima">
    <button type="button" class="ogm-ev-foto" data-accion="ampliar" data-url="${esc(ev.front)}" aria-label="Ver la foto en grande"><img src="${esc(ev.front)}" alt="Foto de ${esc(e.nombre)}"></button>
    <div><strong>' + [char]0x00da + 'ltima evidencia</strong><small>${esc(haceCuanto(ev.en))} ' + [char]0x00b7 + ' tambi' + [char]0x00e9 + 'n en Evidencias del panel</small>${ev.audio ? `<audio controls preload="none" src="${esc(ev.audio)}"></audio>` : ""}</div>
  </div>`;'), ('  const foto = (url, nombre) => `<button type="button" class="ogm-ev-foto" data-accion="ampliar" data-url="${esc(url)}" aria-label="Ver la foto ${nombre} en grande"><img src="${esc(url)}" alt="Foto ${nombre} de ${esc(e.nombre)}"><small>${nombre}</small></button>`;
  return `<div class="ogm-evidencia ogm-ultima">
    <div class="ogm-fotos">${foto(ev.front, "Delantera")}${ev.rear ? foto(ev.rear, "Trasera") : ""}</div>
    <div><strong>' + [char]0x00da + 'ltima evidencia</strong><small>${esc(haceCuanto(ev.en))} ' + [char]0x00b7 + ' tambi' + [char]0x00e9 + 'n en Evidencias del panel</small>${ev.audio ? `<button type="button" class="ogm-escuchar" data-accion="escuchar" data-url="${esc(ev.audio)}">' + [char]0x25b6 + ' Escuchar el audio</button>` : ""}</div>
  </div>`;')),
    @('src\panel-mapa.txt', 'evidencia: escuchar el audio dentro de la app', '/** La foto se agranda sobre el mapa', ('/**
 * El audio se baja y se reproduce desde la memoria (en la app el reproductor directo no sonaba: el visor de la app no pedia el audio por partes como
 * un navegador). Si algo falla, lo dice, y el audio sigue en Evidencias del panel.
 */
async function escucharAudio(boton) {
  const url = boton.dataset.url;
  if (!url || boton.disabled) return;
  boton.disabled = true;
  boton.textContent = "Cargando el audio' + [char]0x2026 + '";
  try {
    const respuesta = await fetch(url, { credentials: "same-origin" });
    if (!respuesta.ok) throw new Error(`audio_${respuesta.status}`);
    const datos = await respuesta.blob();
    if (!datos.size) throw new Error("audio_vacio");
    // Si el servidor no dice que clase de audio es, se mira como empieza el archivo.
    const cabeza = new Uint8Array(await datos.slice(0, 12).arrayBuffer());
    const texto = (desde, hasta) => String.fromCharCode(...cabeza.slice(desde, hasta));
    let tipo = datos.type && datos.type !== "application/octet-stream" ? datos.type : "";
    if (!tipo) {
      if (texto(0, 4) === "RIFF") tipo = "audio/wav";
      else if (texto(0, 4) === "OggS") tipo = "audio/ogg";
      else if (texto(0, 3) === "ID3" || (cabeza[0] === 0xff && (cabeza[1] & 0xe0) === 0xe0)) tipo = "audio/mpeg";
      else if (texto(4, 8) === "ftyp") tipo = "audio/mp4";
      else if (cabeza[0] === 0x1a && cabeza[1] === 0x45) tipo = "audio/webm";
      else if (texto(0, 5) === "#!AMR") tipo = "audio/amr";
    }
    const audio = document.createElement("audio");
    audio.controls = true;
    audio.preload = "auto";
    audio.src = URL.createObjectURL(tipo ? new Blob([datos], { type: tipo }) : datos);
    audio.addEventListener("error", () => {
      boton.disabled = false;
      boton.textContent = "No se pudo reproducir ac' + [char]0x00e1 + ' ' + [char]0x00b7 + ' reintentar";
      audio.replaceWith(boton);
    });
    boton.replaceWith(audio);
    void audio.play().catch(() => undefined);
  } catch (error) {
    boton.disabled = false;
    boton.textContent = error.message === "audio_vacio" ? "El audio lleg' + [char]0x00f3 + ' vac' + [char]0x00ed + 'o" : "No se pudo cargar el audio ' + [char]0x00b7 + ' reintentar";
  }
}

/** La foto se agranda sobre el mapa')),
    @('src\panel-mapa.txt', 'evidencia: accion escuchar', '    if (accion === "ampliar") return ampliarFoto(boton.dataset.url);', '    if (accion === "escuchar") return escucharAudio(boton);
    if (accion === "ampliar") return ampliarFoto(boton.dataset.url);'),
    @('src\panel-explanations.css', 'mapa: fotos delantera y trasera, boton de audio', '/* Botones en pastilla (como el dibujo de la consola). */', '/* Evidencia en la tarjeta: las dos fotos (delantera y trasera) con su nombre, y el boton para escuchar el audio. */
#og-mapa .ogm-ultima { flex-wrap: wrap; }
#og-mapa .ogm-ultima .ogm-fotos { display: flex; gap: 6px; }
#og-mapa .ogm-ev-foto { position: relative; overflow: hidden; }
#og-mapa .ogm-ev-foto small { position: absolute; left: 0; right: 0; bottom: 0; padding: 1px 0; background: rgba(0, 0, 0, 0.55); color: #fff; font-size: 0.6rem; text-align: center; }
#og-mapa .ogm-escuchar { justify-self: start; margin-top: 4px; padding: 7px 12px; border: 1px solid var(--ogm-oro-borde); border-radius: 999px; background: var(--ogm-oro-fondo); color: var(--ogm-oro-vivo); font-size: 0.8rem; font-weight: 700; }
#og-mapa .ogm-escuchar:disabled { opacity: 0.6; }

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
    if (Test-Path ($ruta + ".bak-evidencia2")) { Mal ("Ya existe " + $t + ".bak-evidencia2. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-evidencia2"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-evidencia2): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-evidencia2") -Destination $ruta -Force }
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
Ok "LISTO: el panel quedo publicado. Cerra la app y abrila de nuevo: la evidencia muestra las dos fotos y el boton del audio."
Write-Host ""
