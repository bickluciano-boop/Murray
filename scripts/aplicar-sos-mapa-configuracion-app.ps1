# aplicar-sos-mapa-configuracion-app.ps1 - SOS y Configuracion (despues de aplicar-familia-proteccion-app.ps1). Tres cosas en un solo paso:
#  - Tocar el aviso de SOS que le llega a la familia abre el mapa del telefono (Apple Maps en iPhone, Google Maps en Android) con la
#    ubicacion mas nueva de la persona. Hace falta tambien aplicar-sos-mapa-panel.ps1 en el panel.
#  - Configuracion como acordeon: todo arranca cerrado y al abrir una seccion se cierran las demas (la guia del primer arranque y los
#    avisos pendientes siguen abiertos cuando hace falta). Las instrucciones del SOS y el detalle de "Mi proteccion" quedan plegados.
#  - El texto del boton rojo ("Mantene apretado 3 segundos") ya no se corta.
# Crea src\Plegable.tsx y src\sosMapa.ts; reemplaza src\SosBlock.tsx y src\ProteccionBlock.tsx; toca App.tsx y src\FamilySection.tsx.
# Va en la carpeta de la APP (la que tiene app.json). Respaldo .bak-cfg. Es solo codigo de la app (nada nativo): sale en la PROXIMA
# build, en Android y en iPhone.
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
if (-not (Test-Path (Join-Path $raiz "src\ProteccionBlock.tsx"))) { Mal "Primero corre aplicar-familia-proteccion-app.ps1."; return }
if (Test-Path (Join-Path $raiz "src\Plegable.tsx")) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if (-not (Test-Path (Join-Path $raiz "App.tsx"))) { Mal "No encuentro App.tsx en esta carpeta."; return }
$cambios = @(
    @('App.tsx', 'acordeon: guardar cual seccion esta abierta', 'function Field({ label, ...inputProps }: FieldProps) {
', '// Configuracion como acordeon: al abrir una seccion se cierran las demas, asi la pantalla no es una tira interminable. Todo
// arranca cerrado, salvo la primera seccion que pida `defaultOpen` (la guia del primer arranque, avisos pendientes). Al salir
// de Configuracion se olvida cual estaba abierta.
let seccionAbierta: string | null = null;
let seccionReclamada = false;
const oyentesDeSeccion = new Set<() => void>();

function abrirSeccion(titulo: string | null) {
  seccionAbierta = titulo;
  oyentesDeSeccion.forEach((avisar) => avisar());
}

function useSeccionAbierta(titulo: string, abiertaAlInicio: boolean) {
  const [, setCuenta] = useState(0);
  useState(() => {
    if (abiertaAlInicio && !seccionReclamada) {
      seccionReclamada = true;
      seccionAbierta = titulo;
    }
    return null;
  });
  useEffect(() => {
    const redibujar = () => setCuenta((n) => n + 1);
    oyentesDeSeccion.add(redibujar);
    return () => {
      oyentesDeSeccion.delete(redibujar);
      if (oyentesDeSeccion.size === 0) {
        seccionAbierta = null;
        seccionReclamada = false;
      }
    };
  }, []);
  return seccionAbierta === titulo;
}

function Field({ label, ...inputProps }: FieldProps) {
'),
    @('App.tsx', 'acordeon: el estado de cada seccion', '  const [open, setOpen] = useState(defaultOpen);
', '  const open = useSeccionAbierta(title, defaultOpen);
'),
    @('App.tsx', 'acordeon: abrir una cierra las otras', '        onPress={() => setOpen((value) => !value)}
', '        onPress={() => abrirSeccion(open ? null : title)}
'),
    @('App.tsx', 'la pantalla no salta al cerrarse una seccion de arriba', '<ScrollView contentContainerStyle={styles.setupContent}>', '<ScrollView contentContainerStyle={styles.setupContent} maintainVisibleContentPosition={{ minIndexForVisible: 0 }}>'),
    @('App.tsx', 'guia de Android cerrada salvo en el primer arranque', '              defaultOpen
              title="Gu', '              defaultOpen={firstRun}
              title="Gu'),
    @('App.tsx', 'Datos del telefono cerrado', '<CollapsibleSection defaultOpen title="Datos del tel', '<CollapsibleSection title="Datos del tel'),
    @('App.tsx', 'Modo perdido cerrado', '<CollapsibleSection defaultOpen title="Modo perdido ', '<CollapsibleSection title="Modo perdido '),
    @('App.tsx', 'Claves de acceso cerrado', '<CollapsibleSection defaultOpen title="Claves de acceso">', '<CollapsibleSection title="Claves de acceso">'),
    @('App.tsx', 'Evidencia y ubicacion cerrado', '<CollapsibleSection defaultOpen title="Evidencia y ubicaci', '<CollapsibleSection title="Evidencia y ubicaci'),
    @('src\FamilySection.tsx', 'Familia y amigos cerrado', '    <Seccion
      defaultOpen
      title="Familia y amigos"', '    <Seccion
      title="Familia y amigos"')
)
$descargas = @(
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/ff9c95852976cc10edb2e742901ce2464389d2a6/scripts/familia/Plegable.tsx", "src\Plegable.tsx", "5c61329eaabc09991704a22c30b4997c5e7d059d2aebdd18a43f60b99ce2910f"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/ff9c95852976cc10edb2e742901ce2464389d2a6/scripts/familia/sosMapa.ts", "src\sosMapa.ts", "bfee75b99ebb5a2c62a6845ded6b777f11897dbff05aebbf6fc8c2bce737969d"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/ff9c95852976cc10edb2e742901ce2464389d2a6/scripts/familia/SosBlock.tsx", "src\SosBlock.tsx", "16bf39ba21ea9e116f61007100e16cd9f393e23cbd7c908a698ad2675fe1c775"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/ff9c95852976cc10edb2e742901ce2464389d2a6/scripts/familia/ProteccionBlock.tsx", "src\ProteccionBlock.tsx", "f2aad5a1cdbeb28964806647a37e391d83b6a7b97ecc5945ed8e114afc6752b9")
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
    if (Test-Path ($ruta + ".bak-cfg")) { Mal ("Ya existe " + $t + ".bak-cfg. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-cfg"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-cfg): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-cfg") -Destination $ruta -Force }
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
