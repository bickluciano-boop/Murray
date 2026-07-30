#!/bin/bash
cd "$(dirname "$0")" || exit 1
source "./ojo_gps_mac_common.sh"

echo "=============================================="
echo "   OJO GPS - PREPARAR PYTHON 3.13 PARA MAC"
echo "=============================================="
echo
echo "Este proceso instala Python 3.13 y el puente del iPhone."
echo "Puede demorar varios minutos."
echo

PYTHON_BIN="$(ensure_ojo_gps_ready)"
if [ $? -ne 0 ] || [ -z "$PYTHON_BIN" ]; then
    echo
    echo "La instalacion no pudo completarse."
    echo "Saca una foto de esta pantalla y enviala."
    read -r -p "Presiona Enter para cerrar..." _
    exit 1
fi

echo
echo "=============================================="
echo "INSTALACION COMPLETA"
echo "Ya podes cerrar esta ventana y abrir Ojo GPS."
echo "=============================================="
read -r -p "Presiona Enter para cerrar..." _
