# Genera scripts/aplicar-estetica-app.ps1: pasa la paleta de la app a azul, blanco y dorado (solo colores: ninguna funcion cambia).
# La app tiene todos sus colores en App.tsx (PALETAS: claro y oscuro, y COMUNES); las demas pantallas los reciben de ahi, asi que alcanza con cambiar esos valores.
import re, hashlib
R = '/home/user/Murray/scripts/'
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/app/'
orig = open(S + 'App.orig.tsx', encoding='utf-8').read().replace('\r\n', '\n')
base = open(R + 'aplicar-consola-identidad-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')

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

# ---- valores nuevos ----
COMUNES = {
    'doradoRelleno': '#1F4FD1',        # relleno de los botones principales: azul
    'doradoRellenoMedio': '#3D6BEA',   # botones principales secundarios: azul medio
    'sobreDorado': '#ffffff',          # texto sobre esos botones
}
CLARO = {
    'fondo': '#FAF8F3', 'superficie': '#ffffff', 'superficieHonda': '#EEF2FB', 'campo': '#ffffff',
    'borde': '#E3E7F1', 'bordeMedio': '#D3D9EA', 'bordeFuerte': '#B4BDD6',
    'texto': '#14213D', 'textoSuave': '#1E2B4D', 'textoMedio': '#2E3B5E', 'textoClaro': '#3E4A6B', 'textoTenue': '#4C5878', 'textoDebil': '#5B6580', 'marcador': '#8A93AB',
    'doradoTexto': '#7A5200', 'doradoTextoSuave': '#8A6410', 'doradoTextoMedio': '#7A5200', 'doradoTenue': '#6E7690',
    'doradoBorde': '#E3C16A', 'doradoBordeMedio': '#E3A92B', 'doradoBordeFuerte': '#C98F12',
    'doradoFondo': '#FFF6DD', 'doradoFondoFuerte': '#FBE7B0',
    'peligroFondo': '#FBEAE7',
    'mapaFondo': '#EAF0F7', 'mapaTexto': '#4A5567', 'mapaTextoFuerte': '#14213D',
    'doradoBordeTenue': '#EBD39A',
}
OSCURO = {
    'fondo': '#0B1020', 'superficie': '#121A33', 'superficieHonda': '#18213F', 'campo': '#0E1630',
    'borde': '#26304F', 'bordeMedio': '#2F3A5E', 'bordeFuerte': '#46527A',
    'texto': '#F5F0E6', 'textoSuave': '#E8E4DA', 'textoMedio': '#D5DBEC', 'textoClaro': '#B9C2DB', 'textoTenue': '#A9B3CE', 'textoDebil': '#8791B0', 'marcador': '#6F7A9B',
    'doradoTexto': '#FFC247', 'doradoTextoSuave': '#FFD477', 'doradoTextoMedio': '#F0B840', 'doradoTenue': '#B5A57A',
    'doradoBorde': '#7A5F22', 'doradoBordeMedio': '#E3A92B', 'doradoBordeFuerte': '#FFC247',
    'doradoFondo': '#211C12', 'doradoFondoFuerte': '#3A2E14',
    'peligroFondo': '#2A1416',
    'mapaFondo': '#101A33', 'mapaTexto': '#9AA6C2', 'mapaTextoFuerte': '#ffffff',
    'doradoBordeTenue': '#5B4A1C',
}

def recolor(texto, nuevos):
    vistos = set()
    def f(m):
        k = m.group(2)
        if k in nuevos:
            vistos.add(k)
            return m.group(1) + k + ': "' + nuevos[k] + '",' + m.group(4)
        return m.group(0)
    out = re.sub(r'^(\s+)([A-Za-z]+): "([^"]*)",(.*)$', lambda m: (m.group(1) + m.group(2) + ': "' + nuevos[m.group(2)] + '",' + m.group(4)) if m.group(2) in nuevos and not vistos.add(m.group(2)) else m.group(0), texto, flags=re.M)
    faltan = set(nuevos) - vistos
    assert not faltan, faltan
    return out

