# Genera scripts/aplicar-horas2-app.ps1 (app, PROXIMA build). Luciano (14/11/2026), probando la 204: en Sertralina pudo cambiar de 10:30 a 9:30, pero en otro medicamento "no me deja poner ningun horario, me lo guarda siempre a las 10".
# Causa: al EDITAR un medicamento, "-" y "+" solo movian el selector y "Agregar esta hora" no hacia nada si la hora ya estaba en la lista (en silencio): para cambiar una hora habia que quitarla con la ✕ y agregar otra.
# Ahora cada hora de la lista se toca para elegirla (queda marcada) y "-" / "+" la CAMBIAN en su lugar; la ✕ la quita; "Agregar otra hora" suma la siguiente media hora libre y la deja elegida.
import re
R = '/home/user/Murray/scripts/'
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
F = 'src\\FamiliaPantalla.tsx'
filas = [
 (F, 'horas: cada hora de la lista se elige (queda marcada) y tiene su propia ✕',
  '                {borrador.horas.map((h) => (\n                  <Pressable key={h} accessibilityRole="button" accessibilityLabel={`Quitar la hora ${h}`} onPress={() => setBorrador({ ...borrador, horas: borrador.horas.filter((x) => x !== h) })} style={chip(true)}>\n                    <Text maxFontSizeMultiplier={TOPE_LETRA} style={chipTexto(true)}>{`${h}  ✕`}</Text>\n                  </Pressable>\n                ))}\n',
  '                {borrador.horas.map((h) => (\n'
  '                  <View key={h} style={{ alignItems: "center", flexDirection: "row", gap: 2 }}>\n'
  '                    <Pressable accessibilityRole="button" accessibilityLabel={`Cambiar la hora ${h}`} accessibilityState={{ selected: h === borrador.hora }} onPress={() => setBorrador({ ...borrador, hora: h })} style={chip(h === borrador.hora)}>\n'
  '                      <Text maxFontSizeMultiplier={TOPE_LETRA} style={chipTexto(h === borrador.hora)}>{h}</Text>\n'
  '                    </Pressable>\n'
  '                    <Pressable\n'
  '                      accessibilityRole="button"\n'
  '                      accessibilityLabel={`Quitar la hora ${h}`}\n'
  '                      hitSlop={8}\n'
  '                      onPress={() => {\n'
  '                        const quedan = borrador.horas.filter((x) => x !== h);\n'
  '                        setBorrador({ ...borrador, horas: quedan, hora: h === borrador.hora ? (quedan[0] ?? borrador.hora) : borrador.hora });\n'
  '                      }}\n'
  '                    >\n'
  '                      <Text maxFontSizeMultiplier={TOPE_LETRA} style={{ color: P.textoDebil, fontSize: 16, fontWeight: "800", paddingHorizontal: 6 }}>✕</Text>\n'
  '                    </Pressable>\n'
  '                  </View>\n'
  '                ))}\n'
  '                <Text maxFontSizeMultiplier={TOPE_LETRA} style={[sp.nota, { width: "100%" }]}>Toca una hora para cambiarla con − y +. La ✕ la quita.</Text>\n'),
 (F, 'horas: el boton - cambia la hora elegida en su lugar', 'onPress={() => setBorrador({ ...borrador, hora: moverHoraRemedio(borrador.hora, -1) })}', 'onPress={() => moverHora(-1)}'),
 (F, 'horas: el boton + cambia la hora elegida en su lugar', 'onPress={() => setBorrador({ ...borrador, hora: moverHoraRemedio(borrador.hora, 1) })}', 'onPress={() => moverHora(1)}'),
 (F, 'horas: "Agregar otra hora" suma la siguiente media hora libre',
  '  const agregarHora = () => {\n    if (!borrador) return;\n    if (borrador.horas.includes(borrador.hora)) return;\n    if (borrador.horas.length >= actual.max.horas) {\n      setAviso(`Hasta ${actual.max.horas} horas por medicamento.`);\n      return;\n    }\n    setAviso("");\n    setBorrador({ ...borrador, horas: [...borrador.horas, borrador.hora].sort() });\n  };\n',
  '  // Si la hora del selector es una de la lista, elegir otra hora (con "-", "+" o la tira de horas) la CAMBIA en su lugar (para editar un horario ya cargado);\n'
  '  // si todavia no esta en la lista, solo mueve el selector.\n'
  '  const elegirHora = (h: string) => {\n'
  '    if (!borrador) return;\n'
  '    if (borrador.horas.includes(borrador.hora) && !borrador.horas.includes(h)) {\n'
  '      setBorrador({ ...borrador, hora: h, horas: borrador.horas.map((x) => (x === borrador.hora ? h : x)).sort() });\n'
  '      return;\n'
  '    }\n'
  '    setBorrador({ ...borrador, hora: h });\n'
  '  };\n'
  '  const moverHora = (pasos: number) => {\n'
  '    if (borrador) elegirHora(moverHoraRemedio(borrador.hora, pasos));\n'
  '  };\n'
  '  // Agrega la hora del selector; si ya esta en la lista, agrega la siguiente media hora libre (antes no hacia nada y no decia por que). La nueva queda elegida para ajustarla con - y +.\n'
  '  const agregarHora = () => {\n'
  '    if (!borrador) return;\n'
  '    if (borrador.horas.length >= actual.max.horas) {\n'
  '      setAviso(`Hasta ${actual.max.horas} horas por medicamento.`);\n'
  '      return;\n'
  '    }\n'
  '    let nueva = borrador.hora;\n'
  '    for (let i = 0; i < 48 && borrador.horas.includes(nueva); i += 1) nueva = moverHoraRemedio(nueva, 1);\n'
  '    if (borrador.horas.includes(nueva)) return;\n'
  '    setAviso("");\n'
  '    setBorrador({ ...borrador, horas: [...borrador.horas, nueva].sort(), hora: nueva });\n'
  '  };\n'),
 (F, 'horas: constante con las 48 medias horas del dia', 'function moverHoraRemedio(hhmm: string, pasos: number): string {\n',
  '// Todas las medias horas del dia (00:00 a 23:30) para la tira de horas que se desliza.\n'
  'const HORAS_DEL_DIA = Array.from({ length: 48 }, (_, i) => `${String(Math.floor(i / 2)).padStart(2, "0")}:${i % 2 === 0 ? "00" : "30"}`);\n'
  'function moverHoraRemedio(hhmm: string, pasos: number): string {\n'),
 (F, 'horas: tira de horas que se desliza (elegir una hora tocandola)', '            <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.separador}>CADA CUÁNTO</Text>\n',
  '            <Deslizable activo desde={Math.max(0, HORAS_DEL_DIA.indexOf(borrador.hora) - 2) * 72}>\n'
  '              <View style={{ flexDirection: "row", gap: 6 }}>\n'
  '                {HORAS_DEL_DIA.map((h) => (\n'
  '                  <Pressable key={h} accessibilityRole="button" accessibilityLabel={`Hora ${h}`} accessibilityState={{ selected: h === borrador.hora }} onPress={() => elegirHora(h)} style={chip(h === borrador.hora)}>\n'
  '                    <Text maxFontSizeMultiplier={TOPE_LETRA} style={chipTexto(h === borrador.hora)}>{h}</Text>\n'
  '                  </Pressable>\n'
  '                ))}\n'
  '              </View>\n'
  '            </Deslizable>\n'
  '            <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.separador}>CADA CUÁNTO</Text>\n'),
 (F, 'horas: el boton dice "Agregar otra hora" cuando ya hay horas', 'style={chipTexto(true)}>Agregar esta hora</Text>', 'style={chipTexto(true)}>{borrador.horas.length ? "Agregar otra hora" : "Agregar esta hora"}</Text>'),
]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-horas2-app.ps1 - App (PROXIMA build). Luciano (14/11/2026), probando la 204: al EDITAR un medicamento no podia cambiar su hora ("no me deja poner ningun horario, me lo guarda siempre a las 10").
# Antes, "-" y "+" solo movian el selector y "Agregar esta hora" no hacia nada (ni avisaba) si esa hora ya estaba en la lista: para cambiar una hora habia que quitarla con la ✕ y agregar otra.
# Ahora: tocas una hora de la lista (queda marcada) y "-" / "+" o la TIRA DE HORAS (que se desliza, de 00:00 a 23:30) la CAMBIAN en su lugar; la ✕ la quita; "Agregar otra hora" suma la siguiente media hora libre y la deja elegida. Requiere aplicar-horas-app.ps1 y aplicar-medicamentos-app.ps1.
# Toca src\\FamiliaPantalla.tsx (respaldo .bak-horas2). Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba.
'''
i0 = base.index('$ErrorActionPreference'); j0 = base.index('Ok "Carpeta correcta"')
guardas = '''Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\FamiliaPantalla.tsx"))) { Mal "No encuentro src\\FamiliaPantalla.tsx en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\FamiliaPantalla.tsx")).texto 'const moverHora = (pasos: number)') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\FamiliaPantalla.tsx")).texto 'function Deslizable') -eq 0) { Mal "Falta aplicar primero aplicar-horas-app.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\\FamiliaPantalla.tsx")).texto 'horas por medicamento.') -eq 0) { Mal "Falta aplicar primero aplicar-medicamentos-app.ps1."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('.bak-version', '.bak-horas2')
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "LISTO: la app compila bien. Las horas de un medicamento se cambian en su lugar (sale en la PROXIMA build, Android e iPhone)."', cola)
assert 'bak-version' not in cola
total = cabeza + base[i0:j0] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕']
assert not bad, set(bad)
open(R + 'aplicar-horas2-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
t = open(S + 'FamiliaPantalla-med.tsx', encoding='utf-8').read().replace('\r\n', '\n')
for a, n, v, nv in filas:
    assert t.count(v) == 1, (n, t.count(v))
for a, n, v, nv in filas:
    t = t.replace(v, nv)
open(S + 'FamiliaPantalla-horas2.tsx', 'w', encoding='utf-8').write(t)
print('ok', len(total))
