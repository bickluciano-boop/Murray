# probar-aviso-como-alerta.ps1 - Diagnostico: manda al Android de bickluciano 4 avisos que se parecen al de "llego a Casa", cada uno
# con una pequena diferencia, para ver cual se muestra y cual no. Solo a tu cuenta. No toca ningun archivo ni la base.
# Va en la carpeta del PANEL (la que tiene wrangler.toml).
$ErrorActionPreference = "Continue"
function Ok($t)  { Write-Host ("OK    " + $t) -ForegroundColor Green }
function Mal($t) { Write-Host ("MAL   " + $t) -ForegroundColor Red }
function Avi($t) { Write-Host ("AVISO " + $t) -ForegroundColor Yellow }
$raiz = (Get-Location).Path
if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"

$sql = "SELECT name, push_token FROM devices WHERE owner_email = 'bickluciano@gmail.com' AND platform = 'android' AND approval_status = 'approved' AND push_token IS NOT NULL ORDER BY last_seen_at DESC LIMIT 1"
$salida = (& npx.cmd wrangler d1 execute ojo-guard-ms --remote --json --command $sql 2>&1 | ForEach-Object { "$_" }) -join "`n"
$ini = $salida.IndexOf("["); $fin = $salida.LastIndexOf("]")
if ($ini -lt 0 -or $fin -le $ini) { Mal "No pude leer la base. Mandame esta pantalla."; Write-Host $salida; return }
try { $filas = @((($salida.Substring($ini, $fin - $ini + 1)) | ConvertFrom-Json)[0].results) } catch { Mal "No entendi lo que contesto la base. Mandame esta pantalla."; Write-Host $salida; return }
if ($filas.Count -eq 0) { Mal "No encontre tu Android con avisos en la base."; return }
$token = $filas[0].push_token
Ok ("Tu Android: " + $filas[0].name + " (token ..." + $token.TrimEnd("]").Substring($token.Length - 7) + ")")

$o = [string][char]0x00F3
$pruebas = @(
    @("1", "Ojo Guard", ("LB iPhone lleg" + $o + " a Casa. [1]"), 86400, "igual al aviso real"),
    @("2", "Ojo Guard", "LB iPhone llego a Casa. [2]", 86400, "igual, pero sin acento"),
    @("3", "Aviso de lugar", ("LB iPhone lleg" + $o + " a Casa. [3]"), 86400, "igual, pero con otro titulo"),
    @("4", "Ojo Guard", ("LB iPhone lleg" + $o + " a Casa. [4]"), 600, "igual, pero con vencimiento corto")
)
Write-Host ""
Write-Host "Deja el Android a la vista, con la pantalla apagada o bloqueada. Salen 4 avisos, uno cada 12 segundos." -ForegroundColor Cyan
Start-Sleep -Seconds 5
foreach ($p in $pruebas) {
    $m = [ordered]@{ to = $token; title = $p[1]; body = $p[2]; sound = "default"; priority = "high"; ttl = $p[3]; data = @{} }
    $cuerpo = "[" + ($m | ConvertTo-Json -Compress -Depth 5) + "]"
    try {
        $r = Invoke-RestMethod -Method Post -Uri "https://exp.host/--/api/v2/push/send" -ContentType "application/json; charset=utf-8" -Body ([System.Text.Encoding]::UTF8.GetBytes($cuerpo))
        $t = $r.data[0]
        if ($t.status -eq "ok") { Ok ("Aviso [" + $p[0] + "] enviado (" + $p[4] + ")") } else { Mal ("Aviso [" + $p[0] + "] rechazado: " + $t.message) }
    } catch { Mal ("Aviso [" + $p[0] + "]: no pude hablar con Expo: " + $_.Exception.Message) }
    Start-Sleep -Seconds 12
}
Write-Host ""
Write-Host "Listo. Mira el Android y decime cuales numeros viste: [1] [2] [3] [4]." -ForegroundColor Cyan
