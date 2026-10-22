# aplicar-arranque2-app.ps1 - App Ojo Guard: barra de 6 pasos y texto de bienvenida (segunda parte del arranque).
# El arranque del usuario nuevo tiene 6 pasos (cuenta, codigo, foto de perfil, documento, cara, preparar el telefono); vincular personas queda para despues, como pediste.
#  - "Preparar este telefono" muestra la barra y dice "Paso 6 de 6". Los pasos de foto dicen "de 6".
#  - Diapositiva 11 de la bienvenida: suma que los movimientos del circulo llegan como aviso en el telefono.
# Cambia App.tsx (una sola ancla) y reemplaza src/Bienvenida.tsx y src/ArranqueIdentidad.tsx por la version nueva. Va en la carpeta de la APP. Respaldo .bak-arranque2. Sale en la PROXIMA build.
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
if (-not (Test-Path (Join-Path $raiz "App.tsx"))) { Mal "No encuentro App.tsx en esta carpeta."; return }
if (-not (Test-Path (Join-Path $raiz "src\ArranqueIdentidad.tsx"))) { Mal "Falta aplicar-arranque-app.ps1 primero (no encuentro src\ArranqueIdentidad.tsx)."; return }
if ((Contar (Leer (Join-Path $raiz "App.tsx")).texto 'Paso 6 de 6') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
$cambios = @(
    ,@('App.tsx', 'Preparar este telefono: barra de 6 pasos (paso 6 de 6)', ('          {firstRun ? <Text style={styles.setupTitle}>Preparar este tel' + [char]0x00e9 + 'fono</Text> : null}
'), ('          {firstRun ? (
            <View style={{ alignItems: "center", flexDirection: "row", justifyContent: "space-between", marginTop: 14 }}>
              <View style={{ flexDirection: "row", gap: 5 }}>
                {[1, 2, 3, 4, 5, 6].map((paso) => (
                  <View key={paso} style={{ backgroundColor: P.doradoRelleno, borderRadius: 3, height: 6, width: 18 }} />
                ))}
              </View>
              <Text style={{ color: P.textoDebil, fontSize: 13, fontWeight: "700" }}>Paso 6 de 6</Text>
            </View>
          ) : null}
          {firstRun ? <Text style={styles.setupTitle}>Preparar este tel' + [char]0x00e9 + 'fono</Text> : null}
'))
)
$descargas = @(
    @('https://raw.githubusercontent.com/bickluciano-boop/Murray/1bea65c8cc7bc12c7ed15029f9a2dbdb116821e5/scripts/app/arranque/Bienvenida.tsx', 'src/Bienvenida.tsx', '9b1a98aa97f3aba5da5ce0493849f15f5f815f38d9c0cd7ed5e8221507675178'),
    @('https://raw.githubusercontent.com/bickluciano-boop/Murray/1bea65c8cc7bc12c7ed15029f9a2dbdb116821e5/scripts/app/arranque/ArranqueIdentidad.tsx', 'src/ArranqueIdentidad.tsx', '378da291192bf1b51c6701afd4a87b411e901fc9647797f468b65b8681eadde2')
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
    $carpetaTmp = Split-Path -Parent $tmp; if (-not (Test-Path $carpetaTmp)) { New-Item -ItemType Directory -Path $carpetaTmp -Force | Out-Null }
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
    if (Test-Path ($ruta + ".bak-arranque2")) { Mal ("Ya existe " + $t + ".bak-arranque2. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-arranque2"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-arranque2): " + ($respaldados -join ", "))

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
foreach ($d in $descargas) { $dest = Join-Path $raiz $d[1]; $carpeta = Split-Path -Parent $dest; if (-not (Test-Path $carpeta)) { New-Item -ItemType Directory -Path $carpeta -Force | Out-Null }; Move-Item -LiteralPath ($dest + ".descarga") -Destination $dest -Force }

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-arranque2") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "LISTO: el arranque quedo en 6 pasos y la bienvenida con el texto nuevo. Sale en la proxima build."
Write-Host ""
