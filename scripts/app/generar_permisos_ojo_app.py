# Genera scripts/aplicar-permisos-ojo-app.ps1: tarjeta PERMISOS (el ojo) dentro de Familia y amigos.
import re
R = '/home/user/Murray/scripts/'
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"

# ---- remoteApi.ts: la llamada nueva ----
A1 = '/** Salir de la familia de un titular (personId "titular:correo", como viene en fetchFamily). */\n'
B1 = '''/** Prende o apaga UNA llave de los permisos con otra persona. El servidor le avisa a ella y no deja apagar al ultimo que recibe un SOS. */
export async function setFamilyPermission(
  enrollment: NativeEnrollment,
  personId: string,
  key: "teVe" | "recibeTuSos" | "loVes" | "recibisSuSos",
  on: boolean,
) {
  await nativeRequest(enrollment, "/api/native/family/perm", {
    method: "POST",
    body: JSON.stringify({ deviceId: enrollment.deviceId, personId, key, on }),
  });
}

''' + A1

# ---- FamiliaPantalla.tsx ----
A2 = 'import { fetchFamily, joinFamily, leaveFamily, pauseFamilyLocation, type FamilyPerson } from "./remoteApi";'
B2 = 'import { fetchFamily, joinFamily, leaveFamily, pauseFamilyLocation, setFamilyPermission, type FamilyPerson } from "./remoteApi";'

