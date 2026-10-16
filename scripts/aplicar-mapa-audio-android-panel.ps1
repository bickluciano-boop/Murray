# aplicar-mapa-audio-android-panel.ps1 - El audio de la evidencia no sonaba en el Android (en el iPhone si): ahora suena en un reproductor propio.
# Luciano (16/10/2026): "si suena en iphone, no suena en android".
# Causas (probadas en un navegador de prueba):
#  - El reproductor estaba DENTRO de la tarjeta, y la tarjeta se redibuja cada pocos segundos: el reproductor se borraba y el audio se cortaba.
#  - El visor de Android solo deja arrancar un audio dentro del toque, y bajar el archivo tarda unos segundos: el arranque automatico se rechazaba.
# Ahora el audio suena en un reproductor propio, fijo arriba del mapa (con su cruz para cerrarlo), que la tarjeta no toca. En el toque se arranca un
# silencio de una decima de segundo para destrabar el reproductor; despues se cambia por el audio de verdad. Si el visor igual no lo arranca solo,
# dice "Toca el play para escuchar"; si el audio no se puede reproducir, dice el tipo y el tamano para saber por que.
# Requiere aplicar-mapa-evidencia2-panel.ps1. Va en la carpeta del PANEL (la que tiene wrangler.toml). Toca src\panel-mapa.txt y
# src\panel-explanations.css. Respaldo .bak-audioandroid. Al final publica el panel solo. No hace falta build: se ve al cerrar y abrir la app.
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
if ((Contar $mapaTexto 'function reproductorAudio') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $mapaTexto 'function escucharAudio') -ne 1) { Mal "Falta aplicar antes aplicar-mapa-evidencia2-panel.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\panel-explanations.css")).texto '/* Botones en pastilla (como el dibujo de la consola). */') -ne 1) { Mal "Falta aplicar antes los pasos de la consola (pestanas, ayudas, equipos)."; return }
$cambios = @(
    @('src\panel-mapa.txt', 'audio de la evidencia: reproductor propio fuera de la tarjeta', ('/**
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
}'), ('/**
 * El audio de la evidencia suena en un reproductor propio, FUERA de la tarjeta: la tarjeta se redibuja cada pocos segundos y, si el
 * reproductor estaba adentro, se borraba y el audio se cortaba (en el Android no se escuchaba). Ademas el visor del telefono solo deja
 * arrancar un audio dentro del toque y bajar el archivo tarda: en el toque se arranca un silencio y despues se cambia por el audio de verdad.
 * Si algo falla, lo dice, y el audio sigue en Evidencias del panel.
 */
let cargandoAudio = false;

/** Un silencio de una decima de segundo, para "destrabar" el reproductor dentro del toque. */
function silencioWav() {
  const datos = new DataView(new ArrayBuffer(44 + 800));
  const poner = (desde, texto) => { for (let i = 0; i < texto.length; i += 1) datos.setUint8(desde + i, texto.charCodeAt(i)); };
  poner(0, "RIFF"); datos.setUint32(4, 36 + 800, true); poner(8, "WAVEfmt "); datos.setUint32(16, 16, true);
  datos.setUint16(20, 1, true); datos.setUint16(22, 1, true); datos.setUint32(24, 8000, true); datos.setUint32(28, 8000, true);
  datos.setUint16(32, 1, true); datos.setUint16(34, 8, true); poner(36, "data"); datos.setUint32(40, 800, true);
  for (let i = 0; i < 800; i += 1) datos.setUint8(44 + i, 128);
  return new Blob([datos.buffer], { type: "audio/wav" });
}

function reproductorAudio() {
  let caja = $("#ogm-reproductor");
  if (caja) return caja;
  caja = document.createElement("div");
  caja.id = "ogm-reproductor";
  caja.className = "ogm-reproductor hidden";
  caja.innerHTML = `<span class="ogm-repro-texto"></span><button type="button" class="ogm-repro-cerrar" aria-label="Cerrar">&times;</button><audio controls preload="auto" playsinline></audio>`;
  caja.querySelector(".ogm-repro-cerrar").addEventListener("click", () => {
    const sonido = caja.querySelector("audio");
    sonido.onerror = null;
    sonido.pause();
    sonido.removeAttribute("src");
    sonido.load();
    caja.classList.add("hidden");
  });
  ($("#og-mapa") || document.body).appendChild(caja);
  return caja;
}

async function escucharAudio(boton) {
  const url = boton.dataset.url;
  if (!url || cargandoAudio) return;
  cargandoAudio = true;
  const caja = reproductorAudio();
  const audio = caja.querySelector("audio");
  const decir = (mensaje) => { caja.querySelector(".ogm-repro-texto").textContent = mensaje; };
  caja.classList.remove("hidden");
  decir("Cargando el audio' + [char]0x2026 + '");
  let real = false;
  let detalle = "";
  audio.onerror = () => { if (real) decir(`No se pudo reproducir ac' + [char]0x00e1 + '${detalle} ' + [char]0x00b7 + ' cerr' + [char]0x00e1 + ' y prob' + [char]0x00e1 + ' de nuevo`); };
  // Dentro del toque: se arranca el silencio, que deja el reproductor listo para sonar cuando llegue el audio.
  try {
    audio.pause();
    audio.src = URL.createObjectURL(silencioWav());
    void audio.play().catch(() => undefined);
  } catch (falla) {
    // Si no se puede, igual se intenta con el audio de verdad.
  }
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
    detalle = ` (${tipo || "sin tipo"}, ${Math.max(1, Math.round(datos.size / 1024))} KB)`;
    real = true;
    audio.src = URL.createObjectURL(tipo ? new Blob([datos], { type: tipo }) : datos);
    audio.load();
    decir("Audio de la evidencia");
    try {
      await audio.play();
    } catch (falla) {
      // El visor no lo dejo arrancar solo: queda el reproductor para tocar el play (si el audio no se puede reproducir, lo avisa el error de arriba).
      if (!audio.error) decir("Toc' + [char]0x00e1 + ' el play para escuchar");
    }
  } catch (error) {
    decir(error.message === "audio_vacio" ? "El audio lleg' + [char]0x00f3 + ' vac' + [char]0x00ed + 'o" : "No se pudo cargar el audio ' + [char]0x00b7 + ' toc' + [char]0x00e1 + ' Escuchar para reintentar");
  } finally {
    cargandoAudio = false;
  }
}')),
    @('src\panel-explanations.css', 'mapa: reproductor del audio', '/* Botones en pastilla (como el dibujo de la consola). */', '/* Reproductor del audio de la evidencia: queda fuera de la tarjeta (que se redibuja cada pocos segundos y cortaba el audio). */
#og-mapa .ogm-reproductor { position: fixed; z-index: 60; left: 8px; right: 8px; top: 8px; display: grid; grid-template-columns: 1fr auto; align-items: center; gap: 4px 8px; padding: 8px 10px; border: 1px solid var(--ogm-oro-borde); border-radius: 16px; background: var(--ogm-panel); box-shadow: var(--ogm-sombra); }
#og-mapa .ogm-reproductor.hidden { display: none; }
#og-mapa .ogm-repro-texto { color: var(--ogm-texto); font-size: 0.8rem; font-weight: 700; }
#og-mapa .ogm-repro-cerrar { width: 30px; height: 30px; padding: 0; border: 1px solid var(--ogm-linea); border-radius: 999px; background: transparent; color: var(--ogm-suave); font-size: 1.1rem; line-height: 1; }
#og-mapa .ogm-reproductor audio { grid-column: 1 / -1; width: 100%; height: 34px; }

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
    if (Test-Path ($ruta + ".bak-audioandroid")) { Mal ("Ya existe " + $t + ".bak-audioandroid. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-audioandroid"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-audioandroid): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-audioandroid") -Destination $ruta -Force }
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
Ok "LISTO: el panel quedo publicado. Cerra la app y abrila de nuevo: toca Escuchar el audio y suena en un reproductor arriba del mapa."
Write-Host ""
