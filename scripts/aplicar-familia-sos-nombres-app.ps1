# aplicar-familia-sos-nombres-app.ps1 - App (PROXIMA build): "Familia y amigos" dice con nombres quien te ve y a quien le suena tu SOS.
# Luciano (04/11/2026): "donde aparece con quien estoy compartiendo la ubicacion y a quien le mandas el SOS" (como lo muestran Apple y Google, dentro de la pantalla que ya existe, sin una nueva).
#  - Tarjeta "MI UBICACION": "Te ven: Papa, Guido y 3 mas." (la regla de quien se ve con quien es simetrica; un grupo grande se resume).
#  - Tarjeta "SOS Y AYUDA": "Tu SOS les suena en la app a: ...". Necesita aplicar antes aplicar-familia-sos-nombres-panel.ps1 (el servidor manda sosTo); sin eso la linea no se muestra.
# Toca solo src\FamiliaPantalla.tsx (respaldo .bak-sosnombres). Va en la carpeta de la APP (la que tiene app.json).
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
if ((Contar (Leer (Join-Path $raiz "src\FamiliaPantalla.tsx")).texto 'function listaDeNombres') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
$cambios = @(
    @('src\FamiliaPantalla.tsx', 'listas de nombres (ayudas)', 'type Paleta = { [clave: string]: string };
', 'type Paleta = { [clave: string]: string };

/** "Papá, Guido y 3 más": nombres para decir con quien se comparte, sin que un grupo grande ocupe media pantalla. */
function listaDeNombres(nombres: string[], max = 4): string {
  const limpios = nombres.map((n) => n.trim()).filter(Boolean);
  if (limpios.length <= max) return limpios.length > 1 ? `${limpios.slice(0, -1).join(", ")} y ${limpios[limpios.length - 1]}` : (limpios[0] ?? "");
  return `${limpios.slice(0, max).join(", ")} y ${limpios.length - max} más`;
}

/** A quien le suena el SOS de esta persona (lo decide el servidor y lo manda en `sosTo`). null si el servidor todavia no lo manda. */
function sosA(people: FamilyPerson[]): string[] | null {
  const marcadas = people as (FamilyPerson & { sosTo?: boolean })[];
  if (!marcadas.some((p) => p.sosTo !== undefined)) return null;
  return marcadas.filter((p) => p.sosTo === true).map((p) => p.name);
}
'),
    @('src\FamiliaPantalla.tsx', 'Mi ubicacion: quien te ve', '<Text style={botones.ayuda}>Tu familia ve dónde estás. Podés pausarlo un rato y volver a compartir cuando quieras.</Text>', '<Text style={botones.ayuda}>{people.length ? `Te ven: ${listaDeNombres(people.map((p) => p.name))}.` : "Tu familia ve dónde estás."} Podés pausarlo un rato y volver a compartir cuando quieras.</Text>'),
    @('src\FamiliaPantalla.tsx', 'Mi ubicacion (menor): con quien compartis', 'Compartís tu ubicación con tu familia. Tus tutores pueden ver dónde estás; siempre vas a ver acá con quién la compartís.', '{people.length ? `Compartís tu ubicación con ${listaDeNombres(people.map((p) => p.name))}.` : "Compartís tu ubicación con tu familia."} Tus tutores pueden ver dónde estás.'),
    @('src\FamiliaPantalla.tsx', 'SOS: a quien le suena', '            {/* El SOS trae su propio espacio de arriba (18 y 8): se descuenta para que no quede un hueco dentro de la tarjeta. */}
', '            {sosA(people) !== null ? (
              <Text style={botones.ayuda}>
                {(sosA(people) ?? []).length ? `Tu SOS les suena en la app a: ${listaDeNombres(sosA(people) ?? [])}.` : "Hoy tu SOS no le suena a nadie en la app. Sumá a alguien desde el mapa del Inicio."}
              </Text>
            ) : null}
            {/* El SOS trae su propio espacio de arriba (18 y 8): se descuenta para que no quede un hueco dentro de la tarjeta. */}
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
    if (Test-Path ($ruta + ".bak-sosnombres")) { Mal ("Ya existe " + $t + ".bak-sosnombres. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-sosnombres"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-sosnombres): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-sosnombres") -Destination $ruta -Force }
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
    foreach ($t in $tocados) { $ruta = Join-Path $raiz $t; if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-sosnombres") -Destination $ruta -Force } }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "LISTO: la app compila bien. Sale en la PROXIMA build."
Write-Host ""
