# aplicar-arranque-app.ps1 - App Ojo Guard: bienvenida (13 diapositivas), pasos de identidad y acceso nuevo.
# Luciano (22/10/2026): bienvenida para el usuario nuevo, foto de perfil, foto del documento (DNI o pasaporte) y foto de la cara, todo obligatorio; "lo de empresa no va mas".
#  - Bienvenida: 13 diapositivas, una sola vez, antes del acceso (src/Bienvenida.tsx).
#  - Despues de abrir la cuenta: foto de perfil, foto del documento y foto de la cara (src/ArranqueIdentidad.tsx). No se pueden saltar.
#    Las fotos quedan guardadas en el telefono con estado "pendiente de verificar": la comparacion entre la cara y el documento NO existe todavia.
#  - Acceso: arranca como prueba de 3 dias; la tarjeta Empresa se esconde (su codigo queda). Logo arriba. Campos y boton principal mas redondeados.
#  - Quien ya tiene la app abierta con su cuenta NO ve nada de esto: solo el usuario nuevo.
# Cambia App.tsx y agrega 3 archivos en src y el logo en assets. Va en la carpeta de la APP (la que tiene app.json). Respaldo .bak-arranque. Sale en la PROXIMA build.
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
if (-not (Test-Path (Join-Path $raiz "src"))) { Mal "No encuentro la carpeta src."; return }
if ((Contar (Leer (Join-Path $raiz "App.tsx")).texto 'ojo_bienvenida_vista_v1') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
$cambios = @(
    @('App.tsx', 'importar la bienvenida y los pasos de identidad', 'import { PaginaChequeo } from "./src/PaginaChequeo";
', 'import { PaginaChequeo } from "./src/PaginaChequeo";
import { Bienvenida } from "./src/Bienvenida";
import { ArranqueIdentidad, cargarIdentidad } from "./src/ArranqueIdentidad";
'),
    @('App.tsx', 'pantallas nuevas: bienvenida e identidad', 'type Screen = "loading" | "access" | "setup" | "guard" | "settings";', 'type Screen = "loading" | "welcome" | "access" | "identity" | "setup" | "guard" | "settings";'),
    @('App.tsx', 'constantes: Empresa escondida y marca de bienvenida vista', 'const APP_VERSION = Constants.expoConfig?.version ?? "0.0.0";
', 'const APP_VERSION = Constants.expoConfig?.version ?? "0.0.0";
// La opcion Empresa ya no se ofrece al abrir la cuenta. El codigo de Empresa sigue en la app: solo se esconde la tarjeta.
const MOSTRAR_ACCESO_EMPRESA = false;
// Se guarda al terminar la bienvenida, para mostrarla una sola vez.
const CLAVE_BIENVENIDA_VISTA = "ojo_bienvenida_vista_v1";
'),
    @('App.tsx', 'el acceso arranca como prueba de 3 dias', 'useState<AccessType | null>(null)', 'useState<AccessType | null>("trial")'),
    @('App.tsx', 'primer arranque: bienvenida antes del acceso', '        if (!stored) {
          setScreen("access");
          return;
        }
', '        if (!stored) {
          void AsyncStorage.getItem(CLAVE_BIENVENIDA_VISTA).then(
            (visto) => setScreen(visto === "1" ? "access" : "welcome"),
            () => setScreen("access"),
          );
          return;
        }
'),
    @('App.tsx', 'despues del acceso: pasos de identidad si faltan', 'if (screen === "access") setScreen("setup");', 'if (screen === "access") {
        void cargarIdentidad().then((identidad) => setScreen(identidad ? "setup" : "identity"));
      }'),
    @('App.tsx', 'mostrar la bienvenida y los pasos de identidad', '  if (screen === "access") {
    return (
      <AccessScreen
', '  if (screen === "welcome") {
    return (
      <Bienvenida
        noche={temaActivo === "oscuro"}
        onTerminar={() => {
          void AsyncStorage.setItem(CLAVE_BIENVENIDA_VISTA, "1").catch(() => undefined);
          setScreen("access");
        }}
        paleta={P}
      />
    );
  }

  if (screen === "identity") {
    return (
      <ArranqueIdentidad
        noche={temaActivo === "oscuro"}
        onTerminar={() => setScreen("setup")}
        paleta={P}
      />
    );
  }

  if (screen === "access") {
    return (
      <AccessScreen
'),
    @('App.tsx', 'acceso: logo y titulo', ('          <Text style={styles.brand}>OJO GUARD' + [char]0x00ae + '</Text>
          <Text style={styles.versionLabel}>VERSI' + [char]0x00d3 + 'N {APP_VERSION}</Text>
          <Text style={styles.setupTitle}>Eleg' + [char]0x00ed + ' c' + [char]0x00f3 + 'mo ingresar</Text>
'), ('          <Image
            resizeMode="contain"
            source={require("./assets/ojo-logo.png")}
            style={{ height: 58, width: 96 }}
          />
          <Text style={styles.brand}>OJO GUARD' + [char]0x00ae + '</Text>
          <Text style={styles.versionLabel}>VERSI' + [char]0x00d3 + 'N {APP_VERSION}</Text>
          <Text style={styles.setupTitle}>Cre' + [char]0x00e1 + ' tu cuenta o ingres' + [char]0x00e1 + '</Text>
')),
    @('App.tsx', 'acceso: etiqueta del primer paso', ('1 ' + [char]0x00b7 + ' ELEG' + [char]0x00cd + ' EL TIPO DE ACCESO'), ('1 ' + [char]0x00b7 + ' TU ACCESO')),
    @('App.tsx', 'acceso: Empresa escondida (abre)', '          <Pressable
            onPress={() => onAccessType("company")}
', '          {MOSTRAR_ACCESO_EMPRESA ? (
          <Pressable
            onPress={() => onAccessType("company")}
'),
    @('App.tsx', 'acceso: Empresa escondida (cierra)', '          </Pressable>
          <Pressable
            onPress={() => onAccessType("trial")}
', '          </Pressable>
          ) : null}
          <Pressable
            onPress={() => onAccessType("trial")}
'),
    @('App.tsx', 'formularios: campos mas redondeados', '    borderRadius: 14,
    borderWidth: 1,
    color: P.texto,
    fontSize: 16,
    paddingHorizontal: 16,
    paddingVertical: 15,
', '    borderRadius: 18,
    borderWidth: 1,
    color: P.texto,
    fontSize: 16,
    paddingHorizontal: 16,
    paddingVertical: 15,
'),
    @('App.tsx', 'formularios: boton principal redondeado', '    backgroundColor: P.doradoRelleno,
    borderRadius: 14,
    marginTop: 4,
    paddingVertical: 16,
', '    backgroundColor: P.doradoRelleno,
    borderRadius: 26,
    marginTop: 4,
    paddingVertical: 16,
')
)
$descargas = @(
    @('https://raw.githubusercontent.com/bickluciano-boop/Murray/162e953aea345487ec9bc9924b988224b0686386/scripts/app/arranque/Bienvenida.tsx', 'src/Bienvenida.tsx', '899cc0f23bba0cbf9715f5453ee1f4aec90cf8b85bafd7c1cea2e828694bf732'),
    @('https://raw.githubusercontent.com/bickluciano-boop/Murray/162e953aea345487ec9bc9924b988224b0686386/scripts/app/arranque/ArranqueIdentidad.tsx', 'src/ArranqueIdentidad.tsx', '478c083985abdea929ffa917741b6612d7f53e7939a2a75a92d762b95a6525db'),
    @('https://raw.githubusercontent.com/bickluciano-boop/Murray/162e953aea345487ec9bc9924b988224b0686386/scripts/app/arranque/Iconos.tsx', 'src/Iconos.tsx', '74f13ef1798b52f51cab295ff6127e137c8113534f13b9f9858605d4c41232e0'),
    @('https://raw.githubusercontent.com/bickluciano-boop/Murray/162e953aea345487ec9bc9924b988224b0686386/scripts/app/arranque/ojo-logo.png', 'assets/ojo-logo.png', 'c4cbb6bdf4296a372841eaf9941edd4ff192730df14eb7eadd9ead18c079cba1')
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
    $carpetaTmp = Split-Path -Parent $tmp; if (-not (Test-Path $carpetaTmp)) { New-Item -ItemType Directory -Path $carpetaTmp -Force | Out-Null }
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
    if (Test-Path ($ruta + ".bak-arranque")) { Mal ("Ya existe " + $t + ".bak-arranque. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-arranque"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-arranque): " + ($respaldados -join ", "))

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
foreach ($d in $descargas) { $dest = Join-Path $raiz $d[1]; $carpeta = Split-Path -Parent $dest; if (-not (Test-Path $carpeta)) { New-Item -ItemType Directory -Path $carpeta -Force | Out-Null }; Move-Item -LiteralPath ($dest + ".descarga") -Destination $dest -Force }

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-arranque") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "LISTO: la app tiene bienvenida, pasos de identidad y el acceso nuevo. Sale en la proxima build."
Avi "Las fotos de identidad quedan guardadas en el telefono, pendientes de verificar: la comparacion cara/documento todavia no esta conectada."
Write-Host ""
