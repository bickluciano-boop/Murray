import io
import json
import math
import os
import queue
import ctypes
import base64
import hashlib
import hmac
import subprocess
import sys
import threading
import time
import tkinter as tk
import urllib.error
import urllib.parse
import urllib.request
import webbrowser
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timedelta
from pathlib import Path
from tkinter import messagebox, ttk
from zoneinfo import ZoneInfo

try:
    from PIL import Image
    PIL_AVAILABLE = True
except ImportError:
    PIL_AVAILABLE = False


IS_WINDOWS = sys.platform == "win32"
IS_MAC = sys.platform == "darwin"
PLATFORM_NAME = "Mac" if IS_MAC else "Windows"

APP_DIR = Path(__file__).resolve().parent
BRIDGE = APP_DIR / "ojo_gps_bridge.py"
WIFI_TUNNEL = APP_DIR / ("Puente-WiFi-Administrador-Mac.command" if IS_MAC else "Puente-WiFi-Administrador.cmd")
INSTALLER_SCRIPT_NAME = "1-Instalar-Python-Mac.command" if IS_MAC else "1-Instalar-Python-3.13.cmd"
CREATE_NO_WINDOW = 0x08000000 if IS_WINDOWS else 0
GREEN = "#16786f"
GREEN_DARK = "#105f59"
BG = "#f4f7f6"
TEXT = "#173230"
MUTED = "#687b79"


def _app_data_dir() -> Path:
    """Carpeta de datos propios de Ojo GPS, según convención de cada sistema."""
    if IS_WINDOWS:
        return Path(os.environ.get("LOCALAPPDATA", str(Path.home()))) / "Ojo GPS"
    if IS_MAC:
        return Path.home() / "Library" / "Application Support" / "Ojo GPS"
    return Path.home() / ".ojo_gps"


APP_DATA_DIR = _app_data_dir()
HELP_STATE = APP_DATA_DIR / "ayuda.json"
MAPILLARY_API = "https://graph.mapillary.com"
MAPILLARY_TOKEN_FILE = APP_DATA_DIR / "mapillary_token.txt"
# Token propio ya registrado, para que Street View funcione sin configuracion
# manual. Si mapillary_token.txt existe y tiene contenido, ese archivo manda
# (permite reemplazarlo el dia que haga falta regenerarlo).
MAPILLARY_TOKEN_DEFAULT = "MLY|25482118621485690|d7dba83e95671549e1fb6d1df2eae37c"
STREET_VIEW_MAX_SIZE = (760, 540)
# Clave fija para firmar codigos de activacion. No es un secreto real (esta
# en el codigo fuente que se distribuye), pero alcanza para que un codigo no
# se pueda inventar a mano; ver PENDIENTES.md para el detalle del limite.
ACTIVATION_SECRET = b"OjoGPS-Activacion-2026-Lu-v1"
ACTIVATION_FILE = APP_DATA_DIR / "activacion.json"
APP_VERSION = "16.4.32"
SUPPORT_EMAIL = "soporte@ojoguard.app"
SUPPORT_WHATSAPP = "5491168468495"


def ui_font(size: int, semibold: bool = False) -> tuple:
    """Fuente de interfaz según el sistema. Windows tiene "Segoe UI Semibold"
    como familia propia; en Mac y Linux se simula con peso "bold" sobre una
    familia real de esos sistemas, en vez de asumir que existe una familia
    con ese nombre exacto."""
    if IS_WINDOWS:
        return ("Segoe UI Semibold", size) if semibold else ("Segoe UI", size)
    family = "Helvetica Neue" if IS_MAC else "DejaVu Sans"
    return (family, size, "bold") if semibold else (family, size)


class ToolTip:
    """Texto breve que aparece al dejar el puntero sobre un control."""

    def __init__(self, widget, text: str, delay: int = 550) -> None:
        self.widget = widget
        self.text = text
        self.delay = delay
        self.job: str | None = None
        self.window: tk.Toplevel | None = None
        widget.bind("<Enter>", self._schedule, add="+")
        widget.bind("<Leave>", self._hide, add="+")
        widget.bind("<ButtonPress>", self._hide, add="+")

    def _schedule(self, _event=None) -> None:
        self._cancel()
        self.job = self.widget.after(self.delay, self._show)

    def _cancel(self) -> None:
        if self.job is not None:
            try:
                self.widget.after_cancel(self.job)
            except tk.TclError:
                pass
            self.job = None

    def _show(self) -> None:
        self.job = None
        if self.window is not None or not self.widget.winfo_exists():
            return
        x = self.widget.winfo_rootx() + 12
        y = self.widget.winfo_rooty() + self.widget.winfo_height() + 7
        tip = tk.Toplevel(self.widget)
        self.window = tip
        tip.wm_overrideredirect(True)
        tk.Label(
            tip,
            text=self.text,
            justify="left",
            wraplength=330,
            bg="#173230",
            fg="white",
            padx=10,
            pady=7,
            font=ui_font(9),
        ).pack()
        tip.update_idletasks()
        width = tip.winfo_reqwidth()
        height = tip.winfo_reqheight()
        screen_width = self.widget.winfo_screenwidth()
        screen_height = self.widget.winfo_screenheight()
        margin = 8
        x = min(max(margin, x), max(margin, screen_width - width - margin))
        if y + height > screen_height - margin:
            y = self.widget.winfo_rooty() - height - 7
        y = min(max(margin, y), max(margin, screen_height - height - margin))
        tip.wm_geometry(f"+{x}+{y}")

    def _hide(self, _event=None) -> None:
        self._cancel()
        if self.window is not None:
            try:
                self.window.destroy()
            except tk.TclError:
                pass
            self.window = None


MAX_ACTIVATION_DAYS = 9999


def _generate_activation_code(days: int, admin: bool = False) -> str:
    if not 0 <= days <= MAX_ACTIVATION_DAYS:
        raise ValueError(f"La cantidad de días debe estar entre 0 y {MAX_ACTIVATION_DAYS}.")
    payload = f"{days:04d}"
    message = payload + ("ADMIN" if admin else "")
    signature = hmac.new(ACTIVATION_SECRET, message.encode("ascii"), hashlib.sha256).hexdigest()[:8].upper()
    raw = payload + signature
    return "-".join(raw[i:i + 4] for i in range(0, len(raw), 4))


def _validate_activation_code(code: str) -> tuple[int, bool] | None:
    raw = code.strip().upper().replace("-", "").replace(" ", "")
    if len(raw) != 12 or not raw[:4].isdigit():
        return None
    payload, signature = raw[:4], raw[4:]
    expected_regular = hmac.new(ACTIVATION_SECRET, payload.encode("ascii"), hashlib.sha256).hexdigest()[:8].upper()
    if hmac.compare_digest(signature, expected_regular):
        return int(payload), False
    expected_admin = hmac.new(ACTIVATION_SECRET, (payload + "ADMIN").encode("ascii"), hashlib.sha256).hexdigest()[:8].upper()
    if hmac.compare_digest(signature, expected_admin):
        return int(payload), True
    return None


