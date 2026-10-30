# Genera scripts/aplicar-diagnostico-audio-ios-app.ps1: en iPhone, "Hacer sonar" anota en el historial (Configuracion > Registros tecnicos) el estado de la app, el error exacto de iOS al activar el audio y si la sirena sigue sonando a los 6 segundos.
import re
R = '/home/user/Murray/scripts/'
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
a1 = 'import { Platform } from "react-native";\n'
b1 = 'import { AppState, Platform } from "react-native";\n'
a2 = '  if (Platform.OS === "ios") await setIsAudioActiveAsync(true).catch(() => undefined);\n'
b2 = ('  let errorActivar: string | null = null;\n'
      '  const appAlEmpezar = AppState.currentState;\n'
      '  if (Platform.OS === "ios") {\n'
      '    await setIsAudioActiveAsync(true).catch((error: unknown) => {\n'
      '      errorActivar = error instanceof Error ? error.message : String(error);\n'
      '    });\n'
      '  }\n')
a3 = ('        error: `iPhone: ${player.playing ? "sonando" : "NO suena"}${errorModo ? `; modo de audio: ${errorModo}` : ""}`,\n'
      '      });\n'
      '    }, 1500);\n')
b3 = ('        error: `iPhone (app ${appAlEmpezar}): ${player.playing ? "sonando" : "NO suena"}${errorModo ? `; modo de audio: ${errorModo}` : ""}${errorActivar ? `; activar audio: ${errorActivar}` : "; activar audio: sin error"}`,\n'
      '      });\n'
      '    }, 1500);\n'
      '    // Segunda mirada, a los 6 segundos: si de verdad avanza el audio o solo dice que esta sonando.\n'
      '    setTimeout(() => {\n'
      '      if (activeAlarmPlayer !== player) return;\n'
      '      void recordFullScreenAlertAttempt({\n'
      '        reason: "hacer-sonar",\n'
      '        moduleFound: false,\n'
      '        result: player.playing,\n'
      '        error: `iPhone a los 6 s (app ${AppState.currentState}): ${player.playing ? "sigue sonando" : "se detuvo"}, posicion ${Math.round(player.currentTime * 10) / 10} s`,\n'
      '      });\n'
      '    }, 6000);\n')
filas = [('src\\earbudTone.ts', 'diagnostico de audio iPhone: AppState', a1, b1),
         ('src\\earbudTone.ts', 'diagnostico de audio iPhone: error al activar', a2, b2),
         ('src\\earbudTone.ts', 'diagnostico de audio iPhone: anotar estado', a3, b3)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-diagnostico-audio-ios-app.ps1 - App (PROXIMA build, iPhone): diagnostico de "Hacer sonar" en segundo plano.
# Motivo (30/10/2026): en build 48 el historial dice "iPhone: sonando" con la app en segundo plano, pero no se oye nada hasta abrirla. Hoy el error de iOS al activar el audio se ignora. Este cambio anota: estado de la app, error exacto al activar el audio, y si a los 6 s el audio avanza.
# Cambia SOLO src\\earbudTone.ts (respaldo .bak-diag-audio). No cambia el sonido ni nada en Android. Va en la carpeta de la APP.
'''
i = base.index('$ErrorActionPreference'); j = base.index('Ok "Carpeta correcta"')
motor_ini = base[i:j]
guardas = '''Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\earbudTone.ts"))) { Mal "No encuentro src\\earbudTone.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\earbudTone.ts")).texto 'errorActivar') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('.bak-version', '.bak-diag-audio')
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "LISTO: la app compila bien. Sale en la PROXIMA build (iPhone)."', cola)
assert 'bak-version' not in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—']
assert not bad, set(bad)
open(R + 'aplicar-diagnostico-audio-ios-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
