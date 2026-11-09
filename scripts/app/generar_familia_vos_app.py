# Genera scripts/aplicar-familia-vos-app.ps1: tarjeta "VOS" arriba de Familia y amigos (tu nombre, tu rol y de quien es la familia) y cada persona con su rol y su tipo de telefono.
import re
R = '/home/user/Murray/scripts/'
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
filas = []
def fila(a, n, x, y):
    filas.append((a, n, x, y))
# ---- remoteApi.ts ----
fila('src\\remoteApi.ts', 'vos: llamada', '/** Salir de la familia de un titular (personId "titular:correo", como viene en fetchFamily). */\n', '''/** Quien sos "vos" en Familia y amigos: tu nombre, si sos titular y en que familias estas (con tu rol y el nombre del titular). */
export type FamiliaVos = { nombre: string; esTitular: boolean; familias: { titular: string; rol: string }[] };
export async function fetchFamilyMe(enrollment: NativeEnrollment): Promise<FamiliaVos> {
  const query = new URLSearchParams({ deviceId: enrollment.deviceId });
  const response = await nativeRequest(enrollment, `/api/native/family/me?${query.toString()}`);
  const r = (await response.json()) as Partial<FamiliaVos>;
  return {
    nombre: typeof r.nombre === "string" ? r.nombre : "",
    esTitular: r.esTitular === true,
    familias: Array.isArray(r.familias) ? r.familias.map((f) => ({ titular: String(f?.titular ?? ""), rol: String(f?.rol ?? "") })) : [],
  };
}

/** Salir de la familia de un titular (personId "titular:correo", como viene en fetchFamily). */
''')
# ---- FamiliaPantalla.tsx ----
fila('src\\FamiliaPantalla.tsx', 'vos: importar', 'import { answerBuenDia, fetchCare, fetchFamily,', 'import { answerBuenDia, fetchCare, fetchFamily, fetchFamilyMe, type FamiliaVos,')
fila('src\\FamiliaPantalla.tsx', 'vos: componente', '/** A quien le suena el SOS de esta persona', r'''/** "Vos": tu nombre, este telefono, tu rol y de quien es la familia (antes la lista solo mostraba a las demas personas y no se entendia cual era la tuya). */
function TarjetaVos({ P, enrollment, botones }: { P: Paleta; enrollment: NativeEnrollment; botones: { ayuda: StyleProp<TextStyle> } }) {
  const [vos, setVos] = useState<FamiliaVos | null>(null);
  useEffect(() => {
    let cancelado = false;
    void fetchFamilyMe(enrollment)
      .then((r) => {
        if (!cancelado) setVos(r);
      })
      .catch(() => undefined);
    return () => {
      cancelado = true;
    };
  }, [enrollment]);
  if (!vos) return null;
  const tipo = Platform.OS === "ios" ? "iPhone" : "Android";
  const lugares: string[] = [];
  if (vos.esTitular) lugares.push("Titular de tu propia familia");
  for (const f of vos.familias) lugares.push(`${ROL_CHIP[f.rol] ?? "Integrante"} en la familia de ${f.titular || "otra persona"}`);
  return (
    <>
      <Text style={{ color: P.textoDebil, fontSize: 12, fontWeight: "800", letterSpacing: 1.1, marginBottom: 8, marginTop: 4 }}>VOS</Text>
      <View style={{ backgroundColor: P.superficie, borderColor: P.borde, borderRadius: 18, borderWidth: 1, gap: 4, padding: 16 }}>
        <Text maxFontSizeMultiplier={TOPE_LETRA} style={{ color: P.texto, fontSize: 17, fontWeight: "800" }}>{vos.nombre || "Este teléfono"}</Text>
        <Text maxFontSizeMultiplier={TOPE_LETRA} style={botones.ayuda}>{`Este teléfono · ${tipo}`}</Text>
        {lugares.length ? lugares.map((t) => <Text key={t} maxFontSizeMultiplier={TOPE_LETRA} style={botones.ayuda}>{t}</Text>) : <Text maxFontSizeMultiplier={TOPE_LETRA} style={botones.ayuda}>Todavía no estás en ninguna familia.</Text>}
      </View>
    </>
  );
}

/** A quien le suena el SOS de esta persona''')
fila('src\\FamiliaPantalla.tsx', 'vos: en la pantalla', '          <View style={s.etiquetaFila}>\n            <Text style={s.etiqueta}>MI FAMILIA</Text>\n', '          <TarjetaVos P={P} enrollment={enrollment} botones={botones} />\n          <View style={s.etiquetaFila}>\n            <Text style={s.etiqueta}>MI FAMILIA</Text>\n')
fila('src\\FamiliaPantalla.tsx', 'vos: rol y tipo de telefono de cada persona',
     '  const rol = persona.owner ? "Titular" : (ROL_CHIP[persona.role] ?? "");\n',
     '  const plataforma = ((persona as { platform?: string }).platform ?? "").toLowerCase();\n  const telefono = plataforma.includes("ios") || plataforma.includes("iphone") ? "iPhone" : plataforma.includes("android") ? "Android" : "";\n  const rol = [persona.owner ? "Titular" : (ROL_CHIP[persona.role] ?? ""), telefono].filter(Boolean).join(" · ");\n')
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-familia-vos-app.ps1 - App (PROXIMA build): tarjeta "VOS" arriba de Familia y amigos, y cada persona con su rol y su tipo de telefono.
# Luciano (09/11/2026, capturas): "no logro entender cual es mi familia": la lista solo mostraba a las otras personas ("Lucho" y "Lu ipone"), nunca a vos ni de quien es la familia.
# Ahora: "VOS: tu nombre / Este telefono · Android / Adulto en la familia de Lucho"; y en PERMISOS cada persona dice "Titular · iPhone", "Adulto · Android"...
# Requiere aplicar-permisos-ojo4-app.ps1, aplicar-cuidado-app.ps1 y el servidor aplicar-familia-vos-panel.ps1 (sin eso la tarjeta VOS no se muestra). Toca src\\remoteApi.ts y src\\FamiliaPantalla.tsx (respaldo .bak-vos). Va en la carpeta de la APP.
'''
i0 = base.index('$ErrorActionPreference'); j0 = base.index('Ok "Carpeta correcta"')
guardas = '''Ok "Carpeta correcta"
foreach ($f in @("src\\FamiliaPantalla.tsx", "src\\remoteApi.ts")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\\FamiliaPantalla.tsx")).texto 'function TarjetaCuidado') -eq 0) { Mal "Falta aplicar primero aplicar-cuidado-app.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\\FamiliaPantalla.tsx")).texto 'function TarjetaVos') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('.bak-version', '.bak-vos')
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "LISTO: la app compila bien. Sale en la PROXIMA build."', cola)
total = cabeza + base[i0:j0] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—']
assert not bad, set(bad)
open(R + 'aplicar-familia-vos-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
