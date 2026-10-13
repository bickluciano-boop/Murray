# probar-aviso-iphone.ps1 - Diagnostico: manda 2 avisos de prueba al iPhone de lubick@me.com (uno comun y otro con la sirena de Ojo
# Guard), y pregunta a Expo si Apple los acepto. Solo a ese iPhone. No toca ningun archivo ni la base.
# Va en la carpeta del PANEL (la que tiene wrangler.toml).
$ErrorActionPreference = "Continue"
function Ok($t)  { Write-Host ("OK    " + $t) -ForegroundColor Green }
function Mal($t) { Write-Host ("MAL   " + $t) -ForegroundColor Red }
function Avi($t) { Write-Host ("AVISO " + $t) -ForegroundColor Yellow }
$raiz = (Get-Location).Path
if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"

$sql = "SELECT name, push_token, last_seen_at, last_location_at FROM devices WHERE owner_email = 'lubick@me.com' AND platform = 'ios' AND approval_status = 'approved' AND push_token IS NOT NULL ORDER BY last_seen_at DESC LIMIT 1"
$salida = (& npx.cmd wrangler d1 execute ojo-guard-ms --remote --json --command $sql 2>&1 | ForEach-Object { "$_" }) -join "`n"
$ini = $salida.IndexOf("["); $fin = $salida.LastIndexOf("]")
if ($ini -lt 0 -or $fin -le $ini) { Mal "No pude leer la base. Mandame esta pantalla."; Write-Host $salida; return }
try { $filas = @((($salida.Substring($ini, $fin - $ini + 1)) | ConvertFrom-Json)[0].results) } catch { Mal "No entendi lo que contesto la base. Mandame esta pantalla."; Write-Host $salida; return }
if ($filas.Count -eq 0) { Mal "No encontre el iPhone de lubick@me.com con avisos en la base."; return }
$f = $filas[0]
$token = $f.push_token
$limpio = $token.TrimEnd("]")
Ok ("iPhone: " + $f.name + " (token ..." + $limpio.Substring([Math]::Max(0, $limpio.Length - 6)) + ")")
Write-Host ("   Ultimo contacto de la app con el servidor: " + $f.last_seen_at + " (UTC)")

$pruebas = @(
    @("A", "Prueba A de Ojo Guard", "Aviso comun, con el sonido normal.", "default"),
    @("B", "Prueba B de Ojo Guard", "Aviso con la sirena de Ojo Guard.", "ojo_sirena.wav")
)
$tickets = @()
Write-Host ""
Write-Host "Tene el iPhone a mano. Salen 2 avisos." -ForegroundColor Cyan
foreach ($p in $pruebas) {
    $m = [ordered]@{ to = $token; title = $p[1]; body = $p[2]; sound = $p[3]; priority = "high"; ttl = 600; data = @{} }
    $cuerpo = "[" + ($m | ConvertTo-Json -Compress -Depth 5) + "]"
    try {
        $r = Invoke-RestMethod -Method Post -Uri "https://exp.host/--/api/v2/push/send" -ContentType "application/json; charset=utf-8" -Body ([System.Text.Encoding]::UTF8.GetBytes($cuerpo))
        $t = $r.data[0]
        if ($t.status -eq "ok") { Ok ("Prueba " + $p[0] + ": Expo la acepto (ticket " + $t.id + ")"); $tickets += ,@($p[0], $t.id) }
        else { Mal ("Prueba " + $p[0] + ": Expo la rechazo: " + $t.message + " | " + ($t.details | ConvertTo-Json -Compress)) }
    } catch { Mal ("Prueba " + $p[0] + ": no pude hablar con Expo: " + $_.Exception.Message) }
    Start-Sleep -Seconds 6
}

if ($tickets.Count -gt 0) {
    Write-Host ""
    Avi "Espero 25 segundos y le pregunto a Expo si Apple entrego los avisos..."
    Start-Sleep -Seconds 25
    try {
        $cuerpo = (@{ ids = @($tickets | ForEach-Object { $_[1] }) } | ConvertTo-Json -Compress)
        $r = Invoke-RestMethod -Method Post -Uri "https://exp.host/--/api/v2/push/getReceipts" -ContentType "application/json" -Body $cuerpo
        foreach ($t in $tickets) {
            $rec = $r.data.($t[1])
            if (-not $rec) { Avi ("Prueba " + $t[0] + ": Expo todavia no tiene el recibo") }
            elseif ($rec.status -eq "ok") { Ok ("Prueba " + $t[0] + ": Apple lo recibio (recibo ok)") }
            else { Mal ("Prueba " + $t[0] + ": NO entregado: " + $rec.message + " | " + ($rec.details | ConvertTo-Json -Compress)) }
        }
    } catch { Mal ("No pude pedir los recibos: " + $_.Exception.Message) }
}
Write-Host ""
Write-Host "Ahora mira el iPhone, incluso el Centro de notificaciones: tienen que estar 'Prueba A' y 'Prueba B'. Decime cuales viste y cual sono." -ForegroundColor Cyan
