#!/bin/bash
# actualizar_mac_ubicacion.sh - Ojo Guard en la Mac: ubicacion REAL de macOS (CoreLocation) en vez de la aproximada por internet.
#
# Hace tres cosas (en este orden) y se detiene si una falla, sin dejar nada a medias:
#   1) Instala la biblioteca pyobjc-framework-CoreLocation para tu usuario (python3 -m pip install --user).
#   2) Comprueba que la app OjoGuardCompu (ver instalar_mac_permisos.sh) la puede cargar.
#   3) Baja el programa nuevo (v0.7.1), verifica su huella, guarda una copia del anterior y reinicia el lanzador.
# Despues macOS te pregunta si OjoGuardCompu puede usar tu ubicacion: tocas Permitir.
#
# Uso:   bash actualizar_mac_ubicacion.sh           (actualiza)
#        bash actualizar_mac_ubicacion.sh --volver  (vuelve al programa anterior)

APP="$HOME/Applications/OjoGuardCompu.app"
CARPETA="$HOME/Library/Application Support/OjoGuardCompu"
SCRIPT="$CARPETA/ojo_guard_compu.py"
AGENTE="$HOME/Library/LaunchAgents/app.ojoguard.compu.plist"
COPIA="$SCRIPT.bak-0.6.1"
URL="https://raw.githubusercontent.com/bickluciano-boop/Murray/9d17552ff41e9f3915c56c1ae44a65a923b8d114/scripts/compu/ojo_guard_compu.py"
HUELLA="2e6c217011de5ae742d56b54ac6100719c81fd973d73b14ccd70ea59c16e2fd5"

fallar() { echo ""; echo "NO SE CAMBIO EL PROGRAMA: $*"; exit 1; }
reiniciar() {
  launchctl unload "$AGENTE" 2>/dev/null
  pkill -f ojo_guard_compu.py 2>/dev/null
  launchctl load -w "$AGENTE" 2>&1
  sleep 5
}

if [ "$(uname -s)" != "Darwin" ]; then fallar "esto es solo para Mac."; fi

if [ "${1:-}" = "--volver" ]; then
  [ -f "$COPIA" ] || fallar "no hay copia anterior en $COPIA"
  cp "$COPIA" "$SCRIPT" && reiniciar && echo "Listo: volvio el programa anterior."
  exit 0
fi

echo "1) Revisando..."
[ -d "$APP" ] || fallar "no esta la app $APP. Primero corre instalar_mac_permisos.sh."
[ -f "$SCRIPT" ] || fallar "no encuentro $SCRIPT."
PYHOME="$(python3 -c 'import sys;print(sys.prefix)' 2>/dev/null)"
[ -n "$PYHOME" ] || fallar "no encuentro Python 3."

echo "2) Instalando la biblioteca de ubicacion de macOS (puede tardar un minuto)..."
python3 -m pip install --user --quiet pyobjc-framework-CoreLocation 2>&1 | tail -n 3
PRUEBA="$(PYTHONHOME="$PYHOME" "$APP/Contents/MacOS/OjoGuardCompu" -c 'import CoreLocation, Foundation; print("CORELOCATION_OK")' 2>&1 | tail -n 1)"
if [ "$PRUEBA" != "CORELOCATION_OK" ]; then
  fallar "la app no pudo cargar CoreLocation (salida: $PRUEBA). Mandame esta pantalla."
fi
echo "  La app puede usar CoreLocation."

echo "3) Bajando el programa nuevo (v0.7.1)..."
TMP="$(mktemp -t ojoguard.XXXXXX)"
curl -fsSL -o "$TMP" "$URL" || { rm -f "$TMP"; fallar "no se pudo bajar el programa."; }
if [ "$(shasum -a 256 "$TMP" | cut -d' ' -f1)" != "$HUELLA" ]; then
  rm -f "$TMP"
  fallar "el archivo bajo mal (la huella no coincide)."
fi
[ -f "$COPIA" ] || cp "$SCRIPT" "$COPIA"
cp "$TMP" "$SCRIPT" && rm -f "$TMP"
reiniciar
if pgrep -f ojo_guard_compu.py >/dev/null 2>&1; then
  echo "  El programa nuevo esta corriendo."
else
  cp "$COPIA" "$SCRIPT"
  reiniciar
  fallar "el programa nuevo no arranco; deje el anterior. Mandame esta pantalla y el final de:  tail -n 15 \"$CARPETA/log.txt\""
fi

echo ""
echo "LISTO. Ahora, con la pantalla de la Mac a la vista:"
echo "  1) Desde el celular, en el panel, toca 'Ubicar ahora' en la Mac."
echo "  2) Si aparece un cartel pidiendo permiso de ubicacion para OjoGuardCompu, toca Permitir."
echo "  3) Si la primera vez no llega, toca 'Ubicar ahora' otra vez."
echo "Para volver al programa anterior:  bash actualizar_mac_ubicacion.sh --volver"