A3 = '/** A quien le suena el SOS de esta persona'
B3 = r'''// ---------------------------------------------------------------------------
// Permisos (el ojo). Cada persona de la lista trae `permisos` del servidor: cuatro llaves, dos de cada lado ("Papa -> vos" y "vos -> Papa").
// Una llave vale si los DOS lados estan prendidos: `mine` es el mio y `theirs` el de la otra persona; uno o el otro puede cortarla.
// El servidor no deja apagar al ULTIMO que recibe un SOS (siempre tiene que quedar al menos una persona) y con un menor no se corta nada.
// ---------------------------------------------------------------------------
type Llave = { on: boolean; mine: boolean; theirs: boolean; ultimo?: boolean };
type ClavePermiso = "teVe" | "recibeTuSos" | "loVes" | "recibisSuSos";
type Permisos = { locked: boolean; teVe: Llave; recibeTuSos: Llave; loVes: Llave; recibisSuSos: Llave };
type PersonaConPermisos = FamilyPerson & { permisos?: Permisos };

const ROL_CHIP: Record<string, string> = { adulto: "Adulto", menor: "Menor", amigo: "Amigo" };

/** Texto de cada error del servidor al tocar una llave. */
function textoDeLlave(nombre: string, codigo: string): string | null {
  if (codigo === "last_recipient_other") return `Sos la única persona que recibe el SOS de ${nombre}. Pedile que sume a otra antes de apagarlo.`;
  if (codigo === "last_recipient_me") return `${nombre} es la única persona que recibe tu SOS. Sumá a otra antes de sacarla.`;
  if (codigo === "minor_locked") return "Con un menor no se puede cortar la ubicación ni el SOS.";
  return null;
}

/** El ojo (abierto / cerrado) y la sirena (con sonido / tachada), dibujados con vistas: sin librerias nuevas. */
function IconoPermiso({ tipo, apagado, color, tam = 24 }: { tipo: "ojo" | "sirena"; apagado: boolean; color: string | undefined; tam?: number }) {
  const g = Math.max(2, Math.round(tam / 12));
  const caja = { width: tam, height: tam, alignItems: "center", justifyContent: "center" } as const;
  if (tipo === "ojo") {
    if (apagado) {
      return (
        <View style={caja}>
          <View style={{ width: tam * 0.94, height: tam * 0.42, borderBottomLeftRadius: tam, borderBottomRightRadius: tam, borderBottomWidth: g, borderColor: color }} />
          <View style={{ position: "absolute", top: tam * 0.6, width: tam * 0.7, flexDirection: "row", justifyContent: "space-between" }}>
            <View style={{ width: g, height: tam * 0.16, borderRadius: g, backgroundColor: color, transform: [{ rotate: "28deg" }] }} />
            <View style={{ width: g, height: tam * 0.18, borderRadius: g, backgroundColor: color }} />
            <View style={{ width: g, height: tam * 0.16, borderRadius: g, backgroundColor: color, transform: [{ rotate: "-28deg" }] }} />
          </View>
        </View>
      );
    }
    return (
      <View style={caja}>
        <View style={{ width: tam, height: tam * 0.62, borderRadius: tam * 0.4, borderWidth: g, borderColor: color, alignItems: "center", justifyContent: "center" }}>
          <View style={{ width: tam * 0.3, height: tam * 0.3, borderRadius: tam, backgroundColor: color }} />
        </View>
      </View>
    );
  }
  return (
    <View style={caja}>
      <View style={{ width: tam * 0.1, height: tam * 0.14, borderRadius: g, backgroundColor: color, marginBottom: tam * 0.04 }} />
      <View style={{ width: tam * 0.64, height: tam * 0.5, borderTopLeftRadius: tam * 0.32, borderTopRightRadius: tam * 0.32, borderWidth: g, borderBottomWidth: 0, borderColor: color }} />
      <View style={{ width: tam * 0.92, height: g * 1.3, borderRadius: g, backgroundColor: color }} />
      {apagado ? <View style={{ position: "absolute", width: tam * 1.18, height: g * 1.3, borderRadius: g, backgroundColor: color, transform: [{ rotate: "-45deg" }] }} /> : null}
    </View>
  );
}

function estilosPermisos(P: Paleta) {
  return StyleSheet.create({
    persona: { borderColor: P.borde, borderRadius: 14, borderWidth: 1, overflow: "hidden" },
    cabecera: { alignItems: "center", flexDirection: "row", gap: 10, padding: 12 },
    avatar: { alignItems: "center", backgroundColor: P.campo, borderColor: P.borde, borderRadius: 18, borderWidth: 1, height: 36, justifyContent: "center", width: 36 },
    avatarLetra: { color: P.doradoTexto, fontSize: 16, fontWeight: "800" },
    nombre: { color: P.texto, flexShrink: 1, fontSize: 16, fontWeight: "800" },
    rol: { color: P.textoClaro, fontSize: 11.5, marginLeft: 2 },
    resumen: { flexDirection: "row", gap: 6, marginLeft: "auto" },
    cuerpo: { borderTopColor: P.borde, borderTopWidth: 1, gap: 10, padding: 12 },
    separador: { color: P.textoDebil, fontSize: 11.5, fontWeight: "800", letterSpacing: 1 },
    fila: { alignItems: "center", flexDirection: "row", gap: 12 },
    icono: { alignItems: "center", borderRadius: 14, borderWidth: 1, height: 44, justifyContent: "center", width: 44 },
    titulo: { color: P.texto, fontSize: 15, fontWeight: "700" },
    detalle: { color: P.textoDebil, fontSize: 12.5, lineHeight: 17 },
    pastilla: { alignItems: "center", borderRadius: 99, borderWidth: 1, flexDirection: "row", gap: 6, paddingHorizontal: 10, paddingVertical: 5 },
    punto: { borderRadius: 5, height: 9, width: 9 },
    pastillaTexto: { fontSize: 12.5, fontWeight: "800" },
    cartel: { backgroundColor: P.peligroFondo, borderColor: P.peligroBorde, borderRadius: 12, borderWidth: 1, padding: 10 },
    cartelTexto: { color: P.peligro, fontSize: 13, lineHeight: 18 },
    nota: { color: P.textoDebil, fontSize: 12.5, lineHeight: 17 },
  });
}

function FilaLlave({ P, tipo, titulo, base, nombre, llave, bloqueada, onPress }: { P: Paleta; tipo: "ojo" | "sirena"; titulo: string; base: string; nombre: string; llave: Llave; bloqueada: boolean; onPress: () => void }) {
  const sp = estilosPermisos(P);
  const encendida = llave.on;
  const tono = encendida ? P.exito : (P.peligroFuerte ?? P.peligro);
  const detalle = encendida ? base : !llave.mine ? "Lo apagaste vos." : `Lo apagó ${nombre} de su lado.`;
  const fija = bloqueada || (encendida && llave.ultimo === true);
  return (
    <Pressable accessibilityRole="switch" accessibilityState={{ checked: encendida, disabled: fija }} disabled={fija} onPress={onPress} style={[sp.fila, fija ? { opacity: 0.6 } : null]}>
      <View style={[sp.icono, { backgroundColor: encendida ? P.exitoFondo : P.peligroFondo, borderColor: encendida ? P.exitoBorde : P.peligroBorde }]}>
        <IconoPermiso tipo={tipo} apagado={!encendida} color={tono} tam={26} />
      </View>
      <View style={{ flex: 1, minWidth: 0 }}>
        <Text style={sp.titulo}>{titulo}</Text>
        <Text style={sp.detalle}>{detalle}</Text>
      </View>
      <View style={[sp.pastilla, { backgroundColor: encendida ? P.exitoFondo : P.peligroFondo, borderColor: encendida ? P.exitoBorde : P.peligroBorde }]}>
        <View style={[sp.punto, { backgroundColor: tono }]} />
        <Text style={[sp.pastillaTexto, { color: tono }]}>{encendida ? "Sí" : "No"}</Text>
      </View>
    </Pressable>
  );
}

function BloquePersona({ P, persona, abierta, onAbrir, onCambiar, aviso }: { P: Paleta; persona: PersonaConPermisos; abierta: boolean; onAbrir: () => void; onCambiar: (clave: ClavePermiso, encender: boolean) => void; aviso: string | null }) {
  const sp = estilosPermisos(P);
  const permisos = persona.permisos;
  if (!permisos) return null;
  const bloqueada = permisos.locked;
  const nombre = persona.name;
  const MAYUS = nombre.toUpperCase();
  const mini = (tipo: "ojo" | "sirena", llave: Llave) => <IconoPermiso key={`${tipo}-${llave === permisos.teVe ? "a" : llave === permisos.loVes ? "b" : llave === permisos.recibeTuSos ? "c" : "d"}`} tipo={tipo} apagado={!llave.on} color={llave.on ? P.exito : (P.peligroFuerte ?? P.peligro)} tam={18} />;
  const alternar = (clave: ClavePermiso) => () => onCambiar(clave, !permisos[clave].mine);
  const ultimoRecibe = permisos.recibisSuSos.on && permisos.recibisSuSos.ultimo === true;
  const ultimoEnvia = permisos.recibeTuSos.on && permisos.recibeTuSos.ultimo === true;
  return (
    <View style={sp.persona}>
      <Pressable accessibilityRole="button" accessibilityState={{ expanded: abierta }} onPress={onAbrir} style={sp.cabecera}>
        <View style={sp.avatar}><Text style={sp.avatarLetra}>{nombre.trim().slice(0, 1).toUpperCase()}</Text></View>
        <Text numberOfLines={1} style={sp.nombre}>{nombre}</Text>
        <Text style={sp.rol}>{persona.owner ? "Titular" : (ROL_CHIP[persona.role] ?? "")}</Text>
        <View style={sp.resumen}>
          {mini("ojo", permisos.teVe)}
          {mini("sirena", permisos.recibeTuSos)}
          {mini("ojo", permisos.loVes)}
          {mini("sirena", permisos.recibisSuSos)}
        </View>
      </Pressable>
      {abierta ? (
        <View style={sp.cuerpo}>
          <Text style={sp.separador}>{`${MAYUS} \u2192 VOS`}</Text>
          <FilaLlave P={P} tipo="ojo" titulo="Te ve" base="Mira tu ubicación" nombre={nombre} llave={permisos.teVe} bloqueada={bloqueada} onPress={alternar("teVe")} />
          <FilaLlave P={P} tipo="sirena" titulo="Recibe tu SOS" base="Le suena la sirena" nombre={nombre} llave={permisos.recibeTuSos} bloqueada={bloqueada} onPress={alternar("recibeTuSos")} />
          <Text style={sp.separador}>{`VOS \u2192 ${MAYUS}`}</Text>
          <FilaLlave P={P} tipo="ojo" titulo="Lo ves" base="Aparece en tu mapa" nombre={nombre} llave={permisos.loVes} bloqueada={bloqueada} onPress={alternar("loVes")} />
          <FilaLlave P={P} tipo="sirena" titulo="Recibís su SOS" base="Apagalo si estás en el cine o de viaje" nombre={nombre} llave={permisos.recibisSuSos} bloqueada={bloqueada} onPress={alternar("recibisSuSos")} />
          {bloqueada ? <Text style={sp.nota}>Con un menor no se puede cortar la ubicación ni el SOS.</Text> : null}
          {ultimoRecibe ? <View style={sp.cartel}><Text style={sp.cartelTexto}>{textoDeLlave(nombre, "last_recipient_other")}</Text></View> : null}
          {ultimoEnvia ? <View style={sp.cartel}><Text style={sp.cartelTexto}>{textoDeLlave(nombre, "last_recipient_me")}</Text></View> : null}
          {aviso ? <View style={sp.cartel}><Text style={sp.cartelTexto}>{aviso}</Text></View> : null}
        </View>
      ) : null}
    </View>
  );
}

''' + A3

