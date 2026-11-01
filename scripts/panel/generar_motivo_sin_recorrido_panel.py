# Genera scripts/aplicar-motivo-sin-recorrido-panel.ps1: cuando una persona no muestra recorrido, el mapa dice por que (ubicacion pausada, sin permiso, o sin puntos guardados).
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
m1a = '    try { estado.recorrido = await cargarRecorrido(equipoElegido()); } catch { estado.recorrido = []; }\n'
m1b = m1a + '    avisarSinRecorrido();\n'
m2a = '  const puntos = filtrarPorRango(estado.recorrido, rango);\n  if (puntos.length > 1) estado.proveedor?.encuadrar(puntos, margenMapa());\n}\n'
m2b = '  const puntos = filtrarPorRango(estado.recorrido, rango);\n  if (puntos.length > 1) estado.proveedor?.encuadrar(puntos, margenMapa());\n  avisarSinRecorrido();\n}\n'
m3a = '  if (estado.recorridoDia.length > 1) estado.proveedor?.encuadrar(estado.recorridoDia, margenMapa());\n}\n'
m3b = '  if (estado.recorridoDia.length > 1) estado.proveedor?.encuadrar(estado.recorridoDia, margenMapa());\n  avisarSinRecorrido();\n}\n'
m4a = '// "Otro dia": el recorrido y todas las paradas de un dia puntual'
m4b = '''// Si una persona no muestra recorrido, el mapa dice por que (y el cartel se va solo a los 7 segundos). En vivo no dice nada.
function avisarSinRecorrido() {
  const e = equipoElegido();
  if (!e || e.tipo !== "persona" || estado.rango === "vivo") return;
  let texto = "";
  if (e.pausado) texto = `${e.nombre} tiene la ubicación pausada: no se ve su recorrido.`;
  else if (!e.conRecorrido) texto = `No podés ver el recorrido de ${e.nombre}. Lo ven el titular y los adultos de la familia, y solo el de los menores (el titular también ve el de los adultos).`;
  else if (!puntosDelRango().length && !estado.cargandoDia) texto = `No hay recorrido guardado de ${e.nombre} en este período.${e.enLinea ? "" : ` Su teléfono figura sin conexión (${textoHace(e)}).`}`;
  aviso(texto);
  clearTimeout(estado.temporizadorMotivo);
  if (texto) estado.temporizadorMotivo = setTimeout(() => aviso(""), 7000);
}

''' + m4a
h1a = '<script type="module" src="/mapa-v1.js?v=12"></script>'
h1b = '<script type="module" src="/mapa-v1.js?v=13"></script>'
filas = [('src\\panel-mapa.txt', 'mapa: avisar el motivo al elegir a una persona', m1a, m1b),
         ('src\\panel-mapa.txt', 'mapa: avisar el motivo al cambiar de rango', m2a, m2b),
         ('src\\panel-mapa.txt', 'mapa: avisar el motivo en Un dia', m3a, m3b),
         ('src\\panel-mapa.txt', 'mapa: funcion del motivo', m4a, m4b),
         ('src\\panel-index.html', 'recargar el mapa nuevo (v=13)', h1a, h1b)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-motivo-sin-recorrido-panel.ps1 - Ojo Guard MS: cuando una persona no muestra recorrido, el mapa dice por que.
# Motivo (01/11/2026, Luciano: "toque a Luli y no hay datos"; su tarjeta decia "Sin conexion, hace 8 h"): el mapa no dibujaba nada y no explicaba nada. Ahora un cartel de 7 segundos dice: ubicacion pausada, sin permiso para ver ese recorrido, o sin recorrido guardado en ese periodo (y si el telefono figura sin conexion).
# Cambia SOLO src\\panel-mapa.txt y src\\panel-index.html (v=13). Respaldo .bak-motivo. Va en la carpeta del PANEL. Sin build.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
foreach ($f in @("src\\panel-mapa.txt", "src\\panel-index.html")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\\panel-mapa.txt")).texto 'function avisarSinRecorrido') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-index.html")).texto '/mapa-v1.js?v=12') -ne 1) { Mal "El mapa no esta en v=12 (falta aplicar primero aplicar-paradas-iphone-panel.ps1). No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-motivo')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: el mapa dice por que una persona no muestra recorrido. Cerra y abri la app (o recarga la pagina del mapa)."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›✓']
assert not bad, set(bad)
open(R + 'aplicar-motivo-sin-recorrido-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
