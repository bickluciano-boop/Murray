# aplicar-inicio-mapa-app.ps1 - Inicio con el mapa adentro de la app.
# Pedido de Luciano (15/10/2026): lo primero que se ve al abrir Ojo Guard tiene que ser el mapa con todos los equipos y la familia, y el
# SOS grande no tiene que ocupar media pantalla. Cambia solo la organizacion: no se saca ninguna funcion.
#  - INICIO: una linea con este telefono (nombre, "En linea", bateria), tres botones chicos (Mi perfil, Familia y Configuracion), el mapa de
#    Ojo Guard MS ocupando casi toda la pantalla (los equipos y la familia, con "Hacer sonar", "Seguir en vivo", "Como llegar", invitar y
#    lugares) y, abajo, el boton de SOS en una franja baja (se mantiene apretado 3 segundos, igual que antes).
#  - FAMILIA (boton nuevo del Inicio): lo que antes estaba abajo del Inicio: la lista de la familia, unirse con un codigo, pausar la
#    ubicacion, salir de la familia y el SOS completo con "Pedir ayuda sin abrir la app".
#  - El mapa es el mismo del panel (en su modo "solo mapa"): entra solo, sin pedir codigos, y se renueva solo. Hace falta aplicar antes
#    aplicar-mapa-en-app-panel.ps1 en el panel. Necesita internet.
#  - Agrega el modulo react-native-webview (es NATIVO): hace falta una BUILD NUEVA, en Android y en iPhone.
# Cambia src\GruposConfiguracion.tsx y src\SosBlock.tsx, suma src\MapaEnApp.tsx, src\InicioMapa.tsx, y toca App.tsx y src\remoteApi.ts.
# Va en la carpeta de la APP (la que tiene app.json). Respaldo .bak-iniciomapa.
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
if (Test-Path (Join-Path $raiz "src\InicioMapa.tsx")) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if (-not (Test-Path (Join-Path $raiz "src\remoteApi.ts"))) { Mal "No encuentro src\remoteApi.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\remoteApi.ts")).texto 'requestPanelHandoff') -eq 0) { Mal "Falta aplicar antes el acceso directo (aplicar-acceso-directo-app.ps1)."; return }
if (-not (Test-Path (Join-Path $raiz "src\GruposConfiguracion.tsx")) -or -not (Test-Path (Join-Path $raiz "src\FamilySection.tsx"))) { Mal "Faltan los scripts anteriores de Inicio y Configuracion."; return }
$cambios = @(
    @('App.tsx', 'import del Inicio con mapa', 'import { FamilySection } from "./src/FamilySection";
', 'import { FamilySection } from "./src/FamilySection";
import { InicioMapa } from "./src/InicioMapa";
'),
    @('App.tsx', 'boton atras: Familia vuelve al Inicio', '      elegirGrupo(grupo === "configuracion" || grupo === "perfil" ? null : "configuracion");', '      elegirGrupo(grupo === "configuracion" || grupo === "perfil" || grupo === "familia" ? null : "configuracion");'),
    @('App.tsx', 'cabecera de grupo: Familia vuelve al Inicio', 'onVolver={() => elegirGrupo(grupoActual === "perfil" ? null : "configuracion")} />', 'onVolver={() => elegirGrupo(grupoActual === "perfil" || grupoActual === "familia" ? null : "configuracion")} />'),
    @('App.tsx', 'Familia y amigos tiene su propia pantalla', '          {!firstRun && grupoActual === null ? (
            <FamilySection
              paleta={P}
              Seccion={CollapsibleSection}', '          {grupoActual === "familia" ? (
            <FamilySection
              paleta={P}
              Seccion={SeccionFamilia}'),
    @('App.tsx', 'seccion de Familia marcada con su grupo', 'function SeccionPlegable({
  title,
  subtitle,
  defaultOpen,', '// La seccion de "Familia y amigos" se ve solo en su pantalla (Inicio, boton "Familia").
function SeccionFamilia({ title, subtitle, defaultOpen, children }: { title: string; subtitle?: string; defaultOpen?: boolean; children: ReactNode }) {
  return (
    <CollapsibleSection grupo="familia" title={title} subtitle={subtitle} defaultOpen={defaultOpen}>
      {children}
    </CollapsibleSection>
  );
}

function SeccionPlegable({
  title,
  subtitle,
  defaultOpen,'),
    @('App.tsx', 'Inicio con el mapa', '  return (
    <SafeAreaView style={styles.setupRoot}>
      <StatusBar style={temaActivo === "claro" ? "dark" : "light"} />
      <HelpButton context="settings" />
      {onCancel && grupoActual === null ? (', ('  // Inicio: el mapa con los equipos y la familia, y el SOS a mano (ver src/InicioMapa.tsx). La primera vez se sigue viendo todo junto.
  if (!firstRun && grupoActual === null) {
    return (
      <SafeAreaView style={styles.setupRoot}>
        <StatusBar style={temaActivo === "claro" ? "dark" : "light"} />
        <HelpButton context="settings" />
        {onCancel ? (
          <Pressable
            accessibilityLabel="Volver a la pantalla de guardia"
            accessibilityRole="button"
            onPress={onCancel}
            style={styles.closeSettingsButton}
          >
            <Text style={styles.closeSettingsButtonText}>' + [char]0x2715 + '</Text>
          </Pressable>
        ) : null}
        <InicioMapa
          paleta={P}
          tema={temaActivo === "claro" ? "claro" : "oscuro"}
          nombre={draft.deviceName}
          enLinea={isOnline}
          onPerfil={() => elegirGrupo("perfil")}
          onFamilia={() => elegirGrupo("familia")}
          onConfiguracion={() => elegirGrupo("configuracion")}
          onVincular={() => elegirGrupo("conexion")}
          botones={{
            secundario: styles.secondaryButton,
            secundarioTexto: styles.secondaryButtonText,
            ayuda: styles.fieldHelp,
          }}
          banda={
            <BandaPermisos
              paleta={P}
              android={Platform.OS === "android"}
              permisosEnOrden={permisosEnOrden}
              permisosTotal={4}
              soloSiFalta
              onPress={() => elegirGrupo("permisos")}
            />
          }
          aviso={
            captureDiagnostic ? (
              <View style={styles.diagnosticCard}>
                <Text style={styles.diagnosticTitle}>Diagn' + [char]0x00f3 + 'stico de captura</Text>
                <Text style={styles.fieldHelp}>{captureDiagnostic}</Text>
                <Pressable onPress={() => void openSystemSettings()} style={styles.syncButton}>
                  <Text style={styles.syncButtonText}>Abrir configuraci' + [char]0x00f3 + 'n de Android</Text>
                </Pressable>
              </View>
            ) : null
          }
        />
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.setupRoot}>
      <StatusBar style={temaActivo === "claro" ? "dark" : "light"} />
      <HelpButton context="settings" />
      {onCancel && grupoActual === null ? (')),
    @('src\remoteApi.ts', 'el enlace directo puede ser para el mapa (firma)', 'export async function requestPanelHandoff(enrollment: NativeEnrollment) {', 'export async function requestPanelHandoff(enrollment: NativeEnrollment, destino?: "mapa") {'),
    @('src\remoteApi.ts', 'el enlace directo puede ser para el mapa (pedido)', '"/api/native/panel-handoff", {
    method: "POST",
    body: JSON.stringify({ deviceId: enrollment.deviceId }),', '"/api/native/panel-handoff", {
    method: "POST",
    body: JSON.stringify({ deviceId: enrollment.deviceId, destino }),')
)
$descargas = @(
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/7278be2932be113d2d01fa1eee8ecd9bf7514d91/scripts/familia/GruposConfiguracion.tsx", "src\GruposConfiguracion.tsx", "81f7b7e042062dc2364b067e8b2e5f1e64f94a86a00bdc41692869dddfc9ba6f"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/7278be2932be113d2d01fa1eee8ecd9bf7514d91/scripts/familia/SosBlock.tsx", "src\SosBlock.tsx", "be2c2ca865b11072ad859e60953c8b778ac73d2fecf19d0080b395ccedcec3aa"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/7278be2932be113d2d01fa1eee8ecd9bf7514d91/scripts/familia/MapaEnApp.tsx", "src\MapaEnApp.tsx", "bdd5edb8da96738cf1a41c60692ebc7b3b107e7f5a1b6fac9783fb7e61186bb3"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/7278be2932be113d2d01fa1eee8ecd9bf7514d91/scripts/familia/InicioMapa.tsx", "src\InicioMapa.tsx", "efca449425af801c0ee6f77261dc63208481e78598faa499ea531bc5a081dab4"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/7278be2932be113d2d01fa1eee8ecd9bf7514d91/scripts/familia/iconos/config-familia.png", "assets\config-familia.png", "e0decb903f354fba3bb14dc665f742e28f74555c9b58456e57a75cc7a1a453c4")
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
    if (Test-Path ($ruta + ".bak-iniciomapa")) { Mal ("Ya existe " + $t + ".bak-iniciomapa. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-iniciomapa"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-iniciomapa): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-iniciomapa") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "Archivos listos. Sumo el modulo del mapa (react-native-webview)..."
& npx.cmd expo install react-native-webview
if ($LASTEXITCODE -ne 0) { Mal "No se pudo instalar react-native-webview (mira el error de arriba). No hagas la build todavia: mandame esta pantalla."; return }
Ok "Modulo instalado. Reviso que la app compile (puede tardar un minuto)..."
& npx.cmd tsc --noEmit
if ($LASTEXITCODE -ne 0) { Mal "La revision de tipos encontro errores (arriba). No hagas la build todavia: mandame esta pantalla."; return }
Write-Host ""
Ok "LISTO: la app compila bien. Hace falta una BUILD NUEVA (Android e iPhone): el mapa usa un modulo nativo."
Write-Host ""
