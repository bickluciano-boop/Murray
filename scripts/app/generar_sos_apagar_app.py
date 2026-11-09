# Genera scripts/aplicar-sos-apagar-app.ps1: apagar mi SOS del todo (dos confirmaciones) y volver a prenderlo, dentro de la tarjeta CUIDADO.
import re
R = '/home/user/Murray/scripts/'
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
filas = []
def fila(archivo, nombre, a, b):
    filas.append((archivo, nombre, a, b))

# ---- remoteApi.ts ----
fila('src\\remoteApi.ts', 'sos apagado: tipo', '  destinatarios: string[];\n};\n', '  destinatarios: string[];\n  sosOff: boolean;\n};\n')
fila('src\\remoteApi.ts', 'sos apagado: lectura', '    destinatarios: Array.isArray(r.destinatarios) ? r.destinatarios.map((x) => String(x)) : [],\n', '    destinatarios: Array.isArray(r.destinatarios) ? r.destinatarios.map((x) => String(x)) : [],\n    sosOff: r.sosOff === true,\n')
fila('src\\remoteApi.ts', 'sos apagado: llamada', '/** Contestar "estoy bien" al Buen dia', '''/** Apagar (off = true) o volver a prender MI SOS. Apagado, el SOS no le llega a nadie; el servidor avisa a quienes lo recibian. */
export async function setSosOff(enrollment: NativeEnrollment, off: boolean) {
  await nativeRequest(enrollment, "/api/native/care/sos", {
    method: "POST",
    body: JSON.stringify({ deviceId: enrollment.deviceId, off }),
  });
}

/** Contestar "estoy bien" al Buen dia''')

# ---- FamiliaPantalla.tsx ----
fila('src\\FamiliaPantalla.tsx', 'sos apagado: importar la llamada',
     'import { answerBuenDia, fetchCare, fetchFamily, joinFamily, leaveFamily, pauseFamilyLocation, setCarePrefs, setFamilyPermission, type CambiosCuidado, type CuidadoEstado, type FamilyPerson } from "./remoteApi";',
     'import { answerBuenDia, fetchCare, fetchFamily, joinFamily, leaveFamily, pauseFamilyLocation, setCarePrefs, setFamilyPermission, setSosOff, type CambiosCuidado, type CuidadoEstado, type FamilyPerson } from "./remoteApi";')
fila('src\\FamiliaPantalla.tsx', 'sos apagado: la tarjeta avisa a la pantalla',
     'function TarjetaCuidado({ P, enrollment, botones }: { P: Paleta; enrollment: NativeEnrollment; botones: { primario: StyleProp<ViewStyle>; primarioTexto: StyleProp<TextStyle>; ayuda: StyleProp<TextStyle> } }) {',
     'function TarjetaCuidado({ P, enrollment, botones, onSosApagado }: { P: Paleta; enrollment: NativeEnrollment; botones: { primario: StyleProp<ViewStyle>; primarioTexto: StyleProp<TextStyle>; ayuda: StyleProp<TextStyle> }; onSosApagado: (apagado: boolean) => void }) {')
fila('src\\FamiliaPantalla.tsx', 'sos apagado: efecto',
     '  useEffect(() => {\n    void cargar();\n  }, [cargar]);\n  if (!cuidado) return null;\n',
     '  useEffect(() => {\n    void cargar();\n  }, [cargar]);\n  const sosApagadoAhora = cuidado?.sosOff;\n  useEffect(() => {\n    if (sosApagadoAhora !== undefined) onSosApagado(sosApagadoAhora);\n  }, [sosApagadoAhora, onSosApagado]);\n  if (!cuidado) return null;\n')
