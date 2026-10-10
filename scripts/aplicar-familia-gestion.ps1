# aplicar-familia-gestion.ps1 - Desde el mapa del panel, el titular le cambia el rol a alguien de su familia
# (adulto, menor o amigo) o lo quita. Arregla tambien la X para anular una invitacion sin usar.
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Toca src\index.ts y actualiza src\panel-mapa.txt y
# src\panel-mapa.css. Respaldos .bak-gestion; si algo falla, se restaura todo. No cambia la base de datos.
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
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'async function remoteFamilyRole') -ne 0) { Avi "Administrar la familia ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'async function remoteFamilyCommand') -eq 0) { Mal "Primero corre aplicar-familia-menores.ps1."; return }
if ((Sha (Join-Path $raiz "src\panel-mapa.txt")) -ne "a48633c49c40c5fe7424f9119e668417c6f94be9aa992b619be3b6f7310a12ed") { Mal "src\panel-mapa.txt no es la version que espero. Primero corre actualizar-mapa.ps1 y despues este."; return }
$cambios = @(
    @('src\index.ts', 'titular primero y quien puede administrar', '  type Persona = { id: string; email: string; name: string; role: string; pausedUntil: string | null; owner: boolean; tutor: boolean };
  const personas = new Map<string, Persona>();
  for (const r of rows.results) {
', '  // gestionable: `viewer` es el titular de esa fila, asi que le puede cambiar el rol o quitarla.
  type Persona = { id: string; email: string; name: string; role: string; pausedUntil: string | null; owner: boolean; tutor: boolean; gestionable: boolean };
  const personas = new Map<string, Persona>();
  // Primero las filas de la familia de `viewer`: si alguien esta en su familia y tambien en
  // otra donde `viewer` es integrante, se ve con el nombre y el rol que le puso `viewer`.
  const filas = [...rows.results].sort((a, b) => Number(b.ownerEmail === viewer) - Number(a.ownerEmail === viewer));
  for (const r of filas) {
'),
    @('src\index.ts', 'persona de la familia', 'personas.set(r.memberEmail, { id: r.id, email: r.memberEmail, name: r.name, role: r.role, pausedUntil: r.pausedUntil, owner: false, tutor });', 'personas.set(r.memberEmail, { id: r.id, email: r.memberEmail, name: r.name, role: r.role, pausedUntil: r.pausedUntil, owner: false, tutor, gestionable: r.ownerEmail === viewer });'),
    @('src\index.ts', 'titular de otra familia', 'pausedUntil: null, owner: true, tutor: false });', 'pausedUntil: null, owner: true, tutor: false, gestionable: false });'),
    @('src\index.ts', 'canManage en la respuesta', '      canCommand: p.tutor,
', '      canCommand: p.tutor,
      // El titular de la familia le puede cambiar el rol o quitarla (ver remoteFamilyRole).
      canManage: p.gestionable,
'),
    @('src\index.ts', 'cambiar el rol', 'async function nativeOwnerEmail(request: Request, env: Env, deviceId: string) {', '/** El titular le cambia el rol a alguien de su familia (adulto, menor o amigo). Quitar: remoteFamilyRemove. */
async function remoteFamilyRole(request: Request, env: Env) {
  const sessionInfo = await readSessionInfo(request, env.SESSION_SECRET);
  if (!sessionInfo) return json({ error: "unauthorized" }, 401);
  if (sessionInfo.method === "emergency") return json({ error: "not_allowed_in_emergency" }, 403);
  const body = await request.json<Record<string, unknown>>().catch(() => ({} as Record<string, unknown>));
  const role = String(body.role ?? "");
  if (!(FAMILY_ROLES as readonly string[]).includes(role)) return json({ error: "invalid_role" }, 400);
  // Un menor no puede tener la ubicacion en pausa: al pasarlo a menor, la pausa se corta.
  const updated = await env.DB.prepare("UPDATE family_members SET role=?, paused_until=CASE WHEN ?=''menor'' THEN NULL ELSE paused_until END WHERE id=? AND owner_email=? AND status=''activo''")
    .bind(role, role, String(body.id ?? ""), sessionInfo.email).run();
  return updated.meta.changes ? json({ updated: true, role }) : json({ error: "not_found" }, 404);
}

async function nativeOwnerEmail(request: Request, env: Env, deviceId: string) {'),
    @('src\index.ts', 'ruta del rol', '      if (route === "POST /api/remote/family/remove") return remoteFamilyRemove(request, env);
', '      if (route === "POST /api/remote/family/remove") return remoteFamilyRemove(request, env);
      if (route === "POST /api/remote/family/role") return remoteFamilyRole(request, env);
')
)
$descargas = @(
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/a22d62f/scripts/mapa/panel-mapa.txt", "src\panel-mapa.txt", "1447595b876bdf9e93a56e9cc5eba90e25bf071da9e17ba3b480493eb8f97e56"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/a22d62f/scripts/mapa/panel-mapa.css", "src\panel-mapa.css", "172c729c9d0f0bcb57ef2bf569e5cebce170e095ef219e1647895bc4f0cc4238")
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
    if (Test-Path ($ruta + ".bak-gestion")) { Mal ("Ya existe " + $t + ".bak-gestion. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-gestion"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-gestion): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-gestion") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "TODO BIEN en los archivos. Falta publicar:  npx.cmd wrangler deploy"
Write-Host ""
