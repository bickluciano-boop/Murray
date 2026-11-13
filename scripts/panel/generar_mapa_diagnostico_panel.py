# Genera scripts/aplicar-mapa-diagnostico-panel.ps1: DIAGNOSTICO del mapa dentro de la app (solo panel, sin build).
# Luciano (13/11/2026): en su Android el mapa de la app se queda en "Cargando el mapa" y la app lo vuelve a pedir cada ~15 s (visto con wrangler tail: el servidor contesta todo bien).
# Esto hace que la pagina del mapa, SOLO cuando esta dentro de la app, avise al servidor como va (inicio, Google listo, mapa creado, tiles, errores de JS, memoria, si sigue viva); el servidor solo lo escribe en el registro (se ve con wrangler tail). No guarda nada.
import re, sys
sys.path.insert(0, '/home/user/Murray/scripts/neutral')
import reglas_neutro as RN
R = '/home/user/Murray/scripts/'
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
def n(s):  # todo texto nuevo pasa por las reglas del espanol neutro
    return RN.aplicar(s)[0]

# ---------- servidor (src\index.ts) ----------
A1 = '      if (url.pathname === "/api/remote/por-las-dudas") return pldApiDuenio(request, env);\n'
B1 = '      if (request.method === "POST" && url.pathname === "/api/remote/mapa-diag") return mapaDiag(request, env);\n' + A1
A2 = 'async function panelHandoffRedeem(request: Request, env: Env, url: URL) {\n'
B2 = n('''/**
 * POST /api/remote/mapa-diag: diagnostico del mapa dentro de la app. La pagina del mapa (solo dentro de la app) avisa como va la carga y el servidor
 * solo lo escribe en el registro (se ve con `wrangler tail`). Pide sesion, no guarda nada y siempre contesta 204.
 */
async function mapaDiag(request: Request, env: Env) {
  const email = await readSession(request, env.SESSION_SECRET);
  if (email) console.log("mapa-diag", (await request.text().catch(() => "")).slice(0, 600));
  return new Response(null, { status: 204 });
}

''') + A2
# ---------- pagina del mapa (src\panel-mapa.txt) ----------
P1 = 'const EN_APP = document.documentElement.classList.contains("app-mapa");\n'
Q1 = P1 + n('''// Diagnostico (solo dentro de la app): la pagina avisa al servidor como va la carga del mapa; se ve con `wrangler tail`. No guarda nada.
const DIAG_T0 = Date.now();
function diag(evento, dato) {
  if (!EN_APP) return;
  try {
    const memoria = performance.memory ? Math.round(performance.memory.usedJSHeapSize / 1048576) : null;
    navigator.sendBeacon("/api/remote/mapa-diag", new Blob([JSON.stringify({ evento, ms: Date.now() - DIAG_T0, dato: String(dato ?? "").slice(0, 200), memMB: memoria })], { type: "application/json" }));
  } catch { /* sigue */ }
}
if (EN_APP) {
  window.addEventListener("error", (e) => diag("error", `${e.message} ${(e.filename || "").split("/").pop()}:${e.lineno}`));
  window.addEventListener("unhandledrejection", (e) => diag("promesa", e.reason?.message ?? e.reason));
  window.gm_authFailure = () => diag("google_clave_rechazada");
  document.addEventListener("visibilitychange", () => diag("visibilidad", document.visibilityState));
  diag("pagina_inicio", navigator.userAgent.slice(0, 120));
  let vivo = 0;
  const relojDiag = setInterval(() => { vivo += 1; diag("vivo", vivo); if (vivo >= 12) clearInterval(relojDiag); }, 5000);
}
''')
P2 = '      if (Date.now() - inicio > maxMs) return rechazar(new Error("google_maps_no_cargo"));\n'
Q2 = '      if (Date.now() - inicio > maxMs) { diag("google_no_cargo"); return rechazar(new Error("google_maps_no_cargo")); }\n'
P3 = '  const g = await esperarGoogle();\n  class Marcador extends g.OverlayView {\n'
Q3 = '  const g = await esperarGoogle();\n  diag("google_listo");\n  class Marcador extends g.OverlayView {\n'
P4 = '    backgroundColor: temaInicial === "claro" ? "#f2efe9" : "#16181c",\n  });\n  const marcadores = new Map();\n'
Q4 = '    backgroundColor: temaInicial === "claro" ? "#f2efe9" : "#16181c",\n  });\n  diag("mapa_creado");\n  g.event.addListenerOnce(mapa, "tilesloaded", () => diag("tiles_cargados"));\n  const marcadores = new Map();\n'

filas = [('src\\index.ts', 'diagnostico: ruta del mapa en la app', A1, B1), ('src\\index.ts', 'diagnostico: funcion que lo escribe en el registro', A2, B2),
         ('src\\panel-mapa.txt', 'diagnostico: aviso de inicio, errores y memoria', P1, Q1), ('src\\panel-mapa.txt', 'diagnostico: Google no cargo', P2, Q2),
         ('src\\panel-mapa.txt', 'diagnostico: Google listo', P3, Q3), ('src\\panel-mapa.txt', 'diagnostico: mapa creado y tiles', P4, Q4)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-mapa-diagnostico-panel.ps1 - Ojo Guard MS: DIAGNOSTICO del mapa dentro de la app (solo panel, sin build).
# Luciano (13/11/2026): en su Android el mapa de la app queda en "Cargando el mapa" y la app lo pide de nuevo cada 15 segundos; el servidor contesta todo bien.
# Hace que la pagina del mapa, solo cuando esta dentro de la app, avise al servidor como va (inicio, Google listo, mapa creado, errores de JS, memoria, si sigue viva). El servidor solo lo escribe en el registro (se ve con wrangler tail): no guarda nada.
# Cambia src\\index.ts y src\\panel-mapa.txt (respaldo .bak-mapadiag). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
foreach ($f in @("src\\index.ts", "src\\panel-mapa.txt")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\\index.ts")).texto 'async function mapaDiag') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-mapadiag')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: el mapa de la app ya avisa como va la carga (se ve con wrangler tail)."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + tpl[i:j] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›✓']
assert not bad, set(bad)
open(R + 'aplicar-mapa-diagnostico-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
for origen, destino, pares in ((S + 'index-ingreso.ts.neutro', S + 'index-diag.ts', filas[:2]), (S + 'panel-mapa-remedios.txt.neutro', S + 'panel-mapa-diag.txt', filas[2:])):
    t = open(origen, encoding='utf-8').read()
    for _, _, a, b in pares:
        assert t.count(a) == 1, (origen, t.count(a), a[:70])
    for _, _, a, b in pares:
        t = t.replace(a, b)
    open(destino, 'w', encoding='utf-8').write(t)
print('ok', len(total))
