# aplicar-correos-pie-panel.ps1 - Ojo Guard MS: arregla dos detalles del mail nuevo (para quien ya aplico aplicar-correos-marca-panel.ps1 version fd9ba5d).
#  - El titulo de la franja azul pasa debajo del logo (en el celular quedaba apretado).
#  - El pie de todos los mails muestra "Tu panel de Ojo Guard: ms.ojoguard.app" (con link), para que quede en la memoria y no se pierda.
# Cambia SOLO src\index.ts (respaldo index.ts.bak-correospie). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
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
if (-not (Test-Path (Join-Path $raiz "src\index.ts"))) { Mal "No encuentro src\index.ts en esta carpeta."; return }
$txt = (Leer (Join-Path $raiz "src\index.ts")).texto
if ((Contar $txt 'Tu panel de Ojo Guard:') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $txt 'function conMarcaCorreoNuevo') -ne 1) { Mal "Primero tiene que estar aplicado aplicar-correos-marca-panel.ps1. No toco nada."; return }
$cambios = @(
    ,@('src\index.ts', 'mails: titulo debajo del logo y pie con el link del panel', '  const resumen = titulo || equipo
    ? `<td class="og-res" align="right" style="vertical-align:middle;padding-left:12px;font-family:Arial,sans-serif">${titulo ? `<div style="color:#ffffff;font-size:14px;font-weight:700;line-height:1.3">${textoCorreo(titulo)}</div>` : ""}${equipo ? `<div style="color:#F1D58A;font-size:13px;margin-top:3px">${equipo}</div>` : ""}</td>`
    : "";
  return `<style>@media only screen and (max-width:480px){.og-res,.og-logo{display:block!important;width:auto!important;text-align:left!important}.og-res{padding:12px 0 0!important}}</style><div style="background:#EEF2FB;padding:18px 10px"><div data-og-marca="1" style="max-width:620px;margin:0 auto;padding:16px 22px;background:#0F1A3A;border-radius:16px 16px 0 0"><table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse"><tr><td class="og-logo" style="vertical-align:middle;width:200px"><img src="${logo}" width="196" height="36" alt="Ojo Guard" style="display:block;border:0;outline:none;text-decoration:none"></td>${resumen}</tr></table></div>${claroCorreo(html)}<div style="max-width:620px;margin:0 auto;padding:14px 22px 0;text-align:center;font-family:Arial,sans-serif;font-size:12px;color:#5B6580">Ojo Guard &middot; soporte@ojoguard.app</div></div>`;
}', '  const resumen = titulo || equipo
    ? `<div style="font-family:Arial,sans-serif;padding-top:14px">${titulo ? `<div style="color:#ffffff;font-size:15px;font-weight:700;line-height:1.35">${textoCorreo(titulo)}</div>` : ""}${equipo ? `<div style="color:#F1D58A;font-size:13px;margin-top:3px">${equipo}</div>` : ""}</div>`
    : "";
  return `<div style="background:#EEF2FB;padding:18px 10px"><div data-og-marca="1" style="max-width:620px;margin:0 auto;padding:18px 22px 16px;background:#0F1A3A;border-radius:16px 16px 0 0"><img src="${logo}" width="196" height="36" alt="Ojo Guard" style="display:block;border:0;outline:none;text-decoration:none">${resumen}</div>${claroCorreo(html)}<div style="max-width:620px;margin:0 auto;padding:16px 22px 0;text-align:center;font-family:Arial,sans-serif;font-size:13px;line-height:1.6;color:#5B6580">Tu panel de Ojo Guard: <a href="${DEFAULT_PANEL_URL}" style="color:#1F4FD1;font-weight:700;text-decoration:none">${DEFAULT_PANEL_URL.replace(/^https?:\/\//, "").replace(/\/$/, "")}</a><br>Guard&#225; este link: lo vas a necesitar si perd&#233;s el acceso. Soporte: soporte@ojoguard.app</div></div>`;
}')
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
    if (Test-Path ($ruta + ".bak-correospie")) { Mal ("Ya existe " + $t + ".bak-correospie. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-correospie"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-correospie): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-correospie") -Destination $ruta -Force }
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
Ok "LISTO: el titulo queda debajo del logo y el pie muestra el link del panel. Pedi otro codigo de ingreso para verlo."
Write-Host ""
