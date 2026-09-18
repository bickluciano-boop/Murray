"""Funciones puras de geolocalización de Ojo GPS: buscar direcciones
(Nominatim), calcular rutas (OSRM), y la matemática de rumbo/distancia
que usan tanto el recorrido como el corrimiento hacia la vereda.

Este módulo no importa tkinter a propósito: lo usan tanto la app de
escritorio (ojo_gps_app.py) como el motor sin pantalla para Raspberry Pi
(ojo_gps_headless.py), que no tiene ni necesita ninguna librería gráfica
instalada.
"""
from __future__ import annotations

import json
import math
import ssl
import urllib.parse
import urllib.request

# El instalador de Python.org para Mac no deja configurados los certificados
# raiz que necesita ssl para verificar HTTPS (a diferencia de Windows y de
# Homebrew, que usan los del sistema). Sin esto, toda busqueda de direccion o
# calculo de ruta falla con "CERTIFICATE_VERIFY_FAILED". certifi trae su
# propio paquete de certificados y ya se instala como dependencia de
# pymobiledevice3, asi que no hace falta un paso manual aparte.
try:
    import certifi
    _SSL_CONTEXT = ssl.create_default_context(cafile=certifi.where())
except ImportError:
    _SSL_CONTEXT = None

USER_AGENT = "OjoGPS/1.0"


def urlopen(request, timeout):
    return urllib.request.urlopen(request, timeout=timeout, context=_SSL_CONTEXT)


# Sesgo suave (no excluyente) hacia Buenos Aires para las búsquedas de
# direcciones: sin esto, un nombre de calle repetido en otra provincia (por
# ejemplo "Cabildo", que también existe en Mendoza) puede ganarle al de
# Buenos Aires, que es donde se usa Ojo GPS en la enorme mayoría de los casos.
NOMINATIM_VIEWBOX = "-58.75,-34.35,-58.20,-34.85"


def nominatim_search(query: str, limit: int = 5) -> list:
    params = urllib.parse.urlencode({
        "q": query,
        "format": "jsonv2",
        "limit": limit,
        "accept-language": "es",
        "addressdetails": 1,
        "countrycodes": "ar",
        "viewbox": NOMINATIM_VIEWBOX,
    })
    request = urllib.request.Request(
        "https://nominatim.openstreetmap.org/search?" + params,
        headers={"User-Agent": USER_AGENT},
    )
    with urlopen(request, 20) as response:
        return json.loads(response.read().decode("utf-8"))


def osrm_route(
    origin: tuple[float, float], destination: tuple[float, float], profile: str = "driving"
) -> tuple[list[tuple[float, float]], float]:
    origin_lat, origin_lon = origin
    destination_lat, destination_lon = destination
    osrm_profile = profile if profile in ("foot", "bike", "driving") else "driving"
    # El demo público de router.project-osrm.org trata "foot" como si fuera
    # "driving" (respeta las manos únicas de auto), así que en Caminar podía
    # mandar a dar toda la vuelta a la manzana en vez de cruzar la calle
    # derecho. routing.openstreetmap.de sí tiene un perfil de peatón bien
    # configurado (ignora la mano única de autos), así que Caminar usa ese
    # servidor en vez del genérico.
    base_url = (
        "https://routing.openstreetmap.de/routed-foot/route/v1/foot/"
        if osrm_profile == "foot"
        else f"https://router.project-osrm.org/route/v1/{osrm_profile}/"
    )
    url = (
        f"{base_url}"
        f"{origin_lon:.7f},{origin_lat:.7f};{destination_lon:.7f},{destination_lat:.7f}"
        "?overview=full&geometries=geojson&steps=false"
    )
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urlopen(request, 25) as response:
        payload = json.loads(response.read().decode("utf-8"))
    routes = payload.get("routes") or []
    if not routes:
        raise RuntimeError("No se encontró un camino entre los dos puntos")
    coordinates = routes[0]["geometry"]["coordinates"]
    points = [(float(lat), float(lon)) for lon, lat in coordinates]
    if len(points) < 2:
        raise RuntimeError("El servicio devolvió un recorrido vacío")
    return points, float(routes[0].get("distance", 0.0))


