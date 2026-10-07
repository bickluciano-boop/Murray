# aplicar-correo-celular.ps1 - En el celular, el titulo del correo pasa debajo del logo en vez de partirse en 3 renglones
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Respaldo index.ts.bak-celular; si algo falla, se restaura.
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
function Lineas([string]$t) { return @($t -split "`r`n|`n").Count }

$archIdx = Join-Path $raiz "src\index.ts"
if (-not (Test-Path $archIdx)) { Mal ("No encuentro " + $archIdx); return }
$fi = Leer $archIdx
if ((Contar $fi.texto 'class="og-res"') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
$A1 = '<td align="right" style="vertical-align:middle;padding-left:12px;font-family:Arial,sans-serif">'
$N1 = '<td class="og-res" align="right" style="vertical-align:middle;padding-left:12px;font-family:Arial,sans-serif">'
$A2 = 'font-size:15px;font-weight:700;line-height:1.3'
$N2 = 'font-size:14px;font-weight:700;line-height:1.3'
$A3 = '<td style="vertical-align:middle;width:180px"><img src="${logo}" width="170" height="29"'
$N3 = '<td class="og-logo" style="vertical-align:middle;width:150px"><img src="${logo}" width="140" height="24"'
$A4 = 'return `<div data-og-marca="1"'
$N4 = 'return `<style>@media only screen and (max-width:480px){.og-res,.og-logo{display:block!important;width:auto!important;text-align:left!important}.og-res{padding:12px 0 0!important}}</style><div data-og-marca="1"'
$pares = @(@("titulo al lado del logo", $A1, $N1), @("tamanio del titulo", $A2, $N2), @("tamanio del logo", $A3, $N3), @("ajuste para celular", $A4, $N4))
$ok = $true
foreach ($p in $pares) {
    $n = Contar $fi.texto $p[1]
    if ($n -eq 1) { Ok ("index.ts: " + $p[0] + ": 1") } else { Mal ("index.ts: " + $p[0] + ": " + $n + " (esperaba 1)"); $ok = $false }
}
if (-not $ok) { Mal "Alguna ancla no coincide. No toco nada. Mandame esta pantalla."; return }
$bak = $archIdx + ".bak-celular"
if (Test-Path $bak) { Mal ("Ya existe " + $bak + ". No toco nada."); return }
Copy-Item -LiteralPath $archIdx -Destination $bak
Ok "Respaldo creado (index.ts.bak-celular)"
$nuevo = $fi.texto
$esperado = 0
foreach ($p in $pares) { $nuevo = $nuevo.Replace($p[1], $p[2]); $esperado = $esperado + ($p[2].Length - $p[1].Length) }
[System.IO.File]::WriteAllText($archIdx, $nuevo, (New-Object System.Text.UTF8Encoding($fi.bom)))

$vi = Leer $archIdx
$todoBien = $true
function Chk([string]$que, [bool]$cond) { if ($cond) { Ok $que } else { Mal $que; $script:todoBien = $false } }
foreach ($p in $pares) { Chk ("index.ts: " + $p[0] + " aplicado") (((Contar $vi.texto $p[2]) -eq 1) -and ((Contar $vi.texto $p[1]) -eq 0)) }
Chk "index.ts: logo de correos y espanol siguen" (((Contar $vi.texto 'function fetchCorreo') -eq 1) -and ((Contar $vi.texto '"Content-Language": "es"') -eq 1))
Chk ("index.ts: largo +" + ($vi.texto.Length - $fi.texto.Length) + " (esperado +" + $esperado + ")") (($vi.texto.Length - $fi.texto.Length) -eq $esperado)
Chk ("index.ts: lineas iguales (" + (Lineas $vi.texto) + ")") ((Lineas $vi.texto) -eq (Lineas $fi.texto))
if (-not $todoBien) {
    Mal "Algo no salio bien. Restauro desde el respaldo."
    Copy-Item -LiteralPath $bak -Destination $archIdx -Force
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "TODO BIEN en el archivo. Falta PUBLICAR: powershell -ExecutionPolicy Bypass -Command ""npx wrangler deploy"""
Write-Host ""
