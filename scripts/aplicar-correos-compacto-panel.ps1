# aplicar-correos-compacto-panel.ps1 - Ojo Guard MS: los mails se ven enteros en el celular (sin tener que bajar) y el mail del codigo muestra el numero bien grande arriba.
# Luciano (22/10/2026): "queda muy grande la tarjeta por mail... que se vea de una sola impresion y que el numero sea grande".
#  - Franja azul mas finita; el titulo solo aparece ahi si el mail no trae uno grande abajo.
#  - Margenes y tamanos de letra mas chicos; pie corto con el link del panel.
#  - Mail del codigo: el numero va primero, centrado y grande.
# Cambia SOLO src\index.ts (respaldo index.ts.bak-correoscompacto). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
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
$txt = (Leer (Join-Path $raiz "src\index.ts")).texto
if ((Contar $txt 'text-size-adjust:100%') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $txt 'Tu panel de Ojo Guard:') -ne 1) { Mal "Primero tienen que estar aplicados los instaladores de correos anteriores (marca y pie). No toco nada."; return }
$cambios = @(
    @('src\index.ts', 'mail del codigo: numero grande arriba', '<div style="font-family:Arial,sans-serif;max-width:620px;margin:auto;background:#0c0d0f;color:#f6f6f2;padding:28px;border-radius:20px"><p style="color:#f4c64e;font-size:12px;font-weight:800;letter-spacing:.16em">OJO GUARD &#183; C&#211;DIGO</p><p style="margin:14px 0 18px"><span style="display:inline-block;font-size:34px;font-weight:800;letter-spacing:.3em;padding:14px 20px 14px 26px;border-radius:12px;background:#EEF2FB;color:#14213D">${code}</span></p><p style="color:#d2d2ce;line-height:1.55">', '<div style="font-family:Arial,sans-serif;max-width:620px;margin:auto;background:#0c0d0f;color:#f6f6f2;padding:28px;border-radius:20px"><p style="margin:0 0 8px"><span style="display:block;text-align:center;font-size:42px;font-weight:800;letter-spacing:.14em;padding:14px 8px;border-radius:12px;background:#EEF2FB;color:#14213D">${code}</span></p><p style="color:#d2d2ce;line-height:1.45;font-size:14px;margin:0 0 4px">'),
    @('src\index.ts', 'mail del codigo: vencimiento', '<p style="color:#8f8d85;font-size:13px">Vence en 15 minutos y funciona una sola vez.</p></div>', '<p style="color:#8f8d85;font-size:12px;margin:0">Vence en 15 minutos y funciona una sola vez.</p></div>'),
    @('src\index.ts', 'mails: compactos para el celular', '// Los cuerpos de los correos estan escritos con la paleta oscura de antes; aca se pasan a la paleta clara de la marca.
function claroCorreo(html: string) {
  const mapa: Array<[string, string]> = [
    ["background:#0c0d0f;color:#f6f6f2;padding:28px;border-radius:20px", "background:#ffffff;color:#14213D;padding:28px;border:1px solid #E3E7F1;border-top:0;border-radius:0 0 16px 16px"],
    ["max-width:560px", "max-width:620px"],
    ["background:#d9b24c;color:#111", "background:#1F4FD1;color:#ffffff"],
    ["background:#201c12;border:1px solid #56461d;border-radius:12px;color:#e4d7ad", "background:#FFF3D6;border:1px solid #F0D79A;border-radius:12px;color:#7A5200"],
    ["<strong style=\"color:#fff\">", "<strong style=\"color:#14213D\">"],
    ["background:#0c0d0f", "background:#ffffff"],
    ["color:#f6f6f2", "color:#14213D"],
    ["color:#d2d2ce", "color:#3E4A6B"],
    ["color:#8f8d85", "color:#5B6580"],
    ["color:#8d8d88", "color:#5B6580"],
    ["color:#f4c64e", "color:#7A5200"],
    ["color:#ff8a7a", "color:#C62828"],
    ["color:#d9b24c", "color:#1F4FD1"],
    ["ojo guard &middot; modo cautela", "Ojo Guard &middot; modo cautela"],
  ];
  let r = html;
  for (const [viejo, nuevo] of mapa) r = r.split(viejo).join(nuevo);
  return r;
}
// Arriba: franja azul marino con el logo y, al lado, que se pidio o que paso y de que equipo. Abajo: el cuerpo en blanco.
function conMarcaCorreoNuevo(html: string, asunto?: unknown) {
  if (html.includes("data-og-marca")) return html;
  const logo = `${DEFAULT_PANEL_URL}marca/ojo-guard-correo.png`;
  let titulo = String(asunto ?? "").replace(/^(Aviso de seguridad|Alerta de seguridad|Ojo Guard)\s*[\u00b7\u2014:-]\s*/i, "").trim().slice(0, 90);
  let equipo = ((html.match(/<strong[^>]*>\s*Dispositivo:\s*<\/strong>\s*([^<]{1,60})/) || [])[1] ?? "").trim();
  const corte = titulo.lastIndexOf(" \u00b7 ");
  if (corte > 0) {
    const cola = textoCorreo(titulo.slice(corte + 3).trim());
    if (!equipo) equipo = cola;
    if (cola === equipo) titulo = titulo.slice(0, corte).trim();
  }
  const resumen = titulo || equipo
    ? `<div style="font-family:Arial,sans-serif;padding-top:14px">${titulo ? `<div style="color:#ffffff;font-size:15px;font-weight:700;line-height:1.35">${textoCorreo(titulo)}</div>` : ""}${equipo ? `<div style="color:#F1D58A;font-size:13px;margin-top:3px">${equipo}</div>` : ""}</div>`
    : "";
  return `<div style="background:#EEF2FB;padding:18px 10px"><div data-og-marca="1" style="max-width:620px;margin:0 auto;padding:18px 22px 16px;background:#0F1A3A;border-radius:16px 16px 0 0"><img src="${logo}" width="196" height="36" alt="Ojo Guard" style="display:block;border:0;outline:none;text-decoration:none">${resumen}</div>${claroCorreo(html)}<div style="max-width:620px;margin:0 auto;padding:16px 22px 0;text-align:center;font-family:Arial,sans-serif;font-size:13px;line-height:1.6;color:#5B6580">Tu panel de Ojo Guard: <a href="${DEFAULT_PANEL_URL}" style="color:#1F4FD1;font-weight:700;text-decoration:none">${DEFAULT_PANEL_URL.replace(/^https?:\/\//, "").replace(/\/$/, "")}</a><br>Guard&#225; este link: lo vas a necesitar si perd&#233;s el acceso. Soporte: soporte@ojoguard.app</div></div>`;
}', '// Los cuerpos de los correos estan escritos con la paleta oscura de antes; aca se pasan a la paleta clara de la marca y se compactan para el celular.
function claroCorreo(html: string) {
  const mapa: Array<[string, string]> = [
    ["background:#0c0d0f;color:#f6f6f2;padding:28px;border-radius:20px", "background:#ffffff;color:#14213D;padding:16px 18px;border:1px solid #E3E7F1;border-top:0;border-radius:0 0 14px 14px"],
    ["max-width:560px", "max-width:620px"],
    ["background:#d9b24c;color:#111", "background:#1F4FD1;color:#ffffff"],
    ["background:#201c12;border:1px solid #56461d;border-radius:12px;color:#e4d7ad", "background:#FFF3D6;border:1px solid #F0D79A;border-radius:12px;color:#7A5200"],
    ["margin-top:22px;padding:16px", "margin-top:12px;padding:12px;font-size:14px;line-height:1.4"],
    ["font-size:26px;margin:10px 0 18px", "font-size:21px;line-height:1.2;margin:4px 0 10px"],
    ["font-size:20px;font-weight:700;margin:0 0 14px", "font-size:17px;font-weight:700;margin:0 0 8px"],
    ["font-size:20px;font-weight:700;margin:0 0 12px", "font-size:17px;font-weight:700;margin:0 0 8px"],
    ["font-size:12px;font-weight:800;letter-spacing:.16em", "font-size:11px;font-weight:800;letter-spacing:.14em;margin:0"],
    ["padding:13px 22px", "padding:11px 20px"],
    ["padding:12px 16px", "padding:10px 16px"],
    ["margin:22px 0", "margin:12px 0"],
    ["margin:20px 0", "margin:12px 0"],
    ["margin:26px 0 0", "margin:12px 0 0"],
    ["<p style=\"color:#d2d2ce;line-height:1.55\">", "<p style=\"color:#3E4A6B;line-height:1.45;font-size:14px;margin:8px 0\">"],
    ["<p style=\"color:#d2d2ce\">", "<p style=\"color:#3E4A6B;font-size:14px;margin:6px 0\">"],
    ["<strong style=\"color:#fff\">", "<strong style=\"color:#14213D\">"],
    ["background:#0c0d0f", "background:#ffffff"],
    ["color:#f6f6f2", "color:#14213D"],
    ["color:#d2d2ce", "color:#3E4A6B"],
    ["color:#8f8d85", "color:#5B6580"],
    ["color:#8d8d88", "color:#5B6580"],
    ["color:#f4c64e", "color:#7A5200"],
    ["color:#ff8a7a", "color:#C62828"],
    ["color:#d9b24c", "color:#1F4FD1"],
    ["ojo guard &middot; modo cautela", "Ojo Guard &middot; modo cautela"],
    ["<p>", "<p style=\"margin:6px 0;font-size:14px\">"],
  ];
  let r = html;
  for (const [viejo, nuevo] of mapa) r = r.split(viejo).join(nuevo);
  return r;
}
// Arriba: franja azul marino con el logo (y el titulo solo si el cuerpo no trae uno grande). Abajo: el cuerpo en blanco, compacto para verse entero en el celular.
function conMarcaCorreoNuevo(html: string, asunto?: unknown) {
  if (html.includes("data-og-marca")) return html;
  const logo = `${DEFAULT_PANEL_URL}marca/ojo-guard-correo.png`;
  let titulo = String(asunto ?? "").replace(/^(Aviso de seguridad|Alerta de seguridad|Ojo Guard)\s*[\u00b7\u2014:-]\s*/i, "").trim().slice(0, 90);
  let equipo = ((html.match(/<strong[^>]*>\s*Dispositivo:\s*<\/strong>\s*([^<]{1,60})/) || [])[1] ?? "").trim();
  const corte = titulo.lastIndexOf(" \u00b7 ");
  if (corte > 0) {
    const cola = textoCorreo(titulo.slice(corte + 3).trim());
    if (!equipo) equipo = cola;
    if (cola === equipo) titulo = titulo.slice(0, corte).trim();
  }
  const resumen = (titulo || equipo) && !html.includes("<h1")
    ? `<div style="font-family:Arial,sans-serif;padding-top:10px;color:#ffffff;font-size:14px;font-weight:700;line-height:1.35">${textoCorreo(titulo)}</div>`
    : "";
  return `<div style="background:#EEF2FB;padding:8px 6px;-webkit-text-size-adjust:100%;text-size-adjust:100%"><div data-og-marca="1" style="max-width:620px;margin:0 auto;padding:12px 16px;background:#0F1A3A;border-radius:14px 14px 0 0"><img src="${logo}" width="150" height="28" alt="Ojo Guard" style="display:block;border:0;outline:none;text-decoration:none">${resumen}</div>${claroCorreo(html)}<div style="max-width:620px;margin:0 auto;padding:10px 12px 2px;text-align:center;font-family:Arial,sans-serif;font-size:12px;line-height:1.5;color:#5B6580">Tu panel de Ojo Guard: <a href="${DEFAULT_PANEL_URL}" style="color:#1F4FD1;font-weight:700;text-decoration:none">${DEFAULT_PANEL_URL.replace(/^https?:\/\//, "").replace(/\/$/, "")}</a><br>Guard&#225; este link por si perd&#233;s el acceso</div></div>`;
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
    if (Test-Path ($ruta + ".bak-correoscompacto")) { Mal ("Ya existe " + $t + ".bak-correoscompacto. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-correoscompacto"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-correoscompacto): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-correoscompacto") -Destination $ruta -Force }
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
Ok "LISTO: los mails quedan compactos y el codigo va grande arriba. Pedi otro codigo de ingreso para verlo."
Write-Host ""
