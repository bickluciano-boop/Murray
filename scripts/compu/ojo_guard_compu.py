# -*- coding: utf-8 -*-
"""
Ojo Guard para computadora - Windows y Mac: SONAR, EVIDENCIA, UBICAR Y ARRANQUE AUTOMATICO (version 0.6)

NOVEDAD 0.6: ahora tambien corre en Mac (macOS). En Mac el sonido sale por afplay, la foto con la camara
integrada (opencv), el audio con el microfono (sounddevice) y la ubicacion es APROXIMADA por internet
(zona de la ciudad): macOS no da la ubicacion exacta a un programa de Python simple. El arranque
automatico en Mac usa un LaunchAgent. En Windows todo sigue igual que en la 0.5.

Que hace en esta etapa:
  * Vincula esta computadora con tu cuenta de Ojo Guard MS, con el mismo codigo de 6 digitos
    que usa el telefono.
  * Aparece en el panel como un dispositivo mas ("Conectado" mientras este programa corra),
    con el porcentaje de bateria.
  * HACER SONAR: al recibir la orden desde el panel, reproduce una alarma por el parlante de
    esta computadora (al volumen que tenga puesto) y se corta sola al minuto.
  * DETENER SONIDO: corta la alarma al recibir la orden.
  * LOCALIZAR AHORA: calcula la ubicacion y la manda al panel (ver "Ubicacion" mas abajo).
  * SOLICITAR EVIDENCIA: saca una foto con la camara, graba 10 segundos de audio con el microfono,
    calcula la ubicacion y lo manda todo al servidor (llega al historial del panel y por mail, igual
    que desde el telefono). Necesita las bibliotecas:  python -m pip install opencv-python-headless sounddevice
  * Cualquier otra orden (Modo perdido...) todavia no esta soportada: contesta "no soportado" al
    panel y no hace nada.

Ubicacion (en orden de preferencia, y siempre dice de donde salio):
  1. Servicio de ubicacion de Windows (usa las redes WiFi cercanas). Tiene que estar activado en
     Configuracion > Privacidad > Ubicacion. Precision tipica: decenas a cientos de metros.
  2. Si Windows no la da: ubicacion APROXIMADA por la direccion de internet (zona de la ciudad,
     varios kilometros de error). Se marca como de baja precision.
  La direccion en texto se pide a un servicio publico de mapas (OpenStreetMap) solo si hay coordenadas.

Que NO hace (a proposito): no usa la camara, ni el microfono, ni la ubicacion. Solo mira si hay
una camara conectada, para ponerlo en el nombre del dispositivo.

Uso:   python ojo_guard_compu.py                  (vincula y/o corre con ventana)
       python ojo_guard_compu.py --instalar       (arranca solo al iniciar sesion, sin ventana: Windows o Mac)
       python ojo_guard_compu.py --quitar-inicio  (saca el arranque automatico)
       python ojo_guard_compu.py --probar-evidencia (saca una foto y graba 3 s de audio de prueba, SIN enviar nada)
       python ojo_guard_compu.py --probar-ubicacion (muestra que ubicacion calcula esta computadora)
       python ojo_guard_compu.py --estado         (dice si esta vinculada, si corre, y el final del registro)
       python ojo_guard_compu.py --desvincular    (borra los datos guardados en esta computadora)
Solo usa la biblioteca estandar de Python (no hay que instalar nada).
"""
import base64
import io
import json
import math
import os
import platform
import re
import shutil
import ssl
import socket
import struct
import subprocess
import sys
import threading
import time
import traceback
import wave
import urllib.error
import urllib.request
import uuid

try:
    import winsound  # solo existe en Windows
except ImportError:
    winsound = None

VERSION = "0.6.1"
ES_MAC = (sys.platform == "darwin") or os.environ.get("OJO_FAKE_PLATFORM") == "darwin"
ES_WINDOWS = (os.name == "nt")
API_BASE = os.environ.get("OJO_API_BASE", "https://ojo-guard-ms-api.bickluciano.workers.dev")
INTERVALO_SEGUNDOS = int(os.environ.get("OJO_INTERVALO", "10"))
DURACION_SONIDO_SEGUNDOS = int(os.environ.get("OJO_DURACION_SONIDO", "60"))
if ES_MAC:
    CARPETA = os.path.join(os.path.expanduser("~"), "Library", "Application Support", "OjoGuardCompu")
else:
    CARPETA = os.path.join(os.environ.get("APPDATA") or os.path.expanduser("~"), "OjoGuardCompu")
ARCHIVO = os.path.join(CARPETA, "config.json")
ARCHIVO_ALARMA = os.path.join(CARPETA, "alarma.wav")
ARCHIVO_LOG = os.path.join(CARPETA, "log.txt")
SCRIPT_INSTALADO = os.path.join(CARPETA, "ojo_guard_compu.py")
PUERTO_CERROJO = int(os.environ.get("OJO_PUERTO_CERROJO", "47931"))
CARPETA_INICIO = os.environ.get("OJO_STARTUP_DIR") or os.path.join(
    os.environ.get("APPDATA") or os.path.expanduser("~"), "Microsoft", "Windows", "Start Menu", "Programs", "Startup")
ARCHIVO_LANZADOR = os.path.join(CARPETA_INICIO, "OjoGuardCompu.vbs")
ETIQUETA_AGENTE = "app.ojoguard.compu"
ARCHIVO_AGENTE = os.path.join(os.path.expanduser("~"), "Library", "LaunchAgents", ETIQUETA_AGENTE + ".plist")


