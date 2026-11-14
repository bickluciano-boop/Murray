# Genera scripts/aplicar-horas3-app.ps1 (app, PROXIMA build). Luciano (14/11/2026), en el iPhone: "sale cortada la hora" (la fila de horas deslizable del Buen dia mostraba la primera hora cortada: "30 | 09:00 | 09:30 | 10:00 | 10:3").
# Causa: el desplazamiento inicial se calculaba con un ancho de boton aproximado y las horas tenian anchos distintos: quedaba una hora cortada a la izquierda.
# Ahora cada hora tiene ancho fijo (76 px con el espacio de 6) y el desplazamiento es exacto: la fila arranca con la hora anterior entera, la elegida y las siguientes; solo asoma cortada la ultima de la derecha (es la senal de que se desliza) y un texto lo dice.
import re
R = '/home/user/Murray/scripts/'
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
F = 'src\\FamiliaPantalla.tsx'
filas = [
 (F, 'horas: la fila deslizable deja un margen al final', '<ScrollHorizontal ref={ref} horizontal showsHorizontalScrollIndicator={false} onContentSizeChange=',
  '<ScrollHorizontal ref={ref} horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ paddingRight: 24 }} onContentSizeChange='),
 (F, 'horas del Buen dia: ancho fijo por hora (el desplazamiento queda exacto)', 'onPress={() => onElegir(o.valor)} style={{ backgroundColor: activa ? P.doradoFondo : P.campo,',
  'onPress={() => onElegir(o.valor)} style={{ ...(muchas ? { alignItems: "center" as const, width: 76 } : {}), backgroundColor: activa ? P.doradoFondo : P.campo,'),
 (F, 'horas del Buen dia: aviso "Desliza para ver mas horas"', '      </Deslizable>\n    </View>\n  );\n}\n\nfunction TarjetaCuidado',
  '      </Deslizable>\n      {muchas ? <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.nota}>Desliza para ver más horas.</Text> : null}\n    </View>\n  );\n}\n\nfunction TarjetaCuidado'),
 (F, 'medicamentos: tira de horas con ancho fijo y desplazamiento exacto', '<Deslizable activo desde={Math.max(0, HORAS_DEL_DIA.indexOf(borrador.hora) - 2) * 72}>',
  '<Deslizable activo desde={Math.max(0, HORAS_DEL_DIA.indexOf(borrador.hora) - 1) * 78}>'),
 (F, 'medicamentos: cada hora de la tira con ancho fijo', 'accessibilityLabel={`Hora ${h}`} accessibilityState={{ selected: h === borrador.hora }} onPress={() => elegirHora(h)} style={chip(h === borrador.hora)}>',
  'accessibilityLabel={`Hora ${h}`} accessibilityState={{ selected: h === borrador.hora }} onPress={() => elegirHora(h)} style={[chip(h === borrador.hora), { alignItems: "center", width: 72 }]}>'),
 (F, 'medicamentos: aviso "Desliza para ver mas horas" bajo la tira', '            </Deslizable>\n            <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.separador}>CADA CUÁNTO</Text>\n',
  '            </Deslizable>\n            <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.nota}>Desliza para ver más horas.</Text>\n            <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.separador}>CADA CUÁNTO</Text>\n'),
]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-horas3-app.ps1 - App (PROXIMA build). Luciano (14/11/2026), en el iPhone: "sale cortada la hora" (la fila de horas que se desliza mostraba la primera cortada).
# Cada hora pasa a tener ancho fijo y el desplazamiento inicial es exacto: la fila arranca con la hora anterior entera, la elegida y las siguientes; solo asoma cortada la ultima de la derecha (senal de que se desliza) y un texto lo aclara ("Desliza para ver mas horas").
# Vale para las horas del Buen dia y para la tira de horas de un medicamento. Requiere aplicar-horas2-app.ps1. Toca src\\FamiliaPantalla.tsx (respaldo .bak-horas3). Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba.
'''
i0 = base.index('$ErrorActionPreference'); j0 = base.index('Ok "Carpeta correcta"')
guardas = '''Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\FamiliaPantalla.tsx"))) { Mal "No encuentro src\\FamiliaPantalla.tsx en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\FamiliaPantalla.tsx")).texto 'Desliza para ver más horas') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\FamiliaPantalla.tsx")).texto 'const HORAS_DEL_DIA') -eq 0) { Mal "Falta aplicar primero aplicar-horas2-app.ps1."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('.bak-version', '.bak-horas3')
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "LISTO: la app compila bien. Las filas de horas ya no salen cortadas (sale en la PROXIMA build, Android e iPhone)."', cola)
assert 'bak-version' not in cola
total = cabeza + base[i0:j0] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕']
assert not bad, set(bad)
open(R + 'aplicar-horas3-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
t = open(S + 'FamiliaPantalla-horas2.tsx', encoding='utf-8').read().replace('\r\n', '\n')
for a, n, v, nv in filas:
    assert t.count(v) == 1, (n, t.count(v))
for a, n, v, nv in filas:
    t = t.replace(v, nv)
open(S + 'FamiliaPantalla-horas3.tsx', 'w', encoding='utf-8').write(t)
print('ok', len(total))
