# aplicar-evidencia-trasera-familia-panel.ps1 - Evidencia de un familiar: tambien llega la foto TRASERA (antes solo la delantera y el audio).
# Luciano (26/10/2026): "si mi papa no encuentra el telefono... con la de adelante no me alcanza. Cuanto mas informacion, mejor, siempre que la persona lo autorice".
# Cuando se le pide foto y audio a una persona de la familia (no a un equipo propio), el servidor devolvia solo la delantera y el audio. Ahora tambien devuelve la trasera,
# la tarjeta (navegador y app) la muestra al lado de la delantera, y el mail que se manda lleva las dos fotos. La persona sigue viendo en su telefono cada pedido.
# La llave por persona ("puede pedirme foto y audio") queda para el panel de permisos que estamos disenando: este cambio no la reemplaza.
# Requiere aplicar-evidencia-tarjeta-consola-panel.ps1. Va en la carpeta del PANEL (la que tiene wrangler.toml). Toca src\index.ts y src\panel-mapa.txt. Respaldo .bak-traserafamilia.
# No cambia la estructura de la base. Al final publica el panel solo.
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
$mapaTexto = (Leer (Join-Path $raiz "src\panel-mapa.txt")).texto
if ((Contar $mapaTexto 'htmlEvidencia(estado.evidencia, elegido) : htmlEvidenciaApp(elegido)') -eq 0 -and (Contar $mapaTexto '${htmlEvidenciaApp(elegido)}') -eq 0) { Mal "Falta aplicar antes aplicar-evidencia-tarjeta-consola-panel.ps1. No toco nada."; return }
$indexTexto = (Leer (Join-Path $raiz "src\index.ts")).texto
if ((Contar $indexTexto 'rear_object_key AS rearKey') -ne 0) { Avi "Esto ya estaba aplicado en el panel. No toco nada."; return }
$cambios = @(
    @('src\index.ts', 'evidencia de familiar: leer tambien la trasera', 'SELECT front_object_key AS frontKey,audio_object_key AS audioKey,location_json AS locationJson,occurred_at AS occurredAt FROM evidence_attempts WHERE id=? AND device_id=?"', 'SELECT front_object_key AS frontKey,rear_object_key AS rearKey,audio_object_key AS audioKey,location_json AS locationJson,occurred_at AS occurredAt FROM evidence_attempts WHERE id=? AND device_id=?"'),
    @('src\index.ts', 'evidencia de familiar: tipo con trasera', 'first<{ frontKey: string | null; audioKey: string | null; locationJson: string | null; occurredAt: string }>();', 'first<{ frontKey: string | null; rearKey: string | null; audioKey: string | null; locationJson: string | null; occurredAt: string }>();'),
    @('src\index.ts', 'evidencia de familiar: enlace a la trasera', 'command.evidence = { front: ev.frontKey ? `${base}&kind=front` : null, audio: ev.audioKey ? `${base}&kind=audio` : null };', 'command.evidence = { front: ev.frontKey ? `${base}&kind=front` : null, rear: ev.rearKey ? `${base}&kind=rear` : null, audio: ev.audioKey ? `${base}&kind=audio` : null };'),
    @('src\index.ts', 'evidencia de familiar: entregar la trasera', '  const audio = url.searchParams.get("kind") === "audio";
  const key = audio ? ev.audioKey : ev.frontKey;', '  const tipoArchivo = url.searchParams.get("kind");
  const audio = tipoArchivo === "audio";
  const key = audio ? ev.audioKey : tipoArchivo === "rear" ? ev.rearKey : ev.frontKey;'),
    @('src\index.ts', 'evidencia de familiar: la trasera tambien va en el mail', 'for (const [key, filename] of [[ev.frontKey, "foto.jpg"], [ev.audioKey, "audio.m4a"]] as const) {', 'for (const [key, filename] of [[ev.frontKey, "foto.jpg"], [ev.rearKey, "foto-trasera.jpg"], [ev.audioKey, "audio.m4a"]] as const) {'),
    @('src\panel-mapa.txt', 'tarjeta: guardar la trasera que llega', '{ id: equipo.id, front: c.evidence.front, audio: c.evidence.audio, en:', '{ id: equipo.id, front: c.evidence.front, rear: c.evidence.rear, audio: c.evidence.audio, en:'),
    @('src\panel-mapa.txt', 'tarjeta: mostrar la trasera que acaba de llegar', 'const ev = nueva ? { front: nueva.front, audio: nueva.audio, en: nueva.en } :', 'const ev = nueva ? { front: nueva.front, rear: nueva.rear, audio: nueva.audio, en: nueva.en } :'),
    @('src\panel-mapa.txt', 'tarjeta del navegador: mismo formato (con las dos fotos) para la que acaba de llegar', '${estado.evidencia?.id === elegido.id ? htmlEvidencia(estado.evidencia, elegido) : htmlEvidenciaApp(elegido)}', '${htmlEvidenciaApp(elegido)}')
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
    if (Test-Path ($ruta + ".bak-traserafamilia")) { Mal ("Ya existe " + $t + ".bak-traserafamilia. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-traserafamilia"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-traserafamilia): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-traserafamilia") -Destination $ruta -Force }
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
Ok "LISTO: el panel quedo publicado. Recarga la consola (ojoguard.app): al pedirle foto y audio a un familiar, llegan las dos fotos."
Write-Host ""
