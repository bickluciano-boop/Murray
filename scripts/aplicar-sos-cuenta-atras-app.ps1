# aplicar-sos-cuenta-atras-app.ps1 - App (PROXIMA build, iPhone y Android). Luciano (14/11/2026): el SOS sono en el telefono de su familia sin que lo pidiera; salio de su iPhone en su casa, por el atajo "SOS Ojo Guard" (toque en la espalda).
# Ahora el SOS pedido desde el enlace del atajo (toque en la espalda, Siri, pantalla de bloqueo) muestra una cuenta regresiva de 5 segundos con un boton enorme "Cancelar" y otro "Enviar ya"; si no se toca nada, el SOS sale solo.
# El boton rojo (mantenerlo 3 segundos) y los dos botones de volumen de Android no cambian. Agrega src\sosCuentaAtras.ts y src\SosCuentaAtrasPantalla.tsx; toca src\sosTask.ts y src\SosBlock.tsx (respaldo .bak-sos5).
# Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba.
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

if (-not (Test-Path (Join-Path $raiz "app.json")) -or (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta de la APP (la que tiene app.json), no la del panel."; return }
Ok "Carpeta correcta"
foreach ($f in @("src\sosTask.ts", "src\SosBlock.tsx")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\sosTask.ts")).texto 'iniciarCuentaAtras') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
$cambios = @(
    @('src\sosTask.ts', 'sos: importar la cuenta regresiva', 'import AsyncStorage from "@react-native-async-storage/async-storage";
', 'import AsyncStorage from "@react-native-async-storage/async-storage";
import { iniciarCuentaAtras } from "./sosCuentaAtras";
'),
    @('src\sosTask.ts', 'sos: el enlace del atajo empieza la cuenta regresiva (antes mandaba el SOS al instante)', '  await AsyncStorage.setItem(CLAVE_USO_ATAJO, new Date().toISOString()).catch(() => undefined);
  void triggerSos();
', '  await AsyncStorage.setItem(CLAVE_USO_ATAJO, new Date().toISOString()).catch(() => undefined);
  // Un toque sin querer en la espalda del iPhone no tiene que hacer sonar la sirena de toda la familia: hay 5 segundos para cancelar (pantalla SosCuentaAtrasPantalla.tsx).
  // Si la pantalla no esta a la vista, la cuenta igual corre y el SOS sale solo al llegar a cero.
  iniciarCuentaAtras(() => void triggerSos());
'),
    @('src\SosBlock.tsx', 'sos: importar la pantalla de la cuenta regresiva', 'import { useCallback, useEffect, useRef, useState } from "react";
', 'import { useCallback, useEffect, useRef, useState } from "react";
import { SosCuentaAtras } from "./SosCuentaAtrasPantalla";
'),
    @('src\SosBlock.tsx', 'sos: la pantalla de la cuenta regresiva junto al boton de la barra', '  return <SosBlock enrollment={vinculo} visible={conFamilia} cuadrado paleta={paleta} botones={botones} />;
}', '  return (
    <>
      <SosBlock enrollment={vinculo} visible={conFamilia} cuadrado paleta={paleta} botones={botones} />
      <SosCuentaAtras />
    </>
  );
}')
)
$descargas = @(
    @('https://raw.githubusercontent.com/bickluciano-boop/Murray/18440b6288a81345237016e0447b081399fe66f0/scripts/app/src/sosCuentaAtras.ts', 'src\sosCuentaAtras.ts', '89b30107f80fa581b1d34d149f4d2aa457bde559d8bae284ed75417807f57302'),
    @('https://raw.githubusercontent.com/bickluciano-boop/Murray/18440b6288a81345237016e0447b081399fe66f0/scripts/app/src/SosCuentaAtrasPantalla.tsx', 'src\SosCuentaAtrasPantalla.tsx', '68e9fa2aceaab94f22dc80e91c33b675166a578654196f78324db3eb7f0bb236')
)

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
    if (Test-Path ($ruta + ".bak-sos5")) { Mal ("Ya existe " + $t + ".bak-sos5. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-sos5"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-sos5): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-sos5") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "Archivos listos. Reviso que la app compile (puede tardar un minuto)..."
& npx.cmd tsc --noEmit
if ($LASTEXITCODE -ne 0) {
    Mal "La revision de tipos encontro errores (arriba). Dejo todo como estaba."
    foreach ($t in $tocados) { $ruta = Join-Path $raiz $t; if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-sos5") -Destination $ruta -Force } }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "LISTO: la app compila bien. El SOS del atajo ahora tiene 5 segundos para cancelar (sale en la PROXIMA build, Android e iPhone)."
Write-Host ""
