# aplicar-version-captura-app.ps1 - App (PROXIMA build): "Actualizar version" en Ajustes (Android), pasos de la captura de evidencia anotados y foto frontal entregada si se agota el tiempo, y sin el texto de Android del ahorro de bateria en iPhone.
# Luciano (27/10/2026): "ponen actualizar" en la app; la foto del iPhone fallo una vez por tiempo agotado sin dejar rastro; en el iPhone aparece texto de Android.
#  1) Ajustes > Revisar permisos: boton "Actualizar version" (solo Android). Consulta ojoguard.app/api/app/version; si el numero de build entre parentesis de la version publicada (ej. "0.9.2 (163)") es mayor al instalado, abre ojoguard.app/descargar.
#  2) Captura de evidencia (iPhone y Android): cada paso queda anotado y se ve en Registros tecnicos; si se agota el tiempo (30 s) y la foto frontal ya salio, se entrega esa; si no, el error dice en que paso se trabo (remote_capture_timeout:<paso>).
#  3) iPhone: en Ajustes ya no aparece el texto de Android sobre el ahorro de bateria.
# Requiere aplicar-captura-reintentos-app.ps1. Toca App.tsx. Va en la carpeta de la APP (la que tiene app.json). Respaldo .bak-version. Si la revision de tipos falla, deja todo como estaba.
# Es solo codigo de la app (nada nativo): sale en la PROXIMA build.
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
if ((Contar (Leer (Join-Path $raiz "App.tsx")).texto 'const CLAVE_PASOS_CAPTURA') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "App.tsx")).texto 'const esperas = Platform.OS === "ios"') -eq 0) { Mal "Falta aplicar primero aplicar-captura-reintentos-app.ps1. No toco nada."; return }
$cambios = @(
    @('App.tsx', 'ayudas del registro de pasos de la captura', 'const CLAVE_BIENVENIDA_VISTA = "ojo_bienvenida_vista_v1";', 'const CLAVE_BIENVENIDA_VISTA = "ojo_bienvenida_vista_v1";
// Pasos de la captura de evidencia, para soporte. En iPhone no hay registro nativo de camara: sin esto no se sabe en que paso se traba.
const CLAVE_PASOS_CAPTURA = "ojo_captura_pasos_v1";
async function anotarPasoCaptura(texto: string) {
  try {
    const previo = JSON.parse((await AsyncStorage.getItem(CLAVE_PASOS_CAPTURA)) ?? "[]") as string[];
    const nuevo = [`${new Date().toISOString()} ${Platform.OS} ${texto}`, ...previo].slice(0, 24);
    await AsyncStorage.setItem(CLAVE_PASOS_CAPTURA, JSON.stringify(nuevo));
  } catch {
    // El registro es solo para soporte: si falla, la captura sigue igual.
  }
}
async function leerPasosCaptura(): Promise<string[]> {
  try {
    const previo = JSON.parse((await AsyncStorage.getItem(CLAVE_PASOS_CAPTURA)) ?? "[]") as unknown;
    return Array.isArray(previo) ? previo.map((x) => String(x)) : [];
  } catch {
    return [];
  }
}
// Boton "Actualizar version" de Ajustes (Android): consulta la ultima version publicada en ojoguard.app.
const URL_VERSION_APP = "https://ojoguard.app/api/app/version";
const URL_DESCARGA_APP = "https://ojoguard.app/descargar";'),
    @('App.tsx', 'paso actual de la captura (referencia)', '  const frontPhotoRef = useRef<string | null>(null);', '  const frontPhotoRef = useRef<string | null>(null);
  const capturaPasoRef = useRef("sin empezar");'),
    @('App.tsx', 'pedido remoto: anota el primer paso', '        setCameraFacing("front");
        setAlertState("capturing");
        await startAudioEvidence();
        return await new Promise<{', '        setCameraFacing("front");
        setAlertState("capturing");
        await startAudioEvidence();
        capturaPasoRef.current = "esperando camara frontal";
        void anotarPasoCaptura("pedido remoto: esperando camara frontal");
        return await new Promise<{'),
    @('App.tsx', 'tiempo agotado: anota el paso y entrega la frontal si ya salio', '          const timeout = setTimeout(() => {
            remoteCaptureRef.current = null;
            setCameraActive(false);
            setAlertState("failed");
            void stopAudioEvidence();
            dismissFullScreenAlert();
            reject(new Error("remote_capture_timeout"));
          }, 30_000);', '          const timeout = setTimeout(() => {
            const paso = capturaPasoRef.current;
            const frontal = frontPhotoRef.current;
            frontPhotoRef.current = null;
            remoteCaptureRef.current = null;
            setCameraActive(false);
            void anotarPasoCaptura(`tiempo agotado en: ${paso}${frontal ? " (la frontal ya estaba: se entrega sola)" : ""}`);
            if (frontal) {
              // La foto frontal ya salio: se entrega aunque la trasera se haya trabado.
              void finalizeSecurityEvidence(frontal, null).then((evidencia) => {
                setAlertState("idle");
                resolve(evidencia);
              }, () => {
                setAlertState("failed");
                dismissFullScreenAlert();
                reject(new Error(`remote_capture_timeout:${paso}`));
              });
              dismissFullScreenAlert();
              return;
            }
            setAlertState("failed");
            void stopAudioEvidence();
            dismissFullScreenAlert();
            reject(new Error(`remote_capture_timeout:${paso}`));
          }, 30_000);'),
    @('App.tsx', 'camara lista: anota y marca el paso', 'onCameraReady={() => void captureSecurityEvidence()}', 'onCameraReady={() => {
              capturaPasoRef.current = cameraFacing === "front" ? "sacando foto frontal" : "sacando foto trasera";
              void anotarPasoCaptura(`camara ${cameraFacing === "front" ? "frontal" : "trasera"} lista`);
              void captureSecurityEvidence();
            }}'),
    @('App.tsx', 'reintentos: anota en que intento salio', '      if (intentoLogrado > 1) {', '      if (intentoLogrado > 1) {
        void anotarPasoCaptura(`foto ${cameraFacing}: salio en el intento ${intentoLogrado}`);'),
    @('App.tsx', 'frontal guardada: anota y marca el paso', '        frontPhotoRef.current = photo.base64;', '        frontPhotoRef.current = photo.base64;
        capturaPasoRef.current = "esperando camara trasera";
        void anotarPasoCaptura("foto frontal lista; esperando camara trasera");'),
    @('App.tsx', 'trasera lista: anota el guardado', '      const evidence = await finalizeSecurityEvidence(frontImageBase64, rearImageBase64);', '      capturaPasoRef.current = "guardando evidencia";
      const evidence = await finalizeSecurityEvidence(frontImageBase64, rearImageBase64);
      void anotarPasoCaptura("evidencia completa: frontal y trasera");'),
    @('App.tsx', 'errores de captura quedan anotados', '    } catch (error) {
      setCameraActive(false);
      const frontImageBase64 = frontPhotoRef.current;
      if (cameraFacing === "back" && frontImageBase64) {', '    } catch (error) {
      void anotarPasoCaptura(`error en ${capturaPasoRef.current}: ${error instanceof Error ? error.message : String(error)}`);
      setCameraActive(false);
      const frontImageBase64 = frontPhotoRef.current;
      if (cameraFacing === "back" && frontImageBase64) {'),
    @('App.tsx', 'estado de la pantalla de ajustes: pasos y mensaje de actualizacion', '  const [nativeCaptureDiagnostics, setNativeCaptureDiagnostics] =
    useState<string[]>([]);', '  const [nativeCaptureDiagnostics, setNativeCaptureDiagnostics] =
    useState<string[]>([]);
  const [pasosCaptura, setPasosCaptura] = useState<string[]>([]);
  const [actualizacionMsg, setActualizacionMsg] = useState("");'),
    @('App.tsx', 'ajustes: lee los pasos de captura', '    setNativeCaptureDiagnostics(getNativeCaptureDiagnostics());', '    setNativeCaptureDiagnostics(getNativeCaptureDiagnostics());
    void leerPasosCaptura().then(setPasosCaptura);'),
    @('App.tsx', 'ajustes: funcion de buscar actualizacion', '  async function openBatterySaverSettings() {', '  async function buscarActualizacion() {
    setActualizacionMsg("Buscando la última versión…");
    try {
      const respuesta = await fetch(URL_VERSION_APP, { headers: { accept: "application/json" } });
      const dato = (await respuesta.json()) as { disponible?: boolean; version?: string };
      if (!dato.disponible) {
        setActualizacionMsg("Todavía no hay una versión nueva publicada.");
        return;
      }
      const tengo = Number.parseInt(String(APP_BUILD_LABEL), 10);
      const coincidencia = /\((\d+)\)\s*$/.exec(String(dato.version ?? ""));
      const ultima = Number.parseInt(coincidencia?.[1] ?? "", 10);
      if (Number.isFinite(tengo) && Number.isFinite(ultima) && tengo >= ultima) {
        setActualizacionMsg(`Ya tenés la última versión (${APP_VERSION}, build ${APP_BUILD_LABEL}).`);
        return;
      }
      setActualizacionMsg(
        `Hay una versión publicada${dato.version ? `: ${dato.version}` : ""}. La tuya es ${APP_VERSION}, build ${APP_BUILD_LABEL}. Se abre la página de descarga.`,
      );
      await Linking.openURL(URL_DESCARGA_APP);
    } catch {
      setActualizacionMsg("No pude consultar la última versión. Revisá la conexión e intentá de nuevo.");
    }
  }

  async function openBatterySaverSettings() {'),
    @('App.tsx', 'iPhone: sin el texto de Android del ahorro de bateria (principio)', '            <Text style={styles.fieldHelp}>
              Android exige que vos confirmes el ahorro de batería.', '            {Platform.OS === "android" ? (
              <>
            <Text style={styles.fieldHelp}>
              Android exige que vos confirmes el ahorro de batería.'),
    @('App.tsx', 'iPhone: sin el texto de Android del ahorro de bateria (final)', '              <Text style={styles.secondaryButtonText}>Abrir ahorro de batería</Text>
            </Pressable>', '              <Text style={styles.secondaryButtonText}>Abrir ahorro de batería</Text>
            </Pressable>
              </>
            ) : null}'),
    @('App.tsx', 'registros tecnicos: pasos de la captura (iPhone y Android)', '            </Plegable>
            <Pressable onPress={onPermissions} style={[styles.secondaryButton, { marginTop: 14 }]}>', '            <Text style={[styles.fieldHelp, { marginTop: 14 }]}>
              {pasosCaptura.length
                ? "Pasos de las últimas capturas de evidencia (más reciente primero):"
                : "Todavía no hay pasos de captura guardados."}
            </Text>
            {pasosCaptura.map((linea, index) => (
              <Text key={`paso-captura-${index}`} style={[styles.fieldHelp, { marginTop: 4, fontSize: 12 }]}>
                {linea}
              </Text>
            ))}
            </Plegable>
            <Pressable onPress={onPermissions} style={[styles.secondaryButton, { marginTop: 14 }]}>'),
    @('App.tsx', 'boton Actualizar version (Android)', '                Probar aviso en este teléfono
              </Text>
            </Pressable>', '                Probar aviso en este teléfono
              </Text>
            </Pressable>
            {Platform.OS === "android" ? (
              <>
                <Pressable accessibilityRole="button" onPress={() => void buscarActualizacion()} style={styles.secondaryButton}>
                  <Text style={styles.secondaryButtonText}>{"Actualizar versión"}</Text>
                </Pressable>
                {actualizacionMsg ? <Text style={styles.fieldHelp}>{actualizacionMsg}</Text> : null}
              </>
            ) : null}')
)
$descargas = @()

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
    if (Test-Path ($ruta + ".bak-version")) { Mal ("Ya existe " + $t + ".bak-version. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-version"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-version): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-version") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "Archivos listos. Reviso que la app compile (puede tardar un minuto)..."
& npx.cmd tsc --noEmit
if ($LASTEXITCODE -ne 0) {
    Mal "La revision de tipos encontro errores (arriba). Dejo todo como estaba."
    foreach ($t in $tocados) { $ruta = Join-Path $raiz $t; if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-version") -Destination $ruta -Force } }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "LISTO: la app compila bien. Sale en la PROXIMA build (Android e iPhone)."
Write-Host ""
