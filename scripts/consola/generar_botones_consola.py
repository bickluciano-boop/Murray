# Genera scripts/aplicar-consola-botones-panel.ps1: ultimo dorado/mostaza que quedaba (botones Ver mapa aca, iconos, numeros, ventana del mapa) pasa al azul. Antes: genero identidad: cambia el logo (ojo dorado en gota con fondo azul marino y 'Ojo Guard' con el punto dorado en la O) en el encabezado y en la pantalla de acceso; antes agrega a src\panel-index.html un bloque <style id="estetica-v1"> (solo apariencia: azul, blanco y dorado) y la tipografia.
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
o = open(D + 'identidad_final_panel-index.html', 'rb').read().decode('utf-8').replace('\r\n', '\n')
assert 'estetica-v2' in o and 'estetica-v3' not in o
# tiene que ser exactamente lo que deja el instalador de identidad (su huella final)
_id = open(R + 'aplicar-consola-identidad-panel.ps1', encoding='utf-8-sig').read()
_fin = re.search(r"\$finales = @\{\s*'src\\panel-index.html' = '([0-9a-f]{64})'", _id).group(1)
assert sha(o) == _fin, (sha(o), _fin)
css = open(R + 'consola/estetica3.css', encoding='utf-8').read().strip()
bloque = '    <style id="estetica-v3">\n' + css + '\n    </style>\n'
cierre = '  </head>'
assert o.count(cierre) == 1
n = o.replace(cierre, bloque + cierre)
cambios = ("$cambios = @(\n"
           "    ,@('src\\panel-index.html', 'estilos del ultimo dorado a azul', %s, %s)\n)\n") % (psq(cierre), psq(bloque + cierre))
cabeza = '''# aplicar-consola-botones-panel.ps1 - Consola (Ojo Guard MS): lo ultimo que quedaba en mostaza pasa al azul de la identidad.
# Botones Ver mapa aca / Escanear ubicacion / Como llegar, iconos de los relojes, numeros y avisos, ventana del mapa y estados vacios, en claro y en noche. El boton OG de emergencia queda dorado a proposito.
# Luciano (22/10/2026): "todavia habia bastantes botones mostaza". Solo APARIENCIA: se agrega un bloque <style id="estetica-v3">. Ninguna funcion cambia.
# Va en la carpeta del PANEL (la que tiene wrangler.toml). Toca solo src\\panel-index.html, y solo si es el que dejo aplicar-consola-identidad-panel.ps1 (huella SHA-256 antes y despues). Respaldo .bak-consolabotones. Al final publica
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\panel-index.html"))) { Mal "No encuentro src\\panel-index.html en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-index.html")).texto 'id="estetica-v3"') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
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
    if ($huella -ne $originales[$k]) { Mal ($k + " no es el que dejo la identidad de la consola (huella " + $huella + "). No toco nada. Mandame esta pantalla."); return }
}
Ok "src\\panel-index.html es el de la consola con la identidad nueva"
''' % (sha(o), sha(n))
cola = tpl[tpl.index('$descargas = @()'):]
cola = cola.replace('.bak-audioandroid', '.bak-consolabotones')
v_ant = '''foreach ($d in $descargas) { Chk ($d[1] + ": verificado") ((Sha (Join-Path $raiz $d[1])) -eq $d[2]) }'''
v_nue = '''foreach ($k in $archivos.Keys) { Chk ($k + ": huella final") ((ShaTexto (Leer (Join-Path $raiz $k)).texto) -eq $finales[$k]) }
''' + v_ant
assert cola.count(v_ant) == 1
cola = cola.replace(v_ant, v_nue)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: la consola quedo sin botones mostaza. Abrila con Ctrl+F5."\n', cola)
assert 'bak-audioandroid' not in cola and 'sin botones mostaza' in cola and '$finales[$k]' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127]
assert not bad, set(bad)
open(R + 'aplicar-consola-botones-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
open(D + 'botones_final_panel-index.html', 'w', encoding='utf-8', newline='').write(n)
print('ok', len(total), 'largo final', len(n))
