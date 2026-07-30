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

"$PYTHON_BIN" ojo_gps_app.py --generar-codigo "$DIAS"
echo
echo "Copiale ese codigo tal cual, con los guiones."
read -r -p "Presiona Enter para cerrar..." _
