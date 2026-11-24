# aplicar-contornos4-panel.ps1 - Ojo Guard MS (panel): la ruta de contornos (GET /api/rvi/buildings) suma Overture Maps como una fuente mas, en carrera con los 5 servidores de OpenStreetMap.
# Overture publica los edificios (OpenStreetMap + Google Open Buildings + Microsoft) como un archivo PMTiles; el panel lee solo la tesela que necesita (rango de bytes, nunca el archivo entero de ~180 GB).
# La respuesta ahora trae "fuente" y cada edificio "src" (de quien salio el contorno). Los de Google/Microsoft son estimados por computadora y pueden venir corridos.
# Requiere aplicar-contornos-panel / 2 / 3. No toca el codigo RVI_TOKEN. Cambia SOLO src\index.ts (respaldo .bak-contornos4). Va en la carpeta del PANEL. Al final publica el panel solo.
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
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'const pedirA = async') -eq 0) { Mal "Falta aplicar primero aplicar-contornos-panel, contornos2 y contornos3."; return }
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'async function rviOverture') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
$cambios = @(
    @('src\index.ts', 'contornos: lector de Overture Maps', 'async function rviContornos(request: Request, env: Env, url: URL) {
', '// Lector de Overture Maps (edificios) por rango de bytes sobre un archivo PMTiles v3 (sin dependencias). Lo usa rviContornos como un servidor mas de la carrera.
// El archivo pesa ~180 GB: NUNCA se pide entero (si el servidor contesta 200 en vez de 206 se corta). Se leen la cabecera, el directorio y UNA tesela z14 (y vecinas si el punto esta cerca del borde).
// Atribucion: cada edificio trae `src` (OpenStreetMap, Google Open Buildings, Microsoft ML Buildings, Esri Community Maps...). Los de Google y Microsoft son estimados por computadora.
const OVT_BASE = "https://overturemaps-extras-us-west-2.s3.us-west-2.amazonaws.com/tiles/";
const OVT_STAC = "https://stac.overturemaps.org/catalog.json";
const OVT_FIJAS = ["2026-11-18.0", "2026-10-21.0"];
const OVT_Z = 14;
type OvtEntrada = { id: number; off: number; len: number; run: number };
type OvtAbierto = { rootOff: number; dataOff: number; leafOff: number; compInt: number; compTile: number; raiz: OvtEntrada[] };

async function ovtGunzip(datos: Uint8Array): Promise<Uint8Array> {
  const flujo = new Blob([datos]).stream().pipeThrough(new DecompressionStream("gzip"));
  return new Uint8Array(await new Response(flujo).arrayBuffer());
}
async function ovtRango(url: string, desde: number, largo: number): Promise<Uint8Array> {
  const r = await fetch(url, { headers: { range: "bytes=" + desde + "-" + (desde + largo - 1) }, signal: AbortSignal.timeout(15000) });
  if (r.status !== 206) {
    try { await r.body?.cancel(); } catch { /* nada */ }
    throw new Error("overture " + r.status);
  }
  return new Uint8Array(await r.arrayBuffer());
}
function ovtVarint(b: Uint8Array, p: { i: number }): number {
  let r = 0;
  let mult = 1;
  for (;;) {
    const x = b[p.i++];
    if (x === undefined) throw new Error("overture datos cortados");
    r += (x & 0x7f) * mult;
    if (x < 0x80) return r;
    mult *= 128;
  }
}
const ovtZig = (n: number) => (n % 2 === 0 ? n / 2 : -(n + 1) / 2);
function ovtDirectorio(b: Uint8Array): OvtEntrada[] {
  const p = { i: 0 };
  const n = ovtVarint(b, p);
  const e: OvtEntrada[] = [];
  let ult = 0;
  for (let k = 0; k < n; k++) { ult += ovtVarint(b, p); e.push({ id: ult, off: 0, len: 0, run: 0 }); }
  for (let k = 0; k < n; k++) e[k].run = ovtVarint(b, p);
  for (let k = 0; k < n; k++) e[k].len = ovtVarint(b, p);
  for (let k = 0; k < n; k++) {
    const v = ovtVarint(b, p);
    e[k].off = v === 0 && k > 0 ? e[k - 1].off + e[k - 1].len : v - 1;
  }
  return e;
}
function ovtTileId(z: number, x0: number, y0: number): number {
  let acc = 0;
  for (let i = 0; i < z; i++) acc += 4 ** i;
  let x = x0;
  let y = y0;
  let d = 0;
  for (let s = 2 ** z / 2; s > 0; s /= 2) {
    const rx = (x & s) > 0 ? 1 : 0;
    const ry = (y & s) > 0 ? 1 : 0;
    d += s * s * ((3 * rx) ^ ry);
    if (ry === 0) {
      if (rx === 1) { x = s - 1 - x; y = s - 1 - y; }
      const t = x; x = y; y = t;
    }
  }
  return acc + d;
}
function ovtBuscar(e: OvtEntrada[], id: number): OvtEntrada | null {
  let m = 0;
  let n = e.length - 1;
  while (m <= n) {
    const k = (n + m) >> 1;
    const c = id - e[k].id;
    if (c > 0) m = k + 1; else if (c < 0) n = k - 1; else return e[k];
  }
  if (n >= 0 && (e[n].run === 0 || id - e[n].id < e[n].run)) return e[n];
  return null;
}
async function ovtAbrir(url: string): Promise<OvtAbierto> {
  const ini = await ovtRango(url, 0, 16384);
  const dv = new DataView(ini.buffer, ini.byteOffset, ini.byteLength);
  if (new TextDecoder().decode(ini.slice(0, 7)) !== "PMTiles" || ini[7] !== 3) throw new Error("overture formato");
  const u = (o: number) => Number(dv.getBigUint64(o, true));
  const rootOff = u(8);
  const rootLen = u(16);
  const compInt = ini[97];
  const compTile = ini[98];
  if ((compInt !== 1 && compInt !== 2) || (compTile !== 1 && compTile !== 2)) throw new Error("overture compresion " + compInt + "/" + compTile);
  let raiz = rootOff + rootLen <= ini.length ? ini.slice(rootOff, rootOff + rootLen) : await ovtRango(url, rootOff, rootLen);
  if (compInt === 2) raiz = await ovtGunzip(raiz);
  return { rootOff, dataOff: u(56), leafOff: u(40), compInt, compTile, raiz: ovtDirectorio(raiz) };
}
async function ovtTesela(url: string, a: OvtAbierto, z: number, x: number, y: number): Promise<Uint8Array | null> {
  const id = ovtTileId(z, x, y);
  let dir = a.raiz;
  for (let nivel = 0; nivel < 4; nivel++) {
    const e = ovtBuscar(dir, id);
    if (!e) return null;
    if (e.run > 0) {
      const t = await ovtRango(url, a.dataOff + e.off, e.len);
      return a.compTile === 2 ? await ovtGunzip(t) : t;
    }
    const hoja = await ovtRango(url, a.leafOff + e.off, e.len);
    dir = ovtDirectorio(a.compInt === 2 ? await ovtGunzip(hoja) : hoja);
  }
  return null;
}
async function ovtRelease(): Promise<string[]> {
  const cache = (caches as unknown as { default: Cache }).default;
  const llave = new Request("https://cache.ojoguard.app/rvi/overture-release");
  let rel = "";
  const g = await cache.match(llave);
  if (g) rel = await g.text();
  if (!rel) {
    try {
      const r = await fetch(OVT_STAC, { signal: AbortSignal.timeout(8000) });
      if (r.ok) {
        const j = await r.json<{ latest?: string }>();
        if (j.latest && /^\d{4}-\d{2}-\d{2}\.\d+$/.test(j.latest)) rel = j.latest;
      }
    } catch { /* se usa la lista fija */ }
    if (rel) await cache.put(llave, new Response(rel, { headers: { "cache-control": "public, max-age=43200" } }));
  }
  return [...(rel ? [rel] : []), ...OVT_FIJAS.filter((x) => x !== rel)];
}
// --- decodificador minimo de teselas vectoriales (MVT): solo la capa "building" ---
type OvtCapa = { b: Uint8Array; claves: string[]; valores: Array<[number, number]>; feats: Array<[number, number]>; extent: number };
function ovtCapa(b: Uint8Array): OvtCapa | null {
  const td = new TextDecoder();
  const p = { i: 0 };
  while (p.i < b.length) {
    const tag = ovtVarint(b, p);
    const f = Math.floor(tag / 8);
    const w = tag & 7;
    if (w === 2) {
      const len = ovtVarint(b, p);
      const ini = p.i;
      p.i += len;
      if (f !== 3) continue;
      const capa: OvtCapa = { b, claves: [], valores: [], feats: [], extent: 4096 };
      let nombre = "";
      const q = { i: ini };
      while (q.i < ini + len) {
        const t2 = ovtVarint(b, q);
        const f2 = Math.floor(t2 / 8);
        const w2 = t2 & 7;
        if (w2 === 2) {
          const l2 = ovtVarint(b, q);
          const s = q.i;
          q.i += l2;
          if (f2 === 1) nombre = td.decode(b.subarray(s, s + l2));
          else if (f2 === 2) capa.feats.push([s, s + l2]);
          else if (f2 === 3) capa.claves.push(td.decode(b.subarray(s, s + l2)));
          else if (f2 === 4) capa.valores.push([s, s + l2]);
        } else if (w2 === 0) {
          const v = ovtVarint(b, q);
          if (f2 === 5) capa.extent = v;
        } else if (w2 === 5) q.i += 4; else if (w2 === 1) q.i += 8; else throw new Error("overture mvt");
      }
      if (nombre === "building") return capa;
    } else if (w === 0) ovtVarint(b, p); else if (w === 5) p.i += 4; else if (w === 1) p.i += 8; else throw new Error("overture mvt");
  }
  return null;
}
function ovtValor(c: OvtCapa, k: number): string | number | boolean | null {
  const [ini, fin] = c.valores[k];
  const b = c.b;
  const q = { i: ini };
  while (q.i < fin) {
    const t = ovtVarint(b, q);
    const f = Math.floor(t / 8);
    const w = t & 7;
    if (w === 2) {
      const l = ovtVarint(b, q);
      const s = q.i;
      q.i += l;
      if (f === 1) return new TextDecoder().decode(b.subarray(s, s + l));
    } else if (w === 5) {
      const v = new DataView(b.buffer, b.byteOffset + q.i, 4).getFloat32(0, true);
      q.i += 4;
      if (f === 2) return v;
    } else if (w === 1) {
      const v = new DataView(b.buffer, b.byteOffset + q.i, 8).getFloat64(0, true);
      q.i += 8;
      if (f === 3) return v;
    } else if (w === 0) {
      const v = ovtVarint(b, q);
      if (f === 4 || f === 5) return v;
      if (f === 6) return ovtZig(v);
      if (f === 7) return v !== 0;
    } else return null;
  }
  return null;
}
type OvtFeat = { id: number; tagsIni: number; tagsFin: number; tipo: number; geoIni: number; geoFin: number };
function ovtFeat(c: OvtCapa, ini: number, fin: number): OvtFeat {
  const f: OvtFeat = { id: 0, tagsIni: -1, tagsFin: -1, tipo: 0, geoIni: -1, geoFin: -1 };
  const q = { i: ini };
  while (q.i < fin) {
    const t = ovtVarint(c.b, q);
    const fl = Math.floor(t / 8);
    const w = t & 7;
    if (w === 2) {
      const l = ovtVarint(c.b, q);
      const s = q.i;
      q.i += l;
      if (fl === 4) { f.geoIni = s; f.geoFin = s + l; }
      else if (fl === 2) { f.tagsIni = s; f.tagsFin = s + l; }
    } else if (w === 0) {
      const v = ovtVarint(c.b, q);
      if (fl === 1) f.id = v; else if (fl === 3) f.tipo = v;
    } else if (w === 5) q.i += 4; else if (w === 1) q.i += 8; else throw new Error("overture mvt");
  }
  return f;
}
function ovtAnillos(c: OvtCapa, f: OvtFeat): Array<Array<[number, number]>> {
  const out: Array<Array<[number, number]>> = [];
  let cur: Array<[number, number]> = [];
  let cx = 0;
  let cy = 0;
  const p = { i: f.geoIni };
  while (p.i < f.geoFin) {
    const ci = ovtVarint(c.b, p);
    const cmd = ci & 7;
    const n = Math.floor(ci / 8);
    for (let j = 0; j < n; j++) {
      if (cmd === 1 || cmd === 2) {
        cx += ovtZig(ovtVarint(c.b, p));
        cy += ovtZig(ovtVarint(c.b, p));
        if (cmd === 1) { if (cur.length) out.push(cur); cur = []; }
        cur.push([cx, cy]);
      } else if (cmd === 7) { if (cur.length) out.push(cur); cur = []; }
    }
  }
  if (cur.length) out.push(cur);
  return out;
}
async function rviOverture(lat0: number, lon0: number): Promise<{ elements: unknown[]; fuente: string }> {
  const metrosLat = 111320;
  const metrosLon = 111320 * Math.cos((lat0 * Math.PI) / 180);
  const n = 2 ** OVT_Z;
  const fx = ((lon0 + 180) / 360) * n;
  const fy = ((1 - Math.log(Math.tan((lat0 * Math.PI) / 180) + 1 / Math.cos((lat0 * Math.PI) / 180)) / Math.PI) / 2) * n;
  const tx = Math.floor(fx);
  const ty = Math.floor(fy);
  const px = fx - tx;
  const py = fy - ty;
  const vecinasX = px < 0.2 ? [-1, 0] : px > 0.8 ? [0, 1] : [0];
  const vecinasY = py < 0.2 ? [-1, 0] : py > 0.8 ? [0, 1] : [0];
  const motivos: string[] = [];
  let url = "";
  let abierto: OvtAbierto | null = null;
  let version = "";
  for (const rel of await ovtRelease()) {
    try { url = OVT_BASE + rel + "/buildings.pmtiles"; abierto = await ovtAbrir(url); version = rel; break; } catch (e) { motivos.push(rel + ": " + (e instanceof Error ? e.message : String(e))); }
  }
  if (!abierto) throw new Error("overture no abrio (" + motivos.join(", ") + ")");
  const a = abierto;
  const pedidos: Array<Promise<Array<{ x: number; y: number; bytes: Uint8Array | null }>>> = [];
  for (const dx of vecinasX) for (const dy of vecinasY) pedidos.push(ovtTesela(url, a, OVT_Z, tx + dx, ty + dy).then((bytes) => [{ x: tx + dx, y: ty + dy, bytes }]));
  const teselas = (await Promise.all(pedidos)).flat();
  const hallados: Array<{ dist: number; el: Record<string, unknown> }> = [];
  for (const t of teselas) {
    if (!t.bytes) continue;
    const capa = ovtCapa(t.bytes);
    if (!capa) continue;
    const aLonLat = (x: number, y: number): [number, number] => {
      const gx = (t.x + x / capa.extent) / n;
      const gy = (t.y + y / capa.extent) / n;
      return [gx * 360 - 180, (Math.atan(Math.sinh(Math.PI * (1 - 2 * gy))) * 180) / Math.PI];
    };
    for (const [ini, fin] of capa.feats) {
      const f = ovtFeat(capa, ini, fin);
      if (f.tipo !== 3 || f.geoIni < 0) continue;
      // filtro barato: primer vertice a menos de 400 m del punto
      const q = { i: f.geoIni };
      ovtVarint(capa.b, q);
      const [lo1, la1] = aLonLat(ovtZig(ovtVarint(capa.b, q)), ovtZig(ovtVarint(capa.b, q)));
      if (Math.hypot((la1 - lat0) * metrosLat, (lo1 - lon0) * metrosLon) > 400) continue;
      const props: Record<string, string | number | boolean | null> = {};
      const marcas: number[] = [];
      const rt = { i: f.tagsIni };
      while (f.tagsIni >= 0 && rt.i < f.tagsFin) marcas.push(ovtVarint(capa.b, rt));
      for (let k = 0; k + 1 < marcas.length; k += 2) props[capa.claves[marcas[k]]] = ovtValor(capa, marcas[k + 1]);
      const anillos = ovtAnillos(capa, f);
      if (!anillos.length) continue;
      const area = (r: Array<[number, number]>) => { let s = 0; for (let i = 0; i < r.length; i++) { const p1 = r[i]; const p2 = r[(i + 1) % r.length]; s += (p2[0] - p1[0]) * (p1[1] + p2[1]); } return s; };
      const signoExterior = area(anillos[0]) < 0;
      let nombre = "";
      try { nombre = String((JSON.parse(String(props.names ?? "{}")) as { primary?: string }).primary ?? ""); } catch { nombre = ""; }
      if (!nombre && typeof props["@name"] === "string") nombre = props["@name"] as string;
      anillos.forEach((r, idx) => {
        if (r.length < 3 || (area(r) < 0) !== signoExterior) return;
        const pts = r.map((pt) => aLonLat(pt[0], pt[1]));
        let minLa = 1e9, maxLa = -1e9, minLo = 1e9, maxLo = -1e9;
        for (const [lo, la] of pts) { minLa = Math.min(minLa, la); maxLa = Math.max(maxLa, la); minLo = Math.min(minLo, lo); maxLo = Math.max(maxLo, lo); }
        const dy = lat0 < minLa ? (minLa - lat0) * metrosLat : lat0 > maxLa ? (lat0 - maxLa) * metrosLat : 0;
        const dx = lon0 < minLo ? (minLo - lon0) * metrosLon : lon0 > maxLo ? (lon0 - maxLo) * metrosLon : 0;
        const dist = Math.hypot(dx, dy);
        if (dist > 130) return;
        const tags: Record<string, string> = { building: String(props.class ?? props.subtype ?? "yes") };
        if (typeof props.num_floors === "number") tags["building:levels"] = String(props.num_floors);
        if (typeof props.height === "number") tags.height = String(Math.round(props.height * 10) / 10);
        if (nombre) tags.name = nombre;
        hallados.push({ dist, el: { id: f.id * 10 + idx, tags, src: String(props["@geometry_source"] ?? "Overture Maps"), geometry: pts.map(([lo, la]) => ({ lat: la, lon: lo })) } });
      });
    }
  }
  if (!hallados.length) throw new Error("overture sin edificios");
  hallados.sort((x, y) => x.dist - y.dist);
  return { elements: hallados.slice(0, 80).map((h) => h.el), fuente: "Overture Maps " + version };
}

async function rviContornos(request: Request, env: Env, url: URL) {
'),
    @('src\index.ts', 'contornos: Overpass devuelve la fuente', '      return elements;
', '      return { elements: elements.map((e) => ({ ...e, src: "OpenStreetMap" })), fuente: "OpenStreetMap (Overpass)" };
'),
    @('src\index.ts', 'contornos: Overture compite con Overpass', '  const motivos: string[] = [];
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
  return rviRespuesta({ error: "overpass_busy", detail: motivos.join("; ") }, 503);', '  // Los 5 servidores de Overpass Y Overture Maps compiten a la vez: gana el primero que devuelve edificios. Overture no depende de Overpass y trae tambien edificios que OpenStreetMap no tiene.
  const motivos: string[] = [];
  const ganador = await new Promise<{ elements: Array<unknown>; fuente: string } | null>((resolver) => {
    let pendientes = RVI_SERVIDORES.length + 1;
    const falla = (e: unknown) => { motivos.push(e instanceof Error ? e.message : String(e)); pendientes -= 1; if (pendientes === 0) resolver(null); };
    for (const servidor of RVI_SERVIDORES) pedirA(servidor).then((r) => resolver(r), falla);
    rviOverture(la, lo).then((r) => resolver(r), falla);
  });
  if (ganador) {
    const cuerpo = { elements: ganador.elements, fuente: ganador.fuente };
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
    if (Test-Path ($ruta + ".bak-contornos4")) { Mal ("Ya existe " + $t + ".bak-contornos4. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-contornos4"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-contornos4): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-contornos4") -Destination $ruta -Force }
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
Ok "LISTO: el panel ahora tambien lee los edificios de Overture Maps. Abri el visor v21 y toca Buscar el edificio de nuevo."
Write-Host ""
