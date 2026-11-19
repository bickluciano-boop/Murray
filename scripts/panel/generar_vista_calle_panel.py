# Genera scripts/aplicar-vista-calle-panel.ps1 (panel, src\panel-app.txt, "Escanear ubicacion"). Requiere aplicar-lugar-guardado-panel.ps1 (usa distanciaMetros y lugaresGuardados).
# Luciano (19/11/2026): "cuando pedis la imagen te muestra la de numero par, la de enfrente".
# Causa: la imagen de calle se pedia a Google sin "heading" (hacia donde mirar): Google mira hacia donde iba el auto que saco la foto, y desde la mitad de la calle eso es la vereda de enfrente.
# Ahora se busca el panorama mas cercano (Maps JS StreetViewService, y si no esta cargado, el servicio "metadata"), se calcula el rumbo desde ese panorama HACIA el punto y se pide la imagen con ese heading (y ese pano).
# Si el telefono esta a menos de 40 m del centro de un lugar guardado, se mira el centro del lugar (el punto que la persona marco). Si algo falla o tarda mas de 4 s, se pide la imagen como antes.
# La clave de Google NO esta en este archivo: se usa la constante STATIC_IMAGES_KEY que ya existe en el panel.
import re
R = '/home/user/Murray/scripts/'
tpl = open(R + 'aplicar-mapa-audio-android-panel.ps1', encoding='utf-8-sig').read().replace('\r\n', '\n')
def psq(s):
    return "'" + s.replace("'", "''") + "'"
F = 'src\\panel-app.txt'
A_A = '  scanStreetImg.src = streetUrl;\n  scanSatImg.src = satUrl;'
A_B = '  // La vista de calle mira HACIA el punto (ver pedirVistaDeCalle): sin rumbo, Google mira hacia donde iba el auto y a veces muestra la vereda de enfrente.\n  pedirVistaDeCalle(latitude, longitude, streetUrl, (url) => { scanStreetImg.src = url; });\n  scanSatImg.src = satUrl;'
B_A = 'function openScanModal(location, title) {'
B_B = '''// Rumbo (0 = norte, 90 = este) para mirar desde un punto hacia otro.
function rumboHacia(desdeLat, desdeLng, haciaLat, haciaLng) {
  const rad = Math.PI / 180, dLng = (haciaLng - desdeLng) * rad;
  const y = Math.sin(dLng) * Math.cos(haciaLat * rad);
  const x = Math.cos(desdeLat * rad) * Math.sin(haciaLat * rad) - Math.sin(desdeLat * rad) * Math.cos(haciaLat * rad) * Math.cos(dLng);
  return (Math.atan2(y, x) / rad + 360) % 360;
}
// A que punto mirar: el del telefono, salvo que este a menos de 40 m del centro de un lugar guardado (el punto que la persona marco: Casa, Trabajo...).
function puntoDeVistaDeCalle(latitude, longitude) {
  let mejor = null;
  for (const lugar of lugaresGuardados || []) {
    const lt = Number(lugar.latitude), ln = Number(lugar.longitude);
    if (!Number.isFinite(lt) || !Number.isFinite(ln)) continue;
    const metros = distanciaMetros(latitude, longitude, lt, ln);
    if (metros <= 40 && (!mejor || metros < mejor.metros)) mejor = { latitude: lt, longitude: ln, metros };
  }
  return mejor ? { latitude: mejor.latitude, longitude: mejor.longitude } : { latitude, longitude };
}
// Pide el panorama mas cercano y arma la imagen de calle apuntando al punto. Si algo falla o tarda mas de 4 s, `respaldo` (la imagen de siempre).
function pedirVistaDeCalle(latitude, longitude, respaldo, poner) {
  let hecho = false, corte = null;
  const usar = (url) => { if (hecho) return; hecho = true; clearTimeout(corte); poner(url); };
  corte = setTimeout(() => usar(respaldo), 4000);
  const objetivo = puntoDeVistaDeCalle(latitude, longitude);
  const base = `https://maps.googleapis.com/maps/api/streetview?size=640x400&fov=80&key=${STATIC_IMAGES_KEY}`;
  const conRumbo = (panoLat, panoLng, panoId) => {
    if (!panoId || !Number.isFinite(panoLat) || !Number.isFinite(panoLng)) return respaldo;
    const pano = `&pano=${encodeURIComponent(panoId)}`;
    // Casi encima del panorama no hay un rumbo claro: se deja el de siempre.
    if (distanciaMetros(panoLat, panoLng, objetivo.latitude, objetivo.longitude) < 3) return `${base}${pano}`;
    return `${base}${pano}&heading=${Math.round(rumboHacia(panoLat, panoLng, objetivo.latitude, objetivo.longitude))}`;
  };
  try {
    if (typeof google !== "undefined" && google.maps && google.maps.StreetViewService) {
      new google.maps.StreetViewService().getPanorama({ location: { lat: objetivo.latitude, lng: objetivo.longitude }, radius: 50, source: google.maps.StreetViewSource ? google.maps.StreetViewSource.OUTDOOR : undefined }, (datos, estado) => {
        const ubicacion = datos && datos.location && datos.location.latLng;
        usar(estado === "OK" && ubicacion ? conRumbo(ubicacion.lat(), ubicacion.lng(), datos.location.pano) : respaldo);
      });
      return;
    }
  } catch { /* sigue con el servicio de metadatos */ }
  fetch(`https://maps.googleapis.com/maps/api/streetview/metadata?location=${objetivo.latitude},${objetivo.longitude}&radius=50&source=outdoor&key=${STATIC_IMAGES_KEY}`)
    .then((respuesta) => respuesta.json())
    .then((m) => usar(m && m.status === "OK" && m.location ? conRumbo(Number(m.location.lat), Number(m.location.lng), m.pano_id) : respaldo))
    .catch(() => usar(respaldo));
}

''' + B_A
filas = [(F, 'vista de calle: pedirla apuntando al punto', A_A, A_B),
         (F, 'vista de calle: las funciones (rumbo, punto, pedido)', B_A, B_B)]
