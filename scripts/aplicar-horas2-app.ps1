# aplicar-horas2-app.ps1 - App (PROXIMA build). Luciano (14/11/2026), probando la 204: al EDITAR un medicamento no podia cambiar su hora ("no me deja poner ningun horario, me lo guarda siempre a las 10").
# Antes, "-" y "+" solo movian el selector y "Agregar esta hora" no hacia nada (ni avisaba) si esa hora ya estaba en la lista: para cambiar una hora habia que quitarla con la ✕ y agregar otra.
# Ahora: tocas una hora de la lista (queda marcada) y "-" / "+" o la TIRA DE HORAS (que se desliza, de 00:00 a 23:30) la CAMBIAN en su lugar; la ✕ la quita; "Agregar otra hora" suma la siguiente media hora libre y la deja elegida. Requiere aplicar-horas-app.ps1 y aplicar-medicamentos-app.ps1.
# Toca src\FamiliaPantalla.tsx (respaldo .bak-horas2). Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba.
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
if ((Contar (Leer (Join-Path $raiz "src\FamiliaPantalla.tsx")).texto 'const moverHora = (pasos: number)') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\FamiliaPantalla.tsx")).texto 'function Deslizable') -eq 0) { Mal "Falta aplicar primero aplicar-horas-app.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\FamiliaPantalla.tsx")).texto 'horas por medicamento.') -eq 0) { Mal "Falta aplicar primero aplicar-medicamentos-app.ps1."; return }
$cambios = @(
    @('src\FamiliaPantalla.tsx', 'horas: cada hora de la lista se elige (queda marcada) y tiene su propia ✕', '                {borrador.horas.map((h) => (
                  <Pressable key={h} accessibilityRole="button" accessibilityLabel={`Quitar la hora ${h}`} onPress={() => setBorrador({ ...borrador, horas: borrador.horas.filter((x) => x !== h) })} style={chip(true)}>
                    <Text maxFontSizeMultiplier={TOPE_LETRA} style={chipTexto(true)}>{`${h}  ✕`}</Text>
                  </Pressable>
                ))}
', '                {borrador.horas.map((h) => (
                  <View key={h} style={{ alignItems: "center", flexDirection: "row", gap: 2 }}>
                    <Pressable accessibilityRole="button" accessibilityLabel={`Cambiar la hora ${h}`} accessibilityState={{ selected: h === borrador.hora }} onPress={() => setBorrador({ ...borrador, hora: h })} style={chip(h === borrador.hora)}>
                      <Text maxFontSizeMultiplier={TOPE_LETRA} style={chipTexto(h === borrador.hora)}>{h}</Text>
                    </Pressable>
                    <Pressable
                      accessibilityRole="button"
                      accessibilityLabel={`Quitar la hora ${h}`}
                      hitSlop={8}
                      onPress={() => {
                        const quedan = borrador.horas.filter((x) => x !== h);
                        setBorrador({ ...borrador, horas: quedan, hora: h === borrador.hora ? (quedan[0] ?? borrador.hora) : borrador.hora });
                      }}
                    >
                      <Text maxFontSizeMultiplier={TOPE_LETRA} style={{ color: P.textoDebil, fontSize: 16, fontWeight: "800", paddingHorizontal: 6 }}>✕</Text>
                    </Pressable>
                  </View>
                ))}
                <Text maxFontSizeMultiplier={TOPE_LETRA} style={[sp.nota, { width: "100%" }]}>Toca una hora para cambiarla con − y +. La ✕ la quita.</Text>
'),
    @('src\FamiliaPantalla.tsx', 'horas: el boton - cambia la hora elegida en su lugar', 'onPress={() => setBorrador({ ...borrador, hora: moverHoraRemedio(borrador.hora, -1) })}', 'onPress={() => moverHora(-1)}'),
    @('src\FamiliaPantalla.tsx', 'horas: el boton + cambia la hora elegida en su lugar', 'onPress={() => setBorrador({ ...borrador, hora: moverHoraRemedio(borrador.hora, 1) })}', 'onPress={() => moverHora(1)}'),
    @('src\FamiliaPantalla.tsx', 'horas: "Agregar otra hora" suma la siguiente media hora libre', '  const agregarHora = () => {
    if (!borrador) return;
    if (borrador.horas.includes(borrador.hora)) return;
    if (borrador.horas.length >= actual.max.horas) {
      setAviso(`Hasta ${actual.max.horas} horas por medicamento.`);
      return;
    }
    setAviso("");
    setBorrador({ ...borrador, horas: [...borrador.horas, borrador.hora].sort() });
  };
