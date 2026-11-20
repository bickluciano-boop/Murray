# Genera scripts/aplicar-lugar-evidencia-panel.ps1 (panel, src\\panel-app.txt). Sin build de la app: solo se publica el panel. Requiere aplicar-lugar-guardado-panel.ps1 (y el de "sin numero").
# Luciano (20/11/2026): "solo difiere en las alturas de la calle": la tarjeta del equipo decia "En Casa · Ugarteche 3157" y la evidencia "Ugarteche 3160 (aprox.)" (numero que adivina el sistema de direcciones). Ahora la direccion de la EVIDENCIA y la de la tarjeta de PULSERAS usan la misma funcion lugarYDireccion: si el punto cae dentro de un lugar guardado dicen "En Casa · Ugarteche 3157". NO toca el mapa, la vista de calle ni el historial de recorridos (L319 y L117 son del mapa).
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
EV_A = '${location.address ? withApprox(location.address) : "Ubicaci'
EV_B = '${lugarYDireccion(location, location.address ? withApprox(location.address) : "") || "Ubicaci'
PU_A = '${location.address ? ` · ${withApprox(location.address)}` : ""}.`;'
PU_B = '${lugarYDireccion(location, location.address ? withApprox(location.address) : "") ? ` · ${lugarYDireccion(location, location.address ? withApprox(location.address) : "")}` : ""}.`;'
F = 'src\\panel-app.txt'
filas = [(F, 'lugar guardado: la direccion de la evidencia', EV_A, EV_B),
         (F, 'lugar guardado: la ubicacion de la tarjeta de pulseras', PU_A, PU_B)]
def cambios_ps(fs):
    # Con UNA sola fila, PowerShell aplana @(@(...)) y $c[0] pasa a ser la primera letra: hay que anteponer una coma (,@(...)).
    pref = "    ," if len(fs) == 1 else "    "
    return "$cambios = @(\n" + ',\n'.join(pref + "@(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in fs) + "\n)\n"
i0 = tpl.index('$ErrorActionPreference'); j0 = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-lugarevid')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
DEPLOY = 'if ($LASTEXITCODE -ne 0) { Mal "No se pudo publicar el panel. Mandame esta pantalla."; return }\n'
assert cola.count(DEPLOY) == 1
MENSAJE = 'LISTO: la evidencia y la tarjeta de pulseras dicen En Casa y la direccion del lugar cuando el punto cae dentro de un lugar guardado. El mapa no cambia.'
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "%s"\n' % MENSAJE, cola)
assert MENSAJE in cola
cabeza = '''# aplicar-lugar-evidencia-panel.ps1 - Ojo Guard MS (panel, src\\panel-app.txt): la direccion de la EVIDENCIA y la de la tarjeta de PULSERAS dicen "En Casa · Ugarteche 3157" cuando el punto cae dentro de un lugar guardado (como ya hace la tarjeta de Dispositivos).
# Luciano (20/11/2026): la evidencia decia "Ugarteche 3160 (aprox.)" y la tarjeta "Ugarteche 3157". Solo texto: no toca el mapa, la vista de calle ni el historial de recorridos. Requiere aplicar-lugar-guardado-panel.ps1. Respaldo .bak-lugarevid. Publica el panel (sin build). Va en la carpeta del PANEL (la que tiene wrangler.toml).
'''
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\panel-app.txt"))) { Mal "No encuentro src\\panel-app.txt en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-app.txt")).texto 'function lugarYDireccion') -eq 0) { Mal "Falta aplicar primero aplicar-lugar-guardado-panel.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-app.txt")).texto '|| "Ubicaci') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
total = cabeza + tpl[i0:j0] + guardas + cambios_ps(filas) + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕‹›']
assert not bad, set(bad)
open(R + 'aplicar-lugar-evidencia-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
open('/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/filas_lugar_evidencia.json', 'w', encoding='utf-8').write(__import__('json').dumps(filas))
muestra = (
  '    $(".evidence-place", article).textContent = `${evidenceDevice} · ${location.address ? withApprox(location.address) : "Ubicación no disponible"}${evidenceFloorSuffix}`;\n'
  '      summary.textContent = `Última ubicación ${watch.lastLocationAt ? formatBuenosAiresDate(watch.lastLocationAt) : "recibida"}${location.address ? ` · ${withApprox(location.address)}` : ""}.`;\n'
  'const time = document.createElement("span"); time.textContent = `${formatBuenosAiresDate(point.capturedAt)} · Buenos Aires${point.address ? ` · ${withApprox(point.address)}` : ""}`;\n'
  'const gridAddress = lugarYDireccion(device.lastLocation, withApprox(device.lastLocation?.address))\n'
)
for a, n, v, nv in filas:
    assert muestra.count(v) == 1, (n, muestra.count(v))
out = muestra
for a, n, v, nv in filas:
    out = out.replace(v, nv)
assert 'point.address ? ` · ${withApprox(point.address)}` : ""' in out, 'el historial del mapa (L319) debe quedar igual'
open('/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/muestra_lugar_evidencia.js', 'w', encoding='utf-8').write(out)
print('ok', len(total))
