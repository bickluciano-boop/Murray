# aplicar-sos-sirena-app-panel.ps1 - Ojo Guard MS: el SOS tambien hace sonar la sirena DESDE LA APP en los Android que lo reciben (el mismo camino que "Hacer sonar").
# Luciano (03/11/2026): un SOS del iPhone llego al Android como notificacion pero sin sirena, y "Hacer sonar" desde el panel si sono. "Hacer sonar" manda dos avisos: uno de datos que despierta la app para que toque la sirena ella misma y otro visible; el SOS mandaba solo el visible, cuyo sonido depende de Android.
# Ahora, por cada Android del que recibe el SOS: una orden "alarm" que vence a los 3 minutos + el mismo aviso doble de "Hacer sonar" (con el titulo "SOS"). iPhone no cambia. Si algo falla en esta parte, el aviso, el mail y el SMS del SOS ya salieron.
# Cambia SOLO src\index.ts (respaldo .bak-sosapp). Va en la carpeta del PANEL (la que tiene wrangler.toml). No necesita build de la app. Al final publica el panel solo.
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
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'sos_sirena_app_failed') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
$cambios = @(
    ,@('src\index.ts', 'SOS: despertar a la app de los Android para que toque la sirena (como Hacer sonar)', '    await familySosMail(env, r, nombre, ubicacionObj).catch((error) => console.error("family_sos_mail_failed", error));
', '    // Android: ademas del aviso (su sonido lo decide Android: volumen de alarma, No interrumpir, enfriamiento de avisos repetidos) se despierta a la app con el MISMO camino de
    // "Hacer sonar" (orden "alarm" + aviso de datos que despierta la tarea de la app), que toca la sirena por su cuenta. La orden vence a los 3 minutos: asi el reintento del cron
    // (retryPendingCommandsCron) no vuelve a mandar la sirena mas tarde. iPhone queda como estaba. Si algo falla aca, el aviso y el mail del SOS ya salieron.
    try {
      const androids = await env.DB.prepare("SELECT id, name, push_token AS pushToken FROM devices WHERE owner_email=? AND approval_status=''approved'' AND push_token IS NOT NULL AND platform=''android''")
        .bind(r).all<{ id: string; name: string; pushToken: string }>();
      for (const equipo of androids.results) {
        const idOrden = randomId("cmd");
        await env.DB.prepare("INSERT INTO commands (id,device_id,owner_email,type,status,created_at,expires_at) VALUES (?,?,?,?,?,?,?)")
          .bind(idOrden, equipo.id, r, "alarm", "pending", now(), plusMinutes(3)).run();
        await sendExpoCommandPush(equipo.pushToken, "alarm", idOrden, equipo.name, { title: "SOS", body: `${nombre} pidi\u00f3 ayuda. Abr\u00ed el mapa para ver d\u00f3nde est\u00e1.` }).catch(() => false);
      }
    } catch (error) {
      console.error("sos_sirena_app_failed", error);
    }
    await familySosMail(env, r, nombre, ubicacionObj).catch((error) => console.error("family_sos_mail_failed", error));
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
    if (Test-Path ($ruta + ".bak-sosapp")) { Mal ("Ya existe " + $t + ".bak-sosapp. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-sosapp"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-sosapp): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-sosapp") -Destination $ruta -Force }
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
Ok "LISTO: el SOS ya hace sonar la sirena desde la app en los Android que lo reciben."
Write-Host ""
