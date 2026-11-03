# Genera scripts/aplicar-sirena-vigilancia-app.ps1: la app (Android) avisa sola si la sirena del SOS quedo silenciada.
import re, subprocess
R = '/home/user/Murray/scripts/'
COMMIT = subprocess.check_output(['git', '-C', R, 'log', '-1', '--format=%H', '--', 'familia/sosTask.ts']).decode().strip()
SHA_NUEVO = subprocess.check_output(['sha256sum', R + 'familia/sosTask.ts']).decode().split()[0]
SHA_VIEJO = 'cd4c622ca494d6bc9e46e847e881d39e5c6991671995e511ca5b14a49ec1db17'  # sosTask.ts que instala aplicar-dr-ojo-guard-app.ps1
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s): return "'" + s.replace("'", "''") + "'"
url = 'https://raw.githubusercontent.com/bickluciano-boop/Murray/%s/scripts/familia/sosTask.ts' % COMMIT
descargas = "$descargas = @(\n    ,@(%s, %s, %s)\n)\n" % (psq(url), psq('src\\sosTask.ts'), psq(SHA_NUEVO))
filas = [('src\\backgroundFetchTask.ts', 'import de la vigilancia de la sirena', 'import { vigilarGesto } from "./sosTask";\n', 'import { vigilarGesto, vigilarSirena } from "./sosTask";\n'),
         ('src\\backgroundFetchTask.ts', 'vigilar la sirena en el trabajo de fondo', '      await vigilarGesto().catch(() => undefined);\n', '      await vigilarGesto().catch(() => undefined);\n      await vigilarSirena().catch(() => undefined);\n')]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-sirena-vigilancia-app.ps1 - App Android (PROXIMA build): la app avisa sola si la sirena del SOS quedo silenciada.
# Caso real (02/11/2026): en el Xiaomi de Luciano el canal "SOS de la familia" quedo en "Predeterminada" y el SOS llegaba sin sirena, sin que nadie se enterara. Android no deja que la app suba la importancia de un canal ya modificado, pero si puede avisar: igual que con el gesto de volumen, mira al abrir la app, al volver al frente y con el trabajo de fondo, y manda una notificacion (como mucho una cada 12 horas) que dice que la sirena esta silenciada y donde arreglarlo (Dr. Ojo Guard).
# Reemplaza src\\sosTask.ts (descarga con huella; hoy tiene que ser la version del Dr. Ojo Guard) y toca src\\backgroundFetchTask.ts. Va en la carpeta de la APP (la que tiene app.json). Respaldo .bak-sirena. Si la revision de tipos falla, deja todo como estaba. iPhone: no cambia nada.
'''
i = base.index('$ErrorActionPreference'); j = base.index('Ok "Carpeta correcta"')
motor_ini = base[i:j]
guardas = '''Ok "Carpeta correcta"
foreach ($f in @("src\\sosTask.ts", "src\\backgroundFetchTask.ts")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\\sosTask.ts")).texto 'vigilarSirena') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
if ((Sha (Join-Path $raiz "src\\sosTask.ts")) -ne '%s') { Mal "src\\sosTask.ts no es la version esperada (la del Dr. Ojo Guard). No toco nada. Mandame esta pantalla."; return }
''' % SHA_VIEJO
cola = base[base.index('$descargas = @()'):].replace('$descargas = @()\n', descargas, 1).replace('.bak-version', '.bak-sirena')
v = 'if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-sirena") -Destination $ruta -Force } }'
assert cola.count(v) == 1, cola.count(v)
cola = cola.replace(v, 'if ($respaldados -contains $t) { Copy-Item -LiteralPath ($ruta + ".bak-sirena") -Destination $ruta -Force } elseif (Test-Path $ruta) { Remove-Item -LiteralPath $ruta -Force } }')
msg = 'Mal "Restaurado. Mandame esta pantalla."'
assert cola.count(msg) == 2
cola = cola.replace(msg, 'foreach ($t in $respaldados) { Remove-Item -LiteralPath ((Join-Path $raiz $t) + ".bak-sirena") -Force -ErrorAction SilentlyContinue }\n' + msg)
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "LISTO: la app compila bien. Sale en la PROXIMA build de Android."', cola)
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›✓']
assert not bad, set(bad)
open(R + 'aplicar-sirena-vigilancia-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total), 'commit', COMMIT[:8], 'sha nuevo', SHA_NUEVO[:12])
