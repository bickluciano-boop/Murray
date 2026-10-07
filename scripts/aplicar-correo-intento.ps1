# aplicar-correo-intento.ps1 - Correo de "intento detectado" prolijo: acento, fechas en hora de Buenos Aires, dispositivo arriba, mismo estilo oscuro
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Respaldo index.ts.bak-intento; si algo falla, se restaura.
$ErrorActionPreference = "Continue"
function Ok($t)  { Write-Host ("OK    " + $t) -ForegroundColor Green }
function Mal($t) { Write-Host ("MAL   " + $t) -ForegroundColor Red }
function Avi($t) { Write-Host ("AVISO " + $t) -ForegroundColor Yellow }
$raiz = (Get-Location).Path
if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
function Contar([string]$donde, [string]$que) {
    $n = 0
    $i = 0
    while ($true) {
        $i = $donde.IndexOf($que, $i, [System.StringComparison]::Ordinal)
        if ($i -lt 0) { break }
        $n = $n + 1
        $i = $i + $que.Length
    }
    return $n
}
function Leer([string]$ruta) {
    $bytes = [System.IO.File]::ReadAllBytes($ruta)
    $bom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    $texto = [System.IO.File]::ReadAllText($ruta, [System.Text.Encoding]::UTF8)
    return @{ texto = $texto; bom = $bom; crlf = $texto.Contains("`r`n") }
}
function Ajustar([string]$t, [bool]$crlf) {
    $x = ($t -replace "`r`n", "`n")
    if ($crlf) { $x = $x -replace "`n", "`r`n" }
    return $x
}
function Lineas([string]$t) { return @($t -split "`r`n|`n").Count }

