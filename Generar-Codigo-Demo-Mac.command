#!/bin/bash
cd "$(dirname "$0")" || exit 1
source "./ojo_gps_mac_common.sh"

echo "=============================================="
echo "  OJO GPS - GENERAR CODIGO DE ACTIVACION"
echo "=============================================="
echo
echo "Este codigo se lo das a quien va a probar Ojo GPS."
echo "Al ponerlo, la app le funciona esa cantidad de dias"
echo "a partir de ese momento (no desde hoy)."
echo
read -r -p "Cuantos dias de acceso le das? " DIAS
echo

PYTHON_BIN="$(ensure_ojo_gps_ready)"
if [ $? -ne 0 ] || [ -z "$PYTHON_BIN" ]; then
    echo
    echo "No se pudo preparar Ojo GPS. Revisa el mensaje de arriba y volve a intentar."
    read -r -p "Presiona Enter para cerrar..." _
    exit 1
fi

"$PYTHON_BIN" ojo_gps_app.py --generar-codigo "$DIAS"
echo
echo "Copiale ese codigo tal cual, con los guiones."
read -r -p "Presiona Enter para cerrar..." _
