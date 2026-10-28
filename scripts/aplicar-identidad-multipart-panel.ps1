# aplicar-identidad-multipart-panel.ps1 - Ojo Guard MS: el pedido a Didit se arma a mano con su limite multipart. Con wrangler tail se vio "didit_failed status=400 tipo=- largo=0": el content-type sacado de Request venia vacio (sin boundary).
# Cambia SOLO src\index.ts (respaldo .bak-identidad-multipart). Va en la carpeta del PANEL. Requiere aplicar-identidad-cuerpo-panel.ps1. Al final publica el panel solo.
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
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'const limite = "----ojoguard"') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto '"cuerpo=" + JSON.stringify') -eq 0) { Mal "Falta aplicar primero aplicar-identidad-cuerpo-panel.ps1. No toco nada."; return }
$cambios = @(
    @('src\index.ts', 'pedido multipart armado a mano (datos)', '  const form = new FormData();
  form.append("issuing_state", "ARG");
  form.append("services", "arg_renaper");
  form.append("document_number", documento);
  form.append("gender", sexo);
  form.append("vendor_data", (await hash(`ojo-guard:${email}`)).slice(0, 24));
  form.append("selfie", new Blob([bytes], { type: "image/jpeg" }), "selfie.jpg");
  const control = new AbortController();', '  // El pedido multipart se arma a mano, con su propio limite: el "content-type" que daba Request venia vacio (sin limite) y Didit contestaba 400 sin cuerpo.
  const limite = "----ojoguard" + crypto.randomUUID().replace(/-/g, "");
  const codificador = new TextEncoder();
  const partes: Uint8Array[] = [];
  const campo = (nombre: string, valor: string) => partes.push(codificador.encode(`--${limite}\r\nContent-Disposition: form-data; name="${nombre}"\r\n\r\n${valor}\r\n`));
  campo("issuing_state", "ARG");
  campo("services", "arg_renaper");
  campo("document_number", documento);
  campo("gender", sexo);
  campo("vendor_data", (await hash(`ojo-guard:${email}`)).slice(0, 24));
  partes.push(codificador.encode(`--${limite}\r\nContent-Disposition: form-data; name="selfie"; filename="selfie.jpg"\r\nContent-Type: image/jpeg\r\n\r\n`));
  partes.push(bytes);
  partes.push(codificador.encode(`\r\n--${limite}--\r\n`));
  const cuerpo = new Uint8Array(partes.reduce((suma, parte) => suma + parte.length, 0));
  let punto = 0;
  for (const parte of partes) {
    cuerpo.set(parte, punto);
    punto += parte.length;
  }
  const control = new AbortController();'),
    @('src\index.ts', 'pedido multipart armado a mano (envio)', '    const empaquetado = new Request("https://verification.didit.me/v3/database-validation/", { method: "POST", body: form });
    const cuerpo = await empaquetado.arrayBuffer();
    tamCuerpo = cuerpo.byteLength;
    respuesta = await fetch("https://verification.didit.me/v3/database-validation/", {
      method: "POST",
      headers: { "x-api-key": env.DIDIT_API_KEY, "content-type": empaquetado.headers.get("content-type") ?? "multipart/form-data" },
      body: cuerpo,
      signal: control.signal,
    });', '    tamCuerpo = cuerpo.byteLength;
    respuesta = await fetch("https://verification.didit.me/v3/database-validation/", {
      method: "POST",
      headers: { "x-api-key": env.DIDIT_API_KEY, "content-type": `multipart/form-data; boundary=${limite}` },
      body: cuerpo,
      signal: control.signal,
    });')
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
    if (Test-Path ($ruta + ".bak-identidad-multipart")) { Mal ("Ya existe " + $t + ".bak-identidad-multipart. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-identidad-multipart"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-identidad-multipart): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-identidad-multipart") -Destination $ruta -Force }
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
Ok "LISTO: el pedido a Didit ahora lleva su limite multipart."
Write-Host ""
