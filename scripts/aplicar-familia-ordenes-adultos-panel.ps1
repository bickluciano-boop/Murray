# aplicar-familia-ordenes-adultos-panel.ps1 - El titular puede hacer sonar, ubicar, pedir foto y audio y seguir en vivo el telefono de un familiar ADULTO.
# Pedido de Luciano (16/10/2026): "en Buscar aprieto hacer sonar y a ella le llega una alarma y se da cuenta que la estoy buscando; porque puedo, y es su
# telefono". Hasta ahora eso solo andaba con tus equipos y con los menores; a un adulto (por ejemplo "LB iPhone") solo se le veia la ubicacion.
#  - Quien lo puede pedir: el TITULAR de la familia. Un adulto no se lo puede pedir a otro adulto. Los amigos quedan afuera.
#  - Nunca es a escondidas: cada pedido le llega a esa persona (aviso en el telefono y, salvo "ubicar", correo) diciendo quien lo hizo, igual que con un menor.
#  - Si el adulto pauso su ubicacion, solo se le puede hacer sonar el telefono (no ubicarlo, ni seguirlo en vivo, ni pedirle foto).
#  - El texto del rol Adulto (al invitar y en el aviso que le llega a quien se pone como adulto) ahora lo dice.
# No cambia nada de tus equipos ni de los menores. Requiere los pasos de Familia (menores) ya aplicados. Va en la carpeta del PANEL (la que tiene wrangler.toml).
# Toca src\index.ts y src\panel-mapa.txt. Respaldo .bak-adultos. Al final publica el panel solo.
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
foreach ($f in @("src\index.ts", "src\panel-mapa.txt")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
$indexTexto = (Leer (Join-Path $raiz "src\index.ts")).texto
if ((Contar $indexTexto 'esAdulto: fila.role') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $indexTexto 'async function familyMinorTarget') -eq 0) { Mal "Falta aplicar antes los pasos de Familia (menores) del servidor."; return }
$cambios = @(
    @('src\index.ts', 'familia: el titular puede ordenar tambien a un adulto (lista)', '      const tutor = r.role === "menor" && (r.ownerEmail === viewer || miRol.get(r.ownerEmail) === "adulto");', '      const tutor = (r.role === "menor" && (r.ownerEmail === viewer || miRol.get(r.ownerEmail) === "adulto")) || (r.role === "adulto" && r.ownerEmail === viewer);'),
    @('src\index.ts', 'familia: telefono de un menor o de un adulto sobre el que se puede ordenar', '    "SELECT owner_email AS ownerEmail,member_email AS memberEmail,owner_name AS ownerName FROM family_members WHERE id=? AND status=''activo'' AND role=''menor''",
  ).bind(personId).first<{ ownerEmail: string; memberEmail: string | null; ownerName: string | null }>();
  if (!fila?.memberEmail || fila.memberEmail === viewer) return null;
  let quien = "";
  if (fila.ownerEmail === viewer) {
    quien = fila.ownerName || "";
  } else {', '    "SELECT owner_email AS ownerEmail,member_email AS memberEmail,owner_name AS ownerName,role,paused_until AS pausedUntil FROM family_members WHERE id=? AND status=''activo'' AND role IN (''menor'',''adulto'')",
  ).bind(personId).first<{ ownerEmail: string; memberEmail: string | null; ownerName: string | null; role: string; pausedUntil: string | null }>();
  if (!fila?.memberEmail || fila.memberEmail === viewer) return null;
  let quien = "";
  if (fila.ownerEmail === viewer) {
    quien = fila.ownerName || "";
  } else if (fila.role !== "menor") {
    // A un adulto solo se lo puede ordenar el titular de la familia.
    return null;
  } else {'),
    @('src\index.ts', 'familia: devolver si es adulto y si pauso su ubicacion', '  return { minorEmail: fila.memberEmail, device, quien: quien || viewer.split("@")[0].replace(/^./, (c) => c.toUpperCase()) };', '  return {
    minorEmail: fila.memberEmail,
    device,
    quien: quien || viewer.split("@")[0].replace(/^./, (c) => c.toUpperCase()),
    esAdulto: fila.role === "adulto",
    pausada: Boolean(fila.pausedUntil && Date.parse(fila.pausedUntil) > Date.now()),
  };'),
    @('src\index.ts', 'familia: tutor del menor o titular del adulto (consultar como va)', 'f.member_email=? AND f.status=''activo'' AND f.role=''menor'' AND (f.owner_email=? OR f.owner_email IN (SELECT owner_email FROM family_members WHERE member_email=? AND status=''activo'' AND role=''adulto'')) LIMIT 1",
  ).bind(minorEmail, viewer, viewer).first<{ ok: number }>();', 'f.member_email=? AND f.status=''activo'' AND ((f.role=''menor'' AND (f.owner_email=? OR f.owner_email IN (SELECT owner_email FROM family_members WHERE member_email=? AND status=''activo'' AND role=''adulto''))) OR (f.role=''adulto'' AND f.owner_email=?)) LIMIT 1",
  ).bind(minorEmail, viewer, viewer, viewer).first<{ ok: number }>();'),
    @('src\index.ts', 'familia: la orden a un adulto con la ubicacion pausada solo puede ser sonar', '  const target = await familyMinorTarget(env, email, String(body.personId ?? ""));
  if (!target) return json({ error: "not_allowed" }, 403);', '  const target = await familyMinorTarget(env, email, String(body.personId ?? ""));
  if (!target) return json({ error: "not_allowed" }, 403);
  // Si un adulto pauso su ubicacion, no se le puede ubicar ni pedir foto: solo hacer sonar su telefono.
  if (target.esAdulto && target.pausada && type !== "alarm" && type !== "stop-ring") return json({ error: "paused" }, 409);'),
    @('src\index.ts', 'familia: seguir en vivo a un adulto con la ubicacion pausada no se puede', '  const target = await familyMinorTarget(env, sessionInfo.email, String(body.personId ?? ""));
  if (!target) return json({ error: "not_allowed" }, 403);', '  const target = await familyMinorTarget(env, sessionInfo.email, String(body.personId ?? ""));
  if (!target) return json({ error: "not_allowed" }, 403);
  if (target.esAdulto && target.pausada && body.action !== "stop") return json({ error: "paused" }, 409);'),
    @('src\index.ts', 'familia: la foto y el audio de un adulto tambien le llegan por correo a quien los pidio', 'FROM family_members WHERE member_email=? AND status=''activo'' AND role=''menor'' ORDER BY CASE WHEN owner_email=? THEN 0 ELSE 1 END LIMIT 1")', 'FROM family_members WHERE member_email=? AND status=''activo'' AND role IN (''menor'',''adulto'') ORDER BY CASE WHEN owner_email=? THEN 0 ELSE 1 END LIMIT 1")'),
    @('src\index.ts', 'familia: el aviso al adulto dice lo que puede hacer el titular', '  return `${quien} te puso como Adulto en su familia: ves a toda la familia y pod\u00e9s pausar tu ubicaci\u00f3n.`;', '  return `${quien} te puso como Adulto en su familia: ves a toda la familia y pod\u00e9s pausar tu ubicaci\u00f3n. Como titular, ${quien} puede hacer sonar tu tel\u00e9fono para encontrarlo, ver d\u00f3nde est\u00e1s (si no pausaste tu ubicaci\u00f3n) y pedir una foto y un audio; cada vez te llega un aviso.`;'),
    @('src\panel-mapa.txt', 'panel: texto del rol Adulto', ('  adulto: ["Adulto", "Ve a toda la familia y puede pausar su ubicaci' + [char]0x00f3 + 'n."],'), ('  adulto: ["Adulto", "Ve a toda la familia y puede pausar su ubicaci' + [char]0x00f3 + 'n. Vos pod' + [char]0x00e9 + 's hacer sonar su tel' + [char]0x00e9 + 'fono; siempre le llega un aviso."],')),
    @('src\panel-mapa.txt', 'panel: aviso si el adulto pauso su ubicacion (ordenes)', '    avisar(error.status === 403', ('    avisar(error.status === 409 ? "Paus' + [char]0x00f3 + ' su ubicaci' + [char]0x00f3 + 'n: por ahora solo pod' + [char]0x00e9 + 's hacer sonar su tel' + [char]0x00e9 + 'fono." : error.status === 403')),
    @('src\panel-mapa.txt', 'panel: aviso si el adulto pauso su ubicacion (en vivo)', ('estado.mensajeVivo = error.status === 401 ? "La sesi' + [char]0x00f3 + 'n venci' + [char]0x00f3 + '. Volv' + [char]0x00e9 + ' a entrar al panel." : "No se pudo activar el seguimiento en vivo. Prob' + [char]0x00e1 + ' de nuevo.";'), ('estado.mensajeVivo = error.status === 401 ? "La sesi' + [char]0x00f3 + 'n venci' + [char]0x00f3 + '. Volv' + [char]0x00e9 + ' a entrar al panel." : error.status === 409 ? "Paus' + [char]0x00f3 + ' su ubicaci' + [char]0x00f3 + 'n: por ahora solo pod' + [char]0x00e9 + 's hacer sonar su tel' + [char]0x00e9 + 'fono." : "No se pudo activar el seguimiento en vivo. Prob' + [char]0x00e1 + ' de nuevo.";'))
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
    if (Test-Path ($ruta + ".bak-adultos")) { Mal ("Ya existe " + $t + ".bak-adultos. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-adultos"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-adultos): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-adultos") -Destination $ruta -Force }
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
Ok "LISTO: el panel quedo publicado. Cerra la app y abrila de nuevo: toca a un familiar adulto y proba Hacer sonar."
Write-Host ""