def cambios_ps(fs):
    return "$cambios = @(\n" + ',\n'.join("    @(%s, %s, %s, %s)" % tuple(psq(x) for x in f) for f in fs) + "\n)\n"
i0 = tpl.index('$ErrorActionPreference'); j0 = tpl.index('if (-not (Test-Path (Join-Path $raiz "wrangler.toml")))')
cola = tpl[tpl.index('$descargas = @()'):].replace('.bak-audioandroid', '.bak-vistacalle')
cola = re.sub(r'foreach \(\$k in \$archivos\.Keys\) \{ Chk \(\$k \+ ": huella final"\).*\n', '', cola)
MENSAJE = 'LISTO: "Escanear ubicacion" mira hacia el punto del telefono (o de tu lugar guardado) y ya no muestra la vereda de enfrente.'
cola = re.sub(r'Ok "LISTO: el panel quedo publicado\..*"\n', 'Ok "%s"\n' % MENSAJE, cola)
assert MENSAJE in cola
cabeza = '''# aplicar-vista-calle-panel.ps1 - Ojo Guard MS (panel, "Escanear ubicacion"): la vista de calle mira HACIA el punto del telefono y no hacia donde iba el auto de Google (que desde la mitad de la calle muestra la vereda de enfrente).
# Luciano (19/11/2026): "cuando pedis la imagen te muestra la de numero par, la de enfrente". Si el telefono esta a menos de 40 m del centro de un lugar guardado, se mira el centro del lugar. Requiere aplicar-lugar-guardado-panel.ps1.
# Cambia src\\panel-app.txt (respaldo .bak-vistacalle). Va en la carpeta del PANEL (la que tiene wrangler.toml). Al final publica el panel solo. No toca ninguna clave.
'''
guardas = '''if (-not (Test-Path (Join-Path $raiz "wrangler.toml"))) { Mal "Abri PowerShell en la carpeta del PANEL (la que tiene wrangler.toml), no la de la app."; return }
Ok "Carpeta correcta"
if (-not (Test-Path (Join-Path $raiz "src\\panel-app.txt"))) { Mal "No encuentro src\\panel-app.txt en esta carpeta."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-app.txt")).texto 'function pedirVistaDeCalle') -ne 0) { Avi "Esto ya estaba aplicado. No toco nada."; return }
if ((Contar (Leer (Join-Path $raiz "src\\panel-app.txt")).texto 'function distanciaMetros') -eq 0) { Mal "Falta aplicar primero aplicar-lugar-guardado-panel.ps1."; return }
'''
total = cabeza + tpl[i0:j0] + guardas + cambios_ps(filas) + cola
bad = [c for c in total if ord(c) > 127 and c not in 'áéíóúñÁÉÍÓÚÑ¿¡…·—«»−✓✕‹›']
assert not bad, set(bad)
assert 'AIza' not in total, 'no debe haber ninguna clave'
open(R + 'aplicar-vista-calle-panel.ps1', 'w', encoding='utf-8-sig', newline='').write(total.replace('\n', '\r\n'))
open('/tmp/claude-0/-home-user-Murray/459a989e-0585-521a-8ee1-3a385ef7024a/scratchpad/filas_vista.json', 'w', encoding='utf-8').write(__import__('json').dumps(filas))
print('ok', len(total))
