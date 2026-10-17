# aplicar-por-las-dudas-reenviar-panel.ps1 - Por las dudas: se puede mandar un enlace nuevo a un referente que ya acepto (si perdio el suyo).
# Luciano (17/10/2026): "el enlace no se le va? si lo pierde?". Hasta ahora el boton "Reenviar" solo aparecia mientras el referente no habia aceptado.
# Ahora, junto a cada referente que ya acepto, hay un boton "Mandar enlace de nuevo": pide confirmar (el enlace que tiene deja de servir), le manda el
# mail con el enlace nuevo y te lo muestra con "Copiar enlace" y "Mandar por WhatsApp". Ademas, "Sin senal hace 1 minutos" pasa a "1 minuto".
# Dos cambios de texto dentro de src\index.ts, solo en el codigo de Por las dudas. Requiere aplicar-por-las-dudas-panel.ps1.
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Respaldo .bak-pldreenv. Al final publica el panel solo.
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
if ((Contar $f.texto 'Mandar enlace de nuevo') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $f.texto 'async function pldApiDuenio') -ne 1) { Mal "Falta aplicar antes aplicar-por-las-dudas-panel.ps1."; return }
$cambios = @(
    @('el boton Reenviar tambien para quien ya acepto', 'if(x.status!=="aceptado"){var re=document.createElement("button");re.className="sec chico";re.textContent="Reenviar";re.onclick=function(){accion({accion:"reenviar",id:x.id},"Enlace reenviado.")};dr.appendChild(re);dr.appendChild(document.createTextNode(" "))}', 'var ya=x.status==="aceptado";var re=document.createElement("button");re.className="sec chico";re.textContent=ya?"Mandar enlace de nuevo":"Reenviar";re.onclick=function(){if(ya&&!confirm("Se le manda un enlace nuevo a "+x.name+" y el que tiene ahora deja de servir. \u00bfSeguro?"))return;accion({accion:"reenviar",id:x.id},"Enlace reenviado.")};dr.appendChild(re);dr.appendChild(document.createTextNode(" "));'),
    @('"Sin senal hace 1 minuto" en singular', '  return `${Math.max(1, Math.round(minutos))} minutos`;', '  const m = Math.max(1, Math.round(minutos));
  return m === 1 ? "1 minuto" : `${m} minutos`;')
)
$ok = $true
foreach ($c in $cambios) {
    $cuantos = Contar $f.texto (Ajustar $c[1] $f.crlf)
    if ($cuantos -eq 1) { Ok ($c[0] + ": 1") } else { Mal ($c[0] + ": " + $cuantos + " (esperaba 1)"); $ok = $false }
}
if (-not $ok) { Mal "Alguna ancla no coincide. No toco nada. Mandame esta pantalla."; return }
if (Test-Path ($indice + ".bak-pldreenv")) { Mal "Ya existe src\index.ts.bak-pldreenv. No toco nada."; return }
Copy-Item -LiteralPath $indice -Destination ($indice + ".bak-pldreenv")
Ok "Respaldo creado: src\index.ts.bak-pldreenv"
$nuevo = $f.texto
$esperado = $f.texto.Length
foreach ($c in $cambios) {
    $a = Ajustar $c[1] $f.crlf; $r = Ajustar $c[2] $f.crlf
    $nuevo = $nuevo.Replace($a, $r)
    $esperado = $esperado + ($r.Length - $a.Length)
}
[System.IO.File]::WriteAllText($indice, $nuevo, (New-Object System.Text.UTF8Encoding($f.bom)))
$v = Leer $indice
if (($v.texto.Length -ne $esperado) -or ((Contar $v.texto 'Mandar enlace de nuevo') -ne 1)) {
    Mal "Algo no salio bien. Restauro src\index.ts desde el respaldo."
    Copy-Item -LiteralPath ($indice + ".bak-pldreenv") -Destination $indice -Force
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Ok ("src\index.ts: largo " + $v.texto.Length + " (esperado " + $esperado + ")")
Write-Host ""
Ok "Archivo listo. Ahora publico el panel..."
& npx.cmd wrangler deploy
if ($LASTEXITCODE -ne 0) { Mal "No se pudo publicar el panel. Mandame esta pantalla."; return }
Write-Host ""
Ok "LISTO: ahora podes mandarle un enlace nuevo a un referente que ya acepto (por si perdio el suyo)."
Write-Host ""
