# Genera scripts/aplicar-sirena-prueba-detener-app.ps1: "Probar la sirena" se puede DETENER y se corta sola a los 10 s.
import re
R = '/home/user/Murray/scripts/'
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
pb = open(R + 'familia/ProteccionBlock.tsx', encoding='utf-8').read().replace('\r\n', '\n')
linea_sirena = [l for l in pb.split('\n') if l.startswith('    setAvisoSirena((await probarSirena()) ?')]
assert len(linea_sirena) == 1
msg_ok = re.search(r'\? ("[^"]*") : ("[^"]*")\);', linea_sirena[0])
assert msg_ok
filas = []
# ---- sosTask.ts ----
A1 = 'const pausa = (ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms));\n'
B1 = A1 + '''
// La prueba de la sirena se corta sola a los 10 segundos y se puede detener a mano (antes sonaba toda la alarma sin forma de pararla).
const PRUEBA_SIRENA_MS = 10_000;
export async function detenerPruebaSirena() {
  // Sacar el aviso de la bandeja corta su sonido.
  await Notifications.dismissNotificationAsync("ojo-guard-sirena-prueba").catch(() => undefined);
  await Notifications.cancelScheduledNotificationAsync("ojo-guard-sirena-prueba").catch(() => undefined);
}
'''
filas.append(('src\\sosTask.ts', 'sirena de prueba: funcion para detenerla', A1, B1))
A2 = '      trigger: { channelId: SOS_CHANNEL },\n    });\n    return true;\n'
B2 = '      trigger: { channelId: SOS_CHANNEL },\n    });\n    setTimeout(() => void detenerPruebaSirena(), PRUEBA_SIRENA_MS);\n    return true;\n'
filas.append(('src\\sosTask.ts', 'sirena de prueba: corte automatico', A2, B2))
# ---- ProteccionBlock.tsx ----
filas.append(('src\\ProteccionBlock.tsx', 'sirena de prueba: importar', 'import { probarSirena } from "./sosTask";', 'import { detenerPruebaSirena, probarSirena } from "./sosTask";'))
filas.append(('src\\ProteccionBlock.tsx', 'sirena de prueba: estado', '  const [avisoSirena, setAvisoSirena] = useState("");\n', '  const [avisoSirena, setAvisoSirena] = useState("");\n  const [sonandoPrueba, setSonandoPrueba] = useState(false);\n'))
A3 = '  async function sirena() {\n' + linea_sirena[0] + '\n  }\n'
B3 = ('  async function detenerSirena() {\n'
      '    setSonandoPrueba(false);\n'
      '    await detenerPruebaSirena();\n'
      '  }\n\n'
      '  async function sirena() {\n'
      '    const sono = await probarSirena();\n'
      '    // El boton pasa a "Detener la sirena" mientras suena (la prueba se corta sola a los 10 segundos).\n'
      '    if (sono) {\n'
      '      setSonandoPrueba(true);\n'
      '      setTimeout(() => setSonandoPrueba(false), 10_500);\n'
      '    }\n'
      '    setAvisoSirena(sono ? ' + msg_ok.group(1) + ' : ' + msg_ok.group(2) + ');\n'
      '  }\n')
filas.append(('src\\ProteccionBlock.tsx', 'sirena de prueba: funciones del boton', A3, B3))
A4 = ('          <Pressable accessibilityRole="button" onPress={() => void sirena()} style={botones.secundario}>\n'
      '            <Text style={botones.secundarioTexto}>Probar la sirena</Text>\n'
      '          </Pressable>\n')
B4 = ('          {sonandoPrueba ? (\n'
      '            <Pressable accessibilityRole="button" onPress={() => void detenerSirena()} style={[botones.secundario, { borderColor: P.peligroBorde, backgroundColor: P.peligroFondo }]}>\n'
      '              <Text style={[botones.secundarioTexto, { color: P.peligroFuerte }]}>Detener la sirena</Text>\n'
      '            </Pressable>\n'
      '          ) : (\n'
      '            <Pressable accessibilityRole="button" onPress={() => void sirena()} style={botones.secundario}>\n'
      '              <Text style={botones.secundarioTexto}>Probar la sirena</Text>\n'
      '            </Pressable>\n'
      '          )}\n')
filas.append(('src\\ProteccionBlock.tsx', 'sirena de prueba: boton Detener', A4, B4))
for f in filas:
    src = open(R + 'familia/' + f[0].split('\\')[1], encoding='utf-8').read().replace('\r\n', '\n')
    assert src.count(f[2]) == 1, (f[1], src.count(f[2]))
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-sirena-prueba-detener-app.ps1 - App (PROXIMA build, Android): "Probar la sirena" se puede detener y se corta sola.
# Luciano (02/11/2026): "no podes anular probar la sirena; tuve que esperar un largo rato". Ahora el boton pasa a "Detener la sirena" mientras suena y la prueba se corta sola a los 10 segundos.
# Toca src\\sosTask.ts y src\\ProteccionBlock.tsx (respaldo .bak-sirenaprueba). Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba.
'''
i0 = base.index('$ErrorActionPreference'); j0 = base.index('Ok "Carpeta correcta"')
guardas = '''Ok "Carpeta correcta"
foreach ($f in @("src\\sosTask.ts", "src\\ProteccionBlock.tsx")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\\sosTask.ts")).texto 'detenerPruebaSirena') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('.bak-version', '.bak-sirenaprueba')
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "LISTO: la app compila bien. Sale en la PROXIMA build (Android)."', cola)
total = cabeza + base[i0:j0] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—']
assert not bad, set(bad)
open(R + 'aplicar-sirena-prueba-detener-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
