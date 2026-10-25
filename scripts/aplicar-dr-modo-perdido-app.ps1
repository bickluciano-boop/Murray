# aplicar-dr-modo-perdido-app.ps1 - Dr. Ojo Guard: nuevos chequeos para que se vea por que Modo perdido no tapa la pantalla.
# Luciano (24/10/2026): "esto lo tendria que decir el Dr. Ojo Guard". Hoy el Dr. no miraba nada de Modo perdido. Ahora suma (en Android):
#  - "Modo perdido sobre la pantalla bloqueada": mira el permiso de avisos de pantalla completa (Android lo apaga solo a veces) y, si falta,
#    ofrece el boton "Permitir avisos de pantalla completa".
#  - "Revision de ordenes en segundo plano": mira en el historial cuando fue la ultima vez que la app se desperto sola a buscar ordenes; si pasaron mas de 40
#    minutos, avisa que Android puede estar durmiendo la app (y lleva a la bateria).
#  - En iPhone, una nota: con la app cerrada Apple no deja sacar fotos ni audio (la evidencia se toma al abrir la app).
# Toca src\proteccion.ts y src\ProteccionBlock.tsx. Va en la carpeta de la APP (la que tiene app.json). Respaldo .bak-drperdido. Si la revision de tipos
# falla, deja todo como estaba. Es solo codigo de la app (nada nativo): sale en la PROXIMA build.
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
if (-not (Test-Path (Join-Path $raiz "src\proteccion.ts"))) { Mal "No encuentro src\proteccion.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\proteccion.ts")).texto 'itemPantallaCompleta') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
$cambios = @(
    @('src\proteccion.ts', 'imports de pantalla completa y del historial', 'import { readBatteryUnrestricted } from "../modules/exact-alarm";
', 'import { readBatteryUnrestricted } from "../modules/exact-alarm";
import { fullScreenAlertModuleAvailable, hasFullScreenAlertPermission } from "../modules/full-screen-alert";
import { loadFullScreenAlertDiagnostics } from "./fullScreenAlertDiagnostics";
'),
    @('src\proteccion.ts', 'nuevo arreglo: pantalla completa', 'export type Arreglo = "ajustes" | "gesto" | "canal" | "bateria" | "bluetooth";', 'export type Arreglo = "ajustes" | "gesto" | "canal" | "bateria" | "bluetooth" | "pantallacompleta";'),
    @('src\proteccion.ts', 'los dos items nuevos', 'function notas(): string[] {', '/** Modo perdido solo puede tapar la pantalla bloqueada si Android deja los avisos de pantalla completa (a veces los apaga solo al hibernar la app). */
function itemPantallaCompleta(): ItemProteccion | null {
  if (Platform.OS !== "android" || !fullScreenAlertModuleAvailable()) return null;
  const base = { id: "pantalla-completa", titulo: "Modo perdido sobre la pantalla bloqueada", peso: 2, arreglo: "pantallacompleta" as const };
  if (hasFullScreenAlertPermission()) {
    return { ...base, estado: "ok", detalle: "Android deja que Modo perdido tape la pantalla aunque el teléfono esté bloqueado." };
  }
  return {
    ...base,
    estado: "falta",
    detalle: "Android no deja que Modo perdido tape la pantalla: con el teléfono bloqueado solo se vería una notificación. Activá los avisos de pantalla completa (Android a veces los apaga solo).",
  };
}

/** La app se despierta sola cada ~15 minutos a buscar órdenes (Modo perdido, sonar, ubicar). Si hace mucho que no lo hace, esas órdenes tardan. */
async function itemRevisionDeOrdenes(): Promise<ItemProteccion | null> {
  if (Platform.OS !== "android") return null;
  const base = { id: "revision", titulo: "Revisión de órdenes en segundo plano", peso: 1, arreglo: "bateria" as const };
  const historial = await loadFullScreenAlertDiagnostics().catch(() => []);
  let ultima = 0;
  for (const entrada of historial) {
    if (entrada.reason !== "sync-start") continue;
    const cuando = Date.parse(entrada.at);
    if (Number.isFinite(cuando) && cuando > ultima) ultima = cuando;
  }
  if (!ultima) {
    return { ...base, estado: "revisar", detalle: "Todavía no hay registro de que la app se haya despertado sola a buscar órdenes. Dejala unos minutos con el teléfono bloqueado y volvé a hacer el chequeo." };
  }
  const minutos = (Date.now() - ultima) / 60_000;
  if (minutos <= 40) {
    return { ...base, estado: "ok", detalle: `La app se despertó sola a buscar órdenes ${haceCuanto(new Date(ultima).toISOString())}.` };
  }
  return {
    ...base,
    estado: "revisar",
    detalle: `La última vez que la app se despertó sola a buscar órdenes fue ${haceCuanto(new Date(ultima).toISOString())}. Android puede estar durmiendo la app: una orden (Modo perdido, hacer sonar) tardaría en llegar. Revisá la batería.`,
  };
}

function notas(): string[] {'),
    @('src\proteccion.ts', 'la nota del iPhone', ('revis' + [char]0x00e1 + ' que no est' + [char]0x00e9 + ' silenciado.",'), ('revis' + [char]0x00e1 + ' que no est' + [char]0x00e9 + ' silenciado.",
      "Con la app cerrada, el iPhone no deja sacar fotos ni grabar audio: la evidencia que pidas desde el panel se toma cuando abrís Ojo Guard. Es un límite de Apple, no una falla.",')),
    @('src\proteccion.ts', 'esperar la revision de ordenes', 'const [servidor, avisos, ubicacion, sirena, atajo] = await Promise.all([', 'const [servidor, avisos, ubicacion, sirena, atajo, revision] = await Promise.all(['),
    @('src\proteccion.ts', 'pedir la revision de ordenes', '    itemAtajo(),
  ]);', '    itemAtajo(),
    itemRevisionDeOrdenes(),
  ]);'),
    @('src\proteccion.ts', 'poner los items nuevos en la lista', 'itemBateria(), atajo].filter(', 'itemBateria(), itemPantallaCompleta(), revision, atajo].filter('),
    @('src\ProteccionBlock.tsx', 'import del permiso de pantalla completa', 'import { openBatterySettings } from "../modules/exact-alarm";
', 'import { openBatterySettings } from "../modules/exact-alarm";
import { requestFullScreenAlertPermission } from "../modules/full-screen-alert";
'),
    @('src\ProteccionBlock.tsx', 'texto del boton nuevo', '  bluetooth: "Abrir el Bluetooth",
};', '  bluetooth: "Abrir el Bluetooth",
  pantallacompleta: "Permitir avisos de pantalla completa",
};'),
    @('src\ProteccionBlock.tsx', 'que hace el boton nuevo', '    if (arreglo === "gesto") openSosAccessibilitySettings();', '    if (arreglo === "pantallacompleta") requestFullScreenAlertPermission();
    else if (arreglo === "gesto") openSosAccessibilitySettings();')
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
    if (Test-Path ($ruta + ".bak-drperdido")) { Mal ("Ya existe " + $t + ".bak-drperdido. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-drperdido"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-drperdido): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-drperdido") -Destination $ruta -Force }
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
    foreach ($t in $tocados) { $ruta = Join-Path $raiz $t; if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-drperdido") -Destination $ruta -Force } }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "LISTO: la app compila bien. Sale en la PROXIMA build."
Write-Host ""
