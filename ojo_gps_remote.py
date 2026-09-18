"""Servidor de control remoto para Ojo GPS.

Permite manejar Ojo GPS desde una pagina web para el celular (buscar una
direccion, Cambiar ubicacion, Joystick, Simular recorrido) sin transmitir
video de la pantalla como un escritorio remoto generico: solo se mandan
las mismas ordenes que ya usan los botones del programa, asi responde
rapido incluso con señal de datos mala.

Pensado primero para usarse dentro de la misma red Wi-Fi que la Mac/PC.
Para controlarlo desde cualquier red de Internet hace falta ademas un
tunel (por ejemplo Cloudflare Tunnel) que exponga este servidor a una
direccion publica — eso se arma aparte, este archivo no lo necesita para
funcionar en la red local.
"""
from __future__ import annotations

import json
import queue
import secrets
import socket
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

MAIN_THREAD_TIMEOUT = 8.0
SESSION_TTL_SECONDS = 12 * 3600
MAX_LOGIN_ATTEMPTS = 5
LOGIN_LOCKOUT_SECONDS = 300


def call_on_main_thread(root, func, *args, **kwargs):
    """Ejecuta func en el hilo principal de Tkinter y espera el resultado.

    Los pedidos HTTP llegan en hilos propios del servidor, pero Tkinter
    solo se puede tocar de forma segura desde su propio hilo (el del
    mainloop) — root.after() encola la llamada ahi y esperamos el
    resultado con una cola, el mismo patrón que ya usa el resto de Ojo
    GPS para pasar datos de hilos de red a la interfaz.
    """
    result: "queue.Queue" = queue.Queue(maxsize=1)

    def _run():
        try:
            result.put(("ok", func(*args, **kwargs)))
        except Exception as exc:  # se reenvia tal cual al cliente
            result.put(("error", exc))

    root.after(0, _run)
    status, value = result.get(timeout=MAIN_THREAD_TIMEOUT)
    if status == "error":
        raise value
    return value


def _local_ip() -> str:
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.connect(("8.8.8.8", 80))
        return sock.getsockname()[0]
    except OSError:
        return "127.0.0.1"
    finally:
        sock.close()


class RemoteControlServer:
    def __init__(self, app) -> None:
        self.app = app
        self.password: str | None = None
        self.sessions: dict[str, float] = {}
        self.failed_attempts: dict[str, list[float]] = {}
        self._lock = threading.Lock()
        self.httpd: ThreadingHTTPServer | None = None
        self.thread: threading.Thread | None = None
        self.port: int | None = None

    def start(self, password: str, port: int = 8765) -> int:
        self.password = password
        handler = _make_handler(self)
        self.httpd = ThreadingHTTPServer(("0.0.0.0", port), handler)
        self.port = self.httpd.server_address[1]
        self.thread = threading.Thread(target=self.httpd.serve_forever, daemon=True)
        self.thread.start()
        return self.port

    def stop(self) -> None:
        if self.httpd is not None:
            self.httpd.shutdown()
            self.httpd.server_close()
        self.httpd = None
        self.thread = None

    @property
    def running(self) -> bool:
        return self.httpd is not None

    def local_url(self) -> str:
        return f"http://{_local_ip()}:{self.port}"

    def check_login(self, client_ip: str, password: str) -> str | None:
        with self._lock:
            now = time.time()
            attempts = [t for t in self.failed_attempts.get(client_ip, []) if now - t < LOGIN_LOCKOUT_SECONDS]
            if len(attempts) >= MAX_LOGIN_ATTEMPTS:
                return None
            if not secrets.compare_digest(password, self.password or ""):
                attempts.append(now)
                self.failed_attempts[client_ip] = attempts
                return None
            self.failed_attempts.pop(client_ip, None)
            token = secrets.token_urlsafe(32)
            self.sessions[token] = now + SESSION_TTL_SECONDS
            return token

    def check_token(self, token: str | None) -> bool:
        if not token:
            return False
        with self._lock:
            expiry = self.sessions.get(token)
            if expiry is None:
                return False
            if expiry < time.time():
                self.sessions.pop(token, None)
                return False
            return True


