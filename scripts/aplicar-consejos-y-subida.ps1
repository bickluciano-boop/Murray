# aplicar-consejos-y-subida.ps1 - Para la proxima build: (1) en iPhone, Configuracion muestra "Protege tu iPhone
# contra robo" (Proteccion de dispositivo robado y Centro de control bloqueado); (2) eas.json con el perfil de
# subida, para que la build de iPhone se suba sola a TestFlight con --auto-submit.
# Va en la carpeta de la APP (la que tiene app.json). Toca App.tsx y eas.json. Respaldo .bak-consejos.
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
if ((Contar (Leer (Join-Path $raiz "App.tsx")).texto 'contra robo"}') -ne 0) { Avi "Los consejos del iPhone ya estaban aplicados. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "eas.json")).texto '"submit"') -ne 0) { Mal "eas.json ya tiene un perfil de subida (submit). No toco nada. Mandame esta pantalla."; return }
$cambios = @(
    @('App.tsx', 'consejos de seguridad del iPhone', '          {!firstRun ? (
            <FamilySection
', '          {Platform.OS === "ios" ? (
            // Dos ajustes de Apple para que un ladron no pueda apagar Buscar ni poner el modo avion con
            // el iPhone bloqueado (asi el telefono sigue mandando su ubicacion). La app no puede
            // cambiarlos ni leerlos: solo explicarlos. Abierto en la configuracion inicial.
            <CollapsibleSection defaultOpen={firstRun} title={"Proteg\u00e9 tu iPhone contra robo"} subtitle={"Dos ajustes del iPhone, un minuto"}>
              <Text style={styles.fieldHelp}>
                {"1. Ajustes \u203a Face ID y c\u00f3digo \u203a Protecci\u00f3n de dispositivo robado: activala. As\u00ed, lejos de tus lugares habituales, apagar Buscar o cambiar tu cuenta de Apple pide tu cara y no alcanza con el c\u00f3digo."}
              </Text>
              <Text style={[styles.fieldHelp, { marginTop: 10 }]}>
                {"2. En esa misma pantalla, m\u00e1s abajo, est\u00e1 lo que se puede usar con el iPhone bloqueado: apag\u00e1 Centro de control. As\u00ed nadie puede poner el modo avi\u00f3n sin desbloquearlo y el tel\u00e9fono sigue mandando su ubicaci\u00f3n."}
              </Text>
            </CollapsibleSection>
          ) : null}

          {!firstRun ? (
            <FamilySection
'),
    @('eas.json', 'subida automatica a TestFlight', '  "build": {
', '  "submit": {
    "production": {
      "ios": {
        "ascAppId": "6812533689"
      }
    }
  },
  "build": {
')
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
    if (Test-Path ($ruta + ".bak-consejos")) { Mal ("Ya existe " + $t + ".bak-consejos. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-consejos"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-consejos): " + ($respaldados -join ", "))

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
$jsonOk = $true
try { $null = (Get-Content -LiteralPath (Join-Path $raiz "eas.json") -Raw | ConvertFrom-Json) } catch { $jsonOk = $false }
Chk "eas.json: sigue siendo valido" $jsonOk

if (-not $todoBien) {
    Mal "Algo no salio bien. Restauro todo desde los respaldos."
    foreach ($t in $tocados) {
        $ruta = Join-Path $raiz $t
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-consejos") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "TODO BIEN. Desde ahora la build de iPhone se sube sola a TestFlight:"
Write-Host "  eas.cmd build --platform ios --profile production --auto-submit"
Write-Host ""
