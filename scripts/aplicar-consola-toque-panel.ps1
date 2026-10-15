# aplicar-consola-toque-panel.ps1 - Consola (Ojo Guard MS), paso 3b: en el celular, la explicacion de cada boton aparece al mantener el dedo.
#  - Se saca la "i" chica de cada boton de un equipo. En el celular o la tablet, al mantener el dedo apretado sobre un boton (un cuarto de
#    segundo) aparece la explicacion en el mismo globito que con el mouse, y queda un momento despues de soltar.
#  - Un toque corto hace la accion como siempre. Mantener apretado para leer la explicacion NO la hace.
# Con mouse o touchpad no cambia nada (la explicacion sigue apareciendo al pasar por encima). Ninguna funcion se saca ni cambia.
# Requiere los pasos anteriores de la consola. Va en la carpeta del PANEL (la que tiene wrangler.toml). Toca src\panel-app.txt y
# src\panel-explanations.css. Respaldo .bak-toque. Al final publica el panel solo.
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
foreach ($f in @("src\panel-app.txt", "src\panel-explanations.css")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\panel-app.txt")).texto 'caja.dataset.ayudaTactil') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\panel-app.txt")).texto 'ayuda.textContent = "i";') -ne 1) { Mal "Falta aplicar antes los pasos anteriores de la consola (ayudas)."; return }
if ((Contar (Leer (Join-Path $raiz "src\panel-explanations.css")).texto '/* Botones en pastilla (como el dibujo de la consola). */') -ne 1) { Mal "Falta aplicar antes los pasos anteriores de la consola."; return }
$cambios = @(
    @('src\panel-app.txt', 'ayuda tactil: al mantener el dedo (en vez de la i)', ('    const explicacion = caja.querySelector("small");
    if (!explicacion || caja.querySelector(".hint")) continue;
    const ayuda = document.createElement("button");
    ayuda.type = "button"; ayuda.className = "hint"; ayuda.textContent = "i";
    ayuda.setAttribute("aria-label", "' + [char]0x00bf + 'Qu' + [char]0x00e9 + ' hace este bot' + [char]0x00f3 + 'n?"); ayuda.setAttribute("aria-expanded", "false");
    ayuda.addEventListener("click", () => { const abierta = caja.classList.toggle("hint-open"); ayuda.setAttribute("aria-expanded", abierta ? "true" : "false"); });
    caja.append(ayuda);
  }
}'), ('    const explicacion = caja.querySelector("small");
    const boton = caja.querySelector("button[data-command]");
    if (!explicacion || !boton || caja.dataset.ayudaTactil) continue;
    caja.dataset.ayudaTactil = "1";
    // En el celular no hay "pasar por encima": la explicaci' + [char]0x00f3 + 'n aparece mientras se mantiene el dedo apretado sobre el bot' + [char]0x00f3 + 'n (un cuarto de
    // segundo) y queda un momento despu' + [char]0x00e9 + 's de soltar. Un toque corto hace la acci' + [char]0x00f3 + 'n como siempre; mantener apretado para leer NO la hace.
    let espera = null, ocultar = null, mostrada = false;
    const esconder = () => { clearTimeout(ocultar); caja.classList.remove("hint-open"); mostrada = false; };
    boton.addEventListener("touchstart", () => {
      esconder();
      espera = setTimeout(() => { mostrada = true; caja.classList.add("hint-open"); }, 250);
    }, { passive: true });
    boton.addEventListener("touchend", () => {
      clearTimeout(espera);
      if (mostrada) ocultar = setTimeout(esconder, 2200);
    });
    boton.addEventListener("touchmove", () => { clearTimeout(espera); }, { passive: true });
    boton.addEventListener("touchcancel", esconder);
    boton.addEventListener("contextmenu", (evento) => { if (mostrada) evento.preventDefault(); });
    // Si se mantuvo apretado hasta ver la explicaci' + [char]0x00f3 + 'n, el "click" que llega al soltar no se toma como pedido de la acci' + [char]0x00f3 + 'n.
    boton.addEventListener("click", (evento) => {
      if (!mostrada) return;
      evento.preventDefault(); evento.stopImmediatePropagation();
    }, true);
  }
}')),
    @('src\panel-app.txt', 'ayuda tactil: comentario', '// Lo que explica cada boton se despliega con el "?": en el celular no hay mouse para "pasar por encima".', ('// Lo que explica cada bot' + [char]0x00f3 + 'n: con mouse, al pasar por encima (CSS); en el celular, al mantener el dedo apretado (ac' + [char]0x00e1 + ' abajo).')),
    @('src\panel-explanations.css', 'ayuda tactil: estilos (globito al mantener el dedo)', '/* Botones en pastilla (como el dibujo de la consola). */', '/* En el celular o la tablet: la explicacion aparece al mantener el dedo apretado sobre el boton (ver agregarAyudas), con el mismo globito que
   con el mouse, y sin la "i". Un toque corto hace la accion. */
@media (hover: none), (pointer: coarse) {
  .actions .hint { display: none !important; }
  .actions button[data-command] {
    padding-left: 20px; padding-right: 20px;
    -webkit-touch-callout: none; -webkit-user-select: none; user-select: none;
  }
  .actions > div > small {
    display: block;
    position: absolute; left: 0; right: 0; bottom: calc(100% + 6px); z-index: 25;
    padding: 9px 12px; border-radius: 12px;
    background: #1f1b12 !important; color: #fff8e6 !important; border: 1px solid #d6ad4b;
    font-size: 0.8rem; line-height: 1.35; text-align: left;
    box-shadow: 0 10px 28px rgba(0, 0, 0, 0.28);
    opacity: 0; visibility: hidden; pointer-events: none;
    transition: opacity 0.12s ease;
  }
}
.actions > div.hint-open > small { opacity: 1; visibility: visible; }

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
    if (Test-Path ($ruta + ".bak-toque")) { Mal ("Ya existe " + $t + ".bak-toque. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-toque"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-toque): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-toque") -Destination $ruta -Force }
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
Ok "LISTO: el panel quedo publicado. Abrilo y mandame fotos (en la compu y en el celular)."
Write-Host ""
