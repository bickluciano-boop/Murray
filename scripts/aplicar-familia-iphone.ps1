# aplicar-familia-iphone.ps1 - Familia en iPhone: el telefono manda su ubicacion solo, en segundo plano y aunque la app
# este cerrada, si comparte su ubicacion con una familia. Va en la carpeta de la APP (la que tiene app.json).
# Agrega src\familyLocation.ts, actualiza src\FamilySection.tsx (aviso del permiso "Siempre") y toca App.tsx,
# src\liveLocation.ts, src\remoteApi.ts y app.json. Respaldos .bak-iphone; si algo falla, se restaura todo. Sale en la PROXIMA build.
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
if (-not (Test-Path (Join-Path $raiz "src\FamilySection.tsx"))) { Mal "Falta Familia en la app: primero corre aplicar-familia-app.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "App.tsx")).texto 'watchFamilyLocation') -ne 0) { Avi "La ubicacion de familia para iPhone ya estaba aplicada. No toco nada."; return }
if (Test-Path (Join-Path $raiz "src\familyLocation.ts")) { Mal "Ya existe src\familyLocation.ts de un intento anterior. No toco nada. Mandame esta pantalla."; return }
if ((Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $raiz "src\FamilySection.tsx")).Hash.ToLower() -ne "fb59e89a8ce3269a09cedbf25402283d4214895b416108f81a574664a180ff75") { Mal "src\FamilySection.tsx no es la version que espero (lo cambio alguien?). No toco nada. Mandame esta pantalla."; return }
$cambios = @(
    @('App.tsx', 'importar la ubicacion de familia', 'import { FamilySection } from "./src/FamilySection";', 'import { FamilySection } from "./src/FamilySection";
import { watchFamilyLocation } from "./src/familyLocation";'),
    @('App.tsx', 'prenderla al abrir la app', '  // Android 14 puede revocar solo el permiso de avisos de pantalla completa', '  // iPhone: si este telefono comparte su ubicacion con una familia, que la mande
  // solo en segundo plano, aunque la app este cerrada (ver src/familyLocation.ts).
  useEffect(() => watchFamilyLocation(), []);

  // Android 14 puede revocar solo el permiso de avisos de pantalla completa'),
    @('src\liveLocation.ts', 'compartir la direccion', 'async function direccionPara(position: Location.LocationObject)', 'export async function direccionPara(position: Location.LocationObject)'),
    @('src\remoteApi.ts', 'punto suelto o en vivo', '  address: string | null;
  live: true;
};', '  address: string | null;
  // true: "Seguir en vivo"; false: un punto suelto (Familia en iPhone, familyLocation.ts).
  live: boolean;
};'),
    @('app.json', 'texto del permiso Siempre (1)', 'en segundo plano solamente cuando el titular solicita encontrar su tel', 'en segundo plano cuando el titular solicita encontrar su tel'),
    @('app.json', 'texto del permiso Siempre (2)', 'desde Ojo Guard MS.",', 'desde Ojo Guard MS y, si compart\u00eds tu ubicaci\u00f3n con tu familia, para que te vean en el mapa.",')
)
$descargas = @(
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/3c5f1f3/scripts/familia/familyLocation.ts", "src\familyLocation.ts", "21452031da40bc2ab9fe659c83467f1473e90bf49d1a0ce217bf17cc8d8ce13d"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/3c5f1f3/scripts/familia/FamilySection.tsx", "src\FamilySection.tsx", "d08bdf7aa3754bfd5bdb189af7a364ace367a9ae43515c60d8aa9f6acf95e032")
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
    if (Test-Path ($ruta + ".bak-iphone")) { Mal ("Ya existe " + $t + ".bak-iphone. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-iphone"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-iphone): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-iphone") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "TODO BIEN. Para revisar que compile:  powershell -ExecutionPolicy Bypass -Command ""npx tsc --noEmit""  (si no muestra nada, esta perfecto)"
Ok "Sale en la PROXIMA build de iPhone. En Android no cambia nada."
Write-Host ""
