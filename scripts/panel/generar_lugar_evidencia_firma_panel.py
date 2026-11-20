# Genera scripts/aplicar-lugar-evidencia-firma-panel.ps1 (panel, src\\panel-app.txt). Sin build. Requiere aplicar-lugar-evidencia-panel.ps1.
# Luciano (20/11/2026): tras aplicar aplicar-lugar-evidencia-panel.ps1 la evidencia SEGUIA diciendo "Ugarteche 3177 (aprox.)". Causa (leida en su panel-app.txt): renderEvidence guarda una firma de las evidencias (id, fecha, urls) y NO vuelve a dibujar si no cambiaron; cuando llegan los lugares guardados (async, despues de la primera pantalla) las evidencias no cambian, asi que quedaban con la direccion cruda. Ahora la firma incluye los lugares guardados: cuando llegan, se vuelven a dibujar UNA vez (y no antes ni despues: sin parpadeo).
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
F = 'src\\panel-app.txt'
S_A = '    entries.map((entry) => [entry.id, entry.occurredAt, entry.frontUrl, entry.rearUrl, entry.audioUrl]),'
S_B = S_A + '\n    // Los lugares guardados llegan despues de la primera pantalla: cuando llegan (o cambian) hay que volver a dibujar la direccion de las evidencias ("En Casa").\n    (typeof lugaresGuardados !== "undefined" && lugaresGuardados ? lugaresGuardados : []).map((lugar) => [lugar.id, lugar.name, lugar.latitude, lugar.longitude, lugar.radius]),'
filas = [(F, 'evidencias: redibujar cuando llegan los lugares guardados', S_A, S_B)]
def cambios_ps(fs):
    # Con UNA sola fila, PowerShell aplana @(@(...)) y $c[0] pasa a ser la primera letra: hay que anteponer una coma (,@(...)).
    pref = "    ," if len(fs) == 1 else "    "
    return "$cambios = @(\n" + ',\n'.join(pref + "@(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in fs) + "\n)\n"
i0 = tpl.index('$ErrorActionPreference'); j0 = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-lugarfirma')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
DEPLOY = 'if ($LASTEXITCODE -ne 0) { Mal "No se pudo publicar el panel. Mandame esta pantalla."; return }\n'
assert cola.count(DEPLOY) == 1
MENSAJE = 'LISTO: las evidencias se redibujan cuando llegan tus lugares guardados y dicen En Casa. El mapa no cambia.'
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "%s"\n' % MENSAJE, cola)
assert MENSAJE in cola
cabeza = '''# aplicar-lugar-evidencia-firma-panel.ps1 - Ojo Guard MS (panel, src\\panel-app.txt): las evidencias se vuelven a dibujar cuando llegan los lugares guardados, asi dicen "En Casa · Ugarteche 3157".
# Luciano (20/11/2026): despues de aplicar-lugar-evidencia-panel.ps1 la evidencia seguia con la direccion cruda: renderEvidence no redibujaba porque las evidencias no habian cambiado. Solo agrega los lugares a la firma de redibujo. Requiere aplicar-lugar-evidencia-panel.ps1. Respaldo .bak-lugarfirma. Publica el panel (sin build). Va en la carpeta del PANEL (la que tiene wrangler.toml).
'''
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\panel-app.txt"))) { Mal "No encuentro src\\panel-app.txt en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-app.txt")).texto '|| "Ubicaci') -eq 0) { Mal "Falta aplicar primero aplicar-lugar-evidencia-panel.ps1."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-app.txt")).texto 'lugaresGuardados : []).map((lugar) =>') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
total = cabeza + tpl[i0:j0] + guardas + cambios_ps(filas) + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕‹›']
assert not bad, set(bad)
open(R + 'aplicar-lugar-evidencia-firma-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
open('/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/filas_lugar_evidencia_firma.json', 'w', encoding='utf-8').write(__import__('json').dumps(filas))
muestra = (
  'function renderEvidence(entries) {\n  const root = $("#evidence-root"), toggle = $("#history-toggle");\n  const signature = JSON.stringify([\n    historyExpanded,\n    currentView,\n'
  + S_A + '\n  ]);\n  if (signature === renderedEvidenceSignature) return;\n  renderedEvidenceSignature = signature;\n  root.replaceChildren();\n}\n'
)
for a, n, v, nv in filas:
    assert muestra.count(v) == 1, (n, muestra.count(v))
out = muestra
for a, n, v, nv in filas:
    out = out.replace(v, nv)
open('/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/muestra_lugar_evidencia_firma.js', 'w', encoding='utf-8').write(out)
print('ok', len(total))