A4 = '  const [siempre, setSiempre] = useState(true);\n'
B4 = A4 + '  const [abierta, setAbierta] = useState<string | null>(null);\n  const [avisoPerm, setAvisoPerm] = useState<{ id: string; texto: string } | null>(null);\n'

A5 = '  // Cualquiera puede salir de una familia, tambien un menor (al titular le llega un correo).\n'
B5 = '''  async function cambiarPermiso(p: PersonaConPermisos, clave: ClavePermiso, encender: boolean) {
    if (!enrollment) return;
    setOcupado(true);
    setAvisoPerm(null);
    try {
      await setFamilyPermission(enrollment, p.id, clave, encender);
      await cargar(enrollment);
    } catch (error) {
      const codigo = error instanceof Error ? error.message : "";
      setAvisoPerm({ id: p.id, texto: textoDeLlave(p.name, codigo) ?? mensajeDeError(error) });
    } finally {
      setOcupado(false);
    }
  }

''' + A5

A6 = '      {hayFamilia ? (\n        <>\n          <Text style={s.etiqueta}>SOS Y AYUDA</Text>\n'
B6 = '''      {(people as PersonaConPermisos[]).some((p) => p.permisos) ? (
        <>
          <Text style={s.etiqueta}>PERMISOS</Text>
          <View style={s.tarjeta}>
            <Text style={botones.ayuda}>
              Elegí con quién compartís tu ubicación y a quién le suena tu SOS. Si alguno corta, el otro recibe un aviso. Siempre tiene que quedar al menos una persona que reciba tu SOS.
            </Text>
            {(people as PersonaConPermisos[]).filter((p) => p.permisos).map((p) => (
              <BloquePersona
                key={`perm-${p.id}`}
                P={P}
                persona={p}
                abierta={abierta === p.id}
                onAbrir={() => { setAvisoPerm(null); setAbierta(abierta === p.id ? null : p.id); }}
                onCambiar={(clave, encender) => void cambiarPermiso(p, clave, encender)}
                aviso={avisoPerm?.id === p.id ? avisoPerm.texto : null}
              />
            ))}
          </View>
        </>
      ) : null}

''' + A6

