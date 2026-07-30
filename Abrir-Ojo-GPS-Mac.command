#!/bin/bash
cd "$(dirname "$0")" || exit 1
source "./ojo_gps_mac_common.sh"

PYTHON_BIN="$(ensure_ojo_gps_ready)"
if [ $? -ne 0 ] || [ -z "$PYTHON_BIN" ]; then
    echo
    echo "No se pudo preparar Ojo GPS. Revisa el mensaje de arriba y volve a intentar."
    read -r -p "Presiona Enter para cerrar..." _
    exit 1
fi

# A diferencia de Windows (que puede lanzar pythonw.exe sin ventana), en Mac
# no hay forma de abrir un .command sin que quede una ventana de Terminal
# visible mientras Ojo GPS esta abierto. Es una limitacion del sistema, no de
# la app: se puede minimizar la Terminal, pero no cerrarla mientras uses Ojo GPS.
exec "$PYTHON_BIN" ojo_gps_app.py
