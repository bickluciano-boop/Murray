# aplicar-permisos-registro-app.ps1 - App (PROXIMA build, Android e iPhone). Luciano (20/11/2026): (1) "Permisos de Android" como tarjeta en Ajustes (la franja verde del Inicio NO cambia); (2) boton "Compartir registro con soporte" en los registros tecnicos.
# Agrega src\TarjetaPermisos.tsx y src\compartirRegistro.ts; toca App.tsx en tres puntos (imports, la franja de Ajustes y el boton). No toca el mapa ni el Inicio. No agrega librerias.
# Requiere la tarjeta de salud (aplicar-tarjeta-salud-app.ps1). Respaldo .bak-permisos. Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba.
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
if (-not (Test-Path (Join-Path $raiz "App.tsx"))) { Mal "No encuentro App.tsx en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "App.tsx")).texto 'compartirRegistroSoporte') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "App.tsx")).texto 'TarjetaSaludAjustes') -eq 0) { Mal "Falta aplicar primero la tarjeta de salud (aplicar-tarjeta-salud-app.ps1)."; return }
$cambios = @(
    @('App.tsx', 'registro: importar la tarjeta de permisos y el compartir registro', 'import { TarjetaSaludAjustes } from "./src/TarjetaSaludEntrada";
', 'import { TarjetaSaludAjustes } from "./src/TarjetaSaludEntrada";
import { TarjetaPermisos } from "./src/TarjetaPermisos";
import { compartirRegistroSoporte } from "./src/compartirRegistro";
'),
    @('App.tsx', 'permisos: la franja de Ajustes pasa a tarjeta (el Inicio no cambia)', '              <BandaPermisos
                paleta={P}
                android={Platform.OS === "android"}
                permisosEnOrden={permisosEnOrden}
                permisosTotal={4}
                onPress={() => elegirGrupo("permisos")}
              />
              <TarjetaSaludAjustes paleta={P} />
', '              <TarjetaPermisos
                paleta={P}
                android={Platform.OS === "android"}
                permisosEnOrden={permisosEnOrden}
                permisosTotal={4}
                onPress={() => elegirGrupo("permisos")}
              />
              <TarjetaSaludAjustes paleta={P} />
'),
    @('App.tsx', 'registro: boton Compartir registro con soporte', '            </Plegable>
            <Pressable onPress={onPermissions} style={[styles.secondaryButton, { marginTop: 14 }]}>
', '            </Plegable>
            <Pressable
              accessibilityRole="button"
              onPress={() =>
                void compartirRegistroSoporte({
                  version: `${APP_VERSION} (build ${APP_BUILD_LABEL})`,
                  sistema: Platform.OS,
                  aviso: Platform.OS === "android" ? describirRastroDeAviso(fullScreenAlertTrace, hasFullScreenAlertPermission()) : "",
                  historial: fullScreenAlertDiagnostics.map(
                    (e) => `${formatearFecha(e.at)} | ${e.reason} | modulo=${e.moduleFound ? "si" : "NO"} | resultado=${e.result ? "OK" : "fallo"}${e.error ? ` | ${e.error}` : ""}`,
                  ),
                  camaraNativa: nativeCaptureDiagnostics,
                  pasos: pasosCaptura,
                })
              }
              style={[styles.secondaryButton, { marginTop: 14 }]}
            >
              <Text style={styles.secondaryButtonText}>Compartir registro con soporte</Text>
            </Pressable>
            <Pressable onPress={onPermissions} style={[styles.secondaryButton, { marginTop: 14 }]}>
')
)
$descargas = @(
    @('https://raw.githubusercontent.com/bickluciano-boop/Murray/b67472b191d3c2cbd6fe661f7db27f454f307abf/scripts/app/src/TarjetaPermisos.tsx', 'src\TarjetaPermisos.tsx', '6a9b82e10213463fced715981c0ec49c21d8aed35d708a67dc06d94836418376'),
    @('https://raw.githubusercontent.com/bickluciano-boop/Murray/b67472b191d3c2cbd6fe661f7db27f454f307abf/scripts/app/src/compartirRegistro.ts', 'src\compartirRegistro.ts', '58f475905d25e0eac227bea076188cc8c283353c885cb77191e11151885c0b7f')
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
    if (Test-Path ($ruta + ".bak-permisos")) { Mal ("Ya existe " + $t + ".bak-permisos. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-permisos"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-permisos): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-permisos") -Destination $ruta -Force }
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
    foreach ($t in $tocados) { $ruta = Join-Path $raiz $t; if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-permisos") -Destination $ruta -Force } }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "LISTO: la app compila bien. Ajustes tiene Permisos de Android como tarjeta y los registros tecnicos tienen el boton Compartir registro con soporte (sale en la PROXIMA build, Android e iPhone)."
Write-Host ""
