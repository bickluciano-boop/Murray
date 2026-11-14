# Genera scripts/aplicar-horas4-app.ps1 (app, PROXIMA build). Luciano (14/11/2026): "no esta tipo scroll que van mirando las horas; esta abajo en la linea y vas corriendo con el dedo de derecha a izquierda".
# Pedia una RUEDA de horas como la del reloj del iPhone: se desliza hacia arriba y abajo y la hora del medio es la elegida. Se hace una rueda propia (sin modulos nativos nuevos): una columna de horas (00-23) y una de minutos (00, 15, 30, 45) con "snap".
# Reemplaza a la tira horizontal y a los botones - / + en los medicamentos, y a la fila de horas del Buen dia.
import re
R = '/home/user/Murray/scripts/'
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
F = 'src\\FamiliaPantalla.tsx'
RUEDA = '''// ---------------------------------------------------------------------------
// Rueda de horas (como la del reloj del iPhone): se desliza hacia arriba y abajo y la hora del medio, entre las dos lineas, es la elegida.
// Dos columnas: horas (00 a 23) y minutos (00, 15, 30, 45). Sin modulos nativos: es un ScrollView con "snap". Tocar un numero tambien lo elige.
// ---------------------------------------------------------------------------
const ALTO_FILA_RUEDA = 40;
const HORAS_RUEDA = Array.from({ length: 24 }, (_, i) => String(i).padStart(2, "0"));
const MINUTOS_RUEDA = ["00", "15", "30", "45"];

function ColumnaRueda({ P, etiqueta, items, valor, onElegir }: { P: Paleta; etiqueta: string; items: string[]; valor: string; onElegir: (v: string) => void }) {
  const ref = useRef<ScrollRueda>(null);
  const espera = useRef<ReturnType<typeof setTimeout> | null>(null);
  const indice = Math.max(0, items.indexOf(valor));
  // Al abrir (y cuando la hora cambia desde afuera, por ejemplo al tocar otra hora de la lista) la rueda se pone en esa hora.
  useEffect(() => {
    ref.current?.scrollTo({ y: indice * ALTO_FILA_RUEDA, animated: false });
  }, [indice]);
  useEffect(
    () => () => {
      if (espera.current) clearTimeout(espera.current);
    },
    [],
  );
  const confirmar = (y: number) => {
    const i = Math.min(items.length - 1, Math.max(0, Math.round(y / ALTO_FILA_RUEDA)));
    const v = items[i];
    if (v !== undefined && v !== valor) onElegir(v);
  };
  return (
    <View style={{ height: ALTO_FILA_RUEDA * 3, width: 72 }}>
      <ScrollRueda
        ref={ref}
        accessibilityLabel={etiqueta}
        nestedScrollEnabled
        showsVerticalScrollIndicator={false}
        snapToInterval={ALTO_FILA_RUEDA}
        decelerationRate="fast"
        scrollEventThrottle={32}
        contentContainerStyle={{ paddingVertical: ALTO_FILA_RUEDA }}
        onScroll={(e) => {
          const y = e.nativeEvent.contentOffset.y;
          if (espera.current) clearTimeout(espera.current);
          espera.current = setTimeout(() => confirmar(y), 160);
        }}
        onMomentumScrollEnd={(e) => {
          if (espera.current) clearTimeout(espera.current);
          confirmar(e.nativeEvent.contentOffset.y);
        }}
      >
        {items.map((it, i) => (
          <Pressable
            key={it}
            accessibilityRole="button"
            accessibilityLabel={`${etiqueta}: ${it}`}
            onPress={() => {
              ref.current?.scrollTo({ y: i * ALTO_FILA_RUEDA, animated: true });
              onElegir(it);
            }}
            style={{ alignItems: "center", height: ALTO_FILA_RUEDA, justifyContent: "center" }}
          >
            <Text maxFontSizeMultiplier={TOPE_LETRA} style={{ color: it === valor ? P.texto : P.textoDebil, fontSize: it === valor ? 24 : 18, fontWeight: it === valor ? "800" : "500" }}>
              {it}
            </Text>
          </Pressable>
        ))}
      </ScrollRueda>
      <View pointerEvents="none" style={{ borderBottomWidth: 1, borderColor: P.doradoBorde, borderTopWidth: 1, height: ALTO_FILA_RUEDA, left: 0, position: "absolute", right: 0, top: ALTO_FILA_RUEDA }} />
    </View>
  );
}

function RuedaHora({ P, valor, onCambio }: { P: Paleta; valor: string; onCambio: (hhmm: string) => void }) {
  const hh = valor.slice(0, 2);
  const minutosReales = Number(valor.slice(3, 5));
  // Si la hora guardada trae otros minutos (por ejemplo 09:20), la rueda muestra los mas cercanos de la lista hasta que se la mueva.
  const mm = MINUTOS_RUEDA.reduce((mejor, m) => (Math.abs(Number(m) - minutosReales) < Math.abs(Number(mejor) - minutosReales) ? m : mejor), "00");
  return (
    <View style={{ alignItems: "center", flexDirection: "row", gap: 6, justifyContent: "center" }}>
      <ColumnaRueda P={P} etiqueta="Hora" items={HORAS_RUEDA} valor={hh} onElegir={(h) => onCambio(`${h}:${mm}`)} />
      <Text style={{ color: P.texto, fontSize: 24, fontWeight: "800" }}>:</Text>
      <ColumnaRueda P={P} etiqueta="Minutos" items={MINUTOS_RUEDA} valor={mm} onElegir={(m) => onCambio(`${hh}:${m}`)} />
    </View>
  );
}

/** La rueda de la hora del saludo del Buen dia: se guarda UNA vez, cuando se deja de girar (si no, girar horas y despues minutos mandaba dos pedidos seguidos y el segundo se perdia). */
function RuedaSaludo({ P, valor, onGuardar }: { P: Paleta; valor: string; onGuardar: (hhmm: string) => void }) {
  const [local, setLocal] = useState(valor);
  const temporizador = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    setLocal(valor);
  }, [valor]);
  useEffect(
    () => () => {
      if (temporizador.current) clearTimeout(temporizador.current);
    },
    [],
  );
  return (
    <RuedaHora
      P={P}
      valor={local}
      onCambio={(h) => {
        setLocal(h);
        if (temporizador.current) clearTimeout(temporizador.current);
        temporizador.current = setTimeout(() => onGuardar(h), 700);
      }}
    />
  );
}

'''
filas = [
 (F, 'rueda: importar el ScrollView para la rueda', 'import { ScrollView as ScrollHorizontal } from "react-native";\n',
  'import { ScrollView as ScrollHorizontal, ScrollView as ScrollRueda } from "react-native";\n'),
 (F, 'rueda: se saca la fila de horas del Buen dia (ahora es una rueda)',
  '// De 05:00 a 13:00 cada media hora (17 opciones): la fila se desliza hacia los costados.\nconst HORAS_BUEN_DIA = Array.from({ length: 17 }, (_, i) => {\n  const minutos = 5 * 60 + i * 30;\n  return `${String(Math.floor(minutos / 60)).padStart(2, "0")}:${minutos % 60 === 0 ? "00" : "30"}`;\n});\n', ''),
 (F, 'rueda: componentes de la rueda (en lugar de la tira de horas)',
  '// Todas las medias horas del dia (00:00 a 23:30) para la tira de horas que se desliza.\nconst HORAS_DEL_DIA = Array.from({ length: 48 }, (_, i) => `${String(Math.floor(i / 2)).padStart(2, "0")}:${i % 2 === 0 ? "00" : "30"}`);\nfunction moverHoraRemedio(hhmm: string, pasos: number): string {\n',
  RUEDA + 'function moverHoraRemedio(hhmm: string, pasos: number): string {\n'),
 (F, 'rueda: ya no hacen falta los botones - / +', '  const moverHora = (pasos: number) => {\n    if (borrador) elegirHora(moverHoraRemedio(borrador.hora, pasos));\n  };\n', ''),
 (F, 'rueda: la rueda y el boton Agregar en el editor de medicamentos (en lugar de - / + y la tira)',
  '            <View style={{ alignItems: "center", flexDirection: "row", flexWrap: "wrap", gap: 10 }}>\n              <Pressable accessibilityRole="button" accessibilityLabel="Hora anterior" onPress={() => moverHora(-1)} style={chip(false)}>\n                <Text maxFontSizeMultiplier={TOPE_LETRA} style={chipTexto(false)}>−</Text>\n              </Pressable>\n              <Text maxFontSizeMultiplier={TOPE_LETRA} style={{ color: P.texto, fontSize: 20, fontWeight: "800", minWidth: 64, textAlign: "center" }}>{borrador.hora}</Text>\n              <Pressable accessibilityRole="button" accessibilityLabel="Hora siguiente" onPress={() => moverHora(1)} style={chip(false)}>\n                <Text maxFontSizeMultiplier={TOPE_LETRA} style={chipTexto(false)}>+</Text>\n              </Pressable>\n              <Pressable accessibilityRole="button" onPress={agregarHora} style={chip(true)}>\n                <Text maxFontSizeMultiplier={TOPE_LETRA} style={chipTexto(true)}>{borrador.horas.length ? "Agregar otra hora" : "Agregar esta hora"}</Text>\n              </Pressable>\n            </View>\n            <Deslizable activo desde={Math.max(0, HORAS_DEL_DIA.indexOf(borrador.hora) - 1) * 78}>\n              <View style={{ flexDirection: "row", gap: 6 }}>\n                {HORAS_DEL_DIA.map((h) => (\n                  <Pressable key={h} accessibilityRole="button" accessibilityLabel={`Hora ${h}`} accessibilityState={{ selected: h === borrador.hora }} onPress={() => elegirHora(h)} style={[chip(h === borrador.hora), { alignItems: "center", width: 72 }]}>\n                    <Text maxFontSizeMultiplier={TOPE_LETRA} style={chipTexto(h === borrador.hora)}>{h}</Text>\n                  </Pressable>\n                ))}\n              </View>\n            </Deslizable>\n            <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.nota}>Desliza para ver más horas.</Text>\n',
  '            <RuedaHora P={P} valor={borrador.hora} onCambio={elegirHora} />\n            <Pressable accessibilityRole="button" onPress={agregarHora} style={[chip(true), { alignSelf: "flex-start" }]}>\n              <Text maxFontSizeMultiplier={TOPE_LETRA} style={chipTexto(true)}>{borrador.horas.length ? "Agregar otra hora" : "Agregar esta hora"}</Text>\n            </Pressable>\n'),
 (F, 'rueda: texto de ayuda de la lista de horas', 'Toca una hora para cambiarla con − y +. La ✕ la quita.', 'Toca una hora de la lista y gira la rueda para cambiarla. La ✕ la quita.'),
 (F, 'rueda: la hora del Buen dia es una rueda',
  '<OpcionesCuidado P={P} titulo="HORA DEL SALUDO" opciones={HORAS_BUEN_DIA.map((h) => ({ valor: h, texto: h }))} elegida={prefs.hora} onElegir={(h) => void cambiar("hora", { hora: h }, (c) => ({ ...c, prefs: { ...c.prefs, hora: h } }))} />\n',
  '<View style={{ gap: 6 }}>\n              <Text maxFontSizeMultiplier={TOPE_LETRA} style={sp.separador}>HORA DEL SALUDO</Text>\n              <RuedaSaludo P={P} valor={prefs.hora} onGuardar={(h) => void cambiar("hora", { hora: h }, (c) => ({ ...c, prefs: { ...c.prefs, hora: h } }))} />\n            </View>\n'),
]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-horas4-app.ps1 - App (PROXIMA build). Luciano (14/11/2026): "no esta tipo scroll que van mirando las horas; esta abajo en la linea y vas corriendo con el dedo de derecha a izquierda".
# Pedia una RUEDA de horas como la del reloj del iPhone (se desliza hacia arriba y abajo; la del medio es la elegida). Se arma una rueda propia, sin modulos nativos nuevos: columna de horas (00-23) y de minutos (00, 15, 30, 45), con snap.
# Reemplaza la tira horizontal y los botones - / + en los medicamentos, y la fila de horas del Buen dia. Requiere aplicar-horas3-app.ps1. Toca src\\FamiliaPantalla.tsx (respaldo .bak-horas4). Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba.
'''
i0 = base.index('$ErrorActionPreference'); j0 = base.index('Ok "Carpeta correcta"')
guardas = '''Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\FamiliaPantalla.tsx"))) { Mal "No encuentro src\\FamiliaPantalla.tsx en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\FamiliaPantalla.tsx")).texto 'function RuedaHora') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\FamiliaPantalla.tsx")).texto 'Desliza para ver más horas') -eq 0) { Mal "Falta aplicar primero aplicar-horas3-app.ps1."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('.bak-version', '.bak-horas4')
_v = 'Chk ($c[0] + ": " + $c[1] + " aplicado") ((Contar $v.texto (Ajustar $c[3] $v.crlf)) -eq 1)'
assert cola.count(_v) == 1
cola = cola.replace(_v, 'if ($c[3].Length -gt 0) { ' + _v + ' }')
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "LISTO: la app compila bien. Las horas se eligen con una rueda (sale en la PROXIMA build, Android e iPhone)."', cola)
assert 'bak-version' not in cola
total = cabeza + base[i0:j0] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕']
assert not bad, set(bad)
open(R + 'aplicar-horas4-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
t = open(S + 'FamiliaPantalla-horas3.tsx', encoding='utf-8').read().replace('\r\n', '\n')
for a, n, v, nv in filas:
    assert t.count(v) == 1, (n, t.count(v))
for a, n, v, nv in filas:
    t = t.replace(v, nv)
open(S + 'FamiliaPantalla-horas4.tsx', 'w', encoding='utf-8').write(t)
print('ok', len(total))
