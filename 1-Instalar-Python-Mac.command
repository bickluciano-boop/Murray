#!/bin/bash
cd "$(dirname "$0")" || exit 1

echo "=============================================="
echo "   OJO GPS - PREPARAR PYTHON 3.13 PARA MAC"
echo "=============================================="
echo
echo "Este proceso instala Python 3.13 y el puente del iPhone."
echo "Puede demorar varios minutos."
echo

pip_install() {
    local err_file
    err_file="$(mktemp)"
    "$PYTHON_BIN" -m pip install --upgrade "$@" 2>"$err_file"
    local status=$?
    if [ $status -ne 0 ] && grep -qi "externally-managed-environment" "$err_file"; then
        # Python de Homebrew suele bloquear pip install directo; --break-system-packages
        # es seguro aca porque instalamos en el Python dedicado de Ojo GPS, no en uno
        # que uses para otra cosa.
        "$PYTHON_BIN" -m pip install --upgrade --break-system-packages "$@"
        status=$?
    elif [ $status -ne 0 ]; then
        cat "$err_file"
    fi
    rm -f "$err_file"
    return $status
}

if command -v python3.13 >/dev/null 2>&1; then
    PYTHON_BIN="python3.13"
else
    echo "No se encontro Python 3.13."
    if command -v brew >/dev/null 2>&1; then
        echo "[1/4] Instalando Python 3.13 con Homebrew..."
        brew install python@3.13
        if [ $? -ne 0 ]; then
            echo
            echo "La instalacion no pudo completarse."
            echo "Saca una foto de esta pantalla y enviala."
            read -r -p "Presiona Enter para cerrar..." _
            exit 1
        fi
        PYTHON_BIN="python3.13"
        if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
            PYTHON_BIN="$(brew --prefix python@3.13)/bin/python3.13"
        fi
    else
        echo "No se encontro Homebrew, necesario para instalar Python 3.13 automaticamente."
        echo
        echo "1. Instalalo desde https://brew.sh (copia el comando de esa pagina en esta"
        echo "   misma Terminal) y volve a ejecutar este archivo."
        echo "   Alternativa sin Homebrew: instala Python 3.13 manualmente desde"
        echo "   https://www.python.org/downloads/macos/ y volve a ejecutar este archivo."
        read -r -p "Presiona Enter para cerrar..." _
        exit 1
    fi
fi

echo
echo "[2/4] Actualizando el instalador de paquetes..."
pip_install pip
if [ $? -ne 0 ]; then
    echo "La instalacion no pudo completarse."
    read -r -p "Presiona Enter para cerrar..." _
    exit 1
fi

echo
echo "[3/4] Instalando pymobiledevice3..."
echo "Instalando compatibilidad LZFSE para Ojo GPS..."
pip_install --no-deps "$(pwd)/lzfse_stub"
if [ $? -ne 0 ]; then
    echo "La instalacion no pudo completarse."
    read -r -p "Presiona Enter para cerrar..." _
    exit 1
fi

echo "Instalando el puente del iPhone..."
pip_install pymobiledevice3
if [ $? -ne 0 ]; then
    echo "La instalacion no pudo completarse."
    read -r -p "Presiona Enter para cerrar..." _
    exit 1
fi

echo
echo "[4/4] Instalando Pillow (necesario para Street View)..."
pip_install pillow
if [ $? -ne 0 ]; then
    echo "La instalacion no pudo completarse."
    read -r -p "Presiona Enter para cerrar..." _
    exit 1
fi

echo
echo "=============================================="
echo "INSTALACION COMPLETA"
echo "Ya podes cerrar esta ventana y abrir Ojo GPS."
echo "=============================================="
read -r -p "Presiona Enter para cerrar..." _
