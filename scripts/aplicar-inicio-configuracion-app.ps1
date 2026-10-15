# aplicar-inicio-configuracion-app.ps1 - Inicio, Mi perfil y Configuracion (paso 3b de ordenar la app).
# Es solo organizacion y apariencia: ninguna funcion cambia.
#  - Al entrar con la clave de administrador se ve el INICIO: la tarjeta de este telefono (nombre, "En linea", bateria), los botones
#    "Mi perfil" y "Configuracion" (la tuerca) y, abajo, Familia y SOS (mapa o lista de la familia, con el SOS justo debajo).
#  - MI PERFIL (los datos de uno): Estado del dispositivo, Datos del telefono (nombre y correo) y Apariencia (Modo noche y fondo).
#  - CONFIGURACION: la banda de permisos y seis tarjetas de a dos: Claves y Seguridad, Fotos de Intrusos (solo Intentos de entrada),
#    Modo Perdido y Cercania, Preferencias generales (Modo preventivo, Pantalla OLED y "Envios pendientes", que antes se llamaba
#    "Proteccion sin internet"), Dr. Ojo Guard (sale de Familia) y Ojo Guard MS.
#  - "Atras" vuelve un paso; la X de salir queda solo en el Inicio, mas chica, y ya no se confunde con "Atras".
#  - Arregla la grilla que salia en una sola columna en pantallas angostas, que "En linea" diga "bateria 87%" (no se confunda con la
#    proteccion del Dr. Ojo Guard, que ahora dice "proteccion 100 %"), y que al volver de Google Maps no se pida de nuevo la clave.
# Cambia src\GruposConfiguracion.tsx y src\ProteccionBlock.tsx, suma src\PaginaChequeo.tsx y cuatro iconos en assets\, y toca App.tsx y
# src\FamilySection.tsx. Va en la carpeta de la APP (la que tiene app.json). Respaldo .bak-inicio. Es solo codigo de la app (nada
# nativo): sale en la PROXIMA build, en Android y en iPhone.
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
if (Test-Path (Join-Path $raiz "src\PaginaChequeo.tsx")) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if (-not (Test-Path (Join-Path $raiz "assets\config-conexion.png"))) { Mal "Primero corre aplicar-configuracion-look-app.ps1."; return }
if (-not (Test-Path (Join-Path $raiz "src\FamilySection.tsx"))) { Mal "No encuentro src\FamilySection.tsx en esta carpeta."; return }
$cambios = @(
    @('App.tsx', 'import de la pantalla de Inicio', 'import { CabeceraGrupo, enGrupo, GrupoActual, TarjetasConfiguracion, useSeVe, type GrupoConfiguracion } from "./src/GruposConfiguracion";
', 'import { BandaPermisos, BotonesInicio, CabeceraGrupo, CabeceraPantalla, enGrupo, GrupoActual, TarjetaTelefono, TarjetasConfiguracion, useSeVe, type GrupoConfiguracion } from "./src/GruposConfiguracion";
import { PaginaChequeo } from "./src/PaginaChequeo";
'),
    @('App.tsx', 'estado: tambien la pantalla de Configuracion', 'const [grupo, setGrupo] = useState<GrupoConfiguracion | null>(null);', 'const [grupo, setGrupo] = useState<GrupoConfiguracion | "configuracion" | null>(null);'),
    @('App.tsx', 'elegirGrupo acepta Configuracion', 'function elegirGrupo(nuevo: GrupoConfiguracion | null) {', 'function elegirGrupo(nuevo: GrupoConfiguracion | "configuracion" | null) {'),
    @('App.tsx', 'boton atras: de un grupo a las tarjetas, de las tarjetas al Inicio', '      elegirGrupo(null);
      return true;', '      elegirGrupo(grupo === "configuracion" || grupo === "perfil" ? null : "configuracion");
      return true;'),
    @('App.tsx', 'la X solo en el Inicio', '      {onCancel ? (
        // Antes la ', '      {onCancel && grupoActual === null ? (
        // Antes la '),
    @('App.tsx', 'la X mas chica: forma y ancho', '    borderRadius: 18,
    height: 36,
    justifyContent: "center",
    left: 16,
    position: "absolute",
    top: Platform.OS === "android" ? 18 : 8,
    width: 36,', '    borderRadius: 15,
    height: 30,
    justifyContent: "center",
    left: 16,
    position: "absolute",
    top: Platform.OS === "android" ? 18 : 8,
    width: 30,'),
    @('App.tsx', 'la X mas chica: signo', 'closeSettingsButtonText: { color: P.texto, fontSize: 18, fontWeight: "900" },', 'closeSettingsButtonText: { color: P.texto, fontSize: 15, fontWeight: "900" },'),
    @('App.tsx', 'Inicio: espacio arriba para que la X no tape la marca', '            <>
          <Text style={styles.brand}>OJO GUARD', '            <>
          {!firstRun ? <View style={{ height: 34 }} /> : null}
          <Text style={styles.brand}>OJO GUARD'),
    @('App.tsx', 'el titulo Configuracion solo en el primer arranque', ('          <Text style={styles.setupTitle}>
            {firstRun ? "Preparar este tel' + [char]0x00e9 + 'fono" : "Configuraci' + [char]0x00f3 + 'n"}
          </Text>
'), ('          {firstRun ? <Text style={styles.setupTitle}>Preparar este tel' + [char]0x00e9 + 'fono</Text> : null}
')),
    @('App.tsx', 'cabecera de Configuracion y de cada grupo', '            <CabeceraGrupo paleta={P} android={Platform.OS === "android"} grupo={grupoActual} onVolver={() => elegirGrupo(null)} />
          )}
', '            <CabeceraGrupo paleta={P} android={Platform.OS === "android"} grupo={grupoActual} onVolver={() => elegirGrupo(grupoActual === "perfil" ? null : "configuracion")} />
          )}
'),
    @('App.tsx', 'las pantallas: Inicio, Configuracion y Dr. Ojo Guard', '          {grupoActual === null ? (
            <TarjetasConfiguracion
              paleta={P}
              android={Platform.OS === "android"}
              nombre={draft.deviceName}
              correo={draft.alertEmail}
              enLinea={isOnline}
              conexion={remoteState}
              permisosEnOrden={
                avisoDePantallaCompleta === null || bateriaSinRestricciones === null || bloqueoDelTelefono === null
                  ? null
                  : [avisoDePantallaCompleta, bateriaSinRestricciones, reliabilityChecklist.hibernation, bloqueoDelTelefono].filter(Boolean).length
              }
              permisosTotal={4}
              intentos={evidenceAttempts.length}
              pendientes={pendingCount}
              cercania={draft.proximityMode === true}
              radioMetros={draft.proximityRadiusMeters ?? 10}
              onElegir={elegirGrupo}
            />
          ) : null}
', '          {grupoActual === null ? (
            <>
              <TarjetaTelefono
                paleta={P}
                nombre={draft.deviceName}
                correo={draft.alertEmail}
                enLinea={isOnline}
              />
              <BotonesInicio paleta={P} onPerfil={() => elegirGrupo("perfil")} onConfiguracion={() => elegirGrupo("configuracion")} />
              <BandaPermisos
                paleta={P}
                android={Platform.OS === "android"}
                permisosEnOrden={permisosEnOrden}
                permisosTotal={4}
                soloSiFalta
                onPress={() => elegirGrupo("permisos")}
              />
            </>
          ) : null}

          {grupoActual === "configuracion" ? (
            <>
              <BandaPermisos
                paleta={P}
                android={Platform.OS === "android"}
                permisosEnOrden={permisosEnOrden}
                permisosTotal={4}
                onPress={() => elegirGrupo("permisos")}
              />
              <TarjetasConfiguracion
                paleta={P}
                android={Platform.OS === "android"}
                intentos={evidenceAttempts.length}
                pendientes={pendingCount}
                cercania={draft.proximityMode === true}
                radioMetros={draft.proximityRadiusMeters ?? 10}
                conexion={remoteState}
                onElegir={elegirGrupo}
              />
            </>
          ) : null}

          {grupoActual === "proteccion" ? (
            <PaginaChequeo
              paleta={P}
              botones={{
                secundario: styles.secondaryButton,
                secundarioTexto: styles.secondaryButtonText,
                ayuda: styles.fieldHelp,
              }}
            />
          ) : null}
'),
    @('App.tsx', 'cabecera de Configuracion: pantalla propia', '          ) : (
            <CabeceraGrupo paleta={P} android={Platform.OS === "android"} grupo={grupoActual}', ('          ) : grupoActual === "configuracion" ? (
            <CabeceraPantalla paleta={P} titulo="Configuraci' + [char]0x00f3 + 'n" onVolver={() => elegirGrupo(null)} />
          ) : (
            <CabeceraGrupo paleta={P} android={Platform.OS === "android"} grupo={grupoActual}')),
    @('App.tsx', 'cuantos permisos de Android estan en orden', '  return (
    <SafeAreaView style={styles.setupRoot}>
      <StatusBar style={temaActivo === "claro" ? "dark" : "light"} />
      <HelpButton context="settings" />', '  // Los cuatro permisos de la guia de Android; null si alguno todavia no se pudo leer.
  const permisosEnOrden =
    avisoDePantallaCompleta === null || bateriaSinRestricciones === null || bloqueoDelTelefono === null
      ? null
      : [avisoDePantallaCompleta, bateriaSinRestricciones, reliabilityChecklist.hibernation, bloqueoDelTelefono].filter(Boolean).length;

  return (
    <SafeAreaView style={styles.setupRoot}>
      <StatusBar style={temaActivo === "claro" ? "dark" : "light"} />
      <HelpButton context="settings" />'),
    @('App.tsx', 'Familia y amigos vuelve al Inicio', '          {!firstRun && enGrupo(grupoActual, "familia") ? (
            <FamilySection
              paleta={P}
              Seccion={SeccionDeFamilia}
', '          {!firstRun && grupoActual === null ? (
            <FamilySection
              paleta={P}
              Seccion={CollapsibleSection}
'),
    @('App.tsx', 'ya no hace falta marcar la seccion de Familia', '// Familia y amigos arma su propia seccion; esto la marca con su grupo para que solo se vea al abrir la tarjeta "Familia y SOS".
function SeccionDeFamilia(props: { title: string; subtitle?: string; defaultOpen?: boolean; children: ReactNode }) {
  return <CollapsibleSection grupo="familia" {...props} />;
}

function SeccionPlegable({', 'function SeccionPlegable({'),
    @('App.tsx', 'Mi perfil: datos del telefono', '<CollapsibleSection grupo="telefono" title="Datos del tel', '<CollapsibleSection grupo="perfil" title="Datos del tel'),
    @('App.tsx', 'Mi perfil: apariencia', '<CollapsibleSection grupo="telefono" title="Apariencia"', '<CollapsibleSection grupo="perfil" title="Apariencia"'),
    @('App.tsx', 'Mi perfil: estado del dispositivo', '{enGrupo(grupoActual, "telefono") ? (', '{enGrupo(grupoActual, "perfil") ? ('),
    @('App.tsx', 'Preferencias generales: tarjeta propia', '<CollapsibleSection grupo="telefono" title="Preferencias generales">', '<CollapsibleSection grupo="preferencias" title="Preferencias generales">'),
    @('App.tsx', 'Proteccion sin internet pasa a Preferencias como Envios pendientes', ('            grupo="fotos"
            title="Protecci' + [char]0x00f3 + 'n sin internet"
            subtitle={pendingCount > 0 ? `${pendingCount} pendiente${pendingCount === 1 ? "" : "s"}` : "Al d' + [char]0x00ed + 'a"}'), ('            grupo="preferencias"
            title="Env' + [char]0x00ed + 'os pendientes"
            subtitle={pendingCount > 0 ? `${pendingCount} por enviar` : "Todo enviado"}')),
    @('src\FamilySection.tsx', 'Familia: ya no trae el chequeo del Dr. Ojo Guard', 'import { ProteccionBlock } from "./ProteccionBlock";
import { fetchFamily', 'import { fetchFamily'),
    @('src\FamilySection.tsx', 'Familia: abierta en el Inicio', '    <Seccion
      title="Familia y amigos"', '    <Seccion
      defaultOpen
      title="Familia y amigos"'),
    @('src\FamilySection.tsx', 'Familia: el SOS sube, justo debajo de las personas', '      ))}

      {Platform.OS === "ios" && people.length > 0 && !siempre ? (', '      ))}

      <SosBlock enrollment={enrollment} visible={me.memberships > 0 || people.length > 0} paleta={P} botones={botones} />

      {Platform.OS === "ios" && people.length > 0 && !siempre ? ('),
    @('src\FamilySection.tsx', 'Familia: el chequeo y el SOS ya no estan al final', '      <ProteccionBlock enrollment={enrollment} visible={me.memberships > 0 || people.length > 0} paleta={P} botones={botones} />
      <SosBlock enrollment={enrollment} visible={me.memberships > 0 || people.length > 0} paleta={P} botones={botones} />

      {me.memberships > 0 ? (', '      {me.memberships > 0 ? ('),
    @('src\FamilySection.tsx', 'Mapa: volver de Google Maps no manda a la pantalla de bloqueo', '  void Linking.openURL(`https://www.google.com/maps/search/?api=1&query=${lat},${lng}`).catch(() => undefined);', '  // Volver de Google Maps no tiene que mandar la app a la pantalla de bloqueo.
  markPendingSystemActivity();
  void Linking.openURL(`https://www.google.com/maps/search/?api=1&query=${lat},${lng}`).catch(() => undefined);')
)
$descargas = @(
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/b015aa90f8be0ced986c0c6d4415aff71f3e57a2/scripts/familia/GruposConfiguracion.tsx", "src\GruposConfiguracion.tsx", "03a0d8b20db4f683f891a1838722b1866c73c940cf0b2737c0ed561af9882e15"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/b015aa90f8be0ced986c0c6d4415aff71f3e57a2/scripts/familia/PaginaChequeo.tsx", "src\PaginaChequeo.tsx", "47a8c6e9247d7be8aa3c5e2a09aedb6698d04c28c21d97d3a9f783f2f9d39934"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/b015aa90f8be0ced986c0c6d4415aff71f3e57a2/scripts/familia/ProteccionBlock.tsx", "src\ProteccionBlock.tsx", "6d4a5d85fe3f9dc0b5018bcc5a271eb20031b44372ad7d59223745278837fcc6"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/b015aa90f8be0ced986c0c6d4415aff71f3e57a2/scripts/familia/iconos/config-tuerca.png", "assets\config-tuerca.png", "9d6eb9a07e95b569c68b9be12e3bd92e0d80b4de926898c353d318ca35308d79"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/b015aa90f8be0ced986c0c6d4415aff71f3e57a2/scripts/familia/iconos/config-chequeo.png", "assets\config-chequeo.png", "3c09ba1ee147a7fa2f6da290e246218c3786b23eab0672406e80b21dfb5a4e53"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/b015aa90f8be0ced986c0c6d4415aff71f3e57a2/scripts/familia/iconos/config-perfil.png", "assets\config-perfil.png", "5886a1f4f1537d7c4c08d177c03d4dbd0bcf24537f58e2f4a0052b93fc614272"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/b015aa90f8be0ced986c0c6d4415aff71f3e57a2/scripts/familia/iconos/config-ajustes.png", "assets\config-ajustes.png", "a231cf478ad5178721f8f226bfae69430b4622a8016138f2d6fccc8b2cd56db0")
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
    if (Test-Path ($ruta + ".bak-inicio")) { Mal ("Ya existe " + $t + ".bak-inicio. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-inicio"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-inicio): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-inicio") -Destination $ruta -Force }
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
Ok "LISTO: la app compila bien. Sale en la PROXIMA build (Android y iPhone)."
Write-Host ""
