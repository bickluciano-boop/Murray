#!/bin/bash
cd "$(dirname "$0")" || exit 1

# command -v encuentra el "python3" de mentira que trae macOS de fabrica (solo
# existe para ofrecer instalar las Herramientas de Xcode), asi que no alcanza
# con que el nombre exista: hay que confirmar que ese Python arranca de verdad.
find_python() {
    for candidate in python3.13 python3; do
        if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c "import sys" >/dev/null 2>&1; then
            echo "$candidate"
            return 0
        fi
    done
    return 1
}

PYTHON_BIN="$(find_python)"
if [ -z "$PYTHON_BIN" ]; then
    echo "No se encontro Python. Ejecuta primero 1-Instalar-Python-Mac.command."
    read -r -p "Presiona Enter para cerrar..." _
    exit 1
fi

# A diferencia de Windows (que puede lanzar pythonw.exe sin ventana), en Mac
# no hay forma de abrir un .command sin que quede una ventana de Terminal
# visible mientras Ojo GPS esta abierto. Es una limitacion del sistema, no de
# la app: se puede minimizar la Terminal, pero no cerrarla mientras uses Ojo GPS.
exec "$PYTHON_BIN" ojo_gps_app.py
