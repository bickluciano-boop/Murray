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

PYTHON_BIN="python3.13"
command -v "$PYTHON_BIN" >/dev/null 2>&1 || PYTHON_BIN="python3"

sudo "$PYTHON_BIN" -m pymobiledevice3 remote tunneld --protocol tcp --no-usb --no-usbmux --no-mobdev2 --wifi

echo
echo "El puente se detuvo. Presiona Enter para cerrar."
read -r _
