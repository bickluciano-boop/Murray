# aplicar-mapa-sin-cache.ps1 - El panel pide siempre la ultima version del mapa (el iPhone se quedaba con una copia vieja)
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Cambia 2 lineas de src\panel-index.html. Respaldo: panel-index.html.bak-sincache.
$ErrorActionPreference = "Continue"
function Ok($t)  { Write-Host ("OK    " + $t) -ForegroundColor Green }
function Mal($t) { Write-Host ("MAL   " + $t) -ForegroundColor Red }
function Avi($t) { Write-Host ("AVISO " + $t) -ForegroundColor Yellow }
$raiz = (Get-Location).Path
if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
function Contar([string]$donde, [string]$que) {
    if ([string]::IsNullOrEmpty($que)) { return 0 }
    $n = 0; $i = 0
    while ($true) { $i = $donde.IndexOf($que, $i, [System.StringComparison]::Ordinal); if ($i -lt 0) { break }; $n = $n + 1; $i = $i + $que.Length }
    return $n
}
function Ajustar([string]$t, [bool]$crlf) { $x = ($t -replace "`r`n", "`n"); if ($crlf) { $x = $x -replace "`n", "`r`n" }; return $x }
$arch = Join-Path $raiz "src\panel-index.html"
if (-not (Test-Path $arch)) { Mal ("No encuentro " + $arch); return }
$bytes = [System.IO.File]::ReadAllBytes($arch)
$bom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
$texto = [System.IO.File]::ReadAllText($arch, [System.Text.Encoding]::UTF8)
$crlf = $texto.Contains("`r`n")
if ((Contar $texto 'mapa-v1.js?t=') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
$A1 = Ajustar '
    <link rel="stylesheet" href="/mapa-v1.css" />' $crlf
$B1 = ''
$A2 = '    <script type="module" src="/mapa-v1.js?v=1"></script>'
$B2 = '    <script type="module">/* Mapa: siempre la ultima version, sin copias viejas del navegador */ const v = Date.now(); const css = document.createElement("link"); css.rel = "stylesheet"; css.href = "/mapa-v1.css?t=" + v; document.head.appendChild(css); import("/mapa-v1.js?t=" + v);</script>'
$c1 = Contar $texto $A1; $c2 = Contar $texto $A2
if ($c1 -ne 1 -or $c2 -ne 1) { Mal ("panel-index.html: estilos del mapa " + $c1 + ", script del mapa " + $c2 + " (esperaba 1 y 1). No toco nada. Mandame esta pantalla."); return }
Ok "panel-index.html: lineas del mapa encontradas"
$bak = $arch + ".bak-sincache"
if (Test-Path $bak) { Mal ("Ya existe " + $bak + ". No toco nada."); return }
Copy-Item -LiteralPath $arch -Destination $bak
Ok "Respaldo creado (panel-index.html.bak-sincache)"
$nuevo = $texto.Replace($A1, $B1).Replace($A2, $B2)
[System.IO.File]::WriteAllText($arch, $nuevo, (New-Object System.Text.UTF8Encoding($bom)))
$v = [System.IO.File]::ReadAllText($arch, [System.Text.Encoding]::UTF8)
$esperado = $texto.Length - $A1.Length + ($B2.Length - $A2.Length)
if (((Contar $v $B2) -eq 1) -and ((Contar $v 'href="/mapa-v1.css"') -eq 0) -and ((Contar $v '/app-v9.js?v=7') -eq 1) -and ($v.Length -eq $esperado)) {
    Ok ("panel-index.html: aplicado (largo " + $v.Length + ", esperado " + $esperado + ")")
    Write-Host ""
    Ok "TODO BIEN en los archivos. Falta PUBLICAR: powershell -ExecutionPolicy Bypass -Command ""npx wrangler deploy"""
    Write-Host ""
} else {
    Copy-Item -LiteralPath $bak -Destination $arch -Force
    Mal "Algo no salio bien. Restaure el archivo. Mandame esta pantalla."
}
