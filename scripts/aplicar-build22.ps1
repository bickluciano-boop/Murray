# aplicar-build22.ps1 - Arreglos para la proxima build (iPhone y Android):
#  1) "Hacer sonar" ya no se repite: la app no vuelve a ejecutar una orden que ya esta ejecutando (antes, unas 20 veces seguidas).
#  2) iPhone: la sirena vuelve a pedir sonar aunque la perilla este en silencio y deja un registro en Configuracion.
#  3) Familia: el boton "Compartir de nuevo" se cortaba (ahora dice "Reanudar").
#  4) Android: canal de avisos de familia sin sonido ("Luciano vio donde estas").
# Va en la carpeta de la APP (la que tiene app.json). Respaldos .bak-b22; si algo falla, se restaura todo.
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
if ((Contar (Leer (Join-Path $raiz "src\remoteSync.ts")).texto 'const enCurso = new Set') -ne 0) { Avi "Los arreglos de la build 22 ya estaban aplicados. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "App.tsx")).texto 'watchFamilyLocation') -eq 0) { Mal "Primero corre aplicar-familia-iphone.ps1."; return }
$cambios = @(
    @('App.tsx', 'un solo aviso de sonar', '          },
          trigger: Platform.OS === "android" ? { channelId: REMOTE_RING_CHANNEL } : null,', '          },
          // Un solo aviso por orden: si se vuelve a programar, reemplaza al anterior.
          identifier: `ojo-guard-ring-${command.commandId}`,
          trigger: Platform.OS === "android" ? { channelId: REMOTE_RING_CHANNEL } : null,'),
    @('App.tsx', 'canal silencioso de familia', '      if (!notifications) return;
      void notifications.setNotificationChannelAsync("ojo-alertas", {', '      if (!notifications) return;
      // Avisos de familia que no tienen que sonar ("Luciano vio donde estas", ver
      // familyMinorNotice en el servidor): se ven en la barra, sin sonido.
      void notifications.setNotificationChannelAsync("ojo-familia-aviso", {
        name: "Avisos de familia",
        description: "Cuando alguien de tu familia mira d\u00f3nde est\u00e1s.",
        importance: notifications.AndroidImportance.LOW,
        sound: null,
        enableVibrate: false,
        lockscreenVisibility: notifications.AndroidNotificationVisibility.PUBLIC,
      });
      void notifications.setNotificationChannelAsync("ojo-alertas", {'),
    @('src\remoteSync.ts', 'ordenes en curso', '
export async function synchronizeRemoteCommands(', '
// Ordenes que este proceso esta ejecutando ahora mismo. "Hacer sonar" tarda un
// minuto (la sirena) y mientras tanto sigue "recibida" en el servidor, asi que
// cada sincronizacion que arrancaba en ese minuto la volvia a ejecutar. Y como
// cada ejecucion muestra un aviso, y cada aviso dispara otra sincronizacion, se
// armaba una cadena: el 08/10/2026 a las 20:29 llegaron unas 20 notificaciones
// iguales en el mismo minuto y la sirena se reiniciaba una y otra vez.
const enCurso = new Set<string>();

export async function synchronizeRemoteCommands('),
    @('src\remoteSync.ts', 'no repetir una orden', '
    const received = markRemoteCommandReceived(command, receivedAt);
    if (command.status === "pending") {
      await confirmRemoteCommand(enrollment, {
        commandId: received.commandId,
        status: "received",
        occurredAt: receivedAt,
      });
      result.receivedCount += 1;
    }

    try {
      const execution = await execute(received);
      const executedAt = now().toISOString();
      const executed = markRemoteCommandExecuted(received, executedAt);
      await confirmRemoteCommand(enrollment, {
        commandId: executed.commandId,
        status: "executed",
        occurredAt: executedAt,
        location: execution.location,
        evidenceAttemptId: execution.evidenceAttemptId,
        nearbyDevices: execution.nearbyDevices,
      });
      result.executedCount += 1;
    } catch (error) {
      await confirmRemoteCommand(enrollment, {
        commandId: received.commandId,
        status: "failed",
        occurredAt: now().toISOString(),
        error: error instanceof Error ? error.message : "remote_command_failed",
      }).catch(() => undefined);
    }', '
    if (enCurso.has(command.commandId)) {
      result.skippedCount += 1;
      continue;
    }
    enCurso.add(command.commandId);
    try {
      const received = markRemoteCommandReceived(command, receivedAt);
      if (command.status === "pending") {
        await confirmRemoteCommand(enrollment, {
          commandId: received.commandId,
          status: "received",
          occurredAt: receivedAt,
        });
        result.receivedCount += 1;
      }

      try {
        const execution = await execute(received);
        const executedAt = now().toISOString();
        const executed = markRemoteCommandExecuted(received, executedAt);
        await confirmRemoteCommand(enrollment, {
          commandId: executed.commandId,
          status: "executed",
          occurredAt: executedAt,
          location: execution.location,
          evidenceAttemptId: execution.evidenceAttemptId,
          nearbyDevices: execution.nearbyDevices,
        });
        result.executedCount += 1;
      } catch (error) {
        await confirmRemoteCommand(enrollment, {
          commandId: received.commandId,
          status: "failed",
          occurredAt: now().toISOString(),
          error: error instanceof Error ? error.message : "remote_command_failed",
        }).catch(() => undefined);
      }
    } finally {
      enCurso.delete(command.commandId);
    }'),
    @('src\earbudTone.ts', 'sirena en silencio (1)', 'import { createAudioPlayer, setAudioModeAsync } from "expo-audio";
import * as FileSystem from "expo-file-system/legacy";
import {', 'import { createAudioPlayer, setAudioModeAsync, setIsAudioActiveAsync } from "expo-audio";
import * as FileSystem from "expo-file-system/legacy";
import { Platform } from "react-native";
import {'),
    @('src\earbudTone.ts', 'sirena en silencio (2)', '} from "./audioRoute";
', '} from "./audioRoute";
import { recordFullScreenAlertAttempt } from "./fullScreenAlertDiagnostics";
'),
    @('src\earbudTone.ts', 'sirena en silencio (3)', '  }

  await setAudioModeAsync({', '  }

  // iPhone: que suene aunque la perilla este en silencio. Probado el 09/10/2026:
  // con la app abierta sonaba solo con la perilla activa, como si este ajuste no
  // quedara puesto. Ahora se pide antes de sonar, se activa la sesion de audio y
  // se vuelve a pedir ya sonando; lo que pase queda en el historial de
  // Configuracion ("hacer sonar"). El volumen no se puede subir desde la app: eso
  // solo lo permite el permiso de Alertas criticas de Apple.
  const modoAlarma = {'),
    @('src\earbudTone.ts', 'sirena en silencio (4)', '    shouldPlayInBackground: true,
    shouldRouteThroughEarpiece: false,
    interruptionMode: "doNotMix",', '    shouldPlayInBackground: true,
    shouldRouteThroughEarpiece: false,
    interruptionMode: "doNotMix",
  } as const;
  let errorModo: string | null = null;
  await setAudioModeAsync(modoAlarma).catch((error: unknown) => {
    errorModo = error instanceof Error ? error.message : String(error);'),
    @('src\earbudTone.ts', 'sirena en silencio (5)', '  stopActiveAlarmPlayer();
  const player = createAudioPlayer(uri);', '  stopActiveAlarmPlayer();
  if (Platform.OS === "ios") await setIsAudioActiveAsync(true).catch(() => undefined);
  const player = createAudioPlayer(uri);'),
    @('src\earbudTone.ts', 'sirena en silencio (6)', '  activeAlarmPlayer = player;', '  activeAlarmPlayer = player;
  if (Platform.OS === "ios") {
    setTimeout(() => {
      if (activeAlarmPlayer !== player) return;
      void setAudioModeAsync(modoAlarma).catch(() => undefined);
      void recordFullScreenAlertAttempt({
        reason: "hacer-sonar",
        moduleFound: false,
        result: player.playing,
        error: `iPhone: ${player.playing ? "sonando" : "NO suena"}${errorModo ? `; modo de audio: ${errorModo}` : ""}`,
      });
    }, 1500);
  }'),
    @('src\FamilySection.tsx', 'botones de pausa', '            <Pressable accessibilityRole="button" disabled={ocupado} onPress={() => void pausar(60)} style={[botones.secundario, s.botonMitad]}>
              <Text style={botones.secundarioTexto}>Pausar 1 hora</Text>
            </Pressable>
            <Pressable accessibilityRole="button" disabled={ocupado} onPress={() => void pausar(0)} style={[botones.secundario, s.botonMitad]}>
              <Text style={botones.secundarioTexto}>Compartir de nuevo</Text>
            </Pressable>', '            <Pressable accessibilityRole="button" disabled={ocupado} onPress={() => void pausar(60)} style={[botones.secundario, s.botonMitad]}>
              <Text adjustsFontSizeToFit numberOfLines={1} style={botones.secundarioTexto}>Pausar 1 hora</Text>
            </Pressable>
            <Pressable accessibilityRole="button" disabled={ocupado} onPress={() => void pausar(0)} style={[botones.secundario, s.botonMitad]}>
              <Text adjustsFontSizeToFit numberOfLines={1} style={botones.secundarioTexto}>Reanudar</Text>
            </Pressable>'),
    @('src\FamilySection.tsx', 'botones de pausa (estilo)', '    pausaFila: { flexDirection: "row", gap: 8, marginTop: 14 },
    botonMitad: { flex: 1 },
    espacio: { marginTop: 12 },', '    pausaFila: { flexDirection: "row", gap: 8, marginTop: 14 },
    botonMitad: { flex: 1, alignItems: "center", justifyContent: "center" },
    espacio: { marginTop: 12 },')
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
    if (Test-Path ($ruta + ".bak-b22")) { Mal ("Ya existe " + $t + ".bak-b22. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-b22"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-b22): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-b22") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "TODO BIEN. Para revisar que compile:  powershell -ExecutionPolicy Bypass -Command ""npx tsc --noEmit""  (si no muestra nada, esta perfecto)"
Ok "Despues: build de iPhone (y de Android cuando quieras el canal silencioso)."
Write-Host ""
