# aplicar-mapa-app-tarjeta2-panel.ps1 - El mapa dentro de la app, todavia mas chico: lista y tarjeta de abajo mas bajas.
# Pedido de Luciano (16/10/2026) al probar la tarjeta nueva: "el recuadro de los dispositivos ya ocupa la mitad del mapa; si una persona esta lejos,
# por ejemplo en la provincia y vos en capital, cuesta verla; habria que lograr que sea todavia mas chico".
#  - La tarjeta del equipo junta nombre, como esta (con la bateria) y direccion en el encabezado, y los botones quedan mas bajos: ocupa cerca de un
#    tercio del mapa en vez de casi la mitad. Margen de error y km de hoy quedan abajo (se recorren con el dedo).
#  - La lista de abajo (Familia y equipos) tambien es mas baja, con el titulo y el resumen en una linea.
#  - Al abrir el mapa y con "ver todos", el encuadre mide lo que tapa la lista o la tarjeta y deja a todos a la vista en el resto del mapa.
# Requiere aplicar-mapa-app-tarjeta-panel.ps1. Va en la carpeta del PANEL (la que tiene wrangler.toml). Toca src\panel-mapa.txt y
# src\panel-explanations.css. Respaldo .bak-tarjeta2. Al final publica el panel solo.
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
if ((Contar $mapaTexto 'ogm-donde') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $mapaTexto 'function htmlTarjetaApp') -eq 0) { Mal "Falta aplicar antes aplicar-mapa-app-tarjeta-panel.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\panel-explanations.css")).texto '/* Botones en pastilla (como el dibujo de la consola). */') -ne 1) { Mal "Falta aplicar antes los pasos de la consola (pestanas, ayudas, equipos)."; return }
$cambios = @(
    @('src\panel-mapa.txt', 'tarjeta: estado corto con la bateria', ('${esc(textoHace(e))}${lejos !== null ? ` ' + [char]0x00b7 + ' ${esc(textoDistancia(lejos))}` : ""}`;
  const baldosa'), ('${esc(textoHace(e, true))}${e.bateria === null ? "" : ` ' + [char]0x00b7 + ' ${Math.round(e.bateria)} %`}${lejos !== null ? ` ' + [char]0x00b7 + ' ${esc(textoDistancia(lejos))}` : ""}`;
  const baldosa')),
    @('src\panel-mapa.txt', 'tarjeta: la bateria ya esta arriba', ('    e.bateria === null ? "" : `Bater' + [char]0x00ed + 'a ${Math.round(e.bateria)}%`,
    km >= 0.05'), '    km >= 0.05'),
    @('src\panel-mapa.txt', 'tarjeta: la direccion dentro del encabezado', ('<small>${cuando}</small></div>
      <button type="button" class="ogm-cerrar" data-accion="soltar" aria-label="Cerrar y volver a la lista" title="Volver a la lista">' + [char]0x2715 + '</button>
    </div>
    <p class="ogm-direc">${esc(e.direccion || (e.lat !== null ? `${e.lat.toFixed(5)}, ${e.lng.toFixed(5)}` : "Todav' + [char]0x00ed + 'a sin ubicaci' + [char]0x00f3 + 'n"))}</p>'), ('<small>${cuando}</small><small class="ogm-donde">${esc(e.direccion || (e.lat !== null ? `${e.lat.toFixed(5)}, ${e.lng.toFixed(5)}` : "Todav' + [char]0x00ed + 'a sin ubicaci' + [char]0x00f3 + 'n"))}</small></div>
      <button type="button" class="ogm-cerrar" data-accion="soltar" aria-label="Cerrar y volver a la lista" title="Volver a la lista">' + [char]0x2715 + '</button>
    </div>')),
    @('src\panel-mapa.txt', 'encuadre: dejar lugar segun lo que tapa la lista o la tarjeta', 'EN_APP ? { top: 60, right: 40, bottom: Math.min(260, Math.round(window.innerHeight * 0.46)), left: 40 }', 'EN_APP ? { top: 60, right: 40, bottom: alturaDeAbajo() + 24, left: 40 }'),
    @('src\panel-mapa.txt', 'encuadre: cuanto tapa lo de abajo', 'function encuadrarTodo() {', '/** Dentro de la app: lo que tapan la lista o la tarjeta de abajo, para que el encuadre deje a todos a la vista en lo que queda del mapa. */
function alturaDeAbajo() {
  const caja = $("#og-mapa .ogm-tarjeta:not(.hidden)") || $("#og-mapa.ogm-sin-elegir .ogm-lado");
  return Math.min(Math.round(window.innerHeight * 0.4), caja ? Math.round(caja.getBoundingClientRect().height) : 0);
}

function encuadrarTodo() {'),
    @('src\panel-explanations.css', 'mapa en la app: todavia mas chico', '/* Botones en pastilla (como el dibujo de la consola). */', '/* Mapa dentro de la app, ronda 2: la lista y la tarjeta de abajo, todavia mas bajas (mas lugar para el mapa, por ejemplo para ver a alguien lejos).
   La tarjeta junta nombre, como esta (con la bateria) y direccion en el encabezado; los datos de menos uso (margen de error, km de hoy) quedan abajo
   y se recorren con el dedo. */
@media (max-width: 899px) {
  html.app-mapa #og-mapa .ogm-tarjeta { max-height: 36%; padding: 2px 10px 8px; }
  html.app-mapa #og-mapa .ogm-asa { height: 14px; margin: -2px -10px 0; width: calc(100% + 20px); }
  html.app-mapa #og-mapa .ogm-asa::before { top: 5px; height: 4px; }
  html.app-mapa #og-mapa .ogm-cab-app { gap: 9px; }
  html.app-mapa #og-mapa .ogm-cab-app .ogm-av.grande { width: 40px; height: 40px; }
  html.app-mapa #og-mapa .ogm-nom strong { font-size: 1rem; }
  html.app-mapa #og-mapa .ogm-cab-app small { font-size: 0.74rem; line-height: 1.3; }
  html.app-mapa #og-mapa .ogm-cab-app .ogm-donde { color: var(--ogm-texto); opacity: 0.85; }
  html.app-mapa #og-mapa .ogm-cerrar { width: 28px; height: 28px; }
  html.app-mapa #og-mapa .ogm-cab-app .ogm-foto:not(:disabled)::after { width: 14px; height: 14px; right: -3px; bottom: -3px; font-size: 0.5rem; }
  html.app-mapa #og-mapa .ogm-tiles { gap: 5px; margin: 6px 0 4px; }
  html.app-mapa #og-mapa .ogm-tile { gap: 2px; padding: 6px 1px 5px; border-radius: 12px; }
  html.app-mapa #og-mapa .ogm-tile svg { width: 19px; height: 19px; }
  html.app-mapa #og-mapa .ogm-tile span { font-size: 0.62rem; }
  html.app-mapa #og-mapa .ogm-msj { margin: 4px 0 0; }
  html.app-mapa #og-mapa.ogm-sin-elegir .ogm-lado { max-height: 30%; padding: 0 8px 6px; }
  html.app-mapa #og-mapa .ogm-asa-lista { height: 16px; }
  html.app-mapa #og-mapa .ogm-asa-lista::before { top: 6px; height: 4px; }
  html.app-mapa #og-mapa .ogm-lista li { padding: 5px 2px; gap: 9px; }
  html.app-mapa #og-mapa .ogm-lista .ogm-av.chico { width: 36px; height: 36px; }
  html.app-mapa #og-mapa .ogm-lista strong { font-size: 0.92rem; }
  html.app-mapa #og-mapa .ogm-lista small { font-size: 0.72rem; }
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
    if (Test-Path ($ruta + ".bak-tarjeta2")) { Mal ("Ya existe " + $t + ".bak-tarjeta2. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-tarjeta2"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-tarjeta2): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-tarjeta2") -Destination $ruta -Force }
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
Ok "LISTO: el panel quedo publicado. Cerra la app y abrila de nuevo para ver el mapa mas chico."
Write-Host ""
