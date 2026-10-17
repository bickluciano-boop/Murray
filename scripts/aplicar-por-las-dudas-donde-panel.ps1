# aplicar-por-las-dudas-donde-panel.ps1 - Por las dudas: la pagina explica donde esta el boton "No lo encuentro".
# Luciano (17/10/2026), segunda prueba: "no veo que en ningun lado diga No lo encuentro". Es a proposito: lo ve solo el REFERENTE, en su enlace
# personal y despues de aceptar; la persona nunca lo aprieta. Pero la pagina no lo decia. Ahora, debajo de "Tus referentes", un texto lo explica y
# dice como probarlo (abrir el enlace del referente en otro navegador y aceptar). Un solo cambio de texto dentro de src\index.ts, solo en la
# pagina de Por las dudas. Requiere aplicar-por-las-dudas-enlace-panel.ps1.
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Respaldo .bak-plddonde. Al final publica el panel solo.
$ErrorActionPreference = "Continue"
function Ok($t)  { Write-Host ("OK    " + $t) -ForegroundColor Green }
function Mal($t) { Write-Host ("MAL   " + $t) -ForegroundColor Red }
function Avi($t) { Write-Host ("AVISO " + $t) -ForegroundColor Yellow }
$raiz = (Get-Location).Path
function Contar([string]$donde, [string]$que) {
    if ([string]::IsNullOrEmpty($que)) { return 0 }
    $n = 0; $i = 0
    while ($true) { $i = $donde.IndexOf($que, $i, [System.StringComparison]::Ordinal); if ($i -lt 0) { break }; $n = $n + 1; $i = $i + $que.Length }
    return $n
}
function Leer([string]$ruta) {
    $bytes = [System.IO.File]::ReadAllBytes($ruta)
    $bom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    $texto = [System.IO.File]::ReadAllText($ruta, [System.Text.Encoding]::UTF8)
    return @{ texto = $texto; bom = $bom; crlf = $texto.Contains("`r`n") }
}
function Ajustar([string]$t, [bool]$crlf) { $x = ($t -replace "`r`n", "`n"); if ($crlf) { $x = $x -replace "`n", "`r`n" }; return $x }
function Sha([string]$ruta) { return (Get-FileHash -Algorithm SHA256 -LiteralPath $ruta).Hash.ToLower() }

if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
$indice = Join-Path $raiz "src\index.ts"
if (-not (Test-Path $indice)) { Mal "No encuentro src\index.ts en esta carpeta."; return }
$f = Leer $indice
if ((Contar $f.texto 'id="dondeBoton"') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $f.texto 'async function pldApiDuenio') -ne 1) { Mal "Falta aplicar antes aplicar-por-las-dudas-panel.ps1."; return }
if ((Contar $f.texto 'id="invitacion"') -ne 1) { Mal "Falta aplicar antes aplicar-por-las-dudas-enlace-panel.ps1."; return }
$cambios = @(
    ,@('la pagina explica donde esta el boton No lo encuentro', '<small class="suave">Hasta 5. Le llega un mail con su enlace personal y tiene que aceptar.</small></div>', '<small class="suave">Hasta 5. Le llega un mail con su enlace personal y tiene que aceptar.</small>
<p id="dondeBoton" class="suave"><b>\u00bfD\u00f3nde est\u00e1 el bot\u00f3n \u201cNo lo encuentro\u201d?</b> Lo ve solo tu referente, en su enlace personal, despu\u00e9s de aceptar. Vos no ten\u00e9s que apretar nada. Para probarlo, abr\u00ed su enlace en otro navegador (o en una ventana privada) y acept\u00e1.</p></div>')
)
$ok = $true
foreach ($c in $cambios) {
    $cuantos = Contar $f.texto (Ajustar $c[1] $f.crlf)
    if ($cuantos -eq 1) { Ok ($c[0] + ": 1") } else { Mal ($c[0] + ": " + $cuantos + " (esperaba 1)"); $ok = $false }
}
if (-not $ok) { Mal "Alguna ancla no coincide. No toco nada. Mandame esta pantalla."; return }
if (Test-Path ($indice + ".bak-plddonde")) { Mal "Ya existe src\index.ts.bak-plddonde. No toco nada."; return }
Copy-Item -LiteralPath $indice -Destination ($indice + ".bak-plddonde")
Ok "Respaldo creado: src\index.ts.bak-plddonde"
$nuevo = $f.texto
$esperado = $f.texto.Length
foreach ($c in $cambios) {
    $a = Ajustar $c[1] $f.crlf; $r = Ajustar $c[2] $f.crlf
    $nuevo = $nuevo.Replace($a, $r)
    $esperado = $esperado + ($r.Length - $a.Length)
}
[System.IO.File]::WriteAllText($indice, $nuevo, (New-Object System.Text.UTF8Encoding($f.bom)))
$v = Leer $indice
if (($v.texto.Length -ne $esperado) -or ((Contar $v.texto 'id="dondeBoton"') -ne 1)) {
    Mal "Algo no salio bien. Restauro src\index.ts desde el respaldo."
    Copy-Item -LiteralPath ($indice + ".bak-plddonde") -Destination $indice -Force
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Ok ("src\index.ts: largo " + $v.texto.Length + " (esperado " + $esperado + ")")
Write-Host ""
Ok "Archivo listo. Ahora publico el panel..."
& npx.cmd wrangler deploy
if ($LASTEXITCODE -ne 0) { Mal "No se pudo publicar el panel. Mandame esta pantalla."; return }
Write-Host ""
Ok "LISTO: la pagina de Por las dudas ahora explica donde esta el boton No lo encuentro."
Write-Host ""
