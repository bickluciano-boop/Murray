# aplicar-cuidado-lugares-panel.ps1 - Ojo Guard MS (servidor): el aviso de SIN SENAL a la familia mira la ultima ubicacion conocida del telefono.
# Luciano (17/11/2026): "preocuparemos a todos por nada; tiene que ser algo pensante: si es un lugar conocido frecuente no tendria que alarmarse; si es la primera vez, llama la atencion".
# En un lugar guardado (Casa, Trabajo...) espera hasta 24 h; en un lugar desconocido avisa a las 6 h y dice la ultima ubicacion conocida. Requiere aplicar-cuidado-dueno-panel.ps1. Cambia src\index.ts (respaldo .bak-cuidadolugares). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
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
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'cuidadoLugarConocido') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'care_bat') -eq 0) { Mal "Falta aplicar primero aplicar-cuidado-dueno-panel.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'function metersBetween') -eq 0) { Mal "Falta la funcion de distancias (aplicar-en-vivo-panel.ps1). No toco nada."; return }
$cambios = @(
    @('src\index.ts', 'lugares: limite de 24 h cuando la ultima ubicacion era un lugar conocido', 'CUIDADO_SIN_SENAL_MIN = 360,', 'CUIDADO_SIN_SENAL_MIN = 360, CUIDADO_SIN_SENAL_CONOCIDO_MIN = 1440,'),
    @('src\index.ts', 'lugares: funcion que dice si la ultima ubicacion era un lugar conocido', '/** Minutos de silencio contando solo las horas despierto (de 7 a 23, hora de la persona): de 23 a 7 el reloj se pausa. */
', '/** La ultima ubicacion conocida del telefono, y si estaba dentro de un lugar guardado (los propios o los de las familias de las que la persona es miembro). */
async function cuidadoLugarConocido(env: Env, dispositivo: string, email: string) {
  const ult = await env.DB.prepare("SELECT latitude, longitude, address FROM location_history WHERE device_id=? ORDER BY captured_at DESC LIMIT 1").bind(dispositivo)
    .first<{ latitude: number; longitude: number; address: string | null }>().catch(() => null);
  if (!ult || !Number.isFinite(Number(ult.latitude)) || !Number.isFinite(Number(ult.longitude))) return { conocido: false, direccion: null as string | null };
  const lugares = await env.DB.prepare("SELECT latitude, longitude, radius FROM family_places WHERE owner_email=? OR owner_email IN (SELECT owner_email FROM family_members WHERE member_email=? AND status=''activo'')").bind(email, email)
    .all<{ latitude: number; longitude: number; radius: number }>().catch(() => ({ results: [] as Array<{ latitude: number; longitude: number; radius: number }> }));
  const punto = { latitude: Number(ult.latitude), longitude: Number(ult.longitude) };
  const conocido = lugares.results.some((l) => metersBetween(punto, { latitude: Number(l.latitude), longitude: Number(l.longitude) }) <= Number(l.radius) + 100);
  return { conocido, direccion: ult.address ? String(ult.address).slice(0, 120) : null };
}
/** Minutos de silencio contando solo las horas despierto (de 7 a 23, hora de la persona): de 23 a 7 el reloj se pausa. */
'),
    @('src\index.ts', 'lugares: el aviso de sin senal decide segun la ultima ubicacion conocida', '          if (!e.silence_at && despiertoMin >= CUIDADO_SIN_SENAL_MIN && !deNoche) {
            const horas = Math.floor(calladoMin / 60), bat = typeof eq.battery === "number" ? ` Su batería era ${eq.battery}%.` : "";
            await cuidadoAvisar(env, eq.email, (nombre) => `No tenemos señal de ${nombre} desde hace ${horas} h.${bat}`, "cuidado sin senal");
            e.silence_at = new Date(ahoraMs).toISOString(); cambio = true;
          }', '          if (!e.silence_at && despiertoMin >= CUIDADO_SIN_SENAL_MIN && !deNoche) {
            // Si la ultima ubicacion era un lugar conocido (Casa, Trabajo...), no se alarma a nadie hasta las 24 h; si era un lugar desconocido, se avisa y se dice donde fue.
            const lugar = await cuidadoLugarConocido(env, eq.id, eq.email);
            if (!lugar.conocido || despiertoMin >= CUIDADO_SIN_SENAL_CONOCIDO_MIN) {
              const horas = Math.floor(calladoMin / 60), bat = typeof eq.battery === "number" ? ` Su batería era ${eq.battery}%.` : "", donde = lugar.direccion ? ` Última ubicación conocida: ${lugar.direccion}.` : "";
              await cuidadoAvisar(env, eq.email, (nombre) => `No tenemos señal de ${nombre} desde hace ${horas} h.${bat}${donde}`, "cuidado sin senal");
              e.silence_at = new Date(ahoraMs).toISOString(); cambio = true;
            }
          }')
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
    if (Test-Path ($ruta + ".bak-cuidadolugares")) { Mal ("Ya existe " + $t + ".bak-cuidadolugares. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-cuidadolugares"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-cuidadolugares): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-cuidadolugares") -Destination $ruta -Force }
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
Ok "LISTO: el aviso de sin senal mira la ultima ubicacion: en un lugar conocido espera 24 h, en uno desconocido avisa a las 6 h con la direccion."
Write-Host ""
