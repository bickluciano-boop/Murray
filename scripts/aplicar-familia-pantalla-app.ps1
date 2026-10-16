# aplicar-familia-pantalla-app.ps1 - La pantalla Familia mas clara (como la lista de Personas de Buscar de Apple) y sin el boton repetido en Ajustes.
# Pedidos de Luciano (16/10/2026), con fotos de la build que trae la barra fija:
#  - AJUSTES REPETIA "Abrir Ojo Guard MS": ya esta "Panel" en la barra de arriba. Se saca de Ajustes > Ojo Guard MS (quedan "Sincronizar
#    ordenes ahora" y "Crear acceso seguro a MS").
#  - LA PANTALLA FAMILIA ERA POCO CLARA. Ahora: sin el titulo "Familia y amigos" repetido adentro (ya lo dice la cabecera); una lista de
#    personas con su foto/inicial, el rol, como esta (En vivo / Sin conexion / hace cuanto), la direccion y la bateria; tocar a una persona la
#    lleva al mapa del Inicio (en Android y en iPhone; antes "Mapa >" tapaba la etiqueta del rol). Despues, cada cosa en su tarjeta con su
#    titulo: Mi ubicacion (pausar 1 hora / reanudar), SOS y ayuda (pedir ayuda sin abrir la app) y Unirme a una familia (con el codigo), y al final
#    "Salir de la familia". No se saca ninguna funcion. El mapa de Apple que habia arriba en iPhone ya no esta: el mapa de todos es el del Inicio.
# Suma src\FamiliaPantalla.tsx y toca App.tsx (el import de la pantalla y el boton de Ajustes). Va en la carpeta de la APP (la que tiene
# app.json). Respaldo .bak-famlista. Es solo codigo de la app (nada nativo): sale en la PROXIMA build.
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
$appTexto = (Leer (Join-Path $raiz "App.tsx")).texto
if ((Contar $appTexto 'src/FamiliaPantalla') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $appTexto 'BarraSuperior') -eq 0) { Mal "Falta aplicar antes la barra de arriba (aplicar-barra-superior-app.ps1)."; return }
if (-not (Test-Path (Join-Path $raiz "src\FamilySection.tsx"))) { Mal "Falta la pantalla Familia de antes (src\FamilySection.tsx)."; return }
$cambios = @(
    @('App.tsx', 'Familia: la pantalla nueva (mismo nombre y mismas propiedades)', 'import { FamilySection } from "./src/FamilySection";', 'import { FamilySection } from "./src/FamiliaPantalla";'),
    @('App.tsx', 'Ajustes: sin el boton Abrir Ojo Guard MS (ya esta Panel en la barra de arriba)', ('                <Pressable onPress={onOpenMs} style={styles.msLaunchButton}>
                  <Text style={styles.msLaunchButtonText}>Abrir Ojo Guard MS ' + [char]0x2192 + '</Text>
                </Pressable>
                <Text style={styles.fieldHelp}>
                  Consult' + [char]0x00e1 + ' evidencias, bater' + [char]0x00ed + 'a, ubicaci' + [char]0x00f3 + 'n, avisos, Modo perdido y b' + [char]0x00fa + 'squeda cercana desde el panel seguro.
                </Text>
                <Pressable
                  disabled={nativeLinkBusy}
                  onPress={onCreateSecureAccess}'), '                <Pressable
                  disabled={nativeLinkBusy}
                  onPress={onCreateSecureAccess}')
)
$descargas = @(
    ,@("https://raw.githubusercontent.com/bickluciano-boop/Murray/e52d456607714336a3fec1fa85533d03f8e55dda/scripts/familia/FamiliaPantalla.tsx", "src\FamiliaPantalla.tsx", "510bb72f7d6c04761e6bfcf3584c8645efcf2f7bc9bf322db33dec052a623edf")
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
    if (Test-Path ($ruta + ".bak-famlista")) { Mal ("Ya existe " + $t + ".bak-famlista. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-famlista"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-famlista): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-famlista") -Destination $ruta -Force }
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
Ok "LISTO: la app compila bien. Sale en la PROXIMA build (Android e iPhone)."
Write-Host ""
