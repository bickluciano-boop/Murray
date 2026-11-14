# Genera scripts/aplicar-horas-app.ps1 (app, PROXIMA build). Luciano (14/11/2026), probando en el iPhone:
#  1) "HORA DEL SALUDO" (Buen dia) solo ofrece 07:00 a 11:00 en punto y no se puede elegir 10:30: ahora ofrece de 05:00 a 13:00 cada media hora y la fila se desliza hacia los costados (empieza centrada en la hora elegida).
#  2) Remedios: ponia la hora con - / + pero no tocaba "Agregar esta hora" y "Guardar remedio" decia "agrega al menos una hora": ahora, si todavia no agrego ninguna, se guarda con la hora que muestra el selector.
import re
R = '/home/user/Murray/scripts/'
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
F = 'src\\FamiliaPantalla.tsx'
filas = [
 (F, 'horas: importar el desplazamiento horizontal', 'import * as Location from "expo-location";\n',
  'import { ScrollView as ScrollHorizontal } from "react-native";\nimport * as Location from "expo-location";\n'),
 (F, 'horas del Buen dia: de 05:00 a 13:00 cada media hora', 'const HORAS_BUEN_DIA = ["07:00", "08:00", "09:00", "10:00", "11:00"];\n',
  '// De 05:00 a 13:00 cada media hora (17 opciones): la fila se desliza hacia los costados.\n'
  'const HORAS_BUEN_DIA = Array.from({ length: 17 }, (_, i) => {\n'
  '  const minutos = 5 * 60 + i * 30;\n'
  '  return `${String(Math.floor(minutos / 60)).padStart(2, "0")}:${minutos % 60 === 0 ? "00" : "30"}`;\n'
  '});\n'),
 (F, 'opciones del cuidado: la fila se desliza si son muchas',
  'function OpcionesCuidado({ P, titulo, opciones, elegida, onElegir }: { P: Paleta; titulo: string; opciones: { valor: string; texto: string }[]; elegida: string; onElegir: (valor: string) => void }) {\n  const sp = estilosPermisos(P);\n  return (\n    <View style={{ gap: 6 }}>\n      <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.separador}>{titulo}</Text>\n      <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 6 }}>\n',
  '/** Si hay muchas opciones (las horas del Buen dia, cada media hora) la fila se desliza hacia los costados y empieza en la elegida; con pocas, se acomodan en renglones. */\n'
  'function Deslizable({ activo, desde, children }: { activo: boolean; desde: number; children: ReactNode }) {\n'
  '  const ref = useRef<ScrollHorizontal>(null);\n'
  '  if (!activo) return <>{children}</>;\n'
  '  return (\n'
  '    <ScrollHorizontal ref={ref} horizontal showsHorizontalScrollIndicator={false} onContentSizeChange={() => ref.current?.scrollTo({ x: desde, y: 0, animated: false })}>\n'
  '      {children}\n'
  '    </ScrollHorizontal>\n'
  '  );\n'
  '}\n\n'
  'function OpcionesCuidado({ P, titulo, opciones, elegida, onElegir }: { P: Paleta; titulo: string; opciones: { valor: string; texto: string }[]; elegida: string; onElegir: (valor: string) => void }) {\n'
  '  const sp = estilosPermisos(P);\n'
  '  const muchas = opciones.length > 6;\n'
  '  const indiceElegida = opciones.findIndex((o) => o.valor === elegida);\n'
  '  return (\n'
  '    <View style={{ gap: 6 }}>\n'
  '      <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.separador}>{titulo}</Text>\n'
  '      <Deslizable activo={muchas} desde={Math.max(0, indiceElegida - 1) * 82}>\n'
  '      <View style={{ flexDirection: "row", flexWrap: muchas ? "nowrap" : "wrap", gap: 6 }}>\n'),
 (F, 'opciones del cuidado: cierre de la fila deslizable', '        })}\n      </View>\n    </View>\n  );\n}\n',
  '        })}\n      </View>\n      </Deslizable>\n    </View>\n  );\n}\n'),
 (F, 'remedios: si no agrego ninguna hora se usa la del selector', '    if (!borrador.horas.length) {\n',
  '    // Si todavia no toco "Agregar esta hora", se guarda con la hora que muestra el selector (antes pedia agregarla y confundia).\n'
  '    const horasFinal = borrador.horas.length ? borrador.horas : [borrador.hora];\n'
  '    if (!horasFinal.length) {\n'),
 (F, 'remedios: guardar con esa hora', 'nombre, horas: borrador.horas, dias, diaMes: borrador.frecuencia === "mensual" ? borrador.diaMes : null };',
  'nombre, horas: horasFinal, dias, diaMes: borrador.frecuencia === "mensual" ? borrador.diaMes : null };'),
]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-horas-app.ps1 - App (PROXIMA build). Luciano (14/11/2026), probando en el iPhone:
#  1) "HORA DEL SALUDO" (Buen dia): solo habia 07:00 a 11:00 en punto y no se podia elegir 10:30. Ahora hay de 05:00 a 13:00 cada media hora y la fila se desliza hacia los costados.
#  2) Remedios: ponia la hora con - / + pero no tocaba "Agregar esta hora" y al guardar decia "agrega al menos una hora". Ahora, si todavia no agrego ninguna, se guarda con la hora que muestra el selector.
# Toca src\\FamiliaPantalla.tsx (respaldo .bak-horas). Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba.
'''
i0 = base.index('$ErrorActionPreference'); j0 = base.index('Ok "Carpeta correcta"')
guardas = '''Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\FamiliaPantalla.tsx"))) { Mal "No encuentro src\\FamiliaPantalla.tsx en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\FamiliaPantalla.tsx")).texto 'function Deslizable') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('.bak-version', '.bak-horas')
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "LISTO: la app compila bien. Sale en la PROXIMA build (Android e iPhone)."', cola)
assert 'bak-version' not in cola
total = cabeza + base[i0:j0] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕']
assert not bad, set(bad)
open(R + 'aplicar-horas-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
t = open(S + 'FamiliaPantalla-robusta.tsx', encoding='utf-8').read().replace('\r\n', '\n')
for a, n, v, nv in filas:
    assert t.count(v) == 1, (n, t.count(v))
for a, n, v, nv in filas:
    t = t.replace(v, nv)
open(S + 'FamiliaPantalla-horas.tsx', 'w', encoding='utf-8').write(t)
print('ok', len(total))