filas = [('src\\remoteApi.ts', 'permisos: llamada al servidor', A1, B1),
         ('src\\FamiliaPantalla.tsx', 'permisos: importar la llamada', A2, B2),
         ('src\\FamiliaPantalla.tsx', 'permisos: ojo, filas y bloque por persona', A3, B3),
         ('src\\FamiliaPantalla.tsx', 'permisos: estado de la pantalla', A4, B4),
         ('src\\FamiliaPantalla.tsx', 'permisos: cambiar una llave', A5, B5),
         ('src\\FamiliaPantalla.tsx', 'permisos: tarjeta PERMISOS', A6, B6)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-permisos-ojo-app.ps1 - App (PROXIMA build): tarjeta PERMISOS ("el ojo") dentro de Familia y amigos.
# Luciano (04/11/2026): una tarjeta adentro de Familia y amigos, con la estructura "PAPA -> VOS" / "VOS -> PAPA": te ve (ojo), recibe tu SOS (sirena), lo ves, recibis su SOS. Uno o el otro puede cortar; el otro recibe un aviso; siempre queda al menos una persona que reciba el SOS.
# Requiere aplicar antes aplicar-familia-sos-nombres-app.ps1 y el instalador del servidor aplicar-permisos-ojo-panel.ps1 (sin el servidor la tarjeta no se muestra). Toca src\\FamiliaPantalla.tsx y src\\remoteApi.ts (respaldo .bak-permisos).
# Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba.
'''
i = base.index('$ErrorActionPreference'); j = base.index('Ok "Carpeta correcta"')
guardas = '''Ok "Carpeta correcta"
foreach ($f in @("src\\FamiliaPantalla.tsx", "src\\remoteApi.ts")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\\FamiliaPantalla.tsx")).texto 'function listaDeNombres') -eq 0) { Mal "Falta aplicar primero aplicar-familia-sos-nombres-app.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\\FamiliaPantalla.tsx")).texto 'function BloquePersona') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('.bak-version', '.bak-permisos')
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "LISTO: la app compila bien. Sale en la PROXIMA build."', cola)
total = cabeza + base[i:j] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—']
assert not bad, set(bad)
open(R + 'aplicar-permisos-ojo-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
