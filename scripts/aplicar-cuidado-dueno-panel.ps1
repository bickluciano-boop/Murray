# aplicar-cuidado-dueno-panel.ps1 - Ojo Guard MS (servidor): (1) el aviso de BATERIA BAJA (15%) le llega solo al dueno del telefono, ya no a la familia (la familia sigue viendo el porcentaje en el mapa);
# (2) el aviso de SIN SENAL a la familia pasa de 3 a 6 horas. Luciano (17/11/2026): "3 es comun: puede que esten en un lugar sin senal y despues una siesta".
# Cambia src\index.ts (respaldo .bak-cuidadodueno). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
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

if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\index.ts"))) { Mal "No encuentro src\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'care_bat') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
$cambios = @(
    @('src\index.ts', 'cuidado: sin senal a la familia a las 6 horas (antes 3)', 'CUIDADO_SIN_SENAL_MIN = 180,', 'CUIDADO_SIN_SENAL_MIN = 360,'),
    @('src\index.ts', 'cuidado: tabla care_bat (bateria baja por telefono)', '  await env.DB.prepare("CREATE TABLE IF NOT EXISTS care_state (email TEXT PRIMARY KEY, bat_low INTEGER NOT NULL DEFAULT 0, silence_at TEXT, bd_day TEXT, bd_sent_at TEXT, bd_ok_at TEXT, bd_alert_at TEXT)").run();
', '  await env.DB.prepare("CREATE TABLE IF NOT EXISTS care_state (email TEXT PRIMARY KEY, bat_low INTEGER NOT NULL DEFAULT 0, silence_at TEXT, bd_day TEXT, bd_sent_at TEXT, bd_ok_at TEXT, bd_alert_at TEXT)").run();
  await env.DB.prepare("CREATE TABLE IF NOT EXISTS care_bat (device_id TEXT PRIMARY KEY, low INTEGER NOT NULL DEFAULT 0)").run();
'),
    @('src\index.ts', 'cuidado: la lista de telefonos trae su id y su token de aviso', '    const equipos = await env.DB.prepare("SELECT owner_email AS email, battery, last_seen_at AS lastSeenAt FROM devices WHERE approval_status=''approved'' AND device_role=''primary''")
      .all<{ email: string; battery: number | null; lastSeenAt: string | null }>();', '    const equipos = await env.DB.prepare("SELECT id AS id, push_token AS pushToken, owner_email AS email, battery, last_seen_at AS lastSeenAt FROM devices WHERE approval_status=''approved'' AND device_role=''primary''")
      .all<{ id: string; pushToken: string | null; email: string; battery: number | null; lastSeenAt: string | null }>();'),
    @('src\index.ts', 'cuidado: el aviso de bateria baja va solo al dueno del telefono', '        if (typeof eq.battery === "number") {
          if (eq.battery <= CUIDADO_BATERIA_BAJA && !e.bat_low && calladoMin !== null && calladoMin < 360) {
            const n = eq.battery;
            await cuidadoAvisar(env, eq.email, (nombre) => `${nombre} tiene la batería baja (${n}%).`, "cuidado bateria");
            e.bat_low = 1; cambio = true;
          } else if (eq.battery >= CUIDADO_BATERIA_OK && e.bat_low) { e.bat_low = 0; cambio = true; }
        }', '        // El aviso es SOLO para el dueno del telefono (la familia sigue viendo el porcentaje en el mapa, pero no recibe este aviso). Un aviso por bajada y por telefono; se rearma al volver a subir. De 23 a 7 no se avisa: si sigue baja a las 7, ahi se avisa.
        if (typeof eq.battery === "number") {
          const bajaAntes = Boolean((await env.DB.prepare("SELECT low FROM care_bat WHERE device_id=?").bind(eq.id).first<{ low: number }>())?.low);
          const horaBat = cuidadoLocal(ahoraMs, prefs.tz).hora;
          const nocheBat = horaBat >= 23 || horaBat < 7;
          if (eq.battery <= CUIDADO_BATERIA_BAJA && !bajaAntes && !nocheBat && calladoMin !== null && calladoMin < 360) {
            await env.DB.prepare("INSERT OR REPLACE INTO care_bat (device_id, low) VALUES (?,1)").bind(eq.id).run();
            if (eq.pushToken) await sendExpoNoticeLogged(env, eq.pushToken, "Batería baja", `Tu batería está en ${eq.battery}%. Conecta el cargador.`, "cuidado bateria propia", { channelId: "ojo-alertas" }).catch(() => false);
          } else if (eq.battery >= CUIDADO_BATERIA_OK && bajaAntes) {
            await env.DB.prepare("INSERT OR REPLACE INTO care_bat (device_id, low) VALUES (?,0)").bind(eq.id).run();
          }
        }'),
    @('src\index.ts', 'cuidado: el reloj de sin senal se pausa de 23 a 7', '          const hora = cuidadoLocal(ahoraMs, prefs.tz).hora;
          const deNoche = hora >= 23 || hora < 7;
          if (!e.silence_at && calladoMin >= CUIDADO_SIN_SENAL_MIN && !deNoche) {', '          const hora = cuidadoLocal(ahoraMs, prefs.tz).hora;
          const deNoche = hora >= 23 || hora < 7;
          // El reloj del "sin senal" se PAUSA de 23 a 7 (hora de la persona): dormir con el telefono apagado o sin senal no cuenta, asi no se avisa a la familia justo al despertar.
          const despiertoMin = cuidadoMinutosDespierto(visto, ahoraMs, prefs.tz);
          if (!e.silence_at && despiertoMin >= CUIDADO_SIN_SENAL_MIN && !deNoche) {'),
    @('src\index.ts', 'cuidado: funcion que cuenta el silencio solo despierto', 'function cuidadoLocal(ahoraMs: number, tzMin: number) {
', '/** Minutos de silencio contando solo las horas despierto (de 7 a 23, hora de la persona): de 23 a 7 el reloj se pausa. */
function cuidadoMinutosDespierto(desdeMs: number, hastaMs: number, tzMin: number) {
  let despierto = 0;
  for (let t = Math.max(desdeMs, hastaMs - 72 * 3600_000); t < hastaMs; t += 15 * 60_000) {
    const h = cuidadoLocal(t, tzMin).hora;
    if (h >= 7 && h < 23) despierto += Math.min(15, (hastaMs - t) / 60_000);
  }
  return despierto;
}
function cuidadoLocal(ahoraMs: number, tzMin: number) {
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
    if (Test-Path ($ruta + ".bak-cuidadodueno")) { Mal ("Ya existe " + $t + ".bak-cuidadodueno. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-cuidadodueno"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-cuidadodueno): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-cuidadodueno") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "Archivos listos. Ahora publico el panel..."
& npx.cmd wrangler deploy
if ($LASTEXITCODE -ne 0) { Mal "No se pudo publicar el panel. Mandame esta pantalla."; return }
Write-Host ""
Ok "LISTO: el aviso de bateria baja le llega solo al dueno del telefono y el aviso de sin senal a la familia pasa a las 6 horas."
Write-Host ""
