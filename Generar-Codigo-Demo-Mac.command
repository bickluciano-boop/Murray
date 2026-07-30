#!/bin/bash
cd "$(dirname "$0")" || exit 1

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

PYTHON_BIN="python3.13"
command -v "$PYTHON_BIN" >/dev/null 2>&1 || PYTHON_BIN="python3"

"$PYTHON_BIN" ojo_gps_app.py --generar-codigo "$DIAS"
echo
echo "Copiale ese codigo tal cual, con los guiones."
read -r -p "Presiona Enter para cerrar..." _
