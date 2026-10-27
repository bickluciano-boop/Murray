# probar-sos-xiaomi.ps1 - Diagnostico del SOS en tu Xiaomi: manda 3 avisos de prueba (como el SOS real) SOLO a tu equipo "Android Lucian..." y pregunta a Expo si los entrego.
# Es la version segura de probar-sos-android.ps1: aquella elegia "el Android visto mas recientemente de tu cuenta", y desde que los telefonos de tu papa y de Guido estan en tu cuenta podia mandarles la prueba a ellos.
# No toca ningun archivo ni la base (solo la lee). Va en la carpeta del PANEL (la que tiene wrangler.toml).
$ErrorActionPreference = "Continue"
function Ok($t)  { Write-Host ("OK    " + $t) -ForegroundColor Green }
function Mal($t) { Write-Host ("MAL   " + $t) -ForegroundColor Red }
function Avi($t) { Write-Host ("AVISO " + $t) -ForegroundColor Yellow }
$raiz = (Get-Location).Path
if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"

$sql = "SELECT name, push_token FROM devices WHERE owner_email = 'bickluciano@gmail.com' AND platform = 'android' AND name LIKE 'Android Lucian%' AND push_token IS NOT NULL ORDER BY last_seen_at DESC LIMIT 1"
$salida = (& npx.cmd wrangler d1 execute ojo-guard-ms --remote --json --command $sql 2>&1 | ForEach-Object { "$_" }) -join "`n"
$ini = $salida.IndexOf("["); $fin = $salida.LastIndexOf("]")
if ($ini -lt 0 -or $fin -le $ini) { Mal "No pude leer la base. Mandame esta pantalla."; Write-Host $salida; return }
try { $filas = @((($salida.Substring($ini, $fin - $ini + 1)) | ConvertFrom-Json)[0].results) } catch { Mal "No entendi lo que contesto la base. Mandame esta pantalla."; Write-Host $salida; return }
if ($filas.Count -eq 0) { Mal "No encontre tu equipo Android Lucian... con avisos en la base."; return }
$token = $filas[0].push_token
Ok ("Tu Android: " + $filas[0].name + " (token ..." + $token.TrimEnd("]").Substring($token.Length - 7) + ")")

$datosSos = @{ type = "sos"; sosId = "prueba"; personId = $null; name = "Prueba"; latitude = -34.58; longitude = -58.42 }
$pruebas = @(
    @{ n = "1"; que = "igual al SOS real (canal de la sirena + datos del mapa)"; m = [ordered]@{ to = $token; title = "SOS"; body = "Prueba [1]: igual al SOS real."; sound = "ojo_sirena.wav"; channelId = "ojo-sos"; interruptionLevel = "time-sensitive"; priority = "high"; ttl = 600; data = $datosSos } },
    @{ n = "2"; que = "canal de la sirena, sin datos"; m = [ordered]@{ to = $token; title = "SOS"; body = "Prueba [2]: sin datos del mapa."; sound = "ojo_sirena.wav"; channelId = "ojo-sos"; interruptionLevel = "time-sensitive"; priority = "high"; ttl = 600; data = @{} } },
    @{ n = "3"; que = "canal comun de alertas (el que siempre anduvo)"; m = [ordered]@{ to = $token; title = "Ojo Guard"; body = "Prueba [3]: canal comun."; sound = "default"; channelId = "ojo-alertas"; priority = "high"; ttl = 600; data = @{} } }
)
Write-Host ""
Write-Host "Deja el Android a la vista, con la pantalla apagada o bloqueada. Salen 3 avisos, uno cada 15 segundos." -ForegroundColor Cyan
Start-Sleep -Seconds 5
$ids = @()
foreach ($p in $pruebas) {
    $cuerpo = "[" + ($p.m | ConvertTo-Json -Compress -Depth 6) + "]"
    try {
        $r = Invoke-RestMethod -Method Post -Uri "https://exp.host/--/api/v2/push/send" -ContentType "application/json; charset=utf-8" -Body ([System.Text.Encoding]::UTF8.GetBytes($cuerpo))
        $t = $r.data[0]
        if ($t.status -eq "ok") { Ok ("Aviso [" + $p.n + "] aceptado por Expo (" + $p.que + ")"); $ids += @{ n = $p.n; id = $t.id } }
        else { Mal ("Aviso [" + $p.n + "] rechazado por Expo: " + $t.message + " " + ($t.details | ConvertTo-Json -Compress)) }
    } catch { Mal ("Aviso [" + $p.n + "]: no pude hablar con Expo: " + $_.Exception.Message) }
    Start-Sleep -Seconds 15
}
Write-Host ""
Write-Host "Espero 20 segundos y le pregunto a Expo si los entrego..." -ForegroundColor Cyan
Start-Sleep -Seconds 20
if ($ids.Count -gt 0) {
    $pedido = (@{ ids = @($ids | ForEach-Object { $_.id }) } | ConvertTo-Json -Compress)
    try {
        $rec = Invoke-RestMethod -Method Post -Uri "https://exp.host/--/api/v2/push/getReceipts" -ContentType "application/json" -Body $pedido
        foreach ($x in $ids) {
            $d = $rec.data.($x.id)
            if ($null -eq $d) { Avi ("Aviso [" + $x.n + "]: Expo todavia no tiene el recibo.") }
            elseif ($d.status -eq "ok") { Ok ("Aviso [" + $x.n + "]: Expo dice que lo entrego a Google/Apple.") }
            else { Mal ("Aviso [" + $x.n + "]: Expo dice ERROR: " + $d.message + " " + ($d.details | ConvertTo-Json -Compress)) }
        }
    } catch { Mal ("No pude pedir los recibos: " + $_.Exception.Message) }
}
Write-Host ""
Write-Host "Listo. Mira el Android y decime cuales numeros viste y cuales sonaron: [1] [2] [3]." -ForegroundColor Cyan
