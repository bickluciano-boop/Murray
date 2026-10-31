# aplicar-mapa-otro-dia-compacto-panel.ps1 - Ojo Guard MS: achica el selector del mapa "Otro dia" (ahora "Un dia") para que no lo tape la columna de botones de la derecha.
# Motivo (31/10/2026, capturas de Luciano en Android e iPhone): el calendario y el boton quedaban debajo de los botones de la derecha y el resumen se cortaba. Cambia solo src\panel-mapa.txt (el estilo y el nombre del boton) y src\panel-index.html (v=6). Respaldo .bak-otrodia2. Va en la carpeta del PANEL. Sin build.
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
foreach ($f in @("src\panel-mapa.txt", "src\panel-index.html")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\panel-mapa.txt")).texto 'max-width:calc(100% - 96px)') -ne 0) { Avi "Esto ya estaba aplicado (o ya aplicaste la version anterior del selector chico: avisame y lo ajusto). No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\panel-index.html")).texto '/mapa-v1.js?v=5') -ne 1) { Mal "El mapa no esta en v=5 (falta aplicar primero aplicar-mapa-otro-dia-panel.ps1). No toco nada."; return }
$cambios = @(
    @('src\panel-mapa.txt', 'mapa: selector de dia mas chico', '<style id="ogm-dia-css">#og-mapa .ogm-dia{position:absolute;z-index:3;top:72px;left:18px;display:flex;align-items:center;gap:4px;padding:5px;background:var(--ogm-panel);border:1px solid var(--ogm-linea);border-radius:14px;box-shadow:var(--ogm-sombra)}#og-mapa .ogm-dia.hidden{display:none}#og-mapa .ogm-dia button{width:38px;height:38px;border-radius:10px;font-size:1.3rem;color:var(--ogm-oro-vivo)}#og-mapa .ogm-dia input{height:38px;padding:0 8px;border-radius:10px;border:1px solid var(--ogm-linea);background:transparent;color:var(--ogm-texto);font:inherit;font-size:.9rem;color-scheme:dark light}#og-mapa .ogm-dia-txt{font-size:.78rem;color:var(--ogm-suave);padding:0 6px;white-space:nowrap}@media (max-width:899px){#og-mapa .ogm-dia{top:calc(max(12px, env(safe-area-inset-top)) + 56px);left:12px}#og-mapa .ogm-seg button{padding:8px 9px;font-size:.8rem}}</style>', '<style id="ogm-dia-css">#og-mapa .ogm-dia{position:absolute;z-index:3;top:72px;left:18px;display:flex;flex-wrap:wrap;align-items:center;gap:2px 4px;padding:4px;background:var(--ogm-panel);border:1px solid var(--ogm-linea);border-radius:14px;box-shadow:var(--ogm-sombra);max-width:calc(100% - 96px);box-sizing:border-box}#og-mapa .ogm-dia.hidden{display:none}#og-mapa .ogm-dia button{flex:none;width:34px;height:34px;border-radius:10px;font-size:1.2rem;color:var(--ogm-oro-vivo)}#og-mapa .ogm-dia input{flex:none;width:132px;min-width:0;height:34px;padding:0 6px;border-radius:10px;border:1px solid var(--ogm-linea);background:transparent;color:var(--ogm-texto);font:inherit;font-size:.82rem;color-scheme:dark light}#og-mapa .ogm-dia-txt{flex-basis:100%;font-size:.76rem;color:var(--ogm-suave);padding:0 6px 3px}#og-mapa .ogm-dia-txt:empty{display:none}@media (max-width:899px){#og-mapa .ogm-dia{top:calc(max(12px, env(safe-area-inset-top)) + 56px);left:12px;max-width:calc(100% - 112px)}#og-mapa .ogm-seg{max-width:calc(100% - 80px)}#og-mapa .ogm-seg button{padding:8px 7px;font-size:.78rem;gap:5px}}</style>'),
    @('src\panel-mapa.txt', 'mapa: boton Un dia (mas corto)', '<button type="button" data-rango="dia">Otro día</button>', '<button type="button" data-rango="dia">Un día</button>'),
    @('src\panel-index.html', 'recargar el mapa nuevo (v=6)', '<script type="module" src="/mapa-v1.js?v=5"></script>', '<script type="module" src="/mapa-v1.js?v=6"></script>')
)
$descargas = @()

# --- Revisar que todas las anclas esten exactamente una vez, en todos los archivos ---
$archivos = @{}
foreach ($c in $cambios) {
    $ruta = Join-Path $raiz $c[0]
    if (-not (Test-Path $ruta)) { Mal ("No encuentro " + $c[0]); return }
    if (-not $archivos.ContainsKey($c[0])) { $archivos[$c[0]] = Leer $ruta }
}
$ok = $true
foreach ($c in $cambios) {
    $f = $archivos[$c[0]]
    $ancla = Ajustar $c[2] $f.crlf
    $cuantos = Contar $f.texto $ancla
    if ($cuantos -eq 1) { Ok ($c[0] + ": " + $c[1] + ": 1") } else { Mal ($c[0] + ": " + $c[1] + ": " + $cuantos + " (esperaba 1)"); $ok = $false }
}
if (-not $ok) { Mal "Alguna ancla no coincide. No toco nada. Mandame esta pantalla."; return }

# --- Descargar archivos nuevos y verificar que llegaron completos ---
foreach ($d in $descargas) {
    $tmp = (Join-Path $raiz $d[1]) + ".descarga"
    try { Invoke-WebRequest -UseBasicParsing $d[0] -OutFile $tmp } catch { }
    if (-not (Test-Path $tmp) -or (Sha $tmp) -ne $d[2]) {
        foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }
        Mal ("No se pudo descargar bien " + $d[1] + ". No toque nada."); return
    }
    Ok ("Descargado y verificado: " + $d[1])
}

