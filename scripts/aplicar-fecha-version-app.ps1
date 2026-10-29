# aplicar-fecha-version-app.ps1 - App (PROXIMA build): en "Actualizar Ojo Guard" se ve cuando se publico la ultima version ("publicada el 29/10/2026 a las 17:55").
# Idea de Luciano (29/10/2026). La fecha es la de la subida del APK a ojoguard.app/descargar (el servidor ya la manda). Cambia solo src\PaginaActualizar.tsx (respaldo .bak-fecha-version). Va en la carpeta de la APP.
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
if (-not (Test-Path (Join-Path $raiz "src\PaginaActualizar.tsx"))) { Mal "No encuentro src\PaginaActualizar.tsx en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\PaginaActualizar.tsx")).texto 'textoFecha') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
$cambios = @(
    @('src\PaginaActualizar.tsx', 'tipo: fecha en "al dia"', '  | { estado: "al-dia"; publicada: string }
', '  | { estado: "al-dia"; publicada: string; subido: string }
'),
    @('src\PaginaActualizar.tsx', 'tipo: fecha en "nueva"', '  | { estado: "nueva"; publicada: string }
', '  | { estado: "nueva"; publicada: string; subido: string }
'),
    @('src\PaginaActualizar.tsx', 'tipo: fecha en "sin numero"', '  | { estado: "sin-numero"; publicada: string }
', '  | { estado: "sin-numero"; publicada: string; subido: string }
'),
    @('src\PaginaActualizar.tsx', 'funcion que da formato a la fecha', 'export async function consultarVersion(build: string): Promise<EstadoVersion> {
', '/** "2026-10-29T20:55:00Z" -> "29/10/2026 a las 17:55" (hora del telefono). Vacio si no hay una fecha valida. */
function textoFecha(valor: unknown): string {
  const f = new Date(String(valor ?? ""));
  if (!Number.isFinite(f.getTime())) return "";
  const dos = (n: number) => String(n).padStart(2, "0");
  return `${dos(f.getDate())}/${dos(f.getMonth() + 1)}/${f.getFullYear()} a las ${dos(f.getHours())}:${dos(f.getMinutes())}`;
}

export async function consultarVersion(build: string): Promise<EstadoVersion> {
'),
    @('src\PaginaActualizar.tsx', 'leer la fecha que manda el servidor', '    const dato = (await respuesta.json()) as { disponible?: boolean; version?: string };
', '    const dato = (await respuesta.json()) as { disponible?: boolean; version?: string; subido?: string };
'),
    @('src\PaginaActualizar.tsx', 'devolver la fecha con cada resultado', '    if (!Number.isFinite(tengo) || !Number.isFinite(ultima)) return { estado: "sin-numero", publicada };
    return tengo >= ultima ? { estado: "al-dia", publicada } : { estado: "nueva", publicada };
', '    const subido = textoFecha(dato.subido);
    if (!Number.isFinite(tengo) || !Number.isFinite(ultima)) return { estado: "sin-numero", publicada, subido };
    return tengo >= ultima ? { estado: "al-dia", publicada, subido } : { estado: "nueva", publicada, subido };
'),
    @('src\PaginaActualizar.tsx', 'texto: ya tenes la ultima, con la fecha', '      return `Ya tenés la última versión (${e.publicada}).`;
', '      return `Ya tenés la última versión (${e.publicada})${e.subido ? `, publicada el ${e.subido}` : ""}.`;
'),
    @('src\PaginaActualizar.tsx', 'texto: hay una nueva, con la fecha', '      return `Hay una versión nueva: ${e.publicada}. Tocá "Descargar la nueva versión".`;
', '      return `Hay una versión nueva: ${e.publicada}${e.subido ? ` (publicada el ${e.subido})` : ""}. Tocá "Descargar la nueva versión".`;
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
    if (Test-Path ($ruta + ".bak-fecha-version")) { Mal ("Ya existe " + $t + ".bak-fecha-version. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-fecha-version"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-fecha-version): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-fecha-version") -Destination $ruta -Force }
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
    foreach ($t in $tocados) { $ruta = Join-Path $raiz $t; if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-fecha-version") -Destination $ruta -Force } }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "LISTO: la app compila bien. Sale en la PROXIMA build."
Write-Host ""
