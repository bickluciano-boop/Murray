# aplicar-familia-avisos.ps1 - Familia, menores: "Ubicar ahora" le avisa al menor en silencio y sin correo
# ("Luciano vio donde estas"). "Hacer sonar" y "Seguir en vivo" siguen avisando con sonido y correo. Los avisos de familia
# dejan de empezar con "Ojo Guard -" (el titulo se cortaba). Va en la carpeta del PANEL (la que tiene wrangler.toml).
# Toca solo src\index.ts. Respaldo .bak-avisos; si algo falla, se restaura.
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
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'silencioso?: boolean') -ne 0) { Avi "Los avisos silenciosos ya estaban aplicados. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'async function remoteFamilyCommand') -eq 0) { Mal "Primero corre aplicar-familia-menores.ps1."; return }
$cambios = @(
    @('src\index.ts', 'avisos: texto y silencio', '
function familyMinorNotice(type: CommandType | "live", quien: string): [string, string] {
  if (type === "locate") return ["Ojo Guard \u2014 Pidieron tu ubicaci\u00f3n", `${quien} pidi\u00f3 tu ubicaci\u00f3n desde Ojo Guard MS.`];
  if (type === "alarm") return ["Ojo Guard \u2014 Buscando este tel\u00e9fono", `${quien} hizo sonar tu tel\u00e9fono para encontrarlo.`];
  if (type === "stop-ring") return ["Ojo Guard \u2014 Sonido detenido", `${quien} detuvo el sonido.`];
  return ["Ojo Guard \u2014 Ubicaci\u00f3n en vivo", `${quien} est\u00e1 viendo tu ubicaci\u00f3n en vivo.`];
}', '
// Que ve el menor en su telefono (titulo y texto), el asunto del correo a su cuenta
// (null: sin correo) y si el aviso llega en silencio. "Ubicar ahora" avisa igual, pero
// sin sonido ni correo (decision de Lu, 09/10/2026): se entera si mira el telefono y
// no lo interrumpe. Hacer sonar si suena: la idea es justamente que lo note.
function familyMinorNotice(type: CommandType | "live", quien: string): { titulo: string; texto: string; asunto: string | null; silencioso: boolean } {
  if (type === "locate") return { titulo: "Ojo Guard", texto: `${quien} vio d\u00f3nde est\u00e1s.`, asunto: null, silencioso: true };
  if (type === "alarm") return { titulo: "Ojo Guard", texto: `${quien} hizo sonar tu tel\u00e9fono para encontrarlo.`, asunto: "Hicieron sonar tu tel\u00e9fono", silencioso: false };
  if (type === "stop-ring") return { titulo: "Ojo Guard", texto: `${quien} detuvo el sonido.`, asunto: null, silencioso: true };
  return { titulo: "Ojo Guard", texto: `${quien} est\u00e1 viendo tu ubicaci\u00f3n en vivo.`, asunto: "Ubicaci\u00f3n en vivo", silencioso: false };
}'),
    @('src\index.ts', 'avisos: ubicar sin correo', '    .bind(id, target.device.id, target.minorEmail, type, "pending", createdAt, plusMinutes(60)).run();
  const [titulo, detalle] = familyMinorNotice(type, target.quien);
  const pushSent = await sendExpoCommandPush(target.device.pushToken, type, id, target.device.name, { title: titulo, body: detalle }).catch(() => false);
  await sendSecurityNotice(env, target.minorEmail, titulo.replace(/^Ojo Guard \u2014 /, ""), detalle, target.device.name);
  return json({ queued: true, commandId: id, status: "pending", pushSent }, 202);', '    .bind(id, target.device.id, target.minorEmail, type, "pending", createdAt, plusMinutes(60)).run();
  const aviso = familyMinorNotice(type, target.quien);
  const pushSent = await sendExpoCommandPush(target.device.pushToken, type, id, target.device.name, { title: aviso.titulo, body: aviso.texto, silencioso: aviso.silencioso }).catch(() => false);
  if (aviso.asunto) await sendSecurityNotice(env, target.minorEmail, aviso.asunto, aviso.texto, target.device.name);
  return json({ queued: true, commandId: id, status: "pending", pushSent }, 202);'),
    @('src\index.ts', 'avisos: en vivo', '    .bind(id, deviceId, target.minorEmail, "live", "pending", ahora, until).run();
  const [titulo, detalle] = familyMinorNotice("live", target.quien);
  const pushSent = await sendExpoCommandPush(target.device.pushToken, "live", id, target.device.name, { title: titulo, body: detalle }).catch(() => false);
  await sendSecurityNotice(env, target.minorEmail, titulo.replace(/^Ojo Guard \u2014 /, ""), detalle, target.device.name);
  return json({ live: true, until, commandId: id, status: "pending", pushSent }, 202);', '    .bind(id, deviceId, target.minorEmail, "live", "pending", ahora, until).run();
  const aviso = familyMinorNotice("live", target.quien);
  const pushSent = await sendExpoCommandPush(target.device.pushToken, "live", id, target.device.name, { title: aviso.titulo, body: aviso.texto, silencioso: aviso.silencioso }).catch(() => false);
  if (aviso.asunto) await sendSecurityNotice(env, target.minorEmail, aviso.asunto, aviso.texto, target.device.name);
  return json({ live: true, until, commandId: id, status: "pending", pushSent }, 202);'),
    @('src\index.ts', 'push: aviso silencioso (1)', '  aviso?: { title: string; body: string },
) {', '  aviso?: { title: string; body: string; silencioso?: boolean },
) {'),
    @('src\index.ts', 'push: aviso silencioso (2)', '      title: aviso?.title ?? message.title,
      body: aviso?.body ?? message.body,
      sound: "default",
      priority: "high",
      ttl: 600,
      channelId: "ojo-busqueda-v2",', '      title: aviso?.title ?? message.title,
      body: aviso?.body ?? message.body,
      // Silencioso (Familia: "Ubicar ahora" a un menor): sin sonido. En Android va por un
      // canal propio sin sonido; mientras la app no lo cree, Android usa su canal general.
      sound: aviso?.silencioso ? undefined : "default",
      priority: "high",
      ttl: 600,
      channelId: aviso?.silencioso ? "ojo-familia-aviso" : "ojo-busqueda-v2",')
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
    if (Test-Path ($ruta + ".bak-avisos")) { Mal ("Ya existe " + $t + ".bak-avisos. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-avisos"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-avisos): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-avisos") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "TODO BIEN en los archivos. Falta publicar:  npx.cmd wrangler deploy"
Write-Host ""
