# aplicar-por-las-dudas-correo-panel.ps1 - Por las dudas: al elegir un referente, la pagina te muestra el mail completo y te pide confirmarlo.
# Luciano (17/10/2026), segunda prueba: cargo marinaflombaum@gmail.com y el mail de Mariana es marianaflombaum@gmail.com. El mail con el enlace
# personal fue a otra direccion. Ahora, antes de mandar nada, la pagina dice "Le vamos a mandar el mail a esta direccion: [..]. Fijate letra por
# letra: si esta mal escrito, le llega a otra persona" y hay que aceptar. Si no, no se manda.
# Ademas (si todavia no lo tenias): el texto que explica donde esta el boton "No lo encuentro" (lo ve solo el referente, en su enlace).
# Hasta dos cambios de texto dentro de src\index.ts, solo en la pagina de Por las dudas. Requiere aplicar-por-las-dudas-panel.ps1.
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Respaldo .bak-pldcorreo. Al final publica el panel solo.
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
$indice = Join-Path $raiz "src\index.ts"
if (-not (Test-Path $indice)) { Mal "No encuentro src\index.ts en esta carpeta."; return }
$f = Leer $indice
if ((Contar $f.texto 'Fijate letra por letra') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $f.texto 'async function pldApiDuenio') -ne 1) { Mal "Falta aplicar antes aplicar-por-las-dudas-panel.ps1."; return }
$yaDonde = ((Contar $f.texto 'id="dondeBoton"') -ne 0)
if ($yaDonde) { Avi "El texto de donde esta el boton No lo encuentro ya estaba. Solo agrego la confirmacion del mail." }
$cambios = @()
if (-not $yaDonde) { $cambios += ,@('la pagina explica donde esta el boton No lo encuentro', '<small class="suave">Hasta 5. Le llega un mail con su enlace personal y tiene que aceptar.</small></div>', '<small class="suave">Hasta 5. Le llega un mail con su enlace personal y tiene que aceptar.</small>
<p id="dondeBoton" class="suave"><b>\u00bfD\u00f3nde est\u00e1 el bot\u00f3n \u201cNo lo encuentro\u201d?</b> Lo ve solo tu referente, en su enlace personal, despu\u00e9s de aceptar. Vos no ten\u00e9s que apretar nada. Para probarlo, abr\u00ed su enlace en otro navegador (o en una ventana privada) y acept\u00e1.</p></div>') }
$cambios += ,@('la pagina pide confirmar el mail antes de mandar', '$("rAgregar").onclick=function(){accion({accion:"agregar",name:$("rNombre").value,email:$("rCorreo").value},"Listo: le mandamos el mail a tu referente.").then(', '$("rAgregar").onclick=function(){var cc=$("rCorreo").value.trim();if(cc&&!confirm("Le vamos a mandar el mail a esta direcci\u00f3n: ["+cc+"]. Fijate letra por letra: si est\u00e1 mal escrito, le llega a otra persona. \u00bfEst\u00e1 bien escrito?"))return;accion({accion:"agregar",name:$("rNombre").value,email:$("rCorreo").value},"Listo: le mandamos el mail a tu referente.").then(')
$ok = $true
foreach ($c in $cambios) {
    $cuantos = Contar $f.texto (Ajustar $c[1] $f.crlf)
    if ($cuantos -eq 1) { Ok ($c[0] + ": 1") } else { Mal ($c[0] + ": " + $cuantos + " (esperaba 1)"); $ok = $false }
}
if (-not $ok) { Mal "Alguna ancla no coincide. No toco nada. Mandame esta pantalla."; return }
if (Test-Path ($indice + ".bak-pldcorreo")) { Mal "Ya existe src\index.ts.bak-pldcorreo. No toco nada."; return }
Copy-Item -LiteralPath $indice -Destination ($indice + ".bak-pldcorreo")
Ok "Respaldo creado: src\index.ts.bak-pldcorreo"
$nuevo = $f.texto
$esperado = $f.texto.Length
foreach ($c in $cambios) {
    $a = Ajustar $c[1] $f.crlf; $r = Ajustar $c[2] $f.crlf
    $nuevo = $nuevo.Replace($a, $r)
    $esperado = $esperado + ($r.Length - $a.Length)
}
[System.IO.File]::WriteAllText($indice, $nuevo, (New-Object System.Text.UTF8Encoding($f.bom)))
$v = Leer $indice
if (($v.texto.Length -ne $esperado) -or ((Contar $v.texto 'Fijate letra por letra') -ne 1) -or ((Contar $v.texto 'id="dondeBoton"') -ne 1)) {
    Mal "Algo no salio bien. Restauro src\index.ts desde el respaldo."
    Copy-Item -LiteralPath ($indice + ".bak-pldcorreo") -Destination $indice -Force
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Ok ("src\index.ts: largo " + $v.texto.Length + " (esperado " + $esperado + ")")
Write-Host ""
Ok "Archivo listo. Ahora publico el panel..."
& npx.cmd wrangler deploy
if ($LASTEXITCODE -ne 0) { Mal "No se pudo publicar el panel. Mandame esta pantalla."; return }
Write-Host ""
Ok "LISTO: al elegir un referente, la pagina te pide confirmar el mail letra por letra, y explica donde esta el boton No lo encuentro."
Write-Host ""
