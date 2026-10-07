# aplicar-entrada-panel.ps1 - Pantalla de entrada del panel con la marca nueva (logo grande, fondo con brillo dorado)
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Respaldo panel-index.html.bak-entrada; si algo falla, se restaura.
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

$archHtml = Join-Path $raiz "src\panel-index.html"
if (-not (Test-Path $archHtml)) { Mal ("No encuentro " + $archHtml); return }
$fh = Leer $archHtml
if ((Contar $fh.texto 'id="acceso-v2"') -ne 0) { Avi "La pantalla de entrada nueva ya estaba puesta. No toco nada."; return }

$A1 = '<section id="access" class="hero card">'
$N1 = $A1 + '<svg class="acceso-marca" viewBox="0 40 226 120" width="168" height="89" aria-hidden="true"><defs><linearGradient id="ogAccGold" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffd978"/><stop offset=".5" stop-color="#e2a93a"/><stop offset="1" stop-color="#9c6a1a"/></linearGradient><radialGradient id="ogAccIris"><stop offset="0" stop-color="#3a2606"/><stop offset=".35" stop-color="#b9851f"/><stop offset=".75" stop-color="#f2c45a"/><stop offset="1" stop-color="#8a5f14"/></radialGradient></defs><path d="M8,100 C48,71.4 84,48 154,48 A64,52 0 0 1 154,152 C84,152 48,128.6 8,100 Z" fill="none" stroke="url(#ogAccGold)" stroke-width="6.5" stroke-linejoin="round"/><path d="M60,100 C90,63 166,63 196,100 C166,137 90,137 60,100 Z" fill="#0b0b0b" stroke="url(#ogAccGold)" stroke-width="4.5"/><circle cx="128" cy="100" r="29" fill="url(#ogAccIris)"/><line x1="140.5" y1="100.0" x2="155.0" y2="100.0" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="140.3" y1="102.2" x2="154.6" y2="104.7" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="139.7" y1="104.3" x2="153.4" y2="109.2" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="138.8" y1="106.2" x2="151.4" y2="113.5" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="137.6" y1="108.0" x2="148.7" y2="117.4" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="136.0" y1="109.6" x2="145.4" y2="120.7" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="134.2" y1="110.8" x2="141.5" y2="123.4" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="132.3" y1="111.7" x2="137.2" y2="125.4" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="130.2" y1="112.3" x2="132.7" y2="126.6" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="128.0" y1="112.5" x2="128.0" y2="127.0" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="125.8" y1="112.3" x2="123.3" y2="126.6" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="123.7" y1="111.7" x2="118.8" y2="125.4" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="121.8" y1="110.8" x2="114.5" y2="123.4" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="120.0" y1="109.6" x2="110.6" y2="120.7" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="118.4" y1="108.0" x2="107.3" y2="117.4" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="117.2" y1="106.2" x2="104.6" y2="113.5" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="116.3" y1="104.3" x2="102.6" y2="109.2" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="115.7" y1="102.2" x2="101.4" y2="104.7" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="115.5" y1="100.0" x2="101.0" y2="100.0" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="115.7" y1="97.8" x2="101.4" y2="95.3" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="116.3" y1="95.7" x2="102.6" y2="90.8" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="117.2" y1="93.8" x2="104.6" y2="86.5" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="118.4" y1="92.0" x2="107.3" y2="82.6" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="120.0" y1="90.4" x2="110.6" y2="79.3" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="121.8" y1="89.2" x2="114.5" y2="76.6" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="123.7" y1="88.3" x2="118.8" y2="74.6" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="125.8" y1="87.7" x2="123.3" y2="73.4" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="128.0" y1="87.5" x2="128.0" y2="73.0" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="130.2" y1="87.7" x2="132.7" y2="73.4" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="132.3" y1="88.3" x2="137.2" y2="74.6" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="134.2" y1="89.2" x2="141.5" y2="76.6" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="136.0" y1="90.4" x2="145.4" y2="79.3" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="137.6" y1="92.0" x2="148.7" y2="82.6" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="138.8" y1="93.8" x2="151.4" y2="86.5" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="139.7" y1="95.7" x2="153.4" y2="90.8" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><line x1="140.3" y1="97.8" x2="154.6" y2="95.3" stroke="#ffe7a8" stroke-opacity=".4" stroke-width="1"/><circle cx="128" cy="100" r="29" fill="none" stroke="#5a3d0c" stroke-width="2"/><circle cx="128" cy="100" r="11.5" fill="#070707"/><circle cx="122.8" cy="94.2" r="3.2" fill="#fff" fill-opacity=".85"/></svg>'
$A2 = '<h1>Tu centro de protecci' + [string][char]0x00F3 + 'n</h1>'
$N2 = '<h1>Entr&#225; a tu cuenta</h1>'
$A3 = '</head>'
$N3 = Ajustar ('<style id="acceso-v2">#access.hero{max-width:560px;text-align:center;background:radial-gradient(120% 75% at 50% 0%,#2b200b 0,#100e0b 58%,#0b0a09 100%);border:1px solid #3a2f16;box-shadow:0 30px 90px rgba(0,0,0,.6)}#access .acceso-marca{display:block;margin:4px auto 22px;width:168px;height:auto;filter:drop-shadow(0 0 16px rgba(255,186,64,.35))}#access .eyebrow{color:#d9b24c;letter-spacing:.3em}#access h1{font-size:clamp(1.9rem,4.4vw,2.8rem);letter-spacing:-.035em;margin:.15em 0 .3em}#access .hero-copy{margin:0 auto 26px;color:#bdb6a6;max-width:44ch}#access form,#access details,#access #passkey-setup{text-align:left}#access details{margin-top:10px}#access details summary{color:#bdb6a6;cursor:pointer}:root[data-theme="light"] #access.hero{background:radial-gradient(120% 75% at 50% 0%,#fff3d1 0,#fffdf8 60%,#ffffff 100%);border-color:#e6dcc0;box-shadow:0 18px 50px rgba(70,58,20,.10)}:root[data-theme="light"] #access .acceso-marca{filter:drop-shadow(0 2px 6px rgba(150,110,30,.25))}:root[data-theme="light"] #access .eyebrow{color:#9c6a1a}:root[data-theme="light"] #access .hero-copy,:root[data-theme="light"] #access details summary{color:#5b5a52}</style>' + "`n  " + $A3) $fh.crlf
$ok = $true
foreach ($c in @(@("panel-index.html: tarjeta de entrada", $A1), @("panel-index.html: titulo de entrada", $A2), @("panel-index.html: fin del head", $A3))) {
    $n = Contar $fh.texto $c[1]
    if ($n -eq 1) { Ok ($c[0] + ": 1") } else { Mal ($c[0] + ": " + $n + " (esperaba 1)"); $ok = $false }
}
if (-not $ok) { Mal "Alguna ancla no coincide. No toco nada. Mandame esta pantalla."; return }

