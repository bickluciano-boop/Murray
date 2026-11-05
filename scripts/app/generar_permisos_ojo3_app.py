# Genera scripts/aplicar-permisos-ojo3-app.ps1: con un menor, las llaves que son del adulto se pueden tocar; solo quedan fijas las dos que cuidan al menor.
import re
R = '/home/user/Murray/scripts/'
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
A1 = 'type Permisos = { locked: boolean; teVe: Llave; recibeTuSos: Llave; loVes: Llave; recibisSuSos: Llave };'
B1 = 'type Permisos = { locked: boolean; fijas?: ClavePermiso[]; teVe: Llave; recibeTuSos: Llave; loVes: Llave; recibisSuSos: Llave };'
A2 = '  const bloqueada = permisos.locked;\n'
B2 = A2 + '  // Con un menor quedan fijas solo las llaves que lo cuidan (verlo y recibir su SOS); las otras dos las decide el adulto.\n  const fija = (clave: ClavePermiso) => bloqueada || (permisos.fijas ?? []).includes(clave);\n'
filas = [('src\\FamiliaPantalla.tsx', 'permisos3: tipo con llaves fijas', A1, B1),
         ('src\\FamiliaPantalla.tsx', 'permisos3: funcion fija', A2, B2)]
for clave in ['teVe', 'recibeTuSos', 'loVes', 'recibisSuSos']:
    a = 'bloqueada={bloqueada} guardando={guardandoClave("%s")}' % clave
    b = 'bloqueada={fija("%s")} guardando={guardandoClave("%s")}' % (clave, clave)
    filas.append(('src\\FamiliaPantalla.tsx', 'permisos3: llave ' + clave, a, b))
A7 = '{bloqueada ? <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.nota}>Con un menor no se puede cortar la ubicación ni el SOS.</Text> : null}'
B7 = '{bloqueada || (permisos.fijas ?? []).length ? <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.nota}>{bloqueada ? "Con un menor no se puede cortar la ubicación ni el SOS." : "Verlo y recibir su SOS no se puede apagar: es lo que cuida a un menor. Lo tuyo sí lo podés cortar."}</Text> : null}'
filas.append(('src\\FamiliaPantalla.tsx', 'permisos3: nota del menor', A7, B7))
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-permisos-ojo3-app.ps1 - App (PROXIMA build): con un menor, las llaves del adulto se pueden tocar.
# Luciano (05/11/2026, iPhone): "iPhone menor te ve a vos... no me tiene que ver; no anda ninguna llave". Con un menor estaban bloqueadas las 4. Ahora: "Te ve" y "Recibe tu SOS" las decide el adulto; quedan fijas "Lo ves" y "Recibis su SOS" (cuidan al menor).
# Requiere aplicar-permisos-ojo2-app.ps1 y el instalador del servidor aplicar-permisos-ojo3-panel.ps1. Toca solo src\\FamiliaPantalla.tsx (respaldo .bak-permisos3). Va en la carpeta de la APP (la que tiene app.json).
'''
i = base.index('$ErrorActionPreference'); j = base.index('Ok "Carpeta correcta"')
guardas = '''Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\FamiliaPantalla.tsx"))) { Mal "No encuentro src\\FamiliaPantalla.tsx en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\FamiliaPantalla.tsx")).texto 'const TOPE_LETRA') -eq 0) { Mal "Falta aplicar primero aplicar-permisos-ojo2-app.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\\FamiliaPantalla.tsx")).texto 'const fija = (clave: ClavePermiso)') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('.bak-version', '.bak-permisos3')
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "LISTO: la app compila bien. Sale en la PROXIMA build."', cola)
total = cabeza + base[i:j] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—']
assert not bad, set(bad)
open(R + 'aplicar-permisos-ojo3-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
