# Genera scripts/aplicar-consola-configuracion-panel.ps1 (instalador de 3 archivos de la consola) a partir de orig/ (lo que tiene Luciano) y nuevo/ (lo que arma hacer_consola.py).
# Reusa el motor de los instaladores anteriores de la consola (anclas exactas, respaldo, verificacion, restauracion, publicar) y le suma dos controles:
#   - antes de tocar nada: la huella SHA-256 de cada archivo tiene que ser la de la foto del 20/10/2026 (si no, no toca nada);
#   - despues de escribir: la huella de cada archivo tiene que ser la esperada (si no, restaura desde los respaldos).
import re, hashlib, sys, os
AQUI = os.path.dirname(os.path.abspath(__file__))
R = os.path.join(AQUI, '..') + '/'                      # la carpeta scripts/ (ahi estan el motor y el instalador que se genera)
D = os.environ.get('CONSOLA_DIR', os.getcwd()) + '/'    # carpeta de trabajo con orig/ (los archivos de Luciano) y nuevo/ (lo que arma hacer_consola.py)
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

def L(p): return open(D + p, 'rb').read().decode('utf-8').replace('\r\n', '\n')
sha = lambda t: hashlib.sha256(t.encode('utf-8')).hexdigest()
ARCH = ['panel-index.html', 'panel-app.txt', 'panel-history.css']
O = {f: L('orig/' + f) for f in ARCH}
N = {f: L('nuevo/' + f) for f in ARCH}

# huellas de la foto (INVENTARIO del 20/10/2026 14:05)
INV = {}
for linea in open(os.path.join(AQUI, 'huellas-20-10-2026.txt'), encoding='utf-8'):
    if '|' not in linea: continue
    nombre, _, h = [x.strip() for x in linea.split('|')]
    INV[nombre] = h
for f in ARCH:
    assert sha(O[f]) == INV[f], (f, sha(O[f]), INV[f])

# ---------- panel-index.html ----------
o, n = O['panel-index.html'], N['panel-index.html']
ancla_style = '    <style>button.location-guide{display:flex'
i = n.index('    <script>\n      /* Accesibilidad compartida'); j = n.index(ancla_style)
script_acc = n[i:j]
assert o.count(ancla_style) == 1 and n.count(ancla_style) == 1
tab_viejo = '<button class="bottom-tab" data-view="account" type="button"><span class="tab-icon" aria-hidden="true">○</span><span>Cuenta</span></button>'
tab_nuevo = '<button class="bottom-tab" data-view="account" type="button"><span class="tab-icon" aria-hidden="true">&#9881;&#65038;</span><span>Configuración</span></button>'
css_viejo = '<link rel="stylesheet" href="/theme-gold-v2.css" />'
css_nuevo = '<link rel="stylesheet" href="/theme-gold-v2.css?v=cfg1" />'
js_viejo = '<script type="module" src="/app-v9.js?v=7"></script>'
js_nuevo = '<script type="module" src="/app-v9.js?v=8"></script>'
ini_cuenta = '        <section id="account" class="dashboard-section" data-views="account">'
ini_items = '        <section id="items" class="dashboard-section" data-views="devices">'
reg_viejo = o[o.index(ini_cuenta):o.index(ini_items)]
reg_nuevo = n[n.index(ini_cuenta):n.index(ini_items)]
cambios_html = [
    ('acceso: se aplica la accesibilidad guardada antes de dibujar', ancla_style, script_acc + ancla_style),
    ('pestana Cuenta pasa a Configuracion', tab_viejo, tab_nuevo),
    ('version nueva de los estilos', css_viejo, css_nuevo),
    ('version nueva del programa', js_viejo, js_nuevo),
    ('pantalla de Configuracion (las tarjetas de antes pasan intactas)', reg_viejo, reg_nuevo),
]
# simulacion: aplicar en orden sobre el original tiene que dar exactamente nuevo/
t = o
for etiqueta, a, b in cambios_html:
    assert t.count(a) == 1, (etiqueta, t.count(a))
    t = t.replace(a, b)
    assert t.count(b) == 1, (etiqueta, 'nuevo', t.count(b))
assert t == n, 'el html no coincide con nuevo/'

# ---------- panel-app.txt ----------
oa, na = O['panel-app.txt'], N['panel-app.txt']
fin_js = 'setTimeout(qaCargar, 2000);'
assert oa.endswith(fin_js) and oa.count(fin_js) == 1 and na.startswith(oa)
cambios_js = [('programa de Configuracion', fin_js, fin_js + na[len(oa):])]
assert oa.replace(fin_js, cambios_js[0][2]) == na

# ---------- panel-history.css ----------
oc, nc = O['panel-history.css'], N['panel-history.css']
cola_css = '.face-refund-note:empty {\n  display: none;\n}\n'
assert oc.endswith(cola_css) and oc.count(cola_css) == 1 and nc.startswith(oc)
cambios_css = [('estilos de Configuracion', cola_css, cola_css + nc[len(oc):])]
assert oc.replace(cola_css, cambios_css[0][2]) == nc

def fila(archivo, c):
    return "    @('src\\%s', %s, %s, %s)" % (archivo, psq(c[0]), psq(c[1]), psq(c[2]))
