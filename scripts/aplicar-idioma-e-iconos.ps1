# aplicar-idioma-e-iconos.ps1 - (1) Los correos se marcan como espanol (Gmail deja de ofrecer traducir)
#                                (2) Las tarjetas de los equipos muestran el ojo nuevo en lugar de "OG"
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Respaldos .bak-idioma; si algo falla, se restaura todo.
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
$archHtml = Join-Path $raiz "src\panel-index.html"
foreach ($a in @($archIdx, $archHtml)) { if (-not (Test-Path $a)) { Mal ("No encuentro " + $a); return } }
$fi = Leer $archIdx
$fh = Leer $archHtml
if (((Contar $fi.texto '"Content-Language": "es"') -ne 0) -or ((Contar $fh.texto 'device-icon-ojo') -ne 0)) { Avi "Esto ya estaba aplicado. No toco nada."; return }

$A1 = 'init = { ...init, body: JSON.stringify({ ...datos, html: conMarcaCorreo(datos.html, datos.subject) }) };'
$N1 = 'init = { ...init, body: JSON.stringify({ ...datos, headers: { "Content-Language": "es", ...(datos.headers || {}) }, html: `<div lang="es" dir="ltr">${conMarcaCorreo(datos.html, datos.subject)}</div>` }) };'
$A2 = '<div class="device-icon">OG</div>'
$N2 = '<div class="device-icon device-icon-ojo"><svg viewBox="0 40 226 120" aria-hidden="true"><path d="M8,100 C48,71.4 84,48 154,48 A64,52 0 0 1 154,152 C84,152 48,128.6 8,100 Z" fill="none" stroke="#e2a93a" stroke-width="10" stroke-linejoin="round"/><path d="M60,100 C90,63 166,63 196,100 C166,137 90,137 60,100 Z" fill="#050505" stroke="#e2a93a" stroke-width="7"/><circle cx="128" cy="100" r="29" fill="#d9a441"/><circle cx="128" cy="100" r="29" fill="none" stroke="#7a5212" stroke-width="3"/><circle cx="128" cy="100" r="12" fill="#070707"/><circle cx="122.6" cy="94" r="3.6" fill="#fff" fill-opacity=".85"/></svg></div>'
$A3 = '</head>'
$N3 = Ajustar ('<style id="ojo-equipos">.device-icon.device-icon-ojo{background:#0c0d0f;border:1px solid #3a2f16;padding:8px;box-sizing:border-box}.device-icon-ojo svg{width:100%;height:auto;display:block}</style>' + "`n  " + $A3) $fh.crlf
$ok = $true
foreach ($c in @(@("index.ts: armado del correo", $fi.texto, $A1), @("panel-index.html: icono OG de los equipos", $fh.texto, $A2), @("panel-index.html: fin del head", $fh.texto, $A3))) {
    $n = Contar $c[1] $c[2]
    if ($n -eq 1) { Ok ($c[0] + ": 1") } else { Mal ($c[0] + ": " + $n + " (esperaba 1)"); $ok = $false }
}
if (-not $ok) { Mal "Alguna ancla no coincide. No toco nada. Mandame esta pantalla."; return }

foreach ($a in @($archIdx, $archHtml)) { if (Test-Path ($a + ".bak-idioma")) { Mal ("Ya existe " + $a + ".bak-idioma. No toco nada."); return } }
$resp = @()
foreach ($a in @($archIdx, $archHtml)) {
    Copy-Item -LiteralPath $a -Destination ($a + ".bak-idioma")
    $resp += @{ origen = $a; copia = ($a + ".bak-idioma") }
}
Ok "Respaldos creados (.bak-idioma)"
[System.IO.File]::WriteAllText($archIdx, $fi.texto.Replace($A1, $N1), (New-Object System.Text.UTF8Encoding($fi.bom)))
[System.IO.File]::WriteAllText($archHtml, $fh.texto.Replace($A2, $N2).Replace($A3, $N3), (New-Object System.Text.UTF8Encoding($fh.bom)))

$vi = Leer $archIdx
$vh = Leer $archHtml
$todoBien = $true
function Chk([string]$que, [bool]$cond) { if ($cond) { Ok $que } else { Mal $que; $script:todoBien = $false } }
Chk "index.ts: correos marcados en espanol" (((Contar $vi.texto $N1) -eq 1) -and ((Contar $vi.texto $A1) -eq 0))
Chk "index.ts: logo de correos sigue" (((Contar $vi.texto 'function fetchCorreo') -eq 1) -and ((Contar $vi.texto 'function conMarcaCorreo') -eq 1))
Chk ("index.ts: largo +" + ($vi.texto.Length - $fi.texto.Length) + " (esperado +" + ($N1.Length - $A1.Length) + ")") (($vi.texto.Length - $fi.texto.Length) -eq ($N1.Length - $A1.Length))
Chk ("index.ts: lineas iguales (" + (Lineas $vi.texto) + ")") ((Lineas $vi.texto) -eq (Lineas $fi.texto))
Chk "panel: ojo en las tarjetas de equipos" (((Contar $vh.texto 'device-icon device-icon-ojo') -eq 1) -and ((Contar $vh.texto $A2) -eq 0))
Chk "panel: icono de pulseras sigue" ((Contar $vh.texto 'device-icon watch-icon') -eq 1)
Chk "panel: estilos nuevos 1 vez" ((Contar $vh.texto 'id="ojo-equipos"') -eq 1)
Chk "panel: head cierra 1 vez" ((Contar $vh.texto '</head>') -eq 1)
$espH = ($N2.Length - $A2.Length) + ($N3.Length - $A3.Length)
Chk ("panel: largo +" + ($vh.texto.Length - $fh.texto.Length) + " (esperado +" + $espH + ")") (($vh.texto.Length - $fh.texto.Length) -eq $espH)
Chk ("panel: lineas " + (Lineas $fh.texto) + " -> " + (Lineas $vh.texto) + " (+1)") ((Lineas $vh.texto) -eq ((Lineas $fh.texto) + 1))
if (-not $todoBien) {
    Mal "Algo no salio bien. Restauro desde los respaldos."
    foreach ($r in $resp) { Copy-Item -LiteralPath $r.copia -Destination $r.origen -Force }
    Mal "Restaurados. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "TODO BIEN en los archivos. Falta PUBLICAR: powershell -ExecutionPolicy Bypass -Command ""npx wrangler deploy"""
Write-Host ""
