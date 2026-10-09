# aplicar-mapa-android.ps1 - Arregla que Ojo Guard se cierre sola en Android al abrir.
# El mapa de Familia (y el del detalle de un intento) usa Google Maps, que en Android pide una clave
# que la app no tiene: sin ella, la app se cierra apenas lo muestra. En Android ya no se muestra ese
# mapa: cada persona se toca y se abre en Google Maps. En iPhone queda igual (usa el mapa de Apple).
# Va en la carpeta de la APP (la que tiene app.json). Toca App.tsx y src\FamilySection.tsx. Respaldo .bak-mapa.
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
if ((Contar (Leer (Join-Path $raiz "src\FamilySection.tsx")).texto 'abrirEnMapa') -ne 0) { Avi "El arreglo del mapa en Android ya estaba aplicado. No toco nada."; return }
$cambios = @(
    @('src\FamilySection.tsx', 'abrir a la persona en Google Maps', 'function mensajeDeError(error: unknown) {', '// Android: abre a la persona en Google Maps (ahi la app no muestra el mapa; ver mas abajo).
function abrirEnMapa(p: FamilyPerson) {
  const lat = Number(p.lastLocation?.latitude);
  const lng = Number(p.lastLocation?.longitude);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return;
  void Linking.openURL(`https://www.google.com/maps/search/?api=1&query=${lat},${lng}`).catch(() => undefined);
}

function mensajeDeError(error: unknown) {'),
    @('src\FamilySection.tsx', 'sin mapa adentro en Android', '      {region ? (', '      {/* Android: el mapa de Google pide una clave que la app no tiene, y sin ella la app se
          cierra. Ahi cada persona se toca y se abre en Google Maps. */}
      {region && Platform.OS !== "android" ? ('),
    @('src\FamilySection.tsx', 'tocar a la persona', '        <View key={p.id} style={s.fila}>', '        <Pressable
          key={p.id}
          accessibilityRole={Platform.OS === "android" ? "button" : undefined}
          disabled={Platform.OS !== "android" || !p.lastLocation || Boolean(p.paused)}
          onPress={() => abrirEnMapa(p)}
          style={s.fila}
        >'),
    @('src\FamilySection.tsx', 'cerrar la fila', '          </View>
        </View>
      ))}', '          </View>
          {Platform.OS === "android" && p.lastLocation && !p.paused ? <Text style={s.ir}>{"Mapa \u203a"}</Text> : null}
        </Pressable>
      ))}'),
    @('src\FamilySection.tsx', 'estilo de Mapa', '    detalle: { color: P.textoSuave, fontSize: 12, marginTop: 2 },', '    detalle: { color: P.textoSuave, fontSize: 12, marginTop: 2 },
    ir: { color: P.doradoTexto, fontSize: 13, fontWeight: "600" },'),
    @('App.tsx', 'intento: sin mapa adentro en Android', '                      <Pressable
                        onPress={() => setEmbeddedMapVisible((visible) => !visible)}', '                      {/* Android: el mapa de Google pide una clave que la app no tiene, y sin ella la
                          app se cierra. Quedan los botones de abajo, que abren Google Maps. */}
                      {Platform.OS === "android" ? null : <Pressable
                        onPress={() => setEmbeddedMapVisible((visible) => !visible)}'),
    @('App.tsx', 'intento: cerrar el boton', '                      </Pressable>
                      {embeddedMapVisible ? <View style={styles.embeddedMapCard}>', '                      </Pressable>}
                      {embeddedMapVisible && Platform.OS !== "android" ? <View style={styles.embeddedMapCard}>')
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
    if (Test-Path ($ruta + ".bak-mapa")) { Mal ("Ya existe " + $t + ".bak-mapa. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-mapa"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-mapa): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-mapa") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "TODO BIEN. Ahora la build de Android:  eas.cmd build --platform android --profile preview"
Write-Host ""
