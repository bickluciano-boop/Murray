# probar-aviso-android.ps1 - Diagnostico: manda 3 avisos de prueba al Android (A sin canal, B canal "ojo-busqueda-v2",
# C canal "ojo-alertas") directo al servicio de avisos de Expo y muestra lo que contesta. No toca ningun archivo.
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Lee de la base el token de los Android aprobados (no lo muestra entero).
$ErrorActionPreference = "Continue"
function Ok($t)  { Write-Host ("OK    " + $t) -ForegroundColor Green }
function Mal($t) { Write-Host ("MAL   " + $t) -ForegroundColor Red }
function Avi($t) { Write-Host ("AVISO " + $t) -ForegroundColor Yellow }
$raiz = (Get-Location).Path
if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"

# --- 1) Buscar los Android en la base ---
$sql = "SELECT id, name, owner_email, push_token, last_seen_at FROM devices WHERE platform = 'android' AND push_token IS NOT NULL AND approval_status = 'approved' ORDER BY last_seen_at DESC LIMIT 3"
$salida = (& npx.cmd wrangler d1 execute ojo-guard-ms --remote --json --command $sql 2>&1 | ForEach-Object { "$_" }) -join "`n"
$ini = $salida.IndexOf("["); $fin = $salida.LastIndexOf("]")
if ($ini -lt 0 -or $fin -le $ini) { Mal "No pude leer la base. Mandame esta pantalla."; Write-Host $salida; return }
try { $filas = @((($salida.Substring($ini, $fin - $ini + 1)) | ConvertFrom-Json)[0].results) } catch { Mal "No entendi lo que contesto la base. Mandame esta pantalla."; Write-Host $salida; return }
if ($filas.Count -eq 0) { Mal "No hay ningun Android aprobado con token de avisos en la base."; return }
Ok ("Android encontrados: " + $filas.Count)

# --- 2) Mandar las tres pruebas a cada uno ---
$pruebas = @(
    @("A", $null, "Sin canal (como salen los avisos hoy)"),
    @("B", "ojo-busqueda-v2", "Canal ojo-busqueda-v2"),
    @("C", "ojo-alertas", "Canal ojo-alertas")
)
$tickets = @()
foreach ($f in $filas) {
    $limpio = $f.push_token.TrimEnd("]"); $fin6 = $limpio.Substring([Math]::Max(0, $limpio.Length - 6))
    Write-Host ""
    Write-Host ("Celular: " + $f.name + " (" + $f.owner_email + "), visto por ultima vez " + $f.last_seen_at + ", token ..." + $fin6) -ForegroundColor Cyan
    foreach ($p in $pruebas) {
        $m = [ordered]@{ to = $f.push_token; title = ("Prueba " + $p[0] + " de Ojo Guard"); body = $p[2]; sound = "default"; priority = "high"; ttl = 600; data = @{} }
        if ($p[1]) { $m["channelId"] = $p[1] }
        $cuerpo = "[" + ($m | ConvertTo-Json -Compress -Depth 5) + "]"
        try {
            $r = Invoke-RestMethod -Method Post -Uri "https://exp.host/--/api/v2/push/send" -ContentType "application/json" -Body $cuerpo
            $t = $r.data[0]
            if ($t.status -eq "ok") { Ok ("Prueba " + $p[0] + ": Expo la acepto (ticket " + $t.id + ")"); $tickets += ,@($p[0], $t.id) }
            else { Mal ("Prueba " + $p[0] + ": Expo la rechazo: " + $t.message + " | " + ($t.details | ConvertTo-Json -Compress)) }
        } catch { Mal ("Prueba " + $p[0] + ": no pude hablar con Expo: " + $_.Exception.Message) }
    }
}

# --- 3) Pedir los recibos (lo que paso despues con Google/Firebase) ---
if ($tickets.Count -gt 0) {
    Write-Host ""
    Avi "Espero 25 segundos y le pregunto a Expo si Google entrego los avisos..."
    Start-Sleep -Seconds 25
    try {
        $ids = @($tickets | ForEach-Object { $_[1] })
        $cuerpo = (@{ ids = $ids } | ConvertTo-Json -Compress)
        $r = Invoke-RestMethod -Method Post -Uri "https://exp.host/--/api/v2/push/getReceipts" -ContentType "application/json" -Body $cuerpo
        foreach ($t in $tickets) {
            $rec = $r.data.($t[1])
            if (-not $rec) { Avi ("Prueba " + $t[0] + ": Expo todavia no tiene el recibo") }
            elseif ($rec.status -eq "ok") { Ok ("Prueba " + $t[0] + ": entregada a Google (recibo ok)") }
            else { Mal ("Prueba " + $t[0] + ": " + $rec.message + " | " + ($rec.details | ConvertTo-Json -Compress)) }
        }
    } catch { Mal ("No pude pedir los recibos: " + $_.Exception.Message) }
}
Write-Host ""
Write-Host "Ahora mira el Android: tienen que haber aparecido avisos 'Prueba A / B / C de Ojo Guard'. Decime cuales viste." -ForegroundColor Cyan
