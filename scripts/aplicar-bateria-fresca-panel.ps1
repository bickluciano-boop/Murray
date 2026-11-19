# aplicar-bateria-fresca-panel.ps1 - Ojo Guard MS (servidor): el aviso de "Bateria baja" solo sale con un dato de bateria RECIENTE (menos de 30 minutos).
# Luciano (19/11/2026): el iPhone recibio "Tu bateria esta en 5 %" con ~35 %. Causa: COALESCE(?,battery) conserva la bateria vieja si el telefono avisa sin dato, mientras la hora de conexion se actualiza (src\index.ts, estado del telefono).
# Crea la tabla battery_fresh sola. Requiere aplicar-cuidado-dueno-panel.ps1. Cambia src\index.ts (respaldo .bak-bateriafresca). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
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
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'battery_fresh') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'care_bat') -eq 0) { Mal "Falta aplicar primero aplicar-cuidado-dueno-panel.ps1."; return }
$cambios = @(
    @('src\index.ts', 'bateria fresca: el estado del telefono anota la hora del dato de bateria real', '  const rawBattery = body.battery == null ? null : Number(body.battery);
  const battery = rawBattery == null || !Number.isFinite(rawBattery)
    ? null
    : Math.max(0, Math.min(100, Math.round(rawBattery)));
  await env.DB.prepare("UPDATE devices SET push_token=COALESCE(?,push_token),battery=COALESCE(?,battery),last_seen_at=? WHERE id=?")
    .bind(pushToken, battery, now(), deviceId).run();
  return json({ updated: true });
', '  const rawBattery = body.battery == null ? null : Number(body.battery);
  // Una bateria negativa (el telefono no pudo leerla) es "sin dato", no 0 %.
  const battery = rawBattery == null || !Number.isFinite(rawBattery) || rawBattery < 0
    ? null
    : Math.max(0, Math.min(100, Math.round(rawBattery)));
  await env.DB.prepare("UPDATE devices SET push_token=COALESCE(?,push_token),battery=COALESCE(?,battery),last_seen_at=? WHERE id=?")
    .bind(pushToken, battery, now(), deviceId).run();
  // Se anota la hora SOLO cuando llega un dato de bateria real: COALESCE conserva la bateria vieja si el telefono avisa sin dato, y el aviso de bateria baja
  // (19/11/2026: "5 %" con el iPhone al 35 %) no debe salir con un dato viejo.
  if (battery !== null) {
    await env.DB.prepare("CREATE TABLE IF NOT EXISTS battery_fresh (device_id TEXT PRIMARY KEY, at TEXT NOT NULL)").run().catch(() => undefined);
    await env.DB.prepare("INSERT OR REPLACE INTO battery_fresh (device_id, at) VALUES (?,?)").bind(deviceId, now()).run().catch(() => undefined);
  }
  return json({ updated: true });
'),
    @('src\index.ts', 'bateria fresca: el aviso de bateria baja exige un dato reciente', '          const nocheBat = horaBat >= 23 || horaBat < 7;
          if (eq.battery <= CUIDADO_BATERIA_BAJA && !bajaAntes && !nocheBat && calladoMin !== null && calladoMin < 360) {', '          const nocheBat = horaBat >= 23 || horaBat < 7;
          // Solo se avisa con un dato de bateria RECIENTE (de los ultimos 30 minutos, tabla battery_fresh); si la tabla todavia no existe o el dato es viejo, no se avisa.
          const bateriaAt = (await env.DB.prepare("SELECT at FROM battery_fresh WHERE device_id=?").bind(eq.id).first<{ at: string }>().catch(() => null))?.at;
          const bateriaFresca = Boolean(bateriaAt) && ahoraMs - Date.parse(String(bateriaAt)) < 30 * 60_000;
          if (eq.battery <= CUIDADO_BATERIA_BAJA && bateriaFresca && !bajaAntes && !nocheBat && calladoMin !== null && calladoMin < 360) {')
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
    if (Test-Path ($ruta + ".bak-bateriafresca")) { Mal ("Ya existe " + $t + ".bak-bateriafresca. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-bateriafresca"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-bateriafresca): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-bateriafresca") -Destination $ruta -Force }
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
Ok "LISTO: el aviso de bateria baja solo sale con un dato de bateria de los ultimos 30 minutos (y una bateria negativa ya no cuenta como 0 %)."
Write-Host ""
