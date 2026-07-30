#!/bin/bash
cd "$(dirname "$0")" || exit 1

PYTHON_BIN="python3.13"
command -v "$PYTHON_BIN" >/dev/null 2>&1 || PYTHON_BIN="python3"

if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
    echo "No se encontro Python. Ejecuta primero 1-Instalar-Python-Mac.command."
    read -r -p "Presiona Enter para cerrar..." _
    exit 1
fi

# A diferencia de Windows (que puede lanzar pythonw.exe sin ventana), en Mac
# no hay forma de abrir un .command sin que quede una ventana de Terminal
# visible mientras Ojo GPS esta abierto. Es una limitacion del sistema, no de
# la app: se puede minimizar la Terminal, pero no cerrarla mientras uses Ojo GPS.
exec "$PYTHON_BIN" ojo_gps_app.py
