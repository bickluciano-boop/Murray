# aplicar-configuracion-tarjetas-app.ps1 - Configuracion en cinco tarjetas grandes (paso 1 de ordenar la app).
# Es solo maquillaje: NO se saca ni se cambia ningun bloque, boton ni texto de Configuracion. Cada bloque de siempre se abre ahora
# desde su tarjeta: Claves y Seguridad, Fotos de Intrusos, Modo Perdido y Cercania, Mi Telefono y Fondo, y Permisos (de Android o del
# iPhone; en Android con el semaforo "N de 4"). Tocar una tarjeta muestra solo los bloques de ese grupo, con "Configuracion" para
# volver (el boton "atras" de Android tambien vuelve primero a las tarjetas). "Familia y amigos" y "Ojo Guard MS" quedan en la
# portada, debajo de las tarjetas. En el primer arranque ("Preparar este telefono") se ve todo junto, como siempre.
# Crea src\GruposConfiguracion.tsx y toca App.tsx. Va en la carpeta de la APP (la que tiene app.json). Respaldo .bak-grupos.
# Es solo codigo de la app (nada nativo): sale en la PROXIMA build, en Android y en iPhone.
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
if (Test-Path (Join-Path $raiz "src\GruposConfiguracion.tsx")) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if (-not (Test-Path (Join-Path $raiz "src\Plegable.tsx"))) { Mal "Primero corre aplicar-sos-mapa-configuracion-app.ps1."; return }
if (-not (Test-Path (Join-Path $raiz "App.tsx"))) { Mal "No encuentro App.tsx en esta carpeta."; return }
$cambios = @(
    @('App.tsx', 'import de las tarjetas', 'import { FamilySection } from "./src/FamilySection";
', 'import { FamilySection } from "./src/FamilySection";
import { CabeceraGrupo, enGrupo, GrupoActual, TarjetasConfiguracion, useSeVe, type GrupoConfiguracion } from "./src/GruposConfiguracion";
'),
    @('App.tsx', 'estado de las tarjetas en Configuracion', '}: SetupProps) {
  const [selectedAttempt, setSelectedAttempt] =
    useState<EvidenceAttempt | null>(null);
', '}: SetupProps) {
  const [selectedAttempt, setSelectedAttempt] =
    useState<EvidenceAttempt | null>(null);
  // Configuracion en tarjetas (ver src/GruposConfiguracion.tsx). En el primer arranque se ve todo junto, como siempre.
  const [grupo, setGrupo] = useState<GrupoConfiguracion | null>(null);
  const grupoActual = firstRun ? "todo" : grupo;
  const scrollRef = useRef<ScrollView>(null);
  function elegirGrupo(nuevo: GrupoConfiguracion | null) {
    reiniciarSecciones();
    setGrupo(nuevo);
    scrollRef.current?.scrollTo({ y: 0, animated: false });
  }
  // Al salir de Configuracion se olvida cual seccion estaba abierta.
  useEffect(() => () => reiniciarSecciones(), []);
  // El boton "atras" de Android vuelve primero a las tarjetas.
  useEffect(() => {
    if (Platform.OS !== "android" || grupo === null) return;
    const suscripcion = BackHandler.addEventListener("hardwareBackPress", () => {
      elegirGrupo(null);
      return true;
    });
    return () => suscripcion.remove();
  }, [grupo]);
'),
    @('App.tsx', 'pantalla de tarjetas: encabezado solo en la portada', '        <ScrollView contentContainerStyle={styles.setupContent} maintainVisibleContentPosition={{ minIndexForVisible: 0 }}>
          <Text style={styles.brand}>OJO GUARD', '        <ScrollView ref={scrollRef} contentContainerStyle={styles.setupContent} maintainVisibleContentPosition={{ minIndexForVisible: 0 }}>
          <GrupoActual.Provider value={grupoActual}>
          {grupoActual === null || grupoActual === "todo" ? (
            <>
          <Text style={styles.brand}>OJO GUARD'),
    @('App.tsx', 'tarjetas, cabecera de cada grupo y estado del dispositivo', '          ) : null}

          <DeviceStatusCard
            isOnline={isOnline}
            lastConnectionAt={lastConnectionAt}
            locationEnabled={draft.locationEnabled}
            oledMode={draft.oledMode !== false}
            preventiveMode={draft.preventiveMode !== false}
            proximityMode={draft.proximityMode === true}
            proximityRadiusMeters={draft.proximityRadiusMeters ?? 10}
          />
', '          ) : null}
            </>
          ) : (
            <CabeceraGrupo paleta={P} android={Platform.OS === "android"} grupo={grupoActual} onVolver={() => elegirGrupo(null)} />
          )}

          {grupoActual === null ? (
            <TarjetasConfiguracion
              paleta={P}
              android={Platform.OS === "android"}
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

          {enGrupo(grupoActual, "telefono") ? (
            <DeviceStatusCard
              isOnline={isOnline}
              lastConnectionAt={lastConnectionAt}
              locationEnabled={draft.locationEnabled}
              oledMode={draft.oledMode !== false}
              preventiveMode={draft.preventiveMode !== false}
              proximityMode={draft.proximityMode === true}
              proximityRadiusMeters={draft.proximityRadiusMeters ?? 10}
            />
          ) : null}
'),
    @('App.tsx', 'fin de la pantalla de tarjetas', '            usan.
          </Text>
        </ScrollView>
', '            usan.
          </Text>
          </GrupoActual.Provider>
        </ScrollView>
'),
    @('App.tsx', 'Familia y amigos solo en la portada', '          {!firstRun ? (
            <FamilySection', '          {!firstRun && grupoActual === null ? (
            <FamilySection'),
    @('App.tsx', 'Guia de Android: grupo permisos', '            <CollapsibleSection
              defaultOpen={firstRun}
', '            <CollapsibleSection
              grupo="permisos"
              defaultOpen={firstRun}
'),
    @('App.tsx', 'Protege tu iPhone: grupo permisos', '<CollapsibleSection defaultOpen={firstRun} title={"Proteg', '<CollapsibleSection grupo="permisos" defaultOpen={firstRun} title={"Proteg'),
    @('App.tsx', 'Datos del telefono: grupo telefono', '<CollapsibleSection title="Datos del tel', '<CollapsibleSection grupo="telefono" title="Datos del tel'),
    @('App.tsx', 'Modo perdido: grupo perdido', '<CollapsibleSection title="Modo perdido ', '<CollapsibleSection grupo="perdido" title="Modo perdido '),
    @('App.tsx', 'Apariencia: grupo telefono', '<CollapsibleSection title="Apariencia"', '<CollapsibleSection grupo="telefono" title="Apariencia"'),
    @('App.tsx', 'Claves de acceso: grupo claves', '<CollapsibleSection title="Claves de acceso">', '<CollapsibleSection grupo="claves" title="Claves de acceso">'),
    @('App.tsx', 'Evidencia y ubicacion: grupo claves', '<CollapsibleSection title="Evidencia y ubicaci', '<CollapsibleSection grupo="claves" title="Evidencia y ubicaci'),
    @('App.tsx', 'Modo cercania: grupo perdido', '<CollapsibleSection title="Modo cercan', '<CollapsibleSection grupo="perdido" title="Modo cercan'),
    @('App.tsx', 'Preferencias generales: grupo telefono', '<CollapsibleSection title="Preferencias generales">', '<CollapsibleSection grupo="telefono" title="Preferencias generales">'),
    @('App.tsx', 'Preparar autonomia: grupo permisos', '          <CollapsibleSection
            title="Preparar aut', '          <CollapsibleSection
            grupo="permisos"
            title="Preparar aut'),
    @('App.tsx', 'Deteccion de intentos: grupo claves', '            <CollapsibleSection
              title="Detecci', '            <CollapsibleSection
              grupo="claves"
              title="Detecci'),
    @('App.tsx', 'Modo personalizado: grupo permisos', '<CollapsibleSection title="Modo personalizado (Android)"', '<CollapsibleSection grupo="permisos" title="Modo personalizado (Android)"'),
    @('App.tsx', 'Proteccion sin internet: grupo fotos', '          <CollapsibleSection
            title="Protecci', '          <CollapsibleSection
            grupo="fotos"
            title="Protecci'),
    @('App.tsx', 'Intentos de entrada: grupo fotos', '          <CollapsibleSection
            title="Intentos de entrada"', '          <CollapsibleSection
            grupo="fotos"
            title="Intentos de entrada"'),
    @('App.tsx', 'Personas, dispositivos y articulos: grupo perdido', '          <TrackedSections
            items={trackedItems}
            onAdd={onAddTrackedItem}
            onMeasurements={onUpdateTrackedItems}
            proximityMode={draft.proximityMode === true}
            proximityRadiusMeters={draft.proximityRadiusMeters ?? 10}
          />
', '          {enGrupo(grupoActual, "perdido") ? (
            <TrackedSections
              items={trackedItems}
              onAdd={onAddTrackedItem}
              onMeasurements={onUpdateTrackedItems}
              proximityMode={draft.proximityMode === true}
              proximityRadiusMeters={draft.proximityRadiusMeters ?? 10}
            />
          ) : null}
'),
    @('App.tsx', 'acordeon: ya no se reinicia solo al quedar sin secciones', '    return () => {
      oyentesDeSeccion.delete(redibujar);
      if (oyentesDeSeccion.size === 0) {
        seccionAbierta = null;
        seccionReclamada = false;
      }
    };
', '    return () => {
      oyentesDeSeccion.delete(redibujar);
    };
'),
    @('App.tsx', 'acordeon: funcion para reiniciar', 'function abrirSeccion(titulo: string | null) {
  seccionAbierta = titulo;
  oyentesDeSeccion.forEach((avisar) => avisar());
}
', 'function abrirSeccion(titulo: string | null) {
  seccionAbierta = titulo;
  oyentesDeSeccion.forEach((avisar) => avisar());
}

// Se olvida cual estaba abierta: al entrar a un grupo de Configuracion, al volver a las tarjetas y al salir de Configuracion
// (la seccion que pida `defaultOpen` se abre sola al armarse).
function reiniciarSecciones() {
  seccionAbierta = null;
  seccionReclamada = false;
}
'),
    @('App.tsx', 'CollapsibleSection: solo se arma en su grupo', 'function CollapsibleSection({
  title,
  subtitle,
  defaultOpen = false,
  children,
}: {
  title: string;
  subtitle?: string;
  defaultOpen?: boolean;
  children: ReactNode;
}) {
  const open = useSeccionAbierta(title, defaultOpen);
', 'function CollapsibleSection({
  title,
  subtitle,
  defaultOpen = false,
  grupo,
  children,
}: {
  title: string;
  subtitle?: string;
  defaultOpen?: boolean;
  grupo?: GrupoConfiguracion;
  children: ReactNode;
}) {
  // Configuracion en tarjetas (src/GruposConfiguracion.tsx): la seccion solo se arma cuando se esta mirando su grupo.
  const seVe = useSeVe(grupo);
  if (!seVe) return null;
  return (
    <SeccionPlegable title={title} subtitle={subtitle} defaultOpen={defaultOpen}>
      {children}
    </SeccionPlegable>
  );
}

function SeccionPlegable({
  title,
  subtitle,
  defaultOpen,
  children,
}: {
  title: string;
  subtitle?: string;
  defaultOpen: boolean;
  children: ReactNode;
}) {
  const open = useSeccionAbierta(title, defaultOpen);
')
)
$descargas = @(
    ,@("https://raw.githubusercontent.com/bickluciano-boop/Murray/d707a0646e23b976509877265895b5df764188ae/scripts/familia/GruposConfiguracion.tsx", "src\GruposConfiguracion.tsx", "e07e94369635bc14023638119d1046acb89caafda76f07f23edd7cf576c97f2b")
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
    if (Test-Path ($ruta + ".bak-grupos")) { Mal ("Ya existe " + $t + ".bak-grupos. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-grupos"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-grupos): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-grupos") -Destination $ruta -Force }
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
