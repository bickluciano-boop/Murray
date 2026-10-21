# Genera scripts/aplicar-consola-estetica-panel.ps1: agrega a src\panel-index.html un bloque <style id="estetica-v1"> (solo apariencia: azul, blanco y dorado) y la tipografia.
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
o = open(D + 'nuevo/panel-index.html', 'rb').read().decode('utf-8').replace('\r\n', '\n')
assert len(o) == 49860
css = open(D + 'estetica.css', encoding='utf-8').read().strip()
bloque = ('    <link rel="preconnect" href="https://fonts.googleapis.com">\n'
          '    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500&family=Plus+Jakarta+Sans:wght@400;500;600;700&display=swap">\n'
          '    <style id="estetica-v1">\n' + css + '\n    </style>\n')
cierre = '  </head>'
assert o.count(cierre) == 1 and 'estetica-v1' not in o
n = o.replace(cierre, bloque + cierre)
cambios = "$cambios = @(\n    ,@('src\\panel-index.html', 'estilo nuevo (azul, blanco y dorado), solo apariencia', %s, %s)\n)\n" % (psq(cierre), psq(bloque + cierre))
cabeza = '''# aplicar-consola-estetica-panel.ps1 - Consola (Ojo Guard MS): estilo nuevo en azul, blanco y dorado, igual al de las paginas Tu proteccion y del camino.
# Luciano (21/10/2026): "no rompamos ningun codigo y no saquemos nada nuestro". Por eso solo cambia la APARIENCIA: se agrega un bloque de estilos al final de la cabecera de src\\panel-index.html;
# no se toca ningun boton, campo, id ni programa. Ni una funcion cambia ni se saca: Mapa y Familia, Mis Equipos, Evidencias, Configuracion, el boton OG y todo lo demas siguen igual.
# Que se ve distinto: fondo marfil con tarjetas blancas redondeadas (en modo noche, azul tinta con marfil y dorado; el boton de modo claro / noche de siempre elige cual), botones de borde suave en forma de
# pastilla, listas de Configuracion y barra de abajo mas redondeadas, campos mas suaves y la tipografia mas clara (Plus Jakarta Sans y Outfit, de Google Fonts; si no cargan, la del sistema).
# Si algo no te gusta, se vuelve atras con el respaldo .bak-esteticaconsola (o se borra el bloque <style id="estetica-v1">).
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Toca solo src\\panel-index.html, y solo si es el que dejo aplicar-consola-configuracion-panel.ps1 (se comprueba con una huella SHA-256 antes y despues). Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\panel-index.html"))) { Mal "No encuentro src\\panel-index.html en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-index.html")).texto 'id="estetica-v1"') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
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
    if ($huella -ne $originales[$k]) { Mal ($k + " no es el que dejo la consola con Configuracion (huella " + $huella + "). No toco nada. Mandame esta pantalla."); return }
}
Ok "src\\panel-index.html es el de la consola con Configuracion"
''' % (sha(o), sha(n))
cola = tpl[tpl.index('$descargas = @()'):]
cola = cola.replace('.bak-audioandroid', '.bak-esteticaconsola')
v_ant = '''foreach ($d in $descargas) { Chk ($d[1] + ": verificado") ((Sha (Join-Path $raiz $d[1])) -eq $d[2]) }'''
v_nue = '''foreach ($k in $archivos.Keys) { Chk ($k + ": huella final") ((ShaTexto (Leer (Join-Path $raiz $k)).texto) -eq $finales[$k]) }
''' + v_ant
assert cola.count(v_ant) == 1
cola = cola.replace(v_ant, v_nue)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: la consola quedo con el estilo nuevo. Abrila con Ctrl+F5."\n', cola)
assert 'bak-audioandroid' not in cola and 'estilo nuevo' in cola and '$finales[$k]' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127]
assert not bad, set(bad)
open(R + 'aplicar-consola-estetica-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
open(D + 'estetica_final_panel-index.html', 'w', encoding='utf-8', newline='').write(n)
print('ok', len(total), 'largo final', len(n))