# ------------------------------------------------------------------ utilidades
def _contexto_ssl():
    """En Mac, el Python de python.org no trae certificados: se usan los de 'certifi' si estan instalados."""
    try:
        import certifi
        return ssl.create_default_context(cafile=certifi.where())
    except Exception:
        return None


CONTEXTO_SSL = _contexto_ssl()


def hora():
    return time.strftime("%H:%M:%S")


def decir(texto):
    linea = "[" + hora() + "] " + texto
    try:
        print(linea, flush=True)
    except Exception:
        pass  # sin ventana (pythonw) no hay donde imprimir
    try:
        os.makedirs(CARPETA, exist_ok=True)
        if os.path.exists(ARCHIVO_LOG) and os.path.getsize(ARCHIVO_LOG) > 200 * 1024:
            os.replace(ARCHIVO_LOG, ARCHIVO_LOG + ".viejo")
        with open(ARCHIVO_LOG, "a", encoding="utf-8") as f:
            f.write(time.strftime("%Y-%m-%d ") + linea + "\n")
    except OSError:
        pass


def cargar_config():
    try:
        with open(ARCHIVO, "r", encoding="utf-8") as f:
            datos = json.load(f)
        return datos if isinstance(datos, dict) else {}
    except (OSError, ValueError):
        return {}


def guardar_config(datos):
    os.makedirs(CARPETA, exist_ok=True)
    temporal = ARCHIVO + ".tmp"
    with open(temporal, "w", encoding="utf-8") as f:
        json.dump(datos, f, ensure_ascii=False, indent=2)
    os.replace(temporal, ARCHIVO)


def llamar(metodo, ruta, cuerpo=None, token=None, tiempo=20):
    """Devuelve (codigo_http, json_o_dict). codigo 0 = no hubo respuesta (red caida)."""
    datos = None if cuerpo is None else json.dumps(cuerpo).encode("utf-8")
    cabeceras = {
        "accept": "application/json",
        "content-type": "application/json",
        "user-agent": "OjoGuardCompu/" + VERSION,
    }
    if token:
        cabeceras["authorization"] = "Bearer " + token
    externo = (metodo == "GET_EXTERNO")
    if externo:
        metodo = "GET"
    pedido = urllib.request.Request(ruta if externo else API_BASE + ruta, data=datos, method=metodo, headers=cabeceras)
    try:
        with urllib.request.urlopen(pedido, timeout=tiempo, context=CONTEXTO_SSL) as r:
            crudo = r.read().decode("utf-8", "replace")
            return r.status, (json.loads(crudo) if crudo else {})
    except urllib.error.HTTPError as e:
        crudo = e.read().decode("utf-8", "replace")
        try:
            return e.code, json.loads(crudo)
        except ValueError:
            return e.code, {"error": "respuesta_no_json"}
    except (urllib.error.URLError, OSError, TimeoutError, ValueError) as error:
        return 0, {"error": "sin_conexion", "detalle": type(error).__name__ + ": " + str(error)[:160]}


# ------------------------------------------------------------------ datos de la compu
def bateria():
    """Porcentaje 0-100, o None si no se puede saber."""
    if ES_MAC:
        try:
            r = subprocess.run(["pmset", "-g", "batt"], capture_output=True, text=True, timeout=10)
            m = re.search(r"(\d{1,3})%", r.stdout or "")
            return int(m.group(1)) if m else None
        except Exception:
            return None
    if os.name != "nt":
        return None
    try:
        import ctypes

        class ESTADO(ctypes.Structure):
            _fields_ = [
                ("ac", ctypes.c_ubyte),
                ("flag", ctypes.c_ubyte),
                ("porcentaje", ctypes.c_ubyte),
                ("sistema", ctypes.c_ubyte),
                ("segundos", ctypes.c_ulong),
                ("segundos_total", ctypes.c_ulong),
            ]

        e = ESTADO()
        if not ctypes.windll.kernel32.GetSystemPowerStatus(ctypes.byref(e)):
            return None
        return None if e.porcentaje == 255 else int(e.porcentaje)
    except Exception:
        return None


def hay_camara():
    """True / False / None (no se pudo saber). Solo mira si existe el dispositivo; no la enciende."""
    if ES_MAC:
        try:
            r = subprocess.run(["system_profiler", "SPCameraDataType"], capture_output=True, text=True, timeout=25)
            salida = r.stdout or ""
            return ("Model ID" in salida) or ("Unique ID" in salida)
        except Exception:
            return None
    if os.name != "nt":
        return None
    try:
        r = subprocess.run(
            ["powershell", "-NoProfile", "-Command",
             "(Get-PnpDevice -Class Camera -PresentOnly -ErrorAction SilentlyContinue | Measure-Object).Count"],
            capture_output=True, text=True, timeout=25,
        )
        return int((r.stdout or "0").strip() or "0") > 0
    except Exception:
        return None


def nombre_por_defecto():
    base = ("Mac " if ES_MAC else "Notebook ") + (platform.node() or ("Mac" if ES_MAC else "Windows"))
    camara = hay_camara()
    if camara is True:
        base += " (con camara)"
    elif camara is False:
        base += " (sin camara)"
    return base


