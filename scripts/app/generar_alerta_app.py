# Genera scripts/aplicar-medicamentos-alerta-app.ps1 (app, PROXIMA build).
# Luciano (18/11/2026): avisos de medicamentos mas notorios "pero que no sea invasiva: solo que si se pone en silencio el telefono pueda vibrar o un flash, en el caso de que la persona no escuche bien".
# Lo que la app puede y no puede hacer (honesto): ni Android ni iPhone dejan que una app suene o vibre con el telefono en SILENCIO TOTAL (solo una alarma de pantalla completa lo haria, y eso es invasivo).
#  - Android: canal nuevo "ojo-medicamentos-2" (cartel arriba, sonido corto, vibracion larga 400-200-400, luz de aviso). Con el telefono en "vibrar" vibra.
#  - Destello (flash de camara / pantalla): lo da el SISTEMA ("Notificacion con flash" en Android, "Flash LED para alertas" en iPhone), no la app. La tarjeta MEDICAMENTOS suma una linea chica
#    "¿No oyes bien los avisos?" que, al tocarla, explica como activarlo y abre los ajustes. No es invasiva: viene cerrada.
import re
R = '/home/user/Murray/scripts/'
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
F, APP = 'src\\FamiliaPantalla.tsx', 'App.tsx'

COMPONENTE = '''/** "¿No oyes bien los avisos?": una linea chica que viene cerrada; al tocarla explica como activar el destello y la vibracion del telefono y abre los ajustes. No es invasiva. */
function AyudaAvisos({ P }: { P: Paleta }) {
  const [abierta, setAbierta] = useState(false);
  const abrirAjustes = () => {
    if (Platform.OS === "android") {
      Linking.sendIntent("android.settings.ACCESSIBILITY_SETTINGS").catch(() => void Linking.openSettings());
    } else {
      void Linking.openSettings();
    }
  };
  const texto =
    Platform.OS === "android"
      ? "Si no oyes bien, el teléfono puede avisarte con un destello y con vibración. Destello: en Ajustes → Accesibilidad busca «flash» (se llama «Notificación con flash» o «Flash de cámara»). Vibración: deja el teléfono en «vibrar» y no en silencio total; en silencio total Android no deja que ninguna app suene ni vibre."
      : "Si no oyes bien, el iPhone puede avisarte con un destello y con vibración. Destello: Ajustes → Accesibilidad → Audio y visual → «Flash LED para alertas». Vibración: Ajustes → Sonidos y vibraciones → «Vibrar en silencio»; así, con el interruptor lateral en silencio, igual vibra.";
  return (
    <View style={{ gap: 6 }}>
      <Pressable accessibilityRole="button" accessibilityState={{ expanded: abierta }} onPress={() => setAbierta((a) => !a)}>
        <Text maxFontSizeMultiplier={TOPE_LETRA} style={{ color: P.textoClaro, fontSize: 13.5, fontWeight: "700", textDecorationLine: "underline" }}>{abierta ? "Ocultar" : "¿No oyes bien los avisos?"}</Text>
      </Pressable>
      {abierta ? (
        <>
          <Text maxFontSizeMultiplier={TOPE_LETRA} style={{ color: P.textoDebil, fontSize: 13, lineHeight: 19 }}>{texto}</Text>
          <Pressable accessibilityRole="button" onPress={abrirAjustes} style={{ alignSelf: "flex-start", borderColor: P.borde, borderRadius: 12, borderWidth: 1, paddingHorizontal: 12, paddingVertical: 8 }}>
            <Text maxFontSizeMultiplier={TOPE_LETRA} style={{ color: P.textoClaro, fontSize: 13.5, fontWeight: "700" }}>{Platform.OS === "android" ? "Abrir ajustes de accesibilidad" : "Abrir ajustes"}</Text>
          </Pressable>
        </>
      ) : null}
    </View>
  );
}

'''
M_A = 'function moverHoraRemedio(hhmm: string, pasos: number): string {\n'
U_A = '        {actual.atrasadas.length ? (\n          <>\n            <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.separador}>PENDIENTES</Text>\n'
CANAL_A = '      void notifications.setNotificationChannelAsync("ojo-alertas", {\n'
CANAL_B = '''      // Recordatorio de medicamentos (v2): cartel arriba con sonido corto, vibracion larga y luz de aviso. Suave, nada de alarma. (Con el telefono en silencio total ninguna app puede sonar ni vibrar; el destello lo da el sistema.)
      void notifications.setNotificationChannelAsync("ojo-medicamentos-2", {
        name: "Recordatorio de medicamentos",
        description: "Un sonido corto, vibración y luz de aviso a la hora de tus medicamentos.",
        importance: notifications.AndroidImportance.HIGH,
        sound: "default",
        enableVibrate: true,
        vibrationPattern: [0, 400, 200, 400],
        enableLights: true,
        lightColor: "#FFB300",
        lockscreenVisibility: notifications.AndroidNotificationVisibility.PUBLIC,
      });
''' + CANAL_A
filas = [
 (F, 'alerta: ayuda del destello y la vibracion (componente)', M_A, COMPONENTE + M_A),
 (F, 'alerta: la linea "No oyes bien los avisos" va arriba de PENDIENTES', U_A, '        <AyudaAvisos P={P} />\n' + U_A),
 (APP, 'alerta: canal de Android nuevo con cartel, vibracion larga y luz', CANAL_A, CANAL_B),
]
def cambios_ps(fs):
    return "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in fs) + "\n)\n"
i0 = base.index('$ErrorActionPreference'); j0 = base.index('Ok "Carpeta correcta"')
cola = base[base.index('$descargas = @()'):].replace('.bak-version', '.bak-alerta')
MENSAJE = 'LISTO: la app compila bien. Avisos de medicamentos con cartel, vibracion larga y ayuda para el destello (sale en la PROXIMA build, Android e iPhone).'
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "%s"' % MENSAJE, cola)
assert MENSAJE in cola
cabeza = '''# aplicar-medicamentos-alerta-app.ps1 - App (PROXIMA build). Luciano (18/11/2026): avisos de medicamentos mas notorios pero NO invasivos: que si el telefono esta en silencio pueda vibrar, o un destello, para quien no oye bien.
# Android: canal nuevo "ojo-medicamentos-2" (cartel arriba, sonido corto, vibracion larga, luz de aviso). Tarjeta MEDICAMENTOS: linea chica cerrada "¿No oyes bien los avisos?" que explica como activar el destello del sistema y abre los ajustes.
# Toca src\\FamiliaPantalla.tsx y App.tsx (respaldo .bak-alerta). Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba. El servidor (aplicar-medicamentos-alerta-panel.ps1) se aplica DESPUES de las builds.
'''
guardas = '''Ok "Carpeta correcta"
foreach ($f in @("src\\FamiliaPantalla.tsx", "App.tsx")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "App.tsx")).texto 'ojo-medicamentos-2') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\FamiliaPantalla.tsx")).texto '>PENDIENTES</Text>') -eq 0) { Mal "Falta aplicar primero aplicar-medicamentos-pendientes-app.ps1."; return }
'''
total = cabeza + base[i0:j0] + guardas + cambios_ps(filas) + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕‹›→']
assert not bad, set(bad)
open(R + 'aplicar-medicamentos-alerta-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
open('/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/tcx/componente.txt', 'w', encoding='utf-8').write(COMPONENTE)
print('ok', len(total), len(filas), 'filas')
