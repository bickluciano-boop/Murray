# aplicar-medicamentos-app.ps1 - App (PROXIMA build): la palabra "remedio(s)" pasa a "medicamento(s)" en todo lo que se ve (tarjeta de Familia y la pregunta al tocar el aviso).
# Luciano (14/11/2026): "podemos cambiar la palabra remedios por medicamentos, porque despues en ingles tambien es medicine". Solo textos visibles: no se tocan nombres internos. Cambia src\FamiliaPantalla.tsx y App.tsx (respaldo .bak-medic).
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
foreach ($f in @("src\FamiliaPantalla.tsx", "App.tsx")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\FamiliaPantalla.tsx")).texto '>MIS MEDICAMENTOS</Text>') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
$cambios = @(
    @('src\FamiliaPantalla.tsx', 'app: titulo del aviso "No se pudo cargar"', 'titulo="Remedios"', 'titulo="Medicamentos"'),
    @('src\FamiliaPantalla.tsx', 'app: "Puedes cargar hasta N medicamentos"', 'hasta ${actual.max.items} remedios.', 'hasta ${actual.max.items} medicamentos.'),
    @('src\FamiliaPantalla.tsx', 'app: "Escribe el nombre del medicamento"', 'Escribe el nombre del remedio.', 'Escribe el nombre del medicamento.'),
    @('src\FamiliaPantalla.tsx', 'app: "Hasta N horas por medicamento"', 'horas por remedio.', 'horas por medicamento.'),
    @('src\FamiliaPantalla.tsx', 'app: encabezado MEDICAMENTOS', '}>REMEDIOS</Text>', '}>MEDICAMENTOS</Text>'),
    @('src\FamiliaPantalla.tsx', 'app: explicacion "todos los medicamentos de esa hora"', 'con todos los remedios de esa hora', 'con todos los medicamentos de esa hora'),
    @('src\FamiliaPantalla.tsx', 'app: MIS MEDICAMENTOS', '>MIS REMEDIOS</Text>', '>MIS MEDICAMENTOS</Text>'),
    @('src\FamiliaPantalla.tsx', 'app: EDITAR / NUEVO MEDICAMENTO', '"EDITAR REMEDIO" : "NUEVO REMEDIO"', '"EDITAR MEDICAMENTO" : "NUEVO MEDICAMENTO"'),
    @('src\FamiliaPantalla.tsx', 'app: etiqueta del nombre (accesibilidad)', 'accessibilityLabel="Nombre del remedio"', 'accessibilityLabel="Nombre del medicamento"'),
    @('src\FamiliaPantalla.tsx', 'app: texto de ayuda del nombre', 'placeholder="Nombre del remedio"', 'placeholder="Nombre del medicamento"'),
    @('src\FamiliaPantalla.tsx', 'app: "Si tomas varios medicamentos a la misma hora"', 'Si tomas varios remedios a la misma hora', 'Si tomas varios medicamentos a la misma hora'),
    @('src\FamiliaPantalla.tsx', 'app: boton Guardar medicamento', '"Guardando…" : "Guardar remedio"', '"Guardando…" : "Guardar medicamento"'),
    @('src\FamiliaPantalla.tsx', 'app: boton Agregar otro / un medicamento', '"Agregar otro remedio" : "Agregar un remedio"', '"Agregar otro medicamento" : "Agregar un medicamento"'),
    @('src\FamiliaPantalla.tsx', 'app: "No decimos que medicamento"', 'No decimos qué remedio.', 'No decimos qué medicamento.'),
    @('App.tsx', 'app: titulo de la pregunta al tocar el aviso', 'Alert.alert("Remedio", ', 'Alert.alert("Medicamento", '),
    @('App.tsx', 'app: pregunta "Tomaste tu medicamento?"', '"¿Tomaste tu remedio?"', '"¿Tomaste tu medicamento?"'),
    @('App.tsx', 'app: "busca Medicamentos y toca Lo tome"', 'busca Remedios y toca', 'busca Medicamentos y toca')
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
    if (Test-Path ($ruta + ".bak-medic")) { Mal ("Ya existe " + $t + ".bak-medic. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-medic"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-medic): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-medic") -Destination $ruta -Force }
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
    foreach ($t in $tocados) { $ruta = Join-Path $raiz $t; if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-medic") -Destination $ruta -Force } }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "LISTO: la app compila bien. Dice medicamentos en vez de remedios (sale en la PROXIMA build, Android e iPhone)."
Write-Host ""
