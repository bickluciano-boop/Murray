# aplicar-mapa-iconos-panel.ps1 - El mapa: cada equipo con el dibujo de lo que es (celular, compu, reloj) en vez de dos letras.
# Pedido de Luciano (16/10/2026): "tomaria el ejemplo de Buscar de Apple para el redondel, o poner el dibujo del dispositivo o la opcion de poder
# editar el circulo, porque al tomar las dos iniciales no queda muy claro".
#  - Los equipos (celular, compu, reloj/pulsera) llevan el dibujo en el circulo, en el mapa, en la lista y en la tarjeta. Las personas llevan una sola
#    inicial (antes "LB iPhone" decia "LI"). Si le pusiste una foto a un equipo (el lapiz del circulo), la foto va por encima como siempre.
#  - Tarjeta de la app: los botones no se estiran cuando son pocos (en una persona adulta quedaba "Como llegar" enorme), el estado puede ocupar dos
#    renglones (se cortaba) y no se repite "Android" despues del nombre (ya lo dice el dibujo).
# Cambia el mapa de la consola de siempre (los dibujos), no solo el de la app. Requiere aplicar-mapa-app-sumar-panel.ps1. Va en la carpeta del PANEL
# (la que tiene wrangler.toml). Toca src\panel-mapa.txt y src\panel-explanations.css. Respaldo .bak-iconos. Al final publica el panel solo.
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
if ((Contar $mapaTexto 'function dibujoDe') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $mapaTexto 'ogm-corto') -eq 0) { Mal "Falta aplicar antes aplicar-mapa-app-sumar-panel.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\panel-explanations.css")).texto '/* Botones en pastilla (como el dibujo de la consola). */') -ne 1) { Mal "Falta aplicar antes los pasos de la consola (pestanas, ayudas, equipos)."; return }
$cambios = @(
    @('src\panel-mapa.txt', 'avatares: dibujo del equipo en vez de dos letras', 'function avatarHtml(equipo, clase = "") {
  const foto = urlFoto(equipo);
  return `<span class="ogm-av ${clase}"><span>${esc(iniciales(equipo.nombre))}</span>${foto ? `<img src="${foto}" alt="" onerror="this.remove()">` : ""}</span>`;
}', 'const DIBUJO_CELULAR = ''<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="7" y="2.5" width="10" height="19" rx="2.6"/><path d="M10.5 18.2h3"/></svg>'';
const DIBUJO_COMPU = ''<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="4.5" y="5" width="15" height="10.5" rx="1.8"/><path d="M2.5 19h19"/></svg>'';
const DIBUJO_RELOJ = ''<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="7.5" y="7" width="9" height="10" rx="2.8"/><path d="M9.4 7l.7-4h3.8l.7 4M9.4 17l.7 4h3.8l.7-4"/></svg>'';

/** El dibujo de lo que es el equipo (celular, compu, reloj o pulsera); las personas llevan su inicial. Si tiene foto, la foto va encima. */
function dibujoDe(equipo) {
  if (equipo.tipo === "persona") return "";
  const texto = `${equipo.plataforma} ${equipo.nombre}`;
  if (equipo.tipo === "pulsera" || /reloj|watch|pulsera/i.test(texto)) return DIBUJO_RELOJ;
  if (/windows|mac ?os|macbook|linux|computadora|notebook|\bpc\b/i.test(texto)) return DIBUJO_COMPU;
  return DIBUJO_CELULAR;
}

function avatarHtml(equipo, clase = "") {
  const foto = urlFoto(equipo);
  const dibujo = dibujoDe(equipo);
  // Una persona: una sola letra (con dos, "LB iPhone" decia "LI" y no se entendia).
  const letras = equipo.tipo === "persona" ? iniciales(equipo.nombre).charAt(0) : iniciales(equipo.nombre);
  return `<span class="ogm-av ${clase}${dibujo ? " ogm-av-dibujo" : ""}"><span>${dibujo || esc(letras)}</span>${foto ? `<img src="${foto}" alt="" onerror="this.remove()">` : ""}</span>`;
}'),
    @('src\panel-explanations.css', 'mapa: dibujos de equipos y tarjeta de la app mas prolija', '/* Botones en pastilla (como el dibujo de la consola). */', '/* El dibujo del equipo (celular, compu, reloj) dentro del circulo, en vez de dos letras. */
.ogm-av-dibujo > span { display: grid; place-items: center; width: 56%; height: 56%; }
.ogm-av-dibujo svg { width: 100%; height: 100%; fill: none; stroke: currentColor; stroke-width: 1.7; stroke-linecap: round; stroke-linejoin: round; }
.ogm-av-dibujo.mini > span { width: 62%; height: 62%; }

/* Tarjeta de la app: los botones no se estiran cuando son pocos (siempre el ancho de uno de cinco), el estado puede ocupar dos renglones y no se
   repite la marca del equipo (la dice el dibujo). */
@media (max-width: 899px) {
  html.app-mapa #og-mapa .ogm-tile { flex: 0 0 calc((100% - 20px) / 5); }
  html.app-mapa #og-mapa .ogm-cab-app small:not(.ogm-donde) { white-space: normal; }
  html.app-mapa #og-mapa .ogm-nom .ogm-marca { display: none; }
}

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
    if (Test-Path ($ruta + ".bak-iconos")) { Mal ("Ya existe " + $t + ".bak-iconos. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-iconos"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-iconos): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-iconos") -Destination $ruta -Force }
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
Ok "LISTO: el panel quedo publicado. Cerra la app y abrila de nuevo: los equipos tienen su dibujo."
Write-Host ""
