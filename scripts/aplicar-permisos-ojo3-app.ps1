# aplicar-permisos-ojo3-app.ps1 - App (PROXIMA build): con un menor, las llaves del adulto se pueden tocar.
# Luciano (05/11/2026, iPhone): "iPhone menor te ve a vos... no me tiene que ver; no anda ninguna llave". Con un menor estaban bloqueadas las 4. Ahora: "Te ve" y "Recibe tu SOS" las decide el adulto; quedan fijas "Lo ves" y "Recibis su SOS" (cuidan al menor).
# Requiere aplicar-permisos-ojo2-app.ps1 y el instalador del servidor aplicar-permisos-ojo3-panel.ps1. Toca solo src\FamiliaPantalla.tsx (respaldo .bak-permisos3). Va en la carpeta de la APP (la que tiene app.json).
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

if (-not (Test-Path (Join-Path $raiz "app.json")) -or (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta de la APP (la que tiene app.json), no la del panel."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\FamiliaPantalla.tsx"))) { Mal "No encuentro src\FamiliaPantalla.tsx en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\FamiliaPantalla.tsx")).texto 'const TOPE_LETRA') -eq 0) { Mal "Falta aplicar primero aplicar-permisos-ojo2-app.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\FamiliaPantalla.tsx")).texto 'const fija = (clave: ClavePermiso)') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
$cambios = @(
    @('src\FamiliaPantalla.tsx', 'permisos3: tipo con llaves fijas', 'type Permisos = { locked: boolean; teVe: Llave; recibeTuSos: Llave; loVes: Llave; recibisSuSos: Llave };', 'type Permisos = { locked: boolean; fijas?: ClavePermiso[]; teVe: Llave; recibeTuSos: Llave; loVes: Llave; recibisSuSos: Llave };'),
    @('src\FamiliaPantalla.tsx', 'permisos3: funcion fija', '  const bloqueada = permisos.locked;
', '  const bloqueada = permisos.locked;
  // Con un menor quedan fijas solo las llaves que lo cuidan (verlo y recibir su SOS); las otras dos las decide el adulto.
  const fija = (clave: ClavePermiso) => bloqueada || (permisos.fijas ?? []).includes(clave);
'),
    @('src\FamiliaPantalla.tsx', 'permisos3: llave teVe', 'bloqueada={bloqueada} guardando={guardandoClave("teVe")}', 'bloqueada={fija("teVe")} guardando={guardandoClave("teVe")}'),
    @('src\FamiliaPantalla.tsx', 'permisos3: llave recibeTuSos', 'bloqueada={bloqueada} guardando={guardandoClave("recibeTuSos")}', 'bloqueada={fija("recibeTuSos")} guardando={guardandoClave("recibeTuSos")}'),
    @('src\FamiliaPantalla.tsx', 'permisos3: llave loVes', 'bloqueada={bloqueada} guardando={guardandoClave("loVes")}', 'bloqueada={fija("loVes")} guardando={guardandoClave("loVes")}'),
    @('src\FamiliaPantalla.tsx', 'permisos3: llave recibisSuSos', 'bloqueada={bloqueada} guardando={guardandoClave("recibisSuSos")}', 'bloqueada={fija("recibisSuSos")} guardando={guardandoClave("recibisSuSos")}'),
    @('src\FamiliaPantalla.tsx', 'permisos3: nota del menor', '{bloqueada ? <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.nota}>Con un menor no se puede cortar la ubicación ni el SOS.</Text> : null}', '{bloqueada || (permisos.fijas ?? []).length ? <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.nota}>{bloqueada ? "Con un menor no se puede cortar la ubicación ni el SOS." : "Verlo y recibir su SOS no se puede apagar: es lo que cuida a un menor. Lo tuyo sí lo podés cortar."}</Text> : null}')
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
    if (Test-Path ($ruta + ".bak-permisos3")) { Mal ("Ya existe " + $t + ".bak-permisos3. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-permisos3"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-permisos3): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-permisos3") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "Archivos listos. Reviso que la app compile (puede tardar un minuto)..."
& npx.cmd tsc --noEmit
if ($LASTEXITCODE -ne 0) {
    Mal "La revision de tipos encontro errores (arriba). Dejo todo como estaba."
    foreach ($t in $tocados) { $ruta = Join-Path $raiz $t; if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-permisos3") -Destination $ruta -Force } }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "LISTO: la app compila bien. Sale en la PROXIMA build."
Write-Host ""
