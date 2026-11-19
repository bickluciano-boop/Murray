# Genera scripts/aplicar-lugar-mapa-panel.ps1 (panel, pestana MAPA: src\panel-mapa.txt). Mismo cambio que aplicar-lugar-guardado-panel.ps1 + aplicar-lugar-sin-numero-panel.ps1 (Dispositivos).
# Luciano (19/11/2026): el panel decia "Ugarteche 3154" y su casa es Ugarteche 3157 (vereda de enfrente). En el Mapa, la tarjeta del equipo ahora dice "En Casa · Ugarteche 3157" (nombre del lugar guardado) cuando el equipo esta dentro del lugar
# (usa estado.lugares, ya cargado por el mapa) y no el numero de calle que adivina el sistema de direcciones. Fuera de un lugar guardado: la direccion como siempre. SOLO texto.
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
F = 'src\\panel-mapa.txt'
A_A = 'function metros(a, b) {'
A_B = '''// Si el equipo esta dentro de un lugar guardado (estado.lugares: Casa, Trabajo...), la tarjeta dice "En <lugar>" y no el numero de calle que adivina el sistema de direcciones
// (cruza de vereda con 10-20 m de error; 19/11/2026: "Ugarteche 3154" con la casa en el 3157). El nombre del lugar puede llevar la direccion real. Igual que en Dispositivos. Solo texto.
function textoLugarGuardado(equipo) {
  if (!equipo || equipo.lat === null || equipo.lat === undefined || equipo.lng === null || equipo.lng === undefined) return "";
  let mejor = null;
  for (const lugar of estado.lugares || []) {
    const lt = Number(lugar.latitude), ln = Number(lugar.longitude), radio = Number(lugar.radius);
    if (!Number.isFinite(lt) || !Number.isFinite(ln) || !Number.isFinite(radio) || !String(lugar.name || "").trim()) continue;
    const distancia = metros({ lat: equipo.lat, lng: equipo.lng }, { lat: lt, lng: ln });
    if (distancia <= radio && (!mejor || distancia < mejor.distancia)) mejor = { nombre: String(lugar.name).trim().slice(0, 40), distancia };
  }
  return mejor ? `En ${mejor.nombre}` : "";
}

''' + A_A
B_A = '<p class="ogm-direc">${esc(elegido.direccion || (elegido.lat !== null ?'
B_B = '<p class="ogm-direc">${esc(textoLugarGuardado(elegido) || elegido.direccion || (elegido.lat !== null ?'
# el texto de la linea y de metros() se verifica contra la copia del repositorio (y Luciano confirmo que su archivo tiene las mismas lineas: 318 y 1569)
mapa = open(R + 'mapa/panel-mapa.txt', encoding='utf-8').read()
assert mapa.count(A_A) == 1 and mapa.count(B_A) == 1, (mapa.count(A_A), mapa.count(B_A))
filas = [(F, 'mapa: funcion que dice si el equipo esta dentro de un lugar guardado', A_A, A_B),
         (F, 'mapa: la tarjeta dice "En <lugar>" dentro de un lugar guardado', B_A, B_B)]
def cambios_ps(fs):
    return "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in fs) + "\n)\n"
i0 = tpl.index('$ErrorActionPreference'); j0 = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-lugarmapa')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
MENSAJE = 'LISTO: en el Mapa, la tarjeta del equipo dice "En Casa" (el nombre del lugar guardado) cuando esta dentro del lugar. Solo texto.'
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "%s"\n' % MENSAJE, cola)
assert MENSAJE in cola
cabeza = '''# aplicar-lugar-mapa-panel.ps1 - Ojo Guard MS (panel, pestana MAPA): la tarjeta del equipo dice "En Casa · <direccion del lugar>" cuando el equipo esta dentro de un lugar guardado, y no el numero de calle que adivina el sistema de direcciones.
# Luciano (19/11/2026): lo mismo que ya se hizo en Dispositivos (aplicar-lugar-guardado-panel.ps1 y aplicar-lugar-sin-numero-panel.ps1). SOLO texto. Cambia src\\panel-mapa.txt (respaldo .bak-lugarmapa). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo.
'''
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\panel-mapa.txt"))) { Mal "No encuentro src\\panel-mapa.txt en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-mapa.txt")).texto 'function textoLugarGuardado') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
'''
total = cabeza + tpl[i0:j0] + guardas + cambios_ps(filas) + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕‹›']
assert not bad, set(bad)
open(R + 'aplicar-lugar-mapa-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
open('/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/filas_mapa.json', 'w', encoding='utf-8').write(__import__('json').dumps(filas))
print('ok', len(total))
