# Genera scripts/aplicar-permisos-ojo2-app.ps1: arregla la tarjeta PERMISOS (build 191): mas compacta, sin avatar repetido, nombre y rol completos,
# texto que no crece con la letra grande del telefono, y el cambio de una llave se ve AL INSTANTE (se guarda en segundo plano).
import re
R = '/home/user/Murray/scripts/'
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
v1 = open(R + 'app/generar_permisos_ojo_app.py', encoding='utf-8').read()
def v1_bloque(nombre, fin):
    i = v1.index(nombre + " = r'''") if (nombre + " = r'''") in v1 else v1.index(nombre + " = '''")
    i = v1.index("'''", i) + 3
    j = v1.index(fin, i)
    return v1[i:j]
OLD_COMP = v1_bloque('B3', "''' + A3")
OLD_ESTADO = "  const [abierta, setAbierta] = useState<string | null>(null);\n  const [avisoPerm, setAvisoPerm] = useState<{ id: string; texto: string } | null>(null);\n"
OLD_CAMBIAR = v1_bloque('B5', "''' + A5")
OLD_RENDER = v1_bloque('B6', "''' + A6")

NEW_COMP = r'''// ---------------------------------------------------------------------------
// Permisos (el ojo). Cada persona de la lista trae `permisos` del servidor: cuatro llaves, dos de cada lado ("Papa -> vos" y "vos -> Papa").
// Una llave vale si los DOS lados estan prendidos: `mine` es el mio y `theirs` el de la otra persona; uno o el otro puede cortarla.
// El servidor no deja apagar al ULTIMO que recibe un SOS (siempre tiene que quedar al menos una persona) y con un menor no se corta nada.
// Al tocar una llave el cambio se ve al instante y se guarda en segundo plano; si el servidor lo rechaza, vuelve atras y dice por que.
// ---------------------------------------------------------------------------
type Llave = { on: boolean; mine: boolean; theirs: boolean; ultimo?: boolean };
type ClavePermiso = "teVe" | "recibeTuSos" | "loVes" | "recibisSuSos";
type Permisos = { locked: boolean; teVe: Llave; recibeTuSos: Llave; loVes: Llave; recibisSuSos: Llave };
type PersonaConPermisos = FamilyPerson & { permisos?: Permisos };

const ROL_CHIP: Record<string, string> = { adulto: "Adulto", menor: "Menor", amigo: "Amigo" };
// El texto de esta tarjeta no crece con la letra grande del telefono: con el tamano de letra de Android al maximo la tarjeta ocupaba media pantalla.
const TOPE_LETRA = 1.1;

/** Texto de cada error del servidor al tocar una llave. */
function textoDeLlave(nombre: string, codigo: string): string | null {
  if (codigo === "last_recipient_other") return `Sos la única persona que recibe el SOS de ${nombre}. Pedile que sume a otra antes de apagarlo.`;
  if (codigo === "last_recipient_me") return `${nombre} es la única persona que recibe tu SOS. Sumá a otra antes de sacarla.`;
  if (codigo === "minor_locked") return "Con un menor no se puede cortar la ubicación ni el SOS.";
  return null;
}

/** La misma persona con UNA llave cambiada (se muestra al instante, antes de que conteste el servidor). */
function conLlave(p: PersonaConPermisos, clave: ClavePermiso, mine: boolean): PersonaConPermisos {
  const permisos = p.permisos;
  if (!permisos) return p;
  const llave = permisos[clave];
  return { ...p, permisos: { ...permisos, [clave]: { ...llave, mine, on: mine && llave.theirs } } };
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
    cabecera: { alignItems: "center", flexDirection: "row", gap: 10, paddingHorizontal: 12, paddingVertical: 10 },
    quien: { flex: 1, minWidth: 0 },
    nombre: { color: P.texto, fontSize: 15.5, fontWeight: "800" },
    rol: { color: P.textoDebil, fontSize: 11.5 },
    resumen: { alignItems: "center", flexDirection: "row", gap: 6 },
    cuerpo: { borderTopColor: P.borde, borderTopWidth: 1, gap: 6, paddingHorizontal: 12, paddingVertical: 10 },
    separador: { color: P.textoDebil, fontSize: 11, fontWeight: "800", letterSpacing: 1, marginTop: 4 },
    fila: { alignItems: "center", flexDirection: "row", gap: 10, minHeight: 40 },
    icono: { alignItems: "center", borderRadius: 10, borderWidth: 1, height: 36, justifyContent: "center", width: 36 },
    titulo: { color: P.texto, fontSize: 14.5, fontWeight: "700" },
    detalle: { color: P.textoDebil, fontSize: 11.5, lineHeight: 15 },
    pastilla: { alignItems: "center", borderRadius: 99, borderWidth: 1, flexDirection: "row", gap: 5, minWidth: 58, justifyContent: "center", paddingHorizontal: 9, paddingVertical: 4 },
    punto: { borderRadius: 5, height: 8, width: 8 },
    pastillaTexto: { fontSize: 12.5, fontWeight: "800" },
    cartel: { backgroundColor: P.peligroFondo, borderColor: P.peligroBorde, borderRadius: 10, borderWidth: 1, padding: 8 },
    cartelTexto: { color: P.peligro, fontSize: 12.5, lineHeight: 17 },
    nota: { color: P.textoDebil, fontSize: 12, lineHeight: 16 },
  });
}

function FilaLlave({ P, tipo, titulo, nombre, llave, bloqueada, guardando, onPress }: { P: Paleta; tipo: "ojo" | "sirena"; titulo: string; nombre: string; llave: Llave; bloqueada: boolean; guardando: boolean; onPress: () => void }) {
  const sp = estilosPermisos(P);
  const encendida = llave.on;
  const tono = encendida ? P.exito : (P.peligroFuerte ?? P.peligro);
  const detalle = encendida ? null : !llave.mine ? "Lo apagaste vos" : `Lo apagó ${nombre} de su lado`;
  const fija = bloqueada || (encendida && llave.ultimo === true);
  return (
    <Pressable accessibilityRole="switch" accessibilityState={{ checked: encendida, disabled: fija }} disabled={fija || guardando} onPress={onPress} style={[sp.fila, fija ? { opacity: 0.6 } : null]}>
      <View style={[sp.icono, { backgroundColor: encendida ? P.exitoFondo : P.peligroFondo, borderColor: encendida ? P.exitoBorde : P.peligroBorde }]}>
        <IconoPermiso tipo={tipo} apagado={!encendida} color={tono} tam={22} />
      </View>
      <View style={{ flex: 1, minWidth: 0 }}>
        <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.titulo}>{titulo}</Text>
        {detalle ? <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.detalle}>{detalle}</Text> : null}
      </View>
      <View style={[sp.pastilla, { backgroundColor: encendida ? P.exitoFondo : P.peligroFondo, borderColor: encendida ? P.exitoBorde : P.peligroBorde, opacity: guardando ? 0.55 : 1 }]}>
        <View style={[sp.punto, { backgroundColor: tono }]} />
        <Text maxFontSizeMultiplier={TOPE_LETRA} style={[sp.pastillaTexto, { color: tono }]}>{encendida ? "Sí" : "No"}</Text>
      </View>
    </Pressable>
  );
}

function BloquePersona({ P, persona, abierta, onAbrir, onCambiar, aviso, guardando }: { P: Paleta; persona: PersonaConPermisos; abierta: boolean; onAbrir: () => void; onCambiar: (clave: ClavePermiso, encender: boolean) => void; aviso: string | null; guardando: string[] }) {
  const sp = estilosPermisos(P);
  const permisos = persona.permisos;
  if (!permisos) return null;
  const bloqueada = permisos.locked;
  const nombre = persona.name;
  const MAYUS = nombre.toUpperCase();
  const rol = persona.owner ? "Titular" : (ROL_CHIP[persona.role] ?? "");
  const tonoDe = (llave: Llave) => (llave.on ? P.exito : (P.peligroFuerte ?? P.peligro));
  const alternar = (clave: ClavePermiso) => () => onCambiar(clave, !permisos[clave].mine);
  const guardandoClave = (clave: ClavePermiso) => guardando.includes(`${persona.id}:${clave}`);
  const ultimoRecibe = permisos.recibisSuSos.on && permisos.recibisSuSos.ultimo === true;
  const ultimoEnvia = permisos.recibeTuSos.on && permisos.recibeTuSos.ultimo === true;
  return (
    <View style={sp.persona}>
      <Pressable accessibilityRole="button" accessibilityState={{ expanded: abierta }} onPress={onAbrir} style={sp.cabecera}>
        <View style={sp.quien}>
          <Text maxFontSizeMultiplier={TOPE_LETRA} numberOfLines={2} style={sp.nombre}>{nombre}</Text>
          {rol ? <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.rol}>{rol}</Text> : null}
        </View>
        <View style={sp.resumen}>
          <IconoPermiso tipo="ojo" apagado={!permisos.teVe.on} color={tonoDe(permisos.teVe)} tam={18} />
          <IconoPermiso tipo="sirena" apagado={!permisos.recibeTuSos.on} color={tonoDe(permisos.recibeTuSos)} tam={18} />
          <IconoPermiso tipo="ojo" apagado={!permisos.loVes.on} color={tonoDe(permisos.loVes)} tam={18} />
          <IconoPermiso tipo="sirena" apagado={!permisos.recibisSuSos.on} color={tonoDe(permisos.recibisSuSos)} tam={18} />
        </View>
      </Pressable>
      {abierta ? (
        <View style={sp.cuerpo}>
          <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.separador}>{`${MAYUS} \u2192 VOS`}</Text>
          <FilaLlave P={P} tipo="ojo" titulo="Te ve" nombre={nombre} llave={permisos.teVe} bloqueada={bloqueada} guardando={guardandoClave("teVe")} onPress={alternar("teVe")} />
          <FilaLlave P={P} tipo="sirena" titulo="Recibe tu SOS" nombre={nombre} llave={permisos.recibeTuSos} bloqueada={bloqueada} guardando={guardandoClave("recibeTuSos")} onPress={alternar("recibeTuSos")} />
          <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.separador}>{`VOS \u2192 ${MAYUS}`}</Text>
          <FilaLlave P={P} tipo="ojo" titulo="Lo ves" nombre={nombre} llave={permisos.loVes} bloqueada={bloqueada} guardando={guardandoClave("loVes")} onPress={alternar("loVes")} />
          <FilaLlave P={P} tipo="sirena" titulo="Recibís su SOS" nombre={nombre} llave={permisos.recibisSuSos} bloqueada={bloqueada} guardando={guardandoClave("recibisSuSos")} onPress={alternar("recibisSuSos")} />
          {bloqueada ? <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.nota}>Con un menor no se puede cortar la ubicación ni el SOS.</Text> : null}
          {ultimoRecibe ? <View style={sp.cartel}><Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.cartelTexto}>{textoDeLlave(nombre, "last_recipient_other")}</Text></View> : null}
          {ultimoEnvia ? <View style={sp.cartel}><Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.cartelTexto}>{textoDeLlave(nombre, "last_recipient_me")}</Text></View> : null}
          {aviso ? <View style={sp.cartel}><Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.cartelTexto}>{aviso}</Text></View> : null}
        </View>
      ) : null}
    </View>
  );
}

'''
NEW_ESTADO = OLD_ESTADO + '  const [guardando, setGuardando] = useState<string[]>([]);\n  const pendientesPerm = useRef(0);\n'
NEW_CAMBIAR = '''  async function cambiarPermiso(p: PersonaConPermisos, clave: ClavePermiso, encender: boolean) {
    if (!enrollment) return;
    const marca = `${p.id}:${clave}`;
    if (guardando.includes(marca)) return;
    setAvisoPerm(null);
    setGuardando((g) => [...g, marca]);
    pendientesPerm.current += 1;
    // El cambio se ve al instante; si el servidor lo rechaza, vuelve atras y dice por que.
    setPeople((lista) => (lista as PersonaConPermisos[]).map((q) => (q.id === p.id ? conLlave(q, clave, encender) : q)));
    try {
      await setFamilyPermission(enrollment, p.id, clave, encender);
    } catch (error) {
      const codigo = error instanceof Error ? error.message : "";
      setAvisoPerm({ id: p.id, texto: textoDeLlave(p.name, codigo) ?? mensajeDeError(error) });
      setPeople((lista) => (lista as PersonaConPermisos[]).map((q) => (q.id === p.id ? conLlave(q, clave, !encender) : q)));
    } finally {
      pendientesPerm.current -= 1;
      setGuardando((g) => g.filter((x) => x !== marca));
      // Con todos los cambios guardados se vuelve a leer del servidor (ahi llega, por ejemplo, quien queda como el ultimo).
      if (pendientesPerm.current === 0) void cargar(enrollment);
    }
  }

'''
NEW_RENDER = OLD_RENDER.replace(
    'Elegí con quién compartís tu ubicación y a quién le suena tu SOS. Si alguno corta, el otro recibe un aviso. Siempre tiene que quedar al menos una persona que reciba tu SOS.',
    'Quién te ve y a quién le suena tu SOS. Si alguno corta, el otro recibe un aviso. Siempre queda al menos una persona que reciba tu SOS.'
).replace('aviso={avisoPerm?.id === p.id ? avisoPerm.texto : null}\n', 'aviso={avisoPerm?.id === p.id ? avisoPerm.texto : null}\n                guardando={guardando}\n')
assert NEW_RENDER != OLD_RENDER and 'guardando={guardando}' in NEW_RENDER

