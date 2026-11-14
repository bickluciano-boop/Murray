# aplicar-horas-app.ps1 - App (PROXIMA build). Luciano (14/11/2026), probando en el iPhone:
#  1) "HORA DEL SALUDO" (Buen dia): solo habia 07:00 a 11:00 en punto y no se podia elegir 10:30. Ahora hay de 05:00 a 13:00 cada media hora y la fila se desliza hacia los costados.
#  2) Remedios: ponia la hora con - / + pero no tocaba "Agregar esta hora" y al guardar decia "agrega al menos una hora". Ahora, si todavia no agrego ninguna, se guarda con la hora que muestra el selector.
# Toca src\FamiliaPantalla.tsx (respaldo .bak-horas). Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba.
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
if ((Contar (Leer (Join-Path $raiz "src\FamiliaPantalla.tsx")).texto 'function Deslizable') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
$cambios = @(
    @('src\FamiliaPantalla.tsx', 'horas: importar el desplazamiento horizontal', 'import * as Location from "expo-location";
', 'import { ScrollView as ScrollHorizontal } from "react-native";
import * as Location from "expo-location";
'),
    @('src\FamiliaPantalla.tsx', 'horas del Buen dia: de 05:00 a 13:00 cada media hora', 'const HORAS_BUEN_DIA = ["07:00", "08:00", "09:00", "10:00", "11:00"];
', '// De 05:00 a 13:00 cada media hora (17 opciones): la fila se desliza hacia los costados.
const HORAS_BUEN_DIA = Array.from({ length: 17 }, (_, i) => {
  const minutos = 5 * 60 + i * 30;
  return `${String(Math.floor(minutos / 60)).padStart(2, "0")}:${minutos % 60 === 0 ? "00" : "30"}`;
});
'),
    @('src\FamiliaPantalla.tsx', 'opciones del cuidado: la fila se desliza si son muchas', 'function OpcionesCuidado({ P, titulo, opciones, elegida, onElegir }: { P: Paleta; titulo: string; opciones: { valor: string; texto: string }[]; elegida: string; onElegir: (valor: string) => void }) {
  const sp = estilosPermisos(P);
  return (
    <View style={{ gap: 6 }}>
      <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.separador}>{titulo}</Text>
      <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 6 }}>
', '/** Si hay muchas opciones (las horas del Buen dia, cada media hora) la fila se desliza hacia los costados y empieza en la elegida; con pocas, se acomodan en renglones. */
function Deslizable({ activo, desde, children }: { activo: boolean; desde: number; children: ReactNode }) {
  const ref = useRef<ScrollHorizontal>(null);
  if (!activo) return <>{children}</>;
  return (
    <ScrollHorizontal ref={ref} horizontal showsHorizontalScrollIndicator={false} onContentSizeChange={() => ref.current?.scrollTo({ x: desde, y: 0, animated: false })}>
      {children}
    </ScrollHorizontal>
  );
}

function OpcionesCuidado({ P, titulo, opciones, elegida, onElegir }: { P: Paleta; titulo: string; opciones: { valor: string; texto: string }[]; elegida: string; onElegir: (valor: string) => void }) {
  const sp = estilosPermisos(P);
  const muchas = opciones.length > 6;
  const indiceElegida = opciones.findIndex((o) => o.valor === elegida);
  return (
    <View style={{ gap: 6 }}>
      <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.separador}>{titulo}</Text>
      <Deslizable activo={muchas} desde={Math.max(0, indiceElegida - 1) * 82}>
      <View style={{ flexDirection: "row", flexWrap: muchas ? "nowrap" : "wrap", gap: 6 }}>
'),
    @('src\FamiliaPantalla.tsx', 'opciones del cuidado: cierre de la fila deslizable', '        })}
      </View>
    </View>
  );
}
', '        })}
      </View>
      </Deslizable>
    </View>
  );
}
'),
    @('src\FamiliaPantalla.tsx', 'remedios: si no agrego ninguna hora se usa la del selector', '    if (!borrador.horas.length) {
', '    // Si todavia no toco "Agregar esta hora", se guarda con la hora que muestra el selector (antes pedia agregarla y confundia).
    const horasFinal = borrador.horas.length ? borrador.horas : [borrador.hora];
    if (!horasFinal.length) {
'),
    @('src\FamiliaPantalla.tsx', 'remedios: guardar con esa hora', 'nombre, horas: borrador.horas, dias, diaMes: borrador.frecuencia === "mensual" ? borrador.diaMes : null };', 'nombre, horas: horasFinal, dias, diaMes: borrador.frecuencia === "mensual" ? borrador.diaMes : null };')
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
    if (Test-Path ($ruta + ".bak-horas")) { Mal ("Ya existe " + $t + ".bak-horas. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-horas"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-horas): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-horas") -Destination $ruta -Force }
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
    foreach ($t in $tocados) { $ruta = Join-Path $raiz $t; if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-horas") -Destination $ruta -Force } }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "LISTO: la app compila bien. Sale en la PROXIMA build (Android e iPhone)."
Write-Host ""
