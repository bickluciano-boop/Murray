# aplicar-icono-app.ps1 - App Ojo Guard: icono nuevo (ojo dorado sobre azul marino).
# Reemplaza SOLO las imagenes del icono que app.json ya usa (icono y primer plano del icono adaptable de Android). No cambia codigo ni app.json.
# Va en la carpeta de la APP (la que tiene app.json). Respaldo .bak-icono. Sale en la PROXIMA build.
$ErrorActionPreference = "Continue"
function Ok($t)  { Write-Host ("OK    " + $t) -ForegroundColor Green }
function Mal($t) { Write-Host ("MAL   " + $t) -ForegroundColor Red }
function Avi($t) { Write-Host ("AVISO " + $t) -ForegroundColor Yellow }
$raiz = (Get-Location).Path
function Sha([string]$ruta) { return (Get-FileHash -Algorithm SHA256 -LiteralPath $ruta).Hash.ToLower() }

if (-not (Test-Path (Join-Path $raiz "app.json")) -or (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta de la APP (la que tiene app.json), no la del panel."; return }
Ok "Carpeta correcta"
try { $cfg = Get-Content -LiteralPath (Join-Path $raiz "app.json") -Raw -Encoding UTF8 | ConvertFrom-Json } catch { Mal "No pude leer app.json."; return }

$destinos = @()
$rutaIcono = $null; $rutaAdaptable = $null
if ($cfg.expo -and $cfg.expo.icon) { $rutaIcono = [string]$cfg.expo.icon }
if ($cfg.expo -and $cfg.expo.android -and $cfg.expo.android.adaptiveIcon -and $cfg.expo.android.adaptiveIcon.foregroundImage) { $rutaAdaptable = [string]$cfg.expo.android.adaptiveIcon.foregroundImage }
if ($rutaIcono) { $destinos += ,@($rutaIcono, 'icon-1024.png', '6fefa17fb2ba1d78e77d9cf8892c92f6f04bc5b893da8d337c3491f2024263c0', 'icono de la app') } else { Avi "app.json no indica un icono (expo.icon). No lo toco." }
if ($rutaAdaptable) {
    $mismo = $false
    if ($rutaIcono) { $mismo = ((Join-Path $raiz $rutaIcono) -eq (Join-Path $raiz $rutaAdaptable)) }
    if ($mismo) { Avi "El icono adaptable usa la misma imagen que el icono: queda la del icono." } else { $destinos += ,@($rutaAdaptable, 'adaptive-foreground-1024.png', '8798e924377b87813cd81916216ecd5e2a74a0942b200bfbfd3fd47f6b7d863e', 'icono adaptable de Android') }
} else { Avi "app.json no indica un icono adaptable de Android. No lo toco." }
if ($destinos.Count -eq 0) { Mal "No hay nada para reemplazar."; return }

$base = 'https://raw.githubusercontent.com/bickluciano-boop/Murray/06bed373ff0df1caa1b63fe8a1b18262d4d7196d/scripts/app/arranque/'
$listos = @()
foreach ($d in $destinos) {
    $ruta = Join-Path $raiz $d[0]
    if (-not (Test-Path $ruta)) { Avi ("No existe " + $d[0] + " en esta carpeta. No lo toco."); continue }
    if (Test-Path ($ruta + ".bak-icono")) { Avi ("Ya existe " + $d[0] + ".bak-icono: el icono ya estaba reemplazado. No lo toco."); continue }
    $tmp = $ruta + ".descarga"
    try { Invoke-WebRequest -UseBasicParsing ($base + $d[1]) -OutFile $tmp } catch { }
    if (-not (Test-Path $tmp) -or (Sha $tmp) -ne $d[2]) {
        if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Force }
        Mal ("No se pudo descargar bien " + $d[1] + ". No toque nada de ese archivo."); continue
    }
    Ok ("Descargado y verificado: " + $d[1])
    Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-icono")
    Move-Item -LiteralPath $tmp -Destination $ruta -Force
    if ((Sha $ruta) -eq $d[2]) { Ok ($d[3] + ": reemplazado (" + $d[0] + ")"); $listos += $d[0] }
    else { Copy-Item -LiteralPath ($ruta + ".bak-icono") -Destination $ruta -Force; Mal ($d[3] + ": no quedo bien, restaurado."); }
}
Write-Host ""
if ($listos.Count -gt 0) { Ok ("LISTO: " + $listos.Count + " imagen(es) reemplazada(s). Salen en la proxima build.") } else { Avi "No se reemplazo nada." }
Write-Host ""
