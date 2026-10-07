# aplicar-logo-panel.ps1 - Pone el logo nuevo (ojo dentro del pin) en el encabezado del panel y como icono de la pestania
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Respaldo .bak-logo; si algo falla, se restaura.
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

$archHtml = Join-Path $raiz "src\panel-index.html"
if (-not (Test-Path $archHtml)) { Mal ("No encuentro " + $archHtml); return }
$fh = Leer $archHtml
if ((Contar $fh.texto 'class="brand-logo"') -ne 0) { Avi "El logo nuevo ya estaba puesto. No toco nada."; return }

$A1 = '<a class="brand" href="/"><span class="brand-eye">' + [string][char]0x25CF + '</span><strong>OJO GUARD</strong><span class="ms-mark">MS</span></a>'
$N1 = '<a class="brand" href="/" aria-label="ojo guard MS"><svg class="brand-logo" viewBox="0 40 226 120" width="53" height="28" aria-hidden="true" style="vertical-align:middle;margin-right:8px;flex:none"><defs><linearGradient id="ogLogoGold" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffd978"/><stop offset=".5" stop-color="#e2a93a"/><stop offset="1" stop-color="#9c6a1a"/></linearGradient><radialGradient id="ogLogoIris"><stop offset="0" stop-color="#3a2606"/><stop offset=".35" stop-color="#b9851f"/><stop offset=".75" stop-color="#f2c45a"/><stop offset="1" stop-color="#8a5f14"/></radialGradient></defs><path d="M8,100 C48,71.4 84,48 154,48 A64,52 0 0 1 154,152 C84,152 48,128.6 8,100 Z" fill="none" stroke="url(#ogLogoGold)" stroke-width="8" stroke-linejoin="round"/><path d="M60,100 C90,63 166,63 196,100 C166,137 90,137 60,100 Z" fill="#0b0b0b" stroke="url(#ogLogoGold)" stroke-width="5.5"/><circle cx="128" cy="100" r="29" fill="url(#ogLogoIris)"/><circle cx="128" cy="100" r="11.5" fill="#070707"/><circle cx="122.8" cy="94.2" r="3.2" fill="#fff" fill-opacity=".85"/></svg><strong style="font-weight:300;letter-spacing:.1em;text-transform:none">ojo guard</strong><span class="ms-mark">MS</span></a>'
$A2 = '</title>'
$N2 = Ajustar '</title>
  <link rel="icon" type="image/svg+xml" href="data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgLTEzIDIyNiAyMjYiPjxyZWN0IHg9IjAiIHk9Ii0xMyIgd2lkdGg9IjIyNiIgaGVpZ2h0PSIyMjYiIHJ4PSI1MCIgZmlsbD0iIzBiMGEwOCIvPjxkZWZzPjxsaW5lYXJHcmFkaWVudCBpZD0iZkdvbGQiIHgxPSIwIiB5MT0iMCIgeDI9IjAiIHkyPSIxIj48c3RvcCBvZmZzZXQ9IjAiIHN0b3AtY29sb3I9IiNmZmQ5NzgiLz48c3RvcCBvZmZzZXQ9Ii41IiBzdG9wLWNvbG9yPSIjZTJhOTNhIi8+PHN0b3Agb2Zmc2V0PSIxIiBzdG9wLWNvbG9yPSIjOWM2YTFhIi8+PC9saW5lYXJHcmFkaWVudD48cmFkaWFsR3JhZGllbnQgaWQ9ImZJcmlzIj48c3RvcCBvZmZzZXQ9IjAiIHN0b3AtY29sb3I9IiMzYTI2MDYiLz48c3RvcCBvZmZzZXQ9Ii4zNSIgc3RvcC1jb2xvcj0iI2I5ODUxZiIvPjxzdG9wIG9mZnNldD0iLjc1IiBzdG9wLWNvbG9yPSIjZjJjNDVhIi8+PHN0b3Agb2Zmc2V0PSIxIiBzdG9wLWNvbG9yPSIjOGE1ZjE0Ii8+PC9yYWRpYWxHcmFkaWVudD48L2RlZnM+PHBhdGggZD0iTTgsMTAwIEM0OCw3MS40IDg0LDQ4IDE1NCw0OCBBNjQsNTIgMCAwIDEgMTU0LDE1MiBDODQsMTUyIDQ4LDEyOC42IDgsMTAwIFoiIGZpbGw9Im5vbmUiIHN0cm9rZT0idXJsKCNmR29sZCkiIHN0cm9rZS13aWR0aD0iOCIgc3Ryb2tlLWxpbmVqb2luPSJyb3VuZCIvPjxwYXRoIGQ9Ik02MCwxMDAgQzkwLDYzIDE2Niw2MyAxOTYsMTAwIEMxNjYsMTM3IDkwLDEzNyA2MCwxMDAgWiIgZmlsbD0iIzBiMGIwYiIgc3Ryb2tlPSJ1cmwoI2ZHb2xkKSIgc3Ryb2tlLXdpZHRoPSI1LjUiLz48Y2lyY2xlIGN4PSIxMjgiIGN5PSIxMDAiIHI9IjI5IiBmaWxsPSJ1cmwoI2ZJcmlzKSIvPjxjaXJjbGUgY3g9IjEyOCIgY3k9IjEwMCIgcj0iMTEuNSIgZmlsbD0iIzA3MDcwNyIvPjxjaXJjbGUgY3g9IjEyMi44IiBjeT0iOTQuMiIgcj0iMy4yIiBmaWxsPSIjZmZmIiBmaWxsLW9wYWNpdHk9Ii44NSIvPjwvc3ZnPg==">' $fh.crlf

