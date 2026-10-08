# aplicar-familia-amigo.ps1 - Familia: un AMIGO se ve solo con el titular que lo invito. No ve al resto de la
# familia (ni a los menores) y el resto no lo ve a el. Va en la carpeta del PANEL (la que tiene wrangler.toml).
# Toca src\index.ts y actualiza el mapa (texto del rol Amigo). Respaldos .bak-amigo; si algo falla, se restaura todo.
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

if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'f.owner_name AS ownerName') -eq 0) { Mal "Primero corre aplicar-familia-nombre.ps1 (y su comando de la base)."; return }
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'miRol.get(r.ownerEmail)') -ne 0) { Avi "Lo de amigo ya estaba aplicado. No toco nada."; return }
$cambios = @(
    @('src\index.ts', 'familia: comentario de quien ve a quien', '// Una "familia" es el titular (owner_email) mas las personas activas que invito.
// Todos los de una misma familia se ven entre si. Los menores no pueden pausar
// su ubicacion; adultos y amigos si.
// ---------------------------------------------------------------------------', '// Una "familia" es el titular (owner_email) mas las personas activas que invito.
// Adultos y menores de una misma familia se ven entre si. Un amigo se ve solo con
// el titular que lo invito, no con el resto. Los menores no pueden pausar su
// ubicacion; adultos y amigos si.
// ---------------------------------------------------------------------------'),
    @('src\index.ts', 'familia: comentario de la funcion', ' * Las personas que `viewer` puede ver: las de cada familia donde es titular o
 * integrante activo, mas los titulares de esas familias. Para cada una se toma la
 * ultima ubicacion de su telefono principal (o del equipo mas reciente).
 */', ' * Las personas que `viewer` puede ver: las de cada familia donde es titular o
 * integrante activo, mas los titulares de esas familias (con un amigo, solo el
 * titular y el amigo se ven). Para cada una se toma la ultima ubicacion de su
 * telefono principal (o del equipo mas reciente).
 */'),
    @('src\index.ts', 'familia: leer el rol de cada uno', '  // Como ve `viewer` a cada titular: el nombre que ese titular eligio al invitarlo
  // ("Papa", "Luciano"). Sale de la fila de la invitacion de `viewer`.
  const nombreDelTitular = new Map<string, string>();
  for (const r of rows.results) {
    if (r.memberEmail === viewer && r.ownerName) nombreDelTitular.set(r.ownerEmail, r.ownerName);
  }', '  // Como ve `viewer` a cada titular: el nombre que ese titular eligio al invitarlo
  // ("Papa", "Luciano"). Sale de la fila de la invitacion de `viewer`, igual que el
  // rol que tiene `viewer` en esa familia.
  const nombreDelTitular = new Map<string, string>();
  const miRol = new Map<string, string>();
  for (const r of rows.results) {
    if (r.memberEmail !== viewer) continue;
    miRol.set(r.ownerEmail, r.role);
    if (r.ownerName) nombreDelTitular.set(r.ownerEmail, r.ownerName);
  }'),
    @('src\index.ts', 'familia: amigo solo con el titular', '  for (const r of rows.results) {
    if (r.memberEmail && r.memberEmail !== viewer && !personas.has(r.memberEmail)) {
      personas.set(r.memberEmail, { id: r.id, email: r.memberEmail, name: r.name, role: r.role, pausedUntil: r.pausedUntil, owner: false });', '  for (const r of rows.results) {
    // Un amigo se ve solo con el titular: en una familia ajena, ni el amigo ve al
    // resto ni el resto lo ve a el. El titular ve a todos los suyos.
    const seVen = r.ownerEmail === viewer || (miRol.get(r.ownerEmail) !== "amigo" && r.role !== "amigo");
    if (seVen && r.memberEmail && r.memberEmail !== viewer && !personas.has(r.memberEmail)) {
      personas.set(r.memberEmail, { id: r.id, email: r.memberEmail, name: r.name, role: r.role, pausedUntil: r.pausedUntil, owner: false });')
)
$descargas = @(
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/aea3fe5/scripts/mapa/panel-mapa.txt", "src\panel-mapa.txt", "6ec2b1e1fe38c518c3cdc836de67489e26a2ed16bb5a99479f14cbcd7eafc6ac"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/aea3fe5/scripts/mapa/panel-mapa.css", "src\panel-mapa.css", "fd011269cd43db70a2c078933f03e475cade2b7bd90da94a51252a5aa7acfaeb")
)

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
    if (Test-Path ($ruta + ".bak-amigo")) { Mal ("Ya existe " + $t + ".bak-amigo. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-amigo"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-amigo): " + ($respaldados -join ", "))

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
$vi = (Leer (Join-Path $raiz "src\index.ts")).texto
Chk "index.ts: familia, en vivo y mapa siguen" (((Contar $vi 'async function remoteFamily(') -eq 1) -and ((Contar $vi 'async function remoteLive') -eq 1) -and ((Contar $vi 'panel-mapa.txt') -eq 1))

if (-not $todoBien) {
    Mal "Algo no salio bien. Restauro todo desde los respaldos."
    foreach ($t in $tocados) {
        $ruta = Join-Path $raiz $t
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-amigo") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "TODO BIEN en los archivos. Falta publicar:  npx.cmd wrangler deploy"
Write-Host ""
