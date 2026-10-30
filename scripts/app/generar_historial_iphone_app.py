# Genera scripts/aplicar-historial-iphone-app.ps1: en Configuracion > Registros tecnicos, el "Historial de segundo plano" (donde la app anota si "Hacer sonar" arranco: "iPhone: sonando / NO suena") ahora tambien se ve en iPhone. Antes solo se dibujaba en Android.
import re
R = '/home/user/Murray/scripts/'
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
a1 = '            <Plegable titulo="Registros técnicos (para soporte)" paleta={P}>\n            {Platform.OS === "android" ? (\n'
b1 = '            <Plegable titulo="Registros técnicos (para soporte)" paleta={P}>\n            {Platform.OS === "android" || Platform.OS === "ios" ? (\n'
a2 = '                  {describirRastroDeAviso(fullScreenAlertTrace, hasFullScreenAlertPermission())}\n'
b2 = '                  {Platform.OS === "android" ? describirRastroDeAviso(fullScreenAlertTrace, hasFullScreenAlertPermission()) : "iPhone: acá se anota lo que pasó en segundo plano, por ejemplo si el sonido de Hacer sonar arrancó."}\n'
filas = [('App.tsx', 'registros tecnicos: el historial tambien en iPhone', a1, b1), ('App.tsx', 'registros tecnicos: texto del iPhone', a2, b2)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-historial-iphone-app.ps1 - App (PROXIMA build): el "Historial de segundo plano" de Configuracion > Registros tecnicos tambien se ve en iPhone.
# Motivo (30/10/2026): en iPhone la app anota "iPhone: sonando / NO suena" cuando llega "Hacer sonar", pero esa lista solo se dibujaba en Android, y asi no se podia saber por que no suena con la app en segundo plano.
# Cambia SOLO App.tsx (respaldo .bak-historial-iphone). Va en la carpeta de la APP.
'''
i = base.index('$ErrorActionPreference'); j = base.index('Ok "Carpeta correcta"')
motor_ini = base[i:j]
guardas = '''Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "App.tsx"))) { Mal "No encuentro App.tsx en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "App.tsx")).texto 'acá se anota lo que pasó en segundo plano') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('.bak-version', '.bak-historial-iphone')
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "LISTO: la app compila bien. Sale en la PROXIMA build."', cola)
assert 'bak-version' not in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—']
assert not bad, set(bad)
open(R + 'aplicar-historial-iphone-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
