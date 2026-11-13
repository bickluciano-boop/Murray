# Genera scripts/aplicar-neutro-panel.ps1 y scripts/aplicar-neutro-app.ps1: pasan los textos de Ojo Guard del voseo ("tocá", "podés", "vos") a un español neutro (tuteo: "toca", "puedes", "tú").
# Luciano (13/11/2026): "que sea mas generico; si no, usamos un español muy argentino y para ofrecer a Latinoamerica queda muy informal".
import re, sys
sys.path.insert(0, '/home/user/Murray/scripts/neutral')
import reglas_neutro as RN
R = '/home/user/Murray/scripts/'
tpl_panel = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
tpl_app = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"

tabla = "$reglas = @(\n" + ',\n'.join("    @(%s, %s, %d)" % (psq(rx), psq(nuevo), 1 if solo else 0) for rx, nuevo, solo in RN.reglas()) + "\n)\n"
buenas = "$buenas = @(" + ', '.join(psq(w) for w in sorted(RN.BUENAS)) + ")\n" + "$buenasEncl = @(" + ', '.join(psq(w) for w in sorted(RN.BUENAS_ENCLITICAS)) + ")\n"

MOTOR = r'''
# --- Las reglas (voseo -> tuteo). Cada una: expresion, reemplazo, 1 = solo si empieza en minuscula ---
''' + tabla + buenas + r'''
$opciones = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
$script:rx = @()
foreach ($r in $reglas) { $script:rx += ,@([regex]::new($r[0], $opciones), $r[1], [bool]($r[2] -eq 1)) }
$script:total = 0; $script:nuevoActual = ""; $script:soloMin = $false
function Decodificar([string]$s) {
    return [regex]::Replace($s, '\\u([0-9a-fA-F]{4})', [System.Text.RegularExpressions.MatchEvaluator]{ param($m) [string][char][Convert]::ToInt32($m.Groups[1].Value, 16) })
}
function Escapar([string]$s) {
    $sb = New-Object System.Text.StringBuilder
    foreach ($c in $s.ToCharArray()) { if ([int]$c -lt 128) { [void]$sb.Append($c) } else { [void]$sb.Append('\u' + ([int]$c).ToString('x4')) } }
    return $sb.ToString()
}
function PonerMayusculas([string]$encontrado, [string]$nuevo) {
    $letras = @((Decodificar $encontrado).ToCharArray() | Where-Object { [char]::IsLetter($_) })
    if ($letras.Count -gt 1 -and @($letras | Where-Object { -not [char]::IsUpper($_) }).Count -eq 0) { $nuevo = $nuevo.ToUpperInvariant() }
    elseif ($letras.Count -gt 0 -and [char]::IsUpper($letras[0])) { $nuevo = $nuevo.Substring(0, 1).ToUpperInvariant() + $nuevo.Substring(1) }
    if ($encontrado.Contains('\u')) { $nuevo = Escapar $nuevo }
    return $nuevo
}
$evaluador = [System.Text.RegularExpressions.MatchEvaluator]{
    param($m)
    if ($script:soloMin -and -not [char]::IsLower($m.Value[0])) { return $m.Value }
    $script:total = $script:total + 1
    return (PonerMayusculas $m.Value $script:nuevoActual)
}
function Neutralizar([string]$texto) {
    foreach ($r in $script:rx) { $script:nuevoActual = $r[1]; $script:soloMin = $r[2]; $texto = $r[0].Replace($texto, $evaluador) }
    return $texto
}
# Palabras que todavia parecen voseo (para revisarlas a mano)
function Restos([string]$texto, $hallados) {
    $t = Decodificar $texto
    $sufijos = '(?:á|é|í|ás|és|ís)'
    foreach ($m in [regex]::Matches($t, '(?<![A-Za-zÀ-ÿ0-9_])[a-záéíóúñ]{2,}' + $sufijos + '(?![A-Za-zÀ-ÿ0-9_])', 'IgnoreCase')) {
        $w = $m.Value.ToLowerInvariant(); if ($buenas -notcontains $w) { $hallados[$w] = 1 + [int]$hallados[$w] }
    }
    foreach ($m in [regex]::Matches($t, '(?<![A-Za-zÀ-ÿ0-9_])[a-záéíóúñ]{3,}(?:ala|alo|ale|ame|anos|ate|ela|elo|ele|eme|enos|ete|ila|ilo|ile|ime|inos|ite)(?![A-Za-zÀ-ÿ0-9_])')) {
        $w = $m.Value; if ($w -cmatch '^[a-z]+$' -and $buenasEncl -notcontains $w) { $hallados['~' + $w] = 1 + [int]$hallados['~' + $w] }
    }
    foreach ($m in [regex]::Matches($t, '(?<=[a-zà-ÿ,] )(?:vos|sos)(?= [a-zà-ÿ¿])|(?<![A-Za-zÀ-ÿ0-9_.])(?:Vos|Sos)(?![A-Za-zÀ-ÿ0-9_])')) {
        $hallados['"' + $m.Value + '"'] = 1 + [int]$hallados['"' + $m.Value + '"']
    }
}
'''

