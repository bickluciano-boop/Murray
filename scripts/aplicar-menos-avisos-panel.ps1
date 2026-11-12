# aplicar-menos-avisos-panel.ps1 - Ojo Guard MS: que el Modo Cautela y la vigilancia de silencio NO manden avisos todo el tiempo (cada SMS y cada mail cuesta, y si avisan de mas nadie les cree el dia que es de verdad).
# Luciano (12/11/2026). En su base: silencio 10 minutos (de dia y de noche), bateria 50 %, "lejos" a 1 km, y la regla de silencio de cada equipo en 45 minutos: un Android en segundo plano reporta cada tanto y saltaba cada hora.
# 1) Minimos sensatos: silencio de noche >= 60 min, de dia >= 180, "lejos" >= 2 km, bateria <= 30 % (lo ya guardado se corrige solo al leerlo; los recomendados 90/360/3/15 no cambian).
# 2) Cautela: despues de cerrar un episodio no se abre otro hasta pasadas 6 horas. 3) Silencio de un equipo: sin causa aparente 4 horas (antes 45 minutos) y no se rearma hasta 6 horas despues del ultimo aviso.
# Cambia src\index.ts y src\deviceSilence.ts (respaldo .bak-menos-avisos). Va en la carpeta del PANEL (la que tiene wrangler.toml). Sin build. Al final publica el panel solo.
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
foreach ($f in @("src\index.ts", "src\deviceSilence.ts")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'async function pldEnfriando') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
$cambios = @(
    @('src\index.ts', 'cautela: minimos de las condiciones (lectura)', '    silenceNightMin: pldNumero(f.silenceNightMin, 10, 1440, PLD_POR_DEFECTO.silenceNightMin),
    silenceDayMin: pldNumero(f.silenceDayMin, 10, 2880, PLD_POR_DEFECTO.silenceDayMin),
    farKm: pldNumero(f.farKm, 0.5, 200, PLD_POR_DEFECTO.farKm),
    batteryPct: pldNumero(f.batteryPct, 1, 50, PLD_POR_DEFECTO.batteryPct),
', '    // Minimos y maximos sensatos: con valores de prueba (10 minutos, bateria 50 %, 1 km) el aviso saltaba todo el tiempo. Lo ya guardado se corrige solo al leerlo.
    silenceNightMin: pldNumero(f.silenceNightMin, 60, 1440, PLD_POR_DEFECTO.silenceNightMin),
    silenceDayMin: pldNumero(f.silenceDayMin, 180, 2880, PLD_POR_DEFECTO.silenceDayMin),
    farKm: pldNumero(f.farKm, 2, 200, PLD_POR_DEFECTO.farKm),
    batteryPct: pldNumero(f.batteryPct, 1, 30, PLD_POR_DEFECTO.batteryPct),
'),
    @('src\index.ts', 'cautela: minimos de las condiciones (guardado)', '      silenceNightMin: Math.round(pldNumero(c.silenceNightMin, 10, 1440, cfg.silenceNightMin)),
      silenceDayMin: Math.round(pldNumero(c.silenceDayMin, 10, 2880, cfg.silenceDayMin)),
      farKm: pldNumero(c.farKm, 0.5, 200, cfg.farKm),
      batteryPct: Math.round(pldNumero(c.batteryPct, 1, 50, cfg.batteryPct)),
', '      silenceNightMin: Math.round(pldNumero(c.silenceNightMin, 60, 1440, cfg.silenceNightMin)),
      silenceDayMin: Math.round(pldNumero(c.silenceDayMin, 180, 2880, cfg.silenceDayMin)),
      farKm: pldNumero(c.farKm, 2, 200, cfg.farKm),
      batteryPct: Math.round(pldNumero(c.batteryPct, 1, 30, cfg.batteryPct)),
'),
    @('src\index.ts', 'cautela: minimo de la pantalla (noche)', 'id="cSilNoche" type="number" min="10"', 'id="cSilNoche" type="number" min="60"'),
    @('src\index.ts', 'cautela: minimo de la pantalla (dia)', 'id="cSilDia" type="number" min="10"', 'id="cSilDia" type="number" min="180"'),
    @('src\index.ts', 'cautela: espera despues de un episodio (funciones)', 'async function pldCronPersona(env: Env, email: string) {
', '// Despues de cerrar un episodio (el telefono volvio a dar senal) no se abre otro hasta pasadas PLD_ENFRIAR_HORAS horas: un telefono que da senal de a ratos
// no tiene que mandar un "¿Estas bien?" cada hora. "Apagado en movimiento con bateria alta" no espera.
const PLD_ENFRIAR_HORAS = 6;
let pldEnfriarTabla = false;
async function pldEnfriarLista(env: Env) {
  if (pldEnfriarTabla) return;
  await env.DB.prepare("CREATE TABLE IF NOT EXISTS pld_enfriar (owner_email TEXT PRIMARY KEY, hasta TEXT NOT NULL)").run();
  pldEnfriarTabla = true;
}
async function pldEnfriar(env: Env, email: string) {
  await pldEnfriarLista(env);
  await env.DB.prepare("INSERT OR REPLACE INTO pld_enfriar (owner_email,hasta) VALUES (?,?)").bind(email, new Date(Date.now() + PLD_ENFRIAR_HORAS * 3_600_000).toISOString()).run();
}
async function pldEnfriando(env: Env, email: string) {
  await pldEnfriarLista(env);
  const f = await env.DB.prepare("SELECT hasta FROM pld_enfriar WHERE owner_email=?").bind(email).first<{ hasta: string }>();
  return Boolean(f && f.hasta > new Date(Date.now()).toISOString());
}

async function pldCronPersona(env: Env, email: string) {
'),
    @('src\index.ts', 'cautela: anotar la espera al cerrar el episodio', '    await env.DB.prepare("DELETE FROM pld_episodios WHERE owner_email=?").bind(email).run();
    let avisados = 0;
', '    await env.DB.prepare("DELETE FROM pld_episodios WHERE owner_email=?").bind(email).run();
    let avisados = 0;
    await pldEnfriar(env, email).catch(() => undefined);
'),
    @('src\index.ts', 'cautela: no abrir otro episodio enseguida', '    if (respondio) return; // dijo que estaba bien hace poco
', '    if (respondio) return; // dijo que estaba bien hace poco
    if (!estado.apagadoEnMovimiento && (await pldEnfriando(env, email).catch(() => false))) return; // el telefono volvio a dar senal hace poco: no se abre otro episodio enseguida
'),
    @('src\index.ts', 'cautela: la espera se borra con la cuenta', '  await borrar("pld_episodios", "DELETE FROM pld_episodios WHERE owner_email=?", 1);
', '  await pldEnfriarLista(env).catch(() => undefined);
  await borrar("pld_episodios", "DELETE FROM pld_episodios WHERE owner_email=?", 1);
  await borrar("pld_enfriar", "DELETE FROM pld_enfriar WHERE owner_email=?", 1);
'),
    @('src\index.ts', 'silencio: no rearmar hasta pasadas 6 horas', '        if (device.silenceAlertAt && device.lastSeenAt && device.lastSeenAt > device.silenceAlertAt) {
          await env.DB.prepare("UPDATE devices SET silence_alert_at=NULL WHERE id=?").bind(device.id).run();
          return;
        }
', '        if (device.silenceAlertAt && device.lastSeenAt && device.lastSeenAt > device.silenceAlertAt) {
          // Un telefono que da senal de a ratos no puede avisar cada hora: se rearma recien pasadas 6 horas del ultimo aviso.
          if (nowMs - Date.parse(device.silenceAlertAt) >= 6 * 3_600_000) {
            await env.DB.prepare("UPDATE devices SET silence_alert_at=NULL WHERE id=?").bind(device.id).run();
          }
          return;
        }
'),
    @('src\deviceSilence.ts', 'silencio sin causa aparente: 4 horas (antes 45 minutos)', 'export const SILENCE_UNEXPLAINED_MINUTES = 45;', 'export const SILENCE_UNEXPLAINED_MINUTES = 240;')
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
    if (Test-Path ($ruta + ".bak-menos-avisos")) { Mal ("Ya existe " + $t + ".bak-menos-avisos. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-menos-avisos"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-menos-avisos): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-menos-avisos") -Destination $ruta -Force }
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
Ok "LISTO: el Modo Cautela y la vigilancia de silencio avisan mucho menos."
Write-Host ""