# ------------------------------------------------------------------ sonido
_temporizador = {"hilo": None}
_afplay = {"activo": False, "proceso": None}


def _bucle_afplay(ruta):
    """Repite la alarma con afplay (macOS) hasta que _afplay['activo'] pase a False."""
    while _afplay["activo"]:
        try:
            proceso = subprocess.Popen(["afplay", ruta])
        except Exception as error:
            decir("No se pudo reproducir el sonido: " + str(error))
            _afplay["activo"] = False
            return
        _afplay["proceso"] = proceso
        proceso.wait()


def generar_alarma():
    """Crea (una vez) un WAV de unos 3 segundos con dos tonos que se alternan. Devuelve la ruta."""
    if os.path.exists(ARCHIVO_ALARMA):
        return ARCHIVO_ALARMA
    os.makedirs(CARPETA, exist_ok=True)
    tasa = 22050
    muestras = []
    for tono in (880, 660) * 4:
        for i in range(int(tasa * 0.4)):
            envolvente = min(1.0, i / 200.0, (int(tasa * 0.4) - i) / 200.0)
            muestras.append(int(30000 * envolvente * math.sin(2 * math.pi * tono * i / tasa)))
    with wave.open(ARCHIVO_ALARMA, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(tasa)
        w.writeframes(b"".join(struct.pack("<h", m) for m in muestras))
    return ARCHIVO_ALARMA


def iniciar_sonido():
    """True si la alarma quedo sonando (se repite hasta que la corten o pase el tiempo)."""
    if ES_MAC:
        if shutil.which("afplay") is None and os.environ.get("OJO_FAKE_SOUND") != "1":
            decir("No encuentro afplay en esta Mac: no se puede reproducir el sonido.")
            return False
        if os.environ.get("OJO_FAKE_SOUND") != "1":
            _afplay["activo"] = True
            threading.Thread(target=_bucle_afplay, args=(generar_alarma(),), daemon=True).start()
    elif winsound is None:
        decir("(esta computadora no es Windows: no se reproduce sonido real)")
        if os.environ.get("OJO_FAKE_SOUND") != "1":
            return False
    else:
        try:
            winsound.PlaySound(generar_alarma(), winsound.SND_FILENAME | winsound.SND_ASYNC | winsound.SND_LOOP)
        except Exception as error:
            decir("No se pudo reproducir el sonido: " + str(error))
            return False
    previo = _temporizador["hilo"]
    if previo is not None:
        previo.cancel()
    hilo = threading.Timer(DURACION_SONIDO_SEGUNDOS, cortar_por_tiempo)
    hilo.daemon = True
    hilo.start()
    _temporizador["hilo"] = hilo
    return True


def detener_sonido():
    if ES_MAC:
        _afplay["activo"] = False
        proceso = _afplay.get("proceso")
        if proceso is not None:
            try:
                proceso.terminate()
            except Exception:
                pass
            _afplay["proceso"] = None
    if winsound is not None:
        try:
            winsound.PlaySound(None, winsound.SND_PURGE)
        except Exception:
            pass
    previo = _temporizador["hilo"]
    if previo is not None:
        previo.cancel()
        _temporizador["hilo"] = None


def cortar_por_tiempo():
    decir("Paso el tiempo maximo (" + str(DURACION_SONIDO_SEGUNDOS) + " s): corto el sonido.")
    detener_sonido()


# ------------------------------------------------------------------ ubicacion
POWERSHELL_UBICACION = r"""
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Device
$w = New-Object System.Device.Location.GeoCoordinateWatcher([System.Device.Location.GeoPositionAccuracy]::High)
[void]$w.TryStart($false, [TimeSpan]::FromSeconds(15))
$t = 0
while (($w.Status -ne 'Ready') -and ($t -lt 20)) { Start-Sleep -Milliseconds 500; $t += 0.5 }
$p = $w.Position.Location
$inv = [Globalization.CultureInfo]::InvariantCulture
if ($p.IsUnknown) {
    'UNKNOWN|' + $w.Permission + '|' + $w.Status
} else {
    'OK|' + $p.Latitude.ToString($inv) + '|' + $p.Longitude.ToString($inv) + '|' + $p.HorizontalAccuracy.ToString($inv) + '|' + $p.Altitude.ToString($inv) + '|' + $p.Course.ToString($inv)
}
$w.Stop()
"""


def _numero(texto):
    try:
        v = float(texto)
        return None if v != v else v  # NaN -> None
    except (TypeError, ValueError):
        return None


def ubicacion_de_windows():
    """(lat, lon, precision_m, altitud, rumbo) o (None, motivo)."""
    falso = os.environ.get("OJO_FAKE_LOCATION")
    if falso:
        if falso.startswith("UNKNOWN"):
            return None, "windows_sin_ubicacion"
        lat, lon, prec = [float(x) for x in falso.split(",")]
        return (lat, lon, prec, None, None), None
    if os.name != "nt":
        return None, "no_es_windows"
    try:
        r = subprocess.run(
            ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", POWERSHELL_UBICACION],
            capture_output=True, text=True, timeout=45, creationflags=0x08000000,
        )
    except Exception as error:
        return None, "powershell_fallo:" + type(error).__name__
    lineas = [l.strip() for l in (r.stdout or "").splitlines() if l.strip()]
    if not lineas:
        return None, "powershell_sin_respuesta"
    partes = lineas[-1].split("|")
    if partes[0] == "OK" and len(partes) >= 6:
        lat, lon = _numero(partes[1]), _numero(partes[2])
        if lat is None or lon is None:
            return None, "windows_coordenadas_invalidas"
        prec = _numero(partes[3])
        return (lat, lon, prec if prec and prec > 0 else 100.0, _numero(partes[4]), _numero(partes[5])), None
    permiso = partes[1] if len(partes) > 1 else "?"
    return None, "windows_ubicacion_desactivada" if permiso == "Denied" else "windows_sin_ubicacion"


def ubicacion_por_internet():
    """Ubicacion APROXIMADA por la direccion IP: sirve para saber en que zona esta, no en que calle."""
    if os.environ.get("OJO_SIN_IP") == "1":
        return None
    http, r = llamar("GET_EXTERNO", "https://ipwho.is/", tiempo=10)
    if http != 200 or not r.get("success", False):
        return None
    lat, lon = _numero(r.get("latitude")), _numero(r.get("longitude"))
    if lat is None or lon is None:
        return None
    lugar = ", ".join(x for x in (r.get("city"), r.get("region"), r.get("country")) if x)
    return lat, lon, lugar


def direccion_en_texto(lat, lon):
    """Calle y numero aproximados desde OpenStreetMap. Si no se puede, None (no es critico)."""
    if os.environ.get("OJO_SIN_DIRECCION") == "1":
        return None
    http, r = llamar(
        "GET_EXTERNO",
        "https://nominatim.openstreetmap.org/reverse?format=jsonv2&zoom=18&accept-language=es&lat=%.6f&lon=%.6f" % (lat, lon),
        tiempo=10)
    texto = r.get("display_name") if http == 200 else None
    return str(texto) if texto else None


def confianza(precision):
    # Mismos cortes que locationConfidence() de la app del telefono.
    return "alta" if precision <= 20 else "media" if precision <= 80 else "baja"


def obtener_ubicacion():
    """(dict_para_el_servidor, None) o (None, motivo)."""
    ahora = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    datos, motivo = ubicacion_de_windows()
    if datos:
        lat, lon, prec, alt, rumbo = datos
        direccion = direccion_en_texto(lat, lon)
        return {
            "latitude": lat, "longitude": lon, "accuracy": round(prec), "capturedAt": ahora,
            "altitude": alt, "heading": rumbo, "address": direccion, "confidence": confianza(prec),
            "source": "windows",
        }, None
    ip = ubicacion_por_internet()
    if ip:
        lat, lon, lugar = ip
        return {
            "latitude": lat, "longitude": lon, "accuracy": 5000, "capturedAt": ahora,
            "altitude": None, "heading": None,
            "address": "Aproximada por internet (zona, no calle)" + (": " + lugar if lugar else ""),
            "confidence": "baja", "source": "ip",
        }, None
    return None, motivo or "ubicacion_no_disponible"


def probar_ubicacion():
    print("Calculando la ubicacion (puede tardar hasta un minuto)...")
    ubic, motivo = obtener_ubicacion()
    if not ubic:
        print("No se pudo obtener ubicacion. Motivo: " + str(motivo))
        if ES_MAC:
            print("En Mac la ubicacion exacta no esta disponible: se usa la aproximada por internet. Revisa que haya conexion.")
        if "windows" in str(motivo):
            print("Revisa: Configuracion de Windows > Privacidad > Ubicacion: 'Ubicacion' activada y")
            print("'Permitir que las aplicaciones de escritorio accedan a tu ubicacion' activada.")
        return 1
    print("Origen:     " + ("servicio de ubicacion de Windows (WiFi)" if ubic["source"] == "windows" else "APROXIMADA por internet (zona de la ciudad)"))
    print("Latitud:    " + str(ubic["latitude"]))
    print("Longitud:   " + str(ubic["longitude"]))
    print("Precision:  +-" + str(ubic["accuracy"]) + " m (" + ubic["confidence"] + ")")
    print("Direccion:  " + str(ubic["address"]))
    print("Mapa:       https://www.google.com/maps/search/?api=1&query=" + str(ubic["latitude"]) + "," + str(ubic["longitude"]))
    return 0


# ------------------------------------------------------------------ evidencia (foto + audio)
SEGUNDOS_DE_AUDIO = int(os.environ.get("OJO_SEGUNDOS_AUDIO", "10"))
FRECUENCIA_AUDIO = 16000
# JPEG minimo valido (1x1) y WAV corto: solo para las pruebas con OJO_FAKE_CAMERA / OJO_FAKE_AUDIO.
_JPEG_FALSO = base64.b64decode(
    "/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////"
    "2wBDAf//////////////////////////////////////////////////////////////////////////////////////wAARCAABAAEDASIAAhEBAxEB/8QA"
    "FQABAQAAAAAAAAAAAAAAAAAAAAf/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFAEBAAAAAAAAAAAAAAAAAAAAAP/EABQRAQAAAAAAAAAAAAAAAAAAAAD/2gAM"
    "AwEAAhEDEQA/AL+AB//Z")


def capturar_foto():
    """Devuelve (bytes_jpeg, None) o (None, motivo). Usa la primera camara que abra y deje leer."""
    if os.environ.get("OJO_FAKE_CAMERA") == "1":
        return _JPEG_FALSO, None
    if os.environ.get("OJO_FAKE_CAMERA") == "0":
        return None, "camara_no_disponible"
    try:
        import cv2
    except ImportError:
        return None, "falta_opencv"
    ultimo_motivo = "camara_no_disponible"
    for indice in (0, 1, 2):
        for backend in ((cv2.CAP_DSHOW, cv2.CAP_ANY) if os.name == "nt" else (cv2.CAP_AVFOUNDATION, cv2.CAP_ANY) if ES_MAC else (cv2.CAP_ANY,)):
            camara = cv2.VideoCapture(indice, backend)
            try:
                if not camara.isOpened():
                    continue
                cuadro = None
                for _ in range(20):          # las primeras imagenes salen oscuras mientras se ajusta la exposicion
                    ok, leido = camara.read()
                    if ok and leido is not None:
                        cuadro = leido
                    time.sleep(0.1)
                if cuadro is None:
                    ultimo_motivo = "camara_sin_imagen"
                    continue
                alto, ancho = cuadro.shape[:2]
                if ancho > 1280:
                    escala = 1280.0 / ancho
                    cuadro = cv2.resize(cuadro, (1280, int(alto * escala)))
                ok, jpeg = cv2.imencode(".jpg", cuadro, [int(cv2.IMWRITE_JPEG_QUALITY), 85])
                if ok:
                    return jpeg.tobytes(), None
            finally:
                camara.release()
    return None, ultimo_motivo


def empezar_audio(segundos):
    """Empieza a grabar sin bloquear. Devuelve un objeto para terminar_audio(), o None si no se pudo."""
    if os.environ.get("OJO_FAKE_AUDIO") == "1":
        return {"falso": True, "inicio": time.time()}
    if os.environ.get("OJO_FAKE_AUDIO") == "0":
        return None
    try:
        import sounddevice as sd
        datos = sd.rec(int(segundos * FRECUENCIA_AUDIO), samplerate=FRECUENCIA_AUDIO, channels=1, dtype="int16")
        return {"sd": sd, "datos": datos, "inicio": time.time()}
    except Exception as error:
        decir("No se pudo empezar a grabar audio: " + type(error).__name__ + ": " + str(error))
        return None


def terminar_audio(grabacion, segundos):
    """Espera lo que falte y devuelve los bytes de un WAV, o None."""
    if grabacion is None:
        return None
    if grabacion.get("falso"):
        espera = segundos - (time.time() - grabacion["inicio"])
        if espera > 0:
            time.sleep(espera)
        crudo = struct.pack("<h", 0) * 160
    else:
        try:
            grabacion["sd"].wait()
            crudo = grabacion["datos"].tobytes()
        except Exception as error:
            decir("Fallo la grabacion de audio: " + type(error).__name__)
            return None
    salida = io.BytesIO()
    with wave.open(salida, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(FRECUENCIA_AUDIO)
        w.writeframes(crudo)
    return salida.getvalue()


def probar_evidencia():
    print("Sacando una foto y grabando 3 segundos de audio. NO se envia nada.")
    grabacion = empezar_audio(3)
    foto, motivo = capturar_foto()
    audio = terminar_audio(grabacion, 3)
    if foto:
        destino = os.path.join(CARPETA, "prueba-foto.jpg")
        os.makedirs(CARPETA, exist_ok=True)
        with open(destino, "wb") as f:
            f.write(foto)
        print("Foto:   OK (" + str(len(foto) // 1024) + " KB). Guardada en " + destino)
    else:
        print("Foto:   NO se pudo (" + str(motivo) + ")")
        if motivo == "falta_opencv":
            print("        Instala:  python -m pip install opencv-python-headless")
    if audio:
        destino = os.path.join(CARPETA, "prueba-audio.wav")
        with open(destino, "wb") as f:
            f.write(audio)
        print("Audio:  OK (" + str(len(audio) // 1024) + " KB). Guardado en " + destino)
    else:
        print("Audio:  NO se pudo (revisa que el microfono este permitido: en Windows, Configuracion > Privacidad > Microfono; en Mac, Ajustes del Sistema > Privacidad y seguridad > Microfono)")
    return 0 if foto else 1


def tomar_evidencia(config):
    """Foto + audio + ubicacion, enviados al servidor. Devuelve (attemptId, None) o (None, motivo)."""
    ocurrio = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    intento = "win-" + uuid.uuid4().hex
    grabacion = empezar_audio(SEGUNDOS_DE_AUDIO)
    foto, motivo = capturar_foto()
    if not foto:
        terminar_audio(grabacion, 0)  # corta la grabacion si habia empezado
        return None, motivo or "camara_no_disponible"
    ubic, _ = obtener_ubicacion()
    audio = terminar_audio(grabacion, SEGUNDOS_DE_AUDIO)
    cuerpo = {
        "deviceId": config["deviceId"], "attemptId": intento, "occurredAt": ocurrio,
        "frontImage": base64.b64encode(foto).decode("ascii"),
    }
    if audio:
        cuerpo["audio"] = base64.b64encode(audio).decode("ascii")
        cuerpo["audioMimeType"] = "audio/wav"
        cuerpo["audioDurationSeconds"] = SEGUNDOS_DE_AUDIO
    if ubic:
        cuerpo["location"] = ubic
    http, r = llamar("POST", "/api/alert", cuerpo, token=config["accessToken"], tiempo=90)
    if http == 200:
        decir("Evidencia enviada: foto " + str(len(foto) // 1024) + " KB, audio " + ("si" if audio else "no") + ", ubicacion " + ("si" if ubic else "no") + ".")
        return intento, None
    return None, "no_se_pudo_enviar_la_evidencia_" + str(http) + (":" + str(r.get("error")) if isinstance(r, dict) and r.get("error") else "")


# ------------------------------------------------------------------ vinculacion
def pedir_codigo(email):
    codigo, r = llamar("POST", "/api/remote/access/request", {"email": email, "accessType": "company"})
    if codigo == 0:
        decir("No hay conexion con el servidor. Revisa internet e intenta de nuevo.")
        detalle = str(r.get("detalle", ""))
        if detalle:
            decir("Detalle tecnico: " + detalle)
        if "CERTIFICATE" in detalle.upper():
            decir("Falta instalar los certificados de seguridad. Corre:  python3 -m pip install --user certifi")
        return False
    if codigo >= 400:
        decir("El servidor no acepto el pedido de codigo (" + str(codigo) + "): " + str(r.get("error", "")))
        return False
    decir("Te enviamos un codigo de 6 digitos a " + email + ". Revisa tu correo (tambien en spam).")
    return True


def vincular(config):
    """Devuelve True si quedo vinculada y con token guardado."""
    if not config.get("deviceId"):
        config["deviceId"] = "win-" + uuid.uuid4().hex
        guardar_config(config)
    if not config.get("email"):
        email = input("Correo de tu cuenta de Ojo Guard (el mismo del telefono): ").strip().lower()
        if "@" not in email:
            decir("Ese correo no parece valido.")
            return False
        config["email"] = email
        guardar_config(config)
    if not config.get("deviceName"):
        sugerido = nombre_por_defecto()
        escrito = input("Nombre de esta computadora [" + sugerido + "]: ").strip()
        config["deviceName"] = escrito or sugerido
        guardar_config(config)

    if not pedir_codigo(config["email"]):
        return False
    codigo = "".join(c for c in input("Escribi el codigo de 6 digitos: ") if c.isdigit())
    if len(codigo) != 6:
        decir("El codigo tiene que tener 6 digitos.")
        return False

    http, r = llamar("POST", "/api/native/enroll", {
        "email": config["email"], "code": codigo, "deviceId": config["deviceId"],
        "deviceName": config["deviceName"], "platform": ("macos" if ES_MAC else "windows"), "accessType": "company",
    })
    if http == 200 and r.get("linked") and r.get("accessToken"):
        config["accessToken"] = r["accessToken"]
        guardar_config(config)
        decir("Listo: esta computadora quedo vinculada.")
        return True
    if http == 409 and r.get("error") == "approval_required":
        decir("La computadora quedo PENDIENTE de autorizacion.")
        decir("Abri Ojo Guard MS, entra a Dispositivos y toca 'Autorizar este dispositivo'.")
        decir("Despues volve a correr este programa: te va a pedir un codigo nuevo y ahi queda vinculada.")
        return False
    if http == 401:
        decir("Codigo incorrecto o vencido (dura 15 minutos). Volve a intentarlo.")
        return False
    if http == 429:
        decir("Demasiados intentos. Espera unos minutos.")
        return False
    if http == 0:
        decir("No hay conexion con el servidor. Revisa internet.")
        return False
    decir("No se pudo vincular (" + str(http) + "): " + str(r.get("error", "")))
    return False


# ------------------------------------------------------------------ ciclo principal
ORDENES_VISTAS = set()


def normalizar_tipo(valor):
    """Mismos sinonimos que usa la app del telefono (normalizeRemoteCommandKind en domain.ts).
    El panel manda 'alarm' para Hacer sonar, no 'ring'."""
    v = str(valor)
    if v in ("ring", "alarm"):
        return "ring"
    if v in ("stop-ring", "stop-alarm", "silence"):
        return "stop-ring"
    if v in ("lost-mode", "lost"):
        return "lost-mode"
    if v in ("lost-off", "lost-mode-off", "unlost", "found"):
        return "lost-mode-off"
    if v in ("locate", "location", "auto-locate"):
        return "locate"
    if v in ("scan-nearby", "nearby", "bluetooth"):
        return "scan-nearby"
    if v in ("capture-evidence", "capture"):
        return "capture-evidence"
    return v


def responder(config, id_orden, estado, error=None, ubicacion=None, evidencia=None):
    cuerpo = {
        "deviceId": config["deviceId"], "commandId": id_orden, "status": estado,
        "occurredAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    if error:
        cuerpo["error"] = error
    if ubicacion:
        cuerpo["location"] = ubicacion
    if evidencia:
        cuerpo["evidenceAttemptId"] = evidencia
    return llamar("POST", "/api/native/commands/status", cuerpo, token=config["accessToken"])


def contestar_ordenes(config):
    http, r = llamar("GET", "/api/native/commands?deviceId=" + config["deviceId"], token=config["accessToken"])
    if http == 401:
        return "no_autorizado"
    if http != 200:
        return "error"
    for orden in r.get("commands", []):
        id_orden = orden.get("id")
        if not id_orden or id_orden in ORDENES_VISTAS:
            continue
        ORDENES_VISTAS.add(id_orden)
        tipo = normalizar_tipo(orden.get("kind"))
        if tipo == "ring":
            decir("Orden: HACER SONAR.")
            responder(config, id_orden, "received")
            if iniciar_sonido():
                responder(config, id_orden, "executed")
                decir("Sonando (se corta sola a los " + str(DURACION_SONIDO_SEGUNDOS) + " s o con 'Detener sonido').")
            else:
                responder(config, id_orden, "failed", "no_se_pudo_reproducir_el_sonido")
        elif tipo == "capture-evidence":
            decir("Orden: SOLICITAR EVIDENCIA (foto, " + str(SEGUNDOS_DE_AUDIO) + " s de audio y ubicacion).")
            responder(config, id_orden, "received")
            intento, motivo = tomar_evidencia(config)
            if intento:
                responder(config, id_orden, "executed", evidencia=intento)
            else:
                responder(config, id_orden, "failed", error=motivo)
                decir("No se pudo tomar la evidencia: " + str(motivo))
        elif tipo == "locate":
            decir("Orden: UBICAR.")
            responder(config, id_orden, "received")
            ubic, motivo = obtener_ubicacion()
            if ubic:
                responder(config, id_orden, "executed", ubicacion=ubic)
                decir("Ubicacion enviada (" + ubic["source"] + ", +-" + str(ubic["accuracy"]) + " m).")
            else:
                responder(config, id_orden, "failed", error=motivo)
                decir("No se pudo obtener la ubicacion: " + str(motivo))
        elif tipo == "stop-ring":
            decir("Orden: DETENER SONIDO.")
            detener_sonido()
            responder(config, id_orden, "executed")
        else:
            decir("Llego la orden '" + str(orden.get("kind")) + "'. Todavia no esta soportada en la computadora; aviso al panel.")
            responder(config, id_orden, "failed", "no_soportado_en_computadora_todavia")
    return "ok"


def ciclo(config):
    decir("Conectada. Intervalo: " + str(INTERVALO_SEGUNDOS) + " s. Para salir: Ctrl+C.")
    ultimo_estado_bateria = 0.0
    fallas = 0
    while True:
        try:
            estado = contestar_ordenes(config)
            if estado == "no_autorizado":
                decir("El servidor ya no reconoce esta computadora (la quitaron o hay que vincularla de nuevo).")
                config.pop("accessToken", None)
                guardar_config(config)
                decir("Corre el programa a mano otra vez para vincularla con un codigo nuevo.")
                return
            if estado == "error":
                fallas += 1
                if fallas in (1, 5) or fallas % 20 == 0:
                    decir("Sin respuesta del servidor (intento " + str(fallas) + "). Sigo probando.")
            else:
                if fallas:
                    decir("Se recupero la conexion.")
                fallas = 0
                if time.time() - ultimo_estado_bateria >= 300:
                    nivel = bateria()
                    llamar("POST", "/api/native/device/status",
                           {"deviceId": config["deviceId"], "battery": nivel}, token=config["accessToken"])
                    ultimo_estado_bateria = time.time()
                    decir("Estado enviado. Bateria: " + (str(nivel) + "%" if nivel is not None else "no disponible"))
        except Exception:
            # Un error inesperado no tiene que matar el programa: queda en el registro y sigue.
            decir("Error inesperado, sigo: " + traceback.format_exc().strip().splitlines()[-1])
        time.sleep(INTERVALO_SEGUNDOS)


# ------------------------------------------------------------------ arranque automatico
_cerrojo = {"socket": None}


def tomar_cerrojo():
    """Evita dos copias a la vez: la primera ocupa un puerto local, la segunda no puede."""
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        s.bind(("127.0.0.1", PUERTO_CERROJO))
    except OSError:
        s.close()
        return False
    s.listen(1)
    _cerrojo["socket"] = s
    return True


def hay_otra_copia():
    if tomar_cerrojo():
        _cerrojo["socket"].close()
        _cerrojo["socket"] = None
        return False
    return True


def ejecutable_sin_ventana():
    if ES_MAC:
        return sys.executable
    carpeta = os.path.dirname(sys.executable)
    candidato = os.path.join(carpeta, "pythonw.exe")
    return candidato if os.path.exists(candidato) else sys.executable


def instalar_inicio():
    config = cargar_config()
    if not config.get("accessToken"):
        print("Primero hay que vincular esta computadora: corre  python ojo_guard_compu.py  sin opciones y segui los pasos.")
        return 1
    os.makedirs(CARPETA, exist_ok=True)
    origen = os.path.abspath(__file__)
    if os.path.abspath(origen) != os.path.abspath(SCRIPT_INSTALADO):
        shutil.copy2(origen, SCRIPT_INSTALADO)
    ejecutable = ejecutable_sin_ventana()
    if ES_MAC:
        return instalar_inicio_mac(ejecutable)
    os.makedirs(CARPETA_INICIO, exist_ok=True)
    vbs = (
        'Set sh = CreateObject("WScript.Shell")\r\n'
        'sh.Run """' + ejecutable + '"" ""' + SCRIPT_INSTALADO + '""", 0, False\r\n'
    )
    with open(ARCHIVO_LANZADOR, "w", encoding=("mbcs" if os.name == "nt" else "utf-8"), newline="") as f:
        f.write(vbs)
    print("Listo. Se va a iniciar sola, sin ventana, cada vez que inicies sesion en Windows.")
    print("  Programa:  " + SCRIPT_INSTALADO)
    print("  Lanzador:  " + ARCHIVO_LANZADOR)
    print("  Registro:  " + ARCHIVO_LOG)
    if hay_otra_copia():
        print("Ya hay una copia corriendo ahora; no inicio otra.")
    elif os.name == "nt":
        flags = 0x00000008 | 0x08000000  # DETACHED_PROCESS | CREATE_NO_WINDOW
        subprocess.Popen([ejecutable, SCRIPT_INSTALADO], creationflags=flags, close_fds=True)
        print("La inicie ahora mismo. En unos segundos tendria que figurar 'Conectado' en el panel.")
    return 0


def instalar_inicio_mac(ejecutable):
    plist = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
        '<plist version="1.0">\n<dict>\n'
        '  <key>Label</key><string>' + ETIQUETA_AGENTE + '</string>\n'
        '  <key>ProgramArguments</key>\n  <array>\n'
        '    <string>' + ejecutable + '</string>\n'
        '    <string>' + SCRIPT_INSTALADO + '</string>\n  </array>\n'
        '  <key>RunAtLoad</key><true/>\n'
        '  <key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>\n'
        '</dict>\n</plist>\n')
    os.makedirs(os.path.dirname(ARCHIVO_AGENTE), exist_ok=True)
    with open(ARCHIVO_AGENTE, "w", encoding="utf-8") as f:
        f.write(plist)
    print("Listo. Se va a iniciar sola, sin ventana, cada vez que inicies sesion en la Mac.")
    print("  Programa:  " + SCRIPT_INSTALADO)
    print("  Lanzador:  " + ARCHIVO_AGENTE)
    print("  Registro:  " + ARCHIVO_LOG)
    if hay_otra_copia():
        print("Ya hay una copia corriendo ahora; no inicio otra. (Al cerrar sesion y volver a entrar arranca sola.)")
    else:
        try:
            subprocess.run(["launchctl", "unload", ARCHIVO_AGENTE], capture_output=True, timeout=20)
            subprocess.run(["launchctl", "load", "-w", ARCHIVO_AGENTE], capture_output=True, timeout=20)
            print("La inicie ahora mismo. En unos segundos tendria que figurar 'Conectado' en el panel.")
        except Exception as error:
            print("No pude iniciarla ahora (" + type(error).__name__ + "). Va a arrancar al volver a iniciar sesion.")
    return 0


def quitar_inicio():
    if ES_MAC:
        try:
            subprocess.run(["launchctl", "unload", ARCHIVO_AGENTE], capture_output=True, timeout=20)
        except Exception:
            pass
        try:
            os.remove(ARCHIVO_AGENTE)
            print("Sacado el arranque automatico.")
        except OSError:
            print("No habia arranque automatico instalado.")
        print("Si hay una copia corriendo ahora, cerrala con:  pkill -f ojo_guard_compu.py")
        return 0
    try:
        os.remove(ARCHIVO_LANZADOR)
        print("Sacado el arranque automatico.")
    except OSError:
        print("No habia arranque automatico instalado.")
    print("Si hay una copia corriendo ahora, cerrala desde el Administrador de tareas (pythonw.exe) o con:  taskkill /f /im pythonw.exe")
    return 0


def mostrar_estado():
    config = cargar_config()
    print("Vinculada:        " + ("si" if config.get("accessToken") else "no"))
    print("Nombre:           " + str(config.get("deviceName", "-")))
    print("Corriendo ahora:  " + ("si" if hay_otra_copia() else "no"))
    print("Arranque automatico: " + ("instalado" if os.path.exists(ARCHIVO_AGENTE if ES_MAC else ARCHIVO_LANZADOR) else "no instalado"))
    print("Ultimas lineas del registro (" + ARCHIVO_LOG + "):")
    try:
        with open(ARCHIVO_LOG, "r", encoding="utf-8") as f:
            for linea in f.read().splitlines()[-8:]:
                print("  " + linea)
    except OSError:
        print("  (todavia no hay registro)")
    return 0


def main():
    if "--desvincular" in sys.argv:
        try:
            os.remove(ARCHIVO)
            print("Datos borrados de esta computadora. En el panel, quitala con 'Quitar este dispositivo'.")
        except OSError:
            print("No habia datos guardados.")
        print("Si habias instalado el arranque automatico, sacalo con:  python ojo_guard_compu.py --quitar-inicio")
        return 0
    if "--probar-ubicacion" in sys.argv:
        return probar_ubicacion()
    if "--probar-evidencia" in sys.argv:
        return probar_evidencia()
    if "--instalar" in sys.argv:
        return instalar_inicio()
    if "--quitar-inicio" in sys.argv:
        return quitar_inicio()
    if "--estado" in sys.argv:
        return mostrar_estado()
    print("Ojo Guard para computadora - version " + VERSION)
    if not tomar_cerrojo():
        decir("Ya hay otra copia corriendo en esta computadora. No inicio otra.")
        return 0
    config = cargar_config()
    try:
        if not config.get("accessToken"):
            interactivo = (sys.stdin is not None and sys.stdin.isatty()) or os.environ.get("OJO_FORZAR_INTERACTIVO") == "1"
            if not interactivo:
                decir("Esta computadora no esta vinculada y no hay ventana para pedir el codigo. Corre el programa a mano para vincularla.")
                return 1
            if not vincular(config):
                return 1
        ciclo(config)
    except KeyboardInterrupt:
        detener_sonido()
        print("\nPrograma detenido. La computadora queda vinculada; vuelve a abrirlo cuando quieras.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
