# aplicar-configuracion-look-app.ps1 - La app abre CLARA y Configuracion con la portada nueva (paso 3a de ordenar la app).
#  - Tema claro por defecto; el oscuro queda como "Modo noche" (interruptor en Configuracion > Mi Telefono y Fondo > Apariencia).
#    Quien ya eligio un tema lo conserva. La barra de arriba del telefono (hora, bateria) se ve bien en los dos temas. La pantalla
#    de bloqueo sigue oscura.
#  - Portada de Configuracion: tarjeta del telefono (nombre, "En linea", bateria, correo), banda de permisos ("Permisos de Android:
#    4/4 OK") y cuatro tarjetas grandes con icono (llave, camara, radar, telefono). El texto de presentacion y el cartel de
#    administrador salen de la portada (el de administrador queda al pie); en el primer arranque todo sigue como siempre.
# Cambia src\GruposConfiguracion.tsx, suma cuatro iconos en assets\ y toca App.tsx. Va en la carpeta de la APP (la que tiene
# app.json). Respaldo .bak-look. Es solo codigo de la app (nada nativo): sale en la PROXIMA build, en Android y en iPhone.
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
if (Test-Path (Join-Path $raiz "assets\config-llave.png")) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if (-not (Test-Path (Join-Path $raiz "src\GruposConfiguracion.tsx"))) { Mal "Primero corre aplicar-configuracion-tarjetas-app.ps1 y aplicar-configuracion-limpieza-app.ps1."; return }
if (-not (Test-Path (Join-Path $raiz "assets"))) { Mal "No encuentro la carpeta assets en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "App.tsx")).texto 'import { Plegable } from "./src/Plegable";') -eq 0) { Mal "Primero corre aplicar-configuracion-limpieza-app.ps1."; return }
$cambios = @(
    @('App.tsx', 'portada: nombre, correo y conexion del telefono', '              android={Platform.OS === "android"}
              permisosEnOrden={
', '              android={Platform.OS === "android"}
              nombre={draft.deviceName}
              correo={draft.alertEmail}
              enLinea={isOnline}
              permisosEnOrden={
'),
    @('App.tsx', 'portada: sin texto de presentacion fuera del primer arranque (abre)', '          <Text style={styles.setupIntro}>
            {firstRun
', '          {firstRun ? (
            <>
          <Text style={styles.setupIntro}>
            {firstRun
'),
    @('App.tsx', 'portada: sin cartel de administrador fuera del primer arranque (cierra)', '          </View>
          {captureDiagnostic ? (
', '          </View>
            </>
          ) : null}
          {captureDiagnostic ? (
'),
    @('App.tsx', 'pie: el aviso de administrador pasa abajo', '            usan.
          </Text>
          </GrupoActual.Provider>
', '            usan.
          </Text>
          {!firstRun ? (
            <Text style={styles.privacy}>
              Esta pantalla solo se abre con tu clave de administrador, que nunca saca fotos ni registra evidencia.
            </Text>
          ) : null}
          </GrupoActual.Provider>
'),
    @('App.tsx', 'tema claro por defecto: variables', 'let temaActivo: Tema = "oscuro";
let P: Paleta = PALETAS.oscuro;
', 'let temaActivo: Tema = "claro";
let P: Paleta = PALETAS.claro;
'),
    @('App.tsx', 'tema claro por defecto: hoja de estilos', 'let styles = hojaOscura;
', 'let styles = hojaClara;
'),
    @('App.tsx', 'barra de estado segun el tema: carga', '        <ActivityIndicator color={P.doradoTexto} size="large" />
        <StatusBar style="light" />
', '        <ActivityIndicator color={P.doradoTexto} size="large" />
        <StatusBar style={temaActivo === "claro" ? "dark" : "light"} />
'),
    @('App.tsx', 'barra de estado segun el tema: acceso', '      <StatusBar style="light" />
      <HelpButton context="access" />
', '      <StatusBar style={temaActivo === "claro" ? "dark" : "light"} />
      <HelpButton context="access" />
'),
    @('App.tsx', 'barra de estado segun el tema: configuracion', '      <StatusBar style="light" />
      <HelpButton context="settings" />
', '      <StatusBar style={temaActivo === "claro" ? "dark" : "light"} />
      <HelpButton context="settings" />
'),
    @('App.tsx', 'Modo noche en Apariencia', '<CollapsibleSection grupo="telefono" title="Apariencia" subtitle="Fondo de pantalla y teclado">
            <View style={styles.wallpaperSettings}>
', '<CollapsibleSection grupo="telefono" title="Apariencia" subtitle="Modo noche, fondo de pantalla y teclado">
            <View style={[styles.temaFila, { borderTopWidth: 0, marginBottom: 14, marginTop: 0, paddingTop: 0 }]}>
              <View style={styles.temaTextos}>
                <Text style={styles.temaEtiqueta}>Modo noche</Text>
                <Text style={styles.temaAyuda}>
                  Fondo oscuro para usar de noche. La pantalla de bloqueo siempre es oscura.
                </Text>
              </View>
              <Switch
                onValueChange={(noche: boolean) => {
                  void guardarTema(noche ? "oscuro" : "claro");
                }}
                thumbColor={P.doradoRelleno}
                trackColor={{ false: P.bordeFuerte, true: P.doradoBorde }}
                value={temaActivo === "oscuro"}
              />
            </View>
            <View style={styles.wallpaperSettings}>
')
)
$descargas = @(
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/a674571aeec11f3d12a0d0c2c612664ecc80c381/scripts/familia/GruposConfiguracion.tsx", "src\GruposConfiguracion.tsx", "9515e9e2757b85930ddc896b88c8aa7124ea1fbf967c239167082101b8e48349"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/a674571aeec11f3d12a0d0c2c612664ecc80c381/scripts/familia/iconos/config-llave.png", "assets\config-llave.png", "3255284eae4e8adb39be86692ba08b0517985d7fbe24aeb7149238433e424ce1"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/a674571aeec11f3d12a0d0c2c612664ecc80c381/scripts/familia/iconos/config-camara.png", "assets\config-camara.png", "933f354c25932801711d57cf51cf9589b34b445222ae43d6bd1c92f26baa5377"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/a674571aeec11f3d12a0d0c2c612664ecc80c381/scripts/familia/iconos/config-radar.png", "assets\config-radar.png", "4b2b69dd74533ffc8defcc3a9c5425cd1c9585d3c83fc03665bfbd0c3e438528"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/a674571aeec11f3d12a0d0c2c612664ecc80c381/scripts/familia/iconos/config-telefono.png", "assets\config-telefono.png", "52dd9b444477cca9fa5dcf3e6b03f6a92b0590d811c8a3e0f7faa2653fcf6453")
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
    if (Test-Path ($ruta + ".bak-look")) { Mal ("Ya existe " + $t + ".bak-look. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-look"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-look): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-look") -Destination $ruta -Force }
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
