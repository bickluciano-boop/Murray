# aplicar-unirme-estetica-panel.ps1 - Ojo Guard MS: la pagina de invitacion "Te invitaron a una familia" (/unirme) pasa al estilo actual y al ojo nuevo.
# Luciano (27/10/2026): "cambiar el ojo viejo en las otras paginas". Era la que quedaba con el fondo oscuro con dorado de antes y el logo-correo.png viejo.
# Funciona igual: muestra el codigo de 6 letras, los pasos y el boton "Abrir Ojo Guard". Se suma el link a ojoguard.app/descargar para quien todavia no tiene la app (Android).
# Cambia SOLO la funcion familyJoinPage en src\index.ts (respaldo .bak-unirme). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
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
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'const UNIRME_ESTILO') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
$cambios = @(
    ,@('src\index.ts', 'pagina de invitacion (/unirme) con el estilo actual', 'function familyJoinPage(url: URL) {
  const code = (url.searchParams.get("codigo") ?? "").toUpperCase().replace(/[^A-Z0-9]/g, "").slice(0, 6);
  const html = `<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Unirte a una familia en Ojo Guard</title>
<style>body{margin:0;min-height:100vh;display:grid;place-items:center;background:#0b0c0e;color:#f3f1ea;font-family:system-ui,-apple-system,Segoe UI,sans-serif;padding:24px}main{max-width:420px;text-align:center}img{height:34px;margin-bottom:22px}h1{font-size:26px;margin:0 0 10px}p{color:#a29e92;line-height:1.55}.codigo{font-size:40px;letter-spacing:.22em;font-weight:700;color:#f0c75a;background:#211d12;border:1px solid #4a3f1f;border-radius:16px;padding:16px 10px;margin:22px 0}ol{text-align:left;color:#d6d2c6;line-height:1.7;padding-left:22px}a.boton{display:inline-block;margin-top:16px;background:#d9b24c;color:#111;border-radius:12px;padding:12px 18px;font-weight:700;text-decoration:none}</style></head>
<body><main><img src="/marca/logo-correo.png" alt="ojo guard"><h1>Te invitaron a una familia</h1><p>Vas a compartir tu ubicaci&oacute;n con esa familia y ver la de ellos en el mapa.</p>
<div class="codigo">${code || "------"}</div>
<ol><li>Instal&aacute; Ojo Guard en tu tel&eacute;fono y entr&aacute; con tu correo.</li><li>And&aacute; a <b>Familia</b> &rsaquo; <b>Unirme con un c&oacute;digo</b>.</li><li>Escrib&iacute; el c&oacute;digo de arriba.</li></ol>
<a class="boton" href="ojoguard://familia?codigo=${code}">Abrir Ojo Guard</a></main></body></html>`;
  return new Response(html, { headers: { "content-type": "text/html; charset=utf-8", "cache-control": "no-store" } });
}', 'const UNIRME_ESTILO = `<style>:root{color-scheme:light;--fondo:#FAF8F3;--tarjeta:#fff;--linea:#E3E7F1;--texto:#14213D;--texto2:#3E4A6B;--suave:#5B6580;--azul:#1F4FD1;--azul-link:#1F4FD1;--azul-suave:#EEF2FB;--dorado:#E3A92B;--dorado-suave:#FFF3D6;--dorado-texto:#7A5200;--sombra:0 6px 24px rgba(20,33,61,.08)}html.noche{color-scheme:dark;--fondo:#0B1020;--tarjeta:#121A33;--linea:rgba(255,255,255,.12);--texto:#F5F0E6;--texto2:#D5DBEC;--suave:#A9B3CE;--azul:#3D6BEA;--azul-link:#9DBBFF;--azul-suave:rgba(255,255,255,.07);--dorado:#FFC247;--dorado-suave:rgba(255,194,71,.16);--dorado-texto:#FFD477;--sombra:0 6px 24px rgba(0,0,0,.35)}*{box-sizing:border-box}body{margin:0;min-height:100vh;background:linear-gradient(180deg,#E3EBFF 0,var(--fondo) 340px) no-repeat,var(--fondo);color:var(--texto);font-family:"Plus Jakarta Sans",system-ui,-apple-system,Segoe UI,sans-serif;line-height:1.45;padding:22px 16px 60px}html.noche body{background:linear-gradient(180deg,#17285F 0,var(--fondo) 380px) no-repeat,var(--fondo)}main{max-width:560px;margin:0 auto}.marca{display:flex;align-items:center;gap:12px;font-weight:600;font-size:1.3rem;letter-spacing:-.01em;margin:6px 0 14px}.ojo{flex:none;display:block}.nom .o{position:relative;display:inline-block;line-height:1}.nom .o::after{content:"";position:absolute;left:50%;top:54%;width:.2em;height:.2em;border-radius:50%;background:var(--dorado);transform:translate(-50%,-50%)}.etiqueta{display:inline-block;font:700 .68rem/1 "Plus Jakarta Sans",system-ui,sans-serif;letter-spacing:.07em;color:var(--dorado-texto);background:var(--dorado-suave);border-radius:999px;padding:6px 10px;margin:0 0 14px}h1{font-size:2rem;line-height:1.2;letter-spacing:-.02em;font-weight:700;margin:.2rem 0 .6rem}h2{font-size:1.05rem;font-weight:700;margin:0 0 10px}p,li{color:var(--texto2);line-height:1.55}li{margin:6px 0}ol{margin:0;padding-left:1.3em}small,.suave{color:var(--suave)}.tarjeta{background:var(--tarjeta);border:1px solid var(--linea);border-radius:26px;padding:18px;margin:14px 0;box-shadow:var(--sombra)}.boton{display:block;text-align:center;background:var(--azul);color:#fff;border-radius:999px;padding:18px 22px;font:700 1.15rem "Plus Jakarta Sans",system-ui,sans-serif;text-decoration:none;box-shadow:0 12px 28px rgba(31,79,209,.3)}.boton:focus-visible{outline:3px solid var(--azul-link);outline-offset:3px}.codigo{font:700 2.6rem/1 "Plus Jakarta Sans",system-ui,sans-serif;letter-spacing:.22em;text-align:center;color:var(--dorado-texto);background:var(--dorado-suave);border-radius:22px;padding:22px 10px 22px 20px;margin:20px 0}ol{margin:0;padding-left:1.3em}.fondo-b{display:block}</style>`;
const UNIRME_LOGO = `<span class="marca"><svg class="ojo" viewBox="0 0 120 72" width="44" height="26" aria-hidden="true" focusable="false"><defs><linearGradient id="ogOro" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#F1D58A"/><stop offset=".5" stop-color="#D4A94D"/><stop offset="1" stop-color="#A67C32"/></linearGradient></defs><path d="M4 36C30 10 62 6 84 8C104 10 116 22 116 36C116 50 104 62 84 64C62 66 30 62 4 36Z" fill="#0F1A3A" stroke="#B48A3C" stroke-width="1"/><path d="M10 36C32 15 60 12 82 14C98 16 107 25 107 36C107 47 98 56 82 58C60 60 32 57 10 36Z" fill="none" stroke="url(#ogOro)" stroke-width="3.4" stroke-linejoin="round"/><path d="M30 36Q66 -6 101 36Q66 78 30 36Z" fill="none" stroke="url(#ogOro)" stroke-width="2.6" stroke-linejoin="round"/><circle cx="66" cy="36" r="17" fill="#1B2D5E" stroke="url(#ogOro)" stroke-width="2.2"/><circle cx="66" cy="36" r="8.6" fill="#05060B"/><circle cx="60.6" cy="30.2" r="2.8" fill="#EEF2FF" fill-opacity=".92"/></svg><span class="nom"><span class="o">O</span>jo Guard</span></span>`;
/** Pagina que abre el link de invitacion (WhatsApp, mail): muestra el codigo y como usarlo. */
function familyJoinPage(url: URL) {
  const code = (url.searchParams.get("codigo") ?? "").toUpperCase().replace(/[^A-Z0-9]/g, "").slice(0, 6);
  const html = `<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex"><title>Unirte a una familia en Ojo Guard</title><link rel="preconnect" href="https://fonts.googleapis.com"><link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700&display=swap">${UNIRME_ESTILO}<script>try{if(localStorage.getItem("ojo_ms_tema")==="oscuro")document.documentElement.classList.add("noche")}catch(e){}</script></head>
<body><main>${UNIRME_LOGO}<span class="etiqueta">N&Uacute;CLEO &middot; EN VALIDACI&Oacute;N</span><h1>Te invitaron a una familia</h1><p>Vas a compartir tu ubicaci&oacute;n con esa familia y ver la de ellos en el mapa.</p>
<div class="codigo">${code || "------"}</div>
<div class="tarjeta"><h2>C&oacute;mo te un&iacute;s</h2><ol><li>Instal&aacute; Ojo Guard en tu tel&eacute;fono y entr&aacute; con tu correo.</li><li>And&aacute; a <b>Familia</b> &rsaquo; <b>Unirme con un c&oacute;digo</b>.</li><li>Escrib&iacute; el c&oacute;digo de arriba.</li></ol></div>
<p><a class="boton" href="ojoguard://familia?codigo=${code}">Abrir Ojo Guard</a></p>
<p class="suave">Si todav&iacute;a no la ten&eacute;s, en Android la baj&aacute;s desde <a href="/descargar" style="color:var(--azul-link)">ojoguard.app/descargar</a>.</p></main></body></html>`;
  return new Response(html, { headers: { "content-type": "text/html; charset=utf-8", "cache-control": "no-store" } });
}')
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
    if (Test-Path ($ruta + ".bak-unirme")) { Mal ("Ya existe " + $t + ".bak-unirme. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-unirme"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-unirme): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-unirme") -Destination $ruta -Force }
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
Ok "LISTO: la pagina de invitacion ya se ve con el estilo actual."
Write-Host ""
