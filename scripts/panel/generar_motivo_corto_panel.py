# Genera scripts/aplicar-motivo-corto-panel.ps1: el cartel "sin recorrido" mas corto y sin ocupar media pantalla (el cartel del mapa se achicaba a la mitad del ancho con texto largo).
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
a1 = '''  if (e.pausado) texto = `${e.nombre} tiene la ubicación pausada: no se ve su recorrido.`;
  else if (!e.conRecorrido) texto = `No podés ver el recorrido de ${e.nombre}. Lo ven el titular y los adultos de la familia, y solo el de los menores (el titular también ve el de los adultos).${ultima}`;
  else if (!puntosDelRango().length && !estado.cargandoDia) texto = `No hay recorrido guardado de ${e.nombre} en este período.${e.enLinea ? "" : " Su teléfono figura sin conexión."}${ultima}`;
'''
b1 = '''  if (e.pausado) texto = `${e.nombre} tiene la ubicación pausada.`;
  else if (!e.conRecorrido) texto = `No podés ver el recorrido de ${e.nombre}.${ultima}`;
  else if (!puntosDelRango().length && !estado.cargandoDia) texto = `Sin recorrido guardado de ${e.nombre} en este período.${e.enLinea ? "" : " Sin conexión."}${ultima}`;
'''
a2 = '/*v3*/#og-mapa .ogm-dia,#og-mapa .ogm-dia *{box-sizing:border-box}'
b2 = '/*v3*/#og-mapa .ogm-aviso{width:max-content;box-sizing:border-box;max-width:calc(100% - 24px)}#og-mapa .ogm-dia,#og-mapa .ogm-dia *{box-sizing:border-box}'
h1a = '<script type="module" src="/mapa-v1.js?v=14"></script>'
h1b = '<script type="module" src="/mapa-v1.js?v=15"></script>'
filas = [('src\\panel-mapa.txt', 'mapa: textos mas cortos del cartel', a1, b1),
         ('src\\panel-mapa.txt', 'mapa: el cartel ya no se achica a la mitad', a2, b2),
         ('src\\panel-index.html', 'recargar el mapa nuevo (v=15)', h1a, h1b)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-motivo-corto-panel.ps1 - Ojo Guard MS: el cartel "sin recorrido" del mapa mas corto y del ancho que corresponde.
# Motivo (01/11/2026, captura de Luciano en el iPhone): el cartel quedaba angosto y alto (tapaba media pantalla) porque esta centrado con left:50% y el navegador lo achica a la mitad del ancho con texto largo. Ahora mide lo que necesita y los textos son mas cortos.
# Cambia SOLO unas lineas de src\\panel-mapa.txt y src\\panel-index.html (v=15). Respaldo .bak-motivocorto. Va en la carpeta del PANEL. Sin build.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
foreach ($f in @("src\\panel-mapa.txt", "src\\panel-index.html")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\\panel-mapa.txt")).texto 'Sin recorrido guardado de') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-index.html")).texto '/mapa-v1.js?v=14') -ne 1) { Mal "El mapa no esta en v=14 (falta aplicar primero aplicar-motivo-ultima-panel.ps1). No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-motivocorto')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: el cartel sin recorrido es mas corto y no tapa media pantalla. Cerra y abri la app (o recarga la pagina del mapa)."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›✓']
assert not bad, set(bad)
open(R + 'aplicar-motivo-corto-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
