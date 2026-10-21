# Genera scripts/aplicar-consola-identidad-panel.ps1: cambia el logo (ojo dorado en gota con fondo azul marino y 'Ojo Guard' con el punto dorado en la O) en el encabezado y en la pantalla de acceso; antes agrega a src\panel-index.html un bloque <style id="estetica-v1"> (solo apariencia: azul, blanco y dorado) y la tipografia.
# Parte del archivo tal como lo dejo aplicar-consola-configuracion-panel.ps1 (nuevo/panel-index.html, 49860 caracteres) y comprueba su huella antes y despues.
import re, hashlib
R = '/home/user/Murray/scripts/'
D = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/consola/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    out = []; conv = False
    for ch in s:
        if ord(ch) > 127:
            assert ord(ch) <= 0xFFFF
            out.append("' + [char]0x%04x + '" % ord(ch)); conv = True
        elif ch == "'": out.append("''")
        else: out.append(ch)
    t = "'" + ''.join(out) + "'"
    return '(' + t + ')' if conv else t
sha = lambda t: hashlib.sha256(t.encode('utf-8')).hexdigest()
o = open(D + 'logo_final_panel-index.html', 'rb').read().decode('utf-8').replace('\r\n', '\n')
assert len(o) == 50351
OJO = open(D + '../logo/ojo.svg.txt', encoding='utf-8').read().strip()
ojo = OJO.replace('class="ojo"', '').replace('width="44" height="26"', '').replace('ogOro', 'ogOroC').replace('<svg  ', '<svg ')
m1 = re.search(r'(<div class="device-icon device-icon-ojo">)(<svg.*?</svg>)', o, re.S)
assert m1 and o.count(m1.group(2)) == 1
css = open(R + 'consola/estetica2.css', encoding='utf-8').read().strip()
bloque = '    <style id="estetica-v2">\n' + css + '\n    </style>\n'
cierre = '  </head>'
assert o.count(cierre) == 1 and 'estetica-v2' not in o
n = o.replace(m1.group(2), ojo).replace(cierre, bloque + cierre)
cambios = ("$cambios = @(\n"
           "    @('src\\panel-index.html', 'logo nuevo en el icono del equipo', %s, %s),\n"
           "    @('src\\panel-index.html', 'estilos de identidad (azul, Modo noche, logo grande)', %s, %s)\n)\n") % (psq(m1.group(2)), psq(ojo), psq(cierre), psq(bloque + cierre))
cabeza = '''# aplicar-consola-identidad-panel.ps1 - Consola (Ojo Guard MS): identidad. Logo mas grande, botones principales en azul (el dorado queda de detalle), Modo noche tambien dentro del panel,
# el logo nuevo en el icono de cada equipo (Mis Equipos), la palabra AJUSTES completa en Configuracion, tarjetas de Evidencias y fondo del mapa en los colores nuevos (claro y noche).
# Luciano (21/10/2026): "no rompamos ningun codigo y no saquemos nada nuestro". Solo APARIENCIA: se agrega un bloque <style id="estetica-v2"> y se cambia el dibujo del icono del equipo. Ninguna funcion cambia.
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Toca solo src\\panel-index.html, y solo si es el que dejo aplicar-consola-logo-panel.ps1 (huella SHA-256 antes y despues). Respaldo .bak-consolaidentidad. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\panel-index.html"))) { Mal "No encuentro src\\panel-index.html en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-index.html")).texto 'id="estetica-v2"') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
function ShaTexto([string]$t) {
    $h = [System.Security.Cryptography.SHA256]::Create()
    return ([System.BitConverter]::ToString($h.ComputeHash([System.Text.Encoding]::UTF8.GetBytes(($t -replace "`r`n", "`n"))))).Replace("-", "").ToLower()
}
$originales = @{
    'src\\panel-index.html' = '%s'
}
$finales = @{
    'src\\panel-index.html' = '%s'
}
foreach ($k in $originales.Keys) {
    $huella = ShaTexto (Leer (Join-Path $raiz $k)).texto
    if ($huella -ne $originales[$k]) { Mal ($k + " no es el que dejo el logo de la consola (huella " + $huella + "). No toco nada. Mandame esta pantalla."); return }
}
Ok "src\\panel-index.html es el de la consola con el logo nuevo"
''' % (sha(o), sha(n))
cola = tpl[tpl.index('$descargas = @()'):]
cola = cola.replace('.bak-audioandroid', '.bak-consolaidentidad')
v_ant = '''foreach ($d in $descargas) { Chk ($d[1] + ": verificado") ((Sha (Join-Path $raiz $d[1])) -eq $d[2]) }'''
v_nue = '''foreach ($k in $archivos.Keys) { Chk ($k + ": huella final") ((ShaTexto (Leer (Join-Path $raiz $k)).texto) -eq $finales[$k]) }
''' + v_ant
assert cola.count(v_ant) == 1
cola = cola.replace(v_ant, v_nue)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: la consola quedo con la identidad nueva. Abrila con Ctrl+F5."\n', cola)
assert 'bak-audioandroid' not in cola and 'identidad nueva' in cola and '$finales[$k]' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127]
assert not bad, set(bad)
open(R + 'aplicar-consola-identidad-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
open(D + 'identidad_final_panel-index.html', 'w', encoding='utf-8', newline='').write(n)
print('ok', len(total), 'largo final', len(n))
