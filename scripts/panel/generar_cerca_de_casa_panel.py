# Genera scripts/aplicar-cerca-de-casa-panel.ps1 (panel, src\panel-app.txt). Sin build. Requiere aplicar-lugar-guardado-panel.ps1 y aplicar-cuadra-por-precision-panel.ps1.
# Luciano (20/11/2026): estaba a ~2 cuadras de su casa (Av. Cerviño y Scalabrini Ortiz) y el panel decia "En Casa · Ugarteche 3157": el lugar Casa tiene radio 200 m (sirve para los avisos de llegada/salida de la familia) y eso es demasiado generoso para AFIRMAR que esta en casa.
# Regla solo de TEXTO (en lugarYDireccion: tarjeta del equipo, evidencia y pulseras): a 80 m o menos del lugar (o de su radio, si es menor) dice "En Casa · ..."; mas lejos pero dentro del radio dice "A 190 m de Casa · <calle>"; fuera del radio, la direccion de siempre.
# Con los puntos de su casa: mediana 36 m, maximo 65 m del pin. NO cambia el radio de los avisos, ni el mapa.
import re
R = '/home/user/Murray/scripts/'
SCRATCH = '/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')


def psq(s):
    return "'" + s.replace("'", "''") + "'"


F = 'src\\panel-app.txt'
M_A = 'mejor = { nombre: String(lugar.name).trim().slice(0, 40), metros };'
M_B = 'mejor = { nombre: String(lugar.name).trim().slice(0, 40), metros, radio };'
R_A = '  if (!mejor) return ajustarPorPrecision(location, direccion);'
R_B = R_A + '''
  // 20/11/2026: estar dentro del RADIO del lugar (200 m, sirve para los avisos de llegada) no alcanza para afirmar "En Casa" (estaba a 2 cuadras y decia "En Casa"): hasta 80 m dice "En Casa", mas lejos "A N m de Casa".
  if (mejor.metros > Math.min(80, mejor.radio)) {
    const corto = String(mejor.nombre).split(" · ")[0].trim() || mejor.nombre;
    const calle = ajustarPorPrecision(location, direccion);
    return `A ${Math.round(mejor.metros / 10) * 10} m de ${corto}${calle ? ` · ${calle}` : ""}`;
  }'''
filas = [(F, 'cerca de casa: guardar el radio del lugar', M_A, M_B),
         (F, 'cerca de casa: a mas de 80 m dice A N m de Casa', R_A, R_B)]


def cambios_ps(fs):
    pref = "    ," if len(fs) == 1 else "    "
    return "$cambios = @(\n" + ',\n'.join(pref + "@(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in fs) + "\n)\n"


i0 = tpl.index('$ErrorActionPreference')
j0 = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-cercacasa')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
DEPLOY = 'if ($LASTEXITCODE -ne 0) { Mal "No se pudo publicar el panel. Mandame esta pantalla."; return }\n'
assert cola.count(DEPLOY) == 1
MENSAJE = 'LISTO: a 80 m o menos de tu lugar guardado dice En Casa; mas lejos dice A N m de Casa. El mapa y los avisos no cambian.'
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "%s"\n' % MENSAJE, cola)
assert MENSAJE in cola
cabeza = '''# aplicar-cerca-de-casa-panel.ps1 - Ojo Guard MS (panel, src\\panel-app.txt): a 80 m o menos de un lugar guardado dice "En Casa"; mas lejos pero dentro de su radio dice "A 190 m de Casa" y la calle.
# Luciano (20/11/2026): estaba a dos cuadras de su casa y el panel decia "En Casa". Solo texto: no cambia el radio de los avisos de llegada/salida ni el mapa. Requiere aplicar-cuadra-por-precision-panel.ps1. Respaldo .bak-cercacasa. Publica el panel (sin build). Va en la carpeta del PANEL (la que tiene wrangler.toml).
'''
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\panel-app.txt"))) { Mal "No encuentro src\\panel-app.txt en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-app.txt")).texto 'function ajustarPorPrecision') -eq 0) { Mal "Falta aplicar primero aplicar-cuadra-por-precision-panel.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-app.txt")).texto 'const corto = String(mejor.nombre)') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
total = cabeza + tpl[i0:j0] + guardas + cambios_ps(filas) + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕‹›±']
assert not bad, set(bad)
open(R + 'aplicar-cerca-de-casa-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))

# --- Prueba: se arma lugarYDireccion con lo que dejan los instaladores ANTERIORES (no una muestra a mano)
g1 = open(R + 'panel/generar_lugar_guardado_panel.py', encoding='utf-8').read()
ini = g1.index('var lugaresGuardados = null')
fin = g1.index("''' + E3_A")
bloque = g1[ini:fin]
SN_A = '  return `En ${mejor.nombre}${direccion ? ` · ${direccion}` : ""}`;'
assert bloque.count(SN_A) == 1, bloque.count(SN_A)
bloque = bloque.replace(SN_A, '  return `En ${mejor.nombre}`;')  # instalador "sin numero"
g3 = open(R + 'panel/generar_cuadra_por_precision_panel.py', encoding='utf-8').read()
marca = "FN_B = '''"
a = g3.index(marca) + len(marca)
b = g3.index("''' + FN_A")
fn_b = g3[a:b]
assert bloque.count('function lugarYDireccion(location, direccion) {') == 1
bloque = bloque.replace('function lugarYDireccion(location, direccion) {', fn_b + 'function lugarYDireccion(location, direccion) {')  # instalador "cuadra"
assert bloque.count('  if (!mejor) return direccion;') == 1
bloque = bloque.replace('  if (!mejor) return direccion;', '  if (!mejor) return ajustarPorPrecision(location, direccion);')
for _a, n, v, nv in filas:
    assert bloque.count(v) == 1, (n, bloque.count(v))
salida = bloque
for _a, n, v, nv in filas:
    salida = salida.replace(v, nv)
open(SCRATCH + 'muestra_cerca.js', 'w', encoding='utf-8').write(salida)
print('ok', len(total))
