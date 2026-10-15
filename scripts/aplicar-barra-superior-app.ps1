# aplicar-barra-superior-app.ps1 - La barra de arriba fija en todas las pantallas de la app, el SOS sin repetir y ajustes del Inicio.
# Pedidos de Luciano (15/10/2026) al probar la build con el mapa:
#  - BARRA FIJA ARRIBA, como las pestanas de Ojo Guard MS: Inicio, Familia, Perfil, Ajustes y "Panel" (abre Ojo Guard MS entrando directo,
#    sin pasar por Configuracion). Queda fija al cambiar de pantalla y marca en cual se esta. Por eso las pantallas Familia, Perfil y
#    Configuracion ya no tienen "Atras" (los grupos de Configuracion si: vuelven a Configuracion).
#  - El boton de SOS estaba repetido: ahora vive solo en el Inicio (la franja roja de abajo). La pantalla Familia trae las ayudas para
#    pedir ayuda sin abrir la app y un recordatorio de donde esta el boton.
#  - El Inicio queda con una linea (nombre del telefono, "En linea" y bateria), el mapa y el SOS.
#  - En Familia, "Mapa >" (al lado de cada persona) lleva al mapa del Inicio, en vez de abrir Google Maps con un pin suelto y coordenadas.
# Cambia src\GruposConfiguracion.tsx, src\SosBlock.tsx y src\InicioMapa.tsx, suma assets\config-inicio.png y toca App.tsx. Va en la carpeta
# de la APP (la que tiene app.json). Respaldo .bak-barra. Es solo codigo de la app (nada nativo): sale en la PROXIMA build.
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
if ((Contar (Leer (Join-Path $raiz "App.tsx")).texto 'BarraSuperior') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if (-not (Test-Path (Join-Path $raiz "src\InicioMapa.tsx"))) { Mal "Falta aplicar antes el Inicio con el mapa (aplicar-inicio-mapa-app.ps1)."; return }
if (-not (Test-Path (Join-Path $raiz "src\GruposConfiguracion.tsx")) -or -not (Test-Path (Join-Path $raiz "src\FamilySection.tsx"))) { Mal "Faltan los scripts anteriores de Inicio y Configuracion."; return }
$cambios = @(
    @('App.tsx', 'import de la barra de arriba', 'import { BandaPermisos, BotonesInicio, CabeceraGrupo, CabeceraPantalla, enGrupo, GrupoActual, TarjetaTelefono, TarjetasConfiguracion, useSeVe, type GrupoConfiguracion } from "./src/GruposConfiguracion";', 'import { BandaPermisos, BarraSuperior, BotonesInicio, CabeceraGrupo, CabeceraPantalla, enGrupo, GrupoActual, TarjetaTelefono, TarjetasConfiguracion, useSeVe, type GrupoConfiguracion, type SeccionBarra } from "./src/GruposConfiguracion";'),
    @('App.tsx', 'barra de arriba: en que pantalla se esta y el boton Panel', '  // Al salir de Configuracion se olvida cual seccion estaba abierta.
  useEffect(() => () => reiniciarSecciones(), []);', '  // Al salir de Configuracion se olvida cual seccion estaba abierta.
  useEffect(() => () => reiniciarSecciones(), []);
  // La barra de arriba (Inicio, Familia, Perfil, Ajustes y Panel) queda fija en todas las pantallas. Todos los grupos de Configuracion
  // cuentan como "Ajustes". "Panel" abre Ojo Guard MS entrando directo; mientras pide el acceso dice "Abriendo...".
  const seccionActual: SeccionBarra = grupoActual === null ? "inicio" : grupoActual === "familia" ? "familia" : grupoActual === "perfil" ? "perfil" : "configuracion";
  const [abriendoPanel, setAbriendoPanel] = useState(false);
  async function abrirPanel() {
    if (abriendoPanel) return;
    setAbriendoPanel(true);
    try {
      await onOpenMs();
    } finally {
      setAbriendoPanel(false);
    }
  }
  function irA(destino: SeccionBarra) {
    elegirGrupo(destino === "inicio" ? null : destino);
  }'),
    @('App.tsx', 'barra de arriba en el Inicio (y el Inicio sin los botones de antes)', '        <InicioMapa
          paleta={P}
          tema={temaActivo === "claro" ? "claro" : "oscuro"}
          nombre={draft.deviceName}
          enLinea={isOnline}
          onPerfil={() => elegirGrupo("perfil")}
          onFamilia={() => elegirGrupo("familia")}
          onConfiguracion={() => elegirGrupo("configuracion")}
          onVincular={() => elegirGrupo("conexion")}
          onPanel={onOpenMs}
          botones={{', '        <BarraSuperior paleta={P} actual={seccionActual} onElegir={irA} onPanel={() => void abrirPanel()} abriendo={abriendoPanel} />
        <InicioMapa
          paleta={P}
          tema={temaActivo === "claro" ? "claro" : "oscuro"}
          nombre={draft.deviceName}
          enLinea={isOnline}
          onVincular={() => elegirGrupo("conexion")}
          botones={{'),
    @('App.tsx', 'barra de arriba en las demas pantallas', '      <KeyboardAvoidingView
        behavior={Platform.OS === "ios" ? "padding" : undefined}
        style={styles.setupRoot}
      >
        <ScrollView ref={scrollRef}', '      {!firstRun ? <BarraSuperior paleta={P} actual={seccionActual} onElegir={irA} onPanel={() => void abrirPanel()} abriendo={abriendoPanel} /> : null}
      <KeyboardAvoidingView
        behavior={Platform.OS === "ios" ? "padding" : undefined}
        style={styles.setupRoot}
      >
        <ScrollView ref={scrollRef}'),
    @('App.tsx', 'Configuracion sin Atras (la barra lleva a las otras pantallas)', ('<CabeceraPantalla paleta={P} titulo="Configuraci' + [char]0x00f3 + 'n" onVolver={() => elegirGrupo(null)} />'), ('<CabeceraPantalla paleta={P} titulo="Configuraci' + [char]0x00f3 + 'n" />')),
    @('App.tsx', 'Perfil y Familia sin Atras', 'onVolver={() => elegirGrupo(grupoActual === "perfil" || grupoActual === "familia" ? null : "configuracion")} />', 'onVolver={grupoActual === "perfil" || grupoActual === "familia" ? undefined : () => elegirGrupo("configuracion")} />'),
    @('App.tsx', 'Familia: Mapa lleva al mapa del Inicio (App)', '              Seccion={SeccionFamilia}', '              Seccion={SeccionFamilia}
              onVerEnMapa={() => elegirGrupo(null)}'),
    @('src\FamilySection.tsx', 'Familia: Mapa lleva al mapa del Inicio (tipo)', '  Seccion: ComponentType<{ title: string; subtitle?: string; defaultOpen?: boolean; children: ReactNode }>;', ('  Seccion: ComponentType<{ title: string; subtitle?: string; defaultOpen?: boolean; children: ReactNode }>;
  /** Al tocar "Mapa ' + [char]0x203a + '" en una persona: lleva al mapa del Inicio (si no se pasa, se abre Google Maps afuera, como antes). */
  onVerEnMapa?: () => void;')),
    @('src\FamilySection.tsx', 'Familia: Mapa lleva al mapa del Inicio (funcion)', 'export function FamilySection({ paleta: P, Seccion, botones }: Props) {', 'export function FamilySection({ paleta: P, Seccion, botones, onVerEnMapa }: Props) {'),
    @('src\FamilySection.tsx', 'Familia: Mapa lleva al mapa del Inicio (toque)', 'onPress={() => abrirEnMapa(p)}', 'onPress={() => (onVerEnMapa ? onVerEnMapa() : abrirEnMapa(p))}')
)
$descargas = @(
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/ac13e5fb35ba35ac9fb1ad224f21161a8f90dc97/scripts/familia/GruposConfiguracion.tsx", "src\GruposConfiguracion.tsx", "d436027d5af8bffa1478971fa6789f339251739ae5aba493193aae2c94951657"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/ac13e5fb35ba35ac9fb1ad224f21161a8f90dc97/scripts/familia/SosBlock.tsx", "src\SosBlock.tsx", "62d13d6e9ef3945ab53b548b193939d8ef284893c6db81261972055a41234102"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/ac13e5fb35ba35ac9fb1ad224f21161a8f90dc97/scripts/familia/InicioMapa.tsx", "src\InicioMapa.tsx", "aa8c0fc4b39669346238779c38f3279014dd0fdeb44752c95e817c3503481396"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/ac13e5fb35ba35ac9fb1ad224f21161a8f90dc97/scripts/familia/iconos/config-inicio.png", "assets\config-inicio.png", "5e8766b48cf69e33c357ff22552b47a104d7068b28ba09b4bf37470ed50ac360")
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
    if (Test-Path ($ruta + ".bak-barra")) { Mal ("Ya existe " + $t + ".bak-barra. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-barra"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-barra): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-barra") -Destination $ruta -Force }
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
