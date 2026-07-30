#!/bin/bash
# Funciones compartidas por los scripts .command de Ojo GPS para Mac.
# Este archivo no se ejecuta solo: los demas scripts lo cargan con "source"
# para no repetir la misma logica en cuatro lugares distintos.

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

# Sin esto, instalar Python (Homebrew) o pymobiledevice3 (que a veces necesita
# compilar su dependencia "cryptography" si no hay un paquete ya armado para
# esta Mac) falla con un error de compilador/enlazador dificil de entender
# ("linking with cc failed", errores de Rust/cargo) que no menciona nunca la
# causa real. Chequearlo antes evita ese rodeo y va directo al cartel de Apple.
ensure_command_line_tools() {
    if xcode-select -p >/dev/null 2>&1; then
        return 0
    fi
    echo "Hace falta instalar las Herramientas de línea de comandos de Apple" >&2
    echo "(un componente gratis de macOS, se usa para compilar; es un paso" >&2
    echo "único, no tiene que ver con Ojo GPS en particular)." >&2
    echo >&2
    xcode-select --install >/dev/null 2>&1
    echo "Te debería haber aparecido un cartel para instalarlas (revisá si" >&2
    echo "quedó atrás de esta ventana, o en Ajustes del Sistema > General >" >&2
    echo "Actualización de software si no aparece ningún cartel). Aceptalo," >&2
    echo "esperá a que termine de instalar (puede demorar varios minutos)," >&2
    echo "y volvé a abrir Ojo GPS." >&2
    return 1
}

pip_install() {
    local python_bin="$1"
    shift
    local err_file
    err_file="$(mktemp)"
    "$python_bin" -m pip install --upgrade "$@" 2>"$err_file"
    local status=$?
    if [ $status -ne 0 ] && grep -qi "externally-managed-environment" "$err_file"; then
        # Python de Homebrew suele bloquear pip install directo; --break-system-packages
        # es seguro aca porque instalamos en el Python dedicado de Ojo GPS, no en uno
        # que uses para otra cosa.
        "$python_bin" -m pip install --upgrade --break-system-packages "$@"
        status=$?
    elif [ $status -ne 0 ]; then
        cat "$err_file" >&2
    fi
    rm -f "$err_file"
    return $status
}

# Igual que pip_install, pero exige que ya exista un paquete compilado
# (wheel) para esta Mac en vez de dejar que pip compile desde cero si no lo
# encuentra. pymobiledevice3 y Pillow dependen de paquetes con partes en C o
# Rust (cryptography, entre otros); compilarlos a mano necesita Xcode +
# OpenSSL + a veces Rust, una cadena larga y fragil que casi nunca hace
# falta porque ya existen wheels para Mac en PyPI. Si de verdad no hubiera
# ninguno para esta Mac puntual, preferimos el error claro y rapido de pip
# ("no matching distribution") antes que dejarla intentar compilar y fallar
# recien despues de varios minutos con un error de Rust/OpenSSL.
pip_install_binary_only() {
    local python_bin="$1"
    shift
    local err_file
    err_file="$(mktemp)"
    "$python_bin" -m pip install --upgrade --only-binary=:all: "$@" 2>"$err_file"
    local status=$?
    if [ $status -ne 0 ] && grep -qi "externally-managed-environment" "$err_file"; then
        "$python_bin" -m pip install --upgrade --break-system-packages --only-binary=:all: "$@"
        status=$?
    elif [ $status -ne 0 ]; then
        cat "$err_file" >&2
    fi
    rm -f "$err_file"
    return $status
}

# Instala Python 3.13 (via Homebrew) y las dependencias de Ojo GPS si hace
# falta, imprimiendo el progreso en pantalla. Al final imprime por stdout el
# nombre del interprete listo para usar (para capturarlo con "$(...)"); todo
# el resto de la salida informativa va a stderr para no mezclarse con eso.
# Devuelve 1 si algo fallo (el motivo ya quedo impreso).
ensure_ojo_gps_ready() {
    if ! ensure_command_line_tools; then
        return 1
    fi

    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local python_bin
    python_bin="$(find_python)"

    if [ -z "$python_bin" ]; then
        echo "No se encontro Python 3.13. Instalando..." >&2
        if command -v brew >/dev/null 2>&1; then
            echo "Instalando Python 3.13 con Homebrew (puede demorar varios minutos)..." >&2
            if ! brew install python@3.13; then
                echo "La instalacion con Homebrew fallo." >&2
                return 1
            fi
        else
            echo "No se encontro Homebrew, necesario para instalar Python 3.13 automaticamente." >&2
            echo >&2
            echo "1. Instalalo desde https://brew.sh (copia el comando de esa pagina en esta" >&2
            echo "   misma Terminal) y volve a abrir Ojo GPS." >&2
            echo "   Alternativa sin Homebrew: instala Python 3.13 manualmente desde" >&2
            echo "   https://www.python.org/downloads/macos/ y volve a abrir Ojo GPS." >&2
            return 1
        fi
        python_bin="$(find_python)"
        if [ -z "$python_bin" ]; then
            echo "Python se instalo pero no se pudo encontrar. Cerra esta ventana, abri" >&2
            echo "una Terminal nueva y volve a intentar." >&2
            return 1
        fi
    fi

    if ! "$python_bin" -c "import pymobiledevice3" >/dev/null 2>&1; then
        echo "Instalando el puente del iPhone (esto puede demorar varios minutos)..." >&2
        echo "Instalando compatibilidad LZFSE para Ojo GPS..." >&2
        if ! pip_install "$python_bin" --no-deps "$script_dir/lzfse_stub"; then
            echo "La instalacion no pudo completarse." >&2
            return 1
        fi
        echo "Instalando pymobiledevice3..." >&2
        if ! pip_install_binary_only "$python_bin" pymobiledevice3; then
            echo "La instalacion no pudo completarse (no se encontro un paquete ya" >&2
            echo "compilado para esta Mac). Revisa el detalle de arriba." >&2
            return 1
        fi
    fi

    if ! "$python_bin" -c "import PIL" >/dev/null 2>&1; then
        echo "Instalando Pillow (necesario para Street View)..." >&2
        if ! pip_install_binary_only "$python_bin" pillow; then
            echo "La instalacion no pudo completarse (no se encontro un paquete ya" >&2
            echo "compilado para esta Mac). Revisa el detalle de arriba." >&2
            return 1
        fi
    fi

    echo "$python_bin"
    return 0
}
