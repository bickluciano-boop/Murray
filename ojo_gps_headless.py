"""Motor de Ojo GPS sin pantalla, para correr en una Raspberry Pi Zero (o
cualquier Linux sin entorno gráfico) que viaja en una mochila/bolsillo,
conectada por cable al iPhone.

No tiene ninguna ventana ni usa tkinter para nada: se controla enteramente
por la misma página web y la misma API HTTP que ojo_gps_remote.py ya
expone para la versión de escritorio (Mac/Windows), así que ambas
comparten el control remoto al 100% — la única diferencia es que acá no
hace falta marshalear las llamadas a un hilo principal de Tkinter, porque
no hay ninguno que proteger (HeadlessEngine.root = None se lo indica a
ojo_gps_remote.call_on_main_thread).

Uso en la Raspberry Pi (una vez instalado, ver PENDIENTES.md para el
detalle de instalación):

    python3 ojo_gps_headless.py [--port 8765] [--password loquesea]

Si no se pasa --password, se genera una al azar y se imprime por
consola una sola vez al arrancar (igual que hace el botón "Remoto" en la
version de escritorio).
"""
from __future__ import annotations

import argparse
import math
import secrets
import subprocess
import sys
import threading
import time
from pathlib import Path

import ojo_gps_geo
import ojo_gps_remote

APP_DIR = Path(__file__).resolve().parent
BRIDGE = APP_DIR / "ojo_gps_bridge.py"

SPEEDS_KMH = {"Caminar": 5.0, "Bicicleta": 15.0, "Auto": 40.0}
ROUTE_PRESETS = {"Caminar": (5.0, "foot"), "Bicicleta": (15.0, "bike"), "Auto": (40.0, "driving")}
TICK_SECONDS = 0.5


