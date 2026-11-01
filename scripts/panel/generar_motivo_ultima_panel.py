# Genera scripts/aplicar-motivo-ultima-panel.ps1: ajuste del cartel "sin recorrido": suma la ultima ubicacion conocida y hace cuanto.
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
a1 = '''  let texto = "";
  if (e.pausado) texto = `${e.nombre} tiene la ubicación pausada: no se ve su recorrido.`;
  else if (!e.conRecorrido) texto = `No podés ver el recorrido de ${e.nombre}. Lo ven el titular y los adultos de la familia, y solo el de los menores (el titular también ve el de los adultos).`;
  else if (!puntosDelRango().length && !estado.cargandoDia) texto = `No hay recorrido guardado de ${e.nombre} en este período.${e.enLinea ? "" : ` Su teléfono figura sin conexión (${textoHace(e)}).`}`;
'''
b1 = '''  const ultima = e.lat !== null ? ` Última ubicación: ${e.direccion || `${e.lat.toFixed(5)}, ${e.lng.toFixed(5)}`} (${textoHace(e)}).` : "";
  let texto = "";
  if (e.pausado) texto = `${e.nombre} tiene la ubicación pausada: no se ve su recorrido.`;
  else if (!e.conRecorrido) texto = `No podés ver el recorrido de ${e.nombre}. Lo ven el titular y los adultos de la familia, y solo el de los menores (el titular también ve el de los adultos).${ultima}`;
  else if (!puntosDelRango().length && !estado.cargandoDia) texto = `No hay recorrido guardado de ${e.nombre} en este período.${e.enLinea ? "" : " Su teléfono figura sin conexión."}${ultima}`;
'''
h1a = '<script type="module" src="/mapa-v1.js?v=13"></script>'
h1b = '<script type="module" src="/mapa-v1.js?v=14"></script>'
filas = [('src\\panel-mapa.txt', 'mapa: el cartel suma la ultima ubicacion', a1, b1),
         ('src\\panel-index.html', 'recargar el mapa nuevo (v=14)', h1a, h1b)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-motivo-ultima-panel.ps1 - Ojo Guard MS: el cartel "sin recorrido" tambien dice la ultima ubicacion conocida y hace cuanto (Luciano, 01/11/2026: "y ultima ubicacion").
# Ajuste de aplicar-motivo-sin-recorrido-panel.ps1 (ya aplicado). Cambia SOLO unas lineas de src\\panel-mapa.txt y src\\panel-index.html (v=14). Respaldo .bak-motivoultima. Va en la carpeta del PANEL. Sin build.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
foreach ($f in @("src\\panel-mapa.txt", "src\\panel-index.html")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\\panel-mapa.txt")).texto 'const ultima = e.lat') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-mapa.txt")).texto 'function avisarSinRecorrido') -ne 1) { Mal "Falta aplicar primero aplicar-motivo-sin-recorrido-panel.ps1. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-index.html")).texto '/mapa-v1.js?v=13') -ne 1) { Mal "El mapa no esta en v=13. No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-motivoultima')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: el cartel sin recorrido dice la ultima ubicacion y hace cuanto. Cerra y abri la app (o recarga la pagina del mapa)."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›✓']
assert not bad, set(bad)
open(R + 'aplicar-motivo-ultima-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
