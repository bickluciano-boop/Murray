# Genera scripts/aplicar-cuadra-por-precision-panel.ps1 (panel, src\\panel-app.txt). Sin build. Requiere aplicar-lugar-guardado-panel.ps1.
# Luciano (20/11/2026), paso A: se midio el numero de calle que da el telefono con 33 puntos tomados en su casa (3157): acierta 7 de 28 (25%); el error tipico (12 numeros, max 21) es el del GPS: 6 de 12 aciertos con precision <=10 m, 1 de 6 con 11-15 m, 0 de 10 con 16 m o mas. Con mas de ~8 m de error el numero es ruido presentado como dato exacto.
# Regla (en lugarYDireccion, la que usan la tarjeta del equipo, la evidencia y las pulseras): si el punto NO cae en un lugar guardado y la precision es mayor a 8 m, en lugar del numero se muestra la CUADRA ("Ugarteche 3100 a 3199") y la precision (±19 m). Con 8 m o menos, igual que hoy. Si falta la precision o el numero, igual que hoy. NO toca el mapa (L117 y L319 usan withApprox directo).
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
F = 'src\\panel-app.txt'
FN_A = 'function lugarYDireccion(location, direccion) {'
FN_B = '''// Paso A (20/11/2026): el numero de calle que da el telefono solo es confiable con ~8 m de precision o menos (con 33 puntos en una casa: 25% de aciertos; 0 de 10 con 16 m o mas).
// Con mas error se muestra la cuadra y la precision en lugar de un numero que parece exacto. Si falta algun dato, la direccion queda como vino.
function ajustarPorPrecision(location, direccion) {
  const precision = Number(location?.accuracy), numero = String(location?.streetNumber ?? "").trim(), calle = String(location?.street ?? "").trim();
  if (!direccion || !Number.isFinite(precision) || precision <= 8 || !/^[0-9]{1,5}$/.test(numero) || !calle) return direccion;
  const base = Math.floor(Number(numero) / 100) * 100;
  const nueva = String(direccion).replace(`${calle} ${numero}`, `${calle} ${base} a ${base + 99}`);
  return nueva === String(direccion) ? direccion : `${nueva} · ±${Math.round(precision)} m`;
}
''' + FN_A
RT_A = '  if (!mejor) return direccion;'
RT_B = '  if (!mejor) return ajustarPorPrecision(location, direccion);'
filas = [(F, 'cuadra por precision: la funcion', FN_A, FN_B),
         (F, 'cuadra por precision: usarla cuando no cae en un lugar guardado', RT_A, RT_B)]
def cambios_ps(fs):
    # Con UNA sola fila, PowerShell aplana @(@(...)) y $c[0] pasa a ser la primera letra: hay que anteponer una coma (,@(...)).
    pref = "    ," if len(fs) == 1 else "    "
    return "$cambios = @(\n" + ',\n'.join(pref + "@(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in fs) + "\n)\n"
i0 = tpl.index('$ErrorActionPreference'); j0 = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-cuadra')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
DEPLOY = 'if ($LASTEXITCODE -ne 0) { Mal "No se pudo publicar el panel. Mandame esta pantalla."; return }\n'
assert cola.count(DEPLOY) == 1
MENSAJE = 'LISTO: con mas de 8 m de error el panel muestra la cuadra y la precision en lugar de un numero de calle poco confiable. El mapa no cambia.'
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "%s"\n' % MENSAJE, cola)
assert MENSAJE in cola
cabeza = '''# aplicar-cuadra-por-precision-panel.ps1 - Ojo Guard MS (panel, src\\panel-app.txt): si la precision del GPS es mayor a 8 m, la tarjeta del equipo, la evidencia y las pulseras muestran la CUADRA y la precision en lugar de un numero de calle que no es confiable.
# Luciano (20/11/2026), paso A: con 33 puntos de su casa (3157) el numero acerto 7 de 28 (25%); con 16 m o mas de error, 0 de 10. Dentro de un lugar guardado sigue diciendo "En Casa". No toca el mapa. Requiere aplicar-lugar-guardado-panel.ps1. Respaldo .bak-cuadra. Publica el panel (sin build). Va en la carpeta del PANEL (la que tiene wrangler.toml).
'''
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\panel-app.txt"))) { Mal "No encuentro src\\panel-app.txt en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-app.txt")).texto 'function lugarYDireccion(location, direccion) {') -eq 0) { Mal "Falta aplicar primero aplicar-lugar-guardado-panel.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-app.txt")).texto 'function ajustarPorPrecision') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
total = cabeza + tpl[i0:j0] + guardas + cambios_ps(filas) + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕‹›±']
assert not bad, set(bad)
open(R + 'aplicar-cuadra-por-precision-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
open('/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/filas_cuadra.json', 'w', encoding='utf-8').write(__import__('json').dumps(filas))
muestra = (
  '// Lugares guardados\nfunction distanciaMetros(a) { return a; }\n'
  'function lugarYDireccion(location, direccion) {\n  const lat = Number(location?.latitude);\n  let mejor = null;\n  if (!mejor) return direccion;\n  return `En ${mejor.nombre}`;\n}\n'
)
for a, n, v, nv in filas:
    assert muestra.count(v) == 1, (n, muestra.count(v))
out = muestra
for a, n, v, nv in filas:
    out = out.replace(v, nv)
open('/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/muestra_cuadra.js', 'w', encoding='utf-8').write(out)
print('ok', len(total))
