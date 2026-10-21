# Genera scripts/aplicar-consola-logo-panel.ps1: cambia el logo (ojo dorado en gota con fondo azul marino y 'Ojo Guard' con el punto dorado en la O) en el encabezado y en la pantalla de acceso; antes agrega a src\panel-index.html un bloque <style id="estetica-v1"> (solo apariencia: azul, blanco y dorado) y la tipografia.
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
o = open(D + 'estetica_final_panel-index.html', 'rb').read().decode('utf-8').replace('\r\n', '\n')
assert len(o) == 53793
OJO = open(D + '../logo/ojo.svg.txt', encoding='utf-8').read().strip()
def ojo(clase, ancho, alto, ident):
    t = OJO.replace('class="ojo"', 'class="%s"' % clase).replace('width="44" height="26"', 'width="%d" height="%d"' % (ancho, alto)).replace('ogOro', ident)
    assert clase in t and ident in t
    return t
m1 = re.search(r'<svg class="brand-logo".*?</svg><strong style="font-weight:300;letter-spacing:\.1em;text-transform:none">ojo guard</strong>', o, re.S)
m2 = re.search(r'<svg class="acceso-marca".*?</svg>', o, re.S)
assert m1 and m2 and o.count(m1.group(0)) == 1 and o.count(m2.group(0)) == 1
nuevo1 = ojo('brand-logo', 44, 26, 'ogOroA') + '<strong style="font-weight:600;letter-spacing:-.01em;text-transform:none;font-size:1.15em;color:var(--e-texto)"><i class="o">O</i>jo Guard</strong>'
nuevo2 = ojo('acceso-marca', 168, 101, 'ogOroB')
css = ('    <style id="logo-v1">\n'
       '      .brand-logo{vertical-align:middle;margin-right:10px;flex:none}\n'
       '      .brand .o{font-style:normal;position:relative;display:inline-block;line-height:1}\n'
       '      .brand .o::after{content:"";position:absolute;left:50%;top:54%;width:.2em;height:.2em;border-radius:50%;background:var(--e-dorado);transform:translate(-50%,-50%)}\n'
       '      .acceso-marca{filter:none !important;width:168px;height:auto}\n'
       '    </style>\n')
cierre = '  </head>'
assert o.count(cierre) == 1 and 'logo-v1' not in o
n = o.replace(m1.group(0), nuevo1).replace(m2.group(0), nuevo2).replace(cierre, css + cierre)
cambios = ("$cambios = @(\n"
           "    @('src\\panel-index.html', 'logo nuevo en el encabezado', %s, %s),\n"
           "    @('src\\panel-index.html', 'logo nuevo en la pantalla de acceso', %s, %s),\n"
           "    @('src\\panel-index.html', 'estilos del logo', %s, %s)\n)\n") % (psq(m1.group(0)), psq(nuevo1), psq(m2.group(0)), psq(nuevo2), psq(cierre), psq(css + cierre))
cabeza = '''# aplicar-consola-logo-panel.ps1 - Consola (Ojo Guard MS): logo nuevo (el ojo dorado en gota con fondo azul marino, y el nombre "Ojo Guard" con el punto dorado en la O).
# Luciano (21/10/2026): "no rompamos ningun codigo y no saquemos nada nuestro". Solo cambia la APARIENCIA: se reemplaza el dibujo del ojo del encabezado y el de la pantalla "Entra a tu cuenta" por el logo nuevo
# (dibujado en SVG, se ve nitido en cualquier tamano, en claro y en noche) y se agrega un bloque de estilos <style id="logo-v1">. No se toca ningun boton, campo, id ni programa.
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Toca solo src\\panel-index.html, y solo si es el que dejo aplicar-consola-estetica-panel.ps1 (se comprueba con una huella SHA-256 antes y despues). Respaldo .bak-logoconsola. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\panel-index.html"))) { Mal "No encuentro src\\panel-index.html en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-index.html")).texto 'id="logo-v1"') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
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
    if ($huella -ne $originales[$k]) { Mal ($k + " no es el que dejo la estetica de la consola (huella " + $huella + "). No toco nada. Mandame esta pantalla."); return }
}
Ok "src\\panel-index.html es el de la consola con el estilo nuevo"
''' % (sha(o), sha(n))
cola = tpl[tpl.index('$descargas = @()'):]
cola = cola.replace('.bak-audioandroid', '.bak-logoconsola')
v_ant = '''foreach ($d in $descargas) { Chk ($d[1] + ": verificado") ((Sha (Join-Path $raiz $d[1])) -eq $d[2]) }'''
v_nue = '''foreach ($k in $archivos.Keys) { Chk ($k + ": huella final") ((ShaTexto (Leer (Join-Path $raiz $k)).texto) -eq $finales[$k]) }
''' + v_ant
assert cola.count(v_ant) == 1
cola = cola.replace(v_ant, v_nue)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: la consola quedo con el logo nuevo. Abrila con Ctrl+F5."\n', cola)
assert 'bak-audioandroid' not in cola and 'logo nuevo' in cola and '$finales[$k]' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127]
assert not bad, set(bad)
open(R + 'aplicar-consola-logo-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
open(D + 'logo_final_panel-index.html', 'w', encoding='utf-8', newline='').write(n)
print('ok', len(total), 'largo final', len(n))