def _make_handler(remote_server: "RemoteControlServer"):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, format, *args):  # noqa: A002 - firma fija de BaseHTTPRequestHandler
            pass

        def _send_json(self, status: int, payload) -> None:
            body = json.dumps(payload).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def _send_html(self, body: str) -> None:
            data = body.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def _token(self) -> str | None:
            header = self.headers.get("Authorization", "")
            if header.startswith("Bearer "):
                return header[len("Bearer "):]
            return None

        def _require_auth(self) -> bool:
            if remote_server.check_token(self._token()):
                return True
            self._send_json(401, {"error": "No autorizado."})
            return False

        def _read_json(self) -> dict:
            length = int(self.headers.get("Content-Length", "0") or "0")
            if length <= 0:
                return {}
            raw = self.rfile.read(length)
            return json.loads(raw.decode("utf-8")) if raw else {}

        def do_GET(self):  # noqa: N802 - firma fija de BaseHTTPRequestHandler
            path = urlparse(self.path).path
            if path == "/":
                self._send_html(INDEX_HTML)
                return
            if path == "/api/status":
                if not self._require_auth():
                    return
                try:
                    app = remote_server.app
                    status = call_on_main_thread(app.root, app._remote_status)
                    self._send_json(200, status)
                except Exception as exc:
                    self._send_json(500, {"error": str(exc)})
                return
            self._send_json(404, {"error": "No encontrado."})

        def do_POST(self):  # noqa: N802 - firma fija de BaseHTTPRequestHandler
            path = urlparse(self.path).path
            try:
                payload = self._read_json()
            except Exception:
                self._send_json(400, {"error": "JSON inválido."})
                return

            if path == "/api/login":
                token = remote_server.check_login(self.client_address[0], str(payload.get("password", "")))
                if token is None:
                    self._send_json(401, {"error": "Contraseña incorrecta, o demasiados intentos: esperá unos minutos."})
                else:
                    self._send_json(200, {"token": token})
                return

            if not self._require_auth():
                return

            app = remote_server.app
            try:
                if path == "/api/search":
                    from ojo_gps_app import nominatim_search
                    results = nominatim_search(str(payload.get("query", "")))
                    self._send_json(200, {"results": results})
                elif path == "/api/select":
                    call_on_main_thread(app.root, app._remote_select_place, payload["item"])
                    self._send_json(200, {"ok": True})
                elif path == "/api/activate":
                    call_on_main_thread(app.root, app.activate)
                    self._send_json(200, {"ok": True})
                elif path == "/api/fix":
                    call_on_main_thread(app.root, app.fix_location)
                    self._send_json(200, {"ok": True})
                elif path == "/api/joystick":
                    call_on_main_thread(
                        app.root, app._remote_joystick,
                        float(payload.get("north", 0.0)), float(payload.get("east", 0.0)),
                    )
                    self._send_json(200, {"ok": True})
                elif path == "/api/route/mode":
                    call_on_main_thread(app.root, app._remote_set_route_mode, str(payload.get("mode", "Caminar")))
                    self._send_json(200, {"ok": True})
                elif path == "/api/route/start":
                    call_on_main_thread(
                        app.root, app._remote_start_route,
                        str(payload.get("origin", "")), str(payload.get("destination", "")),
                    )
                    self._send_json(200, {"ok": True})
                elif path == "/api/route/pause":
                    call_on_main_thread(app.root, app.toggle_route_pause)
                    self._send_json(200, {"ok": True})
                elif path == "/api/route/stop":
                    call_on_main_thread(app.root, app._stop_route)
                    self._send_json(200, {"ok": True})
                else:
                    self._send_json(404, {"error": "No encontrado."})
            except queue.Empty:
                self._send_json(504, {"error": "Ojo GPS no respondió a tiempo."})
            except Exception as exc:
                self._send_json(400, {"error": str(exc)})

    return Handler