A0 = 'import { useCallback, useEffect, useState, type ComponentType, type ReactNode } from "react";'
B0 = 'import { useCallback, useEffect, useRef, useState, type ComponentType, type ReactNode } from "react";'
filas = [('src\\FamiliaPantalla.tsx', 'permisos2: importar useRef', A0, B0),
         ('src\\FamiliaPantalla.tsx', 'permisos2: tarjeta compacta (componentes)', OLD_COMP, NEW_COMP),
         ('src\\FamiliaPantalla.tsx', 'permisos2: estado de guardado', OLD_ESTADO, NEW_ESTADO),
         ('src\\FamiliaPantalla.tsx', 'permisos2: cambio al instante', OLD_CAMBIAR, NEW_CAMBIAR),
         ('src\\FamiliaPantalla.tsx', 'permisos2: tarjeta en la pantalla', OLD_RENDER, NEW_RENDER)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-permisos-ojo2-app.ps1 - App (PROXIMA build): arregla la tarjeta PERMISOS de la build 191.
# Luciano (05/11/2026): "la tarjeta es muy grande, grotesca; no se entiende una L y despues otra L; y cada vez que apretas una llave demora varios segundos en pasar de Si a No".
#  - Mas compacta: filas de una linea, sin el avatar con la letra repetida, nombre y rol completos (el nombre ya no se corta), y el texto no crece con la letra grande del telefono.
#  - El cambio de una llave se ve al instante (se guarda en segundo plano; mientras guarda se ve un poco apagada y esa llave no se puede tocar de nuevo; si el servidor lo rechaza vuelve atras y dice por que).
# Requiere aplicar-permisos-ojo-app.ps1. Toca solo src\\FamiliaPantalla.tsx (respaldo .bak-permisos2). Va en la carpeta de la APP (la que tiene app.json).
'''
i = base.index('$ErrorActionPreference'); j = base.index('Ok "Carpeta correcta"')
guardas = '''Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\FamiliaPantalla.tsx"))) { Mal "No encuentro src\\FamiliaPantalla.tsx en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\FamiliaPantalla.tsx")).texto 'function BloquePersona') -eq 0) { Mal "Falta aplicar primero aplicar-permisos-ojo-app.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\\FamiliaPantalla.tsx")).texto 'const TOPE_LETRA') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('.bak-version', '.bak-permisos2')
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "LISTO: la app compila bien. Sale en la PROXIMA build."', cola)
total = cabeza + base[i:j] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—']
assert not bad, set(bad)
open(R + 'aplicar-permisos-ojo2-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total), len(OLD_COMP), len(OLD_CAMBIAR), len(OLD_RENDER))
