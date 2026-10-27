# aplicar-descarga-panel.ps1 - Ojo Guard MS: pagina publica https://ojoguard.app/descargar para bajar la ultima app de Android.
# Luciano (27/10/2026): "en nuestra pagina, no podriamos tener la ultima version y se meten y la bajan? / ponen actualizar".
#  - Agrega GET /descargar (pagina con el boton "Actualizar Ojo Guard"), GET /descargar/ojo-guard.apk (baja el APK) y GET /api/app/version (para el boton de Ajustes de la app).
#  - El APK se guarda en el R2 que ya tiene el panel (EVIDENCE_FILES) con clave fija: no se sirve ninguna otra cosa de ese almacenamiento.
#  - Este instalador NO sube el APK: eso lo hace subir-apk-panel.ps1, y se repite en cada build nueva.
# Cambia SOLO src\index.ts (respaldo .bak-descarga). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
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
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'function apkPagina(') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
$cambios = @(
    @('src\index.ts', 'funciones de la pagina de descarga', 'function familyJoinPage(url: URL) {', '/** Descarga de la app de Android: ojoguard.app/descargar. El APK vive en R2 con clave fija y solo esa clave se sirve. */
const APK_CLAVE = "descargas/ojo-guard.apk";
const APK_INFO_CLAVE = "descargas/version.json";
type ApkInfo = { version: string; subido: string; bytes: number; sha256: string };
async function apkInfo(env: Env): Promise<ApkInfo | null> {
  if (!env.EVIDENCE_FILES) return null;
  const objeto = await env.EVIDENCE_FILES.get(APK_INFO_CLAVE);
  if (!objeto) return null;
  try {
    const dato = JSON.parse(await objeto.text()) as Partial<ApkInfo>;
    if (!dato.bytes || !dato.subido) return null;
    return { version: String(dato.version || ""), subido: String(dato.subido), bytes: Number(dato.bytes), sha256: String(dato.sha256 || "") };
  } catch {
    return null;
  }
}
function apkEscapar(texto: string) {
  return texto.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}
async function apkPagina(env: Env) {
  const info = await apkInfo(env);
  let cuerpo = `<h1>Ojo Guard para Android</h1><p>Todav\u00eda no hay una versi\u00f3n para bajar. Prob\u00e1 de nuevo en un rato.</p>`;
  if (info) {
    const cuando = new Date(info.subido).toLocaleString("es-AR", { timeZone: "America/Argentina/Buenos_Aires", day: "2-digit", month: "2-digit", year: "numeric", hour: "2-digit", minute: "2-digit" });
    const mb = (info.bytes / 1048576).toFixed(1).replace(".", ",");
    const version = info.version ? " (" + apkEscapar(info.version) + ")" : "";
    const huella = info.sha256 ? `<small class="suave">Huella SHA-256: ${apkEscapar(info.sha256.slice(0, 16))}\u2026</small>` : "";
    cuerpo = `<h1>Ojo Guard para Android</h1><p>La \u00faltima versi\u00f3n${version}, subida el ${cuando}. Pesa ${mb} MB.</p>
<p><a class="boton" href="/descargar/ojo-guard.apk" download="ojo-guard.apk">Actualizar Ojo Guard</a></p>
<div class="tarjeta"><h2>C\u00f3mo se instala</h2><ol>
<li>Toc\u00e1 <b>Actualizar Ojo Guard</b> y esper\u00e1 a que termine la descarga.</li>
<li>Abr\u00ed el archivo desde la notificaci\u00f3n o desde la carpeta Descargas.</li>
<li>Si el celular pregunta por instalar apps de esta fuente, permitilo. Es solo la primera vez.</li>
<li>Toc\u00e1 Instalar. Si ya ten\u00e9s Ojo Guard, se actualiza encima.</li>
</ol><p class="suave">Si no se puede instalar, no borres la app: avisanos.</p></div>
<p class="suave">iPhone: esta descarga es solo para Android. En iPhone la app se actualiza desde la App Store o TestFlight.</p>${huella}`;
  }
  const estilo = `<style>*{box-sizing:border-box}body{margin:0;min-height:100vh;background:#0b0c0e;color:#f3f1ea;font-family:system-ui,-apple-system,Segoe UI,sans-serif;padding:22px 16px 60px}main{max-width:560px;margin:0 auto}img.logo{display:block;height:34px;margin:6px 0 18px}h1{font-size:1.5rem;margin:.2rem 0 .5rem}h2{font-size:1.05rem;margin:0 0 10px}p,li{color:#d2d2ce;line-height:1.55}li{margin:6px 0}small,.suave{color:#a29e92}.tarjeta{background:#14151a;border:1px solid #2a2c31;border-radius:18px;padding:16px;margin:14px 0}.boton{display:block;text-align:center;background:#d9b24c;color:#111;border-radius:14px;padding:18px;font:700 1.2rem system-ui;text-decoration:none}</style>`;
  const html = `<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex"><title>Descargar Ojo Guard</title>${estilo}</head><body><main><img class="logo" src="/marca/logo-correo.png" alt="ojo guard">${cuerpo}</main></body></html>`;
  return new Response(html, { headers: { "content-type": "text/html; charset=utf-8", "cache-control": "no-store", "referrer-policy": "no-referrer" } });
}
async function apkDescarga(request: Request, env: Env) {
  if (!env.EVIDENCE_FILES) return new Response("No disponible", { status: 503 });
  const objeto = await env.EVIDENCE_FILES.get(APK_CLAVE);
  if (!objeto) return new Response("Todav\u00eda no hay una versi\u00f3n para bajar.", { status: 404, headers: { "content-type": "text/plain; charset=utf-8", "cache-control": "no-store" } });
  return new Response(request.method === "HEAD" ? null : objeto.body, {
    headers: {
      "content-type": "application/vnd.android.package-archive",
      "content-disposition": ''attachment; filename="ojo-guard.apk"'',
      "content-length": String(objeto.size),
      "cache-control": "no-store"
    }
  });
}
/** Para que la app sepa si hay una version nueva (boton "Actualizar version" de Ajustes). */
async function apkVersionJson(env: Env) {
  const info = await apkInfo(env);
  const cuerpo = info ? { disponible: true, ...info, url: "https://ojoguard.app/descargar" } : { disponible: false };
  return new Response(JSON.stringify(cuerpo), { headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" } });
}

function familyJoinPage(url: URL) {'),
    @('src\index.ts', 'rutas de la pagina de descarga', 'if (route === "GET /unirme") return familyJoinPage(url);', 'if (route === "GET /descargar") return apkPagina(env);
      if (route === "GET /descargar/ojo-guard.apk" || route === "HEAD /descargar/ojo-guard.apk") return apkDescarga(request, env);
      if (route === "GET /api/app/version") return apkVersionJson(env);
      if (route === "GET /unirme") return familyJoinPage(url);')
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
    if (Test-Path ($ruta + ".bak-descarga")) { Mal ("Ya existe " + $t + ".bak-descarga. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-descarga"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-descarga): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-descarga") -Destination $ruta -Force }
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
Ok "LISTO: ya existe https://ojoguard.app/descargar. Falta subir el APK (subir-apk-panel.ps1)."
Write-Host ""
