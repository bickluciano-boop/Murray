# Genera scripts/aplicar-sos-discreto-app.ps1 (app, PROXIMA build, iPhone y Android). Requiere aplicar-sos-cuenta-atras-app.ps1.
# Luciano (18/11/2026): (1) "cuando apretas tres veces la mayoria de las veces no te da tiempo a desactivar porque la pantalla se apaga y hasta que lee Face ID ya la hizo sonar";
# (2) "tiene que ser un poco disimulado: si te estan por robar no esta bueno ver algo muy llamativo". Opcion B elegida por Luciano, en version DISCRETA:
#  - Telefono bloqueado o app en segundo plano: la cuenta es de 15 s (antes 5) y el unico rastro es un aviso NEUTRO ("Ojo Guard - Toca para revisar", sin SOS ni familia ni botones).
#    Al desbloquear y abrir la app se ve la pantalla con al menos 5 s para cancelar.
#  - Pantalla a la vista: 5 s, pantalla casi negra con un numero tenue y un "Cancelar" sobrio; no dice SOS ni familia, sin rojo ni parpadeos ni pitidos por segundo.
# Reemplaza src\sosCuentaAtras.ts y src\SosCuentaAtrasPantalla.tsx (respaldo .bak-sosdiscreto). No toca sosTask.ts: el enlace del atajo sigue llamando a iniciarCuentaAtras.
import re, hashlib
R = '/home/user/Murray/scripts/'
COMMIT_ARCHIVOS = '654f51851f0f38ff15f5f0cbe6f5045e850bb858'
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
def sha(ruta):
    return hashlib.sha256(open(ruta, 'rb').read()).hexdigest()
nuevos = [('sosCuentaAtras.ts', 'src\\sosCuentaAtras.ts'), ('SosCuentaAtrasPantalla.tsx', 'src\\SosCuentaAtrasPantalla.tsx')]
descargas = "$descargas = @(\n" + ',\n'.join("    @(%s, %s, %s)" % (psq('https://raw.githubusercontent.com/bickluciano-boop/Murray/%s/scripts/app/src/%s' % (COMMIT_ARCHIVOS, a)), psq(b), psq(sha(R + 'app/src/' + a))) for a, b in nuevos) + "\n)\n"
cabeza = '''# aplicar-sos-discreto-app.ps1 - App (PROXIMA build, iPhone y Android). Luciano (18/11/2026): el SOS del atajo (tres toques en la espalda) salia antes de poder cancelar porque la cuenta de 5 s corria con el telefono bloqueado; y
# "tiene que ser un poco disimulado: si te estan por robar no esta bueno ver algo muy llamativo". Con el telefono bloqueado la cuenta es de 15 s y solo deja un aviso neutro ("Ojo Guard - Toca para revisar"); con la pantalla a la vista son 5 s
# en una pantalla casi negra con un numero tenue y un "Cancelar" sobrio (sin la palabra SOS ni familia). Requiere aplicar-sos-cuenta-atras-app.ps1. Reemplaza src\\sosCuentaAtras.ts y src\\SosCuentaAtrasPantalla.tsx (respaldo .bak-sosdiscreto).
# Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba.
'''
i0 = base.index('$ErrorActionPreference'); j0 = base.index('Ok "Carpeta correcta"')
guardas = '''Ok "Carpeta correcta"
foreach ($f in @("src\\sosTask.ts", "src\\sosCuentaAtras.ts", "src\\SosCuentaAtrasPantalla.tsx")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + ". Falta aplicar primero aplicar-sos-cuenta-atras-app.ps1."); return } }
if ((Contar (Leer (Join-Path $raiz "src\\sosTask.ts")).texto 'iniciarCuentaAtras') -eq 0) { Mal "Falta aplicar primero aplicar-sos-cuenta-atras-app.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\\sosCuentaAtras.ts")).texto 'CUENTA_ATRAS_BLOQUEADO_SEGUNDOS') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('$descargas = @()\n', descargas, 1).replace('.bak-version', '.bak-sosdiscreto')
MENSAJE = 'LISTO: la app compila bien. El SOS del atajo es discreto: 15 s con el telefono bloqueado (aviso neutro) y 5 s con la pantalla a la vista (sale en la PROXIMA build, Android e iPhone).'
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "%s"' % MENSAJE, cola)
assert MENSAJE in cola and 'bak-version' not in cola and 'raw.githubusercontent' in cola
# sin anclas: $cambios vacio
total = cabeza + base[i0:j0] + guardas + "$cambios = @()\n" + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕']
assert not bad, set(bad)
open(R + 'aplicar-sos-discreto-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
