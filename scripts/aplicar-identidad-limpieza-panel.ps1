# aplicar-identidad-limpieza-panel.ps1 - Ojo Guard MS: saca del servidor las pruebas de diagnostico de Didit (sonda, matriz y variantes) que se dejaron para investigar el error 500 del Sandbox.
# Ahora la verificacion anda en vivo (03/11/2026). Esas pruebas mandaban pedidos de mas a Didit cuando algo fallaba (incluso con la selfie real). Queda un registro corto de lo que contesta Didit (estado, tipo y comienzo del cuerpo), sin selfie ni DNI.
# Cambia SOLO src\index.ts (respaldo .bak-idlimpieza). Va en la carpeta del PANEL (la que tiene wrangler.toml). No cambia la app ni el resultado de la verificacion. Requiere aplicar-identidad-estado-panel.ps1. Al final publica el panel solo.
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
if ((Contar (Leer (Join-Path $raiz "src\index.ts")).texto 'function multipartDidit') -eq 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
$cambios = @(
    @('src\index.ts', 'Didit: sacar la sonda y la matriz de diagnostico', '  } catch (error) {
    // Prueba chica: si Didit corta la conexion apenas llega un pedido grande (clave invalida o tamano), una prueba con una imagen diminuta deja ver el motivo real.
    let sonda = "sin respuesta";
    try {
      const f2 = new FormData();
      f2.append("issuing_state", "ARG");
      f2.append("services", "arg_renaper");
      f2.append("document_number", "12345678");
      f2.append("gender", "M");
      const chica = Uint8Array.from(atob("/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA="), (c) => c.charCodeAt(0));
      f2.append("selfie", new Blob([chica], { type: "image/jpeg" }), "chica.jpg");
      const r2 = await fetch("https://verification.didit.me/v3/database-validation/", { method: "POST", headers: { "x-api-key": env.DIDIT_API_KEY ?? "" }, body: f2 });
      sonda = r2.status + " " + (await r2.text().catch(() => "")).slice(0, 300);
    } catch (error2) {
      sonda = "tambien falla: " + String(error2);
    }
    // Pedidos de prueba de distintos tamanos (bytes al azar con cabecera de JPEG): Didit contesta 400 a todos si el pedido pasa; si se corta la conexion, ese tamano no pasa.
    const matriz: string[] = [];
    for (const [kb, conVd] of [[1, true], [100, false], [300, false], [520, false], [1024, false]] as Array<[number, boolean]>) {
      try {
        const f3 = new FormData();
        f3.append("issuing_state", "ARG");
        f3.append("services", "arg_renaper");
        f3.append("document_number", "12345678");
        f3.append("gender", "M");
        if (conVd) f3.append("vendor_data", "prueba");
        const falsos = new Uint8Array(kb * 1024);
        for (let o = 0; o < falsos.length; o += 65536) crypto.getRandomValues(falsos.subarray(o, Math.min(o + 65536, falsos.length)));
        falsos[0] = 0xff;
        falsos[1] = 0xd8;
        falsos[2] = 0xff;
        f3.append("selfie", new Blob([falsos], { type: "image/jpeg" }), "prueba.jpg");
        const emp3 = new Request("https://verification.didit.me/v3/database-validation/", { method: "POST", body: f3 });
        const cu3 = await emp3.arrayBuffer();
        const r3 = await fetch("https://verification.didit.me/v3/database-validation/", { method: "POST", headers: { "x-api-key": env.DIDIT_API_KEY ?? "", "content-type": emp3.headers.get("content-type") ?? "multipart/form-data" }, body: cu3 });
        matriz.push(kb + "k=" + r3.status);
      } catch {
        matriz.push(kb + "k=CORTA");
      }
    }
    console.error("didit_unreachable", String(error), "bytes=" + tamCuerpo, "sonda=" + sonda, "matriz=" + matriz.join(" "));
    return json({ error: "identity_unreachable" }, 502);
', '  } catch (error) {
    console.error("didit_unreachable", String(error).slice(0, 200), "bytes=" + tamCuerpo);
    return json({ error: "identity_unreachable" }, 502);
'),
    @('src\index.ts', 'Didit: sacar las variantes de diagnostico y dejar un registro corto', '  if (!respuesta.ok || !datos) {
    // Diagnostico: lo que contesto Didit (tipo, largo y cuerpo) y lo que se le mando (selfie en bytes, largo del DNI, sexo).
    const encabezadosDidit: string[] = [];
    respuesta.headers.forEach((valor, nombre) => encabezadosDidit.push(nombre + ": " + valor));
    console.error("didit_failed", "status=" + respuesta.status, "tipo=" + (respuesta.headers.get("content-type") ?? "-"), "largo=" + texto.length, "cuerpo=" + JSON.stringify(texto.slice(0, 900)), "selfie=" + bytes.length, "dni=" + documento.length, "sexo=" + sexo, "encabezados=" + JSON.stringify(encabezadosDidit.join(" | ")), "clave:", formaClave);
    if (respuesta.status >= 500) {
      // Didit se rompio por dentro (500): se prueban variantes del mismo pedido para ver cual lo hace fallar. Se anota cada resultado.
      const chica = Uint8Array.from(atob("/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA="), (c) => c.charCodeAt(0));
      const base: Array<[string, string]> = [["issuing_state", "ARG"], ["services", "arg_renaper"], ["document_number", documento], ["gender", sexo]];
      // Segunda ronda: Didit acepta la selfie real (no da 400 de imagen) y se rompe adentro. Se prueba una imagen valida SIN cara, otro DNI y otro sexo, para ver si el 500 depende de la cara o de los datos.
      const gris = Uint8Array.from(atob("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"), (c) => c.charCodeAt(0));
      const otroDni = base.map(([clave, valor]): [string, string] => (clave === "document_number" ? [clave, "20123456"] : [clave, valor]));
      const otroSexo = base.map(([clave, valor]): [string, string] => (clave === "gender" ? [clave, "F"] : [clave, valor]));
      const pruebas: Array<[string, Array<[string, string]>, Uint8Array]> = [
        ["imagenSinCara", base, gris],
        ["imagenSinCaraConVd", [...base, ["vendor_data", "prueba"]], gris],
        ["otroDni", otroDni, bytes],
        ["otroSexo", otroSexo, bytes],
        ["otroDniSinCara", otroDni, gris],
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
    return json({ error: "identity_provider_error", status: respuesta.status }, 502);
  }
', '  if (!respuesta.ok || !datos) {
    // Se anota lo que contesto Didit (estado, tipo y el comienzo del cuerpo) para poder reclamar; nunca la selfie ni el DNI.
    console.error("didit_failed", "status=" + respuesta.status, "tipo=" + (respuesta.headers.get("content-type") ?? "-"), "cuerpo=" + JSON.stringify(texto.slice(0, 300)), "cf-ray=" + (respuesta.headers.get("cf-ray") ?? "-"));
    return json({ error: "identity_provider_error", status: respuesta.status }, 502);
  }
'),
    @('src\index.ts', 'Didit: sacar la funcion de pedidos de prueba', '// Diagnostico: arma un pedido multipart (campos de texto + una selfie) con su propio limite.
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

', '// Las pruebas de diagnostico de Didit (sonda, matriz y variantes) se sacaron el 03/11/2026: la verificacion ya anda en vivo.

'),
    @('src\index.ts', 'Didit: sacar el registro de la forma de la clave', '  const formaClave = "largo=" + claveCruda.length + "/" + claveDidit.length + (/\s/.test(claveDidit) ? " con-espacios" : "") + (claveCruda !== claveDidit ? " limpiada" : "");
', '  // (la forma de la clave ya no se anota en el registro)
')
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
    if (Test-Path ($ruta + ".bak-idlimpieza")) { Mal ("Ya existe " + $t + ".bak-idlimpieza. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-idlimpieza"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-idlimpieza): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-idlimpieza") -Destination $ruta -Force }
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
Ok "LISTO: las pruebas de diagnostico de Didit ya no estan en el servidor."
Write-Host ""
