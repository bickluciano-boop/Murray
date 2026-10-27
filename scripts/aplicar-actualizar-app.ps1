# aplicar-actualizar-app.ps1 - App (PROXIMA build): tarjeta "Actualizar Ojo Guard" en Configuracion (solo Android, al lado del Dr. Ojo Guard) y linea de version dentro del Dr. Ojo Guard.
# Luciano (27/10/2026): "esta muy escondido: tendria que haber un icono al lado del Dr. que diga actualizacion... o adentro del Dr." -> las dos.
#  1) Configuracion: tarjeta nueva "Actualizar Ojo Guard" (icono de descarga): muestra tu version y build, "Buscar actualizacion" y "Volver a instalar la ultima" (abre ojoguard.app/descargar).
#  2) Dr. Ojo Guard: arriba una linea "Version de Ojo Guard: al dia" o "Hay una version nueva... Toca para actualizar" (si no hay dato o no hay internet no muestra nada).
# Archivos nuevos que baja con huella verificada: src\PaginaActualizar.tsx y assets\config-actualizar.png. Toca App.tsx, src\GruposConfiguracion.tsx y src\PaginaChequeo.tsx (respaldo .bak-actualizar).
# Requiere aplicar-version-captura-app.ps1. Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba. Sale en la PROXIMA build.
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
foreach ($f in @("App.tsx", "src\GruposConfiguracion.tsx", "src\PaginaChequeo.tsx")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\GruposConfiguracion.tsx")).texto '"actualizacion"') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "App.tsx")).texto 'const CLAVE_PASOS_CAPTURA') -eq 0) { Mal "Falta aplicar primero aplicar-version-captura-app.ps1. No toco nada."; return }
$cambios = @(
    @('src\GruposConfiguracion.tsx', 'grupo nuevo en el tipo', '"proteccion" | "conexion" | "permisos" | "perfil" | "familia";', '"proteccion" | "conexion" | "permisos" | "perfil" | "familia" | "actualizacion";'),
    @('src\GruposConfiguracion.tsx', 'texto del grupo nuevo', '  conexion: { titulo: "Ojo Guard MS", resumen: "Cómo se conecta este teléfono con el panel de Ojo Guard MS." },', '  conexion: { titulo: "Ojo Guard MS", resumen: "Cómo se conecta este teléfono con el panel de Ojo Guard MS." },
  actualizacion: { titulo: "Actualizar Ojo Guard", resumen: "La versión instalada, si hay una nueva y cómo volver a instalarla." },'),
    @('src\GruposConfiguracion.tsx', 'icono del grupo nuevo', '  conexion: require("../assets/config-conexion.png"),
};', '  conexion: require("../assets/config-conexion.png"),
  actualizacion: require("../assets/config-actualizar.png"),
};'),
    @('src\GruposConfiguracion.tsx', 'tarjeta nueva (solo Android) al lado del Dr. Ojo Guard', '    { grupo: "proteccion", detalle: "Chequeo del teléfono y prueba de sirena" },
  ];', '    { grupo: "proteccion", detalle: "Chequeo del teléfono y prueba de sirena" },
    ...(android ? [{ grupo: "actualizacion" as const, detalle: "Versión instalada y buscar una nueva" }] : []),
  ];'),
    @('src\PaginaChequeo.tsx', 'imports', 'import { Text } from "react-native";', 'import { Platform, Text } from "react-native";'),
    @('src\PaginaChequeo.tsx', 'import de la linea de version', 'import { ProteccionBlock } from "./ProteccionBlock";', 'import { LineaVersion } from "./PaginaActualizar";
import { ProteccionBlock } from "./ProteccionBlock";'),
    @('src\PaginaChequeo.tsx', 'propiedades nuevas', '  botones: ComponentProps<typeof ProteccionBlock>["botones"];
};', '  botones: ComponentProps<typeof ProteccionBlock>["botones"];
  /** Número de build instalado (solo Android: con él se ve si hay una versión nueva). */
  build?: string | undefined;
  /** Abre la página "Actualizar Ojo Guard". */
  onActualizar?: (() => void) | undefined;
};'),
    @('src\PaginaChequeo.tsx', 'firma', 'export function PaginaChequeo({ paleta, botones }: Props) {', 'export function PaginaChequeo({ paleta, botones, build, onActualizar }: Props) {'),
    @('src\PaginaChequeo.tsx', 'linea de version arriba del chequeo', '  return <ProteccionBlock abierto enrollment={enrollment} paleta={paleta} botones={botones} visible />;', '  return (
    <>
      {Platform.OS === "android" && build ? <LineaVersion build={build} botones={botones} onActualizar={onActualizar} /> : null}
      <ProteccionBlock abierto enrollment={enrollment} paleta={paleta} botones={botones} visible />
    </>
  );'),
    @('App.tsx', 'import de la pagina nueva', 'import { PaginaChequeo } from "./src/PaginaChequeo";', 'import { PaginaActualizar } from "./src/PaginaActualizar";
import { PaginaChequeo } from "./src/PaginaChequeo";'),
    @('App.tsx', 'pagina Actualizar Ojo Guard', '          {grupoActual === "proteccion" ? (', '          {grupoActual === "actualizacion" ? (
            <PaginaActualizar
              version={APP_VERSION}
              build={String(APP_BUILD_LABEL)}
              botones={{
                secundario: styles.secondaryButton,
                secundarioTexto: styles.secondaryButtonText,
                ayuda: styles.fieldHelp,
              }}
            />
          ) : null}

          {grupoActual === "proteccion" ? ('),
    @('App.tsx', 'Dr. Ojo Guard: build y atajo a la pagina nueva', '            <PaginaChequeo
              paleta={P}
', '            <PaginaChequeo
              paleta={P}
              build={String(APP_BUILD_LABEL)}
              onActualizar={() => elegirGrupo("actualizacion")}
')
)
$descargas = @(
    @('https://raw.githubusercontent.com/bickluciano-boop/Murray/09eb06feb4c263df5437e24f668beead44f43d6b/scripts/app/src/PaginaActualizar.tsx', 'src\PaginaActualizar.tsx', '6d4629ec58cec617bae14d323b2990b145df6eea5e10519a9052488efe7926c6'),
    @('https://raw.githubusercontent.com/bickluciano-boop/Murray/09eb06feb4c263df5437e24f668beead44f43d6b/scripts/app/assets/config-actualizar.png', 'assets\config-actualizar.png', 'e51fce92ff23ce827e0a365f86c9938487ef3fd698ecad2f6ce7938bd3c67c5c')
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
    if (Test-Path ($ruta + ".bak-actualizar")) { Mal ("Ya existe " + $t + ".bak-actualizar. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-actualizar"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-actualizar): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-actualizar") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    foreach ($t in $respaldados) { Remove-Item -LiteralPath ((Join-Path $raiz $t) + ".bak-actualizar") -Force -ErrorAction SilentlyContinue }
Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "Archivos listos. Reviso que la app compile (puede tardar un minuto)..."
& npx.cmd tsc --noEmit
if ($LASTEXITCODE -ne 0) {
    Mal "La revision de tipos encontro errores (arriba). Dejo todo como estaba."
    foreach ($t in $tocados) { $ruta = Join-Path $raiz $t; if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-actualizar") -Destination $ruta -Force } elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force } }
    foreach ($t in $respaldados) { Remove-Item -LiteralPath ((Join-Path $raiz $t) + ".bak-actualizar") -Force -ErrorAction SilentlyContinue }
Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "LISTO: la app compila bien. Sale en la PROXIMA build."
Write-Host ""