# --- Respaldos ---
$tocados = @($archivos.Keys) + @($descargas | ForEach-Object { $_[1] })
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path ($ruta + ".bak-otrodia2")) { Mal ("Ya existe " + $t + ".bak-otrodia2. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-otrodia2"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-otrodia2): " + ($respaldados -join ", "))

# --- Aplicar ---
$esperado = @{}
foreach ($k in $archivos.Keys) { $esperado[$k] = $archivos[$k].texto.Length }
$nuevos = @{}
foreach ($k in $archivos.Keys) { $nuevos[$k] = $archivos[$k].texto }
foreach ($c in $cambios) {
    $f = $archivos[$c[0]]
    $ancla = Ajustar $c[2] $f.crlf; $reemplazo = Ajustar $c[3] $f.crlf
    $nuevos[$c[0]] = $nuevos[$c[0]].Replace($ancla, $reemplazo)
    $esperado[$c[0]] = $esperado[$c[0]] + ($reemplazo.Length - $ancla.Length)
}
foreach ($k in $archivos.Keys) { [System.IO.File]::WriteAllText((Join-Path $raiz $k), $nuevos[$k], (New-Object System.Text.UTF8Encoding($archivos[$k].bom))) }
foreach ($d in $descargas) { Move-Item -LiteralPath ((Join-Path $raiz $d[1]) + ".descarga") -Destination (Join-Path $raiz $d[1]) -Force }

# --- Verificar ---
$todoBien = $true
function Chk([string]$que, [bool]$cond) { if ($cond) { Ok $que } else { Mal $que; $script:todoBien = $false } }
foreach ($c in $cambios) {
    $v = (Leer (Join-Path $raiz $c[0]))
    Chk ($c[0] + ": " + $c[1] + " aplicado") ((Contar $v.texto (Ajustar $c[3] $v.crlf)) -eq 1)
}
foreach ($k in $archivos.Keys) {
    $largo = (Leer (Join-Path $raiz $k)).texto.Length
    Chk ($k + ": largo " + $largo + " (esperado " + $esperado[$k] + ")") ($largo -eq $esperado[$k])
}
foreach ($d in $descargas) { Chk ($d[1] + ": verificado") ((Sha (Join-Path $raiz $d[1])) -eq $d[2]) }

if (-not $todoBien) {
    Mal "Algo no salio bien. Restauro todo desde los respaldos."
    foreach ($t in $tocados) {
        $ruta = Join-Path $raiz $t
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-otrodia2") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "Archivos listos. Ahora publico el panel..."
& npx.cmd wrangler deploy
if ($LASTEXITCODE -ne 0) { Mal "No se pudo publicar el panel. Mandame esta pantalla."; return }
Write-Host ""
Ok "LISTO: el selector del mapa es mas chico. Cerra y abri la app (o recarga la pagina del mapa)."
Write-Host ""
