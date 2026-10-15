# aplicar-consola-equipos-panel.ps1 - Consola (Ojo Guard MS), paso 3: Mis Equipos mas limpio.
#  - En cada equipo quedan a la vista cuatro botones: Solicitar evidencia, Localizar ahora, Hacer sonar (o Detener sonido, segun corresponda
#    ahora) y Activar Modo perdido (o Desactivar). Al hacer sonar, el boton pasa solo a "Detener sonido"; y al activar Modo perdido, a "Desactivar".
#  - Todo lo demas (la accion contraria, Detectar cerca y Quitar este dispositivo) se despliega con "Mas acciones". No se saca ninguna funcion.
# Requiere los pasos 1 y 2. Va en la carpeta del PANEL (la que tiene wrangler.toml). Toca src\panel-app.txt y src\panel-explanations.css.
# Respaldo .bak-equipos. Al final publica el panel solo.
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
if ((Contar (Leer (Join-Path $raiz "src\panel-app.txt")).texto 'function organizarAcciones(') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\panel-explanations.css")).texto '/* Botones en pastilla (como el dibujo de la consola). */') -ne 1) { Mal "Falta aplicar antes los pasos 1 y 2 de la consola."; return }
$cambios = @(
    @('src\panel-app.txt', 'mis equipos: organizar las acciones (Mas acciones)', 'const ACTION_PAIRS = [', ('// Mis Equipos: lo de todos los d' + [char]0x00ed + 'as queda a la vista (pedir evidencia, ubicar, y sonar o detener y Modo perdido activar o desactivar,
// seg' + [char]0x00fa + 'n lo que corresponda ahora). El resto (la acci' + [char]0x00f3 + 'n contraria, Detectar cerca y Quitar este dispositivo) se despliega con "M' + [char]0x00e1 + 's acciones".
// No se saca nada: todos los botones siguen en la tarjeta y se muestran u ocultan nada m' + [char]0x00e1 + 's.
const masAbiertos = new Set();
function organizarAcciones(card, deviceId) {
  const actions = card.querySelector(".actions");
  if (!actions) return;
  const state = deviceCommandState[deviceId] || {};
  const secundarias = new Set(["scan-nearby"]);
  for (const pair of ACTION_PAIRS) {
    if (!card.querySelector(`[data-command="${pair.on}"]`) || !card.querySelector(`[data-command="${pair.off}"]`)) continue;
    secundarias.add(state[pair.stateKey] === true ? pair.on : pair.off);
  }
  for (const boton of actions.querySelectorAll("[data-command]")) boton.parentElement.classList.toggle("accion-secundaria", secundarias.has(boton.dataset.command));
  let mas = actions.querySelector(".mas-acciones");
  const pintar = () => {
    const abierto = masAbiertos.has(deviceId);
    card.classList.toggle("mas-abierto", abierto);
    mas.textContent = abierto ? "Menos acciones ' + [char]0x25b4 + '" : "M' + [char]0x00e1 + 's acciones ' + [char]0x25be + '";
    mas.setAttribute("aria-expanded", abierto ? "true" : "false");
  };
  if (!mas) {
    mas = document.createElement("button");
    mas.type = "button"; mas.className = "mas-acciones ghost";
    mas.addEventListener("click", () => { if (masAbiertos.has(deviceId)) masAbiertos.delete(deviceId); else masAbiertos.add(deviceId); pintar(); });
    actions.append(mas);
  }
  card.classList.add("con-mas");
  pintar();
}

const ACTION_PAIRS = [')),
    @('src\panel-app.txt', 'mis equipos: reorganizar al cambiar de estado', '    offButton.classList.toggle("is-current-action", isOn);
    offButton.classList.toggle("is-recent-action", !isOn);
  }
}', '    offButton.classList.toggle("is-current-action", isOn);
    offButton.classList.toggle("is-recent-action", !isOn);
  }
  organizarAcciones(card, deviceId);
}'),
    @('src\panel-app.txt', 'mis equipos: la fila de Quitar se puede esconder', 'const removeRow = document.createElement("div"); removeRow.style.marginTop = "10px";', 'const removeRow = document.createElement("div"); removeRow.style.marginTop = "10px"; removeRow.className = "quitar-fila";'),
    @('src\panel-explanations.css', 'estilos de Mas acciones', '/* Botones en pastilla (como el dibujo de la consola). */', '/* Mis Equipos: lo de todos los dias a la vista; lo demas, en "Mas acciones". */
.device:not(.mas-abierto) .actions > div.accion-secundaria { display: none; }
.device .actions > div.accion-secundaria { order: 10; }
.actions .mas-acciones {
  grid-column: 1 / -1; order: 5; justify-self: center; width: auto;
  background: transparent; border: 0; box-shadow: none;
  color: var(--gold-text, var(--lime)); font-weight: 800; padding: 8px 16px;
  text-decoration: underline; text-underline-offset: 3px;
}
.device.con-mas:not(.mas-abierto) .quitar-fila { display: none; }

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
    if (Test-Path ($ruta + ".bak-equipos")) { Mal ("Ya existe " + $t + ".bak-equipos. No toco nada."); foreach ($x in $descargas) { $y = (Join-Path $raiz $x[1]) + ".descarga"; if (Test-Path $y) { Remove-Item -LiteralPath $y -Force } }; return }
}
$respaldados = @()
foreach ($t in $tocados) {
    $ruta = Join-Path $raiz $t
    if (Test-Path $ruta) { Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-equipos"); $respaldados += $t }
}
Ok ("Respaldos creados (.bak-equipos): " + ($respaldados -join ", "))

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
        if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-equipos") -Destination $ruta -Force }
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
