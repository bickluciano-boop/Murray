# aplicar-consentimiento-app.ps1 - App (PROXIMA build): antes de pedir el DNI y la selfie, la pantalla de verificacion de identidad muestra el consentimiento biometrico y pide aceptarlo (casilla "Soy mayor de 18 anios y acepto...").
# Qué dice: que datos se usan (DNI, sexo, selfie = dato biometrico), para que, quien los procesa (Didit y RENAPER), que guarda Ojo Guard (no la selfie), cuanto tiempo (Didit 1 mes), y como pedir el borrado. La version aceptada (2026-11-03) se guarda en el telefono y se manda al servidor con cada verificacion.
# Cambia SOLO src\VerificarIdentidad.tsx (respaldo .bak-consentimiento) con anclas exactas, sin reemplazar el archivo: respeta los cambios de la camara y del espejo. Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba.
# Conviene instalar antes aplicar-identidad-consentimiento-panel.ps1 (el servidor que guarda la version). Sale en la PROXIMA build.
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
if (-not (Test-Path (Join-Path $raiz "src\VerificarIdentidad.tsx"))) { Mal "No encuentro src\VerificarIdentidad.tsx en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\VerificarIdentidad.tsx")).texto 'CONSENTIMIENTO_VERSION') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
$cambios = @(
    @('src\VerificarIdentidad.tsx', 'importar el almacenamiento del telefono', 'import * as FileSystem from "expo-file-system/legacy";
', 'import AsyncStorage from "@react-native-async-storage/async-storage";
import * as FileSystem from "expo-file-system/legacy";
'),
    @('src\VerificarIdentidad.tsx', 'version del consentimiento y funciones para leerlo y guardarlo', 'const URL_API = "https://ojo-guard-ms-api.bickluciano.workers.dev";
', 'const URL_API = "https://ojo-guard-ms-api.bickluciano.workers.dev";

/**
 * Consentimiento biometrico (03/11/2026): antes de pedir el DNI y la selfie se muestra un texto y la persona tiene que aceptarlo.
 * CONSENTIMIENTO_VERSION identifica ESE texto (AAAA-MM-DD): si el texto cambia, se cambia la version y se vuelve a pedir.
 * La version aceptada se guarda en el telefono (para no preguntar cada vez) y se manda al servidor con cada verificacion, que registra cual version y cuando.
 */
const CONSENTIMIENTO_VERSION = "2026-11-03";
const CLAVE_CONSENTIMIENTO = "ojo-guard-consentimiento-biometrico";

async function consentimientoAceptado(): Promise<boolean> {
  try {
    return (await AsyncStorage.getItem(CLAVE_CONSENTIMIENTO)) === CONSENTIMIENTO_VERSION;
  } catch {
    return false;
  }
}

async function guardarConsentimiento(): Promise<void> {
  try {
    await AsyncStorage.setItem(CLAVE_CONSENTIMIENTO, CONSENTIMIENTO_VERSION);
  } catch {
    // Si no se puede guardar en el telefono igual se sigue: el servidor recibe la version con cada verificacion.
  }
}
'),
    @('src\VerificarIdentidad.tsx', 'mensaje si el servidor pide el consentimiento', '    case "invalid_selfie":
      return { mensaje: "La foto no se pudo usar. Sacate otra.", volverA: "selfie" };
', '    case "consent_required":
      return { mensaje: "Falta aceptar el consentimiento. Actualizá Ojo Guard a la última versión y probá de nuevo.", volverA: "datos" };
    case "invalid_selfie":
      return { mensaje: "La foto no se pudo usar. Sacate otra.", volverA: "selfie" };
'),
    @('src\VerificarIdentidad.tsx', 'mandar la version del consentimiento con la verificacion', 'body: JSON.stringify({ deviceId: enrollment.deviceId, documentNumber: documento, gender: sexo, selfieBase64 }),', 'body: JSON.stringify({ deviceId: enrollment.deviceId, documentNumber: documento, gender: sexo, selfieBase64, consentVersion: CONSENTIMIENTO_VERSION }),'),
    @('src\VerificarIdentidad.tsx', 'estado del consentimiento', '  const [yaVerificada, setYaVerificada] = useState<boolean | null>(revisarEstado ? null : false);
', '  const [yaVerificada, setYaVerificada] = useState<boolean | null>(revisarEstado ? null : false);
  // "leyendo" mientras se mira si ya acepto el consentimiento en este telefono; "pendiente" muestra el texto; "aceptado" sigue con los datos.
  const [consentimiento, setConsentimiento] = useState<"leyendo" | "pendiente" | "aceptado">("leyendo");
  const [casilla, setCasilla] = useState(false);

  useEffect(() => {
    let vigente = true;
    void consentimientoAceptado().then((aceptado) => {
      if (vigente) setConsentimiento(aceptado ? "aceptado" : "pendiente");
    });
    return () => {
      vigente = false;
    };
  }, []);

  async function aceptarConsentimiento() {
    if (!casilla) return;
    await guardarConsentimiento();
    setConsentimiento("aceptado");
  }
'),
    @('src\VerificarIdentidad.tsx', 'pantalla del consentimiento antes de pedir el DNI', '  if (etapa === "datos") {
    const opciones: Array<{ valor: Sexo; texto: string }> = [
', '  if (etapa === "datos" && consentimiento !== "aceptado") {
    if (consentimiento === "leyendo") {
      return (
        <View style={{ paddingVertical: 24 }}>
          <ActivityIndicator color={azul} />
        </View>
      );
    }
    const punto = (rotulo: string, texto: string) => (
      <Text style={{ color: paleta.textoMedio, fontSize: 14.5, lineHeight: 21 }}>
        <Text style={{ color: paleta.texto, fontWeight: "800" }}>{rotulo} </Text>
        {texto}
      </Text>
    );
    return (
      <View style={{ gap: 6 }}>
        {sinTituloPropio ? null : titulo("Antes de verificarte")}
        {parrafo("Para confirmar que sos vos te vamos a pedir tu número de DNI, el sexo que figura en él y una selfie. Leé cómo usamos esos datos y, si estás de acuerdo, aceptá.")}
        <View style={{ gap: 12, marginTop: 14, padding: 16, borderRadius: 16, borderWidth: 1, borderColor: paleta.borde, backgroundColor: tarjeta }}>
          {punto("Qué usamos.", "Tu número de DNI, tu sexo y una foto de tu cara. La foto de tu cara es un dato biométrico.")}
          {punto("Para qué.", "Para compararla con la foto que el registro oficial (RENAPER) tiene de tu DNI y confirmar que sos vos. Solo para eso: no usamos tus datos para publicidad ni los vendemos.")}
          {punto("Quién los procesa.", "Didit, la empresa que hace la verificación, y RENAPER. Didit puede procesar los datos fuera de Argentina.")}
          {punto("Qué guardamos nosotros.", "La selfie no. Guardamos el resultado, el puntaje de la comparación, los últimos 3 números del DNI, una huella que no permite recuperar el número y la fecha en que aceptaste esto.")}
          {punto("Cuánto tiempo.", "Didit guarda los datos de la consulta 1 mes (el plazo que le pedimos) y después los elimina.")}
          {punto("Tus derechos.", "Es opcional: podés omitirlo y usar Ojo Guard igual. Podés pedir que borremos tus datos cuando quieras, desde Perfil > Borrar mi cuenta o escribiendo a soporte@ojoguard.app.")}
        </View>
        <Pressable
          accessibilityRole="checkbox"
          accessibilityState={{ checked: casilla }}
          onPress={() => setCasilla(!casilla)}
          style={{ flexDirection: "row", alignItems: "flex-start", gap: 12, marginTop: 18 }}
        >
          <View style={{ width: 26, height: 26, borderRadius: 7, borderWidth: 2, borderColor: azul, backgroundColor: casilla ? azul : "transparent", alignItems: "center", justifyContent: "center", marginTop: 1 }}>
            {casilla ? <Icono nombre="check" color="#fff" tam={18} /> : null}
          </View>
          <Text style={{ flex: 1, color: paleta.texto, fontSize: 15, lineHeight: 22 }}>
            Soy mayor de 18 años y acepto que Ojo Guard use mi DNI y mi selfie para verificar mi identidad, como se explica arriba.
          </Text>
        </Pressable>
        <View style={{ gap: 10, marginTop: 20 }}>
          {boton("Aceptar y seguir", () => void aceptarConsentimiento(), { principal: true, deshabilitado: !casilla })}
          {permitirOmitir ? enlace("Ahora no", () => onListo("omitida")) : null}
        </View>
      </View>
    );
  }

  if (etapa === "datos") {
    const opciones: Array<{ valor: Sexo; texto: string }> = [
')
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
    if (Test-Path ($ruta + ".bak-consentimiento")) { Mal ("Ya existe " + $t + ".bak-consentimiento. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-consentimiento"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-consentimiento): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-consentimiento") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    foreach ($t in $respaldados) { Remove-Item -LiteralPath ((Join-Path $raiz $t) + ".bak-consentimiento") -Force -ErrorAction SilentlyContinue }
Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "Archivos listos. Reviso que la app compile (puede tardar un minuto)..."
& npx.cmd tsc --noEmit
if ($LASTEXITCODE -ne 0) {
    Mal "La revision de tipos encontro errores (arriba). Dejo todo como estaba."
    foreach ($t in $tocados) { $ruta = Join-Path $raiz $t; if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-consentimiento") -Destination $ruta -Force } elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force } }
    foreach ($t in $respaldados) { Remove-Item -LiteralPath ((Join-Path $raiz $t) + ".bak-consentimiento") -Force -ErrorAction SilentlyContinue }
Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "LISTO: la app compila bien. Sale en la PROXIMA build."
Write-Host ""