def _load_activation_state() -> dict | None:
    try:
        data = json.loads(ACTIVATION_FILE.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    code = data.get("code")
    activated_at = data.get("activated_at")
    if not isinstance(code, str) or not isinstance(activated_at, str):
        return None
    validated = _validate_activation_code(code)
    if validated is None:
        return None
    days, is_admin = validated
    try:
        activated_dt = datetime.fromisoformat(activated_at)
    except ValueError:
        return None
    return {"days": days, "activated_at": activated_dt, "is_admin": is_admin}


def _save_activation_state(code: str) -> None:
    ACTIVATION_FILE.parent.mkdir(parents=True, exist_ok=True)
    ACTIVATION_FILE.write_text(
        json.dumps({"code": code.strip().upper(), "activated_at": datetime.now().isoformat()}, ensure_ascii=False),
        encoding="utf-8",
    )


def _check_activation() -> tuple[bool, bool, datetime | None]:
    """Devuelve (se_puede_abrir, es_admin, vence). Si no hay una activación
    válida y vigente guardada, muestra un cartel pidiendo un código antes de
    abrir la app principal."""
    state = _load_activation_state()
    if state is not None:
        expires = state["activated_at"] + timedelta(days=state["days"])
        if datetime.now() <= expires:
            return True, state["is_admin"], expires
        initial_message = "Tu código de Ojo GPS venció. Pedí uno nuevo para seguir usándolo."
    else:
        initial_message = "Ingresá el código de activación para usar Ojo GPS."

    gate = tk.Tk()
    gate.title("Ojo GPS - Activación")
    gate.configure(bg="white")
    gate.resizable(False, False)
    try:
        gate.eval("tk::PlaceWindow . center")
    except tk.TclError:
        pass
    result = {"ok": False, "is_admin": False, "expires": None}
    message_var = tk.StringVar(value=initial_message)
    code_var = tk.StringVar(value="")

    def _try_activate() -> None:
        validated = _validate_activation_code(code_var.get())
        if validated is None:
            message_var.set("Código inválido. Revisalo (sin espacios de más) y probá de nuevo.")
            return
        _save_activation_state(code_var.get())
        result["ok"] = True
        result["is_admin"] = validated[1]
        result["expires"] = datetime.now() + timedelta(days=validated[0])
        gate.destroy()

    def _cancel() -> None:
        gate.destroy()

    frame = tk.Frame(gate, padx=24, pady=20, bg="white")
    frame.pack(fill="both", expand=True)
    tk.Label(
        frame, textvariable=message_var, bg="white", fg="#173230",
        font=ui_font(10), wraplength=280, justify="left",
    ).pack(anchor="w", pady=(0, 12))
    entry = tk.Entry(frame, textvariable=code_var, font=ui_font(13), justify="center")
    entry.pack(fill="x", pady=(0, 14))
    entry.focus_set()
    buttons = tk.Frame(frame, bg="white")
    buttons.pack(fill="x")
    tk.Button(buttons, text="Cancelar", command=_cancel).pack(side="right")
    tk.Button(buttons, text="Activar", command=_try_activate, default="active").pack(side="right", padx=(0, 8))
    gate.bind("<Return>", lambda _event: _try_activate())
    gate.protocol("WM_DELETE_WINDOW", _cancel)
    gate.mainloop()
    return result["ok"], result["is_admin"], result["expires"]


class OjoGPSApp:
    def __init__(self, root: tk.Tk, is_admin: bool = False, expires: datetime | None = None) -> None:
        self.root = root
        self.is_admin = is_admin
        self.activation_expires = expires
        self.root.title(f"Ojo GPS 16.4.32 para iPhone en {PLATFORM_NAME}")
        self.root.geometry("940x710")
        self.root.minsize(860, 650)
        self.root.configure(bg=BG)
        self.root.protocol("WM_DELETE_WINDOW", self.close)

        self.events: queue.Queue[tuple[str, str]] = queue.Queue()
        self.search_results: list[dict] = []
        self.bridge: subprocess.Popen | None = None
        self.active = False
        self.fixed = False
        self.restore_succeeded = False
        self.last_heartbeat = 0.0
        self.reconnecting = False
        self.reconnect_attempts = 0
        self.current_coords: tuple[float, float] | None = None
        self.bridge_started_at = 0.0
        self.current_mode = "cable"
        self.current_operation = "maintain"
        self.wifi_preparing = False
        self.joystick_window: tk.Toplevel | None = None
        self.joystick_direction: str | None = None
        self.joystick_vector: tuple[float, float] | None = None
        self.joystick_job: str | None = None
        self.joystick_canvas: tk.Canvas | None = None
        self.joystick_knob: int | None = None
        self.joystick_heading_line: int | None = None
        self.joystick_demo_pointer: int | None = None
        self.joystick_help_button: ttk.Button | None = None
        self.joystick_skip_button: ttk.Button | None = None
        self.joystick_help_job: str | None = None
        self.joystick_help_active = False
        self.joystick_help_frame = 0
        self.joystick_help_seen = self._load_help_seen()
        self.fix_help_window: tk.Toplevel | None = None
        self.fix_help_job: str | None = None
        self.fix_help_frame = 0
        self.fix_help_canvas: tk.Canvas | None = None
        self.fix_help_step_labels: list[tk.Label] = []
        self.movement_mode = tk.StringVar(value="Caminar")
        self.joystick_coords_text = tk.StringVar(value="")
        self.joystick_instruction_text = tk.StringVar(
            value="Arrastrá el círculo con el mouse o el dedo. Mantenelo presionado para avanzar y soltalo para detenerte."
        )
        self.route_window: tk.Toplevel | None = None
        self.route_job: str | None = None
        self.route_points: list[tuple[float, float]] = []
        self.route_index = 0
        self.route_active = False
        self.route_paused = False
        self.route_speed = tk.DoubleVar(value=15.0)
        self.route_speed_text = tk.StringVar(value="15 km/h")
        self.route_profile = "bike"
        self.route_origin_short = ""
        self.route_destination_short = ""
        self.route_info_text = tk.StringVar(value="Escribí la partida y la llegada")
        self.route_origin_address = tk.StringVar(value="")
        self.route_destination_address = tk.StringVar(value="")
        self.route_request_id = 0
        self.route_suggestion_ids = {"origin": 0, "destination": 0}
        self.route_suggestion_jobs = {"origin": None, "destination": None}
        self.route_suggestion_results = {"origin": [], "destination": []}
        self.route_selected_locations = {"origin": None, "destination": None}
        self.map_window: tk.Toplevel | None = None
        self.map_canvas: tk.Canvas | None = None
        self.map_zoom = 15
        self.map_center = (-34.6037, -58.3816)
        self.map_marker: tuple[float, float] | None = None
        self.map_reference_marker: tuple[float, float] | None = None
        self.map_images: list[tk.PhotoImage] = []
        self.map_render_id = 0
        self.map_tile_cache: dict[tuple[int, int, int], str] = {}
        self.map_tile_cache_lock = threading.Lock()
        self.map_cache_dir = APP_DATA_DIR / "map_cache"
        self.map_cache_dir.mkdir(parents=True, exist_ok=True)
        self.map_render_job: str | None = None
        self.map_info_text = tk.StringVar(value="Hacé clic en el mapa para marcar el punto exacto.")
        self.map_selected_address = ""
        self.map_selected_short = ""
        self.map_selected_address_details: dict = {}
        self.map_target = "main"
        self.map_route_edit_target = "origin"
        self.map_drag_start: tuple[float, float] | None = None
        self.map_drag_last: tuple[float, float] | None = None
        self.map_drag_center: tuple[float, float] | None = None
        self.map_dragging = False
        self.place_info_text = tk.StringVar(
            value="Zona: San Nicolás · Buenos Aires · Argentina  |  Hora local: consultando…"
        )
        self.place_location_text = "San Nicolás · Buenos Aires · Argentina"
        self.place_timezone = "America/Argentina/Buenos_Aires"
        self.place_clock_job: str | None = None

        self.street_view_window: tk.Toplevel | None = None
        self.street_view_canvas: tk.Canvas | None = None
        self.street_view_photo = None
        self.street_view_request_id = 0
        self.street_view_cache_dir = APP_DATA_DIR / "street_view_cache"
        self.street_view_cache_dir.mkdir(parents=True, exist_ok=True)

        self.address = tk.StringVar(value="Obelisco, Buenos Aires")
        self.latitude = tk.StringVar(value="-34.6037")
        self.longitude = tk.StringVar(value="-58.3816")
        self.selected_name = tk.StringVar(value="Obelisco, Buenos Aires")
        self.status_text = tk.StringVar(value="Listo para conectar")
        self.connection_text = tk.StringVar(value="DESCONECTADO")
        self.connection_mode = tk.StringVar(value="cable")
        self.footer_text = tk.StringVar(value="Uso normal por cable: mantené el iPhone conectado, desbloqueado y con Modo de desarrollador activo.")
        self.connection_hint_text = tk.StringVar(
            value="Wi-Fi: el iPhone y la PC deben estar conectados a la misma red."
        )

        self._build_style()
        self._build_ui()
        self.root.after(120, self._poll_events)

    def _build_style(self) -> None:
        style = ttk.Style()
        try:
            style.theme_use("clam")
        except tk.TclError:
            pass
        style.configure("TFrame", background=BG)
        style.configure("Card.TFrame", background="white")
        style.configure("TLabel", background=BG, foreground=TEXT, font=ui_font(10))
        style.configure("Card.TLabel", background="white", foreground=TEXT, font=ui_font(10))
        style.configure("Title.TLabel", background=BG, foreground=GREEN_DARK, font=ui_font(28, semibold=True))
        style.configure("Subtitle.TLabel", background=BG, foreground=MUTED, font=ui_font(11))
        style.configure("Section.TLabel", background="white", foreground=TEXT, font=ui_font(12, semibold=True))
        style.configure("Status.TLabel", background="white", foreground=GREEN_DARK, font=ui_font(11, semibold=True))
        style.configure("PlaceContext.TLabel", background="white", foreground=GREEN_DARK, font=ui_font(10, semibold=True))
        style.configure("Primary.TButton", font=ui_font(11, semibold=True), padding=(16, 11), background=GREEN, foreground="white")
        style.map("Primary.TButton", background=[("active", GREEN_DARK), ("disabled", "#9ab8b5")])
        style.configure("Secondary.TButton", font=ui_font(10, semibold=True), padding=(12, 9))
        style.configure("TEntry", padding=8, font=ui_font(10))
        style.configure("Card.TRadiobutton", background="white", foreground=TEXT, font=ui_font(10, semibold=True))

    def _build_ui(self) -> None:
        outer = ttk.Frame(self.root, padding=(30, 24, 30, 24))
        outer.pack(fill="both", expand=True)

        header = ttk.Frame(outer)
        header.pack(fill="x", pady=(0, 18))
        header_left = ttk.Frame(header)
        header_left.pack(side="left", fill="x", expand=True)
        ttk.Label(header_left, text="Ojo GPS 16.4.32", style="Title.TLabel").pack(anchor="w")
        ttk.Label(header_left, text=f"Ubicación para iPhone desde {PLATFORM_NAME}. No compatible con Android.", style="Subtitle.TLabel").pack(anchor="w")

        self.help_button = ttk.Button(header, text="Ayuda", style="Secondary.TButton", command=self.open_help)
        self.help_button.pack(side="right", padx=(10, 0))
        ToolTip(self.help_button, "Abrí las instrucciones completas según lo que quieras hacer.")

        self.support_button = ttk.Button(header, text="Soporte", style="Secondary.TButton", command=self._open_support_panel)
        self.support_button.pack(side="right", padx=(10, 0))
        ToolTip(self.support_button, "Escribinos por mail, WhatsApp, o pedile ayuda a una IA.")

        traffic = tk.Frame(header, bg="white", padx=14, pady=9, highlightthickness=1, highlightbackground="#dbe7e5")
        traffic.pack(side="right", padx=(18, 0))
        self.top_status_dot = tk.Canvas(traffic, width=22, height=22, bg="white", highlightthickness=0)
        self.top_dot = self.top_status_dot.create_oval(3, 3, 19, 19, fill="#c94f45", outline="")
        self.top_status_dot.pack(side="left")
        tk.Label(traffic, textvariable=self.connection_text, bg="white", fg=TEXT, font=ui_font(10, semibold=True)).pack(side="left", padx=(7, 0))
        ToolTip(traffic, "Verde: conectado. Amarillo: procesando. Rojo: desconectado.")

        if self.is_admin:
            admin_badge = tk.Frame(
                header, bg="#fff4e0", padx=14, pady=9,
                highlightthickness=1, highlightbackground="#e0b876", cursor="hand2",
            )
            admin_badge.pack(side="right", padx=(18, 0))
            admin_label = tk.Label(
                admin_badge, text="⚙ ADMINISTRADOR", bg="#fff4e0", fg="#8a5a10", font=ui_font(10, semibold=True),
            )
            admin_label.pack()
            admin_badge.bind("<Button-1>", lambda _event: self._open_admin_panel())
            admin_label.bind("<Button-1>", lambda _event: self._open_admin_panel())
            ToolTip(admin_badge, "Generar códigos de activación para dar copias de prueba.")
        elif self.activation_expires is not None:
            remaining = self.activation_expires - datetime.now()
            if remaining.days >= 1:
                plural = "s" if remaining.days != 1 else ""
                expiry_text = f"Vence en {remaining.days} día{plural}"
            else:
                hours = max(1, int(remaining.total_seconds() // 3600))
                plural = "s" if hours != 1 else ""
                expiry_text = f"Vence en {hours} hora{plural}"
            expiry_badge = tk.Frame(
                header, bg="#eef6f5", padx=14, pady=9,
                highlightthickness=1, highlightbackground="#bcdad6",
            )
            expiry_badge.pack(side="right", padx=(18, 0))
            tk.Label(
                expiry_badge, text=expiry_text, bg="#eef6f5", fg=GREEN_DARK, font=ui_font(10, semibold=True),
            ).pack()
            ToolTip(expiry_badge, "Días de uso restantes de esta copia de prueba de Ojo GPS.")

        card = ttk.Frame(outer, style="Card.TFrame", padding=22)
        card.pack(fill="both", expand=True)
        self.card = card

        order = tk.Frame(card, bg="#e5f3f1", padx=14, pady=10)
        order.pack(fill="x", pady=(0, 16))
        tk.Label(
            order,
            text="PRIMERO ELEGÍ QUÉ QUERÉS HACER. Para ver cada función paso a paso, abrí Ayuda.",
            bg="#e5f3f1",
            fg=GREEN_DARK,
            font=ui_font(10, semibold=True),
        ).pack(anchor="w")

        self.main_panel = ttk.Frame(card, style="Card.TFrame")
        self.main_panel.pack(fill="both", expand=True)
        main = self.main_panel

        mode_row = ttk.Frame(main, style="Card.TFrame")
        mode_row.pack(fill="x", pady=(0, 16))
        ttk.Label(mode_row, text="Conexión", style="Section.TLabel").pack(side="left", padx=(0, 14))
        self.cable_radio = ttk.Radiobutton(
            mode_row,
            text="Cable (estable)",
            value="cable",
            variable=self.connection_mode,
            command=self._mode_changed,
            style="Card.TRadiobutton",
        )
        self.cable_radio.pack(side="left")
        ToolTip(self.cable_radio, "Usá Ojo GPS con el iPhone conectado por cable.")
        self.wifi_radio = ttk.Radiobutton(
            mode_row,
            text="Wi-Fi (experimental)",
            value="wifi",
            variable=self.connection_mode,
            command=self._mode_changed,
            style="Card.TRadiobutton",
        )
        self.wifi_radio.pack(side="left", padx=(16, 0))
        ToolTip(self.wifi_radio, "Usalo sin cable. La PC y el iPhone deben estar en la misma red.")
        self.wifi_button = ttk.Button(
            mode_row,
            text="Preparar Wi-Fi",
            style="Secondary.TButton",
            command=self.prepare_wifi,
        )
        self.wifi_button.pack(side="right")
        ToolTip(self.wifi_button, "Prepará la conexión Wi-Fi antes de retirar el cable.")
        ttk.Label(
            main,
            textvariable=self.connection_hint_text,
            style="Card.TLabel",
            foreground=GREEN_DARK,
        ).pack(anchor="w", pady=(0, 14))

        ttk.Label(main, text="Buscar una dirección o lugar", style="Section.TLabel").pack(anchor="w")
        search_row = ttk.Frame(main, style="Card.TFrame")
        search_row.pack(fill="x", pady=(8, 8))
        self.address_entry = ttk.Entry(search_row, textvariable=self.address)
        self.address_entry.pack(side="left", fill="x", expand=True)
        self.address_entry.bind("<Return>", lambda _event: self.search())
        self.search_button = ttk.Button(search_row, text="Buscar", style="Secondary.TButton", command=self.search)
        self.search_button.pack(side="left", padx=(10, 0))
        ToolTip(self.search_button, "Buscá la dirección escrita y elegí una opción de la lista.")
        self.map_button = ttk.Button(search_row, text="Elegir en el mapa", style="Secondary.TButton", command=self.open_map)
        self.map_button.pack(side="left", padx=(10, 0))
        ToolTip(self.map_button, "Abrí el mapa y marcá el punto exacto aunque no conozcas la altura.")

        self.results = tk.Listbox(
            main,
            height=5,
            activestyle="none",
            selectbackground="#cfe8e5",
            selectforeground=TEXT,
            bg="#f8fbfa",
            fg=TEXT,
            relief="flat",
            highlightthickness=1,
            highlightbackground="#dbe7e5",
            font=ui_font(9),
        )
        self.results.pack(fill="x")
        self.results.bind("<<ListboxSelect>>", self.select_result)

        selected = ttk.Frame(main, style="Card.TFrame")
        selected.pack(fill="x", pady=(18, 6))
        ttk.Label(selected, text="Destino elegido:", style="Section.TLabel").pack(side="left")
        ttk.Label(selected, textvariable=self.selected_name, style="Status.TLabel").pack(side="left", padx=(8, 0))
        ttk.Label(main, textvariable=self.place_info_text, style="PlaceContext.TLabel").pack(anchor="w", pady=(0, 8))

        toggles_row = ttk.Frame(main, style="Card.TFrame")
        toggles_row.pack(fill="x", pady=(4, 0))
        self.coords_visible = False
        self.coords_button = ttk.Button(toggles_row, text="Mostrar datos técnicos", command=self._toggle_coordinates)
        self.coords_button.pack(side="left")
        ToolTip(self.coords_button, "Muestra latitud y longitud solo si las necesitás.")
        self.street_view_button = ttk.Button(
            toggles_row, text="Ver Street View", command=self._open_street_view_from_main,
        )
        self.street_view_button.pack(side="left", padx=(10, 0))
        ToolTip(self.street_view_button, "Mostrá una foto de la calle cerca del destino elegido antes de cambiar el GPS.")
        coords = ttk.Frame(main, style="Card.TFrame")
        self.coords_frame = coords
        left = ttk.Frame(coords, style="Card.TFrame")
        right = ttk.Frame(coords, style="Card.TFrame")
        left.pack(side="left", fill="x", expand=True, padx=(0, 7))
        right.pack(side="left", fill="x", expand=True, padx=(7, 0))
        ttk.Label(left, text="Latitud", style="Card.TLabel").pack(anchor="w")
        ttk.Entry(left, textvariable=self.latitude).pack(fill="x", pady=(4, 0))
        ttk.Label(right, text="Longitud", style="Card.TLabel").pack(anchor="w")
        ttk.Entry(right, textvariable=self.longitude).pack(fill="x", pady=(4, 0))

        buttons = ttk.Frame(main, style="Card.TFrame")
        buttons.pack(fill="x", pady=(6, 14))
        self.activate_button = ttk.Button(buttons, text="Cambiar ubicación", style="Primary.TButton", command=self.activate)
        self.activate_button.pack(side="left", fill="x", expand=True)
        ToolTip(self.activate_button, "Cambia el GPS a la dirección seleccionada.")
        self.joystick_button = ttk.Button(buttons, text="Joystick", style="Secondary.TButton", command=self.open_joystick, state="disabled")
        self.joystick_button.pack(side="left", padx=(12, 0))
        ToolTip(self.joystick_button, "Mové el GPS manualmente en cualquier dirección.")
        self.route_button = ttk.Button(
            buttons,
            text="Simular recorrido",
            style="Secondary.TButton",
            command=self.open_route,
            state="disabled",
        )
        self.route_button.pack(side="left", padx=(12, 0))
        ToolTip(self.route_button, "Simulá un recorrido entre dos ubicaciones.")
        self.fix_button = ttk.Button(
            buttons,
            text="Fijar GPS",
            style="Secondary.TButton",
            command=self.fix_location,
            state="disabled",
        )
        self.fix_button.pack(side="left", padx=(12, 0))
        ToolTip(self.fix_button, "Mantiene la ubicación después de desconectar el cable.")
        self.restore_button = ttk.Button(buttons, text="Volver al GPS real", style="Secondary.TButton", command=self.restore)
        self.restore_button.pack(side="left", padx=(12, 0))
        ToolTip(self.restore_button, "Recuperá la ubicación verdadera del iPhone.")

        separator = ttk.Separator(main)
        separator.pack(fill="x", pady=(4, 13))
        status_row = ttk.Frame(main, style="Card.TFrame")
        status_row.pack(fill="x")
        self.status_dot = tk.Canvas(status_row, width=16, height=16, bg="white", highlightthickness=0)
        self.dot = self.status_dot.create_oval(3, 3, 13, 13, fill="#8ba09e", outline="")
        self.status_dot.pack(side="left")
        ttk.Label(status_row, textvariable=self.status_text, style="Status.TLabel").pack(side="left", padx=(7, 0))

        self._build_route_panel(card)

        ttk.Label(outer, textvariable=self.footer_text, style="Subtitle.TLabel").pack(anchor="w", pady=(14, 0))

    def _build_route_panel(self, card) -> None:
        """Construye una sola vez el recorrido integrado en la ventana principal."""
        self.route_panel = ttk.Frame(card, style="Card.TFrame")

        title_row = ttk.Frame(self.route_panel, style="Card.TFrame")
        title_row.pack(fill="x", pady=(0, 12))
        ttk.Label(title_row, text="Simular recorrido", style="Title.TLabel").pack(side="left")
        ttk.Button(
            title_row,
            text="← Volver",
            style="Secondary.TButton",
            command=self._close_route_panel,
        ).pack(side="right")

        ttk.Label(
            self.route_panel,
            text="Completá primero la partida y después la llegada.",
            style="Subtitle.TLabel",
        ).pack(anchor="w", pady=(0, 14))

        locations = ttk.Frame(self.route_panel, style="Card.TFrame")
        locations.pack(fill="x")
        ttk.Label(locations, text="1. Dirección de partida", style="Section.TLabel").pack(anchor="w")
        origin_row = ttk.Frame(locations, style="Card.TFrame")
        origin_row.pack(fill="x", pady=(5, 3))
        self.route_origin_entry = ttk.Entry(origin_row, textvariable=self.route_origin_address)
        self.route_origin_entry.pack(side="left", fill="x", expand=True)
        origin_map_button = ttk.Button(
            origin_row,
            text="Ver y editar en el mapa",
            command=lambda: self.open_route_map("origin"),
        )
        origin_map_button.pack(side="left", padx=(8, 0))
        ToolTip(origin_map_button, "Marcá directamente en el mapa la dirección de partida.")
        self.route_origin_results = tk.Listbox(locations, height=2, exportselection=False, font=ui_font(9))
        self.route_origin_results.pack(fill="x", pady=(0, 10))
        self.route_origin_entry.bind("<KeyRelease>", lambda _event: self._schedule_route_suggestions("origin"))
        self.route_origin_results.bind("<<ListboxSelect>>", lambda _event: self._select_route_suggestion("origin"))
        ttk.Label(locations, text="2. Dirección de llegada", style="Section.TLabel").pack(anchor="w")
        destination_row = ttk.Frame(locations, style="Card.TFrame")
        destination_row.pack(fill="x", pady=(5, 3))
        self.route_destination_entry = ttk.Entry(destination_row, textvariable=self.route_destination_address)
        self.route_destination_entry.pack(side="left", fill="x", expand=True)
        destination_map_button = ttk.Button(
            destination_row,
            text="Ver y editar en el mapa",
            command=lambda: self.open_route_map("destination"),
        )
        destination_map_button.pack(side="left", padx=(8, 0))
        ToolTip(destination_map_button, "Marcá directamente en el mapa la dirección de llegada.")
        self.route_destination_results = tk.Listbox(locations, height=2, exportselection=False, font=ui_font(9))
        self.route_destination_results.pack(fill="x", pady=(0, 12))
        self.route_destination_entry.bind("<KeyRelease>", lambda _event: self._schedule_route_suggestions("destination"))
        self.route_destination_results.bind("<<ListboxSelect>>", lambda _event: self._select_route_suggestion("destination"))

        ttk.Label(self.route_panel, text="3. Elegí cómo moverte", style="Section.TLabel").pack(anchor="w", pady=(0, 5))
        presets = ttk.Frame(self.route_panel, style="Card.TFrame")
        presets.pack(fill="x", pady=(0, 8))
        for label, value, profile in (
            ("Caminar · 5 km/h", 5.0, "foot"),
            ("Bicicleta · 15 km/h", 15.0, "bike"),
            ("Auto · 40 km/h", 40.0, "driving"),
        ):
            ttk.Button(
                presets,
                text=label,
                style="Secondary.TButton",
                command=lambda v=value, p=profile: self._set_route_speed(v, p),
            ).pack(side="left", expand=True, fill="x", padx=4)

        speed_row = ttk.Frame(self.route_panel, style="Card.TFrame")
        speed_row.pack(fill="x")
        ttk.Label(speed_row, text="Ajustar velocidad", style="Section.TLabel").pack(side="left")
        ttk.Label(speed_row, textvariable=self.route_speed_text, style="Status.TLabel").pack(side="right")
        tk.Scale(
            self.route_panel,
            from_=1.0,
            to=120.0,
            orient="horizontal",
            variable=self.route_speed,
            command=self._route_speed_changed,
            showvalue=False,
            bg="white",
            troughcolor="#4faaa1",
            activebackground=GREEN_DARK,
            highlightthickness=0,
            bd=0,
            sliderlength=28,
            width=18,
        ).pack(fill="x", pady=(5, 7))

        ttk.Label(
            self.route_panel,
            textvariable=self.route_info_text,
            style="Subtitle.TLabel",
            wraplength=800,
        ).pack(anchor="w", pady=(0, 12))

        controls = ttk.Frame(self.route_panel, style="Card.TFrame")
        controls.pack(fill="x")
        self.route_start_button = ttk.Button(
            controls,
            text="Buscar ruta e iniciar",
            style="Primary.TButton",
            command=self.start_route,
        )
        self.route_start_button.pack(side="left", fill="x", expand=True)
        self.route_pause_button = ttk.Button(
            controls,
            text="Pausar",
            style="Secondary.TButton",
            command=self.toggle_route_pause,
            state="disabled",
        )
        self.route_pause_button.pack(side="left", padx=(10, 0))
        self.route_stop_button = ttk.Button(
            controls,
            text="Detener",
            style="Secondary.TButton",
            command=self._stop_route,
            state="disabled",
        )
        self.route_stop_button.pack(side="left", padx=(10, 0))

    def _route_panel_is_visible(self) -> bool:
        return bool(self.route_panel.winfo_manager())

    def _close_route_panel(self) -> None:
        self.route_request_id += 1
        for field in ("origin", "destination"):
            self.route_suggestion_ids[field] += 1
            job = self.route_suggestion_jobs[field]
            if job is not None:
                try:
                    self.root.after_cancel(job)
                except tk.TclError:
                    pass
                self.route_suggestion_jobs[field] = None
            self.route_suggestion_results[field] = []
        self.route_origin_results.delete(0, tk.END)
        self.route_destination_results.delete(0, tk.END)
        if self.route_active:
            self._stop_route()
        else:
            self.route_start_button.configure(state="normal")
            self.route_pause_button.configure(state="disabled", text="Pausar")
            self.route_stop_button.configure(state="disabled")
            self.route_info_text.set("Escribí la partida y la llegada")
            if self.active:
                self.joystick_button.configure(state="normal")
                self.set_status("Ubicación simulada activa", GREEN)
        self.route_panel.pack_forget()
        self.main_panel.pack(fill="both", expand=True)

    def open_help(self) -> None:
        window = tk.Toplevel(self.root)
        window.title("Ojo GPS - Ayuda")
        window.geometry("760x570")
        window.minsize(680, 520)
        window.configure(bg=BG)
        window.transient(self.root)

        frame = ttk.Frame(window, padding=24)
        frame.pack(fill="both", expand=True)
        title_row = ttk.Frame(frame)
        title_row.pack(fill="x", pady=(0, 18))
        ttk.Label(title_row, text="¿Qué querés hacer?", style="Title.TLabel").pack(side="left")
        ttk.Button(title_row, text="Cerrar  ×", style="Secondary.TButton", command=window.destroy).pack(side="right")

        topics = {
            "Cambiar con cable": (
                "Cambiar mi ubicación con cable",
                "1. Conectá y desbloqueá el iPhone.\n"
                "2. Activá Modo de desarrollador.\n"
                "3. Buscá y elegí una dirección.\n"
                "4. Tocá Cambiar ubicación.\n"
                "5. Esperá el indicador verde.\n\n"
                "Mientras uses este modo, mantené el cable conectado.",
            ),
            "Usar por Wi-Fi": (
                "Usar Ojo GPS por Wi-Fi",
                "1. Conectá el iPhone por cable y desbloquealo.\n"
                "2. Confirmá que la PC y el iPhone estén en la misma red Wi-Fi.\n"
                "3. Elegí Wi-Fi y tocá Preparar Wi-Fi.\n"
                "4. Aceptá los permisos y dejá abierta la ventana del Puente Wi-Fi.\n"
                "5. Esperá el indicador verde y recién entonces desconectá el cable.\n"
                "6. Elegí una dirección y tocá Cambiar ubicación.",
            ),
            "Fijar GPS": (
                "Fijar la ubicación y desconectar el iPhone",
                "1. Con el cable conectado, buscá y elegí la dirección.\n"
                "2. Tocá Cambiar ubicación y esperá el indicador verde.\n"
                "3. Tocá Fijar GPS.\n"
                "4. Desactivá Modo de desarrollador, pero no retires todavía el cable.\n"
                "5. Esperá nuevamente el indicador verde.\n"
                "6. Recién entonces desconectá el cable.",
            ),
            "Recorrido": (
                "Simular un recorrido",
                "1. Activá una ubicación y esperá el indicador verde.\n"
                "2. Tocá Simular recorrido.\n"
                "3. Escribí arriba la dirección de partida.\n"
                "4. Escribí debajo la dirección de llegada.\n"
                "5. Elegí la velocidad y tocá Buscar ruta e iniciar.\n\n"
                "Podés pausar, continuar o detener el recorrido.",
            ),
            "Joystick": (
                "Moverme con el joystick",
                "1. Cambiá primero a una ubicación y esperá el indicador verde.\n"
                "2. Tocá Joystick.\n"
                "3. Elegí Caminar, Bicicleta o Auto.\n"
                "4. Arrastrá el círculo con el mouse o el dedo.\n"
                "5. Mantenelo presionado para avanzar y soltalo para detenerte.",
            ),
            "GPS real": (
                "Volver a mi ubicación real",
                "1. Conectá el iPhone por cable y desbloquealo.\n"
                "2. Activá Modo de desarrollador.\n"
                "3. Esperá que Ojo GPS reconozca el iPhone.\n"
                "4. Tocá Volver al GPS real.\n"
                "5. Cerrá y volvé a abrir la aplicación de mapas para comprobarlo.",
            ),
        }

        body = ttk.Frame(frame)
        body.pack(fill="both", expand=True)
        menu = ttk.Frame(body)
        menu.pack(side="left", fill="y", padx=(0, 20))
        content = tk.Frame(body, bg="white", padx=24, pady=22, highlightthickness=1, highlightbackground="#dbe7e5")
        content.pack(side="left", fill="both", expand=True)
        help_title = tk.StringVar()
        help_text = tk.StringVar()

        tk.Label(content, textvariable=help_title, bg="white", fg=GREEN_DARK, font=ui_font(17, semibold=True), anchor="w").pack(fill="x")
        tk.Label(
            content,
            textvariable=help_text,
            bg="white",
            fg=TEXT,
            font=ui_font(11),
            justify="left",
            anchor="nw",
            wraplength=430,
        ).pack(fill="both", expand=True, pady=(18, 0))

        def select_topic(key: str) -> None:
            title, text = topics[key]
            help_title.set(title)
            help_text.set(text)

        for key in topics:
            ttk.Button(
                menu,
                text=key,
                style="Secondary.TButton",
                command=lambda value=key: select_topic(value),
            ).pack(fill="x", pady=(0, 8))
        select_topic("Cambiar con cable")

    def _open_admin_panel(self) -> None:
        window = tk.Toplevel(self.root)
        window.title("Ojo GPS - Panel de administrador")
        window.geometry("480x500")
        window.minsize(440, 460)
        window.configure(bg=BG)
        window.transient(self.root)

        frame = ttk.Frame(window, padding=24)
        frame.pack(fill="both", expand=True)
        title_row = ttk.Frame(frame)
        title_row.pack(fill="x", pady=(0, 14))
        ttk.Label(title_row, text="Generar código de activación", style="Section.TLabel").pack(side="left")
        ttk.Button(title_row, text="Cerrar  ×", style="Secondary.TButton", command=window.destroy).pack(side="right")

        ttk.Label(
            frame,
            text=(
                "Generá un código para dar una copia de prueba con vencimiento.\n"
                "A partir de que la otra persona lo activa, tiene esa cantidad\n"
                "exacta de días de uso. Nunca tiene acceso a este panel."
            ),
            style="Card.TLabel",
            justify="left",
        ).pack(anchor="w", pady=(0, 16))

        days_row = ttk.Frame(frame)
        days_row.pack(fill="x", pady=(0, 6))
        ttk.Label(days_row, text="Cantidad de días:", style="Card.TLabel").pack(side="left")
        days_var = tk.StringVar(value="7")
        ttk.Entry(days_row, textvariable=days_var, width=8, justify="center").pack(side="left", padx=(10, 0))

        message_var = tk.StringVar(value="")
        result_var = tk.StringVar(value="")
        last_code = {"code": "", "days": 0}

        def _generate() -> None:
            text = days_var.get().strip()
            if not text.isdigit() or not 0 < int(text) <= MAX_ACTIVATION_DAYS:
                message_var.set(
                    f"Ingresá un número de días válido, entre 1 y {MAX_ACTIVATION_DAYS} (por ejemplo, 7)."
                )
                return
            days = int(text)
            code = _generate_activation_code(days, admin=False)
            result_var.set(code)
            message_var.set("")
            last_code["code"] = code
            last_code["days"] = days
            history_box.insert(0, f"{code}   ·   {days} días   ·   {datetime.now():%H:%M}")

        ttk.Button(days_row, text="Generar código", style="Primary.TButton", command=_generate).pack(side="left", padx=(14, 0))
        ttk.Label(frame, textvariable=message_var, style="Card.TLabel", foreground="#c45a4a").pack(anchor="w")

        result_row = ttk.Frame(frame)
        result_row.pack(fill="x", pady=(10, 6))
        result_entry = ttk.Entry(result_row, textvariable=result_var, font=ui_font(13, semibold=True), justify="center", state="readonly")
        result_entry.pack(side="left", fill="x", expand=True)

        def _copy() -> None:
            if not result_var.get():
                return
            self.root.clipboard_clear()
            self.root.clipboard_append(result_var.get())
            message_var.set("Copiado.")

        ttk.Button(result_row, text="Copiar", style="Secondary.TButton", command=_copy).pack(side="left", padx=(10, 0))

        def _send_code(via: str) -> None:
            if not last_code["code"]:
                message_var.set("Primero generá un código.")
                return
            plural = "s" if last_code["days"] != 1 else ""
            text = (
                "Ojo GPS - código de acceso\n\n"
                f"Código: {last_code['code']}\n"
                f"Válido por {last_code['days']} día{plural} desde que lo actives.\n\n"
                "Cómo activarlo:\n"
                "1. Abrí Ojo GPS.\n"
                "2. Cuando te pida el código de activación, pegá este:\n"
                f"   {last_code['code']}\n"
                "3. Listo, ya podés usar la app durante ese tiempo."
            )
            if via == "mail":
                subject = urllib.parse.quote("Código de acceso a Ojo GPS")
                body = urllib.parse.quote(text)
                webbrowser.open(f"mailto:?subject={subject}&body={body}")
            else:
                webbrowser.open(f"https://wa.me/?text={urllib.parse.quote(text)}")

        share_row = ttk.Frame(frame)
        share_row.pack(fill="x", pady=(0, 18))
        ttk.Label(share_row, text="Mandar este código:", style="Card.TLabel").pack(side="left")
        ttk.Button(
            share_row, text="✉  Mail", style="Secondary.TButton",
            command=lambda: _send_code("mail"),
        ).pack(side="left", padx=(10, 0))
        ttk.Button(
            share_row, text="WhatsApp", style="Secondary.TButton",
            command=lambda: _send_code("whatsapp"),
        ).pack(side="left", padx=(8, 0))

        ttk.Label(frame, text="Códigos generados en esta sesión:", style="Card.TLabel").pack(anchor="w", pady=(4, 6))
        history_box = tk.Listbox(
            frame, height=6, font=ui_font(9), relief="flat",
            highlightthickness=1, highlightbackground="#dbe7e5", activestyle="none",
        )
        history_box.pack(fill="both", expand=True)

    def _support_context(self) -> str:
        return f"Ojo GPS versión {APP_VERSION}. Lo que me pasa es: "

    def _open_support_panel(self) -> None:
        window = tk.Toplevel(self.root)
        window.title("Ojo GPS - Soporte")
        window.geometry("420x340")
        window.minsize(380, 320)
        window.configure(bg=BG)
        window.transient(self.root)

        frame = ttk.Frame(window, padding=24)
        frame.pack(fill="both", expand=True)
        title_row = ttk.Frame(frame)
        title_row.pack(fill="x", pady=(0, 16))
        ttk.Label(title_row, text="¿Cómo querés hacer la consulta?", style="Section.TLabel").pack(side="left")
        ttk.Button(title_row, text="Cerrar  ×", style="Secondary.TButton", command=window.destroy).pack(side="right")

        def _and_close(action) -> None:
            action()
            window.destroy()

        ttk.Button(
            frame, text="✉  Escribir por mail", style="Primary.TButton",
            command=lambda: _and_close(self._support_via_mail),
        ).pack(fill="x", pady=(0, 10))
        ttk.Button(
            frame, text="Escribir por WhatsApp", style="Primary.TButton",
            command=lambda: _and_close(self._support_via_whatsapp),
        ).pack(fill="x", pady=(0, 10))
        ttk.Button(
            frame, text="Preguntarle a una IA", style="Primary.TButton",
            command=lambda: _and_close(self._support_via_ia),
        ).pack(fill="x", pady=(0, 10))

        ttk.Label(
            frame,
            text=(
                "La opción de IA copia una descripción del problema al "
                "portapapeles y abre un chat de IA para que la pegues y "
                "preguntes."
            ),
            style="Card.TLabel", justify="left", wraplength=360,
        ).pack(anchor="w", pady=(10, 0))

    def _support_via_mail(self) -> None:
        subject = urllib.parse.quote("Soporte Ojo GPS")
        body = urllib.parse.quote(self._support_context())
        webbrowser.open(f"mailto:{SUPPORT_EMAIL}?subject={subject}&body={body}")

    def _support_via_whatsapp(self) -> None:
        text = urllib.parse.quote(self._support_context())
        webbrowser.open(f"https://wa.me/{SUPPORT_WHATSAPP}?text={text}")

    def _support_via_ia(self) -> None:
        try:
            self.root.clipboard_clear()
            self.root.clipboard_append(self._support_context())
        except tk.TclError:
            pass
        webbrowser.open("https://claude.ai/new")

    def _mode_changed(self) -> None:
        if self.bridge is not None:
            self.connection_mode.set(self.current_mode)
            messagebox.showinfo("Ojo GPS", "Primero volvé al GPS real antes de cambiar el tipo de conexión.")
            return
        if self.connection_mode.get() == "wifi":
            self.footer_text.set("Wi-Fi: la PC y el iPhone deben estar en la misma red. El puente administrador debe seguir abierto.")
            self.set_status("Prepará el Wi-Fi con el cable conectado", "#d59b2b")
        else:
            self.footer_text.set("Uso normal por cable: mantené el iPhone conectado, desbloqueado y con Modo de desarrollador activo.")
            self.set_status("Listo para conectar por cable")

    def prepare_wifi(self) -> None:
        if self.wifi_preparing:
            return
        if sys.version_info < (3, 13):
            messagebox.showerror(
                "Ojo GPS - Wi-Fi",
                "El modo Wi-Fi de este iPhone necesita Python 3.13.\n\n"
                f"Cerrá Ojo GPS, ejecutá {INSTALLER_SCRIPT_NAME} y después volvé a abrir la aplicación.",
            )
            return
        if self.bridge is not None:
            messagebox.showinfo("Ojo GPS", "Primero volvé al GPS real.")
            return
        self.connection_mode.set("wifi")
        self._mode_changed()
        self.wifi_preparing = True
        self.wifi_button.configure(state="disabled")
        self.set_status("Preparando emparejamiento Wi-Fi con el cable...", "#d59b2b")
        threading.Thread(target=self._prepare_wifi_worker, daemon=True).start()

    def _python_console(self) -> str:
        executable = Path(sys.executable)
        if executable.name.lower() == "pythonw.exe":
            candidate = executable.with_name("python.exe")
            if candidate.exists():
                return str(candidate)
        return str(executable)

    def _prepare_wifi_worker(self) -> None:
        try:
            base = [self._python_console(), "-m", "pymobiledevice3", "lockdown"]

            # pymobiledevice3 tuvo dos sintaxis para esta opcion. Probamos ambas
            # para que Ojo GPS funcione con la version que ya tiene instalada la PC.
            wifi_result = self._run_setup_command(base + ["wifi-connections", "on"])
            if wifi_result.returncode != 0:
                wifi_result = self._run_setup_command(base + ["wifi-connections", "--state", "on"])
            if wifi_result.returncode != 0:
                detail = (wifi_result.stderr or wifi_result.stdout or "Error desconocido").strip()
                raise RuntimeError(detail[-900:])

            pairing_result = self._run_setup_command(base + ["remotepairing", "--pair"])
            if pairing_result.returncode != 0:
                detail = (pairing_result.stderr or pairing_result.stdout or "Error desconocido").strip()
                raise RuntimeError(detail[-900:])
            self.events.put(("WIFI_PREP_OK", ""))
        except Exception as exc:
            self.events.put(("WIFI_PREP_ERROR", str(exc)))

    def _run_setup_command(self, command: list[str]) -> subprocess.CompletedProcess:
        return subprocess.run(
            command,
            cwd=APP_DIR,
            capture_output=True,
            text=True,
            timeout=120,
            creationflags=CREATE_NO_WINDOW,
        )

    def _launch_wifi_tunnel(self) -> None:
        try:
            if IS_MAC:
                # macOS no tiene un equivalente directo al "runas" de Windows para
                # elevar un script desde código; abrimos el .command en una
                # Terminal nueva y el "sudo" adentro del script pide la
                # contraseña ahí mismo, en vez de un cartel gráfico separado.
                subprocess.Popen(["open", "-a", "Terminal", str(WIFI_TUNNEL)])
                permission_hint = "Ingresá tu contraseña de Mac cuando la Terminal te la pida"
            else:
                result = ctypes.windll.shell32.ShellExecuteW(
                    None,
                    "runas",
                    str(WIFI_TUNNEL),
                    None,
                    str(APP_DIR),
                    1,
                )
                if result <= 32:
                    raise RuntimeError("Windows no pudo abrir el puente como administrador")
                permission_hint = "Aceptá el permiso de Windows"
            self.set_status(f"Puente Wi-Fi iniciando; {permission_hint.lower()}", "#d59b2b")
            messagebox.showinfo(
                "Ojo GPS - Wi-Fi",
                f"{permission_hint} y dejá abierta la ventana negra del puente.\n\n"
                "Mantené el iPhone conectado y desbloqueado. Al cerrar este aviso, Ojo GPS continuará automáticamente.\n\n"
                "Retirá el cable solamente cuando el indicador esté verde.",
            )
            self.root.after(1500, self._connect_after_wifi_tunnel)
        except Exception as exc:
            self.set_status("No se pudo iniciar el puente Wi-Fi", "#c45a4a")
            messagebox.showerror("Ojo GPS", str(exc))

    def _connect_after_wifi_tunnel(self) -> None:
        """Continua el flujo Wi-Fi una vez abierta la ventana administradora."""
        if self.connection_mode.get() != "wifi":
            return
        if self.bridge is not None or self.active:
            return
        self.set_status("Puente Wi-Fi abierto; conectando automáticamente...", "#d59b2b")
        self.activate()

    def set_status(self, text: str, color: str = "#8ba09e") -> None:
        self.status_text.set(text)
        self.status_dot.itemconfigure(self.dot, fill=color)

    def set_connection(self, text: str, color: str) -> None:
        self.connection_text.set(text)
        self.top_status_dot.itemconfigure(self.top_dot, fill=color)

    def search(self) -> None:
        query = self.address.get().strip()
        if not query:
            messagebox.showinfo("Ojo GPS", "Escribí una dirección o el nombre de un lugar.")
            return
        self.search_button.configure(state="disabled")
        self.set_status("Buscando lugar...", "#d59b2b")
        threading.Thread(target=self._search_worker, args=(query,), daemon=True).start()

    def _search_worker(self, query: str) -> None:
        try:
            params = urllib.parse.urlencode({
                "q": query,
                "format": "jsonv2",
                "limit": 5,
                "accept-language": "es",
                "addressdetails": 1,
            })
            request = urllib.request.Request(
                "https://nominatim.openstreetmap.org/search?" + params,
                headers={"User-Agent": "OjoGPS-Windows/16.4.32"},
            )
            with urllib.request.urlopen(request, timeout=20) as response:
                results = json.loads(response.read().decode("utf-8"))
            self.events.put(("SEARCH_OK", json.dumps(results)))
        except Exception as exc:
            self.events.put(("SEARCH_ERROR", str(exc)))

    def select_result(self, _event=None) -> None:
        selection = self.results.curselection()
        if not selection:
            return
        item = self.search_results[selection[0]]
        self.latitude.set(item["lat"])
        self.longitude.set(item["lon"])
        self.selected_name.set(self._short_place_label(item))
        self.set_status("Destino seleccionado", GREEN)
        self._request_place_context(float(item["lat"]), float(item["lon"]), item)

    def _toggle_coordinates(self) -> None:
        """Keep coordinates available without making them the main experience."""
        self.coords_visible = not self.coords_visible
        if self.coords_visible:
            self.coords_frame.pack(fill="x", pady=(8, 0), after=self.coords_button)
            self.coords_button.configure(text="Ocultar datos técnicos")
        else:
            self.coords_frame.pack_forget()
            self.coords_button.configure(text="Mostrar datos técnicos")

    @staticmethod
    def _world_pixels(lat: float, lon: float, zoom: int) -> tuple[float, float]:
        scale = 256 * (2 ** zoom)
        lat = max(-85.05112878, min(85.05112878, lat))
        x = (lon + 180.0) / 360.0 * scale
        y = (1.0 - math.asinh(math.tan(math.radians(lat))) / math.pi) / 2.0 * scale
        return x, y

    @staticmethod
    def _latlon_from_world(x: float, y: float, zoom: int) -> tuple[float, float]:
        scale = 256 * (2 ** zoom)
        lon = x / scale * 360.0 - 180.0
        n = math.pi - 2.0 * math.pi * y / scale
        lat = math.degrees(math.atan(math.sinh(n)))
        return lat, lon

    def _open_destination_map(self) -> None:
        """Abre la llegada asegurando antes que la partida tenga coordenadas."""
        if self.route_selected_locations.get("origin") is None:
            query = self.route_origin_address.get().strip()
            if not query:
                messagebox.showinfo(
                    "Simular recorrido",
                    "Primero escribí o marcá en el mapa la dirección de partida.",
                )
                self.route_origin_entry.focus_set()
                return
            try:
                (lat, lon), origin_item = self._geocode_route_location(query)
            except Exception as exc:
                messagebox.showerror(
                    "Simular recorrido",
                    "No pude ubicar la dirección de partida. Elegila de la lista o marcala en el mapa.\n\n"
                    + str(exc),
                )
                self.route_origin_entry.focus_set()
                return
            display_name = origin_item.get("display_name", query)
            self.route_selected_locations["origin"] = {
                "lat": str(lat),
                "lon": str(lon),
                "display_name": display_name,
                "address": origin_item.get("address") or {},
            }
            self.route_origin_address.set(display_name)
        self.open_map("destination")

    def open_route_map(self, edit_target: str = "origin") -> None:
        """Abre inmediatamente el mapa para revisar partida y llegada.

        Antes se intentaba convertir aquí cada texto en coordenadas mediante
        Internet. Esa espera bloqueaba la interfaz y hacía parecer que el
        botón no funcionaba. Las direcciones elegidas de la lista ya conservan
        sus coordenadas; las demás se pueden marcar directamente en el mapa.
        """
        self.map_route_edit_target = edit_target
        label = "partida" if edit_target == "origin" else "llegada"
        try:
            self.open_map("route")
            self._bring_map_to_front()
            if not self.route_selected_locations.get(edit_target):
                self.map_info_text.set(
                    f"Editando {label}: hacé clic en el punto exacto del mapa. "
                    "El mapa se abrió sin esperar búsquedas externas."
                )
        except Exception as exc:
            # Un callback de Tk que falla puede parecer un botón inactivo.
            # Limpiamos la referencia y explicamos el problema al usuario.
            self.map_window = None
            self.map_canvas = None
            self.map_images = []
            messagebox.showerror(
                "Mapa de recorrido",
                f"No se pudo abrir el mapa para editar la {label}.\n\n"
                f"{type(exc).__name__}: {exc}",
            )

    def _switch_route_map_target(self, target: str) -> None:
        self.map_route_edit_target = target
        label = "partida" if target == "origin" else "llegada"
        saved = self.route_selected_locations.get(target)
        suffix = " El punto actual sigue guardado hasta que elijas otro." if saved else ""
        self.map_info_text.set(f"Editando {label}: hacé clic en el mapa para cambiarla.{suffix}")

    def _route_map_done(self) -> None:
        if not self.route_selected_locations.get("origin") or not self.route_selected_locations.get("destination"):
            messagebox.showinfo("Simular recorrido", "Marcá la partida y la llegada antes de cerrar el mapa.")
            return
        self.route_info_text.set("Partida y llegada guardadas. Podés corregir cualquiera o iniciar el recorrido.")
        self._close_map()

    def _fit_map_to_markers(self, first: tuple[float, float], second: tuple[float, float]) -> None:
        """Centra y aleja el mapa lo necesario para que entren partida y llegada."""
        self.map_center = ((first[0] + second[0]) / 2.0, (first[1] + second[1]) / 2.0)
        for zoom in range(18, 2, -1):
            ax, ay = self._world_pixels(first[0], first[1], zoom)
            bx, by = self._world_pixels(second[0], second[1], zoom)
            if abs(ax - bx) <= 620 and abs(ay - by) <= 360:
                self.map_zoom = zoom
                return
        self.map_zoom = 3

    def _map_window_exists(self) -> bool:
        """Comprueba la ventana sin dejar una referencia inválida de Tk."""
        if self.map_window is None:
            return False
        try:
            return bool(self.map_window.winfo_exists())
        except tk.TclError:
            self.map_window = None
            self.map_canvas = None
            self.map_images = []
            return False

    def _release_map_topmost(self, window: tk.Toplevel) -> None:
        try:
            if self.map_window is window and window.winfo_exists():
                window.attributes("-topmost", False)
        except tk.TclError:
            pass

    def _bring_map_to_front(self) -> None:
        """Restaura el mapa y lo muestra delante de la ventana principal."""
        window = self.map_window
        if window is None:
            return
        try:
            window.deiconify()
            window.state("normal")
            window.lift()
            window.attributes("-topmost", True)
            window.focus_force()
            window.after(180, lambda current=window: self._release_map_topmost(current))
        except tk.TclError:
            self.map_window = None
            self.map_canvas = None
            self.map_images = []

    def open_map(self, target: str = "main") -> None:
        if self._map_window_exists():
            if self.map_target == target:
                self._bring_map_to_front()
                return
            self._close_map()
        self.map_target = target
        selected = self.route_selected_locations.get(target) if target in ("origin", "destination") else None
        origin_selected = self.route_selected_locations.get("origin")
        self.map_reference_marker = None
        try:
            if target == "route" and origin_selected is not None:
                self.map_center = (float(origin_selected["lat"]), float(origin_selected["lon"]))
            elif selected is not None:
                self.map_center = (float(selected["lat"]), float(selected["lon"]))
            elif target == "destination" and origin_selected is not None:
                self.map_center = (float(origin_selected["lat"]), float(origin_selected["lon"]))
            else:
                self.map_center = (float(self.latitude.get()), float(self.longitude.get()))
        except (ValueError, KeyError, TypeError):
            self.map_center = (-34.6037, -58.3816)
        self.map_marker = None
        if selected is not None:
            self.map_marker = self.map_center
        elif target == "main":
            self.map_marker = self.map_center
        if target == "destination" and origin_selected is not None:
            try:
                self.map_reference_marker = (float(origin_selected["lat"]), float(origin_selected["lon"]))
            except (ValueError, KeyError, TypeError):
                self.map_reference_marker = None
        if target == "destination" and self.map_reference_marker is not None and self.map_marker is not None:
            self._fit_map_to_markers(self.map_reference_marker, self.map_marker)
        if target == "route":
            destination_selected = self.route_selected_locations.get("destination")
            if origin_selected and destination_selected:
                self._fit_map_to_markers(
                    (float(origin_selected["lat"]), float(origin_selected["lon"])),
                    (float(destination_selected["lat"]), float(destination_selected["lon"])),
                )
            self.map_selected_address = ""
            map_title = "Partida y llegada en el mismo mapa"
        elif target == "origin":
            self.map_selected_address = self.route_origin_address.get().strip()
            map_title = "Elegí la dirección de partida"
        elif target == "destination":
            self.map_selected_address = self.route_destination_address.get().strip()
            map_title = "Elegí la dirección de llegada"
        else:
            self.map_selected_address = self.address.get().strip()
            self.map_selected_short = ""
            map_title = "Elegí el punto exacto"
        win = tk.Toplevel(self.root)
        self.map_window = win
        win.title("Ojo GPS - Elegir ubicación en el mapa")
        win.transient(self.root)
        screen_width = win.winfo_screenwidth()
        screen_height = win.winfo_screenheight()
        window_width = max(560, min(900, screen_width - 70))
        window_height = max(500, min(760, screen_height - 90))
        pos_x = max(0, (screen_width - window_width) // 2)
        pos_y = max(0, (screen_height - window_height) // 2)
        win.geometry(f"{window_width}x{window_height}+{pos_x}+{pos_y}")
        win.minsize(min(620, window_width), min(500, window_height))
        win.protocol("WM_DELETE_WINDOW", self._close_map)
        head = ttk.Frame(win, padding=(18, 15))
        head.pack(fill="x")
        ttk.Label(head, text=map_title, style="Section.TLabel").pack(side="left")
        ttk.Button(head, text="−", command=lambda: self._change_map_zoom(-1)).pack(side="right", padx=(5, 0))
        ttk.Button(head, text="+", command=lambda: self._change_map_zoom(1)).pack(side="right")
        ttk.Label(
            win,
            text=(
                "Los dos puntos quedan guardados. Elegí cuál querés corregir y hacé clic en el mapa."
                if target == "route"
                else
                "El punto azul P es la partida. Hacé clic para marcar la llegada en rojo."
                if target == "destination" and self.map_reference_marker is not None
                else "Arrastrá el mapa con el mouse o el dedo. Hacé clic para elegir un punto. Usá la rueda o +/− para el zoom."
            ),
        ).pack(anchor="w", padx=18)
        if target == "route":
            edit_row = ttk.Frame(win, padding=(18, 8, 18, 0))
            edit_row.pack(fill="x")
            ttk.Button(
                edit_row, text="Editar partida (P)",
                command=lambda: self._switch_route_map_target("origin"),
            ).pack(side="left", fill="x", expand=True, padx=(0, 5))
            ttk.Button(
                edit_row, text="Editar llegada (L)",
                command=lambda: self._switch_route_map_target("destination"),
            ).pack(side="left", fill="x", expand=True, padx=(5, 0))
        self.map_canvas = tk.Canvas(win, width=768, height=512, bg="#dbe7e5", highlightthickness=1, highlightbackground="#b9cfcc")
        self.map_canvas.pack(fill="both", expand=True, padx=18, pady=12)
        self.map_canvas.bind("<ButtonPress-1>", self._map_drag_begin)
        self.map_canvas.bind("<B1-Motion>", self._map_drag_move)
        self.map_canvas.bind("<ButtonRelease-1>", self._map_drag_end)
        self.map_canvas.bind("<MouseWheel>", self._map_mousewheel)
        self.map_canvas.bind("<Button-4>", lambda _event: self._change_map_zoom(1))
        self.map_canvas.bind("<Button-5>", lambda _event: self._change_map_zoom(-1))
        # El evento recibido por Tk cambia según el teclado y según si se usa
        # el bloque numérico. Escuchamos la tecla en la ventana completa para
        # que el zoom funcione aunque el usuario haya hecho clic en un botón.
        win.bind("<KeyPress>", self._map_keypress)
        self.map_canvas.configure(takefocus=True)
        self.map_canvas.focus_set()
        ttk.Label(win, textvariable=self.map_info_text).pack(anchor="w", padx=18, pady=(0, 8))
        actions = ttk.Frame(win, padding=(18, 0, 18, 16))
        actions.pack(fill="x")
        ttk.Button(actions, text="Cancelar", command=self._close_map).pack(side="right")
        if target == "route":
            ttk.Button(actions, text="Listo", style="Primary.TButton", command=self._route_map_done).pack(side="right", padx=(0, 10))
        else:
            ttk.Button(actions, text="Usar esta ubicación", style="Primary.TButton", command=self._use_map_location).pack(side="right", padx=(0, 10))
        ttk.Button(actions, text="Ver Street View", command=self._open_street_view_from_map).pack(side="left")
        # Esperamos a que Tk conozca el tamaño definitivo y cargamos una sola vez.
        self.map_render_job = win.after(80, self._render_map)
        win.after_idle(self._bring_map_to_front)

    def _close_map(self) -> None:
        if self.map_render_job is not None and self.map_window is not None:
            try:
                self.map_window.after_cancel(self.map_render_job)
            except tk.TclError:
                pass
        self.map_render_job = None
        if self.map_window is not None:
            try:
                self.map_window.destroy()
            except tk.TclError:
                pass
        self.map_window = None
        self.map_canvas = None
        self.map_images = []

    def _change_map_zoom(self, delta: int) -> None:
        self.map_zoom = max(3, min(19, self.map_zoom + delta))
        self.map_info_text.set(f"Zoom {self.map_zoom}: cargando mapa…")
        self._schedule_map_render(220)

    def _schedule_map_render(self, delay: int = 160) -> None:
        """Agrupa varios movimientos o pulsaciones de zoom en una sola carga."""
        if self.map_window is None:
            return
        if self.map_render_job is not None:
            try:
                self.map_window.after_cancel(self.map_render_job)
            except tk.TclError:
                pass
        self.map_render_job = self.map_window.after(delay, self._render_map)

    def _map_mousewheel(self, event) -> str:
        self._change_map_zoom(1 if event.delta > 0 else -1)
        return "break"

    def _map_keypress(self, event) -> str | None:
        """Acerca o aleja con +/− del teclado principal o numérico."""
        key = str(getattr(event, "keysym", ""))
        char = str(getattr(event, "char", ""))
        if key in ("plus", "KP_Add") or char in ("+", "="):
            self._change_map_zoom(1)
            return "break"
        if key in ("minus", "KP_Subtract") or char in ("-", "_"):
            self._change_map_zoom(-1)
            return "break"
        return None

    def _map_drag_begin(self, event) -> None:
        self.map_drag_start = (event.x, event.y)
        self.map_drag_last = (event.x, event.y)
        self.map_drag_center = self.map_center
        self.map_dragging = False
        if self.map_canvas is not None:
            self.map_canvas.configure(cursor="fleur")

    def _map_drag_move(self, event) -> None:
        if self.map_drag_start is None or self.map_drag_last is None or self.map_drag_center is None:
            return
        dx = event.x - self.map_drag_start[0]
        dy = event.y - self.map_drag_start[1]
        if abs(dx) + abs(dy) < 5:
            return
        self.map_dragging = True
        cx, cy = self._world_pixels(self.map_drag_center[0], self.map_drag_center[1], self.map_zoom)
        self.map_center = self._latlon_from_world(cx - dx, cy - dy, self.map_zoom)
        if self.map_canvas is not None:
            step_x = event.x - self.map_drag_last[0]
            step_y = event.y - self.map_drag_last[1]
            self.map_canvas.move("all", step_x, step_y)
        self.map_drag_last = (event.x, event.y)

    def _map_drag_end(self, event) -> None:
        if self.map_canvas is not None:
            self.map_canvas.configure(cursor="arrow")
        was_dragging = self.map_dragging
        self.map_drag_start = None
        self.map_drag_last = None
        self.map_drag_center = None
        self.map_dragging = False
        if was_dragging:
            self.map_info_text.set("Mapa desplazado. Hacé clic en el punto que querés elegir.")
            self._schedule_map_render(120)
        else:
            self._map_click(event)

    def _render_map(self) -> None:
        self.map_render_job = None
        if self.map_canvas is None:
            return
        self.map_canvas.delete("all")
        self.map_canvas.create_text(384, 245, text="Cargando mapa…", fill=GREEN_DARK, font=ui_font(13, semibold=True))
        self.map_render_id += 1
        request_id = self.map_render_id
        width = max(640, self.map_canvas.winfo_width() or 768)
        height = max(420, self.map_canvas.winfo_height() or 512)
        threading.Thread(target=self._map_tiles_worker, args=(request_id, self.map_center, self.map_zoom, width, height), daemon=True).start()

    def _load_map_tile(self, zoom: int, tile_x: int, tile_y: int) -> str:
        cache_key = (zoom, tile_x, tile_y)
        with self.map_tile_cache_lock:
            data = self.map_tile_cache.get(cache_key)
        if data is not None:
            return data
        cache_file = self.map_cache_dir / str(zoom) / str(tile_x) / f"{tile_y}.png"
        try:
            raw = cache_file.read_bytes()
        except OSError:
            url = f"https://tile.openstreetmap.org/{zoom}/{tile_x}/{tile_y}.png"
            req = urllib.request.Request(url, headers={"User-Agent": "OjoGPS-Windows/16.4.32"})
            with urllib.request.urlopen(req, timeout=8) as response:
                raw = response.read()
            try:
                cache_file.parent.mkdir(parents=True, exist_ok=True)
                cache_file.write_bytes(raw)
            except OSError:
                pass
        data = base64.b64encode(raw).decode("ascii")
        with self.map_tile_cache_lock:
            self.map_tile_cache[cache_key] = data
            while len(self.map_tile_cache) > 300:
                self.map_tile_cache.pop(next(iter(self.map_tile_cache)))
        return data

    def _map_tiles_worker(self, request_id: int, center: tuple[float, float], zoom: int, width: int, height: int) -> None:
        try:
            cx, cy = self._world_pixels(center[0], center[1], zoom)
            first_x = math.floor((cx - width / 2) / 256)
            last_x = math.floor((cx + width / 2) / 256)
            first_y = math.floor((cy - height / 2) / 256)
            last_y = math.floor((cy + height / 2) / 256)
            tiles = []
            needed = []
            limit = 2 ** zoom
            for ty in range(first_y, last_y + 1):
                for tx in range(first_x, last_x + 1):
                    if request_id != self.map_render_id:
                        return
                    if not 0 <= ty < limit:
                        continue
                    tile_x = tx % limit
                    needed.append((tx, ty, tile_x))
            with ThreadPoolExecutor(max_workers=4) as executor:
                futures = {
                    executor.submit(self._load_map_tile, zoom, tile_x, ty): (tx, ty)
                    for tx, ty, tile_x in needed
                }
                for future in as_completed(futures):
                    if request_id != self.map_render_id:
                        return
                    tx, ty = futures[future]
                    try:
                        tile_data = future.result()
                    except Exception:
                        continue
                    tiles.append({
                        "x": tx * 256 - (cx - width / 2),
                        "y": ty * 256 - (cy - height / 2),
                        "data": tile_data,
                    })
            if request_id != self.map_render_id:
                return
            payload = {"id": request_id, "zoom": zoom, "width": width, "height": height, "center": center, "tiles": tiles}
            self.events.put(("MAP_TILES", json.dumps(payload)))
        except Exception as exc:
            if request_id == self.map_render_id:
                self.events.put(("MAP_ERROR", str(exc)))

    def _map_click(self, event) -> None:
        if self.map_canvas is None:
            return
        width = self.map_canvas.winfo_width()
        height = self.map_canvas.winfo_height()
        cx, cy = self._world_pixels(self.map_center[0], self.map_center[1], self.map_zoom)
        lat, lon = self._latlon_from_world(cx - width / 2 + event.x, cy - height / 2 + event.y, self.map_zoom)
        if self.map_target == "route":
            field = self.map_route_edit_target
            temporary = f"Punto elegido ({lat:.5f}, {lon:.5f})"
            self.route_selected_locations[field] = {
                "lat": str(lat),
                "lon": str(lon),
                "display_name": temporary,
            }
            variable, listbox = self._route_widgets(field)
            variable.set(temporary)
            listbox.delete(0, tk.END)
            label = "Partida" if field == "origin" else "Llegada"
            self.map_info_text.set(f"{label} guardada. Buscando el nombre de la dirección…")
            if field == "origin":
                self.map_reference_marker = (lat, lon)
                self._draw_map_reference_marker(event.x, event.y)
            else:
                self.map_marker = (lat, lon)
                self._draw_map_marker(event.x, event.y)
            threading.Thread(
                target=self._reverse_worker,
                args=(lat, lon, True, field),
                daemon=True,
            ).start()
            return
        self.map_marker = (lat, lon)
        self._draw_map_marker(event.x, event.y)
        self.map_selected_address = ""
        self.map_selected_short = ""
        self.map_selected_address_details = {}
        self.map_info_text.set("Buscando la dirección del punto elegido…")
        threading.Thread(target=self._reverse_worker, args=(lat, lon, True), daemon=True).start()

    def _draw_map_marker(self, x: float, y: float) -> None:
        if self.map_canvas is None:
            return
        self.map_canvas.delete("marker")
        self.map_canvas.create_oval(x - 10, y - 10, x + 10, y + 10, fill="#e24b3b", outline="white", width=3, tags="marker")
        self.map_canvas.create_line(x, y + 8, x, y + 21, fill="#e24b3b", width=4, tags="marker")
        if self.map_target in ("destination", "route"):
            self.map_canvas.create_text(x, y - 1, text="L", fill="white", font=ui_font(8, semibold=True), tags="marker")

    def _draw_map_reference_marker(self, x: float, y: float) -> None:
        """Dibuja la partida sin confundirla con la llegada que se está eligiendo."""
        if self.map_canvas is None:
            return
        self.map_canvas.delete("reference_marker")
        self.map_canvas.create_oval(
            x - 11,
            y - 11,
            x + 11,
            y + 11,
            fill="#2878c8",
            outline="white",
            width=3,
            tags="reference_marker",
        )
        self.map_canvas.create_line(x, y + 9, x, y + 23, fill="#2878c8", width=4, tags="reference_marker")
        self.map_canvas.create_text(
            x,
            y - 1,
            text="P",
            fill="white",
            font=ui_font(9, semibold=True),
            tags="reference_marker",
        )

    def _use_map_location(self) -> None:
        if self.map_marker is None:
            messagebox.showinfo("Ojo GPS", "Primero hacé clic en el mapa para marcar una ubicación.")
            return
        lat, lon = self.map_marker
        chosen_address = self.map_selected_address or "Punto elegido en el mapa"
        if self.map_target in ("origin", "destination"):
            field = self.map_target
            variable, listbox = self._route_widgets(field)
            variable.set(chosen_address)
            self.route_selected_locations[field] = {
                "lat": str(lat),
                "lon": str(lon),
                "display_name": chosen_address,
                "address": self.map_selected_address_details,
            }
            self.route_suggestion_ids[field] += 1
            listbox.delete(0, tk.END)
            label = "Partida" if field == "origin" else "Llegada"
            self.route_info_text.set(f"{label} elegida en el mapa. Completá la otra dirección.")
            self._close_map()
            if field == "origin":
                self.route_destination_entry.focus_set()
            return
        self.latitude.set(f"{lat:.7f}")
        self.longitude.set(f"{lon:.7f}")
        if self.map_selected_address:
            self.address.set(self.map_selected_address)
            self.selected_name.set(self.map_selected_short or self.map_selected_address.split(",")[0])
        else:
            self.address.set(chosen_address)
            self.selected_name.set(chosen_address)
        self._request_place_context(lat, lon)
        self.set_status("Destino elegido en el mapa", GREEN)
        self._close_map()

    def _current_map_point(self) -> tuple[float, float] | None:
        """Coordenadas del punto activo en la ventana del mapa, según el target."""
        if self.map_target == "route":
            saved = self.route_selected_locations.get(self.map_route_edit_target)
            if not saved:
                return None
            try:
                return (float(saved["lat"]), float(saved["lon"]))
            except (KeyError, TypeError, ValueError):
                return None
        return self.map_marker

    def _open_street_view_from_map(self) -> None:
        point = self._current_map_point()
        if point is None:
            messagebox.showinfo("Street View", "Primero elegí un punto en el mapa.")
            return
        self.open_street_view(*point)

    def _open_street_view_from_main(self) -> None:
        try:
            lat = float(self.latitude.get())
            lon = float(self.longitude.get())
        except ValueError:
            messagebox.showinfo("Street View", "Primero elegí un destino.")
            return
        self.open_street_view(lat, lon)

    @staticmethod
    def _load_mapillary_token() -> str:
        try:
            token = MAPILLARY_TOKEN_FILE.read_text(encoding="utf-8").strip()
            if token:
                return token
        except (OSError, UnicodeDecodeError):
            pass
        return MAPILLARY_TOKEN_DEFAULT

    def _street_view_window_exists(self) -> bool:
        if self.street_view_window is None:
            return False
        try:
            return bool(self.street_view_window.winfo_exists())
        except tk.TclError:
            self.street_view_window = None
            self.street_view_canvas = None
            return False

    def _bring_street_view_to_front(self) -> None:
        window = self.street_view_window
        if window is None:
            return
        try:
            window.lift()
            window.focus_force()
        except tk.TclError:
            pass

    def open_street_view(self, lat: float, lon: float) -> None:
        """Abre una vista de calle cercana al punto, sin bloquear el resto de Ojo GPS."""
        if not PIL_AVAILABLE:
            messagebox.showerror(
                "Street View",
                "Falta el paquete Pillow, necesario para mostrar fotos.\n\n"
                f"Volvé a ejecutar {INSTALLER_SCRIPT_NAME} para instalarlo y probá de nuevo.",
            )
            return
        token = self._load_mapillary_token()
        if self._street_view_window_exists():
            try:
                self.street_view_window.destroy()
            except tk.TclError:
                pass
        self.street_view_request_id += 1
        request_id = self.street_view_request_id
        win = tk.Toplevel(self.root)
        self.street_view_window = win
        win.title("Ojo GPS - Street View")
        win.transient(self.root)
        width, height = STREET_VIEW_MAX_SIZE[0] + 40, STREET_VIEW_MAX_SIZE[1] + 110
        win.geometry(f"{width}x{height}")
        win.minsize(420, 360)
        win.protocol("WM_DELETE_WINDOW", self._close_street_view)
        ttk.Label(
            win,
            text="Vista de calle cerca del punto elegido (opcional)",
            style="Section.TLabel",
            padding=(18, 14, 18, 4),
        ).pack(anchor="w")
        canvas = tk.Canvas(win, bg="#0e211f", highlightthickness=0)
        canvas.pack(fill="both", expand=True, padx=18, pady=(0, 10))
        self.street_view_canvas = canvas
        canvas.create_text(
            STREET_VIEW_MAX_SIZE[0] / 2, STREET_VIEW_MAX_SIZE[1] / 2,
            text="Buscando vista de calle…", fill="white",
            font=ui_font(12, semibold=True), tags="status",
        )
        actions = ttk.Frame(win, padding=(18, 0, 18, 16))
        actions.pack(fill="x")
        ttk.Button(actions, text="Cerrar", command=self._close_street_view).pack(side="right")
        win.after_idle(self._bring_street_view_to_front)
        threading.Thread(
            target=self._street_view_worker, args=(request_id, lat, lon, token), daemon=True,
        ).start()

    def _close_street_view(self) -> None:
        self.street_view_request_id += 1  # invalida cualquier respuesta en camino
        if self.street_view_window is not None:
            try:
                self.street_view_window.destroy()
            except tk.TclError:
                pass
        self.street_view_window = None
        self.street_view_canvas = None
        self.street_view_photo = None

    @staticmethod
    def _fit_size(width: int, height: int, max_width: int, max_height: int) -> tuple[int, int]:
        scale = min(max_width / width, max_height / height, 1.0)
        return max(1, round(width * scale)), max(1, round(height * scale))

    def _street_view_worker(self, request_id: int, lat: float, lon: float, token: str) -> None:
        try:
            search_params = urllib.parse.urlencode({
                "access_token": token,
                "fields": "id,geometry,compass_angle",
                "lat": lat,
                "lng": lon,
                "radius": 50,
                "limit": 20,
            })
            search_req = urllib.request.Request(
                f"{MAPILLARY_API}/images?" + search_params,
                headers={"User-Agent": "OjoGPS-Windows/16.4.32"},
            )
            with urllib.request.urlopen(search_req, timeout=12) as response:
                found = json.loads(response.read().decode("utf-8")).get("data", [])
            if request_id != self.street_view_request_id:
                return
            if not found:
                self.events.put(("STREET_VIEW_EMPTY", json.dumps({"id": request_id})))
                return

            def _photo_score(entry: dict) -> float:
                coords = (entry.get("geometry") or {}).get("coordinates") or [lon, lat]
                camera_pos = (coords[1], coords[0])
                distance = self._distance_m((lat, lon), camera_pos)
                compass = entry.get("compass_angle")
                if compass is None:
                    return distance + 90.0
                bearing_to_target = self._bearing_deg(camera_pos, (lat, lon))
                return self._angle_diff_deg(compass, bearing_to_target) + distance

            found.sort(key=_photo_score)
            image_id = found[0]["id"]
            cache_file = self.street_view_cache_dir / f"{image_id}.jpg"
            try:
                raw = cache_file.read_bytes()
            except OSError:
                detail_params = urllib.parse.urlencode({"access_token": token, "fields": "thumb_1024_url"})
                detail_req = urllib.request.Request(
                    f"{MAPILLARY_API}/{image_id}?" + detail_params,
                    headers={"User-Agent": "OjoGPS-Windows/16.4.32"},
                )
                with urllib.request.urlopen(detail_req, timeout=12) as response:
                    photo_url = json.loads(response.read().decode("utf-8")).get("thumb_1024_url")
                if not photo_url:
                    self.events.put(("STREET_VIEW_EMPTY", json.dumps({"id": request_id})))
                    return
                img_req = urllib.request.Request(photo_url, headers={"User-Agent": "OjoGPS-Windows/16.4.32"})
                with urllib.request.urlopen(img_req, timeout=15) as response:
                    raw = response.read()
                try:
                    cache_file.write_bytes(raw)
                except OSError:
                    pass
            if request_id != self.street_view_request_id:
                return
            image = Image.open(io.BytesIO(raw)).convert("RGB")
            target_w, target_h = self._fit_size(image.width, image.height, *STREET_VIEW_MAX_SIZE)
            image = image.resize((target_w, target_h), Image.LANCZOS)
            png_buffer = io.BytesIO()
            image.save(png_buffer, format="PNG")
            self.events.put(("STREET_VIEW_OK", json.dumps({
                "id": request_id,
                "data": base64.b64encode(png_buffer.getvalue()).decode("ascii"),
            })))
        except urllib.error.HTTPError as exc:
            if request_id == self.street_view_request_id:
                if exc.code in (400, 401, 403):
                    self.events.put(("STREET_VIEW_AUTH_ERROR", json.dumps({"id": request_id})))
                else:
                    message = f"El servidor de Street View respondió con un error ({exc.code})."
                    self.events.put(("STREET_VIEW_ERROR", json.dumps({"id": request_id, "message": message})))
        except Exception as exc:
            if request_id == self.street_view_request_id:
                self.events.put(("STREET_VIEW_ERROR", json.dumps({"id": request_id, "message": str(exc)})))

    def _reverse_worker(
        self,
        lat: float,
        lon: float,
        for_map: bool = False,
        route_field: str | None = None,
    ) -> None:
        try:
            params = urllib.parse.urlencode({"format": "jsonv2", "lat": lat, "lon": lon, "accept-language": "es", "addressdetails": 1})
            req = urllib.request.Request("https://nominatim.openstreetmap.org/reverse?" + params, headers={"User-Agent": "OjoGPS-Windows/16.4.32"})
            with urllib.request.urlopen(req, timeout=20) as response:
                item = json.loads(response.read().decode("utf-8"))
            item["lat"] = str(lat)
            item["lon"] = str(lon)
            if route_field:
                item["_route_field"] = route_field
            self.events.put(("MAP_REVERSE" if for_map else "PLACE_REVERSE", json.dumps(item)))
        except Exception:
            if for_map:
                fallback = {"lat": lat, "lon": lon, "display_name": "Punto elegido en el mapa", "address": {}}
                if route_field:
                    fallback["_route_field"] = route_field
                self.events.put(("MAP_REVERSE", json.dumps(fallback)))

    def _request_place_context(self, lat: float, lon: float, item: dict | None = None) -> None:
        if item is None or not item.get("address"):
            threading.Thread(target=self._reverse_worker, args=(lat, lon, False), daemon=True).start()
            return
        threading.Thread(target=self._place_context_worker, args=(lat, lon, item), daemon=True).start()

    def _place_context_worker(self, lat: float, lon: float, item: dict) -> None:
        address = item.get("address") or {}
        locality = address.get("suburb") or address.get("neighbourhood") or address.get("quarter")
        city = address.get("city") or address.get("town") or address.get("village") or address.get("municipality")
        country = address.get("country")
        parts = []
        for value in (locality, city, country):
            if value and value not in parts:
                parts.append(value)
        location_text = " · ".join(parts) if parts else "Punto elegido"
        timezone_name = ""
        fallback_hour = None
        fallback_minute = None
        try:
            params = urllib.parse.urlencode({"latitude": lat, "longitude": lon})
            req = urllib.request.Request("https://timeapi.io/api/time/current/coordinate?" + params, headers={"User-Agent": "OjoGPS-Windows/16.4.32"})
            with urllib.request.urlopen(req, timeout=10) as response:
                clock = json.loads(response.read().decode("utf-8"))
            timezone_name = str(clock.get("timeZone") or "")
            fallback_hour = int(clock.get("hour"))
            fallback_minute = int(clock.get("minute"))
        except Exception:
            pass
        self.events.put(("PLACE_CONTEXT", json.dumps({
            "location": location_text,
            "timezone": timezone_name,
            "fallback_hour": fallback_hour,
            "fallback_minute": fallback_minute,
        })))

    def _refresh_place_clock(self) -> None:
        if self.place_clock_job is not None:
            try:
                self.root.after_cancel(self.place_clock_job)
            except tk.TclError:
                pass
            self.place_clock_job = None
        try:
            now = datetime.now(ZoneInfo(self.place_timezone))
            phase = "☀ Día" if 7 <= now.hour < 19 else "🌙 Noche"
            self.place_info_text.set(
                f"Zona: {self.place_location_text}  |  Hora local: {now:%H:%M}  |  {phase}"
            )
        except Exception:
            self.place_info_text.set(
                f"Zona: {self.place_location_text}  |  Hora local: no disponible"
            )
        self.place_clock_job = self.root.after(1000, self._refresh_place_clock)

    def activate(self) -> None:
        if self.bridge is not None:
            messagebox.showinfo("Ojo GPS", "Ya hay una ubicación activa.")
            return
        coords = self._read_coords()
        if coords is None:
            return
        lat, lon = coords

        self.fixed = False
        self.current_operation = "maintain"
        self.activate_button.configure(state="disabled")
        self.joystick_button.configure(state="disabled")
        self.route_button.configure(state="disabled")
        self.fix_button.configure(state="disabled")
        self.search_button.configure(state="disabled")
        self.current_coords = (lat, lon)
        self.current_mode = self.connection_mode.get()
        self.set_connection("CONECTANDO", "#d59b2b")
        if self.current_mode == "wifi":
            self.set_status("Buscando el iPhone por Wi-Fi...", "#d59b2b")
        else:
            self.set_status("Conectando con el iPhone por cable...", "#d59b2b")
        threading.Thread(target=self._start_bridge, args=(self.current_mode, "maintain", lat, lon), daemon=True).start()

    def _read_coords(self) -> tuple[float, float] | None:
        try:
            lat = float(self.latitude.get().replace(",", "."))
            lon = float(self.longitude.get().replace(",", "."))
            if not -90 <= lat <= 90 or not -180 <= lon <= 180:
                raise ValueError
        except ValueError:
            messagebox.showerror("Ojo GPS", "Revisá la latitud y la longitud.")
            return None
        return lat, lon

    def fix_location(self) -> None:
        if self.active and self.bridge is not None and self.bridge.stdin is not None:
            self._stop_route(close_window=True)
            self._close_joystick()
            self.joystick_button.configure(state="disabled")
            self.route_button.configure(state="disabled")
            self.current_operation = "freeze"
            self.fix_button.configure(state="disabled")
            self.set_connection("ESPERANDO", "#d59b2b")
            self.set_status("Desactivá en tu dispositivo el Modo de desarrollador", "#d59b2b")
            self.footer_text.set("FIJAR GPS: desactivá Modo de desarrollador, pero NO desconectes el cable hasta ver el indicador verde.")
            self._open_fix_tutorial()
            return

        messagebox.showinfo(
            "Fijar GPS",
            "Primero conectá el iPhone por cable, pulsá Cambiar ubicación y esperá el indicador verde.\n\n"
            "Después pulsá Fijar GPS.",
        )

    def _open_fix_tutorial(self) -> None:
        if self.fix_help_window is not None and self.fix_help_window.winfo_exists():
            self.fix_help_window.lift()
            self.fix_help_window.focus_force()
            return

        window = tk.Toplevel(self.root)
        self.fix_help_window = window
        window.title("Ojo GPS - Cómo fijar el GPS")
        window.geometry("610x540")
        window.resizable(False, False)
        window.configure(bg="white")
        window.protocol("WM_DELETE_WINDOW", self._close_fix_tutorial)

        header = tk.Frame(window, bg="white", padx=22, pady=16)
        header.pack(fill="x")
        tk.Label(
            header,
            text="Cómo fijar el GPS",
            bg="white",
            fg=GREEN_DARK,
            font=ui_font(20, semibold=True),
        ).pack(side="left")
        tk.Button(
            header,
            text="×",
            command=self._close_fix_tutorial,
            bg="white",
            fg=MUTED,
            activebackground="#eef5f4",
            relief="flat",
            bd=0,
            font=ui_font(18),
            cursor="hand2",
        ).pack(side="right")

        tk.Label(
            window,
            text="Paso final · La ubicación ya debe estar activa en verde · Solo para iPhone",
            bg="white",
            fg=MUTED,
            font=ui_font(10),
        ).pack(anchor="w", padx=24)

        canvas = tk.Canvas(window, width=560, height=150, bg="#f7fbfa", highlightthickness=0)
        canvas.pack(padx=24, pady=(14, 10))
        self.fix_help_canvas = canvas

        # iPhone, cable y PC: la animación cambia su estado, pero no toca el GPS.
        canvas.create_rectangle(55, 20, 145, 135, width=3, outline=GREEN_DARK, tags="phone")
        canvas.create_rectangle(70, 42, 130, 96, fill="white", outline="#cbdad8")
        canvas.create_text(100, 112, text="iPhone", fill=TEXT, font=ui_font(10, semibold=True))
        canvas.create_line(145, 78, 365, 78, width=7, fill=GREEN, tags="cable")
        canvas.create_rectangle(365, 36, 505, 123, width=3, outline=GREEN_DARK, tags="pc")
        canvas.create_text(435, 80, text="Ojo GPS", fill=GREEN_DARK, font=ui_font(15, semibold=True))
        canvas.create_text(100, 67, text="CONECTADO", fill=GREEN, font=ui_font(9, semibold=True), tags="phone_state")
        canvas.create_oval(420, 18, 450, 48, fill="#d59b2b", outline="", tags="signal")

        steps_frame = tk.Frame(window, bg="white")
        steps_frame.pack(fill="x", padx=24)
        texts = [
            "Mantené el iPhone conectado y desbloqueado.",
            "Desactivá en tu dispositivo el Modo de desarrollador.",
            "Esperá la confirmación de Ojo GPS.",
            "Cuando el indicador esté verde, desconectá el cable.",
        ]
        self.fix_help_step_labels = []
        for number, text in enumerate(texts, start=1):
            label = tk.Label(
                steps_frame,
                text=f"{number}.  {text}",
                anchor="w",
                justify="left",
                bg="white",
                fg=MUTED,
                padx=12,
                pady=8,
                font=ui_font(10),
            )
            label.pack(fill="x", pady=2)
            self.fix_help_step_labels.append(label)

        footer = tk.Frame(window, bg="white", padx=24, pady=14)
        footer.pack(fill="x")
        tk.Label(
            footer,
            text="La ubicación quedará fija aunque cambies de red.",
            bg="white",
            fg=GREEN_DARK,
            font=ui_font(10, semibold=True),
        ).pack(side="left")
        tk.Button(
            footer,
            text="Omitir  ×",
            command=self._close_fix_tutorial,
            bg="white",
            fg=MUTED,
            activebackground="#eef5f4",
            relief="flat",
            bd=0,
            font=ui_font(9),
            cursor="hand2",
        ).pack(side="right")

        self.fix_help_frame = 0
        self._animate_fix_tutorial()

    def _animate_fix_tutorial(self) -> None:
        if self.fix_help_window is None or not self.fix_help_window.winfo_exists():
            self.fix_help_job = None
            return
        if self.fix_help_canvas is None:
            return

        step = self.fix_help_frame % 4
        for index, label in enumerate(self.fix_help_step_labels):
            if index == step:
                label.configure(bg="#e5f3f1", fg=GREEN_DARK, font=ui_font(10, semibold=True))
            else:
                label.configure(bg="white", fg=MUTED, font=ui_font(10))

        canvas = self.fix_help_canvas
        if step == 0:
            canvas.itemconfigure("cable", fill=GREEN, dash=())
            canvas.itemconfigure("phone_state", text="CONECTADO", fill=GREEN)
            canvas.itemconfigure("signal", fill="#d59b2b")
        elif step == 1:
            canvas.itemconfigure("cable", fill=GREEN, dash=())
            canvas.itemconfigure("phone_state", text="DESACTIVAR", fill="#c45a4a")
            canvas.itemconfigure("signal", fill="#d59b2b")
        elif step == 2:
            canvas.itemconfigure("cable", fill=GREEN, dash=())
            canvas.itemconfigure("phone_state", text="ESPERANDO", fill="#d59b2b")
            canvas.itemconfigure("signal", fill="#d59b2b")
        else:
            canvas.itemconfigure("cable", fill="#a9b8b6", dash=(8, 6))
            canvas.itemconfigure("phone_state", text="YA PODÉS RETIRAR", fill=GREEN_DARK)
            canvas.itemconfigure("signal", fill=GREEN)

        self.fix_help_frame += 1
        self.fix_help_job = self.root.after(2800, self._animate_fix_tutorial)

    def _close_fix_tutorial(self) -> None:
        if self.fix_help_job is not None:
            try:
                self.root.after_cancel(self.fix_help_job)
            except tk.TclError:
                pass
            self.fix_help_job = None
        if self.fix_help_window is not None:
            try:
                self.fix_help_window.destroy()
            except tk.TclError:
                pass
        self.fix_help_window = None
        self.fix_help_canvas = None
        self.fix_help_step_labels = []

    def open_route(self) -> None:
        if not self.active or self.bridge is None or self.bridge.stdin is None:
            messagebox.showinfo("Recorrido", "Primero activá una ubicación y esperá el indicador verde.")
            return
        if self._route_panel_is_visible():
            return
        if not self.route_origin_address.get().strip():
            self.route_origin_address.set(self.address.get().strip() or self.selected_name.get().strip())
        self.route_info_text.set("Completá las dos direcciones para calcular el recorrido.")
        self.main_panel.pack_forget()
        self.route_panel.pack(fill="both", expand=True)
        self.route_destination_entry.focus_set()

    def _route_speed_changed(self, _value=None) -> None:
        self.route_speed_text.set(f"{self.route_speed.get():.0f} km/h")
        if self.route_active:
            self._update_route_info_text()

    def _route_widgets(self, field: str):
        if field == "origin":
            return self.route_origin_address, self.route_origin_results
        return self.route_destination_address, self.route_destination_results

    def _schedule_route_suggestions(self, field: str) -> None:
        variable, listbox = self._route_widgets(field)
        self.route_selected_locations[field] = None
        self.route_suggestion_ids[field] += 1
        request_id = self.route_suggestion_ids[field]
        job = self.route_suggestion_jobs[field]
        if job is not None:
            try:
                self.root.after_cancel(job)
            except tk.TclError:
                pass
        listbox.delete(0, tk.END)
        self.route_suggestion_results[field] = []
        query = variable.get().strip()
        if len(query) < 3:
            self.route_suggestion_jobs[field] = None
            return
        self.route_suggestion_jobs[field] = self.root.after(
            350,
            lambda: threading.Thread(
                target=self._route_suggestions_worker,
                args=(field, query, request_id),
                daemon=True,
            ).start(),
        )

    def _route_suggestions_worker(self, field: str, query: str, request_id: int) -> None:
        try:
            params = urllib.parse.urlencode({
                "q": query,
                "format": "jsonv2",
                "limit": 5,
                "accept-language": "es",
                "addressdetails": 1,
            })
            request = urllib.request.Request(
                "https://nominatim.openstreetmap.org/search?" + params,
                headers={"User-Agent": "OjoGPS-Windows/16.4.32"},
            )
            with urllib.request.urlopen(request, timeout=20) as response:
                results = json.loads(response.read().decode("utf-8"))
            payload = {"field": field, "request_id": request_id, "results": results}
            self.events.put(("ROUTE_SUGGESTIONS", json.dumps(payload)))
        except Exception:
            payload = {"field": field, "request_id": request_id, "results": []}
            self.events.put(("ROUTE_SUGGESTIONS", json.dumps(payload)))

    def _select_route_suggestion(self, field: str) -> None:
        variable, listbox = self._route_widgets(field)
        selection = listbox.curselection()
        if not selection:
            return
        index = int(selection[0])
        results = self.route_suggestion_results[field]
        if index >= len(results):
            return
        item = results[index]
        self.route_selected_locations[field] = item
        variable.set(item.get("display_name", variable.get()))
        self.route_suggestion_ids[field] += 1
        listbox.delete(0, tk.END)

    def _set_route_speed(self, speed: float, profile: str | None = None) -> None:
        self.route_speed.set(speed)
        self._route_speed_changed()
        if profile is not None:
            self.route_profile = profile

    def start_route(self) -> None:
        if self.route_active:
            return
        origin_query = self.route_origin_address.get().strip()
        destination_query = self.route_destination_address.get().strip()
        if not origin_query:
            messagebox.showinfo("Simular recorrido", "Escribí la dirección de partida en el primer campo.")
            return
        if not destination_query:
            messagebox.showinfo("Simular recorrido", "Escribí la dirección de llegada en el segundo campo.")
            return
        self.route_request_id += 1
        request_id = self.route_request_id
        selected = {}
        for field, query in (("origin", origin_query), ("destination", destination_query)):
            item = self.route_selected_locations[field]
            selected[field] = item if item and item.get("display_name") == query else None
            _, listbox = self._route_widgets(field)
            listbox.delete(0, tk.END)
        self._close_joystick()
        self.joystick_button.configure(state="disabled")
        self.route_start_button.configure(state="disabled")
        self.route_info_text.set("Buscando las dos direcciones y calculando el camino...")
        self.set_status("Calculando recorrido...", "#d59b2b")
        threading.Thread(
            target=self._route_prepare_worker,
            args=(request_id, origin_query, destination_query, selected["origin"], selected["destination"], self.route_profile),
            daemon=True,
        ).start()

    @staticmethod
    def _parse_route_coordinates(value: str) -> tuple[float, float] | None:
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

    def _geocode_route_location(self, query: str) -> tuple[tuple[float, float], dict]:
        coordinates = self._parse_route_coordinates(query)
        if coordinates is not None:
            display_name = f"{coordinates[0]:.6f}, {coordinates[1]:.6f}"
            return coordinates, {"display_name": display_name, "address": {}}
        params = urllib.parse.urlencode({
            "q": query,
            "format": "jsonv2",
            "limit": 1,
            "accept-language": "es",
            "addressdetails": 1,
        })
        request = urllib.request.Request(
            "https://nominatim.openstreetmap.org/search?" + params,
            headers={"User-Agent": "OjoGPS-Windows/16.4.32"},
        )
        with urllib.request.urlopen(request, timeout=20) as response:
            results = json.loads(response.read().decode("utf-8"))
        if not results:
            raise RuntimeError(f"No encontramos esta dirección: {query}")
        return (float(results[0]["lat"]), float(results[0]["lon"])), results[0]

    @staticmethod
    def _selected_route_location(item, fallback: str):
        if not item:
            return None
        return (float(item["lat"]), float(item["lon"])), item

    def _route_prepare_worker(self, request_id: int, origin_query: str, destination_query: str, origin_item, destination_item, profile: str) -> None:
        try:
            origin_selected = self._selected_route_location(origin_item, origin_query)
            destination_selected = self._selected_route_location(destination_item, destination_query)
            origin, origin_full_item = origin_selected or self._geocode_route_location(origin_query)
            destination, destination_full_item = destination_selected or self._geocode_route_location(destination_query)
            if self._distance_m(origin, destination) < 2.0:
                raise RuntimeError("La partida y la llegada coinciden. Elegí dos lugares diferentes.")
            origin_short = self._short_place_label(origin_full_item)
            destination_short = self._short_place_label(destination_full_item)
            self._route_worker(request_id, origin, destination, origin_short, destination_short, profile)
        except Exception as exc:
            self.events.put(("ROUTE_PLAN_ERROR", json.dumps({"request_id": request_id, "message": str(exc)})))

    def _route_worker(
        self,
        request_id: int,
        origin: tuple[float, float],
        destination: tuple[float, float],
        origin_short: str = "Partida",
        destination_short: str = "Llegada",
        profile: str = "driving",
    ) -> None:
        try:
            origin_lat, origin_lon = origin
            destination_lat, destination_lon = destination
            osrm_profile = profile if profile in ("foot", "bike", "driving") else "driving"
            url = (
                f"https://router.project-osrm.org/route/v1/{osrm_profile}/"
                f"{origin_lon:.7f},{origin_lat:.7f};{destination_lon:.7f},{destination_lat:.7f}"
                "?overview=full&geometries=geojson&steps=false"
            )
            request = urllib.request.Request(url, headers={"User-Agent": "OjoGPS-Windows/16.4.32"})
            with urllib.request.urlopen(request, timeout=25) as response:
                payload = json.loads(response.read().decode("utf-8"))
            routes = payload.get("routes") or []
            if not routes:
                raise RuntimeError("No se encontró un camino entre los dos puntos")
            coordinates = routes[0]["geometry"]["coordinates"]
            points = [(float(lat), float(lon)) for lon, lat in coordinates]
            if len(points) < 2:
                raise RuntimeError("El servicio devolvió un recorrido vacío")
            if osrm_profile == "foot":
                points = self._offset_route_for_sidewalk(points)
            result = {
                "request_id": request_id,
                "points": points,
                "distance": float(routes[0].get("distance", 0.0)),
                "origin_short": origin_short,
                "destination_short": destination_short,
            }
            self.events.put(("ROUTE_PLAN_OK", json.dumps(result)))
        except Exception as exc:
            self.events.put(("ROUTE_PLAN_ERROR", json.dumps({"request_id": request_id, "message": str(exc)})))

    def _begin_route(
        self,
        points: list[tuple[float, float]],
        origin_short: str = "Partida",
        destination_short: str = "Llegada",
    ) -> None:
        # Antes de iniciar el avance, el GPS se coloca exactamente en la partida elegida.
        origin = points[0]
        self.current_coords = origin
        self.latitude.set(f"{origin[0]:.7f}")
        self.longitude.set(f"{origin[1]:.7f}")
        try:
            self.bridge.stdin.write(f"MOVE:{origin[0]:.7f},{origin[1]:.7f}\n")
            self.bridge.stdin.flush()
        except Exception:
            self.events.put(("ROUTE_ERROR", "Se perdió la conexión antes de iniciar el recorrido."))
            return
        self.route_points = points
        self.route_index = 1
        self.route_active = True
        self.route_paused = False
        self.route_pause_button.configure(state="normal", text="Pausar")
        self.route_stop_button.configure(state="normal")
        self.route_origin_short = origin_short
        self.route_destination_short = destination_short
        self._update_route_info_text()
        self.set_status("Recorrido automático en marcha", GREEN)
        self._route_tick()

    def _remaining_route_distance_m(self) -> float:
        if self.current_coords is None or not self.route_points:
            return 0.0
        total = 0.0
        position = self.current_coords
        for idx in range(self.route_index, len(self.route_points)):
            target = self.route_points[idx]
            total += self._distance_m(position, target)
            position = target
        return total

    def _update_route_info_text(self) -> None:
        remaining_m = self._remaining_route_distance_m()
        speed = max(1.0, self.route_speed.get())
        minutes = remaining_m / (speed * 1000.0 / 60.0)
        self.route_info_text.set(
            f"{self.route_origin_short} → {self.route_destination_short}\n"
            f"Distancia restante: {remaining_m / 1000.0:.2f} km  •  Llegás en: {self._format_duration(minutes)}"
        )

    def _route_tick(self) -> None:
        self.route_job = None
        if not self.route_active or self.route_paused or self.current_coords is None:
            return
        if self.bridge is None or self.bridge.stdin is None:
            self._stop_route()
            return
        if self.route_index >= len(self.route_points):
            self._finish_route()
            return

        remaining = max(1.0, self.route_speed.get()) * 1000.0 / 3600.0 * 0.5
        position = self.current_coords
        while remaining > 0 and self.route_index < len(self.route_points):
            target = self.route_points[self.route_index]
            segment = self._distance_m(position, target)
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

        self.current_coords = position
        self.latitude.set(f"{position[0]:.7f}")
        self.longitude.set(f"{position[1]:.7f}")
        self._update_route_info_text()
        try:
            self.bridge.stdin.write(f"MOVE:{position[0]:.7f},{position[1]:.7f}\n")
            self.bridge.stdin.flush()
        except Exception:
            self._stop_route()
            return
        if self.route_index >= len(self.route_points):
            self._finish_route()
        else:
            self.route_job = self.root.after(500, self._route_tick)

    def toggle_route_pause(self) -> None:
        if not self.route_active:
            return
        self.route_paused = not self.route_paused
        if self.route_paused:
            if self.route_job is not None:
                try:
                    self.root.after_cancel(self.route_job)
                except tk.TclError:
                    pass
                self.route_job = None
            self.route_pause_button.configure(text="Continuar")
            self.set_status("Recorrido en pausa", "#d59b2b")
        else:
            self.route_pause_button.configure(text="Pausar")
            self.set_status("Recorrido automático en marcha", GREEN)
            self._route_tick()

    def _finish_route(self) -> None:
        self.route_active = False
        self.route_paused = False
        self.route_points = []
        self.route_index = 0
        self.route_job = None
        self.route_info_text.set("Destino alcanzado. La ubicación permanece activa.")
        self.route_start_button.configure(state="normal")
        self.route_pause_button.configure(state="disabled", text="Pausar")
        self.route_stop_button.configure(state="disabled")
        if self.active:
            self.joystick_button.configure(state="normal")
        self.set_status("Destino alcanzado", GREEN)

    def _stop_route(self, close_window: bool = False) -> None:
        if self.route_job is not None:
            try:
                self.root.after_cancel(self.route_job)
            except tk.TclError:
                pass
        self.route_job = None
        was_active = self.route_active
        self.route_active = False
        self.route_paused = False
        self.route_points = []
        self.route_index = 0
        self.route_start_button.configure(state="normal")
        self.route_pause_button.configure(state="disabled", text="Pausar")
        self.route_stop_button.configure(state="disabled")
        self.route_info_text.set("Recorrido detenido; la ubicación actual permanece activa.")
        if close_window:
            self.route_panel.pack_forget()
            self.main_panel.pack(fill="both", expand=True)
        if self.active:
            self.joystick_button.configure(state="normal")
            if was_active:
                self.set_status("Recorrido detenido", GREEN)

    @staticmethod
    def _distance_m(first: tuple[float, float], second: tuple[float, float]) -> float:
        lat1, lon1 = map(math.radians, first)
        lat2, lon2 = map(math.radians, second)
        delta_lat = lat2 - lat1
        delta_lon = lon2 - lon1
        value = math.sin(delta_lat / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(delta_lon / 2) ** 2
        return 6_371_000.0 * 2 * math.atan2(math.sqrt(value), math.sqrt(max(0.0, 1 - value)))

    @staticmethod
    def _bearing_deg(origin: tuple[float, float], target: tuple[float, float]) -> float:
        lat1, lon1 = math.radians(origin[0]), math.radians(origin[1])
        lat2, lon2 = math.radians(target[0]), math.radians(target[1])
        delta_lon = lon2 - lon1
        x = math.sin(delta_lon) * math.cos(lat2)
        y = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(delta_lon)
        return (math.degrees(math.atan2(x, y)) + 360.0) % 360.0

    @staticmethod
    def _angle_diff_deg(first: float, second: float) -> float:
        diff = abs(first - second) % 360.0
        return diff if diff <= 180.0 else 360.0 - diff

    @staticmethod
    def _offset_point(origin: tuple[float, float], bearing_deg: float, distance_m: float) -> tuple[float, float]:
        radius = 6_371_000.0
        lat1 = math.radians(origin[0])
        lon1 = math.radians(origin[1])
        brng = math.radians(bearing_deg)
        d_over_r = distance_m / radius
        lat2 = math.asin(
            math.sin(lat1) * math.cos(d_over_r) + math.cos(lat1) * math.sin(d_over_r) * math.cos(brng)
        )
        lon2 = lon1 + math.atan2(
            math.sin(brng) * math.sin(d_over_r) * math.cos(lat1),
            math.cos(d_over_r) - math.sin(lat1) * math.sin(lat2),
        )
        return (math.degrees(lat2), (math.degrees(lon2) + 540.0) % 360.0 - 180.0)

    def _offset_route_for_sidewalk(self, points: list[tuple[float, float]], offset_m: float = 2.5) -> list[tuple[float, float]]:
        # Corre cada punto de la ruta unos metros hacia el costado derecho de
        # la dirección de avance, para que Caminar se vea al borde de la
        # calle en vez de pisando el medio. Es una aproximación visual: no
        # sabe dónde está la vereda real, así que siempre corre para el
        # mismo lado y puede no coincidir con la vereda en calles muy
        # anchas o en curvas muy cerradas.
        if len(points) < 2:
            return points
        offset_points = []
        for index, point in enumerate(points):
            if index == 0:
                heading = self._bearing_deg(points[0], points[1])
            elif index == len(points) - 1:
                heading = self._bearing_deg(points[-2], points[-1])
            else:
                bearing_in = math.radians(self._bearing_deg(points[index - 1], point))
                bearing_out = math.radians(self._bearing_deg(point, points[index + 1]))
                vector_x = math.sin(bearing_in) + math.sin(bearing_out)
                vector_y = math.cos(bearing_in) + math.cos(bearing_out)
                heading = math.degrees(math.atan2(vector_x, vector_y)) % 360.0
            offset_points.append(self._offset_point(point, (heading + 90.0) % 360.0, offset_m))
        return offset_points

    @staticmethod
    def _format_duration(minutes: float) -> str:
        total = max(1, round(minutes))
        hours, mins = divmod(total, 60)
        return f"{hours} h {mins} min" if hours else f"{mins} min"

    @staticmethod
    def _short_place_label(item: dict) -> str:
        address = item.get("address") or {}
        road = address.get("road") or address.get("pedestrian")
        number = address.get("house_number")
        return (
            (f"{road} {number}" if road and number else road)
            or address.get("pedestrian")
            or address.get("suburb")
            or address.get("city")
            or item.get("display_name", "Punto elegido").split(",")[0]
        )

    @staticmethod
    def _load_help_seen() -> bool:
        try:
            data = json.loads(HELP_STATE.read_text(encoding="utf-8"))
            return bool(data.get("joystick_tutorial_v1"))
        except (OSError, ValueError, TypeError):
            return False

    def _save_help_seen(self) -> None:
        try:
            HELP_STATE.parent.mkdir(parents=True, exist_ok=True)
            HELP_STATE.write_text(
                json.dumps({"joystick_tutorial_v1": True}, ensure_ascii=False),
                encoding="utf-8",
            )
        except OSError:
            pass

    def _joystick_help_clicked(self) -> None:
        if self.joystick_help_active:
            self._finish_joystick_tutorial(mark_seen=True)
        else:
            self._start_joystick_tutorial()

    def _start_joystick_tutorial(self) -> None:
        if self.joystick_canvas is None or self.joystick_knob is None:
            return
        self._stop_move()
        if self.joystick_help_job is not None:
            try:
                self.root.after_cancel(self.joystick_help_job)
            except tk.TclError:
                pass
            self.joystick_help_job = None
        self.joystick_help_active = True
        self.joystick_help_frame = 0
        if self.joystick_help_button is not None:
            self.joystick_help_button.configure(text="Ayuda en curso", state="disabled")
        if self.joystick_skip_button is not None:
            self.joystick_skip_button.pack(side="right", padx=(0, 4), pady=(0, 12))
        self.joystick_instruction_text.set("Tomá el círculo con el mouse o el dedo.")
        if self.joystick_demo_pointer is not None:
            self.joystick_canvas.delete(self.joystick_demo_pointer)
        self.joystick_demo_pointer = self.joystick_canvas.create_oval(
            152, 152, 170, 170, fill="#f2a33a", outline="white", width=2
        )
        self._animate_joystick_tutorial()

    def _animate_joystick_tutorial(self) -> None:
        if not self.joystick_help_active or self.joystick_canvas is None or self.joystick_knob is None:
            return
        frame = self.joystick_help_frame
        if frame <= 15:
            progress = frame / 15.0
            dx, dy = 56.0 * progress, -56.0 * progress
            self.joystick_instruction_text.set("Arrastrá hacia la dirección en la que querés avanzar.")
        elif frame <= 35:
            dx, dy = 56.0, -56.0
            self.joystick_instruction_text.set("Mantenelo presionado para seguir avanzando.")
        elif frame <= 50:
            progress = (frame - 35) / 15.0
            dx, dy = 56.0 * (1.0 - progress), -56.0 * (1.0 - progress)
            self.joystick_instruction_text.set("Soltalo para detenerte.")
        elif frame <= 70:
            dx, dy = 0.0, 0.0
            self.joystick_instruction_text.set("Listo: funciona con mouse, dedo o flechas del teclado.")
        else:
            self._finish_joystick_tutorial(mark_seen=True)
            return

        center = 130.0
        radius = 30.0
        knob_x = center + dx
        knob_y = center + dy
        self.joystick_canvas.coords(
            self.joystick_knob,
            knob_x - radius,
            knob_y - radius,
            knob_x + radius,
            knob_y + radius,
        )
        if self.joystick_heading_line is not None:
            self.joystick_canvas.coords(
                self.joystick_heading_line,
                center,
                center,
                center + dx * 0.72,
                center + dy * 0.72,
            )
        if self.joystick_demo_pointer is not None:
            self.joystick_canvas.coords(
                self.joystick_demo_pointer,
                knob_x + 20,
                knob_y + 20,
                knob_x + 38,
                knob_y + 38,
            )
        self.joystick_help_frame += 1
        self.joystick_help_job = self.root.after(180, self._animate_joystick_tutorial)

    def _finish_joystick_tutorial(self, mark_seen: bool) -> None:
        if self.joystick_help_job is not None:
            try:
                self.root.after_cancel(self.joystick_help_job)
            except tk.TclError:
                pass
            self.joystick_help_job = None
        self.joystick_help_active = False
        if self.joystick_canvas is not None:
            if self.joystick_demo_pointer is not None:
                self.joystick_canvas.delete(self.joystick_demo_pointer)
            if self.joystick_knob is not None:
                self.joystick_canvas.coords(self.joystick_knob, 100, 100, 160, 160)
            if self.joystick_heading_line is not None:
                self.joystick_canvas.coords(self.joystick_heading_line, 130, 130, 130, 130)
        self.joystick_demo_pointer = None
        self.joystick_instruction_text.set(
            "Arrastrá el círculo con el mouse o el dedo. Mantenelo presionado para avanzar y soltalo para detenerte."
        )
        if self.joystick_help_button is not None:
            self.joystick_help_button.configure(text="¿Cómo se usa?", state="normal")
        if self.joystick_skip_button is not None:
            self.joystick_skip_button.pack_forget()
        if mark_seen:
            self.joystick_help_seen = True
            self._save_help_seen()

    def open_joystick(self) -> None:
        if not self.active or self.bridge is None or self.bridge.stdin is None:
            messagebox.showinfo(
                "Joystick",
                "Primero pulsá Cambiar ubicación y esperá el indicador verde.",
            )
            return
        if self.route_active:
            messagebox.showinfo("Joystick", "Primero pausá o detené el recorrido automático.")
            return
        if self.joystick_window is not None and self.joystick_window.winfo_exists():
            self.joystick_window.lift()
            self.joystick_window.focus_force()
            return

        window = tk.Toplevel(self.root)
        self.joystick_window = window
        window.title("Ojo GPS - Joystick")
        # La altura adicional evita que Windows recorte la flecha inferior y
        # las coordenadas cuando la pantalla usa escala de texto de 125/150 %.
        window.geometry("500x650")
        window.minsize(440, 590)
        window.resizable(True, True)
        window.configure(bg=BG)
        window.protocol("WM_DELETE_WINDOW", self._close_joystick)

        frame = ttk.Frame(window, padding=24)
        frame.pack(fill="both", expand=True)
        title_row = ttk.Frame(frame)
        title_row.pack(fill="x")
        ttk.Label(title_row, text="Joystick", style="Title.TLabel").pack(side="left", expand=True, padx=(90, 0))
        self.joystick_help_button = ttk.Button(
            title_row,
            text="¿Cómo se usa?",
            style="Secondary.TButton",
            command=self._joystick_help_clicked,
        )
        self.joystick_help_button.pack(side="right")
        ttk.Label(
            frame,
            textvariable=self.joystick_instruction_text,
            style="Subtitle.TLabel",
            wraplength=420,
            justify="center",
        ).pack(anchor="center", pady=(8, 16))

        help_action_row = ttk.Frame(frame)
        help_action_row.pack(fill="x")
        self.joystick_skip_button = ttk.Button(
            help_action_row,
            text="Omitir  ×",
            style="Secondary.TButton",
            command=lambda: self._finish_joystick_tutorial(mark_seen=True),
        )

        mode_row = ttk.Frame(frame)
        mode_row.pack(fill="x", pady=(0, 14))
        ttk.Label(mode_row, text="Velocidad:").pack(side="left")
        mode_box = ttk.Combobox(
            mode_row,
            textvariable=self.movement_mode,
            values=("Caminar", "Bicicleta", "Auto"),
            state="readonly",
            width=16,
        )
        mode_box.pack(side="right")

        pad = tk.Canvas(frame, width=260, height=260, bg=BG, highlightthickness=0, cursor="hand2")
        self.joystick_canvas = pad
        pad.pack(pady=4)
        pad.create_oval(20, 20, 240, 240, fill="#e7f1ef", outline="#9fc8c3", width=3)
        pad.create_line(130, 30, 130, 230, fill="#c3dcd9", width=2)
        pad.create_line(30, 130, 230, 130, fill="#c3dcd9", width=2)
        pad.create_line(59, 59, 201, 201, fill="#d4e5e3", width=2)
        pad.create_line(201, 59, 59, 201, fill="#d4e5e3", width=2)
        pad.create_text(130, 11, text="N", fill=GREEN_DARK, font=ui_font(10, semibold=True))
        pad.create_text(249, 130, text="E", fill=GREEN_DARK, font=ui_font(10, semibold=True))
        pad.create_text(130, 249, text="S", fill=GREEN_DARK, font=ui_font(10, semibold=True))
        pad.create_text(11, 130, text="O", fill=GREEN_DARK, font=ui_font(10, semibold=True))
        self.joystick_heading_line = pad.create_line(
            130, 130, 130, 130, fill=GREEN_DARK, width=5, arrow="last"
        )
        self.joystick_knob = pad.create_oval(100, 100, 160, 160, fill=GREEN, outline=GREEN_DARK, width=2)
        pad.bind("<ButtonPress-1>", self._joystick_drag)
        pad.bind("<B1-Motion>", self._joystick_drag)
        pad.bind("<ButtonRelease-1>", self._joystick_release)
        self._update_joystick_coords()
        ttk.Label(frame, textvariable=self.joystick_coords_text, style="Subtitle.TLabel").pack(pady=(12, 4))
        ttk.Label(
            frame,
            text="Caminar 5 km/h  •  Bicicleta 15 km/h  •  Auto 40 km/h",
            style="Subtitle.TLabel",
        ).pack()

        window.bind("<KeyPress-Up>", lambda _event: self._start_move("north"))
        window.bind("<KeyPress-Down>", lambda _event: self._start_move("south"))
        window.bind("<KeyPress-Left>", lambda _event: self._start_move("west"))
        window.bind("<KeyPress-Right>", lambda _event: self._start_move("east"))
        window.bind("<KeyRelease>", lambda _event: self._joystick_release())
        window.focus_force()
        if not self.joystick_help_seen:
            self.joystick_help_job = self.root.after(700, self._start_joystick_tutorial)

    def _joystick_drag(self, event) -> None:
        if self.joystick_help_active:
            self._finish_joystick_tutorial(mark_seen=True)
        center = 130.0
        # El centro del mando queda dentro del aro aunque Windows aplique
        # escalado de pantalla. Su distancia al centro regula la intensidad.
        max_radius = 80.0
        dx = float(event.x) - center
        dy = float(event.y) - center
        magnitude = math.hypot(dx, dy)
        if magnitude > max_radius:
            scale = max_radius / magnitude
            dx *= scale
            dy *= scale
            magnitude = max_radius
        if magnitude < 5.0:
            self._joystick_release()
            return
        if self.joystick_canvas is not None and self.joystick_knob is not None:
            radius = 30.0
            knob_x = center + dx
            knob_y = center + dy
            self.joystick_canvas.coords(
                self.joystick_knob,
                knob_x - radius,
                knob_y - radius,
                knob_x + radius,
                knob_y + radius,
            )
            if self.joystick_heading_line is not None:
                self.joystick_canvas.coords(
                    self.joystick_heading_line,
                    center,
                    center,
                    center + dx * 0.72,
                    center + dy * 0.72,
                )
        # Norte es Y negativa en la pantalla; este es X positiva.
        self._start_vector_move(-dy / max_radius, dx / max_radius)

    def _joystick_release(self, _event=None) -> None:
        self._stop_move()
        if self.joystick_canvas is not None and self.joystick_knob is not None:
            self.joystick_canvas.coords(self.joystick_knob, 100, 100, 160, 160)
            if self.joystick_heading_line is not None:
                self.joystick_canvas.coords(self.joystick_heading_line, 130, 130, 130, 130)

    def _start_vector_move(self, north: float, east: float) -> None:
        self.joystick_vector = (north, east)
        if self.joystick_direction == "analog":
            return
        self.joystick_direction = "analog"
        self._move_once()

    def _start_move(self, direction: str) -> None:
        if self.joystick_direction == direction:
            return
        self._stop_move()
        self.joystick_direction = direction
        vectors = {
            "north": (1.0, 0.0),
            "south": (-1.0, 0.0),
            "east": (0.0, 1.0),
            "west": (0.0, -1.0),
        }
        self.joystick_vector = vectors.get(direction)
        self._move_once()

    def _stop_move(self) -> None:
        self.joystick_direction = None
        self.joystick_vector = None
        if self.joystick_job is not None:
            try:
                self.root.after_cancel(self.joystick_job)
            except tk.TclError:
                pass
            self.joystick_job = None

    def _move_once(self) -> None:
        if self.joystick_direction is None or self.joystick_vector is None or not self.active or self.current_coords is None:
            self._stop_move()
            return
        if self.bridge is None or self.bridge.stdin is None:
            self._stop_move()
            return

        speeds_kmh = {"Caminar": 5.0, "Bicicleta": 15.0, "Auto": 40.0}
        speed_kmh = speeds_kmh.get(self.movement_mode.get(), 5.0)
        distance_m = speed_kmh * 1000.0 / 3600.0 * 0.5
        latitude, longitude = self.current_coords
        north_factor, east_factor = self.joystick_vector
        north_m = distance_m * north_factor
        east_m = distance_m * east_factor

        latitude += north_m / 111_320.0
        longitude += east_m / max(1.0, 111_320.0 * math.cos(math.radians(latitude)))
        self.current_coords = (latitude, longitude)
        self.latitude.set(f"{latitude:.7f}")
        self.longitude.set(f"{longitude:.7f}")
        self._update_joystick_coords()
        try:
            self.bridge.stdin.write(f"MOVE:{latitude:.7f},{longitude:.7f}\n")
            self.bridge.stdin.flush()
            self.set_status(f"Moviendo en modo {self.movement_mode.get()}...", GREEN)
        except Exception:
            self._stop_move()
            return
        self.joystick_job = self.root.after(500, self._move_once)

    def _update_joystick_coords(self) -> None:
        if self.current_coords is None:
            self.joystick_coords_text.set("Sin coordenadas activas")
            return
        latitude, longitude = self.current_coords
        self.joystick_coords_text.set(f"{latitude:.6f}, {longitude:.6f}")

    def _close_joystick(self) -> None:
        self._finish_joystick_tutorial(mark_seen=False)
        self._stop_move()
        if self.joystick_window is not None:
            try:
                self.joystick_window.destroy()
            except tk.TclError:
                pass
            self.joystick_window = None
        self.joystick_canvas = None
        self.joystick_knob = None
        self.joystick_heading_line = None
        self.joystick_help_button = None
        self.joystick_skip_button = None

    def _start_bridge(self, mode: str, operation: str, lat: float, lon: float) -> None:
        try:
            self.current_operation = operation
            self.bridge_started_at = time.monotonic()
            self.bridge = subprocess.Popen(
                [sys.executable, str(BRIDGE), mode, operation, str(lat), str(lon)],
                cwd=APP_DIR,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
                creationflags=CREATE_NO_WINDOW,
            )
            assert self.bridge.stdout is not None
            for line in self.bridge.stdout:
                line = line.strip()
                if line.startswith("OJO_STATUS:"):
                    self.events.put(("BRIDGE", line.removeprefix("OJO_STATUS:")))
            code = self.bridge.wait()
            self.events.put(("BRIDGE_EXIT", str(code)))
        except Exception as exc:
            self.events.put(("BRIDGE", "ERROR:" + str(exc)))

    def restore(self) -> None:
        self._stop_route(close_window=True)
        self._close_joystick()
        if self.bridge is None:
            if not messagebox.askokcancel(
                "Volver al GPS real",
                "Para restaurar el GPS real del iPhone:\n\n"
                "1. Activá nuevamente Modo de desarrollador en el iPhone.\n"
                "2. Conectalo a la PC con el cable.\n"
                "3. Dejalo desbloqueado y aceptá Confiar si aparece.\n"
                "4. Cuando esté listo, pulsá Aceptar para restaurar.\n\n"
                "Este procedimiento es exclusivo para iPhone.",
            ):
                return
            # Una ubicación fijada sin conexión solo puede limpiarse de forma
            # confiable volviendo a abrir el servicio de desarrollo por cable.
            self.current_mode = "cable"
            self.connection_mode.set("cable")
            self.current_operation = "clear"
            self.restore_succeeded = False
            self.activate_button.configure(state="disabled")
            self.fix_button.configure(state="disabled")
            self.search_button.configure(state="disabled")
            self.restore_button.configure(state="disabled")
            self.set_connection("RESTAURANDO", "#d59b2b")
            self.set_status("Conectando para restaurar el GPS real...", "#d59b2b")
            threading.Thread(target=self._start_bridge, args=(self.current_mode, "clear", 0.0, 0.0), daemon=True).start()
            return
        self.current_operation = "clear"
        self.restore_succeeded = False
        self.restore_button.configure(state="disabled")
        self.fix_button.configure(state="disabled")
        self.set_connection("RESTAURANDO", "#d59b2b")
        self.set_status("Restaurando GPS real...", "#d59b2b")
        try:
            if self.bridge.stdin is None:
                raise RuntimeError("el puente ya se cerró")
            self.bridge.stdin.write("RESTORE\n")
            self.bridge.stdin.flush()
        except Exception as exc:
            self.restore_button.configure(state="normal")
            self.fix_button.configure(state="normal")
            messagebox.showerror(
                "Ojo GPS",
                f"No se pudo enviar la restauración: {exc}\n\n"
                "Activá Modo de desarrollador, reconectá el cable y volvé a pulsar Volver al GPS real.",
            )

    def _poll_events(self) -> None:
        try:
            while True:
                kind, value = self.events.get_nowait()
                if kind == "SEARCH_OK":
                    self.search_results = json.loads(value)
                    self.results.delete(0, tk.END)
                    for item in self.search_results:
                        self.results.insert(tk.END, "  " + item["display_name"])
                    if self.search_results:
                        self.results.selection_set(0)
                        self.select_result()
                        self.set_status("Elegí un resultado", GREEN)
                    else:
                        self.set_status("No encontramos ese lugar", "#c45a4a")
                    self.search_button.configure(state="normal")
                elif kind == "SEARCH_ERROR":
                    self.search_button.configure(state="normal")
                    self.set_status("No se pudo buscar; podés escribir coordenadas", "#c45a4a")
                elif kind == "PLACE_CONTEXT":
                    payload = json.loads(value)
                    self.place_location_text = payload.get("location") or "Punto elegido"
                    timezone_name = payload.get("timezone") or ""
                    if timezone_name:
                        self.place_timezone = timezone_name
                    self._refresh_place_clock()
                elif kind == "PLACE_REVERSE":
                    item = json.loads(value)
                    self.selected_name.set(self._short_place_label(item))
                    self._request_place_context(float(item["lat"]), float(item["lon"]), item)
                elif kind == "MAP_REVERSE":
                    item = json.loads(value)
                    label = self._short_place_label(item)
                    resolved = item.get("display_name") or label
                    route_field = item.get("_route_field")
                    if self.map_target == "route" and route_field in ("origin", "destination"):
                        current = self.route_selected_locations.get(route_field)
                        # Una búsqueda anterior no debe pisar un punto que el usuario
                        # acaba de cambiar mientras se resolvía la dirección.
                        if current and abs(float(current["lat"]) - float(item["lat"])) < 0.0000001 and abs(float(current["lon"]) - float(item["lon"])) < 0.0000001:
                            current["display_name"] = resolved
                            current["address"] = item.get("address") or {}
                            variable, _listbox = self._route_widgets(route_field)
                            variable.set(resolved)
                            point_name = "Partida" if route_field == "origin" else "Llegada"
                            other_name = "llegada" if route_field == "origin" else "partida"
                            self.map_info_text.set(
                                f"{point_name} guardada. Podés editar la {other_name} o tocar Listo."
                            )
                    else:
                        self.map_selected_address = resolved
                        self.map_selected_short = label
                        self.map_selected_address_details = item.get("address") or {}
                        self.map_info_text.set("Destino: " + self.map_selected_address)
                elif kind == "MAP_TILES":
                    payload = json.loads(value)
                    if payload.get("id") != self.map_render_id or self.map_canvas is None:
                        continue
                    self.map_canvas.delete("all")
                    self.map_images = []
                    for tile in payload.get("tiles", []):
                        image = tk.PhotoImage(data=tile["data"])
                        self.map_images.append(image)
                        self.map_canvas.create_image(tile["x"], tile["y"], image=image, anchor="nw")
                    self.map_canvas.create_text(8, 8, text="© OpenStreetMap", anchor="nw", fill="#173230", font=ui_font(8))
                    cx, cy = self._world_pixels(self.map_center[0], self.map_center[1], self.map_zoom)
                    if self.map_target == "route":
                        origin = self.route_selected_locations.get("origin")
                        destination = self.route_selected_locations.get("destination")
                        if origin:
                            rx, ry = self._world_pixels(float(origin["lat"]), float(origin["lon"]), self.map_zoom)
                            self._draw_map_reference_marker(
                                payload["width"] / 2 + rx - cx,
                                payload["height"] / 2 + ry - cy,
                            )
                        if destination:
                            mx, my = self._world_pixels(float(destination["lat"]), float(destination["lon"]), self.map_zoom)
                            self._draw_map_marker(
                                payload["width"] / 2 + mx - cx,
                                payload["height"] / 2 + my - cy,
                            )
                    elif self.map_reference_marker is not None:
                        rx, ry = self._world_pixels(
                            self.map_reference_marker[0], self.map_reference_marker[1], self.map_zoom
                        )
                        self._draw_map_reference_marker(
                            payload["width"] / 2 + rx - cx,
                            payload["height"] / 2 + ry - cy,
                        )
                    if self.map_target != "route" and self.map_marker is not None:
                        mx, my = self._world_pixels(self.map_marker[0], self.map_marker[1], self.map_zoom)
                        self._draw_map_marker(payload["width"] / 2 + mx - cx, payload["height"] / 2 + my - cy)
                elif kind == "MAP_ERROR":
                    if self.map_canvas is not None:
                        self.map_canvas.delete("all")
                        self.map_canvas.create_text(
                            self.map_canvas.winfo_width() / 2,
                            self.map_canvas.winfo_height() / 2,
                            text="No se pudo cargar el mapa. Revisá Internet y volvé a intentar.",
                            fill="#c45a4a",
                            font=ui_font(12, semibold=True),
                        )
                elif kind == "STREET_VIEW_OK":
                    payload = json.loads(value)
                    if payload.get("id") != self.street_view_request_id or self.street_view_canvas is None:
                        continue
                    try:
                        raw_png = base64.b64decode(payload["data"])
                        photo = tk.PhotoImage(data=raw_png)
                    except (tk.TclError, ValueError):
                        self.street_view_canvas.delete("all")
                        self.street_view_canvas.create_text(
                            self.street_view_canvas.winfo_width() / 2,
                            self.street_view_canvas.winfo_height() / 2,
                            text="No se pudo mostrar la foto recibida.",
                            fill="white", font=ui_font(12, semibold=True),
                        )
                        continue
                    self.street_view_photo = photo
                    self.street_view_canvas.delete("all")
                    cw = self.street_view_canvas.winfo_width() or STREET_VIEW_MAX_SIZE[0]
                    ch = self.street_view_canvas.winfo_height() or STREET_VIEW_MAX_SIZE[1]
                    self.street_view_canvas.create_image(cw / 2, ch / 2, image=photo, anchor="center")
                    self.street_view_canvas.create_text(
                        8, ch - 8, text="© Mapillary", anchor="sw", fill="white", font=ui_font(8),
                    )
                elif kind == "STREET_VIEW_EMPTY":
                    payload = json.loads(value)
                    if payload.get("id") != self.street_view_request_id or self.street_view_canvas is None:
                        continue
                    self.street_view_canvas.delete("all")
                    self.street_view_canvas.create_text(
                        (self.street_view_canvas.winfo_width() or STREET_VIEW_MAX_SIZE[0]) / 2,
                        (self.street_view_canvas.winfo_height() or STREET_VIEW_MAX_SIZE[1]) / 2,
                        text="No hay vista de calle disponible cerca de este punto",
                        fill="white", font=ui_font(12, semibold=True),
                        width=STREET_VIEW_MAX_SIZE[0] - 40, justify="center",
                    )
                elif kind == "STREET_VIEW_ERROR":
                    payload = json.loads(value)
                    if payload.get("id") != self.street_view_request_id or self.street_view_canvas is None:
                        continue
                    self.street_view_canvas.delete("all")
                    self.street_view_canvas.create_text(
                        (self.street_view_canvas.winfo_width() or STREET_VIEW_MAX_SIZE[0]) / 2,
                        (self.street_view_canvas.winfo_height() or STREET_VIEW_MAX_SIZE[1]) / 2,
                        text="No se pudo cargar Street View.\n" + str(payload.get("message", "")),
                        fill="#f0a898", font=ui_font(11, semibold=True),
                        width=STREET_VIEW_MAX_SIZE[0] - 40, justify="center",
                    )
                elif kind == "STREET_VIEW_AUTH_ERROR":
                    payload = json.loads(value)
                    if payload.get("id") != self.street_view_request_id or self.street_view_canvas is None:
                        continue
                    MAPILLARY_TOKEN_FILE.parent.mkdir(parents=True, exist_ok=True)
                    if IS_WINDOWS:
                        try:
                            os.startfile(MAPILLARY_TOKEN_FILE.parent)
                        except OSError:
                            pass
                    elif IS_MAC:
                        try:
                            subprocess.run(["open", str(MAPILLARY_TOKEN_FILE.parent)])
                        except OSError:
                            pass
                    self.street_view_canvas.delete("all")
                    self.street_view_canvas.create_text(
                        (self.street_view_canvas.winfo_width() or STREET_VIEW_MAX_SIZE[0]) / 2,
                        (self.street_view_canvas.winfo_height() or STREET_VIEW_MAX_SIZE[1]) / 2,
                        text=(
                            "El token de Mapillary no es válido o venció.\n\n"
                            "Se abrió la carpeta donde va guardado: reemplazá el "
                            "token dentro de mapillary_token.txt (gratis en "
                            "mapillary.com/dashboard/developers) y volvé a tocar "
                            "Ver Street View."
                        ),
                        fill="#f0a898", font=ui_font(11, semibold=True),
                        width=STREET_VIEW_MAX_SIZE[0] - 40, justify="center",
                    )
                elif kind == "WIFI_PREP_OK":
                    self.wifi_preparing = False
                    self.wifi_button.configure(state="normal")
                    self._launch_wifi_tunnel()
                elif kind == "WIFI_PREP_ERROR":
                    self.wifi_preparing = False
                    self.wifi_button.configure(state="normal")
                    self.set_status("No se pudo preparar el Wi-Fi", "#c45a4a")
                    messagebox.showerror(
                        "Ojo GPS - Wi-Fi",
                        "Dejá el iPhone conectado y desbloqueado, y volvé a intentar.\n\n" + value,
                    )
                elif kind == "ROUTE_SUGGESTIONS":
                    payload = json.loads(value)
                    field = payload.get("field")
                    if field not in ("origin", "destination"):
                        continue
                    if payload.get("request_id") != self.route_suggestion_ids[field]:
                        continue
                    if not self._route_panel_is_visible():
                        continue
                    results = payload.get("results") or []
                    self.route_suggestion_results[field] = results
                    _, listbox = self._route_widgets(field)
                    listbox.delete(0, tk.END)
                    for item in results:
                        listbox.insert(tk.END, "  " + item.get("display_name", ""))
                elif kind == "ROUTE_PLAN_OK":
                    payload = json.loads(value)
                    if payload.get("request_id") != self.route_request_id:
                        continue
                    if not self.active or not self._route_panel_is_visible():
                        continue
                    points = [(float(item[0]), float(item[1])) for item in payload["points"]]
                    self._begin_route(
                        points,
                        payload.get("origin_short", "Partida"),
                        payload.get("destination_short", "Llegada"),
                    )
                elif kind == "ROUTE_PLAN_ERROR":
                    payload = json.loads(value)
                    if payload.get("request_id") != self.route_request_id:
                        continue
                    if not self.active or not self._route_panel_is_visible():
                        continue
                    self.route_start_button.configure(state="normal")
                    self.route_info_text.set("No se pudo calcular el recorrido.")
                    self.joystick_button.configure(state="normal")
                    self.set_status("No se pudo calcular el recorrido", "#c45a4a")
                    messagebox.showerror("Ojo GPS - Recorrido", payload.get("message", "Error desconocido"))
                elif kind == "ROUTE_ERROR":
                    if not self.active or not self._route_panel_is_visible():
                        continue
                    self.route_start_button.configure(state="normal")
                    self.route_info_text.set("No se pudo calcular el recorrido.")
                    if self.active:
                        self.joystick_button.configure(state="normal")
                    self.set_status("No se pudo calcular el recorrido", "#c45a4a")
                    messagebox.showerror("Ojo GPS - Recorrido", value)
                elif kind == "BRIDGE":
                    self._handle_bridge(value)
                elif kind == "BRIDGE_EXIT":
                    self.bridge = None
                    if self.fixed:
                        self.active = False
                        self.reconnecting = False
                        self.last_heartbeat = 0.0
                        self.bridge_started_at = 0.0
                        self.activate_button.configure(state="normal")
                        self.joystick_button.configure(state="disabled")
                        self.route_button.configure(state="disabled")
                        self.fix_button.configure(state="disabled")
                        self.search_button.configure(state="normal")
                        self.restore_button.configure(state="normal")
                        self.set_status("Ubicación fija; ya podés desconectar", GREEN)
                        self.set_connection("UBICACIÓN FIJA", GREEN)
                        self.footer_text.set("UBICACIÓN FIJA: el indicador está verde; ahora sí podés desconectar el cable.")
                    elif self.current_operation == "freeze":
                        self._close_fix_tutorial()
                        self.active = False
                        self.reconnecting = False
                        self.last_heartbeat = 0.0
                        self.bridge_started_at = 0.0
                        confirmed = messagebox.askyesno(
                            "Confirmar ubicación fija",
                            "¿Desactivaste Modo de desarrollador ANTES de retirar el cable?",
                        )
                        if confirmed:
                            self.fixed = True
                            self.activate_button.configure(state="normal")
                            self.joystick_button.configure(state="disabled")
                            self.route_button.configure(state="disabled")
                            self.fix_button.configure(state="disabled")
                            self.search_button.configure(state="normal")
                            self.restore_button.configure(state="normal")
                            self.set_status("Ubicación fija; ya podés desconectar o cambiar de red", GREEN)
                            self.set_connection("UBICACIÓN FIJA", GREEN)
                            self.footer_text.set("UBICACIÓN FIJA: el indicador está verde; ahora sí podés desconectar el cable.")
                        else:
                            self.fixed = False
                            self._reset_controls()
                            self.set_status("Procedimiento incompleto; volvé a cambiar la ubicación", "#c45a4a")
                    elif self.current_operation == "clear":
                        restored = self.restore_succeeded
                        self._reset_controls()
                        if restored:
                            self.set_status("GPS verdadero restaurado", GREEN)
                            self.set_connection("GPS REAL", GREEN)
                        self.restore_succeeded = False
                    elif self.active or self.reconnecting:
                        self.active = False
                        self.last_heartbeat = 0.0
                        self.reconnecting = True
                        self.reconnect_attempts += 1
                        max_attempts = 8 if self.current_mode == "wifi" else 3
                        if self.reconnect_attempts <= max_attempts and self.current_coords is not None:
                            self.set_status(f"Reconectando automáticamente ({self.reconnect_attempts}/{max_attempts})...", "#d59b2b")
                            self.root.after(1800 if self.current_mode == "wifi" else 900, self._restart_bridge)
                        else:
                            self.set_status("No se pudo reconectar", "#c45a4a")
                            self._reset_controls()
                            if self.current_mode == "wifi":
                                advice = "Revisá que la PC y el iPhone sigan en la misma red y que la ventana del puente esté abierta."
                            else:
                                advice = (
                                    "Ojo GPS intentó recuperarla 3 veces. Verificá que el iPhone siga desbloqueado, "
                                    "desconectá y reconectá el cable y esperá el semáforo verde antes de volver a intentar."
                                )
                            messagebox.showerror("Ojo GPS", "No se pudo recuperar la conexión. " + advice)
                    else:
                        self._reset_controls()
        except queue.Empty:
            pass
        if self.active and not self.reconnecting and self.last_heartbeat and time.monotonic() - self.last_heartbeat > 10:
            self.reconnecting = True
            self.set_status("El puente no responde; reiniciándolo...", "#d59b2b")
            if self.bridge is not None and self.bridge.poll() is None:
                try:
                    self.bridge.terminate()
                except Exception:
                    pass
        elif self.reconnecting and self.bridge is not None and self.bridge.poll() is None and self.bridge_started_at and time.monotonic() - self.bridge_started_at > 15:
            self.set_status("La reconexión no respondió; nuevo intento...", "#d59b2b")
            try:
                self.bridge.terminate()
            except Exception:
                pass
        elif not self.active and not self.reconnecting and self.bridge is not None and self.bridge.poll() is None and self.bridge_started_at and time.monotonic() - self.bridge_started_at > 30:
            self.reconnecting = True
            self.set_status("La conexión no respondió; reiniciándola...", "#d59b2b")
            try:
                self.bridge.terminate()
            except Exception:
                pass
        self.root.after(120, self._poll_events)

    def _restart_bridge(self) -> None:
        if self.current_coords is None or self.bridge is not None:
            return
        lat, lon = self.current_coords
        self.current_operation = "maintain"
        threading.Thread(target=self._start_bridge, args=(self.current_mode, "maintain", lat, lon), daemon=True).start()

    def _handle_bridge(self, value: str) -> None:
        if value == "PREPARING":
            self.set_status("Preparando herramientas del iPhone...", "#d59b2b")
        elif value == "CONNECTING":
            self.set_status("Conectando con el iPhone por cable...", "#d59b2b")
        elif value == "WIFI_CONNECTING":
            self.set_status("Buscando el puente Wi-Fi...", "#d59b2b")
        elif value == "WIFI_FOUND":
            self.set_status("iPhone encontrado por Wi-Fi; activando...", "#d59b2b")
        elif value == "ACTIVE":
            self.active = True
            self.fixed = False
            self.current_operation = "maintain"
            self.last_heartbeat = time.monotonic()
            self.bridge_started_at = 0.0
            self.reconnecting = False
            self.reconnect_attempts = 0
            self.joystick_button.configure(state="normal")
            self.route_button.configure(state="normal")
            self.search_button.configure(state="normal")
            self.fix_button.configure(state="normal")
            self.restore_button.configure(state="normal")
            self.set_status("Ubicación simulada activa", GREEN)
            self.set_connection("WI-FI CONECTADO" if self.current_mode == "wifi" else "CABLE CONECTADO", GREEN)
            if self.current_mode == "wifi":
                self.footer_text.set("Wi-Fi: mantené la PC y el iPhone en la misma red mientras la ubicación esté activa.")
            else:
                self.footer_text.set("Uso normal por cable: mantené el iPhone conectado y el Modo de desarrollador activo. Para desconectarlo, usá Fijar GPS.")
        elif value == "HEARTBEAT":
            self.last_heartbeat = time.monotonic()
            if self.current_operation == "freeze":
                self.set_status("Desactivá Modo de desarrollador y esperá el indicador verde", "#d59b2b")
                self.set_connection("ESPERANDO", "#d59b2b")
                self.footer_text.set("FIJAR GPS: desactivá Modo de desarrollador, pero NO desconectes el cable hasta ver el indicador verde.")
            elif self.joystick_direction is None and not self.route_active:
                self.set_status("Ubicación simulada activa", GREEN)
                self.set_connection("WI-FI CONECTADO" if self.current_mode == "wifi" else "CABLE CONECTADO", GREEN)
        elif value.startswith("POSITION:"):
            self.last_heartbeat = time.monotonic()
            try:
                raw_latitude, raw_longitude = value.removeprefix("POSITION:").split(",", 1)
                self.current_coords = (float(raw_latitude), float(raw_longitude))
                self._update_joystick_coords()
            except ValueError:
                pass
        elif value.startswith("MOVE_ERROR:"):
            self._stop_move()
            self.set_status("No se pudo aplicar el movimiento", "#c45a4a")
        elif value == "RESTORING":
            self.set_connection("RESTAURANDO", "#d59b2b")
            self.set_status("Restaurando GPS real...", "#d59b2b")
        elif value == "RESTORED":
            self._stop_route(close_window=True)
            self._close_joystick()
            self.active = False
            self.fixed = False
            self.reconnecting = False
            self.restore_succeeded = True
            self.set_status("GPS verdadero restaurado", GREEN)
            self.set_connection("GPS REAL", GREEN)
            messagebox.showinfo(
                "Ojo GPS",
                "GPS real restaurado correctamente. Ya podés desconectar el iPhone.",
            )
        elif value.startswith("ERROR:"):
            self._stop_route(close_window=True)
            self._close_joystick()
            self.joystick_button.configure(state="disabled")
            self.route_button.configure(state="disabled")
            if self.current_operation == "clear":
                self.restore_succeeded = False
            if self.current_operation == "freeze":
                self._close_fix_tutorial()
                self.active = False
                self.reconnecting = False
                self.set_status("iPhone desconectado; confirmá el procedimiento", "#d59b2b")
                self.set_connection("COMPROBANDO", "#d59b2b")
            else:
                self.set_status("No se pudo conectar", "#c45a4a")
                self.set_connection("DESCONECTADO", "#c94f45")
            if self.current_operation == "maintain" and self.current_mode == "wifi" and self.current_coords is not None:
                self.reconnecting = True
            elif self.current_operation != "freeze" and not self.reconnecting:
                extra = "\n\nConectá brevemente el iPhone o abrí el puente Wi-Fi y volvé a intentar." if self.current_operation == "clear" else "\n\nEl GPS real no fue modificado."
                error_text = value.removeprefix("ERROR:")
                if "InvalidServiceError" in error_text or "dvtservicehub" in error_text:
                    error_text = (
                        "No se pudo abrir el servicio de desarrollo del iPhone.\n\n"
                        "1. Activá Modo de desarrollador en el iPhone.\n"
                        "2. Dejalo desbloqueado.\n"
                        "3. Desconectá y volvé a conectar el cable.\n"
                        "4. Esperá el semáforo verde antes de pulsar Fijar GPS."
                    )
                messagebox.showerror("Ojo GPS", error_text + extra)

    def _reset_controls(self) -> None:
        self._close_fix_tutorial()
        self._stop_route(close_window=True)
        self._close_joystick()
        self.active = False
        self.last_heartbeat = 0.0
        self.reconnecting = False
        self.reconnect_attempts = 0
        self.current_coords = None
        self.bridge_started_at = 0.0
        self.bridge = None
        self.activate_button.configure(state="normal")
        self.joystick_button.configure(state="disabled")
        self.route_button.configure(state="disabled")
        self.fix_button.configure(state="disabled")
        self.search_button.configure(state="normal")
        self.restore_button.configure(state="normal")
        self.set_connection("DESCONECTADO", "#c94f45")
        if self.connection_mode.get() == "wifi":
            self.footer_text.set("Wi-Fi: conectá el iPhone por cable para preparar el puente; luego ambos deben quedar en la misma red.")
        else:
            self.footer_text.set("Uso normal por cable: conectá y desbloqueá el iPhone con Modo de desarrollador activo.")

    def close(self) -> None:
        if self.place_clock_job is not None:
            try:
                self.root.after_cancel(self.place_clock_job)
            except tk.TclError:
                pass
            self.place_clock_job = None
        self._close_fix_tutorial()
        self._stop_route(close_window=True)
        self._close_joystick()
        if self.fixed:
            if not messagebox.askyesno(
                "Cerrar Ojo GPS",
                "La ubicación fija seguirá activa en el iPhone. ¿Cerrar la aplicación?",
            ):
                return
            self.root.destroy()
            return
        if self.bridge is not None and self.bridge.poll() is None:
            if not messagebox.askyesno("Cerrar Ojo GPS", "Se restaurará el GPS verdadero antes de cerrar. ¿Continuar?"):
                return
            try:
                if self.bridge.stdin is not None:
                    self.bridge.stdin.write("RESTORE\n")
                    self.bridge.stdin.flush()
                self.bridge.wait(timeout=15)
            except Exception:
                try:
                    self.bridge.terminate()
                except Exception:
                    pass
        self.root.destroy()


def main() -> None:
    if len(sys.argv) >= 2 and sys.argv[1] == "--generar-codigo":
        if (
            len(sys.argv) < 3
            or not sys.argv[2].isdigit()
            or not 0 < int(sys.argv[2]) <= MAX_ACTIVATION_DAYS
        ):
            print(
                f"Uso: ojo_gps_app.py --generar-codigo <cantidad de dias, entre 1 y {MAX_ACTIVATION_DAYS}> [--admin]"
            )
            return
        days = int(sys.argv[2])
        admin = len(sys.argv) >= 4 and sys.argv[3] == "--admin"
        print(f"Código de activación válido por {days} días (desde que se use){' - ADMIN' if admin else ''}:")
        print(_generate_activation_code(days, admin=admin))
        return
    ok, is_admin, expires = _check_activation()
    if not ok:
        return
    root = tk.Tk()
    OjoGPSApp(root, is_admin=is_admin, expires=expires)
    root.mainloop()


if __name__ == "__main__":
    main()