# bloques viejos
ini_o = orig.index('  oscuro: {\n    ...COMUNES,')
ini_c = orig.index('  claro: {\n    ...COMUNES,')
fin_c = orig.index('\n  },\n};', ini_c) + len('\n  },')
blo_o = orig[ini_o:ini_c]
blo_c = orig[ini_c:fin_c]
assert blo_o.count('doradoBordeTenue') == 1 and blo_c.count('doradoBordeTenue') == 1
nuevo_o = recolor(blo_o, OSCURO)
nuevo_c = recolor(blo_c, CLARO)
ini_k = orig.index('  // relleno de boton dorado: 11,7:1 con el texto en los dos temas')
fin_k = orig.index('  // relleno del circulo de precision')
blo_k = orig[ini_k:fin_k]
nuevo_k = blo_k
nuevo_k = nuevo_k.replace('// relleno de boton dorado: 11,7:1 con el texto en los dos temas', '// relleno de los botones principales: azul (blanco sobre azul, 7,6:1)')
nuevo_k = nuevo_k.replace('// relleno de boton dorado secundario', '// relleno de los botones principales, tono medio')
nuevo_k = nuevo_k.replace('// texto sobre boton dorado: oscuro SIEMPRE, incluso en tema claro', '// texto sobre los botones principales: blanco en los dos temas')
nuevo_k = recolor(nuevo_k, COMUNES)
for b, n in ((blo_o, nuevo_o), (blo_c, nuevo_c), (blo_k, nuevo_k)):
    assert orig.count(b) == 1 and b != n
final = orig.replace(blo_o, nuevo_o).replace(blo_c, nuevo_c).replace(blo_k, nuevo_k)
open(S + 'App.final.tsx', 'w', encoding='utf-8', newline='').write(final)

cambios = ("$cambios = @(\n"
           "    @('App.tsx', 'colores comunes: botones principales en azul', %s, %s),\n"
           "    @('App.tsx', 'paleta de noche: azul oscuro, marfil y dorado', %s, %s),\n"
           "    @('App.tsx', 'paleta clara: blanco, azul y dorado', %s, %s)\n)\n") % (psq(blo_k), psq(nuevo_k), psq(blo_o), psq(nuevo_o), psq(blo_c), psq(nuevo_c))

# ---- instalador: se arma con el motor del de la consola ----
ini = base.index('$ErrorActionPreference')
j = base.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor = base[ini:j]
cabeza = '''# aplicar-estetica-app.ps1 - App Ojo Guard: estetica nueva (azul, blanco y dorado), solo COLORES.
# Luciano (21/10/2026): "no rompamos ningun codigo y no saquemos nada nuestro". La app tiene todos sus colores en un solo lugar (la paleta de App.tsx); las demas pantallas los reciben de ahi.
# Se cambian esos valores y nada mas: ninguna funcion, boton, texto ni pantalla cambia de lugar.
#  - Tema claro: fondo marfil, tarjetas blancas, texto azul marino, bordes azul grisaceo. Tema de noche: azul oscuro (no negro), texto marfil. El dorado queda de detalle (letras, bordes, avisos).
#  - Los botones principales (los que eran dorados) pasan a azul con letra blanca. La pantalla de guardia y la de Modo perdido siguen oscuras y doradas, como antes.
# Cambia solo App.tsx. Va en la carpeta de la APP (la que tiene app.json). Respaldo .bak-esteticaapp. Es codigo de la app: sale en la PROXIMA build (Android e iPhone).
'''
guardas = '''if (-not (Test-Path (Join-Path $raiz "app.json")) -or (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta de la APP (la que tiene app.json), no la del panel."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "App.tsx"))) { Mal "No encuentro App.tsx en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "App.tsx")).texto '// relleno de los botones principales: azul') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = base[base.index('$descargas = @()'):]
cola = cola.replace('.bak-consolaidentidad', '.bak-esteticaapp')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
fin_txt = cola.index('Write-Host ""\nOk "Archivos listos. Ahora publico el panel..."')
cola = cola[:fin_txt] + '''Write-Host ""
Ok "LISTO: App.tsx quedo con la paleta nueva (azul, blanco y dorado). Sale en la proxima build."
Write-Host ""
'''
assert 'wrangler' not in cola and 'huella final' not in cola
total = cabeza + motor + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127]
assert not bad, set(bad)
open(R + 'aplicar-estetica-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total), len(orig), len(final))
