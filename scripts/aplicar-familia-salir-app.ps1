# aplicar-familia-salir-app.ps1 - Familia: "Salir de la familia de ..." en Configuracion > Familia y amigos.
# Cualquiera puede salir, tambien un menor; al titular le llega un correo. Necesita el panel con
# aplicar-menores-evidencia.ps1 publicado. Va en la carpeta de la APP (la que tiene app.json).
# Toca src\FamilySection.tsx y src\remoteApi.ts. Respaldo .bak-salir. Sale en la PROXIMA build.
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
if ((Contar (Leer (Join-Path $raiz "src\remoteApi.ts")).texto 'export async function leaveFamily') -ne 0) { Avi "Salir de la familia ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\FamilySection.tsx")).texto 'abrirEnMapa') -eq 0) { Mal "Primero corre aplicar-mapa-android.ps1."; return }
$cambios = @(
    @('src\remoteApi.ts', 'salir de una familia', 'export async function reportLostModeDeactivated(', '/** Salir de la familia de un titular (personId "titular:correo", como viene en fetchFamily). */
export async function leaveFamily(enrollment: NativeEnrollment, personId: string) {
  await nativeRequest(enrollment, "/api/native/family/leave", {
    method: "POST",
    body: JSON.stringify({ deviceId: enrollment.deviceId, personId }),
  });
}

export async function reportLostModeDeactivated('),
    @('src\FamilySection.tsx', 'importar Alert', 'import { AppState, Linking, Platform, Pressable,', 'import { Alert, AppState, Linking, Platform, Pressable,'),
    @('src\FamilySection.tsx', 'importar leaveFamily', 'import { fetchFamily, joinFamily, pauseFamilyLocation, type FamilyPerson } from "./remoteApi";', 'import { fetchFamily, joinFamily, leaveFamily, pauseFamilyLocation, type FamilyPerson } from "./remoteApi";'),
    @('src\FamilySection.tsx', 'salir: confirmar y avisar', '  const s = estilos(P);
', '  // Cualquiera puede salir de una familia, tambien un menor (al titular le llega un correo).
  // Si alguien te puso como Menor sin que corresponda, desde aca te vas.
  function confirmarSalir(p: FamilyPerson) {
    Alert.alert(
      `\u00bfSalir de la familia de ${p.name}?`,
      "Dej\u00e1s de ver a esa familia en el mapa y ellos dejan de verte. Para volver, te tienen que mandar una invitaci\u00f3n nueva.",
      [
        { text: "Cancelar", style: "cancel" },
        { text: "Salir", style: "destructive", onPress: () => void salir(p) },
      ],
    );
  }

  async function salir(p: FamilyPerson) {
    if (!enrollment) return;
    setOcupado(true);
    setMensaje("");
    try {
      await leaveFamily(enrollment, p.id);
      setMensaje(`Saliste de la familia de ${p.name}.`);
      await cargar(enrollment);
      void adjustFamilyLocation();
    } catch (error) {
      setMensaje(mensajeDeError(error));
    } finally {
      setOcupado(false);
    }
  }

  const s = estilos(P);
'),
    @('src\FamilySection.tsx', 'salir: un link por familia', '      {enrollment ? (
        <Pressable accessibilityRole="button" onPress={() => { setMensaje(""); void cargar(enrollment); }}', '      {people.filter((p) => p.owner).map((p) => (
        <Pressable key={`salir-${p.id}`} accessibilityRole="button" disabled={ocupado} onPress={() => confirmarSalir(p)} style={s.salirFila}>
          <Text style={s.salir}>Salir de la familia de {p.name}</Text>
        </Pressable>
      ))}

      {enrollment ? (
        <Pressable accessibilityRole="button" onPress={() => { setMensaje(""); void cargar(enrollment); }}'),
    @('src\FamilySection.tsx', 'salir: estilo', '    ir: { color: P.doradoTexto, fontSize: 13, fontWeight: "600" },
', '    ir: { color: P.doradoTexto, fontSize: 13, fontWeight: "600" },
    salirFila: { paddingVertical: 10 },
    salir: { color: P.textoSuave, fontSize: 13, fontWeight: "600", textDecorationLine: "underline" },
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
    if (Test-Path ($ruta + ".bak-salir")) { Mal ("Ya existe " + $t + ".bak-salir. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-salir"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-salir): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-salir") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "TODO BIEN. Sale en la proxima build (Android e iPhone)."
Write-Host ""
