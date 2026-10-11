# aplicar-prueba-aviso-android.ps1 - Diagnostico: una pagina que manda 3 avisos de prueba a tus celulares (cada uno por un
# canal distinto) y muestra lo que contesta el servicio de avisos. Sirve para saber por que el aviso "salio de Casa" no le
# llega al Android. No cambia nada del funcionamiento: solo suma una direccion nueva, que ademas pide estar con sesion iniciada.
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Toca src\index.ts. Respaldo .bak-pruebapush.
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
$indexTexto = (Leer (Join-Path $raiz "src\index.ts")).texto
if ((Contar $indexTexto 'async function remotePushTest') -ne 0) { Avi "La prueba ya estaba aplicada. No toco nada."; return }
if ((Contar $indexTexto 'async function remoteFamilyAlerts') -eq 0) { Mal "Primero corre aplicar-familia-avisos-persona.ps1."; return }
$cambios = @(
    @('src\index.ts', 'prueba de avisos al celular', '/** Pagina que abre el link de invitacion (WhatsApp, mail): muestra el codigo y como usarlo. */
', '/**
 * Diagnostico: manda tres avisos de prueba a los celulares de quien lo pide, cada uno por un canal
 * distinto (A: sin canal, B: "ojo-busqueda-v2", C: "ojo-alertas"), y devuelve lo que contesto Expo.
 * Sirve para ver cual de los tres le llega al Android. Solo con sesion, solo a tus propios equipos.
 */
async function remotePushTest(request: Request, env: Env) {
  const sessionInfo = await readSessionInfo(request, env.SESSION_SECRET);
  if (!sessionInfo) return json({ error: "unauthorized" }, 401);
  if (sessionInfo.method === "emergency") return json({ error: "not_allowed_in_emergency" }, 403);
  const tokens = await pushTokensOf(env, sessionInfo.email);
  const pruebas: { clave: string; canal: string | null }[] = [
    { clave: "A", canal: null },
    { clave: "B", canal: "ojo-busqueda-v2" },
    { clave: "C", canal: "ojo-alertas" },
  ];
  const resultados: Record<string, unknown>[] = [];
  for (const token of tokens) {
    for (const p of pruebas) {
      const mensaje = { to: token, title: `Prueba ${p.clave} de Ojo Guard`, body: p.canal ? `Canal: ${p.canal}` : "Sin canal (como salen los avisos hoy)", sound: "default", priority: "high", ttl: 600, ...(p.canal ? { channelId: p.canal } : {}), data: {} };
      try {
        const respuesta = await fetch("https://exp.host/--/api/v2/push/send", {
          method: "POST",
          headers: { "content-type": "application/json", accept: "application/json" },
          body: JSON.stringify([mensaje]),
        });
        resultados.push({ prueba: p.clave, canal: p.canal, http: respuesta.status, expo: await respuesta.json().catch(() => null) });
      } catch (error) {
        resultados.push({ prueba: p.clave, canal: p.canal, error: String(error) });
      }
    }
  }
  return json({ celulares: tokens.length, resultados });
}

/** Pagina que abre el link de invitacion (WhatsApp, mail): muestra el codigo y como usarlo. */
'),
    @('src\index.ts', 'ruta de la prueba', '      if (route === "GET /api/remote/family/alerts" || route === "POST /api/remote/family/alerts") return remoteFamilyAlerts(request, env);
', '      if (route === "GET /api/remote/family/alerts" || route === "POST /api/remote/family/alerts") return remoteFamilyAlerts(request, env);
      if (route === "GET /api/remote/push-test") return remotePushTest(request, env);
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
    if (Test-Path ($ruta + ".bak-pruebapush")) { Mal ("Ya existe " + $t + ".bak-pruebapush. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-pruebapush"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-pruebapush): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-pruebapush") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "TODO BIEN en los archivos. Falta un paso: npx.cmd wrangler deploy"
Write-Host "Despues abri en el navegador (con la sesion del panel iniciada): https://ojo-guard-ms-api.bickluciano.workers.dev/api/remote/push-test"
Write-Host ""
