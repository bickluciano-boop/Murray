# aplicar-logo-correos.ps1 - Agrega una franja con el logo de ojo guard arriba de todos los correos
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Respaldo index.ts.bak-correos; si algo falla, se restaura.
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
if ((Contar $fi.texto 'function fetchCorreo') -ne 0) { Avi "El logo en los correos ya estaba puesto. No toco nada."; return }

$A1 = 'fetch("https://api.resend.com/emails", {'
$N1 = 'fetchCorreo("https://api.resend.com/emails", {'
$A2 = '      if (route === "GET /alarm.wav") return alarmToneResponse();'
$N2 = Ajustar ('      if (route === "GET /marca/logo-correo.png") return logoCorreoResponse();' + "`n" + $A2) $fi.crlf
$A3 = 'export default {'
$N3 = Ajustar (@'
// Logo de ojo guard para el encabezado de los correos (PNG 600x104; los correos no muestran SVG).
const LOGO_CORREO_B64 = "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";
function logoCorreoResponse() {
  const bytes = Uint8Array.from(atob(LOGO_CORREO_B64), (c) => c.charCodeAt(0));
  return new Response(bytes, { headers: { "content-type": "image/png", "cache-control": "public, max-age=604800", "x-content-type-options": "nosniff" } });
}
// Pone la franja con el logo arriba de cada correo que sale por Resend.
function conMarcaCorreo(html: string) {
  if (html.includes("data-og-marca")) return html;
  const logo = `${DEFAULT_PANEL_URL}marca/logo-correo.png`;
  return `<div data-og-marca="1" style="max-width:620px;margin:0 auto 12px;padding:18px 24px;background:#0c0d0f;border-radius:16px"><img src="${logo}" width="200" height="35" alt="ojo guard" style="display:block;border:0;outline:none;text-decoration:none"></div>${html}`;
}
async function fetchCorreo(input: string, init: RequestInit) {
  try {
    if (typeof init.body === "string") {
      const datos = JSON.parse(init.body);
      if (datos && typeof datos.html === "string") init = { ...init, body: JSON.stringify({ ...datos, html: conMarcaCorreo(datos.html) }) };
    }
  } catch {
    // Si algo falla, el correo sale igual, sin el logo.
  }
  return fetch(input, init);
}
'@ + "`n" + $A3) $fi.crlf

$cuantos = Contar $fi.texto $A1
if ($cuantos -ge 1 -and $cuantos -le 12) { Ok ("index.ts: envios de correo encontrados: " + $cuantos) } else { Mal ("index.ts: envios de correo: " + $cuantos); return }
$ok = $true
foreach ($c in @(@("index.ts: ruta del sonido de alarma", $A2), @("index.ts: export default", $A3))) {
    $n = Contar $fi.texto $c[1]
    if ($n -eq 1) { Ok ($c[0] + ": 1") } else { Mal ($c[0] + ": " + $n + " (esperaba 1)"); $ok = $false }
}
if (-not $ok) { Mal "Alguna ancla no coincide. No toco nada. Mandame esta pantalla."; return }

$bak = $archIdx + ".bak-correos"
if (Test-Path $bak) { Mal ("Ya existe " + $bak + ". No toco nada."); return }
Copy-Item -LiteralPath $archIdx -Destination $bak
Ok "Respaldo creado (index.ts.bak-correos)"

$nuevo = $fi.texto.Replace($A1, $N1).Replace($A2, $N2).Replace($A3, $N3)
[System.IO.File]::WriteAllText($archIdx, $nuevo, (New-Object System.Text.UTF8Encoding($fi.bom)))

$vi = Leer $archIdx
$todoBien = $true
function Chk([string]$que, [bool]$cond) { if ($cond) { Ok $que } else { Mal $que; $script:todoBien = $false } }
$esperado = $cuantos * ($N1.Length - $A1.Length) + ($N2.Length - $A2.Length) + ($N3.Length - $A3.Length)
$lineasCod = (Lineas $N3) - 1
Chk ("todos los correos pasan por el logo (" + $cuantos + ")") (((Contar $vi.texto $N1) -eq $cuantos) -and ((Contar $vi.texto $A1) -eq 0))
Chk "ruta del logo agregada 1 vez" ((Contar $vi.texto '"GET /marca/logo-correo.png"') -eq 1)
Chk "funciones nuevas 1 vez" (((Contar $vi.texto 'function fetchCorreo') -eq 1) -and ((Contar $vi.texto 'function conMarcaCorreo') -eq 1) -and ((Contar $vi.texto 'function logoCorreoResponse') -eq 1))
Chk "export default sigue 1 vez" ((Contar $vi.texto $A3) -eq 1)
Chk "sonido de alarma sigue" ((Contar $vi.texto $A2) -eq 1)
Chk ("largo +" + ($vi.texto.Length - $fi.texto.Length) + " (esperado +" + $esperado + ")") (($vi.texto.Length - $fi.texto.Length) -eq $esperado)
Chk ("lineas " + (Lineas $fi.texto) + " -> " + (Lineas $vi.texto) + " (+" + ($lineasCod + 1) + ")") ((Lineas $vi.texto) -eq ((Lineas $fi.texto) + $lineasCod + 1))
if (-not $todoBien) {
    Mal "Algo no salio bien. Restauro desde el respaldo."
    Copy-Item -LiteralPath $bak -Destination $archIdx -Force
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "TODO BIEN en el archivo. Falta PUBLICAR: powershell -ExecutionPolicy Bypass -Command ""npx wrangler deploy"""
Write-Host ""
