# aplicar-medicamentos-alerta-app.ps1 - App (PROXIMA build). Luciano (18/11/2026): avisos de medicamentos mas notorios pero NO invasivos: que si el telefono esta en silencio pueda vibrar, o un destello, para quien no oye bien.
# Android: canal nuevo "ojo-medicamentos-2" (cartel arriba, sonido corto, vibracion larga, luz de aviso). Tarjeta MEDICAMENTOS: linea chica cerrada "¿No oyes bien los avisos?" que explica como activar el destello del sistema y abre los ajustes.
# Toca src\FamiliaPantalla.tsx y App.tsx (respaldo .bak-alerta). Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba. El servidor (aplicar-medicamentos-alerta-panel.ps1) se aplica DESPUES de las builds.
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
foreach ($f in @("src\FamiliaPantalla.tsx", "App.tsx")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "App.tsx")).texto 'ojo-medicamentos-2') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\FamiliaPantalla.tsx")).texto '>PENDIENTES</Text>') -eq 0) { Mal "Falta aplicar primero aplicar-medicamentos-pendientes-app.ps1."; return }
$cambios = @(
    @('src\FamiliaPantalla.tsx', 'alerta: ayuda del destello y la vibracion (componente)', 'function moverHoraRemedio(hhmm: string, pasos: number): string {
', '/** "¿No oyes bien los avisos?": una linea chica que viene cerrada; al tocarla explica como activar el destello y la vibracion del telefono y abre los ajustes. No es invasiva. */
function AyudaAvisos({ P }: { P: Paleta }) {
  const [abierta, setAbierta] = useState(false);
  const abrirAjustes = () => {
    if (Platform.OS === "android") {
      Linking.sendIntent("android.settings.ACCESSIBILITY_SETTINGS").catch(() => void Linking.openSettings());
    } else {
      void Linking.openSettings();
    }
  };
  const texto =
    Platform.OS === "android"
      ? "Si no oyes bien, el teléfono puede avisarte con un destello y con vibración. Destello: en Ajustes → Accesibilidad busca «flash» (se llama «Notificación con flash» o «Flash de cámara»). Vibración: deja el teléfono en «vibrar» y no en silencio total; en silencio total Android no deja que ninguna app suene ni vibre."
      : "Si no oyes bien, el iPhone puede avisarte con un destello y con vibración. Destello: Ajustes → Accesibilidad → Audio y visual → «Flash LED para alertas». Vibración: Ajustes → Sonidos y vibraciones → «Vibrar en silencio»; así, con el interruptor lateral en silencio, igual vibra.";
  return (
    <View style={{ gap: 6 }}>
      <Pressable accessibilityRole="button" accessibilityState={{ expanded: abierta }} onPress={() => setAbierta((a) => !a)}>
        <Text maxFontSizeMultiplier={TOPE_LETRA} style={{ color: P.textoClaro, fontSize: 13.5, fontWeight: "700", textDecorationLine: "underline" }}>{abierta ? "Ocultar" : "¿No oyes bien los avisos?"}</Text>
      </Pressable>
      {abierta ? (
        <>
          <Text maxFontSizeMultiplier={TOPE_LETRA} style={{ color: P.textoDebil, fontSize: 13, lineHeight: 19 }}>{texto}</Text>
          <Pressable accessibilityRole="button" onPress={abrirAjustes} style={{ alignSelf: "flex-start", borderColor: P.borde, borderRadius: 12, borderWidth: 1, paddingHorizontal: 12, paddingVertical: 8 }}>
            <Text maxFontSizeMultiplier={TOPE_LETRA} style={{ color: P.textoClaro, fontSize: 13.5, fontWeight: "700" }}>{Platform.OS === "android" ? "Abrir ajustes de accesibilidad" : "Abrir ajustes"}</Text>
          </Pressable>
        </>
      ) : null}
    </View>
  );
}

function moverHoraRemedio(hhmm: string, pasos: number): string {
'),
    @('src\FamiliaPantalla.tsx', 'alerta: la linea "No oyes bien los avisos" va arriba de PENDIENTES', '        {actual.atrasadas.length ? (
          <>
            <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.separador}>PENDIENTES</Text>
', '        <AyudaAvisos P={P} />
        {actual.atrasadas.length ? (
          <>
            <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.separador}>PENDIENTES</Text>
'),
    @('App.tsx', 'alerta: canal de Android nuevo con cartel, vibracion larga y luz', '      void notifications.setNotificationChannelAsync("ojo-alertas", {
', '      // Recordatorio de medicamentos (v2): cartel arriba con sonido corto, vibracion larga y luz de aviso. Suave, nada de alarma. (Con el telefono en silencio total ninguna app puede sonar ni vibrar; el destello lo da el sistema.)
      void notifications.setNotificationChannelAsync("ojo-medicamentos-2", {
        name: "Recordatorio de medicamentos",
        description: "Un sonido corto, vibración y luz de aviso a la hora de tus medicamentos.",
        importance: notifications.AndroidImportance.HIGH,
        sound: "default",
        enableVibrate: true,
        vibrationPattern: [0, 400, 200, 400],
        enableLights: true,
        lightColor: "#FFB300",
        lockscreenVisibility: notifications.AndroidNotificationVisibility.PUBLIC,
      });
      void notifications.setNotificationChannelAsync("ojo-alertas", {
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
    if (Test-Path ($ruta + ".bak-alerta")) { Mal ("Ya existe " + $t + ".bak-alerta. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-alerta"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-alerta): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-alerta") -Destination $ruta -Force }
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
    foreach ($t in $tocados) { $ruta = Join-Path $raiz $t; if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-alerta") -Destination $ruta -Force } }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "LISTO: la app compila bien. Avisos de medicamentos con cartel, vibracion larga y ayuda para el destello (sale en la PROXIMA build, Android e iPhone)."
Write-Host ""
