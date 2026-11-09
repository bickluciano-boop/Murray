# aplicar-familia-vos-app.ps1 - App (PROXIMA build): tarjeta "VOS" arriba de Familia y amigos, y cada persona con su rol y su tipo de telefono.
# Luciano (09/11/2026, capturas): "no logro entender cual es mi familia": la lista solo mostraba a las otras personas ("Lucho" y "Lu ipone"), nunca a vos ni de quien es la familia.
# Ahora: "VOS: tu nombre / Este telefono · Android / Adulto en la familia de Lucho"; y en PERMISOS cada persona dice "Titular · iPhone", "Adulto · Android"...
# Requiere aplicar-permisos-ojo4-app.ps1, aplicar-cuidado-app.ps1 y el servidor aplicar-familia-vos-panel.ps1 (sin eso la tarjeta VOS no se muestra). Toca src\remoteApi.ts y src\FamiliaPantalla.tsx (respaldo .bak-vos). Va en la carpeta de la APP.
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
foreach ($f in @("src\FamiliaPantalla.tsx", "src\remoteApi.ts")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\FamiliaPantalla.tsx")).texto 'function TarjetaCuidado') -eq 0) { Mal "Falta aplicar primero aplicar-cuidado-app.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\FamiliaPantalla.tsx")).texto 'function TarjetaVos') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
$cambios = @(
    @('src\remoteApi.ts', 'vos: llamada', '/** Salir de la familia de un titular (personId "titular:correo", como viene en fetchFamily). */
', '/** Quien sos "vos" en Familia y amigos: tu nombre, si sos titular y en que familias estas (con tu rol y el nombre del titular). */
export type FamiliaVos = { nombre: string; esTitular: boolean; familias: { titular: string; rol: string }[] };
export async function fetchFamilyMe(enrollment: NativeEnrollment): Promise<FamiliaVos> {
  const query = new URLSearchParams({ deviceId: enrollment.deviceId });
  const response = await nativeRequest(enrollment, `/api/native/family/me?${query.toString()}`);
  const r = (await response.json()) as Partial<FamiliaVos>;
  return {
    nombre: typeof r.nombre === "string" ? r.nombre : "",
    esTitular: r.esTitular === true,
    familias: Array.isArray(r.familias) ? r.familias.map((f) => ({ titular: String(f?.titular ?? ""), rol: String(f?.rol ?? "") })) : [],
  };
}

/** Salir de la familia de un titular (personId "titular:correo", como viene en fetchFamily). */
'),
    @('src\FamiliaPantalla.tsx', 'vos: importar', 'import { answerBuenDia, fetchCare, fetchFamily,', 'import { answerBuenDia, fetchCare, fetchFamily, fetchFamilyMe, type FamiliaVos,'),
    @('src\FamiliaPantalla.tsx', 'vos: componente', '/** A quien le suena el SOS de esta persona', '/** "Vos": tu nombre, este telefono, tu rol y de quien es la familia (antes la lista solo mostraba a las demas personas y no se entendia cual era la tuya). */
function TarjetaVos({ P, enrollment, botones }: { P: Paleta; enrollment: NativeEnrollment; botones: { ayuda: StyleProp<TextStyle> } }) {
  const [vos, setVos] = useState<FamiliaVos | null>(null);
  useEffect(() => {
    let cancelado = false;
    void fetchFamilyMe(enrollment)
      .then((r) => {
        if (!cancelado) setVos(r);
      })
      .catch(() => undefined);
    return () => {
      cancelado = true;
    };
  }, [enrollment]);
  if (!vos) return null;
  const tipo = Platform.OS === "ios" ? "iPhone" : "Android";
  const lugares: string[] = [];
  if (vos.esTitular) lugares.push("Titular de tu propia familia");
  for (const f of vos.familias) lugares.push(`${ROL_CHIP[f.rol] ?? "Integrante"} en la familia de ${f.titular || "otra persona"}`);
  return (
    <>
      <Text style={{ color: P.textoDebil, fontSize: 12, fontWeight: "800", letterSpacing: 1.1, marginBottom: 8, marginTop: 4 }}>VOS</Text>
      <View style={{ backgroundColor: P.superficie, borderColor: P.borde, borderRadius: 18, borderWidth: 1, gap: 4, padding: 16 }}>
        <Text maxFontSizeMultiplier={TOPE_LETRA} style={{ color: P.texto, fontSize: 17, fontWeight: "800" }}>{vos.nombre || "Este teléfono"}</Text>
        <Text maxFontSizeMultiplier={TOPE_LETRA} style={botones.ayuda}>{`Este teléfono · ${tipo}`}</Text>
        {lugares.length ? lugares.map((t) => <Text key={t} maxFontSizeMultiplier={TOPE_LETRA} style={botones.ayuda}>{t}</Text>) : <Text maxFontSizeMultiplier={TOPE_LETRA} style={botones.ayuda}>Todavía no estás en ninguna familia.</Text>}
      </View>
    </>
  );
}

/** A quien le suena el SOS de esta persona'),
    @('src\FamiliaPantalla.tsx', 'vos: en la pantalla', '          <View style={s.etiquetaFila}>
            <Text style={s.etiqueta}>MI FAMILIA</Text>
', '          <TarjetaVos P={P} enrollment={enrollment} botones={botones} />
          <View style={s.etiquetaFila}>
            <Text style={s.etiqueta}>MI FAMILIA</Text>
'),
    @('src\FamiliaPantalla.tsx', 'vos: rol y tipo de telefono de cada persona', '  const rol = persona.owner ? "Titular" : (ROL_CHIP[persona.role] ?? "");
', '  const plataforma = ((persona as { platform?: string }).platform ?? "").toLowerCase();
  const telefono = plataforma.includes("ios") || plataforma.includes("iphone") ? "iPhone" : plataforma.includes("android") ? "Android" : "";
  const rol = [persona.owner ? "Titular" : (ROL_CHIP[persona.role] ?? ""), telefono].filter(Boolean).join(" · ");
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
    if (Test-Path ($ruta + ".bak-vos")) { Mal ("Ya existe " + $t + ".bak-vos. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-vos"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-vos): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-vos") -Destination $ruta -Force }
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
    foreach ($t in $tocados) { $ruta = Join-Path $raiz $t; if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-vos") -Destination $ruta -Force } }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "LISTO: la app compila bien. Sale en la PROXIMA build."
Write-Host ""
