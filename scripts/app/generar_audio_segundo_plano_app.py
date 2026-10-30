# Genera scripts/aplicar-audio-segundo-plano-app.ps1: agrega "audio" a UIBackgroundModes del iPhone en app.json, para que "Hacer sonar" pueda sonar desde segundo plano aunque la perilla lateral este en silencio.
import re
R = '/home/user/Murray/scripts/'
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
a = '        "UIBackgroundModes": [\n          "remote-notification",\n          "location"\n        ]'
b = '        "UIBackgroundModes": [\n          "remote-notification",\n          "location",\n          "audio"\n        ]'
fila = ('app.json', 'iPhone: permiso de audio en segundo plano (Hacer sonar con la perilla en silencio)', a, b)
# Una sola fila: la coma delante evita que PowerShell aplane @(@(...)).
cambios = "$cambios = @(\n    ,@(%s, %s, %s, %s)\n)\n" % tuple(psq(x) for x in fila)
cabeza = '''# aplicar-audio-segundo-plano-app.ps1 - App (PROXIMA build, iPhone): agrega "audio" a UIBackgroundModes en app.json.
# Motivo (30/10/2026): "Hacer sonar" a distancia solo sonaba con la perilla lateral del iPhone activa, porque con la app en segundo plano iOS no deja arrancar el audio de la alarma sin este permiso.
# Cambia SOLO app.json (respaldo .bak-audio-fondo). No cambia nada en Android. Apple puede preguntar en la revision por que se usa el audio en segundo plano: es la sirena para encontrar el telefono. Va en la carpeta de la APP.
'''
i = base.index('$ErrorActionPreference'); j = base.index('Ok "Carpeta correcta"')
motor_ini = base[i:j]
guardas = '''Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "app.json"))) { Mal "No encuentro app.json en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "app.json")).texto '"audio"') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('.bak-version', '.bak-audio-fondo')
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "LISTO: la app compila bien. Sale en la PROXIMA build (iPhone)."', cola)
assert 'bak-version' not in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—']
assert not bad, set(bad)
open(R + 'aplicar-audio-segundo-plano-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
