# aplicar-mapa-pestanas-lista-panel.ps1 - La lista de abajo con dos pestanas: Personas | Dispositivos (como Buscar de Apple).
# Luciano (16/10/2026): "personas/dispositivos". Ahora la lista tiene dos pestanas, cada una con cuantos hay ("Personas - 2", "Dispositivos - 3"), y se ve una
# sola a la vez; ya no hay que recorrer todo junto ni se ven los titulos FAMILIA / DISPOSITIVOS. La fila plegada de abajo ES el selector: tocar una pestana
# abre la lista en esa. Sin personas en la familia, queda solo "Dispositivos". En la compu (consola) la lista no cambia. Nada se pierde.
# Requiere aplicar-mapa-lista-fila-panel.ps1. Va en la carpeta del PANEL (la que tiene wrangler.toml). Toca src\panel-mapa.txt y
# src\panel-explanations.css. Respaldo .bak-listapest. Al final publica el panel solo. No hace falta build.
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
foreach ($f in @("src\panel-mapa.txt", "src\panel-explanations.css")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
$mapaTexto = (Leer (Join-Path $raiz "src\panel-mapa.txt")).texto
if ((Contar $mapaTexto 'data-lista="personas"') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $mapaTexto '"ogm hidden ogm-plegada"') -ne 1) { Mal "Falta aplicar antes aplicar-mapa-lista-fila-panel.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\panel-explanations.css")).texto '/* Botones en pastilla (como el dibujo de la consola). */') -ne 1) { Mal "Falta aplicar antes los pasos de la consola (pestanas, ayudas, equipos)."; return }
$cambios = @(
    @('src\panel-mapa.txt', 'pestanas: el selector en la lista', '      <h2>Tus dispositivos</h2>', '      <h2>Tus dispositivos</h2>
      <div class="ogm-pestanas" role="group" aria-label="Personas o dispositivos"><button type="button" data-lista="personas" class="on">Personas</button><button type="button" data-lista="dispositivos">Dispositivos</button></div>'),
    @('src\panel-mapa.txt', 'pestanas: contadores y pestana activa', '  $(".ogm-lado h2", raiz).textContent = personas.length ? "Familia y equipos" : "Tus dispositivos";', ('  $(".ogm-lado h2", raiz).textContent = personas.length ? "Familia y equipos" : "Tus dispositivos";
  // Pestanas de la lista (en la app): Personas / Dispositivos, como en Buscar de Apple. Sin personas, solo queda Dispositivos.
  const pestPersonas = $(''[data-lista="personas"]'', raiz);
  const pestDispositivos = $(''[data-lista="dispositivos"]'', raiz);
  if (pestPersonas && pestDispositivos) {
    if (!personas.length || (estado.pestanaLista !== "personas" && estado.pestanaLista !== "dispositivos")) estado.pestanaLista = personas.length ? "personas" : "dispositivos";
    pestPersonas.textContent = `Personas ' + [char]0x00b7 + ' ${personas.length}`;
    pestDispositivos.textContent = `Dispositivos ' + [char]0x00b7 + ' ${dispositivos.length}`;
    pestPersonas.hidden = !personas.length;
    pestPersonas.classList.toggle("on", estado.pestanaLista === "personas");
    pestDispositivos.classList.toggle("on", estado.pestanaLista === "dispositivos");
  }')),
    @('src\panel-mapa.txt', 'pestanas: se ve una sola a la vez', '  $(''[data-ogm="lista"]'', raiz).innerHTML = personas.length
    ? `<li class="ogm-grupo">FAMILIA</li>${personas.map(fila).join("")}<li class="ogm-grupo">DISPOSITIVOS</li>${dispositivos.map(fila).join("")}`
    : dispositivos.map(fila).join("");', '  // En la app se ve una sola pestana a la vez (sin los titulos FAMILIA / DISPOSITIVOS); en la compu sigue todo junto.
  $(''[data-ogm="lista"]'', raiz).innerHTML = EN_APP
    ? (estado.pestanaLista === "personas" ? personas : dispositivos).map(fila).join("")
    : personas.length
      ? `<li class="ogm-grupo">FAMILIA</li>${personas.map(fila).join("")}<li class="ogm-grupo">DISPOSITIVOS</li>${dispositivos.map(fila).join("")}`
      : dispositivos.map(fila).join("");'),
    @('src\panel-mapa.txt', 'pestanas: tocar una pestana abre la lista en esa', '    if (boton.dataset.rango) return elegirRango(boton.dataset.rango);', '    if (boton.dataset.lista) {
      // Plegada: abre la lista en esa pestana. Abierta: otra pestana la cambia; tocar la que ya esta marcada la vuelve a plegar.
      const abrirLista = raiz.classList.contains("ogm-plegada") || estado.pestanaLista !== boton.dataset.lista;
      estado.pestanaLista = boton.dataset.lista;
      if (EN_APP) plegar(!abrirLista);
      return dibujar();
    }
    if (boton.dataset.rango) return elegirRango(boton.dataset.rango);'),
    @('src\panel-explanations.css', 'mapa: pestanas de la lista', '/* Botones en pastilla (como el dibujo de la consola). */', '/* Lista de abajo con dos pestanas, como en Buscar de Apple: "Personas" y "Dispositivos" (cada una con cuantos hay). Se ve una sola a la vez, y
   la fila plegada ES el selector: tocar una pestana abre la lista en esa. (Pedido de Luciano, 16/10/2026: "personas/dispositivos".) */
.ogm-pestanas { display: none; }
@media (max-width: 899px) {
  html.app-mapa #og-mapa .ogm-lado h2 { display: none; }
  html.app-mapa #og-mapa .ogm-lado .ogm-pestanas { display: flex; flex: 1 1 auto; gap: 3px; padding: 3px; border: 1px solid var(--ogm-linea); border-radius: 12px; }
  html.app-mapa #og-mapa.ogm-plegada.ogm-sin-elegir .ogm-lado > .ogm-pestanas.ogm-pestanas.ogm-pestanas { display: flex; }
  html.app-mapa #og-mapa .ogm-pestanas button { flex: 1 1 0; padding: 6px 8px; border-radius: 9px; font-size: 0.78rem; font-weight: 700; color: var(--ogm-suave); white-space: nowrap; }
  html.app-mapa #og-mapa .ogm-pestanas button.on { background: var(--ogm-oro-fondo); color: var(--ogm-oro-vivo); }
  html.app-mapa #og-mapa .ogm-pestanas button[hidden] { display: none; }
}

/* Botones en pastilla (como el dibujo de la consola). */')
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
    if (Test-Path ($ruta + ".bak-listapest")) { Mal ("Ya existe " + $t + ".bak-listapest. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-listapest"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-listapest): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-listapest") -Destination $ruta -Force }
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
Ok "LISTO: el panel quedo publicado. Cerra la app y abrila de nuevo: abajo hay dos pestanas, Personas y Dispositivos."
Write-Host ""
