# ver-registro-avisos.ps1 - Muestra los ultimos avisos que mando el servidor (tabla push_log) y le pregunta a Expo si cada uno
# fue entregado al celular. No toca ningun archivo ni la base. Va en la carpeta del PANEL (la que tiene wrangler.toml).
$ErrorActionPreference = "Continue"
function Ok($t)  { Write-Host ("OK    " + $t) -ForegroundColor Green }
function Mal($t) { Write-Host ("MAL   " + $t) -ForegroundColor Red }
function Avi($t) { Write-Host ("AVISO " + $t) -ForegroundColor Yellow }
$raiz = (Get-Location).Path
function Hora($v) {
    # La base guarda la hora en UTC; se muestra la de Buenos Aires (UTC-3).
    try {
        $d = if ($v -is [datetime]) { $v.ToUniversalTime() } else { [datetime]::Parse([string]$v, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AdjustToUniversal) }
        return $d.AddHours(-3).ToString("dd/MM HH:mm:ss")
    } catch { return [string]$v }
}
if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"

$sql = "SELECT id, at, texto, token_fin, http, estado, detalle FROM push_log ORDER BY id DESC LIMIT 5"
$salida = (& npx.cmd wrangler d1 execute ojo-guard-ms --remote --json --command $sql 2>&1 | ForEach-Object { "$_" }) -join "`n"
$ini = $salida.IndexOf("["); $fin = $salida.LastIndexOf("]")
if ($ini -lt 0 -or $fin -le $ini) { Mal "No pude leer la base. Mandame esta pantalla."; Write-Host $salida; return }
try { $filas = @((($salida.Substring($ini, $fin - $ini + 1)) | ConvertFrom-Json)[0].results) } catch { Mal "No entendi lo que contesto la base. Mandame esta pantalla."; Write-Host $salida; return }
if ($filas.Count -eq 0) { Avi "El registro esta vacio: desde que se publico el cambio el servidor no mando ningun aviso de lugar."; return }

Write-Host ""
Write-Host ("Ultimos avisos del servidor (" + $filas.Count + "), del mas nuevo al mas viejo:") -ForegroundColor Cyan
$tickets = @()
foreach ($f in $filas) {
    Write-Host ""
    Write-Host ("  " + (Hora $f.at) + "  |  " + $f.texto + "  |  celular ..." + $f.token_fin)
    if ($f.estado -eq "ok") { Ok ("Expo lo acepto (http " + $f.http + ", ticket " + $f.detalle + ")"); $tickets += ,@((Hora $f.at), $f.detalle) }
    else { Mal ("Expo no lo acepto: " + $f.estado + " | http " + $f.http + " | " + $f.detalle) }
}

if ($tickets.Count -gt 0) {
    Write-Host ""
    Write-Host "Le pregunto a Expo si Google entrego cada aviso al celular..." -ForegroundColor Cyan
    try {
        $cuerpo = (@{ ids = @($tickets | ForEach-Object { $_[1] }) } | ConvertTo-Json -Compress)
        $r = Invoke-RestMethod -Method Post -Uri "https://exp.host/--/api/v2/push/getReceipts" -ContentType "application/json" -Body $cuerpo
        foreach ($t in $tickets) {
            $rec = $r.data.($t[1])
            if (-not $rec) { Avi ($t[0] + ": Expo todavia no tiene el recibo (probar de nuevo en un par de minutos)") }
            elseif ($rec.status -eq "ok") { Ok ($t[0] + ": entregado al celular (recibo ok)") }
            else { Mal ($t[0] + ": NO entregado: " + $rec.message + " | " + ($rec.details | ConvertTo-Json -Compress)) }
        }
    } catch { Mal ("No pude pedir los recibos: " + $_.Exception.Message) }
}
Write-Host ""
