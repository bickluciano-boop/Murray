# Genera scripts/aplicar-mapa-latido-app.ps1: el mapa de Inicio (WebView) se recarga solo si se cuelga.
import re
R = '/home/user/Murray/scripts/'
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
base = open(R + 'aplicar-version-captura-app.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
a1 = '  const cargadoEn = useRef(0);\n'
b1 = (a1 + '  // Latido del mapa: la pagina avisa cada 5 s que sigue viva. Si deja de avisar (se colgo y no responde al tacto), se vuelve a cargar sola.\n'
      '  const ultimoLatido = useRef(0);\n  const huboLatido = useRef(false);\n  const listoRef = useRef(false);\n')
a2 = '      cargadoEn.current = Date.now();\n'
b2 = a2 + '      ultimoLatido.current = Date.now();\n      huboLatido.current = false;\n'
a3 = '  function alMensaje(evento: WebViewMessageEvent) {\n'
b3 = '''  useEffect(() => {
    listoRef.current = estado === "listo";
  }, [estado]);

  // Si el mapa deja de dar latidos (la pagina se colgo: no responde ni al zoom ni al toque), se vuelve a cargar solo. Como mucho una vez por minuto.
  // Solo vigila si ya llego al menos un latido de esta carga: con un panel sin latido no hace nada.
  useEffect(() => {
    const suscripcion = AppState.addEventListener("change", (estadoApp) => {
      if (estadoApp === "active") ultimoLatido.current = Date.now();
    });
    const intervalo = setInterval(() => {
      if (AppState.currentState !== "active" || !listoRef.current || !huboLatido.current) return;
      if (Date.now() - ultimoLatido.current > 25_000 && Date.now() - cargadoEn.current > 60_000) void cargar();
    }, 5_000);
    return () => {
      suscripcion.remove();
      clearInterval(intervalo);
    };
  }, [cargar]);

''' + a3
a4 = '      if (dato.tipo === "sin_sesion") setEstado("error");\n'
b4 = '      if (dato.tipo === "latido") {\n        ultimoLatido.current = Date.now();\n        huboLatido.current = true;\n        return;\n      }\n' + a4
a5 = '          onMessage={alMensaje}\n'
b5 = a5 + '          // Si el motor del mapa se muere (poca memoria, segundo plano), se vuelve a cargar en vez de quedar en blanco o congelado.\n          onRenderProcessGone={() => void cargar()}\n          onContentProcessDidTerminate={() => void cargar()}\n'
filas = [('src\\MapaEnApp.tsx', 'mapa: contadores del latido', a1, b1),
         ('src\\MapaEnApp.tsx', 'mapa: el latido se reinicia en cada carga', a2, b2),
         ('src\\MapaEnApp.tsx', 'mapa: vigilante que recarga si se cuelga', a3, b3),
         ('src\\MapaEnApp.tsx', 'mapa: recibir el latido', a4, b4),
         ('src\\MapaEnApp.tsx', 'mapa: recargar si el motor del mapa se muere', a5, b5)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-mapa-latido-app.ps1 - App (PROXIMA build): el mapa de Inicio se recarga solo si se cuelga.
# Luciano (11/11/2026): "muchas veces el mapa se tilda, no podes hacer ni zoom ni moverlo, y tengo que tocar otro boton de abajo para que vuelva".
# La pagina del mapa avisa cada 5 s que sigue viva (hay que aplicar antes aplicar-mapa-latido-panel.ps1). Si deja de avisar 25 s con la app abierta, la app lo recarga sola (como mucho una vez por minuto). Tambien se recarga si el motor del mapa se muere.
# Toca SOLO src\\MapaEnApp.tsx (respaldo .bak-mapa-latido). Va en la carpeta de la APP (la que tiene app.json). Si la revision de tipos falla, deja todo como estaba.
'''
i = base.index('$ErrorActionPreference'); j = base.index('Ok "Carpeta correcta"')
motor_ini = base[i:j]
guardas = '''Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\MapaEnApp.tsx"))) { Mal "No encuentro src\\MapaEnApp.tsx en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\MapaEnApp.tsx")).texto 'huboLatido') -ne 0) { Avi "Esto ya estaba aplicado en la app. No toco nada."; return }
'''
cola = base[base.index('$descargas = @()'):].replace('.bak-version', '.bak-mapa-latido')
cola = re.sub(r'Ok "LISTO: la app compila bien\. Sale en la PROXIMA build[^"]*"', 'Ok "LISTO: la app compila bien. Sale en la PROXIMA build."', cola)
assert 'bak-version' not in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—']
assert not bad, set(bad)
open(R + 'aplicar-mapa-latido-app.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
t = open(R + 'familia/MapaEnApp.tsx', encoding='utf-8').read().replace('\r\n', '\n')
for a in (a1, a2, a3, a4, a5):
    assert t.count(a) == 1, (t.count(a), a[:60])
for a, b in ((a1, b1), (a2, b2), (a3, b3), (a4, b4), (a5, b5)):
    t = t.replace(a, b)
open(S + 'MapaEnApp-latido.tsx', 'w', encoding='utf-8').write(t)
print('ok', len(total))