class HeadlessEngine:
    """Implementa la misma interfaz que espera
    ojo_gps_remote.RemoteControlServer (_remote_status,
    _remote_select_place, _remote_joystick, _remote_set_route_mode,
    _remote_start_route, activate, fix_location, toggle_route_pause,
    _stop_route), para que el servidor de control remoto funcione igual
    con esta version sin pantalla que con la de escritorio.
    """

    # ojo_gps_remote.call_on_main_thread interpreta root=None como "no hay
    # ningún hilo principal que proteger, llamá directo" — acá no hace
    # falta encolar nada porque no hay tkinter.
    root = None

    def __init__(self) -> None:
        self.lock = threading.RLock()
        self.bridge: subprocess.Popen | None = None
        self.current_coords: tuple[float, float] | None = None
        self.active = False
        self.connection_text = "DESCONECTADO"
        self.status_text = "Listo para conectar"
        self.selected_name = "Sin destino elegido"
        self.movement_mode = "Caminar"

        self.joystick_vector: tuple[float, float] | None = None
        self.joystick_timer: threading.Timer | None = None

        self.route_active = False
        self.route_paused = False
        self.route_points_base: list[tuple[float, float]] = []
        self.route_points: list[tuple[float, float]] = []
        self.route_index = 0
        self.route_profile = "bike"
        self.route_speed = 15.0
        self.route_origin_short = ""
        self.route_destination_short = ""
        self.route_info = "Escribí la partida y la llegada"
        self.route_stopped_state: dict | None = None
        self.route_timer: threading.Timer | None = None

    # ------------------------------------------------------------------
    # Conexión con el iPhone (mismo protocolo que usa ojo_gps_app.py)
    # ------------------------------------------------------------------
    def activate(self) -> None:
        with self.lock:
            if self.bridge is not None:
                raise RuntimeError("Ya hay una ubicación activa.")
            if self.current_coords is None:
                raise RuntimeError("Elegí un destino primero.")
            lat, lon = self.current_coords
        threading.Thread(target=self._run_bridge, args=(lat, lon), daemon=True).start()

    def _run_bridge(self, lat: float, lon: float) -> None:
        self.status_text = "Conectando con el iPhone por cable..."
        self.connection_text = "CONECTANDO"
        try:
            bridge = subprocess.Popen(
                [sys.executable, str(BRIDGE), "cable", "maintain", str(lat), str(lon)],
                cwd=APP_DIR,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
            )
            self.bridge = bridge
            assert bridge.stdout is not None
            for line in bridge.stdout:
                self._handle_bridge_line(line.strip())
            bridge.wait()
        except Exception as exc:
            self.status_text = f"Error: {exc}"
        finally:
            self._stop_route_internal()
            self._stop_joystick()
            self.bridge = None
            self.active = False
            self.connection_text = "DESCONECTADO"

    def _handle_bridge_line(self, line: str) -> None:
        if not line.startswith("OJO_STATUS:"):
            return
        value = line.removeprefix("OJO_STATUS:")
        if value == "PREPARING":
            self.status_text = "Preparando herramientas del iPhone..."
        elif value == "CONNECTING":
            self.status_text = "Conectando con el iPhone por cable..."
        elif value == "ACTIVE":
            self.active = True
            self.status_text = "Ubicación simulada activa"
            self.connection_text = "CABLE CONECTADO"
        elif value == "HEARTBEAT":
            if self.joystick_vector is None and not self.route_active:
                self.status_text = "Ubicación simulada activa"
        elif value.startswith("POSITION:"):
            try:
                raw_lat, raw_lon = value.removeprefix("POSITION:").split(",", 1)
                self.current_coords = (float(raw_lat), float(raw_lon))
            except ValueError:
                pass
        elif value.startswith("ERROR:"):
            self.status_text = "Error: " + value.removeprefix("ERROR:")
            self.connection_text = "DESCONECTADO"

    def fix_location(self) -> None:
        # Fijar GPS en la version de escritorio necesita una confirmación
        # interactiva justo en el momento de desactivar Modo Desarrollador
        # en el propio iPhone — no tiene sentido en un control remoto sin
        # esa coordinación en pantalla. Se puede sumar más adelante si
        # hace falta.
        raise RuntimeError("Fijar GPS todavía no está disponible en esta versión sin pantalla.")

    # ------------------------------------------------------------------
    # Interfaz para el control remoto (misma forma que en ojo_gps_app.py)
    # ------------------------------------------------------------------
    def _remote_status(self) -> dict:
        lat = lon = None
        if self.current_coords is not None:
            lat, lon = self.current_coords
        return {
            "latitude": lat,
            "longitude": lon,
            "selected_name": self.selected_name,
            "connection": self.connection_text,
            "status": self.status_text,
            "active": self.active,
            "route_active": self.route_active,
            "route_info": self.route_info,
            "movement_mode": self.movement_mode,
        }

    def _remote_select_place(self, item: dict) -> None:
        self.current_coords = (float(item["lat"]), float(item["lon"]))
        self.selected_name = ojo_gps_geo.short_place_label(item)
        self.status_text = "Destino seleccionado"

    # ---------------------------- Joystick -----------------------------
    def _remote_joystick(self, north: float, east: float) -> None:
        if not self.active:
            raise RuntimeError("Todavía no hay una ubicación activa.")
        if north == 0.0 and east == 0.0:
            self._stop_joystick()
            return
        with self.lock:
            self.joystick_vector = (north, east)
            if self.joystick_timer is None:
                self._joystick_tick()

    def _joystick_tick(self) -> None:
        with self.lock:
            if self.joystick_vector is None or not self.active or self.current_coords is None or self.bridge is None:
                self.joystick_timer = None
                return
            speed_kmh = SPEEDS_KMH.get(self.movement_mode, 5.0)
            distance_m = speed_kmh * 1000.0 / 3600.0 * TICK_SECONDS
            lat, lon = self.current_coords
            north, east = self.joystick_vector
            north_m = distance_m * north
            east_m = distance_m * east
            lat += north_m / 111_320.0
            lon += east_m / max(1.0, 111_320.0 * math.cos(math.radians(lat)))
            self._move_to(lat, lon)
            self.joystick_timer = threading.Timer(TICK_SECONDS, self._joystick_tick)
            self.joystick_timer.daemon = True
            self.joystick_timer.start()

    def _stop_joystick(self) -> None:
        with self.lock:
            self.joystick_vector = None
            if self.joystick_timer is not None:
                self.joystick_timer.cancel()
                self.joystick_timer = None

    def _move_to(self, lat: float, lon: float) -> None:
        self.current_coords = (lat, lon)
        if self.bridge is None or self.bridge.stdin is None:
            return
        try:
            self.bridge.stdin.write(f"MOVE:{lat:.7f},{lon:.7f}\n")
            self.bridge.stdin.flush()
        except Exception:
            pass

    # ------------------------- Simular recorrido -------------------------
    def _remote_set_route_mode(self, mode: str) -> None:
        if mode not in ROUTE_PRESETS:
            raise ValueError("Modo de movimiento inválido.")
        self.movement_mode = mode
        speed, profile = ROUTE_PRESETS[mode]
        self.route_speed = speed
        if profile != self.route_profile:
            self.route_profile = profile
            with self.lock:
                if self.route_active and self.route_points_base:
                    self.route_points = self._points_for_profile(self.route_points_base)

    def _points_for_profile(self, points: list[tuple[float, float]]) -> list[tuple[float, float]]:
        return ojo_gps_geo.offset_route_for_sidewalk(points) if self.route_profile == "foot" else points

    def _remote_start_route(self, origin: str, destination: str) -> None:
        if not self.active or self.bridge is None:
            raise RuntimeError("Primero tocá Cambiar ubicación para conectar el iPhone.")
        if not origin or not destination:
            raise RuntimeError("Escribí la partida y la llegada.")

        stopped = self.route_stopped_state
        if stopped is not None and stopped["origin"] == origin and stopped["destination"] == destination:
            self._resume_stopped_route(stopped)
            return

        origin_coords, origin_short = self._resolve_place(origin)
        destination_coords, destination_short = self._resolve_place(destination)
        if ojo_gps_geo.distance_m(origin_coords, destination_coords) < 2.0:
            raise RuntimeError("La partida y la llegada coinciden. Elegí dos lugares diferentes.")

        points, _distance = ojo_gps_geo.osrm_route(origin_coords, destination_coords, self.route_profile)
        with self.lock:
            self.route_points_base = points
            self.route_points = self._points_for_profile(points)
            self.route_origin_short = origin_short
            self.route_destination_short = destination_short
            self.route_origin_query = origin
            self.route_destination_query = destination
            self.route_index = 1
            self.route_active = True
            self.route_paused = False
            self.route_stopped_state = None
            self._move_to(*self.route_points[0])
            self._update_route_info()
        self._schedule_route_tick()

    @staticmethod
    def _resolve_place(query: str) -> tuple[tuple[float, float], str]:
        coords = ojo_gps_geo.parse_route_coordinates(query)
        if coords is not None:
            return coords, query
        results = ojo_gps_geo.nominatim_search(query, limit=1)
        if not results:
            raise RuntimeError(f"No encontramos esta dirección: {query}")
        item = results[0]
        return (float(item["lat"]), float(item["lon"])), ojo_gps_geo.short_place_label(item)

    def _resume_stopped_route(self, stopped: dict) -> None:
        with self.lock:
            self.route_points_base = stopped["points_base"]
            self.route_points = self._points_for_profile(self.route_points_base)
            self.route_index = min(stopped["index"], max(1, len(self.route_points) - 1))
            self.route_origin_short = stopped["origin_short"]
            self.route_destination_short = stopped["destination_short"]
            self.route_active = True
            self.route_paused = False
            self.route_stopped_state = None
            self._update_route_info()
        self._schedule_route_tick()

    def _remaining_route_distance_m(self) -> float:
        if self.current_coords is None or not self.route_points:
            return 0.0
        position = self.current_coords
        total = 0.0
        for idx in range(self.route_index, len(self.route_points)):
            target = self.route_points[idx]
            total += ojo_gps_geo.distance_m(position, target)
            position = target
        return total

    def _update_route_info(self) -> None:
        remaining_m = self._remaining_route_distance_m()
        speed = max(1.0, self.route_speed)
        minutes = remaining_m / (speed * 1000.0 / 60.0)
        total_minutes = max(1, round(minutes))
        hours, mins = divmod(total_minutes, 60)
        duration = f"{hours} h {mins} min" if hours else f"{mins} min"
        self.route_info = (
            f"{self.route_origin_short} → {self.route_destination_short}\n"
            f"Distancia restante: {remaining_m / 1000.0:.2f} km  •  Llegás en: {duration}"
        )

    def _schedule_route_tick(self) -> None:
        with self.lock:
            if self.route_timer is not None:
                self.route_timer.cancel()
            self.route_timer = threading.Timer(TICK_SECONDS, self._route_tick)
            self.route_timer.daemon = True
            self.route_timer.start()

    def _route_tick(self) -> None:
        with self.lock:
            self.route_timer = None
            if not self.route_active or self.route_paused or self.current_coords is None:
                return
            if self.bridge is None or self.bridge.stdin is None:
                self._stop_route_internal()
                return
            if self.route_index >= len(self.route_points):
                self._finish_route()
                return

            remaining = max(1.0, self.route_speed) * 1000.0 / 3600.0 * TICK_SECONDS
            position = self.current_coords
            while remaining > 0 and self.route_index < len(self.route_points):
                target = self.route_points[self.route_index]
                segment = ojo_gps_geo.distance_m(position, target)
                if segment <= remaining or segment < 0.05:
                    position = target
                    remaining -= segment
                    self.route_index += 1
                else:
                    ratio = remaining / segment
                    position = (
                        position[0] + (target[0] - position[0]) * ratio,
                        position[1] + (target[1] - position[1]) * ratio,
                    )
                    remaining = 0

            self._move_to(*position)
            self._update_route_info()
            if self.route_index >= len(self.route_points):
                self._finish_route()
                return
        self._schedule_route_tick()

    def _finish_route(self) -> None:
        self.route_active = False
        self.route_paused = False
        self.route_points = []
        self.route_points_base = []
        self.route_index = 0
        self.route_stopped_state = None
        self.route_info = "Destino alcanzado. La ubicación permanece activa."

    def toggle_route_pause(self) -> None:
        if not self.route_active:
            return
        with self.lock:
            self.route_paused = not self.route_paused
            if self.route_paused:
                if self.route_timer is not None:
                    self.route_timer.cancel()
                    self.route_timer = None
                return
        self._schedule_route_tick()

    def _stop_route(self) -> None:
        with self.lock:
            self._stop_route_internal()

    def _stop_route_internal(self) -> None:
        if self.route_timer is not None:
            self.route_timer.cancel()
            self.route_timer = None
        was_active = self.route_active
        if (
            was_active
            and self.route_points_base
            and self.route_index < len(self.route_points)
            and hasattr(self, "route_origin_query")
        ):
            self.route_stopped_state = {
                "origin": self.route_origin_query,
                "destination": self.route_destination_query,
                "points_base": self.route_points_base,
                "index": self.route_index,
                "origin_short": self.route_origin_short,
                "destination_short": self.route_destination_short,
            }
        self.route_active = False
        self.route_paused = False
        self.route_points = []
        self.route_points_base = []
        self.route_index = 0
        if was_active:
            self.route_info = "Recorrido detenido; la ubicación actual permanece activa."


def main() -> None:
    parser = argparse.ArgumentParser(description="Ojo GPS sin pantalla, para Raspberry Pi.")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--password", default=None, help="Si no se pasa, se genera una al azar.")
    args = parser.parse_args()

    engine = HeadlessEngine()
    server = ojo_gps_remote.RemoteControlServer(engine)
    password = args.password or secrets.token_hex(3)
    port = server.start(password, port=args.port)

    print("=" * 50)
    print("Ojo GPS (Raspberry Pi) - Control remoto listo")
    print("=" * 50)
    print(f"Dirección: {server.local_url()}")
    print(f"Contraseña: {password}")
    print("Dejá esta ventana/proceso corriendo. Ctrl+C para cerrar.")
    print("=" * 50)

    try:
        while True:
            time.sleep(3600)
    except KeyboardInterrupt:
        print("\nCerrando...")
        server.stop()
        if engine.bridge is not None:
            try:
                if engine.bridge.stdin is not None:
                    engine.bridge.stdin.write("RESTORE\n")
                    engine.bridge.stdin.flush()
                engine.bridge.wait(timeout=15)
            except Exception:
                try:
                    engine.bridge.terminate()
                except Exception:
                    pass


if __name__ == "__main__":
    main()
