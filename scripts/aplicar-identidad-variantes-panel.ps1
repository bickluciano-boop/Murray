# aplicar-identidad-variantes-panel.ps1 - Ojo Guard MS: con la clave bien cargada Didit contesta 500 (error interno, HTML) a la consulta RENAPER. Cuando pasa, el servidor manda 5 variantes del pedido (sin vendor_data, con nombre y fecha, sin services, selfie chica) y anota cual funciona.
# Cambia SOLO src\index.ts (respaldo .bak-identidad-variantes). Va en la carpeta del PANEL. Requiere aplicar-identidad-clave-panel.ps1. Al final publica el panel solo.
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
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'didit_variantes') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'const claveDidit') -eq 0) { Mal "Falta aplicar primero aplicar-identidad-clave-panel.ps1. No toco nada."; return }
$cambios = @(
    @('src\index.ts', 'funcion de pedido multipart de prueba', 'export default {
  async scheduled(_controller', '// Diagnostico: arma un pedido multipart (campos de texto + una selfie) con su propio limite.
function multipartDidit(campos: Array<[string, string]>, archivo: Uint8Array) {
  const limite = "----ojoguard" + crypto.randomUUID().replace(/-/g, "");
  const codificador = new TextEncoder();
  const partes: Uint8Array[] = [];
  for (const [nombre, valor] of campos) partes.push(codificador.encode(`--${limite}\r\nContent-Disposition: form-data; name="${nombre}"\r\n\r\n${valor}\r\n`));
  partes.push(codificador.encode(`--${limite}\r\nContent-Disposition: form-data; name="selfie"; filename="selfie.jpg"\r\nContent-Type: image/jpeg\r\n\r\n`));
  partes.push(archivo);
  partes.push(codificador.encode(`\r\n--${limite}--\r\n`));
  const cuerpo = new Uint8Array(partes.reduce((suma, parte) => suma + parte.length, 0));
  let punto = 0;
  for (const parte of partes) {
    cuerpo.set(parte, punto);
    punto += parte.length;
  }
  return { cuerpo, tipo: `multipart/form-data; boundary=${limite}` };
}

export default {
  async scheduled(_controller'),
    @('src\index.ts', 'variantes del pedido cuando Didit da 500', '    return json({ error: "identity_provider_error", status: respuesta.status }, 502);', '    if (respuesta.status >= 500) {
      // Didit se rompio por dentro (500): se prueban variantes del mismo pedido para ver cual lo hace fallar. Se anota cada resultado.
      const chica = Uint8Array.from(atob("/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA="), (c) => c.charCodeAt(0));
      const base: Array<[string, string]> = [["issuing_state", "ARG"], ["services", "arg_renaper"], ["document_number", documento], ["gender", sexo]];
      const pruebas: Array<[string, Array<[string, string]>, Uint8Array]> = [
        ["sinVd", base, bytes],
        ["conDatos", [...base, ["first_name", "Prueba"], ["last_name", "Prueba"], ["date_of_birth", "1980-01-01"]], bytes],
        ["sinServices", base.filter(([clave]) => clave !== "services"), bytes],
        ["fotoChica", base, chica],
        ["conVd", [...base, ["vendor_data", "prueba"]], chica],
      ];
      const salidas = await Promise.all(pruebas.map(async ([nombre, campos, archivo]) => {
        try {
          const armado = multipartDidit(campos, archivo);
          const r = await fetch("https://verification.didit.me/v3/database-validation/", { method: "POST", headers: { "x-api-key": claveDidit, "content-type": armado.tipo }, body: armado.cuerpo, signal: AbortSignal.timeout(20000) });
          const t = await r.text();
          return nombre + "=" + r.status + " " + JSON.stringify(t.slice(0, 160));
        } catch (error) {
          return nombre + "=ERROR " + String(error).slice(0, 60);
        }
      }));
      console.error("didit_variantes", salidas.join(" | "));
    }
    return json({ error: "identity_provider_error", status: respuesta.status }, 502);')
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
    if (Test-Path ($ruta + ".bak-identidad-variantes")) { Mal ("Ya existe " + $t + ".bak-identidad-variantes. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-identidad-variantes"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-identidad-variantes): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-identidad-variantes") -Destination $ruta -Force }
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
Ok "LISTO: si Didit da 500 el servidor prueba variantes del pedido."
Write-Host ""