$ok = $true
foreach ($c in @(
    @("panel-index.html: logo del encabezado", $A1),
    @("panel-index.html: fin del titulo", $A2))) {
    $n = Contar $fh.texto $c[1]
    if ($n -eq 1) { Ok ($c[0] + ": 1") } else { Mal ($c[0] + ": " + $n + " (esperaba 1)"); $ok = $false }
}
if ((Contar $fh.texto 'rel="icon"') -ne 0) { Avi "Ya habia un icono de pestania; lo dejo y agrego el nuevo antes." }
if (-not $ok) { Mal "Alguna ancla no coincide. No toco nada. Mandame esta pantalla."; return }

$bak = $archHtml + ".bak-logo"
if (Test-Path $bak) { Mal ("Ya existe " + $bak + ". No toco nada."); return }
Copy-Item -LiteralPath $archHtml -Destination $bak
Ok "Respaldo creado (.bak-logo)"

$nuevo = $fh.texto.Replace($A1, $N1).Replace($A2, $N2)
[System.IO.File]::WriteAllText($archHtml, $nuevo, (New-Object System.Text.UTF8Encoding($fh.bom)))

$vh = Leer $archHtml
$todoBien = $true
function Chk([string]$que, [bool]$cond) { if ($cond) { Ok $que } else { Mal $que; $script:todoBien = $false } }
$esperado = ($N1.Length - $A1.Length) + ($N2.Length - $A2.Length)
Chk "logo nuevo en el encabezado 1 vez" ((Contar $vh.texto 'class="brand-logo"') -eq 1)
Chk "logo viejo ya no esta" ((Contar $vh.texto $A1) -eq 0)
Chk "icono de pestania agregado 1 vez" ((Contar $vh.texto 'data:image/svg+xml;base64,') -eq 1)
Chk "el titulo sigue 1 vez" ((Contar $vh.texto '</title>') -eq 1)
Chk "boton Cerrar acceso sigue" ((Contar $vh.texto 'id="logout"') -eq 1)
Chk ("largo " + ($vh.texto.Length - $fh.texto.Length) + " (esperado " + $esperado + ")") (($vh.texto.Length - $fh.texto.Length) -eq $esperado)
Chk ("lineas " + (Lineas $fh.texto) + " -> " + (Lineas $vh.texto) + " (+1)") ((Lineas $vh.texto) -eq ((Lineas $fh.texto) + 1))
if (-not $todoBien) {
    Mal "Algo no salio bien. Restauro desde el respaldo."
    Copy-Item -LiteralPath $bak -Destination $archHtml -Force
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "TODO BIEN en el archivo. Falta PUBLICAR: powershell -ExecutionPolicy Bypass -Command ""npx wrangler deploy"""
Write-Host ""