$archIdx = Join-Path $raiz "src\index.ts"
if (-not (Test-Path $archIdx)) { Mal ("No encuentro " + $archIdx); return }
$fi = Leer $archIdx
if ((Contar $fi.texto 'function fechaCorreo') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
$A1 = '  if (prefs.notifyEmail && !deliveredAt) {'
$B1 = Ajustar '  if (prefs.notifyEmail && !deliveredAt) {
    const alertDeviceName = (await env.DB.prepare("SELECT name FROM devices WHERE id=?").bind(deviceId).first<{ name: string | null }>())?.name || "Tel\u00e9fono principal";' $fi.crlf
$A2 = '        subject: "Alerta de seguridad de Ojo Guard",'
$B2 = Ajustar '        subject: `Intento de acceso detectado \u00b7 ${alertDeviceName}`,' $fi.crlf
$A3 = '<h1>Ojo Guard detecto un intento</h1>'
$B3 = Ajustar '<div style="font-family:Arial,sans-serif;max-width:620px;margin:auto;background:#0c0d0f;color:#f6f6f2;padding:28px;border-radius:20px"><p style="color:#f4c64e;font-size:12px;font-weight:800;letter-spacing:.16em">OJO GUARD &#183; ALERTA DE SEGURIDAD</p><h1 style="font-size:26px;margin:10px 0 18px">Se detect&#243; un intento de acceso</h1>' $fi.crlf
$A4 = '<p><strong>Fecha:</strong> ${escapeHtml(body.occurredAt)}</p>'
$B4 = Ajustar '<p style="color:#d2d2ce"><strong style="color:#fff">Dispositivo:</strong> ${escapeHtml(alertDeviceName)}</p><p style="color:#d2d2ce"><strong style="color:#fff">Fecha y hora:</strong> ${escapeHtml(fechaCorreo(body.occurredAt ?? now()))} &#183; Buenos Aires</p>' $fi.crlf
$A5 = '${escapeHtml(emailLocation.capturedAt)}'
$B5 = Ajustar '${escapeHtml(fechaCorreo(emailLocation.capturedAt))}' $fi.crlf
$A6 = '<p><a href="${emailLocation.mapUrl}">'
$B6 = Ajustar '<p style="margin:20px 0"><a style="display:inline-block;background:#d9b24c;color:#111;padding:12px 16px;border-radius:10px;text-decoration:none;font-weight:700" href="${emailLocation.mapUrl}">' $fi.crlf
$A7 = '<p>Identificador del intento: ${escapeHtml(body.attemptId)}</p>'
$B7 = Ajustar '<p style="color:#d2d2ce;line-height:1.55">Las fotos tambi&#233;n quedan guardadas en el <a style="color:#d9b24c" href="${env.PANEL_URL || DEFAULT_PANEL_URL}">historial de Ojo Guard MS</a>.</p><p style="color:#8d8d88;font-size:12px;margin-top:20px">Identificador del intento: ${escapeHtml(body.attemptId)}</p></div>' $fi.crlf
$A8 = 'function textoCorreo(valor: unknown) {'
$B8 = Ajustar '// Fechas de los correos en hora de Buenos Aires y en palabras (no ISO/UTC).
function fechaCorreo(valor: unknown) { const fecha = new Date(String(valor ?? "")); if (Number.isNaN(fecha.getTime())) return String(valor ?? ""); return new Intl.DateTimeFormat("es-AR", { timeZone: "America/Argentina/Buenos_Aires", dateStyle: "long", timeStyle: "medium" }).format(fecha); }
function textoCorreo(valor: unknown) {' $fi.crlf
$pares = @(@("nombre del equipo", $A1, $B1), @("asunto", $A2, $B2), @("titulo", $A3, $B3), @("dispositivo y fecha", $A4, $B4), @("fecha de la ubicacion", $A5, $B5), @("boton del mapa", $A6, $B6), @("cierre", $A7, $B7), @("formato de fechas", $A8, $B8))
$ok = $true
foreach ($p in $pares) {
    $cuantos = Contar $fi.texto $p[1]
    if ($cuantos -eq 1) { Ok ("index.ts: " + $p[0] + ": 1") } else { Mal ("index.ts: " + $p[0] + ": " + $cuantos + " (esperaba 1)"); $ok = $false }
}
if (-not $ok) { Mal "Alguna ancla no coincide. No toco nada. Mandame esta pantalla."; return }
$bak = $archIdx + ".bak-intento"
if (Test-Path $bak) { Mal ("Ya existe " + $bak + ". No toco nada."); return }
Copy-Item -LiteralPath $archIdx -Destination $bak
Ok "Respaldo creado (index.ts.bak-intento)"
$nuevo = $fi.texto
$esperado = 0
foreach ($p in $pares) { $nuevo = $nuevo.Replace($p[1], $p[2]); $esperado = $esperado + ($p[2].Length - $p[1].Length) }
[System.IO.File]::WriteAllText($archIdx, $nuevo, (New-Object System.Text.UTF8Encoding($fi.bom)))

$vi = Leer $archIdx
$todoBien = $true
function Chk([string]$que, [bool]$cond) { if ($cond) { Ok $que } else { Mal $que; $script:todoBien = $false } }
foreach ($p in $pares) { Chk ("index.ts: " + $p[0] + " aplicado") ((Contar $vi.texto $p[2]) -eq 1) }
Chk "index.ts: texto viejo reemplazado" (((Contar $vi.texto 'Ojo Guard detecto un intento') -eq 0) -and ((Contar $vi.texto '"Alerta de seguridad de Ojo Guard"') -eq 0))
Chk "index.ts: logo de correos y espanol siguen" (((Contar $vi.texto 'function fetchCorreo') -eq 1) -and ((Contar $vi.texto '"Content-Language": "es"') -eq 1))
Chk ("index.ts: largo +" + ($vi.texto.Length - $fi.texto.Length) + " (esperado +" + $esperado + ")") (($vi.texto.Length - $fi.texto.Length) -eq $esperado)
Chk ("index.ts: lineas +" + ((Lineas $vi.texto) - (Lineas $fi.texto)) + " (esperado +3)") (((Lineas $vi.texto) - (Lineas $fi.texto)) -eq 3)
if (-not $todoBien) {
    Mal "Algo no salio bien. Restauro desde el respaldo."
    Copy-Item -LiteralPath $bak -Destination $archIdx -Force
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "TODO BIEN en el archivo. Falta PUBLICAR: powershell -ExecutionPolicy Bypass -Command ""npx wrangler deploy"""
Write-Host ""
