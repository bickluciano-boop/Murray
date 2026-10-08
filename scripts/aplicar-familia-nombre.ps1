# aplicar-familia-nombre.ps1 - Familia: el titular elige con que nombre lo ven ("Papa", "Luciano") al invitar,
# en lugar del nombre de su correo. Va en la carpeta del PANEL (la que tiene wrangler.toml).
# Toca src\index.ts y actualiza el mapa (src\panel-mapa.txt y .css). Respaldos .bak-nombre; si algo falla, se restaura todo.
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
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'async function remoteFamily(') -eq 0) { Mal "Falta Familia en el servidor: primero corre aplicar-familia-panel.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'f.owner_name AS ownerName') -ne 0) { Avi "El nombre del titular ya estaba aplicado. No toco nada."; return }
$cambios = @(
    @('src\index.ts', 'familia: leer el nombre elegido', '  const rows = await env.DB.prepare(
    "SELECT f.id,f.owner_email AS ownerEmail,f.member_email AS memberEmail,f.name,f.role,f.paused_until AS pausedUntil FROM family_members f WHERE f.status=''activo'' AND (f.owner_email=? OR f.owner_email IN (SELECT owner_email FROM family_members WHERE member_email=? AND status=''activo''))",
  ).bind(viewer, viewer).all<{ id: string; ownerEmail: string; memberEmail: string; name: string; role: string; pausedUntil: string | null }>();
  type Persona = { id: string; email: string; name: string; role: string; pausedUntil: string | null; owner: boolean };', '  const rows = await env.DB.prepare(
    "SELECT f.id,f.owner_email AS ownerEmail,f.member_email AS memberEmail,f.name,f.role,f.paused_until AS pausedUntil,f.owner_name AS ownerName FROM family_members f WHERE f.status=''activo'' AND (f.owner_email=? OR f.owner_email IN (SELECT owner_email FROM family_members WHERE member_email=? AND status=''activo''))",
  ).bind(viewer, viewer).all<{ id: string; ownerEmail: string; memberEmail: string; name: string; role: string; pausedUntil: string | null; ownerName: string | null }>();
  // Como ve `viewer` a cada titular: el nombre que ese titular eligio al invitarlo
  // ("Papa", "Luciano"). Sale de la fila de la invitacion de `viewer`.
  const nombreDelTitular = new Map<string, string>();
  for (const r of rows.results) {
    if (r.memberEmail === viewer && r.ownerName) nombreDelTitular.set(r.ownerEmail, r.ownerName);
  }
  type Persona = { id: string; email: string; name: string; role: string; pausedUntil: string | null; owner: boolean };'),
    @('src\index.ts', 'familia: usarlo para el titular', '    if (r.ownerEmail !== viewer && !personas.has(r.ownerEmail)) {
      // El titular de una familia ajena: se muestra con el nombre de su equipo principal.
      personas.set(r.ownerEmail, { id: `titular:${r.ownerEmail}`, email: r.ownerEmail, name: "", role: "adulto", pausedUntil: null, owner: true });
    }', '    if (r.ownerEmail !== viewer && !personas.has(r.ownerEmail)) {
      // El titular de una familia ajena: con el nombre que eligio al invitar (si no puso
      // ninguno, mas abajo se usa el de su correo).
      personas.set(r.ownerEmail, { id: `titular:${r.ownerEmail}`, email: r.ownerEmail, name: nombreDelTitular.get(r.ownerEmail) ?? "", role: "adulto", pausedUntil: null, owner: true });
    }'),
    @('src\index.ts', 'familia: comentario del nombre por correo', '      id: p.id,
      // Al titular de otra familia no le pusieron nombre: se usa el de su correo ("lubick").
      name: p.name || (p.owner ? p.email.split("@")[0].replace(/^./, (c) => c.toUpperCase()) : device?.name || p.email.split("@")[0]),', '      id: p.id,
      // Si el titular no eligio como lo ven, se usa el de su correo ("Bickluciano").
      name: p.name || (p.owner ? p.email.split("@")[0].replace(/^./, (c) => c.toUpperCase()) : device?.name || p.email.split("@")[0]),'),
    @('src\index.ts', 'familia: buscar el ultimo nombre usado', '  ).bind(email, now()).all<{ id: string; name: string; role: string; code: string; expiresAt: string }>();
  return json({', '  ).bind(email, now()).all<{ id: string; name: string; role: string; code: string; expiresAt: string }>();
  // El ultimo "como te ve" que uso el titular, para completar solo el dialogo de invitar.
  const ultimo = await env.DB.prepare(
    "SELECT owner_name AS ownerName FROM family_members WHERE owner_email=? AND owner_name IS NOT NULL AND owner_name<>'''' ORDER BY created_at DESC LIMIT 1",
  ).bind(email).first<{ ownerName: string }>();
  return json({'),
    @('src\index.ts', 'familia: devolverlo al panel', '    invites: invites.results.map((i) => ({ ...i, link: familyInviteUrl(env, i.code) })),
  });', '    invites: invites.results.map((i) => ({ ...i, link: familyInviteUrl(env, i.code) })),
    ownerName: ultimo?.ownerName ?? "",
  });'),
    @('src\index.ts', 'familia: leer el nombre al invitar', '  const role = String(body.role ?? "");
  if (!name || !(FAMILY_ROLES as readonly string[]).includes(role)) return json({ error: "invalid_invite" }, 400);', '  const role = String(body.role ?? "");
  // Como va a ver al titular la persona invitada ("Papa", "Luciano"). Columna owner_name,
  // agregada a mano el 08/10/2026 con ALTER TABLE family_members ADD COLUMN owner_name TEXT.
  const ownerName = String(body.ownerName ?? "").trim().slice(0, 40);
  if (!name || !(FAMILY_ROLES as readonly string[]).includes(role)) return json({ error: "invalid_invite" }, 400);'),
    @('src\index.ts', 'familia: guardar el nombre al invitar', '    try {
      await env.DB.prepare("INSERT INTO family_members (id,owner_email,name,role,status,invite_code,invite_expires_at,created_at) VALUES (?,?,?,?,?,?,?,?)")
        .bind(id, sessionInfo.email, name, role, "invitado", code, expiresAt, now()).run();
      return json({ id, name, role, code, expiresAt, link: familyInviteUrl(env, code) }, 201);
    } catch (error) {', '    try {
      await env.DB.prepare("INSERT INTO family_members (id,owner_email,name,role,status,invite_code,invite_expires_at,created_at,owner_name) VALUES (?,?,?,?,?,?,?,?,?)")
        .bind(id, sessionInfo.email, name, role, "invitado", code, expiresAt, now(), ownerName || null).run();
      return json({ id, name, role, code, expiresAt, ownerName, link: familyInviteUrl(env, code) }, 201);
    } catch (error) {')
)
$descargas = @(
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/0b541ea/scripts/mapa/panel-mapa.txt", "src\panel-mapa.txt", "e3a76025d8e7087a746083854b9eca3772ebe8ee58826af8502b4ceaa51eb5cf"),
    @("https://raw.githubusercontent.com/bickluciano-boop/Murray/0b541ea/scripts/mapa/panel-mapa.css", "src\panel-mapa.css", "fd011269cd43db70a2c078933f03e475cade2b7bd90da94a51252a5aa7acfaeb")
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
    if (Test-Path ($ruta + ".bak-nombre")) { Mal ("Ya existe " + $t + ".bak-nombre. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-nombre"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-nombre): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-nombre") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "TODO BIEN en los archivos. Faltan 2 pasos, EN ESTE ORDEN:"
Write-Host "   1) Agregar el dato a la base (y ponerte 'Luciano' en la invitacion que ya existe):"
Write-Host "      npx.cmd wrangler d1 execute ojo-guard-ms --remote --command ""ALTER TABLE family_members ADD COLUMN owner_name TEXT; UPDATE family_members SET owner_name = 'Luciano' WHERE owner_email LIKE 'bickluciano@%'"""
Write-Host "   2) Publicar:  npx.cmd wrangler deploy"
Write-Host ""
