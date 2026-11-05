# Genera scripts/aplicar-permisos-ojo4-app.ps1: las llaves de SOS que "no aplican" (un menor no recibe el SOS de los adultos) se muestran quietas y dicen por que.
import re
R = '/home/user/Murray/scripts/'
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
v2 = open(R + 'app/generar_permisos_ojo2_app.py', encoding='utf-8').read()
i = v2.index('function FilaLlave(')
j = v2.index('function BloquePersona(')
OLD_FILA = v2[i:j]
NEW_FILA = r'''function FilaLlave({ P, tipo, titulo, nombre, llave, bloqueada, guardando, onPress }: { P: Paleta; tipo: "ojo" | "sirena"; titulo: string; nombre: string; llave: Llave; bloqueada: boolean; guardando: boolean; onPress: () => void }) {
  const sp = estilosPermisos(P);
  // "No aplica": un menor no recibe el SOS de los adultos (y un amigo solo el de su titular): la llave se muestra quieta y dice por que.
  const noAplica = llave.elegible === false;
  const encendida = llave.on && !noAplica;
  const tono = noAplica ? P.textoDebil : encendida ? P.exito : (P.peligroFuerte ?? P.peligro);
  const fondo = noAplica ? P.campo : encendida ? P.exitoFondo : P.peligroFondo;
  const borde = noAplica ? P.borde : encendida ? P.exitoBorde : P.peligroBorde;
  const detalle = noAplica
    ? (titulo === "Recibe tu SOS" ? `${nombre} no recibe tu SOS (es menor o amigo).` : `No recibís el SOS de ${nombre}.`)
    : encendida ? null : !llave.mine ? "Lo apagaste vos" : `Lo apagó ${nombre} de su lado`;
  const fija = noAplica || bloqueada || (encendida && llave.ultimo === true);
  return (
    <Pressable accessibilityRole="switch" accessibilityState={{ checked: encendida, disabled: fija }} disabled={fija || guardando} onPress={onPress} style={[sp.fila, fija ? { opacity: noAplica ? 0.75 : 0.6 } : null]}>
      <View style={[sp.icono, { backgroundColor: fondo, borderColor: borde }]}>
        <IconoPermiso tipo={tipo} apagado={!encendida} color={tono} tam={22} />
      </View>
      <View style={{ flex: 1, minWidth: 0 }}>
        <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.titulo}>{titulo}</Text>
        {detalle ? <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.detalle}>{detalle}</Text> : null}
      </View>
      <View style={[sp.pastilla, { backgroundColor: fondo, borderColor: borde, opacity: guardando ? 0.55 : 1 }]}>
        <View style={[sp.punto, { backgroundColor: tono }]} />
        <Text maxFontSizeMultiplier={TOPE_LETRA} style={[sp.pastillaTexto, { color: tono }]}>{noAplica ? "—" : encendida ? "Sí" : "No"}</Text>
      </View>
    </Pressable>
  );
}

'''
A1 = 'type Llave = { on: boolean; mine: boolean; theirs: boolean; ultimo?: boolean };'
B1 = 'type Llave = { on: boolean; mine: boolean; theirs: boolean; ultimo?: boolean; elegible?: boolean };'
A2 = '  const tonoDe = (llave: Llave) => (llave.on ? P.exito : (P.peligroFuerte ?? P.peligro));\n'
B2 = '  const tonoDe = (llave: Llave) => (llave.elegible === false ? P.textoDebil : llave.on ? P.exito : (P.peligroFuerte ?? P.peligro));\n'
filas = [('src\\FamiliaPantalla.tsx', 'permisos4: tipo con elegible', A1, B1),
         ('src\\FamiliaPantalla.tsx', 'permisos4: fila que dice "no aplica"', OLD_FILA, NEW_FILA),
         ('src\\FamiliaPantalla.tsx', 'permisos4: color del resumen', A2, B2)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-permisos-ojo4-app.ps1 - App (PROXIMA build): las llaves de SOS que "no aplican" se muestran quietas.
# Luciano (05/11/2026): "el menor no tiene por que escuchar una alerta y asustarse, el padre si". Un menor nunca recibe el SOS de los adultos; la tarjeta decia "Recibe tu SOS: Si". Ahora dice "No aplica" (raya, gris, sin tocar).
# Requiere aplicar-permisos-ojo3-app.ps1 y el servidor aplicar-permisos-ojo4-panel.ps1 (sin eso se ve como antes). Toca solo src\\FamiliaPantalla.tsx (respaldo .bak-permisos4). Va en la carpeta de la APP.
'''
i0 = base.index('$ErrorActionPreference'); j0 = base.index('Ok "Carpeta correcta"')
guardas = '''Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\FamiliaPantalla.tsx"))) { Mal "No encuentro src\\FamiliaPantalla.tsx en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\FamiliaPantalla.tsx")).texto 'const fija = (clave: ClavePermiso)') -eq 0) { Mal "Falta aplicar primero aplicar-permisos-ojo3-app.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\\FamiliaPantalla.tsx")).texto 'const noAplica') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('.bak-version', '.bak-permisos4')
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "LISTO: la app compila bien. Sale en la PROXIMA build."', cola)
total = cabeza + base[i0:j0] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—']
assert not bad, set(bad)
open(R + 'aplicar-permisos-ojo4-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total), len(OLD_FILA))
