# aplicar-barra-chica-app.ps1 - Barra de abajo mas baja, nombre del telefono en un renglon y la X y el ? del iPhone bien ubicados.
# Pedidos de Luciano (16/10/2026), mirando el Inicio con el mapa: "esta sobrecargado; reducir el tamano de los iconos de abajo" y "nombre en un solo
# renglon"; y de la prueba en el iPhone: la X (arriba a la izquierda) y el ? (arriba a la derecha) se pisaban con la hora y la bateria.
#  - La barra de abajo (SOS, Inicio, Perfil, Ajustes, Panel): botones mas bajos (de unos 53 a unos 40 de alto), iconos de 17 en vez de 22, letra de 10,
#    menos aire arriba y abajo; el SOS cuadradito igual de bajo. El SOS sigue igual: se mantiene apretado 3 segundos.
#  - Arriba: "Android Luciano - En linea - 24%" en UN solo renglon, entre la X y el ?.
#  - iPhone: la X y el ? bajan lo que mide la zona de la hora y la bateria (en Android no cambia nada).
# Cambia App.tsx (el import y dos posiciones) y reemplaza src\GruposConfiguracion.tsx y src\SosBlock.tsx (se revisa que sean los de la ultima vez).
# Va en la carpeta de la APP (la que tiene app.json). Respaldo .bak-barrachica. Es codigo de la app: hace falta una BUILD NUEVA (Android e iPhone).
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
foreach ($f in @("App.tsx", "src\GruposConfiguracion.tsx", "src\SosBlock.tsx")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "App.tsx")).texto 'initialWindowMetrics') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
# Los dos archivos que se reemplazan tienen que ser exactamente los de la ultima vez (aplicar-barra-ajustes-app.ps1); si alguien los toco a mano, no se pisan.
$viejos = @{ "src\GruposConfiguracion.tsx" = "11e45fd296154de8e9ec4ea4085c7f3dd55a8a2989f208a09906437f8d015b3e"; "src\SosBlock.tsx" = "d0021f1522daa44e96569074f16addd959b231039916db2773ec296d0e1979e8" }
foreach ($k in $viejos.Keys) { if ((Sha (Join-Path $raiz $k)) -ne $viejos[$k]) { Mal ($k + " no es el de la ultima vez (falta aplicar-barra-ajustes-app.ps1 o se cambio a mano). No toco nada. Mandame esta pantalla."); return } }
$cambios = @(
    @('App.tsx', 'import de las medidas de la pantalla segura (iPhone)', 'import { InicioMapa } from "./src/InicioMapa";', 'import { InicioMapa } from "./src/InicioMapa";
import { initialWindowMetrics } from "react-native-safe-area-context";'),
    @('App.tsx', 'iPhone: el ? baja debajo de la hora y la bateria', '    right: 16,
    top: Platform.OS === "android" ? 18 : 8,
    width: 36,', '    right: 16,
    top: Platform.OS === "android" ? 18 : 8 + (initialWindowMetrics?.insets.top ?? 47),
    width: 36,'),
    @('App.tsx', 'iPhone: la X baja debajo de la hora y la bateria', '    position: "absolute",
    top: Platform.OS === "android" ? 18 : 8,
    width: 30,', '    position: "absolute",
    top: Platform.OS === "android" ? 18 : 8 + (initialWindowMetrics?.insets.top ?? 47),
    width: 30,')
)
$descargas = @(
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/ad5c571df310645e95f16503cdf523b9971dd736/scripts/familia/GruposConfiguracion.tsx", "src\GruposConfiguracion.tsx", "0274dc667cca1b5c7f7fe77b0298138daaa13d97ae570d691ca55b1019bd967d"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/ad5c571df310645e95f16503cdf523b9971dd736/scripts/familia/SosBlock.tsx", "src\SosBlock.tsx", "dec0c5d931f79a7cb9f22657ba9c15ae9223ecffbf1e8065bc3faaa7157cbf1c")
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
    if (Test-Path ($ruta + ".bak-barrachica")) { Mal ("Ya existe " + $t + ".bak-barrachica. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-barrachica"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-barrachica): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-barrachica") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "Archivos listos. Reviso que la app compile (puede tardar un minuto)..."
& npx.cmd tsc --noEmit
if ($LASTEXITCODE -ne 0) { Mal "La revision de tipos encontro errores (arriba). No hagas la build todavia: mandame esta pantalla."; return }
Write-Host ""
Ok "LISTO: la app compila bien. Hace falta una BUILD NUEVA (Android e iPhone): barra de abajo mas baja, nombre en un renglon y X y ? del iPhone en su lugar."
Write-Host ""