def distance_m(first: tuple[float, float], second: tuple[float, float]) -> float:
    lat1, lon1 = map(math.radians, first)
    lat2, lon2 = map(math.radians, second)
    delta_lat = lat2 - lat1
    delta_lon = lon2 - lon1
    value = math.sin(delta_lat / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(delta_lon / 2) ** 2
    return 6_371_000.0 * 2 * math.atan2(math.sqrt(value), math.sqrt(max(0.0, 1 - value)))


def bearing_deg(origin: tuple[float, float], target: tuple[float, float]) -> float:
    lat1, lon1 = math.radians(origin[0]), math.radians(origin[1])
    lat2, lon2 = math.radians(target[0]), math.radians(target[1])
    delta_lon = lon2 - lon1
    x = math.sin(delta_lon) * math.cos(lat2)
    y = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(delta_lon)
    return (math.degrees(math.atan2(x, y)) + 360.0) % 360.0


def angle_diff_deg(first: float, second: float) -> float:
    diff = abs(first - second) % 360.0
    return diff if diff <= 180.0 else 360.0 - diff


def offset_point(origin: tuple[float, float], bearing: float, distance: float) -> tuple[float, float]:
    radius = 6_371_000.0
    lat1 = math.radians(origin[0])
    lon1 = math.radians(origin[1])
    brng = math.radians(bearing)
    d_over_r = distance / radius
    lat2 = math.asin(
        math.sin(lat1) * math.cos(d_over_r) + math.cos(lat1) * math.sin(d_over_r) * math.cos(brng)
    )
    lon2 = lon1 + math.atan2(
        math.sin(brng) * math.sin(d_over_r) * math.cos(lat1),
        math.cos(d_over_r) - math.sin(lat1) * math.sin(lat2),
    )
    return (math.degrees(lat2), (math.degrees(lon2) + 540.0) % 360.0 - 180.0)


def offset_route_for_sidewalk(
    points: list[tuple[float, float]], offset_m: float = 5.0
) -> list[tuple[float, float]]:
    # Corre cada punto de la ruta unos metros hacia el costado derecho de la
    # dirección de avance, para que Caminar se vea al borde de la calle en
    # vez de pisando el medio. Ver el comentario largo en ojo_gps_app.py
    # (OjoGPSApp._offset_route_for_sidewalk, que delega acá) sobre por qué
    # son 5 metros y no 2.5.
    if len(points) < 2:
        return points
    offset_points = []
    for index, point in enumerate(points):
        if index == 0:
            heading = bearing_deg(points[0], points[1])
        elif index == len(points) - 1:
            heading = bearing_deg(points[-2], points[-1])
        else:
            bearing_in = math.radians(bearing_deg(points[index - 1], point))
            bearing_out = math.radians(bearing_deg(point, points[index + 1]))
            vector_x = math.sin(bearing_in) + math.sin(bearing_out)
            vector_y = math.cos(bearing_in) + math.cos(bearing_out)
            heading = math.degrees(math.atan2(vector_x, vector_y)) % 360.0
        offset_points.append(offset_point(point, (heading + 90.0) % 360.0, offset_m))
    return offset_points


def short_place_label(item: dict) -> str:
    address = item.get("address") or {}
    road = address.get("road") or address.get("pedestrian")
    number = address.get("house_number")
    base = (
        (f"{road} {number}" if road and number else road)
        or address.get("pedestrian")
        or address.get("suburb")
        or address.get("city")
        or item.get("display_name", "Punto elegido").split(",")[0]
    )
    # Sin la localidad, una calle homónima en otra provincia (ej. "Cabildo"
    # también existe en Mendoza) se mostraba idéntica a la de Buenos Aires,
    # sin forma de notar el error antes de iniciar el recorrido.
    locality = address.get("suburb") or address.get("city") or address.get("town")
    state = address.get("state")
    context = ", ".join(part for part in (locality, state) if part and part not in base)
    return f"{base}, {context}" if context else base


def parse_route_coordinates(value: str) -> tuple[float, float] | None:
    try:
        pieces = [piece.strip() for piece in value.split(",")]
        if len(pieces) != 2:
            return None
        lat, lon = float(pieces[0]), float(pieces[1])
        if not (-90 <= lat <= 90 and -180 <= lon <= 180):
            return None
        return lat, lon
    except ValueError:
        return None