fila('src\\FamiliaPantalla.tsx', 'sos apagado: apagar con dos confirmaciones',
     '  const { prefs, hoy, destinatarios } = actual;\n',
     r'''  const { prefs, hoy, destinatarios } = actual;
  // Apagar el SOS del todo: lugar deliberado + DOS confirmaciones (lo decide la propia persona; nadie lo hace por ella).
  const cambiarSos = async (off: boolean) => {
    setAviso("");
    setGuardando((g) => [...g, "sos"]);
    setCuidado({ ...actual, sosOff: off });
    try {
      await setSosOff(enrollment, off);
      void cargar();
    } catch (error) {
      setCuidado(actual);
      const codigo = error instanceof Error ? error.message : "";
      setAviso(codigo === "minor_locked" ? "Con un menor no se puede apagar el SOS." : "No se pudo guardar. Probá de nuevo.");
    } finally {
      setGuardando((g) => g.filter((x) => x !== "sos"));
    }
  };
  const confirmarApagarSos = () => {
    const quienes = destinatarios.length ? listaDeNombres(destinatarios) : "nadie";
    Alert.alert(
      "¿Apagar tu SOS?",
      `Si lo apagás, tu SOS no le va a llegar a nadie (hoy le llega a: ${quienes}). Tampoco van a avisar la batería ni el Buen día. Ellos van a recibir un aviso de que lo apagaste.`,
      [
        { text: "Cancelar", style: "cancel" },
        {
          text: "Seguir",
          style: "destructive",
          onPress: () =>
            Alert.alert("Última confirmación", "Si te pasa algo, nadie va a saber que pediste ayuda. ¿Apagar tu SOS igual?", [
              { text: "No, dejarlo prendido", style: "cancel" },
              { text: "Sí, apagar mi SOS", style: "destructive", onPress: () => void cambiarSos(true) },
            ]),
        },
      ],
    );
  };
''')
fila('src\\FamiliaPantalla.tsx', 'sos apagado: seccion en la tarjeta',
     '        {aviso ? <View style={sp.cartel}><Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.cartelTexto}>{aviso}</Text></View> : null}\n      </View>\n    </>\n  );\n}\n',
     r'''        <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.separador}>MI SOS</Text>
        {actual.sosOff ? (
          <>
            <View style={sp.cartel}>
              <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.cartelTexto}>Tu SOS está apagado: no le llega a nadie, y la batería y el Buen día tampoco avisan.</Text>
            </View>
            <Pressable accessibilityRole="button" disabled={guardando.includes("sos")} onPress={() => void cambiarSos(false)} style={botones.primario}>
              <Text style={botones.primarioTexto}>Prender mi SOS</Text>
            </Pressable>
          </>
        ) : (
          <Pressable accessibilityRole="button" disabled={guardando.includes("sos")} onPress={confirmarApagarSos}>
            <Text maxFontSizeMultiplier={TOPE_LETRA} style={{ color: P.peligroFuerte ?? P.peligro, fontSize: 13.5, fontWeight: "700", textDecorationLine: "underline" }}>Apagar mi SOS…</Text>
          </Pressable>
        )}
        {aviso ? <View style={sp.cartel}><Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.cartelTexto}>{aviso}</Text></View> : null}
      </View>
    </>
  );
}
''')
fila('src\\FamiliaPantalla.tsx', 'sos apagado: estado de la pantalla', '  const pendientesPerm = useRef(0);\n', '  const pendientesPerm = useRef(0);\n  const [sosApagado, setSosApagado] = useState(false);\n')
fila('src\\FamiliaPantalla.tsx', 'sos apagado: tarjeta en la pantalla',
     '{enrollment ? <TarjetaCuidado P={P} enrollment={enrollment} botones={botones} /> : null}',
     '{enrollment ? <TarjetaCuidado P={P} enrollment={enrollment} botones={botones} onSosApagado={setSosApagado} /> : null}')
fila('src\\FamiliaPantalla.tsx', 'sos apagado: el texto de la tarjeta SOS',
     ': "Hoy tu SOS no le suena a nadie en la app. Sumá a alguien desde el mapa del Inicio."}',
     ': sosApagado ? "Tu SOS está apagado: no le suena a nadie. Prendelo en la tarjeta CUIDADO." : "Hoy tu SOS no le suena a nadie en la app. Sumá a alguien desde el mapa del Inicio."}')
# ---- SosBlock.tsx y sosTask.ts: el mensaje cuando el SOS esta apagado ----
fila('src\\SosBlock.tsx', 'sos apagado: mensaje al apretar el SOS',
     '  no_recipients: "No hay nadie a quien avisar. Sumá a alguien a tu familia primero.",\n',
     '  no_recipients: "No hay nadie a quien avisar. Sumá a alguien a tu familia primero.",\n  sos_off: "Tu SOS está apagado. Prendelo en Ajustes, Familia y amigos, tarjeta CUIDADO.",\n')
fila('src\\sosTask.ts', 'sos apagado: aviso del SOS en segundo plano',
     '            ? "No hay nadie a quien avisar: sumá a alguien a tu familia."\n            : "Revisá la conexión y probá de nuevo. Si es una emergencia, llamá a emergencias.",\n',
     '            ? "No hay nadie a quien avisar: sumá a alguien a tu familia."\n            : codigo === "sos_off"\n              ? "Tu SOS está apagado. Prendelo en Ajustes, Familia y amigos."\n              : "Revisá la conexión y probá de nuevo. Si es una emergencia, llamá a emergencias.",\n')

cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-sos-apagar-app.ps1 - App (PROXIMA build): apagar mi SOS del todo (dos confirmaciones) y prenderlo de nuevo, dentro de la tarjeta CUIDADO.
# Luciano (09/11/2026, "si, dejalo asi"): las llaves rapidas de PERMISOS mantienen "siempre queda alguien", pero un adulto decide por si mismo: puede apagar su SOS del todo desde un lugar deliberado, con confirmacion fuerte; los demas reciben un aviso.
# Apagado, el SOS no sale y avisa por que (en el boton y en el aviso de segundo plano); la tarjeta SOS dice que esta apagado en vez de "no hay nadie".
# Requiere aplicar-cuidado-app.ps1 y el servidor aplicar-sos-apagar-panel.ps1. Toca src\\remoteApi.ts, src\\FamiliaPantalla.tsx, src\\SosBlock.tsx y src\\sosTask.ts (respaldo .bak-sosoff). Va en la carpeta de la APP.
'''
i0 = base.index('$ErrorActionPreference'); j0 = base.index('Ok "Carpeta correcta"')
guardas = '''Ok "Carpeta correcta"
foreach ($f in @("src\\FamiliaPantalla.tsx", "src\\remoteApi.ts", "src\\SosBlock.tsx", "src\\sosTask.ts")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\\FamiliaPantalla.tsx")).texto 'function TarjetaCuidado') -eq 0) { Mal "Falta aplicar primero aplicar-cuidado-app.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\\FamiliaPantalla.tsx")).texto 'const confirmarApagarSos') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('.bak-version', '.bak-sosoff')
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "LISTO: la app compila bien. Sale en la PROXIMA build."', cola)
total = cabeza + base[i0:j0] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—']
assert not bad, set(bad)
open(R + 'aplicar-sos-apagar-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
