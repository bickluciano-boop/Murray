#!/bin/bash
cd "$(dirname "$0")" || exit 1
source "./ojo_gps_mac_common.sh"

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

PYTHON_BIN="$(ensure_ojo_gps_ready)"
if [ $? -ne 0 ] || [ -z "$PYTHON_BIN" ]; then
    echo
    echo "No se pudo preparar Ojo GPS. Revisa el mensaje de arriba y volve a intentar."
    read -r -p "Presiona Enter para cerrar..." _
    exit 1
fi

sudo "$PYTHON_BIN" -m pymobiledevice3 remote tunneld --protocol tcp --no-usb --no-usbmux --no-mobdev2 --wifi

echo
echo "El puente se detuvo. Presiona Enter para cerrar."
read -r _
