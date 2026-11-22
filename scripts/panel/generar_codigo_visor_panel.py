# Genera scripts/renovar-codigo-visor-panel.ps1: crea un codigo nuevo para el visor (secreto RVI_TOKEN), lo guarda en el panel y lo deja copiado en el portapapeles.
# Luciano (22/11/2026): el codigo del primer instalador se perdio del portapapeles (no se puede volver a ver). No cambia ningun archivo del panel: solo "wrangler secret put RVI_TOKEN".
R = '/home/user/Murray/scripts/'
ps = r'''# renovar-codigo-visor-panel.ps1 - Ojo Guard MS (panel): crea un codigo NUEVO para el visor de prueba con Google 3D (secreto RVI_TOKEN).
# El codigo viejo deja de valer. No cambia ningun archivo del panel ni lo publica: solo guarda el secreto. El codigo queda COPIADO en el portapapeles y NO se muestra.
# Va en la carpeta del PANEL (la que tiene wrangler.toml).
$ErrorActionPreference = "Stop"
function Ok([string]$t) { Write-Host ("OK    " + $t) -ForegroundColor Green }
function Mal([string]$t) { Write-Host ("MAL   " + $t) -ForegroundColor Red }
function Avi([string]$t) { Write-Host ("AVISO " + $t) -ForegroundColor Yellow }
$raiz = (Get-Location).Path
if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
$indice = Join-Path $raiz "src\index.ts"
if (-not (Test-Path $indice)) { Mal "No encuentro src\index.ts en esta carpeta."; return }
if (-not (Select-String -LiteralPath $indice -Pattern "async function rviContornos" -SimpleMatch -Quiet)) { Mal "Falta aplicar primero aplicar-contornos-panel.ps1."; return }
Write-Host "Creando el codigo nuevo del visor (secreto RVI_TOKEN)..."
$bytesRvi = New-Object byte[] 24
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create(); $rng.GetBytes($bytesRvi); $rng.Dispose()
$codigoRvi = ([System.BitConverter]::ToString($bytesRvi)).Replace("-", "").ToLower()
$ErrorActionPreference = "Continue"
$salidaSecreto = ($codigoRvi | & npx.cmd wrangler secret put RVI_TOKEN 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0) { Write-Host $salidaSecreto; Mal "No se pudo guardar el secreto. Mandame esta pantalla."; return }
Ok "Secreto guardado"
try { Set-Clipboard -Value $codigoRvi } catch { Avi "No pude copiarlo al portapapeles." }
Write-Host "Probando la ruta (sin mostrar el codigo)..."
$estadoRvi = "sin respuesta"
for ($intento = 1; $intento -le 4; $intento++) {
    try {
        $resp = Invoke-WebRequest -UseBasicParsing -TimeoutSec 40 -Uri ("https://ojoguard.app/api/rvi/buildings?lat=-34.6037&lon=-58.3816&k=" + $codigoRvi)
        $estadoRvi = "HTTP " + $resp.StatusCode + " (cache: " + $resp.Headers["x-rvi-cache"] + ")"; break
    } catch {
        $codigoHttp = ""; try { $codigoHttp = [int]$_.Exception.Response.StatusCode } catch { }
        $estadoRvi = "HTTP " + $codigoHttp; if ($codigoHttp -eq 403 -or $codigoHttp -eq 404) { Start-Sleep -Seconds 8 } else { Start-Sleep -Seconds 5 }
    }
}
Write-Host ("      Prueba de la ruta: " + $estadoRvi)
Write-Host ""
Ok "LISTO: el codigo nuevo quedo guardado y COPIADO en el portapapeles (no se muestra aca)."
Write-Host "      Pegalo YA en el visor, en 'Codigo del panel'. No copies nada mas antes de pegarlo. No me lo mandes por el chat." -ForegroundColor Yellow
Write-Host ""
'''
bad = [c for c in ps if ord(c) > 127]
assert not bad, set(bad)
open(R + 'renovar-codigo-visor-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(ps.replace('\n', '\r\n'))
print('ok', len(ps))
