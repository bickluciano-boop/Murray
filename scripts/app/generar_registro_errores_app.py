# Genera scripts/aplicar-registro-errores-app.ps1 (app, PROXIMA build, Android e iPhone).
# Luciano (20/11/2026): en Salud, la tarjeta del reloj con deteccion de caidas. Es SOLO informativa (no se conecta con ningun reloj, sin precios ni tiendas).
# Agrega src\RelojCaidasAviso.tsx y toca src\TarjetaSaludEntrada.tsx en dos puntos (un import y una linea debajo de "Salud y emergencias"). NO toca App.tsx, el mapa ni el Inicio.
import re, hashlib, subprocess
R = '/home/user/Murray/scripts/'
COMMIT_ARCHIVOS = 'b67472b191d3c2cbd6fe661f7db27f454f307abf'
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
def sha(ruta):
    return hashlib.sha256(open(ruta, 'rb').read()).hexdigest()
nuevos = []
descargas = "$descargas = @()\n"
F = 'src\\backgroundRemoteTask.ts'
P_A = '      try {\n        const result = await runBackgroundCommandSync();\n'
P_B = '      try {\n        // 20/11/2026: anota que este camino (el aviso que despierta a la app) ARRANCO. Hasta hoy no dejaba ninguna huella y no se podia saber si Android lo habia llamado.\n        await Promise.resolve(recordFullScreenAlertAttempt({ reason: "push-task-start", moduleFound: true, result: true, error: null })).catch(() => undefined);\n        const result = await runBackgroundCommandSync();\n'
E_A = '      } catch {\n        return Notifications.BackgroundNotificationTaskResult.Failed;\n'
E_B = '      } catch (error) {\n        // 20/11/2026: antes el error se tragaba sin dejar nada anotado.\n        await Promise.resolve(recordFullScreenAlertAttempt({ reason: "sync-error", moduleFound: true, result: false, error: `push: ${String(error)}` })).catch(() => undefined);\n        return Notifications.BackgroundNotificationTaskResult.Failed;\n'
A_A = '      await runBackgroundCommandSync("exact-alarm");\n    } catch {\n'
A_B = '      await runBackgroundCommandSync("exact-alarm");\n    } catch (error) {\n      // 20/11/2026: antes el error se tragaba sin dejar nada anotado (a las 00:11 la alarma arranco y no leyo las ordenes, sin saber por que).\n      await Promise.resolve(recordFullScreenAlertAttempt({ reason: "sync-error", moduleFound: true, result: false, error: `exact-alarm: ${String(error)}` })).catch(() => undefined);\n'
filas = [(F, 'registro: anotar que el aviso que despierta a la app arranco', P_A, P_B),
         (F, 'registro: anotar el error del aviso que despierta a la app', E_A, E_B),
         (F, 'registro: anotar el error de la alarma exacta', A_A, A_B)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-registro-errores-app.ps1 - App (PROXIMA build, Android e iPhone). Luciano (20/11/2026): las ordenes de la consola tardaban 10-30 min con el telefono quieto y el registro tecnico no decia por que.
# SOLO anota en el registro tecnico (no cambia ninguna funcion): (1) cuando el aviso que despierta a la app ARRANCA la tarea, (2) el error si esa tarea falla, (3) el error si falla la alarma exacta. Hasta hoy los dos errores se tragaban sin dejar nada.
# Cambia src\\backgroundRemoteTask.ts (respaldo .bak-regerr). Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba.
'''
i0 = base.index('$ErrorActionPreference'); j0 = base.index('Ok "Carpeta correcta"')
guardas = '''Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\backgroundRemoteTask.ts"))) { Mal "No encuentro src\\backgroundRemoteTask.ts en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\backgroundRemoteTask.ts")).texto 'reason: "sync-error"') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\backgroundRemoteTask.ts")).texto 'recordFullScreenAlertAttempt') -eq 0) { Mal "No encuentro recordFullScreenAlertAttempt en backgroundRemoteTask.ts. Mandame esta pantalla."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('$descargas = @()\n', descargas, 1).replace('.bak-version', '.bak-regerr')
MENSAJE = 'LISTO: la app compila bien. El registro tecnico ahora anota cuando el aviso despierta a la app y los errores de las lecturas en segundo plano (sale en la PROXIMA build, Android e iPhone).'
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "%s"' % MENSAJE, cola)
assert MENSAJE in cola and 'bak-version' not in cola
total = cabeza + base[i0:j0] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕‹›→']
assert not bad, set(bad)
open(R + 'aplicar-registro-errores-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
muestra = '''TaskManager.defineTask<Notifications.NotificationTaskPayload>(
    BACKGROUND_REMOTE_TASK,
    async () => {
      try {
        const result = await runBackgroundCommandSync();
        return result.executedCount > 0
          ? Notifications.BackgroundNotificationTaskResult.NewData
          : Notifications.BackgroundNotificationTaskResult.NoData;
      } catch {
        return Notifications.BackgroundNotificationTaskResult.Failed;
      }
    },
  );
if (Platform.OS === "android") {
  AppRegistry.registerHeadlessTask("OjoGuardExactAlarmTask", () => async () => {
    try {
      await runBackgroundCommandSync("exact-alarm");
    } catch {
      // Nada que hacer aqui: la proxima alarma reprogramada va a reintentar.
    }
  });
}
'''
for a, n, v, nv in filas:
    assert muestra.count(v) == 1, (n, muestra.count(v))
out = muestra
for a, n, v, nv in filas:
    out = out.replace(v, nv)
assert out.count('reason: "sync-error"') == 2 and 'push-task-start' in out and 'Nada que hacer' in out
print(out)
print('ok', len(total))
