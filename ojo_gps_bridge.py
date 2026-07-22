import asyncio
import sys
import threading

from pymobiledevice3.remote.userspace_tunnel import UserspaceRsdTunnel
from pymobiledevice3.services.dvt.instruments.dvt_provider import DvtProvider
from pymobiledevice3.services.dvt.instruments.location_simulation import LocationSimulation
from pymobiledevice3.tunneld.api import get_tunneld_devices


def status(value: str) -> None:
    print(f"OJO_STATUS:{value}", flush=True)


async def maintain_location(rsd, latitude: float, longitude: float) -> None:
    async with DvtProvider(rsd) as dvt:
        async with LocationSimulation(dvt) as location:
            await location.set(latitude, longitude)
            status("ACTIVE")

            loop = asyncio.get_running_loop()
            last_refresh = loop.time()
            commands: asyncio.Queue[str] = asyncio.Queue()

            def read_commands() -> None:
                for line in sys.stdin:
                    loop.call_soon_threadsafe(commands.put_nowait, line.strip())
                loop.call_soon_threadsafe(commands.put_nowait, "RESTORE")

            threading.Thread(target=read_commands, daemon=True).start()

            while True:
                try:
                    command = await asyncio.wait_for(commands.get(), timeout=2.0)
                except asyncio.TimeoutError:
                    # Mantener el indicador vivo sin castigar el servicio del iPhone.
                    # Un refresco cada 15 s alcanza para sostener la simulación.
                    if loop.time() - last_refresh >= 15.0:
                        await location.set(latitude, longitude)
                        last_refresh = loop.time()
                    status("HEARTBEAT")
                    continue

                if command.upper() == "RESTORE" or not command:
                    break
                if not command.upper().startswith("MOVE:"):
                    continue

                try:
                    raw_latitude, raw_longitude = command.split(":", 1)[1].split(",", 1)
                    latitude = float(raw_latitude)
                    longitude = float(raw_longitude)
                    await location.set(latitude, longitude)
                    last_refresh = loop.time()
                    status(f"POSITION:{latitude:.7f},{longitude:.7f}")
                except (ValueError, IndexError):
                    status("MOVE_ERROR:Coordenadas de movimiento invalidas")

            status("RESTORING")
            await location.clear()
            status("RESTORED")


async def execute(rsd, latitude: float, longitude: float, operation: str) -> None:
    if operation == "clear":
        async with DvtProvider(rsd) as dvt:
            async with LocationSimulation(dvt) as location:
                status("RESTORING")
                await location.clear()
                status("RESTORED")
        return

    await maintain_location(rsd, latitude, longitude)


async def run_cable(latitude: float, longitude: float, operation: str) -> None:
    status("CONNECTING")
    async with UserspaceRsdTunnel() as rsd:
        await execute(rsd, latitude, longitude, operation)


async def run_wifi(latitude: float, longitude: float, operation: str) -> None:
    status("WIFI_CONNECTING")
    rsds = await get_tunneld_devices()
    if not rsds:
        raise RuntimeError("El puente Wi-Fi no encontro el iPhone")

    rsd = rsds[0]
    for extra in rsds[1:]:
        await extra.close()

    status("WIFI_FOUND")
    try:
        await execute(rsd, latitude, longitude, operation)
    finally:
        await rsd.close()


def main() -> None:
    if len(sys.argv) != 5:
        status("ERROR:Modo, operacion o coordenadas incompletas")
        raise SystemExit(2)

    mode = sys.argv[1].lower()
    operation = sys.argv[2].lower()
    try:
        latitude = float(sys.argv[3])
        longitude = float(sys.argv[4])
        if operation not in {"maintain", "clear"}:
            raise ValueError(f"Operacion desconocida: {operation}")
        if mode == "wifi":
            asyncio.run(run_wifi(latitude, longitude, operation))
        elif mode == "cable":
            asyncio.run(run_cable(latitude, longitude, operation))
        else:
            raise ValueError(f"Modo desconocido: {mode}")
    except Exception as exc:
        status(f"ERROR:{type(exc).__name__}: {exc}")
        raise SystemExit(1)


if __name__ == "__main__":
    main()
