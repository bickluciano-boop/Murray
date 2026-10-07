# aplicar-encabezado-correos.ps1 - En la franja del logo de cada correo agrega que se pidio y de que equipo
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Respaldo index.ts.bak-encabezado; si algo falla, se restaura.
$ErrorActionPreference = "Continue"
function Ok($t)  { Write-Host ("OK    " + $t) -ForegroundColor Green }
function Mal($t) { Write-Host ("MAL   " + $t) -ForegroundColor Red }
function Avi($t) { Write-Host ("AVISO " + $t) -ForegroundColor Yellow }
$raiz = (Get-Location).Path
if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
function Contar([string]$donde, [string]$que) {
    $n = 0
    $i = 0
    while ($true) {
        $i = $donde.IndexOf($que, $i, [System.StringComparison]::Ordinal)
        if ($i -lt 0) { break }
        $n = $n + 1
        $i = $i + $que.Length
    }
    return $n
}
function Leer([string]$ruta) {
    $bytes = [System.IO.File]::ReadAllBytes($ruta)
    $bom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    $texto = [System.IO.File]::ReadAllText($ruta, [System.Text.Encoding]::UTF8)
    return @{ texto = $texto; bom = $bom; crlf = $texto.Contains("`r`n") }
}
function Ajustar([string]$t, [bool]$crlf) {
    $x = ($t -replace "`r`n", "`n")
    if ($crlf) { $x = $x -replace "`n", "`r`n" }
    return $x
}
function Lineas([string]$t) { return @($t -split "`r`n|`n").Count }

$archIdx = Join-Path $raiz "src\index.ts"
if (-not (Test-Path $archIdx)) { Mal ("No encuentro " + $archIdx); return }
$fi = Leer $archIdx
if ((Contar $fi.texto 'function textoCorreo') -ne 0) { Avi "El encabezado nuevo ya estaba puesto. No toco nada."; return }
if ((Contar $fi.texto 'function fetchCorreo') -ne 1) { Mal "Primero tiene que estar aplicado el logo en los correos (aplicar-logo-correos.ps1)."; return }

$A1 = Ajustar @'
function conMarcaCorreo(html: string) {
  if (html.includes("data-og-marca")) return html;
  const logo = `${DEFAULT_PANEL_URL}marca/logo-correo.png`;
  return `<div data-og-marca="1" style="max-width:620px;margin:0 auto 12px;padding:18px 24px;background:#0c0d0f;border-radius:16px"><img src="${logo}" width="200" height="35" alt="ojo guard" style="display:block;border:0;outline:none;text-decoration:none"></div>${html}`;
}
'@ $fi.crlf
$N1 = Ajustar @'
function textoCorreo(valor: unknown) {
  return String(valor ?? "").replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" } as Record<string, string>)[c]);
}
// Arriba, al lado del logo: que se pidio o que paso, y de que equipo.
function conMarcaCorreo(html: string, asunto?: unknown) {
  if (html.includes("data-og-marca")) return html;
  const logo = `${DEFAULT_PANEL_URL}marca/logo-correo.png`;
  let titulo = String(asunto ?? "").replace(/^(Aviso de seguridad|Alerta de seguridad|Ojo Guard)\s*[\u00b7\u2014:-]\s*/i, "").trim().slice(0, 90);
  let equipo = ((html.match(/<strong[^>]*>\s*Dispositivo:\s*<\/strong>\s*([^<]{1,60})/) || [])[1] ?? "").trim();
  const corte = titulo.lastIndexOf(" \u00b7 ");
  if (corte > 0) {
    const cola = textoCorreo(titulo.slice(corte + 3).trim());
    if (!equipo) equipo = cola;
    if (cola === equipo) titulo = titulo.slice(0, corte).trim();
  }
  const resumen = titulo || equipo
    ? `<td align="right" style="vertical-align:middle;padding-left:12px;font-family:Arial,sans-serif">${titulo ? `<div style="color:#f6f6f2;font-size:15px;font-weight:700;line-height:1.3">${textoCorreo(titulo)}</div>` : ""}${equipo ? `<div style="color:#d9b24c;font-size:13px;margin-top:3px">${equipo}</div>` : ""}</td>`
    : "";
  return `<div data-og-marca="1" style="max-width:620px;margin:0 auto 12px;padding:16px 22px;background:#0c0d0f;border-radius:16px"><table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse"><tr><td style="vertical-align:middle;width:180px"><img src="${logo}" width="170" height="29" alt="ojo guard" style="display:block;border:0;outline:none;text-decoration:none"></td>${resumen}</tr></table></div>${html}`;
}
'@ $fi.crlf
$A2 = 'conMarcaCorreo(datos.html) })'
$N2 = 'conMarcaCorreo(datos.html, datos.subject) })'
$ok = $true
foreach ($c in @(@("index.ts: funcion del encabezado", $A1), @("index.ts: llamada al encabezado", $A2))) {
    $n = Contar $fi.texto $c[1]
    if ($n -eq 1) { Ok ($c[0] + ": 1") } else { Mal ($c[0] + ": " + $n + " (esperaba 1)"); $ok = $false }
}
if (-not $ok) { Mal "Alguna ancla no coincide. No toco nada. Mandame esta pantalla."; return }

$bak = $archIdx + ".bak-encabezado"
if (Test-Path $bak) { Mal ("Ya existe " + $bak + ". No toco nada."); return }
Copy-Item -LiteralPath $archIdx -Destination $bak
Ok "Respaldo creado (index.ts.bak-encabezado)"
$nuevo = $fi.texto.Replace($A1, $N1).Replace($A2, $N2)
[System.IO.File]::WriteAllText($archIdx, $nuevo, (New-Object System.Text.UTF8Encoding($fi.bom)))

$vi = Leer $archIdx
$todoBien = $true
function Chk([string]$que, [bool]$cond) { if ($cond) { Ok $que } else { Mal $que; $script:todoBien = $false } }
$esperado = ($N1.Length - $A1.Length) + ($N2.Length - $A2.Length)
Chk "encabezado nuevo 1 vez" (((Contar $vi.texto 'function textoCorreo') -eq 1) -and ((Contar $vi.texto 'function conMarcaCorreo(html: string, asunto?: unknown)') -eq 1))
Chk "encabezado viejo ya no esta" ((Contar $vi.texto $A1) -eq 0)
Chk "la llamada pasa el asunto" (((Contar $vi.texto $N2) -eq 1) -and ((Contar $vi.texto $A2) -eq 0))
Chk "logo de correos sigue" (((Contar $vi.texto 'function fetchCorreo') -eq 1) -and ((Contar $vi.texto 'function logoCorreoResponse') -eq 1))
Chk ("largo +" + ($vi.texto.Length - $fi.texto.Length) + " (esperado +" + $esperado + ")") (($vi.texto.Length - $fi.texto.Length) -eq $esperado)
Chk ("lineas " + (Lineas $fi.texto) + " -> " + (Lineas $vi.texto)) ((Lineas $vi.texto) -eq ((Lineas $fi.texto) + (Lineas $N1) - (Lineas $A1)))
if (-not $todoBien) {
    Mal "Algo no salio bien. Restauro desde el respaldo."
    Copy-Item -LiteralPath $bak -Destination $archIdx -Force
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "TODO BIEN en el archivo. Falta PUBLICAR: powershell -ExecutionPolicy Bypass -Command ""npx wrangler deploy"""
Write-Host ""
