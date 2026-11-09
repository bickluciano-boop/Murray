# aplicar-sos-apagar-app.ps1 - App (PROXIMA build): apagar mi SOS del todo (dos confirmaciones) y prenderlo de nuevo, dentro de la tarjeta CUIDADO.
# Luciano (09/11/2026, "si, dejalo asi"): las llaves rapidas de PERMISOS mantienen "siempre queda alguien", pero un adulto decide por si mismo: puede apagar su SOS del todo desde un lugar deliberado, con confirmacion fuerte; los demas reciben un aviso.
# Apagado, el SOS no sale y avisa por que (en el boton y en el aviso de segundo plano); la tarjeta SOS dice que esta apagado en vez de "no hay nadie".
# Requiere aplicar-cuidado-app.ps1 y el servidor aplicar-sos-apagar-panel.ps1. Toca src\remoteApi.ts, src\FamiliaPantalla.tsx, src\SosBlock.tsx y src\sosTask.ts (respaldo .bak-sosoff). Va en la carpeta de la APP.
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
foreach ($f in @("src\FamiliaPantalla.tsx", "src\remoteApi.ts", "src\SosBlock.tsx", "src\sosTask.ts")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\FamiliaPantalla.tsx")).texto 'function TarjetaCuidado') -eq 0) { Mal "Falta aplicar primero aplicar-cuidado-app.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\FamiliaPantalla.tsx")).texto 'const confirmarApagarSos') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
$cambios = @(
    @('src\remoteApi.ts', 'sos apagado: tipo', '  destinatarios: string[];
};
', '  destinatarios: string[];
  sosOff: boolean;
};
'),
    @('src\remoteApi.ts', 'sos apagado: lectura', '    destinatarios: Array.isArray(r.destinatarios) ? r.destinatarios.map((x) => String(x)) : [],
', '    destinatarios: Array.isArray(r.destinatarios) ? r.destinatarios.map((x) => String(x)) : [],
    sosOff: r.sosOff === true,
'),
    @('src\remoteApi.ts', 'sos apagado: llamada', '/** Contestar "estoy bien" al Buen dia', '/** Apagar (off = true) o volver a prender MI SOS. Apagado, el SOS no le llega a nadie; el servidor avisa a quienes lo recibian. */
export async function setSosOff(enrollment: NativeEnrollment, off: boolean) {
  await nativeRequest(enrollment, "/api/native/care/sos", {
    method: "POST",
    body: JSON.stringify({ deviceId: enrollment.deviceId, off }),
  });
}

/** Contestar "estoy bien" al Buen dia'),
    @('src\FamiliaPantalla.tsx', 'sos apagado: importar la llamada', 'import { answerBuenDia, fetchCare, fetchFamily, joinFamily, leaveFamily, pauseFamilyLocation, setCarePrefs, setFamilyPermission, type CambiosCuidado, type CuidadoEstado, type FamilyPerson } from "./remoteApi";', 'import { answerBuenDia, fetchCare, fetchFamily, joinFamily, leaveFamily, pauseFamilyLocation, setCarePrefs, setFamilyPermission, setSosOff, type CambiosCuidado, type CuidadoEstado, type FamilyPerson } from "./remoteApi";'),
    @('src\FamiliaPantalla.tsx', 'sos apagado: la tarjeta avisa a la pantalla', 'function TarjetaCuidado({ P, enrollment, botones }: { P: Paleta; enrollment: NativeEnrollment; botones: { primario: StyleProp<ViewStyle>; primarioTexto: StyleProp<TextStyle>; ayuda: StyleProp<TextStyle> } }) {', 'function TarjetaCuidado({ P, enrollment, botones, onSosApagado }: { P: Paleta; enrollment: NativeEnrollment; botones: { primario: StyleProp<ViewStyle>; primarioTexto: StyleProp<TextStyle>; ayuda: StyleProp<TextStyle> }; onSosApagado: (apagado: boolean) => void }) {'),
    @('src\FamiliaPantalla.tsx', 'sos apagado: efecto', '  useEffect(() => {
    void cargar();
  }, [cargar]);
  if (!cuidado) return null;
', '  useEffect(() => {
    void cargar();
  }, [cargar]);
  const sosApagadoAhora = cuidado?.sosOff;
  useEffect(() => {
    if (sosApagadoAhora !== undefined) onSosApagado(sosApagadoAhora);
  }, [sosApagadoAhora, onSosApagado]);
  if (!cuidado) return null;
'),
    @('src\FamiliaPantalla.tsx', 'sos apagado: apagar con dos confirmaciones', '  const { prefs, hoy, destinatarios } = actual;
', '  const { prefs, hoy, destinatarios } = actual;
  // Apagar el SOS del todo: lugar deliberado + DOS confirmaciones (lo decide la propia persona; nadie lo hace por ella).
  const cambiarSos = async (off: boolean) => {
    setAviso("");
    setGuardando((g) => [...g, "sos"]);
    setCuidado({ ...actual, sosOff: off });
    try {
      await setSosOff(enrollment, off);
      void cargar();
    } catch (error) {
      setCuidado(actual);
      const codigo = error instanceof Error ? error.message : "";
      setAviso(codigo === "minor_locked" ? "Con un menor no se puede apagar el SOS." : "No se pudo guardar. Probá de nuevo.");
    } finally {
      setGuardando((g) => g.filter((x) => x !== "sos"));
    }
  };
  const confirmarApagarSos = () => {
    const quienes = destinatarios.length ? listaDeNombres(destinatarios) : "nadie";
    Alert.alert(
      "¿Apagar tu SOS?",
      `Si lo apagás, tu SOS no le va a llegar a nadie (hoy le llega a: ${quienes}). Tampoco van a avisar la batería ni el Buen día. Ellos van a recibir un aviso de que lo apagaste.`,
      [
        { text: "Cancelar", style: "cancel" },
        {
          text: "Seguir",
          style: "destructive",
          onPress: () =>
            Alert.alert("Última confirmación", "Si te pasa algo, nadie va a saber que pediste ayuda. ¿Apagar tu SOS igual?", [
              { text: "No, dejarlo prendido", style: "cancel" },
              { text: "Sí, apagar mi SOS", style: "destructive", onPress: () => void cambiarSos(true) },
            ]),
        },
      ],
    );
  };
'),
    @('src\FamiliaPantalla.tsx', 'sos apagado: seccion en la tarjeta', '        {aviso ? <View style={sp.cartel}><Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.cartelTexto}>{aviso}</Text></View> : null}
      </View>
    </>
  );
}
', '        <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.separador}>MI SOS</Text>
        {actual.sosOff ? (
          <>
            <View style={sp.cartel}>
              <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.cartelTexto}>Tu SOS está apagado: no le llega a nadie, y la batería y el Buen día tampoco avisan.</Text>
            </View>
            <Pressable accessibilityRole="button" disabled={guardando.includes("sos")} onPress={() => void cambiarSos(false)} style={botones.primario}>
              <Text style={botones.primarioTexto}>Prender mi SOS</Text>
            </Pressable>
          </>
        ) : (
          <Pressable accessibilityRole="button" disabled={guardando.includes("sos")} onPress={confirmarApagarSos}>
            <Text maxFontSizeMultiplier={TOPE_LETRA} style={{ color: P.peligroFuerte ?? P.peligro, fontSize: 13.5, fontWeight: "700", textDecorationLine: "underline" }}>Apagar mi SOS…</Text>
          </Pressable>
        )}
        {aviso ? <View style={sp.cartel}><Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.cartelTexto}>{aviso}</Text></View> : null}
      </View>
    </>
  );
}
'),
    @('src\FamiliaPantalla.tsx', 'sos apagado: estado de la pantalla', '  const pendientesPerm = useRef(0);
', '  const pendientesPerm = useRef(0);
  const [sosApagado, setSosApagado] = useState(false);
'),
    @('src\FamiliaPantalla.tsx', 'sos apagado: tarjeta en la pantalla', '{enrollment ? <TarjetaCuidado P={P} enrollment={enrollment} botones={botones} /> : null}', '{enrollment ? <TarjetaCuidado P={P} enrollment={enrollment} botones={botones} onSosApagado={setSosApagado} /> : null}'),
    @('src\FamiliaPantalla.tsx', 'sos apagado: el texto de la tarjeta SOS', ': "Hoy tu SOS no le suena a nadie en la app. Sumá a alguien desde el mapa del Inicio."}', ': sosApagado ? "Tu SOS está apagado: no le suena a nadie. Prendelo en la tarjeta CUIDADO." : "Hoy tu SOS no le suena a nadie en la app. Sumá a alguien desde el mapa del Inicio."}'),
    @('src\SosBlock.tsx', 'sos apagado: mensaje al apretar el SOS', '  no_recipients: "No hay nadie a quien avisar. Sumá a alguien a tu familia primero.",
', '  no_recipients: "No hay nadie a quien avisar. Sumá a alguien a tu familia primero.",
  sos_off: "Tu SOS está apagado. Prendelo en Ajustes, Familia y amigos, tarjeta CUIDADO.",
'),
    @('src\sosTask.ts', 'sos apagado: aviso del SOS en segundo plano', '            ? "No hay nadie a quien avisar: sumá a alguien a tu familia."
            : "Revisá la conexión y probá de nuevo. Si es una emergencia, llamá a emergencias.",
', '            ? "No hay nadie a quien avisar: sumá a alguien a tu familia."
            : codigo === "sos_off"
              ? "Tu SOS está apagado. Prendelo en Ajustes, Familia y amigos."
              : "Revisá la conexión y probá de nuevo. Si es una emergencia, llamá a emergencias.",
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
    if (Test-Path ($ruta + ".bak-sosoff")) { Mal ("Ya existe " + $t + ".bak-sosoff. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-sosoff"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-sosoff): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-sosoff") -Destination $ruta -Force }
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
    foreach ($t in $tocados) { $ruta = Join-Path $raiz $t; if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-sosoff") -Destination $ruta -Force } }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "LISTO: la app compila bien. Sale en la PROXIMA build."
Write-Host ""
