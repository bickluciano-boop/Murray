# Genera scripts/aplicar-paradas-iphone-panel.ps1: las paradas tambien para telefonos que mandan pocos puntos (iPhone quieto: iOS no manda puntos hasta que se mueve ~150 m).
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
a1 = '''/** Agrupa puntos seguidos que quedan cerca: si duran lo suficiente, es una parada. */
function paradas(puntos) {
  const lista = [];
  let grupo = [];
  const cerrar = () => {
    if (grupo.length < 2) return;
    const desde = new Date(grupo[0].en), hasta = new Date(grupo[grupo.length - 1].en);
    const minutos = (hasta - desde) / 60_000;
    if (minutos < CONFIG.paradaMinutos) return;
    const lat = grupo.reduce((s, p) => s + p.lat, 0) / grupo.length;
    const lng = grupo.reduce((s, p) => s + p.lng, 0) / grupo.length;
    lista.push({ lat, lng, desde, hasta, minutos: Math.round(minutos), direccion: grupo.find((p) => p.direccion)?.direccion || "" });
  };
  for (const punto of puntos) {
    if (!grupo.length) { grupo = [punto]; continue; }
    const centro = { lat: grupo.reduce((s, p) => s + p.lat, 0) / grupo.length, lng: grupo.reduce((s, p) => s + p.lng, 0) / grupo.length };
    if (metros(centro, punto) <= CONFIG.paradaMetros) grupo.push(punto);
    else { cerrar(); grupo = [punto]; }
  }
  cerrar();
  return lista;
}
'''
b1 = '''/**
 * Agrupa puntos seguidos que quedan cerca: si duran lo suficiente, es una parada.
 * Telefonos que mandan pocos puntos (iPhone: con el telefono quieto iOS no manda nada hasta que se mueve ~150 m): un punto suelto
 * seguido, mucho despues, de otro punto lejano al que se llego despacio (3 km/h o menos) cuenta como una parada hasta ese segundo punto.
 */
function paradas(puntos) {
  const lista = [];
  let grupo = [];
  const cerrar = (siguiente) => {
    if (!grupo.length) return;
    const centro = { lat: grupo.reduce((s, p) => s + p.lat, 0) / grupo.length, lng: grupo.reduce((s, p) => s + p.lng, 0) / grupo.length };
    const desde = new Date(grupo[0].en);
    let hasta = new Date(grupo[grupo.length - 1].en);
    if (siguiente) {
      const hastaSiguiente = new Date(siguiente.en);
      const horas = (hastaSiguiente - hasta) / 3_600_000;
      if ((hastaSiguiente - desde) / 60_000 >= CONFIG.paradaMinutos && horas > 0 && metros(centro, siguiente) / 1000 / horas <= 3) hasta = hastaSiguiente;
    }
    const minutos = (hasta - desde) / 60_000;
    if (minutos < CONFIG.paradaMinutos) return;
    lista.push({ lat: centro.lat, lng: centro.lng, desde, hasta, minutos: Math.round(minutos), direccion: grupo.find((p) => p.direccion)?.direccion || "" });
  };
  for (const punto of puntos) {
    if (!grupo.length) { grupo = [punto]; continue; }
    const centro = { lat: grupo.reduce((s, p) => s + p.lat, 0) / grupo.length, lng: grupo.reduce((s, p) => s + p.lng, 0) / grupo.length };
    if (metros(centro, punto) <= CONFIG.paradaMetros) grupo.push(punto);
    else { cerrar(punto); grupo = [punto]; }
  }
  cerrar();
  return lista;
}
'''
h1a = '<script type="module" src="/mapa-v1.js?v=11"></script>'
h1b = '<script type="module" src="/mapa-v1.js?v=12"></script>'
filas = [('src\\panel-mapa.txt', 'mapa: paradas con pocos puntos (iPhone)', a1, b1),
         ('src\\panel-index.html', 'recargar el mapa nuevo (v=12)', h1a, h1b)]
cambios = "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in filas) + "\n)\n"
cabeza = '''# aplicar-paradas-iphone-panel.ps1 - Ojo Guard MS: el mapa tambien reconoce paradas en telefonos que mandan pocos puntos (iPhone quieto).
# Motivo (01/11/2026, Luciano: "no muestra las paradas de esos"): con el iPhone quieto iOS no manda puntos hasta que se mueve ~150 m, asi que una parada es UN punto al llegar y otro al irse; el mapa pedia dos o mas puntos juntos durante 8 minutos y nunca la veia.
# Ahora: un punto que sigue, mucho despues, de otro punto lejano al que se llego despacio (3 km/h o menos) cuenta como parada hasta ese segundo punto. Cambia SOLO la funcion paradas() en src\\panel-mapa.txt y src\\panel-index.html (v=12). Respaldo .bak-paradas. Va en la carpeta del PANEL. Sin build.
'''
i = tpl.index('$ErrorActionPreference'); j = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
motor_ini = tpl[i:j]
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
foreach ($f in @("src\\panel-mapa.txt", "src\\panel-index.html")) { if (-not (Test-Path (Join-Path $raiz $f))) { Mal ("No encuentro " + $f + " en esta carpeta."); return } }
if ((Contar (Leer (Join-Path $raiz "src\\panel-mapa.txt")).texto 'const cerrar = (siguiente) =>') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-index.html")).texto '/mapa-v1.js?v=11') -ne 1) { Mal "El mapa no esta en v=11 (falta aplicar primero aplicar-aviso-historial-panel.ps1). No toco nada."; return }
'''
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-paradas')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "LISTO: las paradas tambien se ven en telefonos que mandan pocos puntos. Cerra y abri la app (o recarga la pagina del mapa)."\n', cola)
assert 'bak-audioandroid' not in cola and 'wrangler deploy' in cola
total = cabeza + motor_ini + guardas + cambios + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—‹›✓']
assert not bad, set(bad)
open(R + 'aplicar-paradas-iphone-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
print('ok', len(total))