filas = [fila('panel-index.html', c) for c in cambios_html] + [fila('panel-app.txt', c) for c in cambios_js] + [fila('panel-history.css', c) for c in cambios_css]
cambios = '$cambios = @(\n' + ',\n'.join(filas) + '\n)\n'

orig_tabla = '$originales = @{\n' + '\n'.join("    'src\\%s' = '%s'" % (f, sha(O[f])) for f in ARCH) + '\n}\n'
final_tabla = '$finales = @{\n' + '\n'.join("    'src\\%s' = '%s'" % (f, sha(N[f])) for f in ARCH) + '\n}\n'

cabeza = '''# aplicar-consola-configuracion-panel.ps1 - Consola (Ojo Guard MS): la pestana "Cuenta" pasa a ser "Configuracion", ordenada por categorias (como los Ajustes de un celular).
# Luciano (20/10/2026): "todo lo configurable (lo que no es de todos los dias) va en Configuracion, mas limpio, como los Ajustes de un telefono". Etapa 2: la consola.
# Que cambia:
#  - La pestana de abajo "Cuenta" se llama "Configuracion" (con un engranaje). Al tocarla se ve una lista: Cuenta y seguridad, Avisos, Tu proteccion, Familia y lugares,
#    Equipos y pulseras, Reconocimiento facial, Apariencia y accesibilidad. Cada una abre su pantalla, con una flecha para volver (el boton Atras del telefono tambien vuelve).
#  - Las tarjetas de antes (correo, proteccion de ingreso, codigo de verificacion, avisos, pregunta de emergencia, reconocimiento facial y personas autorizadas) son las mismas,
#    con los mismos botones: solo cambian de lugar.
#  - "Tu proteccion" abre la pagina de Configuracion de Tu proteccion (el boton OG de arriba sigue para lo de todos los dias: Modo Cautela y Modo Guardian).
#  - "Familia y lugares" y "Equipos y pulseras" son atajos a donde ya esta cada cosa (el mapa, Mis Equipos, invitar, agregar un equipo, la presentacion de las pulseras). No se duplica nada.
#  - "Apariencia y accesibilidad": el boton de modo claro / noche (adentro del panel ya no esta arriba; en la pantalla de acceso sigue donde estaba) y el tamano del texto,
#    el alto contraste y los botones mas grandes (se recuerdan en este dispositivo y valen tambien en Tu proteccion).
#  - En el modo de emergencia, Configuracion sigue oculta, como antes lo estaba Cuenta.
# Mapa y Familia, Mis Equipos y Evidencias no se tocan. No se saca nada: todo lo que habia sigue (mismos botones y mismos campos).
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Toca src\\panel-index.html, src\\panel-app.txt y src\\panel-history.css, y solo si son los de la foto del 20/10/2026
# (se comprueba con una huella SHA-256; si no, no toca nada). Respaldo .bak-cfgconsola. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
foreach ($f in @("src\\panel-index.html", "src\\panel-app.txt", "src\\panel-history.css")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\\panel-index.html")).texto 'id="cfg-lista"') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
function ShaTexto([string]$t) {
    $h = [System.Security.Cryptography.SHA256]::Create()
    return ([System.BitConverter]::ToString($h.ComputeHash([System.Text.Encoding]::UTF8.GetBytes(($t -replace "`r`n", "`n"))))).Replace("-", "").ToLower()
}
''' + orig_tabla + final_tabla + '''foreach ($k in $originales.Keys) {
    $huella = ShaTexto (Leer (Join-Path $raiz $k)).texto
    if ($huella -ne $originales[$k]) { Mal ($k + " no es el de la foto del 20/10/2026 (huella " + $huella + "). No toco nada. Mandame esta pantalla."); return }
}
Ok "Los tres archivos son los de la foto del 20/10/2026"
'''
cola = tpl[tpl.index('$descargas = @()'):]
cola = cola.replace('.bak-audioandroid', '.bak-cfgconsola')
# huella final de cada archivo (ademas del largo)
v_ant = '''foreach ($d in $descargas) { Chk ($d[1] + ": verificado") ((Sha (Join-Path $raiz $d[1])) -eq $d[2]) }'''
v_nue = '''foreach ($k in $archivos.Keys) { Chk ($k + ": huella final") ((ShaTexto (Leer (Join-Path $raiz $k)).texto) -eq $finales[$k]) }
''' + v_ant
assert cola.count(v_ant) == 1
cola = cola.replace(v_ant, v_nue)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: la consola quedo publicada. Abrila con Ctrl+F5 y toca Configuracion (la pestana de abajo, donde antes decia Cuenta)."\n', cola)
assert 'bak-audioandroid' not in cola and 'LISTO: la consola quedo publicada' in cola and '$finales[$k]' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127]
assert not bad, set(bad)
salida = R + 'aplicar-consola-configuracion-panel.ps1'
open(salida, 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('escrito', salida, len(total), 'caracteres', total.count('\n'), 'lineas')
print('huellas originales:', {f: sha(O[f])[:12] for f in ARCH})
print('huellas finales   :', {f: sha(N[f])[:12] for f in ARCH})
