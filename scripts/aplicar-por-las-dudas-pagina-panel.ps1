# aplicar-por-las-dudas-pagina-panel.ps1 - La pagina /por-las-dudas: campos bloqueados hasta que carguen tus datos y boton "Entrar al panel".
# Luciano (17/10/2026), con la pagina abierta sin sesion: vio "Cargando..." y escribio valores a mano que no se guardaban. Ahora:
#  - Mientras se leen tus datos, el contenido se ve apagado y no se puede tocar (no se escribe en el aire).
#  - Si falta la sesion del panel, aparece una tarjeta "Falta entrar al panel" con el boton "Entrar al panel" (lleva a /acceso-v7) y "Ya entre, probar de nuevo".
# Cuatro cambios de texto dentro de src\index.ts, solo en la pagina nueva (nada de lo que ya anda). Requiere aplicar-por-las-dudas-panel.ps1.
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Respaldo .bak-pldpag. Al final publica el panel solo.
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
if ((Contar $f.texto 'id="sinSesion"') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar $f.texto 'async function pldApiDuenio') -ne 1) { Mal "Falta aplicar antes aplicar-por-las-dudas-panel.ps1."; return }
$cambios = @(
    @('sin sesion: el error se marca', 'if(r.status===401){throw new Error("Entr\u00e1 primero al panel de Ojo Guard MS con tu cuenta y volv\u00e9 a abrir esta p\u00e1gina.")}', 'if(r.status===401){var er=new Error("Entr\u00e1 primero al panel de Ojo Guard MS con tu cuenta y volv\u00e9 a abrir esta p\u00e1gina.");er.sinSesion=true;throw er}')
    ,@('tarjeta Entrar al panel y contenido bloqueado', '<div class="tarjeta"><h2>C\u00f3mo est\u00e1s hoy</h2>', '<div id="sinSesion" class="tarjeta" style="display:none"><h2>Falta entrar al panel</h2><p>Para ver y cambiar tus referentes ten\u00e9s que entrar al panel de Ojo Guard MS con tu cuenta, <b>en este mismo navegador</b>. Entr\u00e1, y despu\u00e9s volv\u00e9 a esta p\u00e1gina.</p><p><a class="boton" href="/acceso-v7">Entrar al panel</a> <button class="sec" onclick="location.reload()">Ya entr\u00e9, probar de nuevo</button></p></div>
<div id="contenido" style="opacity:.4;pointer-events:none">
<div class="tarjeta"><h2>C\u00f3mo est\u00e1s hoy</h2>')
    ,@('el contenido cierra antes del script', '<div class="tarjeta"><h2>Registro</h2><div id="registro" class="suave">Cargando\u2026</div></div>
<script>', '<div class="tarjeta"><h2>Registro</h2><div id="registro" class="suave">Cargando\u2026</div></div>
</div>
<script>')
    ,@('al cargar se habilita; sin sesion se muestra el boton', 'api().then(pintar).catch(function(e){aviso(e.message)});', 'api().then(function(d){var c=$("contenido");c.style.opacity="";c.style.pointerEvents="";pintar(d)}).catch(function(e){if(e.sinSesion){aviso("");$("sinSesion").style.display="block";$("contenido").style.display="none"}else{aviso(e.message)}});')
)
$ok = $true
foreach ($c in $cambios) {
    $cuantos = Contar $f.texto (Ajustar $c[1] $f.crlf)
    if ($cuantos -eq 1) { Ok ($c[0] + ": 1") } else { Mal ($c[0] + ": " + $cuantos + " (esperaba 1)"); $ok = $false }
}
if (-not $ok) { Mal "Alguna ancla no coincide. No toco nada. Mandame esta pantalla."; return }
if (Test-Path ($indice + ".bak-pldpag")) { Mal "Ya existe src\index.ts.bak-pldpag. No toco nada."; return }
Copy-Item -LiteralPath $indice -Destination ($indice + ".bak-pldpag")
Ok "Respaldo creado: src\index.ts.bak-pldpag"
$nuevo = $f.texto
$esperado = $f.texto.Length
foreach ($c in $cambios) {
    $a = Ajustar $c[1] $f.crlf; $r = Ajustar $c[2] $f.crlf
    $nuevo = $nuevo.Replace($a, $r)
    $esperado = $esperado + ($r.Length - $a.Length)
}
[System.IO.File]::WriteAllText($indice, $nuevo, (New-Object System.Text.UTF8Encoding($f.bom)))
$v = Leer $indice
if (($v.texto.Length -ne $esperado) -or ((Contar $v.texto 'id="sinSesion"') -ne 1)) {
    Mal "Algo no salio bien. Restauro src\index.ts desde el respaldo."
    Copy-Item -LiteralPath ($indice + ".bak-pldpag") -Destination $indice -Force
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Ok ("src\index.ts: largo " + $v.texto.Length + " (esperado " + $esperado + ")")
Write-Host ""
Ok "Archivo listo. Ahora publico el panel..."
& npx.cmd wrangler deploy
if ($LASTEXITCODE -ne 0) { Mal "No se pudo publicar el panel. Mandame esta pantalla."; return }
Write-Host ""
Ok "LISTO: la pagina de Por las dudas ya avisa si falta entrar al panel y espera a cargar tus datos."
Write-Host ""
