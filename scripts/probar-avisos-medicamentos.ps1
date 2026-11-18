# probar-avisos-medicamentos.ps1 - Diagnostico (solo manda 6 avisos de prueba a los telefonos de Luciano; no cambia nada en el servidor ni en la base).
# Luciano (18/11/2026): el aviso de medicamentos de la HORA no aparecio en ninguno de los dos telefonos aunque Expo lo acepto y Google/Apple dieron recibo "ok"; el recordatorio de 16 minutos despues si.
# Manda 6 variantes a cada telefono para ver cual se muestra:  A = igual al aviso real | B = sin "time-sensitive" | C = sin datos | D = comun (sin canal, sin datos, sin nivel) |
# E = como el SOS (canal ojo-sos, time-sensitive, vida corta de 10 min) | F = canal de alertas (ojo-alertas, maxima importancia, time-sensitive, vida corta).
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Lee los tokens de la base y NUNCA los imprime.
$ErrorActionPreference = "Continue"
function Ok($t)  { Write-Host ("OK    " + $t) -ForegroundColor Green }
function Mal($t) { Write-Host ("MAL   " + $t) -ForegroundColor Red }
$raiz = (Get-Location).Path
if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml)."; return }
Ok "Carpeta correcta"
$crudo = (& npx.cmd wrangler d1 execute ojo-guard-ms --remote --json --command "SELECT name, platform, push_token FROM devices WHERE approval_status='approved' AND push_token IS NOT NULL AND name IN ('Android Luciano (Xiaomi)','iPhone Luciano')" 2>$null | Out-String)
$inicio = $crudo.IndexOf("[")
if ($inicio -lt 0) { Mal "No pude leer los telefonos de la base."; return }
$telefonos = @()
try { $telefonos = @(($crudo.Substring($inicio) | ConvertFrom-Json)[0].results) } catch { Mal "No pude leer la respuesta de la base."; return }
if ($telefonos.Count -eq 0) { Mal "No encontre los telefonos."; return }
foreach ($t in $telefonos) { Ok ("Telefono encontrado: " + $t.name + " (" + $t.platform + ")") }
Write-Host ""
Write-Host "BLOQUEA los dos telefonos ahora y no los toques. En 15 segundos empiezo: 6 avisos a cada uno, uno cada 8 segundos." -ForegroundColor Cyan
Start-Sleep -Seconds 15
$datosReales = @{ type = "remedio"; dosisId = "prueba"; dosisIds = @("prueba"); day = "2026-11-18"; hhmm = "12:45" }
$variantes = @(
    @{ letra = "A"; texto = "Igual al aviso real"; canal = "ojo-medicamentos-2"; nivel = "time-sensitive"; datos = $datosReales },
    @{ letra = "B"; texto = "Sin time-sensitive"; canal = "ojo-medicamentos-2"; nivel = $null; datos = $datosReales },
    @{ letra = "C"; texto = "Sin datos"; canal = "ojo-medicamentos-2"; nivel = "time-sensitive"; datos = $null },
    @{ letra = "D"; texto = "Comun"; canal = $null; nivel = $null; datos = $null },
    @{ letra = "E"; texto = "Como el SOS (canal ojo-sos)"; canal = "ojo-sos"; nivel = "time-sensitive"; datos = $datosReales; ttl = 600 },
    @{ letra = "F"; texto = "Canal de alertas (ojo-alertas)"; canal = "ojo-alertas"; nivel = "time-sensitive"; datos = $datosReales; ttl = 600 }
)
foreach ($v in $variantes) {
    foreach ($t in $telefonos) {
        $m = [ordered]@{ to = $t.push_token; title = ("PRUEBA " + $v.letra); body = ($v.texto + ". No lo toques."); sound = "default"; priority = "high" }
        if ($v.canal) { $m["channelId"] = $v.canal }
        if ($v.nivel) { $m["interruptionLevel"] = $v.nivel }
        if ($v.ttl) { $m["ttl"] = $v.ttl }
        $m["data"] = $(if ($v.datos) { $v.datos } else { @{} })
        $cuerpo = "[" + ($m | ConvertTo-Json -Depth 6 -Compress) + "]"
        try {
            $r = Invoke-RestMethod -Method Post -Uri "https://exp.host/--/api/v2/push/send" -ContentType "application/json" -Body $cuerpo
            $estado = if ($r.data -is [array]) { $r.data[0].status } else { $r.data.status }
            if ($estado -eq "ok") { Ok ("Prueba " + $v.letra + " enviada a " + $t.name) } else { Mal ("Prueba " + $v.letra + " a " + $t.name + ": " + $estado) }
        } catch { Mal ("Prueba " + $v.letra + " a " + $t.name + ": " + $_.Exception.Message) }
    }
    Start-Sleep -Seconds 8
}
Write-Host ""
Ok "Listo. Mira los dos telefonos: anota cuales de A, B, C, D, E y F aparecieron (con el telefono bloqueado y despues de sacarlo del bloqueo) y contame."