INDEX_HTML = """<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
<title>Ojo GPS - Control remoto</title>
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">
<style>
  :root { --green: #2f7d6b; --green-dark: #1f5c4e; --bg: #f3f6f5; }
  * { box-sizing: border-box; }
  body { margin: 0; font-family: -apple-system, system-ui, sans-serif; background: var(--bg); color: #17322f; }
  header { background: var(--green-dark); color: white; padding: 12px 16px; font-weight: 600; }
  #login { max-width: 320px; margin: 60px auto; padding: 20px; }
  #login input { width: 100%; padding: 12px; font-size: 16px; margin-bottom: 10px; border: 1px solid #ccc; border-radius: 8px; }
  button { background: var(--green); color: white; border: none; border-radius: 8px; padding: 12px 14px; font-size: 15px; font-weight: 600; }
  button.secondary { background: #dbe7e5; color: #17322f; }
  button:disabled { opacity: 0.5; }
  #app { display: none; padding: 12px; padding-bottom: 40px; }
  .card { background: white; border-radius: 12px; padding: 12px; margin-bottom: 12px; box-shadow: 0 1px 3px rgba(0,0,0,0.08); }
  .row { display: flex; gap: 8px; }
  .row > * { flex: 1; }
  input[type=text] { width: 100%; padding: 10px; font-size: 15px; border: 1px solid #ccc; border-radius: 8px; margin-bottom: 6px; }
  #results { list-style: none; padding: 0; margin: 6px 0 0; }
  #results li { padding: 10px; border-bottom: 1px solid #eee; font-size: 14px; }
  #map { height: 260px; border-radius: 12px; overflow: hidden; }
  #status { font-size: 13px; color: #4a615d; margin-top: 4px; }
  #joystick-pad { width: 220px; height: 220px; margin: 10px auto; border-radius: 50%; background: #e7f1ef; border: 3px solid #9fc8c3; position: relative; touch-action: none; }
  #joystick-knob { width: 60px; height: 60px; border-radius: 50%; background: var(--green); position: absolute; left: 80px; top: 80px; }
  .modes { display: flex; gap: 6px; margin-top: 8px; }
  .modes button { flex: 1; font-size: 13px; padding: 8px 4px; }
  .modes button.active { background: var(--green-dark); }
  h3 { margin: 0 0 8px; font-size: 15px; }
</style>
</head>
<body>
<header>Ojo GPS · Control remoto</header>

<div id="login">
  <div class="card">
    <h3>Ingresá la contraseña</h3>
    <input type="password" id="password" placeholder="Contraseña" autocomplete="current-password">
    <button id="loginBtn" style="width:100%">Entrar</button>
    <div id="loginError" style="color:#c94f45;font-size:13px;margin-top:8px;"></div>
  </div>
</div>

<div id="app">
  <div class="card">
    <div id="status">Cargando...</div>
    <div id="map"></div>
  </div>

  <div class="card">
    <h3>Buscar dirección</h3>
    <input type="text" id="searchInput" placeholder="Escribí una dirección">
    <button id="searchBtn" style="width:100%">Buscar</button>
    <ul id="results"></ul>
    <button id="activateBtn" class="secondary" style="width:100%;margin-top:8px;">Cambiar ubicación</button>
  </div>

  <div class="card">
    <h3>Joystick</h3>
    <div class="modes">
      <button data-mode="Caminar" class="mode-btn active">Caminar</button>
      <button data-mode="Bicicleta" class="mode-btn">Bicicleta</button>
      <button data-mode="Auto" class="mode-btn">Auto</button>
    </div>
    <div id="joystick-pad"><div id="joystick-knob"></div></div>
  </div>

  <div class="card">
    <h3>Simular recorrido</h3>
    <input type="text" id="routeOrigin" placeholder="Partida">
    <input type="text" id="routeDestination" placeholder="Llegada">
    <div class="row">
      <button id="routeStartBtn">Iniciar</button>
      <button id="routePauseBtn" class="secondary">Pausar</button>
      <button id="routeStopBtn" class="secondary">Detener</button>
    </div>
  </div>

  <div class="card">
    <button id="fixBtn" class="secondary" style="width:100%">Fijar GPS</button>
  </div>
</div>

<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<script>
let token = null;
let map, marker;

function api(path, body) {
  const opts = { method: "POST", headers: { "Content-Type": "application/json" } };
  if (token) opts.headers["Authorization"] = "Bearer " + token;
  if (body !== undefined) opts.body = JSON.stringify(body);
  return fetch(path, opts).then(async (r) => {
    const data = await r.json().catch(() => ({}));
    if (!r.ok) throw new Error(data.error || ("Error " + r.status));
    return data;
  });
}

function apiGet(path) {
  return fetch(path, { headers: { Authorization: "Bearer " + token } }).then(async (r) => {
    const data = await r.json().catch(() => ({}));
    if (!r.ok) throw new Error(data.error || ("Error " + r.status));
    return data;
  });
}

document.getElementById("loginBtn").onclick = () => {
  const password = document.getElementById("password").value;
  api("/api/login", { password }).then((data) => {
    token = data.token;
    document.getElementById("login").style.display = "none";
    document.getElementById("app").style.display = "block";
    initMap();
    pollStatus();
    setInterval(pollStatus, 2000);
  }).catch((err) => {
    document.getElementById("loginError").textContent = err.message;
  });
};

function initMap() {
  map = L.map("map").setView([-34.6037, -58.3816], 15);
  L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
    attribution: "© OpenStreetMap",
    maxZoom: 19,
  }).addTo(map);
  marker = L.circleMarker([-34.6037, -58.3816], { radius: 9, color: "#2f7d6b", fillColor: "#2f7d6b", fillOpacity: 1 }).addTo(map);
}

let firstStatus = true;
function pollStatus() {
  apiGet("/api/status").then((s) => {
    document.getElementById("status").textContent =
      s.selected_name + " — " + s.connection + " — " + s.status;
    const lat = parseFloat(s.latitude), lon = parseFloat(s.longitude);
    if (!isNaN(lat) && !isNaN(lon) && map) {
      marker.setLatLng([lat, lon]);
      if (firstStatus) { map.setView([lat, lon], 16); firstStatus = false; }
    }
  }).catch(() => {});
}

document.getElementById("searchBtn").onclick = () => {
  const query = document.getElementById("searchInput").value.trim();
  if (!query) return;
  api("/api/search", { query }).then((data) => {
    const list = document.getElementById("results");
    list.innerHTML = "";
    (data.results || []).forEach((item) => {
      const li = document.createElement("li");
      li.textContent = item.display_name;
      li.onclick = () => {
        api("/api/select", { item }).then(() => pollStatus());
        list.innerHTML = "";
      };
      list.appendChild(li);
    });
  }).catch((err) => alert(err.message));
};

document.getElementById("activateBtn").onclick = () => {
  api("/api/activate").catch((err) => alert(err.message));
};

document.getElementById("fixBtn").onclick = () => {
  api("/api/fix").catch((err) => alert(err.message));
};

document.querySelectorAll(".mode-btn").forEach((btn) => {
  btn.onclick = () => {
    document.querySelectorAll(".mode-btn").forEach((b) => b.classList.remove("active"));
    btn.classList.add("active");
    api("/api/route/mode", { mode: btn.dataset.mode }).catch((err) => alert(err.message));
  };
});

document.getElementById("routeStartBtn").onclick = () => {
  api("/api/route/start", {
    origin: document.getElementById("routeOrigin").value.trim(),
    destination: document.getElementById("routeDestination").value.trim(),
  }).catch((err) => alert(err.message));
};
document.getElementById("routePauseBtn").onclick = () => api("/api/route/pause").catch((err) => alert(err.message));
document.getElementById("routeStopBtn").onclick = () => api("/api/route/stop").catch((err) => alert(err.message));

// Joystick tactil: arrastrar el dedo dentro del circulo manda un vector
// norte/este (-1..1), igual que el joystick de mouse de la app de escritorio.
(function () {
  const pad = document.getElementById("joystick-pad");
  const knob = document.getElementById("joystick-knob");
  const center = 110, maxRadius = 80, knobRadius = 30;
  let dragging = false, lastSend = 0;

  function sendVector(north, east) {
    const now = Date.now();
    if (now - lastSend < 150 && !(north === 0 && east === 0)) return;
    lastSend = now;
    api("/api/joystick", { north, east }).catch(() => {});
  }

  function handleMove(clientX, clientY) {
    const rect = pad.getBoundingClientRect();
    let dx = clientX - rect.left - center;
    let dy = clientY - rect.top - center;
    const mag = Math.hypot(dx, dy);
    if (mag > maxRadius) { dx = dx * maxRadius / mag; dy = dy * maxRadius / mag; }
    knob.style.left = (center + dx - knobRadius) + "px";
    knob.style.top = (center + dy - knobRadius) + "px";
    sendVector(-dy / maxRadius, dx / maxRadius);
  }

  function reset() {
    knob.style.left = "80px";
    knob.style.top = "80px";
    sendVector(0, 0);
  }

  pad.addEventListener("touchstart", (e) => { dragging = true; handleMove(e.touches[0].clientX, e.touches[0].clientY); e.preventDefault(); }, { passive: false });
  pad.addEventListener("touchmove", (e) => { if (dragging) handleMove(e.touches[0].clientX, e.touches[0].clientY); e.preventDefault(); }, { passive: false });
  pad.addEventListener("touchend", () => { dragging = false; reset(); });
  pad.addEventListener("mousedown", (e) => { dragging = true; handleMove(e.clientX, e.clientY); });
  window.addEventListener("mousemove", (e) => { if (dragging) handleMove(e.clientX, e.clientY); });
  window.addEventListener("mouseup", () => { if (dragging) { dragging = false; reset(); } });
})();
</script>
</body>
</html>
"""
