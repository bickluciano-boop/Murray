# Genera scripts/aplicar-mapa-carga-paralela-panel.ps1: el mapa arranca mas rapido porque sus pasos dejan de ir en fila.
#  Antes: Google Maps -> (recien ahi) /session -> /family -> /recorrido -> dibujar. Ahora: Google Maps, /session y /family arrancan juntos; se dibuja apenas hay personas y el recorrido llega despues.
import re
R = '/home/user/Murray/scripts/'
S = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
# 1) /session y /family a la vez
A1 = '  const cuenta = await pedir("/api/remote/session");\n  if (!cuenta.authenticated) throw Object.assign(new Error("sin_sesion"), { status: 401 });\n'
B1 = ('  // /family no depende de /session: se piden juntos (antes uno detras del otro).\n'
      '  const familiaP = pedir("/api/remote/family");\n  familiaP.catch(() => undefined);\n') + A1
A2 = '    const familia = await pedir("/api/remote/family");\n    estado.invitaciones = familia.invites || [];\n'
B2 = '    const familia = await familiaP;\n    estado.invitaciones = familia.invites || [];\n'
# 2) los datos se piden mientras carga Google Maps
A3 = '  if (!estado.proveedor) {\n    try {\n      estado.proveedor = await proveedorGoogle('
B3 = ('  // Los datos (personas, equipos) se piden YA, mientras carga Google Maps (antes se esperaba a Google y recien despues se pedian).\n'
      '  if (!estado.proveedor && !DEMO) { estado.precarga = cargarEquipos(); estado.precarga.catch(() => undefined); }\n') + A3
A4 = '    estado.equipos = await cargarEquipos();\n    completarDirecciones(estado.equipos);\n'
B4 = ('    const adelantado = estado.precarga;\n    estado.precarga = null;\n'
      '    estado.equipos = adelantado ? await adelantado : await cargarEquipos();\n    completarDirecciones(estado.equipos);\n')
# 3) dibujar apenas hay personas; el recorrido llega despues
A5 = '  const equipo = equipoElegido();\n  if (equipo && (forzarRecorrido || Date.now() - estado.ultimoRecorrido > (estado.vivo ? 10_000 : 30_000))) {\n    try { estado.recorrido = await cargarRecorrido(equipo); }'
B5 = ('  // La primera vez se dibujan ya las personas y los equipos; el recorrido (otro pedido) llega despues y se redibuja.\n'
      '  if (!estado.primerDibujo) { estado.primerDibujo = true; try { dibujar(); document.documentElement.classList.remove("abriendo"); } catch (error) { console.error("dibujar", error); } }\n') + A5
pares = [(A1, B1), (A2, B2), (A3, B3), (A4, B4), (A5, B5)]
nombres = ['mapa: /family junto con /session', 'mapa: usar /family ya pedido', 'mapa: pedir los datos mientras carga Google Maps', 'mapa: usar los datos ya pedidos', 'mapa: dibujar apenas hay personas']
filas = [('src\\panel-mapa.txt', n, a, b) for n, (a, b) in zip(nombres, pares)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-mapa-carga-paralela-panel.ps1 - Ojo Guard MS: el mapa abre mas rapido porque sus pasos dejan de ir en fila.
# Luciano (12/11/2026): el mapa tarda 9 s en abrir en el Android. Antes: Google Maps -> /session -> /family -> recorrido -> dibujar, uno detras del otro. Ahora Google Maps, /session y /family arrancan juntos y se dibuja apenas hay personas; el recorrido llega despues.
# Cambia SOLO src\\panel-mapa.txt (respaldo .bak-carga-paralela). Va en la carpeta del PANEL (la que tiene wrangler.toml). No necesita build. Al final publica el panel solo.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\panel-mapa.txt"))) { Mal "No encuentro src\\panel-mapa.txt en esta carpeta."; return }
$mapaTexto = (Leer (Join-Path $raiz "src\\panel-mapa.txt")).texto
if ((Contar $mapaTexto 'estado.precarga') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-carga-paralela')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: el mapa arranca mas rapido (recarga la pagina con Ctrl+F5)."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + tpl[i:j] + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›✓']
assert not bad, set(bad)
open(R + 'aplicar-mapa-carga-paralela-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
m = open(S + 'panel-mapa-latido.txt', encoding='utf-8').read().replace('\r\n', '\n')
for a, _ in pares:
    assert m.count(a) == 1, (m.count(a), a[:70])
for a, b in pares:
    m = m.replace(a, b)
open(S + 'panel-mapa-paralela.txt', 'w', encoding='utf-8').write(m)
print('ok', len(total))
