# Genera scripts/aplicar-contornos-panel.ps1: el panel consulta los contornos de edificios de OpenStreetMap (Overpass) y los guarda en cache,
# para que el visor de prueba con Google 3D (scripts/rvi/visor-3d-real.html) no dependa del servicio publico saturado.
# Solo agrega una ruta nueva GET /api/rvi/buildings (con codigo propio RVI_TOKEN). No toca nada de lo existente. Sin base de datos nueva: usa la cache del Worker.
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-raiz-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')


def psq(s):
    return "'" + s.replace("'", "''") + "'"


A_FN = 'async function deviceLocationHistory(request: Request, env: Env, url: URL) {\n'
N_FN = '''// Contornos de edificios para el visor de prueba con Google 3D. Consulta OpenStreetMap (Overpass) una sola vez por zona de ~100 m y guarda la respuesta 30 dias en la cache del Worker:
// asi el visor no depende de que el servicio publico este libre. Pide el codigo propio RVI_TOKEN (secreto, no es la clave de Google). No guarda nada de nadie: solo formas de edificios.
const RVI_SERVIDORES = ["https://overpass-api.de/api/interpreter", "https://overpass.private.coffee/api/interpreter", "https://overpass.kumi.systems/api/interpreter"];
function rviRespuesta(cuerpo: unknown, status: number, extra: Record<string, string> = {}) {
  return new Response(JSON.stringify(cuerpo), { status, headers: { "content-type": "application/json; charset=utf-8", "access-control-allow-origin": "*", "cache-control": "no-store", ...extra } });
}
async function rviContornos(request: Request, env: Env, url: URL) {
  const secreto = String((env as unknown as { RVI_TOKEN?: string }).RVI_TOKEN ?? "");
  if (secreto.length < 16) return rviRespuesta({ error: "not_configured" }, 404);
  const dado = String(url.searchParams.get("k") ?? "");
  let dif = secreto.length ^ dado.length;
  for (let i = 0; i < secreto.length; i++) dif |= secreto.charCodeAt(i) ^ (dado.charCodeAt(i) || 0);
  if (dif !== 0) return rviRespuesta({ error: "forbidden" }, 403);
  const lat = Number(url.searchParams.get("lat")), lon = Number(url.searchParams.get("lon"));
  if (!Number.isFinite(lat) || !Number.isFinite(lon) || lat < -56 || lat > -21 || lon < -74 || lon > -53) return rviRespuesta({ error: "out_of_range" }, 400);
  const la = Math.round(lat * 1000) / 1000, lo = Math.round(lon * 1000) / 1000;
  const llave = new Request("https://cache.ojoguard.app/rvi/contornos?lat=" + la + "&lon=" + lo);
  const cache = (caches as unknown as { default: Cache }).default;
  const guardado = await cache.match(llave);
  if (guardado) return rviRespuesta(await guardado.json(), 200, { "x-rvi-cache": "hit" });
  const consulta = "[out:json][timeout:20];way[\\"building\\"](around:130," + la + "," + lo + ");out tags geom;";
  const motivos: string[] = [];
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
      const cuerpo = { elements };
      await cache.put(llave, new Response(JSON.stringify(cuerpo), { headers: { "content-type": "application/json", "cache-control": "public, max-age=2592000" } }));
      return rviRespuesta(cuerpo, 200, { "x-rvi-cache": "miss" });
    } catch (e) { motivos.push(host + (e instanceof Error && e.name === "AbortError" ? " tardo demasiado" : " no respondio")); }
  }
  return rviRespuesta({ error: "overpass_busy", detail: motivos.join("; ") }, 503);
}

''' + A_FN

A_RUTA = '      if (route === "GET /api/remote/location-history") return deviceLocationHistory(request, env, url);\n'
N_RUTA = A_RUTA + '      if (route === "GET /api/rvi/buildings") return rviContornos(request, env, url);\n'

