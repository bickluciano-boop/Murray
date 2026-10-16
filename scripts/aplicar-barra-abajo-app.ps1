# aplicar-barra-abajo-app.ps1 - La barra de abajo con el SOS cuadradito, Familia dentro de Ajustes y mucho mas mapa en el Inicio.
# Pedidos de Luciano (16/10/2026), mirando el mapa nuevo en el telefono:
#  - EL MAPA QUEDABA MUY CHICO. Los 5 iconos (Inicio, Perfil, Ajustes, Panel) pasan ABAJO, en una sola linea, y el SOS entra en esa misma linea como
#    cuadradito rojo con "SOS" y "3 s" (se mantiene apretado 3 segundos, igual que antes; cuando sale pasa a "Estoy bien" y el aviso de a quien se
#    le aviso flota arriba de la barra). Se saca la franja ancha del SOS de abajo del mapa. "Android Luciano - En linea - bateria" queda chico, en el
#    renglon de arriba entre la X y la ayuda (?). El SOS esta a mano en TODAS las pantallas, no solo en el Inicio. Si la app no esta en una familia
#    no aparece el cuadradito. Mientras se escribe con el teclado, la barra se esconde.
#  - FAMILIA Y AMIGOS REPETIA EL MAPA. Ya no es un boton de la barra: pasa a ser una tarjeta ancha arriba de Ajustes. Adentro quedan solo las
#    cosas que el mapa no hace: cuantas personas comparten con vos, pausar mi ubicacion, el SOS y sus ayudas para pedirlo sin abrir la app,
#    unirme con un codigo y salir de una familia. Las personas se ven y se suman (boton "Sumar") en el mapa del Inicio.
# Cambia src\GruposConfiguracion.tsx, src\SosBlock.tsx, src\InicioMapa.tsx y src\FamiliaPantalla.tsx, y toca App.tsx. Va en la carpeta de la APP (la que tiene
# app.json). Respaldo .bak-barraabajo. Es solo codigo de la app (nada nativo): sale en la PROXIMA build.
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
if ((Contar $appTexto 'BarraInferior') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $appTexto 'src/FamiliaPantalla') -eq 0) { Mal "Falta aplicar antes aplicar-familia-pantalla-app.ps1."; return }
if ((Contar $appTexto 'BarraSuperior') -eq 0) { Mal "Falta aplicar antes la barra de arriba (aplicar-barra-superior-app.ps1)."; return }
$cambios = @(
    @('App.tsx', 'imports: barra de abajo', 'import { BandaPermisos, BarraSuperior, BotonesInicio, CabeceraGrupo, CabeceraPantalla, enGrupo, GrupoActual, TarjetaTelefono, TarjetasConfiguracion, useSeVe, type GrupoConfiguracion, type SeccionBarra } from "./src/GruposConfiguracion";', 'import { BandaPermisos, BarraInferior, BotonesInicio, CabeceraGrupo, CabeceraPantalla, enGrupo, GrupoActual, TarjetaTelefono, TarjetasConfiguracion, useSeVe, type GrupoConfiguracion, type SeccionBarra } from "./src/GruposConfiguracion";'),
    @('App.tsx', 'imports: el SOS de la barra', 'import { InicioMapa } from "./src/InicioMapa";', 'import { InicioMapa } from "./src/InicioMapa";
import { SosEnBarra } from "./src/SosBlock";'),
    @('App.tsx', 'Familia es un grupo de Ajustes', '  const seccionActual: SeccionBarra = grupoActual === null ? "inicio" : grupoActual === "familia" ? "familia" : grupoActual === "perfil" ? "perfil" : "configuracion";', '  const seccionActual: SeccionBarra = grupoActual === null ? "inicio" : grupoActual === "perfil" ? "perfil" : "configuracion";'),
    @('App.tsx', 'la barra de abajo (con el SOS)', '  function irA(destino: SeccionBarra) {
    elegirGrupo(destino === "inicio" ? null : destino);
  }', '  function irA(destino: SeccionBarra) {
    elegirGrupo(destino === "inicio" ? null : destino);
  }
  // La barra de abajo, fija en todas las pantallas: el SOS (cuadradito rojo, solo si este telefono esta en una familia), Inicio, Perfil, Ajustes y Panel.
  const barraInferior = (
    <BarraInferior
      paleta={P}
      actual={seccionActual}
      onElegir={irA}
      onPanel={() => void abrirPanel()}
      abriendo={abriendoPanel}
      sos={<SosEnBarra paleta={P} botones={{ secundario: styles.secondaryButton, secundarioTexto: styles.secondaryButtonText, ayuda: styles.fieldHelp }} />}
    />
  );'),
    @('App.tsx', 'atras de Android: Familia vuelve a las tarjetas de Ajustes', '      elegirGrupo(grupo === "configuracion" || grupo === "perfil" || grupo === "familia" ? null : "configuracion");', '      elegirGrupo(grupo === "configuracion" || grupo === "perfil" ? null : "configuracion");'),
    @('App.tsx', 'Inicio: la barra pasa abajo', '        <BarraSuperior paleta={P} actual={seccionActual} onElegir={irA} onPanel={() => void abrirPanel()} abriendo={abriendoPanel} />
        <InicioMapa', '        <InicioMapa'),
    @('App.tsx', 'Inicio: la barra abajo del mapa', '            ) : null
          }
        />
      </SafeAreaView>
    );
  }

  return (', '            ) : null
          }
        />
        {barraInferior}
      </SafeAreaView>
    );
  }

  return ('),
    @('App.tsx', 'Ajustes y demas pantallas: lugar arriba en vez de la barra', '      {!firstRun ? <BarraSuperior paleta={P} actual={seccionActual} onElegir={irA} onPanel={() => void abrirPanel()} abriendo={abriendoPanel} /> : null}', '      {!firstRun ? <View style={{ height: 52 }} /> : null}'),
    @('App.tsx', 'Ajustes y demas pantallas: la barra abajo', '        </Modal>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

function AccuracyPreview(', '        </Modal>
      </KeyboardAvoidingView>
      {!firstRun ? barraInferior : null}
    </SafeAreaView>
  );
}

function AccuracyPreview('),
    @('App.tsx', 'Familia tiene Atras (vuelve a Ajustes)', 'onVolver={grupoActual === "perfil" || grupoActual === "familia" ? undefined : () => elegirGrupo("configuracion")} />', 'onVolver={grupoActual === "perfil" ? undefined : () => elegirGrupo("configuracion")} />')
)
$descargas = @(
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/da28200d0146235f0ac80d8eb154e55aae57f138/scripts/familia/GruposConfiguracion.tsx", "src\GruposConfiguracion.tsx", "c32d8b8bb63661a3c24e7be0268d5cf6853738f9af515c4bed8091018d1c4411"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/da28200d0146235f0ac80d8eb154e55aae57f138/scripts/familia/SosBlock.tsx", "src\SosBlock.tsx", "be3d953af3e3edbfe3cfc6f9d2b3f009a6042bdd98e10eeb74e50adc114585c0"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/da28200d0146235f0ac80d8eb154e55aae57f138/scripts/familia/InicioMapa.tsx", "src\InicioMapa.tsx", "d0c0d8e373ff66e73aa22ce28a3ac0e83203919ffc9ed23ffa5b191a82e7f1c4"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/da28200d0146235f0ac80d8eb154e55aae57f138/scripts/familia/FamiliaPantalla.tsx", "src\FamiliaPantalla.tsx", "467b6b0296f6c6e391f60a67a29566e6fa1cf1f1235abe931be0ff5c14d49705")
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
    if (Test-Path ($ruta + ".bak-barraabajo")) { Mal ("Ya existe " + $t + ".bak-barraabajo. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-barraabajo"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-barraabajo): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-barraabajo") -Destination $ruta -Force }
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
