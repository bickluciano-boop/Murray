# aplicar-identidad-app.ps1 - App (PROXIMA build): verificacion de identidad con DNI + sexo + selfie (el servidor usa Didit y RENAPER).
# Luciano (28/10/2026): "Didit renaper"; la verificacion se puede omitir para usar la app, pero sin verificar no se puede pedir foto y audio a otras personas.
#  1) Arranque: despues de la foto de perfil, pantalla para escribir el DNI y elegir el sexo, y despues la selfie. Tiene "Omitir por ahora". Ya NO se pide la foto del documento.
#  2) Configuracion: tarjeta nueva "Verificar mi identidad" (al final de la grilla) para hacerlo mas tarde o ver que ya esta verificada.
#  3) Las fotos viejas del documento y de la cara que guardaban las versiones anteriores se borran del telefono.
# Archivos que baja con huella verificada: src\VerificarIdentidad.tsx (nuevo), src\ArranqueIdentidad.tsx (reemplaza al actual) y assets\config-identidad.png. Toca App.tsx y src\GruposConfiguracion.tsx (respaldo .bak-identidad).
# Requiere aplicar-actualizar-app.ps1 y el servidor con aplicar-identidad-didit-panel.ps1. Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba. Sale en la PROXIMA build.
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
foreach ($f in @("App.tsx", "src\GruposConfiguracion.tsx", "src\ArranqueIdentidad.tsx")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\GruposConfiguracion.tsx")).texto '"identidad"') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\GruposConfiguracion.tsx")).texto '"actualizacion"') -eq 0) { Mal "Falta aplicar primero aplicar-actualizar-app.ps1. No toco nada."; return }
$cambios = @(
    @('src\GruposConfiguracion.tsx', 'grupo nuevo en el tipo', '"proteccion" | "conexion" | "permisos" | "perfil" | "familia" | "actualizacion";', '"proteccion" | "conexion" | "permisos" | "perfil" | "familia" | "actualizacion" | "identidad";'),
    @('src\GruposConfiguracion.tsx', 'texto del grupo nuevo', '  actualizacion: { titulo: "Actualizar Ojo Guard", resumen: "La versión instalada, si hay una nueva y cómo volver a instalarla." },', '  actualizacion: { titulo: "Actualizar Ojo Guard", resumen: "La versión instalada, si hay una nueva y cómo volver a instalarla." },
  identidad: { titulo: "Verificar mi identidad", resumen: "Confirmá que sos vos con tu DNI y una selfie. Hasta hacerlo no podés pedir foto y audio a otras personas de tu familia." },'),
    @('src\GruposConfiguracion.tsx', 'icono del grupo nuevo', '  actualizacion: require("../assets/config-actualizar.png"),
};', '  actualizacion: require("../assets/config-actualizar.png"),
  identidad: require("../assets/config-identidad.png"),
};'),
    @('src\GruposConfiguracion.tsx', 'tarjeta nueva al final de la grilla', '    ...(android ? [{ grupo: "actualizacion" as const, detalle: "Versión instalada y buscar una nueva" }] : []),
  ];', '    ...(android ? [{ grupo: "actualizacion" as const, detalle: "Versión instalada y buscar una nueva" }] : []),
    { grupo: "identidad", detalle: "Confirmá que sos vos con tu DNI y una selfie" },
  ];'),
    @('App.tsx', 'import de la pantalla nueva', 'import { PaginaActualizar } from "./src/PaginaActualizar";', 'import { PaginaActualizar } from "./src/PaginaActualizar";
import { VerificarIdentidad } from "./src/VerificarIdentidad";'),
    @('App.tsx', 'pagina Verificar mi identidad', '          {grupoActual === "actualizacion" ? (', '          {grupoActual === "identidad" ? (
            <VerificarIdentidad
              noche={temaActivo === "oscuro"}
              onListo={() => elegirGrupo("configuracion")}
              paleta={P}
              permitirOmitir={false}
              revisarEstado
            />
          ) : null}

          {grupoActual === "actualizacion" ? (')
)
$descargas = @(
    @('https://raw.githubusercontent.com/bickluciano-boop/Murray/e470b2275c503d9b265fe457273155ff9c541f9d/scripts/app/src/VerificarIdentidad.tsx', 'src\VerificarIdentidad.tsx', '52d8fcbf8a7d856b9995c7d9a8a73c1db34f9b4f6035dd6cb745b26266010f2c'),
    @('https://raw.githubusercontent.com/bickluciano-boop/Murray/e470b2275c503d9b265fe457273155ff9c541f9d/scripts/app/arranque/ArranqueIdentidad.tsx', 'src\ArranqueIdentidad.tsx', 'd2e2080efba714a314045e1e0457cd4be7aa613a775d3b5ed2e6444d707dab87'),
    @('https://raw.githubusercontent.com/bickluciano-boop/Murray/e470b2275c503d9b265fe457273155ff9c541f9d/scripts/app/assets/config-identidad.png', 'assets\config-identidad.png', '45812c766485a861daf2f016b9ceec0b8a597b864b0fb6946af95d9b76ffb41d')
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
    if (Test-Path ($ruta + ".bak-identidad")) { Mal ("Ya existe " + $t + ".bak-identidad. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-identidad"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-identidad): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-identidad") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    foreach ($t in $respaldados) { Remove-Item -LiteralPath ((Join-Path $raiz $t) + ".bak-identidad") -Force -ErrorAction SilentlyContinue }
Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "Archivos listos. Reviso que la app compile (puede tardar un minuto)..."
& npx.cmd tsc --noEmit
if ($LASTEXITCODE -ne 0) {
    Mal "La revision de tipos encontro errores (arriba). Dejo todo como estaba."
    foreach ($t in $tocados) { $ruta = Join-Path $raiz $t; if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-identidad") -Destination $ruta -Force } elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force } }
    foreach ($t in $respaldados) { Remove-Item -LiteralPath ((Join-Path $raiz $t) + ".bak-identidad") -Force -ErrorAction SilentlyContinue }
Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "LISTO: la app compila bien. Sale en la PROXIMA build."
Write-Host ""
