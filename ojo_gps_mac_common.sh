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
    # ">&2 2>err_file", en ese orden, manda la salida normal de pip (todo el
    # "Collecting...", "Successfully installed...") a la terminal, y separado
    # capura solo los errores en err_file. Sin esto, ese texto de progreso
    # terminaria mezclado con lo que esta funcion devuelve por stdout a quien
    # la llama con "$(...)" (por ejemplo, ensure_ojo_gps_ready mas abajo).
    "$python_bin" -m pip install --upgrade "$@" >&2 2>"$err_file"
    local status=$?
    if [ $status -ne 0 ] && grep -qi "externally-managed-environment" "$err_file"; then
        # Python de Homebrew suele bloquear pip install directo; --break-system-packages
        # es seguro aca porque instalamos en el Python dedicado de Ojo GPS, no en uno
        # que uses para otra cosa.
        "$python_bin" -m pip install --upgrade --break-system-packages "$@" >&2
        status=$?
    elif [ $status -ne 0 ]; then
        cat "$err_file" >&2
    fi
    rm -f "$err_file"
    return $status
}

# Igual que pip_install, pero exige que ya exista un paquete compilado
# (wheel) para el/los paquetes indicados en only_binary_spec (por ejemplo
# "cryptography", o ":all:" para todos los que se instalen en este comando)
# en vez de dejar que pip compile desde cero si no lo encuentra. cryptography
# (dependencia de pymobiledevice3) tiene partes en Rust; compilarla a mano
# necesita Xcode + OpenSSL + a veces Rust, una cadena larga y fragil que casi
# nunca hace falta porque ya existen wheels para Mac en PyPI.
#
# OJO: no usar ":all:" cuando el paquete principal que se instala (por
# ejemplo pymobiledevice3) no publica wheels para versiones recientes — pip
# terminaria aceptando la unica version vieja que sí tenga wheel, sin avisar,
# en vez de la version real y actual (asi paso con pymobiledevice3 1.0.0, un
# paquete de otro proposito completamente distinto que casualmente tenia
# wheel). Por eso pymobiledevice3 se instala pidiendo el wheel solo para
# "cryptography", dejando que pymobiledevice3 en si se resuelva a su version
# real (aunque eso signifique compilarlo, ya que no tiene partes en C: es
# puro Python, no necesita compilador). Pillow sí publica wheels reales para
# todas sus versiones vigentes, asi que ahi ":all:" es seguro.
pip_install_binary_only() {
    local python_bin="$1"
    local only_binary_spec="$2"
    shift 2
    local err_file
    err_file="$(mktemp)"
    # Ver el comentario en pip_install sobre por que la salida normal de pip
    # va a la terminal (>&2) y no se deja mezclar con el stdout de esta función.
    "$python_bin" -m pip install --upgrade --only-binary="$only_binary_spec" "$@" >&2 2>"$err_file"
    local status=$?
    if [ $status -ne 0 ] && grep -qi "externally-managed-environment" "$err_file"; then
        "$python_bin" -m pip install --upgrade --break-system-packages --only-binary="$only_binary_spec" "$@" >&2
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
            if ! brew install python@3.13 >&2; then
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

    # Se chequea el submodulo puntual que usa Ojo GPS, no solo "import
    # pymobiledevice3": existe en PyPI un paquete viejo, de otro autor y
    # proposito (una herramienta de reversing de binarios, version 1.0.0),
    # que casualmente se llama igual y SI importa con "import
    # pymobiledevice3" sin tirar error. Si alguna vez terminó instalado ese
    # en vez del real (nos paso, ver PENDIENTES.md), este chequeo mas
    # especifico lo detecta igual como "no instalado" y fuerza a reinstalar
    # el correcto.
    if ! "$python_bin" -c "from pymobiledevice3.remote.userspace_tunnel import UserspaceRsdTunnel" >/dev/null 2>&1; then
        echo "Instalando el puente del iPhone (esto puede demorar varios minutos)..." >&2
        echo "Instalando compatibilidad LZFSE para Ojo GPS..." >&2
        if ! pip_install "$python_bin" --no-deps "$script_dir/lzfse_stub"; then
            echo "La instalacion no pudo completarse." >&2
            return 1
        fi
        echo "Instalando pymobiledevice3..." >&2
        # Solo "cryptography" (una dependencia) necesita forzarse a un wheel
        # ya compilado; pymobiledevice3 en si no publica wheels para
        # versiones recientes, asi que forzarlo tambien terminaria
        # instalando una version vieja e incorrecta (ver comentario arriba
        # de pip_install_binary_only). Es pura Python, no necesita
        # compilador propio.
        if ! pip_install_binary_only "$python_bin" cryptography pymobiledevice3; then
            echo "La instalacion no pudo completarse. Revisa el detalle de arriba." >&2
            return 1
        fi
    fi

    if ! "$python_bin" -c "import PIL" >/dev/null 2>&1; then
        echo "Instalando Pillow (necesario para Street View)..." >&2
        if ! pip_install_binary_only "$python_bin" ":all:" pillow; then
            echo "La instalacion no pudo completarse (no se encontro un paquete ya" >&2
            echo "compilado para esta Mac). Revisa el detalle de arriba." >&2
            return 1
        fi
    fi

    echo "$python_bin"
    return 0
}