', '  // Si la hora del selector es una de la lista, elegir otra hora (con "-", "+" o la tira de horas) la CAMBIA en su lugar (para editar un horario ya cargado);
  // si todavia no esta en la lista, solo mueve el selector.
  const elegirHora = (h: string) => {
    if (!borrador) return;
    if (borrador.horas.includes(borrador.hora) && !borrador.horas.includes(h)) {
      setBorrador({ ...borrador, hora: h, horas: borrador.horas.map((x) => (x === borrador.hora ? h : x)).sort() });
      return;
    }
    setBorrador({ ...borrador, hora: h });
  };
  const moverHora = (pasos: number) => {
    if (borrador) elegirHora(moverHoraRemedio(borrador.hora, pasos));
  };
  // Agrega la hora del selector; si ya esta en la lista, agrega la siguiente media hora libre (antes no hacia nada y no decia por que). La nueva queda elegida para ajustarla con - y +.
  const agregarHora = () => {
    if (!borrador) return;
    if (borrador.horas.length >= actual.max.horas) {
      setAviso(`Hasta ${actual.max.horas} horas por medicamento.`);
      return;
    }
    let nueva = borrador.hora;
    for (let i = 0; i < 48 && borrador.horas.includes(nueva); i += 1) nueva = moverHoraRemedio(nueva, 1);
    if (borrador.horas.includes(nueva)) return;
    setAviso("");
    setBorrador({ ...borrador, horas: [...borrador.horas, nueva].sort(), hora: nueva });
  };
'),
    @('src\FamiliaPantalla.tsx', 'horas: constante con las 48 medias horas del dia', 'function moverHoraRemedio(hhmm: string, pasos: number): string {
', '// Todas las medias horas del dia (00:00 a 23:30) para la tira de horas que se desliza.
const HORAS_DEL_DIA = Array.from({ length: 48 }, (_, i) => `${String(Math.floor(i / 2)).padStart(2, "0")}:${i % 2 === 0 ? "00" : "30"}`);
function moverHoraRemedio(hhmm: string, pasos: number): string {
'),
    @('src\FamiliaPantalla.tsx', 'horas: tira de horas que se desliza (elegir una hora tocandola)', '            <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.separador}>CADA CUÁNTO</Text>
', '            <Deslizable activo desde={Math.max(0, HORAS_DEL_DIA.indexOf(borrador.hora) - 2) * 72}>
              <View style={{ flexDirection: "row", gap: 6 }}>
                {HORAS_DEL_DIA.map((h) => (
                  <Pressable key={h} accessibilityRole="button" accessibilityLabel={`Hora ${h}`} accessibilityState={{ selected: h === borrador.hora }} onPress={() => elegirHora(h)} style={chip(h === borrador.hora)}>
                    <Text maxFontSizeMultiplier={TOPE_LETRA} style={chipTexto(h === borrador.hora)}>{h}</Text>
                  </Pressable>
                ))}
              </View>
            </Deslizable>
            <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.separador}>CADA CUÁNTO</Text>
'),
    @('src\FamiliaPantalla.tsx', 'horas: el boton dice "Agregar otra hora" cuando ya hay horas', 'style={chipTexto(true)}>Agregar esta hora</Text>', 'style={chipTexto(true)}>{borrador.horas.length ? "Agregar otra hora" : "Agregar esta hora"}</Text>')
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
    if (Test-Path ($ruta + ".bak-horas2")) { Mal ("Ya existe " + $t + ".bak-horas2. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-horas2"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-horas2): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-horas2") -Destination $ruta -Force }
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
    foreach ($t in $tocados) { $ruta = Join-Path $raiz $t; if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-horas2") -Destination $ruta -Force } }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "LISTO: la app compila bien. Las horas de un medicamento se cambian en su lugar (sale en la PROXIMA build, Android e iPhone)."
Write-Host ""
