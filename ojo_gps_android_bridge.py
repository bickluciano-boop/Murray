import subprocess
import sys

ADB = "adb"
ACTION_SET_LOCATION = "app.ojogps.android.SET_LOCATION"
ACTION_STOP = "app.ojogps.android.STOP"
CREATE_NO_WINDOW = 0x08000000 if sys.platform == "win32" else 0


def _run(args: list[str]) -> str:
    result = subprocess.run(
        [ADB, *args],
        capture_output=True,
        text=True,
        timeout=15,
        creationflags=CREATE_NO_WINDOW,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or f"adb {' '.join(args)} falló")
    return result.stdout.strip()


def is_adb_available() -> bool:
    try:
        _run(["version"])
        return True
    except (RuntimeError, FileNotFoundError, OSError):
        return False


def list_devices() -> list[str]:
    output = _run(["devices"])
    devices = []
    for line in output.splitlines()[1:]:
        line = line.strip()
        if line.endswith("\tdevice"):
            devices.append(line.split("\t")[0])
    return devices


def install_apk(apk_path: str) -> None:
    _run(["install", "-r", apk_path])


def set_location(latitude: float, longitude: float) -> None:
    _run([
        "shell", "am", "broadcast",
        "-a", ACTION_SET_LOCATION,
        "-e", "lat", f"{latitude:.7f}",
        "-e", "lon", f"{longitude:.7f}",
    ])


def stop_location() -> None:
    _run(["shell", "am", "broadcast", "-a", ACTION_STOP])
