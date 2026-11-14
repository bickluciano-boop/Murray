# aplicar-horas4-app.ps1 - App (PROXIMA build). Luciano (14/11/2026): "no esta tipo scroll que van mirando las horas; esta abajo en la linea y vas corriendo con el dedo de derecha a izquierda".
# Pedia una RUEDA de horas como la del reloj del iPhone (se desliza hacia arriba y abajo; la del medio es la elegida). Se arma una rueda propia, sin modulos nativos nuevos: columna de horas (00-23) y de minutos (00, 15, 30, 45), con snap.
# Reemplaza la tira horizontal y los botones - / + en los medicamentos, y la fila de horas del Buen dia. Requiere aplicar-horas3-app.ps1. Toca src\FamiliaPantalla.tsx (respaldo .bak-horas4). Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba.
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
if ((Contar (Leer (Join-Path $raiz "src\FamiliaPantalla.tsx")).texto 'function RuedaHora') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\FamiliaPantalla.tsx")).texto 'Desliza para ver más horas') -eq 0) { Mal "Falta aplicar primero aplicar-horas3-app.ps1."; return }
$cambios = @(
    @('src\FamiliaPantalla.tsx', 'rueda: importar el ScrollView para la rueda', 'import { ScrollView as ScrollHorizontal } from "react-native";
', 'import { ScrollView as ScrollHorizontal, ScrollView as ScrollRueda } from "react-native";
'),
    @('src\FamiliaPantalla.tsx', 'rueda: se saca la fila de horas del Buen dia (ahora es una rueda)', '// De 05:00 a 13:00 cada media hora (17 opciones): la fila se desliza hacia los costados.
const HORAS_BUEN_DIA = Array.from({ length: 17 }, (_, i) => {
  const minutos = 5 * 60 + i * 30;
  return `${String(Math.floor(minutos / 60)).padStart(2, "0")}:${minutos % 60 === 0 ? "00" : "30"}`;
});
', ''),
    @('src\FamiliaPantalla.tsx', 'rueda: componentes de la rueda (en lugar de la tira de horas)', '// Todas las medias horas del dia (00:00 a 23:30) para la tira de horas que se desliza.
const HORAS_DEL_DIA = Array.from({ length: 48 }, (_, i) => `${String(Math.floor(i / 2)).padStart(2, "0")}:${i % 2 === 0 ? "00" : "30"}`);
function moverHoraRemedio(hhmm: string, pasos: number): string {
', '// ---------------------------------------------------------------------------
// Rueda de horas (como la del reloj del iPhone): se desliza hacia arriba y abajo y la hora del medio, entre las dos lineas, es la elegida.
// Dos columnas: horas (00 a 23) y minutos (00, 15, 30, 45). Sin modulos nativos: es un ScrollView con "snap". Tocar un numero tambien lo elige.
// ---------------------------------------------------------------------------
const ALTO_FILA_RUEDA = 40;
const HORAS_RUEDA = Array.from({ length: 24 }, (_, i) => String(i).padStart(2, "0"));
const MINUTOS_RUEDA = ["00", "15", "30", "45"];

function ColumnaRueda({ P, etiqueta, items, valor, onElegir }: { P: Paleta; etiqueta: string; items: string[]; valor: string; onElegir: (v: string) => void }) {
  const ref = useRef<ScrollRueda>(null);
  const espera = useRef<ReturnType<typeof setTimeout> | null>(null);
  const indice = Math.max(0, items.indexOf(valor));
  // Al abrir (y cuando la hora cambia desde afuera, por ejemplo al tocar otra hora de la lista) la rueda se pone en esa hora.
  useEffect(() => {
    ref.current?.scrollTo({ y: indice * ALTO_FILA_RUEDA, animated: false });
  }, [indice]);
  useEffect(
    () => () => {
      if (espera.current) clearTimeout(espera.current);
    },
    [],
  );
  const confirmar = (y: number) => {
    const i = Math.min(items.length - 1, Math.max(0, Math.round(y / ALTO_FILA_RUEDA)));
    const v = items[i];
    if (v !== undefined && v !== valor) onElegir(v);
  };
  return (
    <View style={{ height: ALTO_FILA_RUEDA * 3, width: 72 }}>
      <ScrollRueda
        ref={ref}
        accessibilityLabel={etiqueta}
        nestedScrollEnabled
        showsVerticalScrollIndicator={false}
        snapToInterval={ALTO_FILA_RUEDA}
        decelerationRate="fast"
        scrollEventThrottle={32}
        contentContainerStyle={{ paddingVertical: ALTO_FILA_RUEDA }}
        onScroll={(e) => {
          const y = e.nativeEvent.contentOffset.y;
          if (espera.current) clearTimeout(espera.current);
          espera.current = setTimeout(() => confirmar(y), 160);
        }}
        onMomentumScrollEnd={(e) => {
          if (espera.current) clearTimeout(espera.current);
          confirmar(e.nativeEvent.contentOffset.y);
        }}
      >
        {items.map((it, i) => (
          <Pressable
            key={it}
            accessibilityRole="button"
            accessibilityLabel={`${etiqueta}: ${it}`}
            onPress={() => {
              ref.current?.scrollTo({ y: i * ALTO_FILA_RUEDA, animated: true });
              onElegir(it);
            }}
            style={{ alignItems: "center", height: ALTO_FILA_RUEDA, justifyContent: "center" }}
          >
            <Text maxFontSizeMultiplier={TOPE_LETRA} style={{ color: it === valor ? P.texto : P.textoDebil, fontSize: it === valor ? 24 : 18, fontWeight: it === valor ? "800" : "500" }}>
              {it}
            </Text>
          </Pressable>
        ))}
      </ScrollRueda>
      <View pointerEvents="none" style={{ borderBottomWidth: 1, borderColor: P.doradoBorde, borderTopWidth: 1, height: ALTO_FILA_RUEDA, left: 0, position: "absolute", right: 0, top: ALTO_FILA_RUEDA }} />
    </View>
  );
}

function RuedaHora({ P, valor, onCambio }: { P: Paleta; valor: string; onCambio: (hhmm: string) => void }) {
  const hh = valor.slice(0, 2);
  const minutosReales = Number(valor.slice(3, 5));
  // Si la hora guardada trae otros minutos (por ejemplo 09:20), la rueda muestra los mas cercanos de la lista hasta que se la mueva.
  const mm = MINUTOS_RUEDA.reduce((mejor, m) => (Math.abs(Number(m) - minutosReales) < Math.abs(Number(mejor) - minutosReales) ? m : mejor), "00");
  return (
    <View style={{ alignItems: "center", flexDirection: "row", gap: 6, justifyContent: "center" }}>
      <ColumnaRueda P={P} etiqueta="Hora" items={HORAS_RUEDA} valor={hh} onElegir={(h) => onCambio(`${h}:${mm}`)} />
      <Text style={{ color: P.texto, fontSize: 24, fontWeight: "800" }}>:</Text>
      <ColumnaRueda P={P} etiqueta="Minutos" items={MINUTOS_RUEDA} valor={mm} onElegir={(m) => onCambio(`${hh}:${m}`)} />
    </View>
  );
}

/** La rueda de la hora del saludo del Buen dia: se guarda UNA vez, cuando se deja de girar (si no, girar horas y despues minutos mandaba dos pedidos seguidos y el segundo se perdia). */
function RuedaSaludo({ P, valor, onGuardar }: { P: Paleta; valor: string; onGuardar: (hhmm: string) => void }) {
  const [local, setLocal] = useState(valor);
  const temporizador = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    setLocal(valor);
  }, [valor]);
  useEffect(
    () => () => {
      if (temporizador.current) clearTimeout(temporizador.current);
    },
    [],
  );
  return (
    <RuedaHora
      P={P}
      valor={local}
      onCambio={(h) => {
        setLocal(h);
        if (temporizador.current) clearTimeout(temporizador.current);
        temporizador.current = setTimeout(() => onGuardar(h), 700);
      }}
    />
  );
}

function moverHoraRemedio(hhmm: string, pasos: number): string {
'),
    @('src\FamiliaPantalla.tsx', 'rueda: ya no hacen falta los botones - / +', '  const moverHora = (pasos: number) => {
    if (borrador) elegirHora(moverHoraRemedio(borrador.hora, pasos));
  };
', ''),
    @('src\FamiliaPantalla.tsx', 'rueda: la rueda y el boton Agregar en el editor de medicamentos (en lugar de - / + y la tira)', '            <View style={{ alignItems: "center", flexDirection: "row", flexWrap: "wrap", gap: 10 }}>
              <Pressable accessibilityRole="button" accessibilityLabel="Hora anterior" onPress={() => moverHora(-1)} style={chip(false)}>
                <Text maxFontSizeMultiplier={TOPE_LETRA} style={chipTexto(false)}>−</Text>
              </Pressable>
              <Text maxFontSizeMultiplier={TOPE_LETRA} style={{ color: P.texto, fontSize: 20, fontWeight: "800", minWidth: 64, textAlign: "center" }}>{borrador.hora}</Text>
              <Pressable accessibilityRole="button" accessibilityLabel="Hora siguiente" onPress={() => moverHora(1)} style={chip(false)}>
                <Text maxFontSizeMultiplier={TOPE_LETRA} style={chipTexto(false)}>+</Text>
              </Pressable>
              <Pressable accessibilityRole="button" onPress={agregarHora} style={chip(true)}>
                <Text maxFontSizeMultiplier={TOPE_LETRA} style={chipTexto(true)}>{borrador.horas.length ? "Agregar otra hora" : "Agregar esta hora"}</Text>
              </Pressable>
            </View>
            <Deslizable activo desde={Math.max(0, HORAS_DEL_DIA.indexOf(borrador.hora) - 1) * 78}>
              <View style={{ flexDirection: "row", gap: 6 }}>
                {HORAS_DEL_DIA.map((h) => (
                  <Pressable key={h} accessibilityRole="button" accessibilityLabel={`Hora ${h}`} accessibilityState={{ selected: h === borrador.hora }} onPress={() => elegirHora(h)} style={[chip(h === borrador.hora), { alignItems: "center", width: 72 }]}>
                    <Text maxFontSizeMultiplier={TOPE_LETRA} style={chipTexto(h === borrador.hora)}>{h}</Text>
                  </Pressable>
                ))}
              </View>
            </Deslizable>
            <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.nota}>Desliza para ver más horas.</Text>
', '            <RuedaHora P={P} valor={borrador.hora} onCambio={elegirHora} />
            <Pressable accessibilityRole="button" onPress={agregarHora} style={[chip(true), { alignSelf: "flex-start" }]}>
              <Text maxFontSizeMultiplier={TOPE_LETRA} style={chipTexto(true)}>{borrador.horas.length ? "Agregar otra hora" : "Agregar esta hora"}</Text>
            </Pressable>
'),
    @('src\FamiliaPantalla.tsx', 'rueda: texto de ayuda de la lista de horas', 'Toca una hora para cambiarla con − y +. La ✕ la quita.', 'Toca una hora de la lista y gira la rueda para cambiarla. La ✕ la quita.'),
    @('src\FamiliaPantalla.tsx', 'rueda: la hora del Buen dia es una rueda', '<OpcionesCuidado P={P} titulo="HORA DEL SALUDO" opciones={HORAS_BUEN_DIA.map((h) => ({ valor: h, texto: h }))} elegida={prefs.hora} onElegir={(h) => void cambiar("hora", { hora: h }, (c) => ({ ...c, prefs: { ...c.prefs, hora: h } }))} />
', '<View style={{ gap: 6 }}>
              <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.separador}>HORA DEL SALUDO</Text>
              <RuedaSaludo P={P} valor={prefs.hora} onGuardar={(h) => void cambiar("hora", { hora: h }, (c) => ({ ...c, prefs: { ...c.prefs, hora: h } }))} />
            </View>
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
    if (Test-Path ($ruta + ".bak-horas4")) { Mal ("Ya existe " + $t + ".bak-horas4. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-horas4"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-horas4): " + ($respaldados -join ", "))

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
    if ($c[3].Length -gt 0) { Chk ($c[0] + ": " + $c[1] + " aplicado") ((Contar $v.texto (Ajustar $c[3] $v.crlf)) -eq 1) }
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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-horas4") -Destination $ruta -Force }
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
    foreach ($t in $tocados) { $ruta = Join-Path $raiz $t; if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-horas4") -Destination $ruta -Force } }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "LISTO: la app compila bien. Las horas se eligen con una rueda (sale en la PROXIMA build, Android e iPhone)."
Write-Host ""
