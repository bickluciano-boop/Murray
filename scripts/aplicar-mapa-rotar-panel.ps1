# aplicar-mapa-rotar-panel.ps1 - Rotar el mapa con dos dedos (mapa vectorial de Google con el Map ID de Ojo Guard).
# Luciano (16/10/2026): "lo que no te deja es si lo queres rotar". El mapa era "raster" (no gira); ahora usa el Map ID creado en Google Cloud
# (proyecto ojo-guard, vector con rotacion). Cambios:
#  - El mapa se crea con mapId y vectorial; se gira con dos dedos (el movimiento y el zoom siguen igual). El estilo claro/noche pasa a ser el de
#    Google (colorScheme) porque con Map ID el "styles" del codigo no vale.
#  - Una brujula chica (junto al boton Mapa/Satelite) aparece cuando el mapa esta girado y lo vuelve a poner con el norte arriba.
#  - El enfoque de la persona (que la deja arriba de la tarjeta) cuenta el giro del mapa.
# En Satelite el mapa no gira (limite de Google: solo con imagenes a 45 grados). Si algo sale mal se vuelve atras copiando los .bak-rotar.
# Requiere aplicar-mapa-enfocar-panel.ps1. Va en la carpeta del PANEL (la que tiene wrangler.toml). Toca src\panel-mapa.txt y
# src\panel-explanations.css. Respaldo .bak-rotar. Al final publica el panel solo. No hace falta build: se ve al cerrar y abrir la app.
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
if ((Contar $mapaTexto 'heading_changed') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $mapaTexto 'proy.fromLatLngToPoint(destino)') -ne 1) { Mal "Falta aplicar antes aplicar-mapa-enfocar-panel.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\panel-explanations.css")).texto '/* Botones en pastilla (como el dibujo de la consola). */') -ne 1) { Mal "Falta aplicar antes los pasos de la consola (pestanas, ayudas, equipos)."; return }
$cambios = @(
    @('src\panel-mapa.txt', 'rotar: mapa vectorial con Map ID', '    clickableIcons: false,
    styles: temaInicial === "claro" ? ESTILO_CLARO : ESTILO_OSCURO,', '    clickableIcons: false,
    // Mapa vectorial (con el Map ID de Ojo Guard): se gira con dos dedos. Con Map ID el "styles" del codigo no vale: el modo claro o noche lo pone Google.
    mapId: "1b7239dd38bbcc4a7271dd0d",
    renderingType: g.RenderingType?.VECTOR,
    headingInteractionEnabled: true,
    tiltInteractionEnabled: false,
    colorScheme: temaInicial === "claro" ? g.ColorScheme?.LIGHT : g.ColorScheme?.DARK,'),
    @('src\panel-mapa.txt', 'rotar: modo claro o noche con colorScheme', '    tema(nombre) { mapa.setOptions({ styles: nombre === "claro" ? ESTILO_CLARO : ESTILO_OSCURO, backgroundColor: nombre === "claro" ? "#f2efe9" : "#16181c" }); },', '    tema(nombre) { mapa.setOptions({ colorScheme: nombre === "claro" ? g.ColorScheme?.LIGHT : g.ColorScheme?.DARK, backgroundColor: nombre === "claro" ? "#f2efe9" : "#16181c" }); },'),
    @('src\panel-mapa.txt', 'rotar: el enfoque cuenta el giro', '          const p = proy.fromLatLngToPoint(destino);
          destino = proy.fromPointToLatLng(new g.Point(p.x, p.y + tapa / 2 / escala));', '          // Con el mapa girado, "arriba de la pantalla" no es el norte: el desplazamiento se gira igual que el mapa.
          const giro = ((mapa.getHeading() || 0) * Math.PI) / 180;
          const mueve = tapa / 2 / escala;
          const p = proy.fromLatLngToPoint(destino);
          destino = proy.fromPointToLatLng(new g.Point(p.x - Math.sin(giro) * mueve, p.y + Math.cos(giro) * mueve));'),
    @('src\panel-mapa.txt', 'rotar: brujula para volver al norte', '  const pos = (p) => new g.LatLng(p.lat, p.lng);
  return {', '  const pos = (p) => new g.LatLng(p.lat, p.lng);
  // Brujula: aparece cuando el mapa esta girado (con dos dedos) y al tocarla vuelve a mirar al norte.
  const brujula = document.createElement("button");
  brujula.type = "button";
  brujula.className = "ogm-brujula hidden";
  brujula.title = "Volver al norte";
  brujula.setAttribute("aria-label", "Volver al norte");
  brujula.innerHTML = ''<svg viewBox="0 0 24 24" width="22" height="22" aria-hidden="true"><path d="M12 2.5l4 9.5H8z" fill="#e0806a"/><path d="M12 21.5l-4-9.5h8z" fill="currentColor" opacity="0.5"/></svg>'';
  brujula.addEventListener("click", () => mapa.setHeading(0));
  ($(".ogm-capas") || $("#og-mapa") || contenedor.parentElement || document.body).appendChild(brujula);
  mapa.addListener("heading_changed", () => {
    const giro = mapa.getHeading() || 0;
    brujula.classList.toggle("hidden", Math.abs(giro) < 0.5 || Math.abs(giro) > 359.5);
    brujula.firstElementChild.style.transform = `rotate(${-giro}deg)`;
  });
  return {'),
    @('src\panel-explanations.css', 'mapa: brujula', '/* Botones en pastilla (como el dibujo de la consola). */', '/* Brujula del mapa: aparece al girar el mapa con dos dedos y lo vuelve a poner con el norte arriba (va junto al boton Mapa/Satelite). */
#og-mapa .ogm-capas .ogm-brujula { display: grid; place-items: center; width: 34px; height: 34px; padding: 0; color: var(--ogm-texto); }
#og-mapa .ogm-capas .ogm-brujula.hidden { display: none; }
#og-mapa .ogm-capas .ogm-brujula svg { transition: transform 0.15s linear; }

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
    if (Test-Path ($ruta + ".bak-rotar")) { Mal ("Ya existe " + $t + ".bak-rotar. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-rotar"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-rotar): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-rotar") -Destination $ruta -Force }
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
Ok "LISTO: el panel quedo publicado. Cerra la app y abrila de nuevo: el mapa se gira con dos dedos y aparece una brujula para volver al norte."
Write-Host ""