$bak = $archHtml + ".bak-entrada"
if (Test-Path $bak) { Mal ("Ya existe " + $bak + ". No toco nada."); return }
Copy-Item -LiteralPath $archHtml -Destination $bak
Ok "Respaldo creado (panel-index.html.bak-entrada)"
$nuevo = $fh.texto.Replace($A1, $N1).Replace($A2, $N2).Replace($A3, $N3)
[System.IO.File]::WriteAllText($archHtml, $nuevo, (New-Object System.Text.UTF8Encoding($fh.bom)))

$vh = Leer $archHtml
$todoBien = $true
function Chk([string]$que, [bool]$cond) { if ($cond) { Ok $que } else { Mal $que; $script:todoBien = $false } }
$esperado = ($N1.Length - $A1.Length) + ($N2.Length - $A2.Length) + ($N3.Length - $A3.Length)
Chk "logo grande en la entrada 1 vez" ((Contar $vh.texto 'class="acceso-marca"') -eq 1)
Chk "titulo nuevo" (((Contar $vh.texto $N2) -eq 1) -and ((Contar $vh.texto $A2) -eq 0))
Chk "estilos nuevos 1 vez" ((Contar $vh.texto 'id="acceso-v2"') -eq 1)
Chk "head cierra 1 vez" ((Contar $vh.texto '</head>') -eq 1)
Chk "formularios intactos" (((Contar $vh.texto 'id="email-form"') -eq 1) -and ((Contar $vh.texto 'id="code-form"') -eq 1) -and ((Contar $vh.texto 'id="qa-login-form"') -eq 1) -and ((Contar $vh.texto 'id="passkey-form"') -eq 1))
Chk "logo del encabezado sigue" ((Contar $vh.texto 'class="brand-logo"') -eq 1)
Chk ("largo +" + ($vh.texto.Length - $fh.texto.Length) + " (esperado +" + $esperado + ")") (($vh.texto.Length - $fh.texto.Length) -eq $esperado)
Chk ("lineas " + (Lineas $fh.texto) + " -> " + (Lineas $vh.texto) + " (+1)") ((Lineas $vh.texto) -eq ((Lineas $fh.texto) + 1))
if (-not $todoBien) {
    Mal "Algo no salio bien. Restauro desde el respaldo."
    Copy-Item -LiteralPath $bak -Destination $archHtml -Force
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "TODO BIEN en el archivo. Falta PUBLICAR: powershell -ExecutionPolicy Bypass -Command ""npx wrangler deploy"""
Write-Host ""
