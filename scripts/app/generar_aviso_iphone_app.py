# Genera scripts/aplicar-aviso-iphone-app.ps1: en la Ayuda (boton "?") de la app, solo en iPhone, un parrafo que explica como usar Ojo Guard para que responda a los pedidos (no cerrarla deslizando, actualizacion en segundo plano, tocar el aviso).
import re
R = '/home/user/Murray/scripts/'
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
a1 = '            <Text style={styles.helpText}>\n              Nunca compartas la clave de administrador ni la clave interna de la compañía.\n            </Text>\n'
b1 = a1 + ('            {Platform.OS === "ios" ? (\n'
           '              <Text style={styles.helpText}>\n'
           '                iPhone: para que Ojo Guard responda a los pedidos (Hacer sonar, Modo perdido, foto y audio), no la cierres deslizándola hacia arriba y dejá activada la Actualización en segundo plano (Ajustes del iPhone, General). Cuando llegue un aviso, tocalo o abrí la app y se hace lo pedido.\n'
           '              </Text>\n'
           '            ) : null}\n')
fila = ('App.tsx', 'ayuda: parrafo para iPhone', a1, b1)
cambios = "$cambios = @(\n    ,@(%s, %s, %s, %s)\n)\n" % tuple(psq(x) for x in fila)
cabeza = '''# aplicar-aviso-iphone-app.ps1 - App (PROXIMA build): en la Ayuda (boton "?"), solo en iPhone, un parrafo con lo que hay que hacer para que Ojo Guard responda a los pedidos.
# Motivo (31/10/2026): en iPhone iOS no deja que la app se abra sola ni use camara/sonido con la pantalla apagada; lo que se puede es no cerrarla deslizandola, dejar la actualizacion en segundo plano y tocar el aviso.
# Cambia SOLO App.tsx (respaldo .bak-aviso-iphone). Android no cambia. Va en la carpeta de la APP.
'''
i = base.index('$ErrorActionPreference'); j = base.index('Ok "Carpeta correcta"')
motor_ini = base[i:j]
guardas = '''Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "App.tsx"))) { Mal "No encuentro App.tsx en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "App.tsx")).texto 'iPhone: para que Ojo Guard responda a los pedidos') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('.bak-version', '.bak-aviso-iphone')
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "LISTO: la app compila bien. Sale en la PROXIMA build (se ve en la Ayuda, solo en iPhone)."', cola)
assert 'bak-version' not in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—']
assert not bad, set(bad)
open(R + 'aplicar-aviso-iphone-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