def cuerpo(tipo, etiqueta):
    if tipo == 'panel':
        archivos = r'''$archivos = @(Get-ChildItem -LiteralPath (Join-Path $raiz "src") -Recurse -File | Where-Object { @(".ts", ".txt", ".html", ".js") -contains $_.Extension -and $_.Name -notmatch "\.bak" })'''
        cierre = r'''Write-Host ""
Ok "Archivos listos. Ahora publico el panel..."
& npx.cmd wrangler deploy
if ($LASTEXITCODE -ne 0) { Mal "No se pudo publicar el panel. Mandame esta pantalla."; return }
Write-Host ""
Ok "LISTO: el panel quedo en espanol neutro (tuteo). Cerra la pagina y abrila de nuevo (Ctrl+F5)."
Write-Host ""
'''
    else:
        archivos = r'''$archivos = @()
if (Test-Path (Join-Path $raiz "App.tsx")) { $archivos += Get-Item -LiteralPath (Join-Path $raiz "App.tsx") }
if (Test-Path (Join-Path $raiz "app.json")) { $archivos += Get-Item -LiteralPath (Join-Path $raiz "app.json") }
if (Test-Path (Join-Path $raiz "src")) { $archivos += @(Get-ChildItem -LiteralPath (Join-Path $raiz "src") -Recurse -File | Where-Object { @(".ts", ".tsx") -contains $_.Extension -and $_.Name -notmatch "\.bak" }) }'''
        cierre = r'''Write-Host ""
Ok "Archivos listos. Reviso que la app compile (puede tardar un minuto)..."
& npx.cmd tsc --noEmit
if ($LASTEXITCODE -ne 0) {
    Mal "La revision de tipos encontro errores (arriba). Dejo todo como estaba."
    foreach ($t in $respaldados) { $ruta = Join-Path $raiz $t; Copy-Item -LiteralPath ($ruta + ".bak-''' + etiqueta + r'''") -Destination $ruta -Force }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Write-Host ""
Ok "LISTO: la app compila bien. Los textos en espanol neutro salen en la PROXIMA build (Android e iPhone)."
Write-Host ""
'''
    return archivos + r'''
if ($archivos.Count -eq 0) { Mal "No encontre archivos para revisar. Revisa que estes en la carpeta correcta."; return }
Ok ("Reviso " + $archivos.Count + " archivos...")

# --- Calcular los cambios (todavia no se escribe nada) ---
$nuevos = @{}; $viejos = @{}; $cuantos = @{}; $hallados = @{}
foreach ($a in $archivos) {
    $rel = $a.FullName.Substring($raiz.Length).TrimStart('\', '/')
    $f = Leer $a.FullName
    $script:total = 0
    $nuevo = Neutralizar $f.texto
    Restos $nuevo $hallados
    if ($nuevo -ne $f.texto) { $nuevos[$rel] = @{ texto = $nuevo; bom = $f.bom; largo = $nuevo.Length }; $cuantos[$rel] = $script:total }
}
if ($nuevos.Count -eq 0) { Avi "No hay nada para cambiar: ya estaba en espanol neutro."; return }
foreach ($k in ($nuevos.Keys | Sort-Object)) { Ok ($k + ": " + $cuantos[$k] + " cambios") }

# --- Respaldos ---
foreach ($k in $nuevos.Keys) { if (Test-Path ((Join-Path $raiz $k) + ".bak-''' + etiqueta + r'''")) { Mal ("Ya existe " + $k + ".bak-''' + etiqueta + r'''. No toco nada."); return } }
$respaldados = @()
foreach ($k in $nuevos.Keys) { $ruta = Join-Path $raiz $k; Copy-Item -LiteralPath $ruta -Destination ($ruta + ".bak-''' + etiqueta + r'''"); $respaldados += $k }
Ok ("Respaldos creados (.bak-''' + etiqueta + r'''): " + $respaldados.Count + " archivos")

# --- Escribir y verificar ---
foreach ($k in $nuevos.Keys) { [System.IO.File]::WriteAllText((Join-Path $raiz $k), $nuevos[$k].texto, (New-Object System.Text.UTF8Encoding($nuevos[$k].bom))) }
$todoBien = $true
foreach ($k in $nuevos.Keys) {
    $largo = (Leer (Join-Path $raiz $k)).texto.Length
    if ($largo -ne $nuevos[$k].largo) { Mal ($k + ": largo " + $largo + " (esperado " + $nuevos[$k].largo + ")"); $todoBien = $false }
}
if (-not $todoBien) {
    Mal "Algo no salio bien. Restauro todo desde los respaldos."
    foreach ($k in $respaldados) { $ruta = Join-Path $raiz $k; Copy-Item -LiteralPath ($ruta + ".bak-''' + etiqueta + r'''") -Destination $ruta -Force }
    Mal "Restaurado. Mandame esta pantalla."
    return
}
Ok ("Verificado: " + $nuevos.Count + " archivos escritos")
Write-Host ""
if ($hallados.Count -gt 0) {
    Avi "Quedan estas palabras que pueden ser voseo (mandame esta lista para revisarlas; pueden ser falsas alarmas):"
    Write-Host ("    " + (($hallados.GetEnumerator() | Sort-Object Name | ForEach-Object { $_.Name + " (" + $_.Value + ")" }) -join "  "))
} else { Ok "No queda ninguna palabra con pinta de voseo." }
''' + cierre

