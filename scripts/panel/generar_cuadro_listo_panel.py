# Genera scripts/aplicar-cuadro-listo-panel.ps1: en "Cambiar rol o quitar", el tilde dice que se guarda al tocarlo y el boton de cerrar pasa a "Listo" (el de guardar rol se llama "Guardar rol").
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
a1 = 'Si lo dejás apagado, no se entera.</small>'
b1 = 'Si lo dejás apagado, no se entera. Se guarda al tocarlo.</small>'
a2 = '<button type="button" class="oro" data-accion="gestion-guardar" ${d.rol === d.rolActual ? "disabled" : ""}>Guardar</button><button type="button" data-accion="cerrar-dialogo">Cancelar</button></div>'
b2 = '<button type="button" class="oro" data-accion="gestion-guardar" ${d.rol === d.rolActual ? "disabled" : ""}>Guardar rol</button><button type="button" data-accion="cerrar-dialogo">${d.rol === d.rolActual ? "Listo" : "Cancelar"}</button></div>'
h1a = '<script type="module" src="/mapa-v1.js?v=16"></script>'
h1b = '<script type="module" src="/mapa-v1.js?v=17"></script>'
filas = [('src\\panel-mapa.txt', 'cuadro de administrar: el tilde se guarda al tocarlo', a1, b1),
         ('src\\panel-mapa.txt', 'cuadro de administrar: botones Guardar rol y Listo', a2, b2),
         ('src\\panel-index.html', 'recargar el mapa nuevo (v=17)', h1a, h1b)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-cuadro-listo-panel.ps1 - Ojo Guard MS: en "Cambiar rol o quitar" el tilde dice que se guarda al tocarlo; el boton de cerrar pasa a "Listo" (si no cambiaste el rol) y el de guardar el rol se llama "Guardar rol".
# Motivo (01/11/2026, Luciano: "no me deja guardar"): el tilde ya estaba guardado pero el boton Guardar (solo para el rol) estaba apagado y parecia que no se podia. Cambia SOLO src\\panel-mapa.txt y src\\panel-index.html (v=17). Respaldo .bak-cuadrolisto. Va en la carpeta del PANEL. Sin build.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
foreach ($f in @("src\\panel-mapa.txt", "src\\panel-index.html")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\\panel-mapa.txt")).texto 'Se guarda al tocarlo') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-index.html")).texto '/mapa-v1.js?v=16') -ne 1) { Mal "El mapa no esta en v=16 (falta aplicar primero aplicar-cartel-izquierda-panel.ps1). No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-cuadrolisto')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: el cuadro de administrar dice que el tilde se guarda al tocarlo y cierra con Listo. Cerra y abri la app (o recarga la pagina del mapa)."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›✓']
assert not bad, set(bad)
open(R + 'aplicar-cuadro-listo-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
