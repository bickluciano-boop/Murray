# aplicar-familia-tope-adultos-panel.ps1 - Ojo Guard MS: tope de adultos por familia (el titular + 1 adulto, su pareja; los hijos sin tope por ahora), con un interruptor APAGADO para la beta.
# Regla de Luciano (03/11/2026): el plan lleva como maximo dos mayores y despues los hijos. Mientras se prueba con su familia (padres y hermanos) el tope NO se aplica: FAMILY_TOPE_ADULTOS_ACTIVO = false. Al lanzar se pone en true (y se agrega el texto en las pantallas: el servidor contesta 409 adult_limit).
# Cambia SOLO src\index.ts (respaldo .bak-topeadultos). Va en la carpeta del PANEL (la que tiene wrangler.toml). No cambia la app. Instalarlo hoy no cambia nada. Al final publica el panel solo.
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
if (-not (Test-Path (Join-Path $raiz "src\index.ts"))) { Mal "No encuentro src\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'FAMILY_TOPE_ADULTOS_ACTIVO') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
$cambios = @(
    @('src\index.ts', 'Familia: tope de adultos (funcion e interruptor, apagado)', 'async function remoteFamilyInvite(request: Request, env: Env) {
', '// Tope de adultos por familia: el titular mas FAMILY_MAX_ADULTOS (su pareja); los hijos no tienen tope por ahora.
// Mientras dure la beta con la familia de Luciano el tope esta APAGADO (FAMILY_TOPE_ADULTOS_ACTIVO = false). Al lanzar: ponerlo en true.
const FAMILY_TOPE_ADULTOS_ACTIVO = false;
const FAMILY_MAX_ADULTOS = 1;
/** true si el titular ya llego al tope de adultos (cuentan los activos y las invitaciones vigentes; `excluirId` es la fila que se esta cambiando). */
async function familyTopeAdultos(env: Env, owner: string, excluirId = "") {
  if (!FAMILY_TOPE_ADULTOS_ACTIVO) return false;
  const fila = await env.DB.prepare("SELECT COUNT(*) AS n FROM family_members WHERE owner_email=? AND role=''adulto'' AND id<>? AND (status=''activo'' OR (status=''invitado'' AND invite_expires_at>?))")
    .bind(owner, excluirId, now()).first<{ n: number }>();
  return Number(fila?.n ?? 0) >= FAMILY_MAX_ADULTOS;
}

async function remoteFamilyInvite(request: Request, env: Env) {
'),
    @('src\index.ts', 'Familia: tope al invitar un adulto', '  if (!name || !(FAMILY_ROLES as readonly string[]).includes(role)) return json({ error: "invalid_invite" }, 400);
', '  if (!name || !(FAMILY_ROLES as readonly string[]).includes(role)) return json({ error: "invalid_invite" }, 400);
  if (role === "adulto" && await familyTopeAdultos(env, sessionInfo.email)) return json({ error: "adult_limit", max: FAMILY_MAX_ADULTOS }, 409);
'),
    @('src\index.ts', 'Familia: tope al cambiarle el rol a adulto', '  if (!(FAMILY_ROLES as readonly string[]).includes(role)) return json({ error: "invalid_role" }, 400);
', '  if (!(FAMILY_ROLES as readonly string[]).includes(role)) return json({ error: "invalid_role" }, 400);
  if (role === "adulto" && await familyTopeAdultos(env, sessionInfo.email, String(body.id ?? ""))) return json({ error: "adult_limit", max: FAMILY_MAX_ADULTOS }, 409);
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
    if (Test-Path ($ruta + ".bak-topeadultos")) { Mal ("Ya existe " + $t + ".bak-topeadultos. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-topeadultos"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-topeadultos): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-topeadultos") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "Archivos listos. Ahora publico el panel..."
& npx.cmd wrangler deploy
if ($LASTEXITCODE -ne 0) { Mal "No se pudo publicar el panel. Mandame esta pantalla."; return }
Write-Host ""
Ok "LISTO: el tope de adultos por familia quedo instalado y APAGADO (beta)."
Write-Host ""
