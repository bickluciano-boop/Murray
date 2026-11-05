# aplicar-permisos-ojo4-app.ps1 - App (PROXIMA build): las llaves de SOS que "no aplican" se muestran quietas.
# Luciano (05/11/2026): "el menor no tiene por que escuchar una alerta y asustarse, el padre si". Un menor nunca recibe el SOS de los adultos; la tarjeta decia "Recibe tu SOS: Si". Ahora dice "No aplica" (raya, gris, sin tocar).
# Requiere aplicar-permisos-ojo3-app.ps1 y el servidor aplicar-permisos-ojo4-panel.ps1 (sin eso se ve como antes). Toca solo src\FamiliaPantalla.tsx (respaldo .bak-permisos4). Va en la carpeta de la APP.
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
if (-not (Test-Path (Join-Path $raiz "src\FamiliaPantalla.tsx"))) { Mal "No encuentro src\FamiliaPantalla.tsx en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\FamiliaPantalla.tsx")).texto 'const fija = (clave: ClavePermiso)') -eq 0) { Mal "Falta aplicar primero aplicar-permisos-ojo3-app.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\FamiliaPantalla.tsx")).texto 'const noAplica') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
$cambios = @(
    @('src\FamiliaPantalla.tsx', 'permisos4: tipo con elegible', 'type Llave = { on: boolean; mine: boolean; theirs: boolean; ultimo?: boolean };', 'type Llave = { on: boolean; mine: boolean; theirs: boolean; ultimo?: boolean; elegible?: boolean };'),
    @('src\FamiliaPantalla.tsx', 'permisos4: fila que dice "no aplica"', 'function FilaLlave({ P, tipo, titulo, nombre, llave, bloqueada, guardando, onPress }: { P: Paleta; tipo: "ojo" | "sirena"; titulo: string; nombre: string; llave: Llave; bloqueada: boolean; guardando: boolean; onPress: () => void }) {
  const sp = estilosPermisos(P);
  const encendida = llave.on;
  const tono = encendida ? P.exito : (P.peligroFuerte ?? P.peligro);
  const detalle = encendida ? null : !llave.mine ? "Lo apagaste vos" : `Lo apagó ${nombre} de su lado`;
  const fija = bloqueada || (encendida && llave.ultimo === true);
  return (
    <Pressable accessibilityRole="switch" accessibilityState={{ checked: encendida, disabled: fija }} disabled={fija || guardando} onPress={onPress} style={[sp.fila, fija ? { opacity: 0.6 } : null]}>
      <View style={[sp.icono, { backgroundColor: encendida ? P.exitoFondo : P.peligroFondo, borderColor: encendida ? P.exitoBorde : P.peligroBorde }]}>
        <IconoPermiso tipo={tipo} apagado={!encendida} color={tono} tam={22} />
      </View>
      <View style={{ flex: 1, minWidth: 0 }}>
        <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.titulo}>{titulo}</Text>
        {detalle ? <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.detalle}>{detalle}</Text> : null}
      </View>
      <View style={[sp.pastilla, { backgroundColor: encendida ? P.exitoFondo : P.peligroFondo, borderColor: encendida ? P.exitoBorde : P.peligroBorde, opacity: guardando ? 0.55 : 1 }]}>
        <View style={[sp.punto, { backgroundColor: tono }]} />
        <Text maxFontSizeMultiplier={TOPE_LETRA} style={[sp.pastillaTexto, { color: tono }]}>{encendida ? "Sí" : "No"}</Text>
      </View>
    </Pressable>
  );
}

', 'function FilaLlave({ P, tipo, titulo, nombre, llave, bloqueada, guardando, onPress }: { P: Paleta; tipo: "ojo" | "sirena"; titulo: string; nombre: string; llave: Llave; bloqueada: boolean; guardando: boolean; onPress: () => void }) {
  const sp = estilosPermisos(P);
  // "No aplica": un menor no recibe el SOS de los adultos (y un amigo solo el de su titular): la llave se muestra quieta y dice por que.
  const noAplica = llave.elegible === false;
  const encendida = llave.on && !noAplica;
  const tono = noAplica ? P.textoDebil : encendida ? P.exito : (P.peligroFuerte ?? P.peligro);
  const fondo = noAplica ? P.campo : encendida ? P.exitoFondo : P.peligroFondo;
  const borde = noAplica ? P.borde : encendida ? P.exitoBorde : P.peligroBorde;
  const detalle = noAplica
    ? (titulo === "Recibe tu SOS" ? `${nombre} no recibe tu SOS (es menor o amigo).` : `No recibís el SOS de ${nombre}.`)
    : encendida ? null : !llave.mine ? "Lo apagaste vos" : `Lo apagó ${nombre} de su lado`;
  const fija = noAplica || bloqueada || (encendida && llave.ultimo === true);
  return (
    <Pressable accessibilityRole="switch" accessibilityState={{ checked: encendida, disabled: fija }} disabled={fija || guardando} onPress={onPress} style={[sp.fila, fija ? { opacity: noAplica ? 0.75 : 0.6 } : null]}>
      <View style={[sp.icono, { backgroundColor: fondo, borderColor: borde }]}>
        <IconoPermiso tipo={tipo} apagado={!encendida} color={tono} tam={22} />
      </View>
      <View style={{ flex: 1, minWidth: 0 }}>
        <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.titulo}>{titulo}</Text>
        {detalle ? <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.detalle}>{detalle}</Text> : null}
      </View>
      <View style={[sp.pastilla, { backgroundColor: fondo, borderColor: borde, opacity: guardando ? 0.55 : 1 }]}>
        <View style={[sp.punto, { backgroundColor: tono }]} />
        <Text maxFontSizeMultiplier={TOPE_LETRA} style={[sp.pastillaTexto, { color: tono }]}>{noAplica ? "—" : encendida ? "Sí" : "No"}</Text>
      </View>
    </Pressable>
  );
}

'),
    @('src\FamiliaPantalla.tsx', 'permisos4: color del resumen', '  const tonoDe = (llave: Llave) => (llave.on ? P.exito : (P.peligroFuerte ?? P.peligro));
', '  const tonoDe = (llave: Llave) => (llave.elegible === false ? P.textoDebil : llave.on ? P.exito : (P.peligroFuerte ?? P.peligro));
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
    if (Test-Path ($ruta + ".bak-permisos4")) { Mal ("Ya existe " + $t + ".bak-permisos4. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-permisos4"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-permisos4): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-permisos4") -Destination $ruta -Force }
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
    foreach ($t in $tocados) { $ruta = Join-Path $raiz $t; if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-permisos4") -Destination $ruta -Force } }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "LISTO: la app compila bien. Sale en la PROXIMA build."
Write-Host ""
