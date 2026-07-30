#!/bin/bash
cd "$(dirname "$0")" || exit 1

echo "=============================================="
echo "        OJO GPS - PUENTE WI-FI (MAC)"
echo "=============================================="
echo
echo "Deja esta ventana abierta mientras uses Ojo GPS."
echo "La Mac y el iPhone deben estar en la misma red Wi-Fi."
echo "Cuando termines, podes cerrar esta ventana."
echo
echo "Te va a pedir tu contraseña de Mac: hace falta para crear el tunel de red."
echo

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

sudo "$PYTHON_BIN" -m pymobiledevice3 remote tunneld --protocol tcp --no-usb --no-usbmux --no-mobdev2 --wifi

echo
echo "El puente se detuvo. Presiona Enter para cerrar."
read -r _