filas = [('src\\index.ts', 'contornos: funcion que consulta y guarda en cache', A_FN, N_FN),
         ('src\\index.ts', 'contornos: ruta GET /api/rvi/buildings', A_RUTA, N_RUTA)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"

cabeza = '''# aplicar-contornos-panel.ps1 - Ojo Guard MS (panel): ruta GET /api/rvi/buildings que consulta los contornos de edificios de OpenStreetMap y los guarda en cache 30 dias.
# Para que el visor de prueba con Google 3D (visor-3d-real.html) no dependa del servicio publico de OpenStreetMap, que a veces esta saturado.
#  - Solo agrega una ruta nueva. No toca el mapa, los pines, los equipos ni nada de lo existente. No guarda datos de nadie: solo formas de edificios.
#  - Pide un codigo propio (secreto RVI_TOKEN) que este instalador inventa al azar, guarda en el panel y deja COPIADO en el portapapeles (no se muestra). Se pega en el visor.
#  - Cambia SOLO src\\index.ts (respaldo .bak-contornos). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final carga el secreto y publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\index.ts"))) { Mal "No encuentro src\\index.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'async function rviContornos') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-raiz', '.bak-contornos')
viejo = '& npx.cmd wrangler deploy\n'
assert cola.count(viejo) == 1
nuevo = '''Write-Host "Creando el codigo propio del visor (secreto RVI_TOKEN)..."
$bytesRvi = New-Object byte[] 24
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create(); $rng.GetBytes($bytesRvi); $rng.Dispose()
$codigoRvi = ([System.BitConverter]::ToString($bytesRvi)).Replace("-", "").ToLower()
$salidaSecreto = ($codigoRvi | & npx.cmd wrangler secret put RVI_TOKEN 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0) {
    Write-Host $salidaSecreto
    foreach ($t in $tocados) { $ruta = Join-Path $raiz $t; if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-contornos") -Destination $ruta -Force } }
    Mal "No se pudo guardar el secreto. Deje todo como estaba. Mandame esta pantalla."; return
}
Ok "Secreto guardado"
& npx.cmd wrangler deploy
'''
cola = cola.replace(viejo, nuevo)
cola = re.sub(r'Ok "LISTO: el panel se abre en.*"\n', '''try { Set-Clipboard -Value $codigoRvi } catch { }
Write-Host ""
Write-Host "Probando la ruta nueva (sin mostrar el codigo)..."
$estadoRvi = "sin respuesta"
for ($intento = 1; $intento -le 4; $intento++) {
    try {
        $resp = Invoke-WebRequest -UseBasicParsing -TimeoutSec 40 -Uri ("https://ojoguard.app/api/rvi/buildings?lat=-34.6037&lon=-58.3816&k=" + $codigoRvi)
        $estadoRvi = "HTTP " + $resp.StatusCode + " (cache: " + $resp.Headers["x-rvi-cache"] + ")"; break
    } catch {
        $codigoHttp = ""; try { $codigoHttp = [int]$_.Exception.Response.StatusCode } catch { }
        $estadoRvi = "HTTP " + $codigoHttp; if ($codigoHttp -eq 403 -or $codigoHttp -eq 404) { break }
        Start-Sleep -Seconds 5
    }
}
Write-Host ("      Prueba de la ruta: " + $estadoRvi)
Ok "LISTO: el panel ya tiene la ruta de contornos."
Write-Host "      El codigo del visor quedo COPIADO en el portapapeles (no se muestra aca)." -ForegroundColor Cyan
Write-Host "      Abri el visor nuevo y pegalo en el campo 'Codigo del panel'. No me lo mandes por el chat." -ForegroundColor Yellow
''', cola)
assert 'bak-raiz' not in cola and 'secret put RVI_TOKEN' in cola and 'Set-Clipboard' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕‹›±']
assert not bad, set(bad)
open(R + 'aplicar-contornos-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))

# --- prueba: el codigo del Worker se extrae y se ejecuta en node con Overpass y la cache simulados
open('/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/rvi_worker.ts.txt', 'w', encoding='utf-8').write(N_FN[:-len(A_FN)])
print('ok', len(total))
