# aplicar-paradas-iphone-panel.ps1 - Ojo Guard MS: el mapa tambien reconoce paradas en telefonos que mandan pocos puntos (iPhone quieto).
# Motivo (01/11/2026, Luciano: "no muestra las paradas de esos"): con el iPhone quieto iOS no manda puntos hasta que se mueve ~150 m, asi que una parada es UN punto al llegar y otro al irse; el mapa pedia dos o mas puntos juntos durante 8 minutos y nunca la veia.
# Ahora: un punto que sigue, mucho despues, de otro punto lejano al que se llego despacio (3 km/h o menos) cuenta como parada hasta ese segundo punto. Cambia SOLO la funcion paradas() en src\panel-mapa.txt y src\panel-index.html (v=12). Respaldo .bak-paradas. Va en la carpeta del PANEL. Sin build.
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
foreach ($f in @("src\panel-mapa.txt", "src\panel-index.html")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\panel-mapa.txt")).texto 'const cerrar = (siguiente) =>') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\panel-index.html")).texto '/mapa-v1.js?v=11') -ne 1) { Mal "El mapa no esta en v=11 (falta aplicar primero aplicar-aviso-historial-panel.ps1). No toco nada."; return }
$cambios = @(
    @('src\panel-mapa.txt', 'mapa: paradas con pocos puntos (iPhone)', '/** Agrupa puntos seguidos que quedan cerca: si duran lo suficiente, es una parada. */
function paradas(puntos) {
  const lista = [];
  let grupo = [];
  const cerrar = () => {
    if (grupo.length < 2) return;
    const desde = new Date(grupo[0].en), hasta = new Date(grupo[grupo.length - 1].en);
    const minutos = (hasta - desde) / 60_000;
    if (minutos < CONFIG.paradaMinutos) return;
    const lat = grupo.reduce((s, p) => s + p.lat, 0) / grupo.length;
    const lng = grupo.reduce((s, p) => s + p.lng, 0) / grupo.length;
    lista.push({ lat, lng, desde, hasta, minutos: Math.round(minutos), direccion: grupo.find((p) => p.direccion)?.direccion || "" });
  };
  for (const punto of puntos) {
    if (!grupo.length) { grupo = [punto]; continue; }
    const centro = { lat: grupo.reduce((s, p) => s + p.lat, 0) / grupo.length, lng: grupo.reduce((s, p) => s + p.lng, 0) / grupo.length };
    if (metros(centro, punto) <= CONFIG.paradaMetros) grupo.push(punto);
    else { cerrar(); grupo = [punto]; }
  }
  cerrar();
  return lista;
}
', '/**
 * Agrupa puntos seguidos que quedan cerca: si duran lo suficiente, es una parada.
 * Telefonos que mandan pocos puntos (iPhone: con el telefono quieto iOS no manda nada hasta que se mueve ~150 m): un punto suelto
 * seguido, mucho despues, de otro punto lejano al que se llego despacio (3 km/h o menos) cuenta como una parada hasta ese segundo punto.
 */
function paradas(puntos) {
  const lista = [];
  let grupo = [];
  const cerrar = (siguiente) => {
    if (!grupo.length) return;
    const centro = { lat: grupo.reduce((s, p) => s + p.lat, 0) / grupo.length, lng: grupo.reduce((s, p) => s + p.lng, 0) / grupo.length };
    const desde = new Date(grupo[0].en);
    let hasta = new Date(grupo[grupo.length - 1].en);
    if (siguiente) {
      const hastaSiguiente = new Date(siguiente.en);
      const horas = (hastaSiguiente - hasta) / 3_600_000;
      if ((hastaSiguiente - desde) / 60_000 >= CONFIG.paradaMinutos && horas > 0 && metros(centro, siguiente) / 1000 / horas <= 3) hasta = hastaSiguiente;
    }
    const minutos = (hasta - desde) / 60_000;
    if (minutos < CONFIG.paradaMinutos) return;
    lista.push({ lat: centro.lat, lng: centro.lng, desde, hasta, minutos: Math.round(minutos), direccion: grupo.find((p) => p.direccion)?.direccion || "" });
  };
  for (const punto of puntos) {
    if (!grupo.length) { grupo = [punto]; continue; }
    const centro = { lat: grupo.reduce((s, p) => s + p.lat, 0) / grupo.length, lng: grupo.reduce((s, p) => s + p.lng, 0) / grupo.length };
    if (metros(centro, punto) <= CONFIG.paradaMetros) grupo.push(punto);
    else { cerrar(punto); grupo = [punto]; }
  }
  cerrar();
  return lista;
}
'),
    @('src\panel-index.html', 'recargar el mapa nuevo (v=12)', '<script type="module" src="/mapa-v1.js?v=11"></script>', '<script type="module" src="/mapa-v1.js?v=12"></script>')
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
    if (Test-Path ($ruta + ".bak-paradas")) { Mal ("Ya existe " + $t + ".bak-paradas. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-paradas"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-paradas): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-paradas") -Destination $ruta -Force }
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
Ok "LISTO: las paradas tambien se ven en telefonos que mandan pocos puntos. Cerra y abri la app (o recarga la pagina del mapa)."
Write-Host ""
