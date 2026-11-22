# aplicar-contornos3-panel.ps1 - Ojo Guard MS (panel): la ruta de contornos de edificios (GET /api/rvi/buildings) consulta VARIOS servidores de OpenStreetMap a la vez y usa el primero que responde bien.
# El servidor principal estaba caido (521) y los otros tardaban; en fila se agotaba el tiempo. Ahora son 5 servidores en paralelo con 22 s cada uno; lo conseguido sigue guardandose 30 dias.
# Requiere aplicar-contornos-panel.ps1 y aplicar-contornos2-panel.ps1. No toca el codigo RVI_TOKEN. Cambia SOLO src\index.ts (respaldo .bak-contornos3). Va en la carpeta del PANEL. Al final publica el panel solo.
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
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'rvi/contornos2') -eq 0) { Mal "Falta aplicar primero aplicar-contornos-panel.ps1 y aplicar-contornos2-panel.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'const pedirA = async') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
$cambios = @(
    @('src\index.ts', 'contornos: mas servidores de respaldo', 'const RVI_SERVIDORES = ["https://overpass-api.de/api/interpreter", "https://overpass.private.coffee/api/interpreter", "https://overpass.kumi.systems/api/interpreter"];', 'const RVI_SERVIDORES = ["https://overpass-api.de/api/interpreter", "https://lz4.overpass-api.de/api/interpreter", "https://z.overpass-api.de/api/interpreter", "https://overpass.private.coffee/api/interpreter", "https://overpass.kumi.systems/api/interpreter"];'),
    @('src\index.ts', 'contornos: consulta a todos los servidores a la vez', '  const motivos: string[] = [];
  for (const servidor of RVI_SERVIDORES) {
    const host = servidor.split("/")[2];
    try {
      const ctl = new AbortController();
      const reloj = setTimeout(() => ctl.abort(), 14000);
      const r = await fetch(servidor, { method: "POST", headers: { "content-type": "application/x-www-form-urlencoded", "user-agent": "OjoGuardPanel/1.0 (contornos de edificios, uso interno)" }, body: "data=" + encodeURIComponent(consulta), signal: ctl.signal });
      clearTimeout(reloj);
      if (!r.ok) { motivos.push(host + " " + r.status); continue; }
      const datos = await r.json<{ elements?: Array<{ id?: number; tags?: Record<string, string>; geometry?: Array<{ lat: number; lon: number }> }> }>();
      const permitidos = ["building", "building:levels", "height", "name", "addr:housename"];
      const elements = (datos.elements ?? []).filter((e) => e.geometry && e.geometry.length >= 3).map((e) => ({
        id: e.id,
        tags: Object.fromEntries(Object.entries(e.tags ?? {}).filter(([k]) => permitidos.includes(k))),
        geometry: e.geometry,
      }));
      // Overpass sobrecargado contesta 200 con la lista vacia y un "remark": eso NO es una respuesta valida y no se guarda.
      const aviso = (datos as unknown as { remark?: string }).remark;
      if (aviso || elements.length === 0) { motivos.push(host + (aviso ? " con aviso: " + String(aviso).slice(0, 80) : " sin edificios")); continue; }
      const cuerpo = { elements };
      await cache.put(llave, new Response(JSON.stringify(cuerpo), { headers: { "content-type": "application/json", "cache-control": "public, max-age=2592000" } }));
      return rviRespuesta(cuerpo, 200, { "x-rvi-cache": "miss" });
    } catch (e) { motivos.push(host + (e instanceof Error && e.name === "AbortError" ? " tardo demasiado" : " no respondio")); }
  }
  return rviRespuesta({ error: "overpass_busy", detail: motivos.join("; ") }, 503);', '  // Se consulta a TODOS los servidores a la vez y gana el primero que devuelve edificios (los publicos se caen o se saturan por turnos). Una respuesta vacia o con aviso cuenta como fallo.
  const pedirA = async (servidor: string) => {
    const host = servidor.split("/")[2];
    const ctl = new AbortController();
    const reloj = setTimeout(() => ctl.abort(), 22000);
    try {
      const r = await fetch(servidor, { method: "POST", headers: { "content-type": "application/x-www-form-urlencoded", "user-agent": "OjoGuardPanel/1.0 (contornos de edificios, uso interno)" }, body: "data=" + encodeURIComponent(consulta), signal: ctl.signal });
      if (!r.ok) throw new Error(host + " " + r.status);
      const datos = await r.json<{ remark?: string; elements?: Array<{ id?: number; tags?: Record<string, string>; geometry?: Array<{ lat: number; lon: number }> }> }>();
      const permitidos = ["building", "building:levels", "height", "name", "addr:housename"];
      const elements = (datos.elements ?? []).filter((e) => e.geometry && e.geometry.length >= 3).map((e) => ({
        id: e.id,
        tags: Object.fromEntries(Object.entries(e.tags ?? {}).filter(([k]) => permitidos.includes(k))),
        geometry: e.geometry,
      }));
      if (datos.remark || elements.length === 0) throw new Error(host + (datos.remark ? " con aviso: " + String(datos.remark).slice(0, 80) : " sin edificios"));
      return elements;
    } catch (e) {
      throw new Error(e instanceof Error && e.name === "AbortError" ? host + " tardo demasiado" : e instanceof Error && e.message.startsWith(host) ? e.message : host + " no respondio");
    } finally {
      clearTimeout(reloj);
    }
  };
  const motivos: string[] = [];
  const ganador = await new Promise<Array<unknown> | null>((resolver) => {
    let pendientes = RVI_SERVIDORES.length;
    for (const servidor of RVI_SERVIDORES) {
      pedirA(servidor).then(
        (elements) => resolver(elements),
        (e) => { motivos.push(e instanceof Error ? e.message : String(e)); pendientes -= 1; if (pendientes === 0) resolver(null); },
      );
    }
  });
  if (ganador) {
    const cuerpo = { elements: ganador };
    await cache.put(llave, new Response(JSON.stringify(cuerpo), { headers: { "content-type": "application/json", "cache-control": "public, max-age=2592000" } }));
    return rviRespuesta(cuerpo, 200, { "x-rvi-cache": "miss" });
  }
  return rviRespuesta({ error: "overpass_busy", detail: motivos.join("; ") }, 503);')
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
    if (Test-Path ($ruta + ".bak-contornos3")) { Mal ("Ya existe " + $t + ".bak-contornos3. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-contornos3"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-contornos3): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-contornos3") -Destination $ruta -Force }
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
Ok "LISTO: el panel ahora prueba 5 servidores de OpenStreetMap a la vez. Abri el visor y toca Buscar el edificio de nuevo."
Write-Host ""
