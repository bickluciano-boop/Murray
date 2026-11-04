# Genera scripts/aplicar-sirena-apaga2-app.ps1: la sirena tambien se apaga cuando la app se abre DESDE CERO (cerrada del todo). Luciano (04/11/2026, build 189): "solo se apago con Detener sonido; ni tocando la notificacion ni entrando a la aplicacion". Causa probable: con la app cerrada, al abrirla el estado ya nace en "active" y no hay ningun evento "change" que corte la sirena (y la notificacion tocada se entrega antes de que exista el oyente).
import re
R = '/home/user/Murray/scripts/'
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
a1 = '    suscripciones.push(\n      AppState.addEventListener("change", (estado) => {\n'
b1 = ('    // App abierta desde cero (la sirena sono con la app cerrada): el estado ya nace en "active" y no hay evento "change", asi que se corta al arrancar.\n'
      '    // Con el Modo perdido activo no se corta (se mira el estado guardado, no el de pantalla, que recien se esta cargando).\n'
      '    void loadLostModeState()\n'
      '      .then((enModoPerdido) => {\n'
      '        if (!enModoPerdido && !cancelado) apagarSirena();\n'
      '      })\n'
      '      .catch(() => undefined);\n') + a1
filas = [('App.tsx', 'sirena: tambien se apaga al abrir la app desde cero', a1, b1)]
cambios = "$cambios = @(\n    ,@(%s, %s, %s, %s)\n)\n" % tuple(psq(x) for x in filas[0])
cabeza = '''# aplicar-sirena-apaga2-app.ps1 - App (PROXIMA build, Android): completa aplicar-sirena-apaga-app.ps1.
# Luciano (04/11/2026, build 189): con la app cerrada y "Hacer sonar" desde el panel, la sirena solo se corto con "Detener sonido"; ni tocando la notificacion ni entrando a la app.
# Causa probable: al abrir la app desde cero el estado ya nace en "active" (no hay evento de cambio) y la notificacion tocada se entrega antes de que exista el oyente. Ahora, al arrancar, tambien corta la sirena (salvo Modo perdido).
# Toca solo App.tsx (respaldo .bak-sirena-apaga2). Requiere haber aplicado aplicar-sirena-apaga-app.ps1. Va en la carpeta de la APP.
'''
i = base.index('$ErrorActionPreference'); j = base.index('Ok "Carpeta correcta"')
guardas = '''Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "App.tsx"))) { Mal "No encuentro App.tsx en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "App.tsx")).texto 'apagarSirena') -eq 0) { Mal "Falta aplicar primero aplicar-sirena-apaga-app.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "App.tsx")).texto 'App abierta desde cero') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('.bak-version', '.bak-sirena-apaga2')
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "LISTO: la app compila bien. Sale en la PROXIMA build (Android)."', cola)
total = cabeza + base[i:j] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—']
assert not bad, set(bad)
open(R + 'aplicar-sirena-apaga2-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
