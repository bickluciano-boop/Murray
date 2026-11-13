# Genera scripts/aplicar-remedios3-app.ps1: REMEDIOS v3 (app, PROXIMA build). Luciano (13/11/2026): "siguen sin funcionar los botones de editar y agregar".
# Causa: Editar y "Agregar otro con este horario" SI funcionaban, pero el formulario se abria al final de la lista de remedios, fuera de la pantalla (con 3 remedios, a 806 px en una pantalla de 700):
# parecia que no pasaba nada. Ahora, mientras se edita o se agrega, la lista se esconde y el formulario queda justo debajo del titulo "MIS REMEDIOS".
import re
R = '/home/user/Murray/scripts/'
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
OLD = '        {actual.items.map((it) => (\n          <View key={it.id} style={{ borderColor: P.borde, borderRadius: 12, borderWidth: 1, gap: 6, padding: 10 }}>\n'
NEW = ('        {/* Mientras se edita o se agrega un remedio la lista se esconde: asi el formulario queda aca, a la vista, y no al final de la lista. */}\n'
       '        {(borrador ? [] : actual.items).map((it) => (\n          <View key={it.id} style={{ borderColor: P.borde, borderRadius: 12, borderWidth: 1, gap: 6, padding: 10 }}>\n')
filas = [('src\\FamiliaPantalla.tsx', 'remedios v3: el formulario de editar/agregar queda a la vista', OLD, NEW)]
cambios = "$cambios = ,@(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-remedios3-app.ps1 - App (PROXIMA build): REMEDIOS v3. Luciano (13/11/2026): "siguen sin funcionar los botones de editar y agregar".
# Los botones SI funcionaban, pero el formulario se abria al final de la lista de remedios, fuera de la pantalla, y parecia que no pasaba nada.
# Ahora, mientras se edita o se agrega un remedio, la lista se esconde y el formulario queda justo debajo del titulo "MIS REMEDIOS", a la vista.
# Requiere aplicar-remedios2-app.ps1. Toca src\\FamiliaPantalla.tsx (respaldo .bak-remedios3). Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba.
'''
i0 = base.index('$ErrorActionPreference'); j0 = base.index('Ok "Carpeta correcta"')
guardas = '''Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\FamiliaPantalla.tsx"))) { Mal "No encuentro src\\FamiliaPantalla.tsx en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\FamiliaPantalla.tsx")).texto 'function textoFrecuenciaRemedio') -eq 0) { Mal "Falta aplicar primero aplicar-remedios2-app.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\\FamiliaPantalla.tsx")).texto '(borrador ? [] : actual.items)') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('.bak-version', '.bak-remedios3')
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "LISTO: la app compila bien. Sale en la PROXIMA build."', cola)
assert 'bak-version' not in cola
total = cabeza + base[i0:j0] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕']
assert not bad, set(bad)
open(R + 'aplicar-remedios3-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
f = open(S + 'FamiliaPantalla-remedios2.tsx', encoding='utf-8').read().replace('\r\n', '\n')
assert f.count(OLD) == 1, f.count(OLD)
open(S + 'FamiliaPantalla-remedios3.tsx', 'w', encoding='utf-8').write(f.replace(OLD, NEW))
print('ok', len(total))
