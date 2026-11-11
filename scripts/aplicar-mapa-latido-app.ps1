# aplicar-mapa-latido-app.ps1 - App (PROXIMA build): el mapa de Inicio se recarga solo si se cuelga.
# Luciano (11/11/2026): "muchas veces el mapa se tilda, no podes hacer ni zoom ni moverlo, y tengo que tocar otro boton de abajo para que vuelva".
# La pagina del mapa avisa cada 5 s que sigue viva (hay que aplicar antes aplicar-mapa-latido-panel.ps1). Si deja de avisar 25 s con la app abierta, la app lo recarga sola (como mucho una vez por minuto). Tambien se recarga si el motor del mapa se muere.
# Toca SOLO src\MapaEnApp.tsx (respaldo .bak-mapa-latido). Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba.
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

if (-not (Test-Path (Join-Path $raiz "app.json")) -or (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta de la APP (la que tiene app.json), no la del panel."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\MapaEnApp.tsx"))) { Mal "No encuentro src\MapaEnApp.tsx en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\MapaEnApp.tsx")).texto 'huboLatido') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
$cambios = @(
    @('src\MapaEnApp.tsx', 'mapa: contadores del latido', '  const cargadoEn = useRef(0);
', '  const cargadoEn = useRef(0);
  // Latido del mapa: la pagina avisa cada 5 s que sigue viva. Si deja de avisar (se colgo y no responde al tacto), se vuelve a cargar sola.
  const ultimoLatido = useRef(0);
  const huboLatido = useRef(false);
  const listoRef = useRef(false);
'),
    @('src\MapaEnApp.tsx', 'mapa: el latido se reinicia en cada carga', '      cargadoEn.current = Date.now();
', '      cargadoEn.current = Date.now();
      ultimoLatido.current = Date.now();
      huboLatido.current = false;
'),
    @('src\MapaEnApp.tsx', 'mapa: vigilante que recarga si se cuelga', '  function alMensaje(evento: WebViewMessageEvent) {
', '  useEffect(() => {
    listoRef.current = estado === "listo";
  }, [estado]);

  // Si el mapa deja de dar latidos (la pagina se colgo: no responde ni al zoom ni al toque), se vuelve a cargar solo. Como mucho una vez por minuto.
  // Solo vigila si ya llego al menos un latido de esta carga: con un panel sin latido no hace nada.
  useEffect(() => {
    const suscripcion = AppState.addEventListener("change", (estadoApp) => {
      if (estadoApp === "active") ultimoLatido.current = Date.now();
    });
    const intervalo = setInterval(() => {
      if (AppState.currentState !== "active" || !listoRef.current || !huboLatido.current) return;
      if (Date.now() - ultimoLatido.current > 25_000 && Date.now() - cargadoEn.current > 60_000) void cargar();
    }, 5_000);
    return () => {
      suscripcion.remove();
      clearInterval(intervalo);
    };
  }, [cargar]);

  function alMensaje(evento: WebViewMessageEvent) {
'),
    @('src\MapaEnApp.tsx', 'mapa: recibir el latido', '      if (dato.tipo === "sin_sesion") setEstado("error");
', '      if (dato.tipo === "latido") {
        ultimoLatido.current = Date.now();
        huboLatido.current = true;
        return;
      }
      if (dato.tipo === "sin_sesion") setEstado("error");
'),
    @('src\MapaEnApp.tsx', 'mapa: recargar si el motor del mapa se muere', '          onMessage={alMensaje}
', '          onMessage={alMensaje}
          // Si el motor del mapa se muere (poca memoria, segundo plano), se vuelve a cargar en vez de quedar en blanco o congelado.
          onRenderProcessGone={() => void cargar()}
          onContentProcessDidTerminate={() => void cargar()}
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
    if (Test-Path ($ruta + ".bak-mapa-latido")) { Mal ("Ya existe " + $t + ".bak-mapa-latido. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-mapa-latido"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-mapa-latido): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-mapa-latido") -Destination $ruta -Force }
        elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force }
    }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "Archivos listos. Reviso que la app compile (puede tardar un minuto)..."
& npx.cmd tsc --noEmit
if ($LASTEXITCODE -ne 0) {
    Mal "La revision de tipos encontro errores (arriba). Dejo todo como estaba."
    foreach ($t in $tocados) { $ruta = Join-Path $raiz $t; if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-mapa-latido") -Destination $ruta -Force } }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "LISTO: la app compila bien. Sale en la PROXIMA build."
Write-Host ""