def armar(tipo, tpl, archivo, etiqueta, cabeza):
    i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))') if tipo == 'panel' else tpl.index('Ok "Carpeta correcta"')
    if tipo == 'panel':
        guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
'''
    else:
        guardas = 'Ok "Carpeta correcta"\n'
    total = cabeza + tpl[i:j] + guardas + MOTOR + cuerpo(tipo, etiqueta)
    bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»‹›✓ÀÿàÿÀ-ÿ'] 
    bad = [c for c in bad if not ('À' <= c <= 'ÿ')]
    assert not bad, set(bad)
    open(R + archivo, 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
    return len(total)

cab_panel = '''# aplicar-neutro-panel.ps1 - Ojo Guard MS (PANEL): pasa los textos del panel y del mapa del voseo ("toca", "podes" en argentino: "tocá", "podés", "vos") a un espanol neutro (tuteo: "toca", "puedes", "tu").
# Luciano (13/11/2026): "que sea mas generico; si no, usamos un espanol muy argentino y para ofrecer a Latinoamerica queda muy informal".
# Revisa todos los archivos de src\\ (.ts, .txt, .html, .js) y cambia solo palabras sueltas de una lista (tocá->toca, podés->puedes, vos->tu...), sin tocar nombres de variables. Respaldo .bak-neutro de cada archivo cambiado.
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Sin build: se ve al recargar. Al final publica el panel solo y lista palabras que podrian ser voseo y no se cambiaron.
'''
cab_app = '''# aplicar-neutro-app.ps1 - App Ojo Guard (PROXIMA build): pasa los textos de la app del voseo ("tocá", "podés", "vos") a un espanol neutro (tuteo: "toca", "puedes", "tu").
# Luciano (13/11/2026): "que sea mas generico; si no, usamos un espanol muy argentino y para ofrecer a Latinoamerica queda muy informal".
# Revisa App.tsx, app.json y src\\ (.ts, .tsx) y cambia solo palabras sueltas de una lista, sin tocar nombres de variables. Respaldo .bak-neutro de cada archivo cambiado. Si la revision de tipos falla, deja todo como estaba.
# Va en la carpeta de la APP (la que tiene app.json).
'''
# Uso: python3 generar_neutro.py panel | panel2 | app   (panel2 = segunda vuelta del panel, con respaldo .bak-neutro2)
for destino in sys.argv[1:]:
    if destino == 'panel':
        print(destino, armar('panel', tpl_panel, 'aplicar-neutro-panel.ps1', 'neutro', cab_panel))
    elif destino == 'panel2':
        print(destino, armar('panel', tpl_panel, 'aplicar-neutro2-panel.ps1', 'neutro2', cab_panel.replace('aplicar-neutro-panel.ps1', 'aplicar-neutro2-panel.ps1').replace('# Luciano (13/11/2026)', '# SEGUNDA VUELTA (palabras que quedaron en la primera). Luciano (13/11/2026)')))
    elif destino == 'app':
        print(destino, armar('app', tpl_app, 'aplicar-neutro-app.ps1', 'neutro', cab_app))
