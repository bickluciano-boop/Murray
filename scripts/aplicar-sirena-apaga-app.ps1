# aplicar-sirena-apaga-app.ps1 - App (PROXIMA build, Android): la sirena que la app toca con un SOS o con "Hacer sonar".
# Luciano (03/11/2026): "la sirena es muy larga y se tendra que apagar cuando la persona abre la notificacion o entra a la aplicacion; si estas en un lugar social no la podes frenar".
#  1) Si la orden viene de un SOS (vence a los 3 minutos) la sirena de la app dura 20 segundos; si viene del panel (vence a la hora) sigue durando 60, para encontrar un telefono perdido.
#  2) Se apaga sola cuando la persona toca el aviso o entra a la app, y saca de la bandeja el aviso del SOS / de la busqueda. Con el Modo perdido activo no se apaga sola.
# Toca src\earbudTone.ts, src\backgroundRemoteTask.ts y App.tsx (respaldo .bak-sirena-apaga). Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba.
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
foreach ($f in @("App.tsx", "src\earbudTone.ts", "src\backgroundRemoteTask.ts")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\earbudTone.ts")).texto 'function duracionSirenaDeOrden') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
$cambios = @(
    @('src\earbudTone.ts', 'sirena: la duracion pasa a ser un parametro', 'export async function playPhoneAlarmTone(): Promise<string> {
', '/**
 * Cuanto suena la sirena de una orden "Hacer sonar". Las ordenes que genera un SOS vencen a los 3 minutos (las del panel, a la hora):
 * esas son un aviso y no una busqueda, asi que suenan 20 segundos. Para encontrar un telefono perdido siguen los 60 de siempre.
 */
function duracionSirenaDeOrden(venceEn?: string | null): number {
  const resto = venceEn ? new Date(venceEn).getTime() - Date.now() : Number.NaN;
  return Number.isFinite(resto) && resto <= 4 * 60_000 ? 20_000 : 60_000;
}

export async function playPhoneAlarmTone(venceEn?: string | null): Promise<string> {
  const duracionMs = duracionSirenaDeOrden(venceEn);
'),
    @('src\earbudTone.ts', 'sirena: duracion en el camino nativo de Android', '    return await playAlarmThroughSpeaker(uri, 60_000);
', '    return await playAlarmThroughSpeaker(uri, duracionMs);
'),
    @('src\earbudTone.ts', 'sirena: duracion en el corte automatico', '    activeAlarmTimeout = setTimeout(() => stopActiveAlarmPlayer(), 60_000);
', '    activeAlarmTimeout = setTimeout(() => stopActiveAlarmPlayer(), duracionMs);
'),
    @('src\backgroundRemoteTask.ts', 'sirena en segundo plano: duracion segun la orden', '        void playPhoneAlarmTone().catch(() => undefined);
', '        void playPhoneAlarmTone(command.expiresAt).catch(() => undefined);
'),
    @('App.tsx', 'sirena en primer plano: duracion segun la orden', '        await playPhoneAlarmTone();
', '        await playPhoneAlarmTone(command.expiresAt);
'),
    @('App.tsx', 'sirena: se apaga al tocar el aviso o entrar a la app', '          shouldShowList: true,
        }),
      });
    });
  }, []);
', '          shouldShowList: true,
        }),
      });
    });
  }, []);

  // La sirena del SOS / "Hacer sonar" se apaga sola apenas la persona toca el aviso o entra a la app (antes seguia sonando hasta el final).
  // Con el Modo perdido activo no: ahi la sirena solo la corta el codigo o "Detener sonido".
  useEffect(() => {
    if (lostModeActive) return undefined;
    let cancelado = false;
    const suscripciones: { remove: () => void }[] = [];
    const apagarSirena = () => {
      stopPhoneAlarmTone();
      void loadNativeNotifications()
        .then(async (notifications) => {
          if (!notifications) return;
          const visibles = await notifications.getPresentedNotificationsAsync().catch(() => []);
          for (const aviso of visibles) {
            const datos = aviso.request.content.data as { kind?: string; type?: string } | null | undefined;
            if (datos?.kind === "ring" || datos?.type === "sos") {
              await notifications.dismissNotificationAsync(aviso.request.identifier).catch(() => undefined);
            }
          }
        })
        .catch(() => undefined);
    };
    suscripciones.push(
      AppState.addEventListener("change", (estado) => {
        if (estado === "active") apagarSirena();
      }),
    );
    void loadNativeNotifications().then((notifications) => {
      if (cancelado || !notifications) return;
      suscripciones.push(notifications.addNotificationResponseReceivedListener(() => stopPhoneAlarmTone()));
    });
    return () => {
      cancelado = true;
      for (const s of suscripciones) s.remove();
    };
  }, [lostModeActive]);
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
    if (Test-Path ($ruta + ".bak-sirena-apaga")) { Mal ("Ya existe " + $t + ".bak-sirena-apaga. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-sirena-apaga"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-sirena-apaga): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-sirena-apaga") -Destination $ruta -Force }
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
    foreach ($t in $tocados) { $ruta = Join-Path $raiz $t; if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-sirena-apaga") -Destination $ruta -Force } }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "LISTO: la app compila bien. Sale en la PROXIMA build (Android)."
Write-Host ""
