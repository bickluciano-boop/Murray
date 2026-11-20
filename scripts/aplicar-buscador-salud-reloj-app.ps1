# aplicar-buscador-salud-reloj-app.ps1 - App (PROXIMA build, Android e iPhone). Luciano (20/11/2026): que el buscador de Ajustes tambien encuentre "Salud y emergencias" y el "Reloj" y los abra solos.
# Agrega src\aperturasAjustes.ts y reemplaza src\indiceBusqueda.ts, src\BuscadorAjustes.tsx, src\TarjetaSaludEntrada.tsx y src\RelojCaidasAviso.tsx (las dos tarjetas solo suman una linea que las anota para que el buscador las abra). Mejora el ranking de errores de tipeo ("alerjias") e ignora palabras vacias ("se cae"). No cambia ninguna funcion, el mapa ni el Inicio. No agrega librerias.
# Requiere aplicar-buscador-ajustes-app.ps1 y el video del reloj. Respaldo .bak-busqueda2. Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba.
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
foreach ($f in @("src\BuscadorAjustes.tsx", "src\indiceBusqueda.ts", "src\TarjetaSaludEntrada.tsx", "src\RelojCaidasAviso.tsx")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + ". Falta aplicar antes el buscador de Ajustes y la tarjeta del reloj con el video."); return } }
if ((Contar (Leer (Join-Path $raiz "src\BuscadorAjustes.tsx")).texto 'abrirDesdeBuscador') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\RelojCaidasAviso.tsx")).texto 'htmlDelVideo') -eq 0) { Mal "Falta aplicar primero el video del reloj (aplicar-reloj-video-app.ps1)."; return }
$cambios = @()
$descargas = @(
    @('https://raw.githubusercontent.com/bickluciano-boop/Murray/9c7d7fab728229b88ef41aae86307085b31d5a74/scripts/app/src/aperturasAjustes.ts', 'src\aperturasAjustes.ts', 'cee3ab5ffe89b8070b1ab6d5c7316e2096751c03be8b72cf19aafc7644095144'),
    @('https://raw.githubusercontent.com/bickluciano-boop/Murray/9c7d7fab728229b88ef41aae86307085b31d5a74/scripts/app/src/indiceBusqueda.ts', 'src\indiceBusqueda.ts', 'ce68dc24fb75e78b70a2c6a97402790948867f0ae81b0e3ccd1993140aa527e0'),
    @('https://raw.githubusercontent.com/bickluciano-boop/Murray/9c7d7fab728229b88ef41aae86307085b31d5a74/scripts/app/src/BuscadorAjustes.tsx', 'src\BuscadorAjustes.tsx', '6fc9ee2a92da20a81add5d45747d0d1cf06235bb33dd949b3e5485850b7471b8'),
    @('https://raw.githubusercontent.com/bickluciano-boop/Murray/9c7d7fab728229b88ef41aae86307085b31d5a74/scripts/app/src/TarjetaSaludEntrada.tsx', 'src\TarjetaSaludEntrada.tsx', 'bdb2cfde2653f85f6c348816c21da8c7dec5bdfcb9a45544a20138bc289cac78'),
    @('https://raw.githubusercontent.com/bickluciano-boop/Murray/9c7d7fab728229b88ef41aae86307085b31d5a74/scripts/app/src/RelojCaidasAviso.tsx', 'src\RelojCaidasAviso.tsx', '6019196e232a83ed2ee995aac28d7b38de7782a32a8ebca034f286b23a8f01b8')
)

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
    if (Test-Path ($ruta + ".bak-busqueda2")) { Mal ("Ya existe " + $t + ".bak-busqueda2. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-busqueda2"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-busqueda2): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-busqueda2") -Destination $ruta -Force }
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
    foreach ($t in $tocados) { $ruta = Join-Path $raiz $t; if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-busqueda2") -Destination $ruta -Force } }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "LISTO: la app compila bien. El buscador de Ajustes encuentra Salud y emergencias y el Reloj y los abre solo (sale en la PROXIMA build, Android e iPhone)."
Write-Host ""
