# Genera scripts/aplicar-sirena-apaga-app.ps1: la sirena que la app toca cuando llega un SOS o un "Hacer sonar" (1) dura 20 s si viene de un SOS (60 s si viene del panel) y (2) se apaga sola cuando la persona toca el aviso o entra a la app.
import re
R = '/home/user/Murray/scripts/'
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"

# --- src\earbudTone.ts: la duracion pasa a ser un parametro (por defecto, 60 s como hasta ahora) ---
a1 = 'export async function playPhoneAlarmTone(): Promise<string> {\n'
b1 = ('/**\n'
      ' * Cuanto suena la sirena de una orden "Hacer sonar". Las ordenes que genera un SOS vencen a los 3 minutos (las del panel, a la hora):\n'
      ' * esas son un aviso y no una busqueda, asi que suenan 20 segundos. Para encontrar un telefono perdido siguen los 60 de siempre.\n'
      ' */\n'
      'function duracionSirenaDeOrden(venceEn?: string | null): number {\n'
      '  const resto = venceEn ? new Date(venceEn).getTime() - Date.now() : Number.NaN;\n'
      '  return Number.isFinite(resto) && resto <= 4 * 60_000 ? 20_000 : 60_000;\n'
      '}\n'
      '\n'
      'export async function playPhoneAlarmTone(venceEn?: string | null): Promise<string> {\n'
      '  const duracionMs = duracionSirenaDeOrden(venceEn);\n')
a2 = '    return await playAlarmThroughSpeaker(uri, 60_000);\n'
b2 = '    return await playAlarmThroughSpeaker(uri, duracionMs);\n'
a3 = '    activeAlarmTimeout = setTimeout(() => stopActiveAlarmPlayer(), 60_000);\n'
b3 = '    activeAlarmTimeout = setTimeout(() => stopActiveAlarmPlayer(), duracionMs);\n'

# --- src\backgroundRemoteTask.ts: la sirena en segundo plano usa el vencimiento de la orden ---
a4 = '        void playPhoneAlarmTone().catch(() => undefined);\n'
b4 = '        void playPhoneAlarmTone(command.expiresAt).catch(() => undefined);\n'

# --- App.tsx: idem en primer plano, y se apaga al tocar el aviso o entrar a la app ---
a5 = '        await playPhoneAlarmTone();\n'
b5 = '        await playPhoneAlarmTone(command.expiresAt);\n'
a6 = '          shouldShowList: true,\n        }),\n      });\n    });\n  }, []);\n'
b6 = a6 + '''
  // La sirena del SOS / "Hacer sonar" se apaga sola apenas la persona toca el aviso o entra a la app (antes seguia sonando hasta el final).
  // Con el Modo perdido activo no: ahi la sirena solo la corta el codigo o "Detener sonido".
  useEffect(() => {
    if (lostModeActive) return undefined;
    let cancelado = false;
    const suscripciones: { remove: () => void }[] = [];
    const apagarSirena = () => {
      stopPhoneAlarmTone();
      void loadNativeNotifications()
        .then(async (notifications) => {
          if (!notifications) return;
          const visibles = await notifications.getPresentedNotificationsAsync().catch(() => []);
          for (const aviso of visibles) {
            const datos = aviso.request.content.data as { kind?: string; type?: string } | null | undefined;
            if (datos?.kind === "ring" || datos?.type === "sos") {
              await notifications.dismissNotificationAsync(aviso.request.identifier).catch(() => undefined);
            }
          }
        })
        .catch(() => undefined);
    };
    suscripciones.push(
      AppState.addEventListener("change", (estado) => {
        if (estado === "active") apagarSirena();
      }),
    );
    void loadNativeNotifications().then((notifications) => {
      if (cancelado || !notifications) return;
      suscripciones.push(notifications.addNotificationResponseReceivedListener(() => stopPhoneAlarmTone()));
    });
    return () => {
      cancelado = true;
      for (const s of suscripciones) s.remove();
    };
  }, [lostModeActive]);
'''

filas = [('src\\earbudTone.ts', 'sirena: la duracion pasa a ser un parametro', a1, b1),
         ('src\\earbudTone.ts', 'sirena: duracion en el camino nativo de Android', a2, b2),
         ('src\\earbudTone.ts', 'sirena: duracion en el corte automatico', a3, b3),
         ('src\\backgroundRemoteTask.ts', 'sirena en segundo plano: duracion segun la orden', a4, b4),
         ('App.tsx', 'sirena en primer plano: duracion segun la orden', a5, b5),
         ('App.tsx', 'sirena: se apaga al tocar el aviso o entrar a la app', a6, b6)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-sirena-apaga-app.ps1 - App (PROXIMA build, Android): la sirena que la app toca con un SOS o con "Hacer sonar".
# Luciano (03/11/2026): "la sirena es muy larga y se tendra que apagar cuando la persona abre la notificacion o entra a la aplicacion; si estas en un lugar social no la podes frenar".
#  1) Si la orden viene de un SOS (vence a los 3 minutos) la sirena de la app dura 20 segundos; si viene del panel (vence a la hora) sigue durando 60, para encontrar un telefono perdido.
#  2) Se apaga sola cuando la persona toca el aviso o entra a la app, y saca de la bandeja el aviso del SOS / de la busqueda. Con el Modo perdido activo no se apaga sola.
# Toca src\\earbudTone.ts, src\\backgroundRemoteTask.ts y App.tsx (respaldo .bak-sirena-apaga). Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba.
'''
i = base.index('$ErrorActionPreference'); j = base.index('Ok "Carpeta correcta"')
motor_ini = base[i:j]
guardas = '''Ok "Carpeta correcta"
foreach ($f in @("App.tsx", "src\\earbudTone.ts", "src\\backgroundRemoteTask.ts")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\\earbudTone.ts")).texto 'function duracionSirenaDeOrden') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('.bak-version', '.bak-sirena-apaga')
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "LISTO: la app compila bien. Sale en la PROXIMA build (Android)."', cola)
assert 'bak-version' not in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—']
assert not bad, set(bad)
open(R + 'aplicar-sirena-apaga-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
