#!/bin/bash
# mac_ubicacion_como_app.sh - Ojo Guard en la Mac: abrir OjoGuardCompu.app como la abre macOS (con "open"), para que CoreLocation la reconozca y pida permiso.
#
# Diagnostico (23/10/2026): el registro dijo  mac_sin_ubicacion_permiso_0_error_1  = macOS nunca pregunto por la ubicacion y CoreLocation rechazo el pedido.
# La camara y el microfono andan con cualquier programa firmado, pero la ubicacion exige que la app este registrada y se abra por LaunchServices.
#
# Que hace:
#   1) Agrega a la app los textos de permiso de ubicacion que le faltan (los tres que usa macOS segun la version) y el PYTHONHOME.
#   2) La vuelve a firmar y la registra en macOS.
#   3) Cambia el lanzador automatico para abrirla con "open" (guarda copia del anterior).
# AVISO: al volver a firmar, macOS puede pedir de nuevo el permiso de camara y microfono (una vez). Es normal: tocar Permitir.
#
# Uso:   bash mac_ubicacion_como_app.sh           (aplica)
#        bash mac_ubicacion_como_app.sh --volver  (vuelve al lanzador anterior)

APP="$HOME/Applications/OjoGuardCompu.app"
CARPETA="$HOME/Library/Application Support/OjoGuardCompu"
SCRIPT="$CARPETA/ojo_guard_compu.py"
AGENTE="$HOME/Library/LaunchAgents/app.ojoguard.compu.plist"
COPIA="$AGENTE.bak-open"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

fallar() { echo ""; echo "NO SE CAMBIO EL LANZADOR: $*"; exit 1; }
reiniciar() {
  launchctl unload "$AGENTE" 2>/dev/null
  pkill -f ojo_guard_compu.py 2>/dev/null
  sleep 1
  launchctl load -w "$AGENTE" 2>&1
  sleep 8
}

if [ "$(uname -s)" != "Darwin" ]; then fallar "esto es solo para Mac."; fi

if [ "${1:-}" = "--volver" ]; then
  [ -f "$COPIA" ] || fallar "no hay copia anterior en $COPIA"
  cp "$COPIA" "$AGENTE" && reiniciar && echo "Listo: volvio el lanzador anterior."
  exit 0
fi

echo "1) Revisando..."
[ -d "$APP" ] || fallar "no esta la app $APP. Primero corre instalar_mac_permisos.sh."
[ -f "$AGENTE" ] || fallar "no encuentro el lanzador $AGENTE."
[ -f "$SCRIPT" ] || fallar "no encuentro $SCRIPT."
PYHOME="$(python3 -c 'import sys;print(sys.prefix)' 2>/dev/null)"
[ -n "$PYHOME" ] || fallar "no encuentro Python 3."
sw_vers -productVersion 2>/dev/null | sed 's/^/  macOS /'

echo "2) Preparando la app (textos de permiso de ubicacion y PYTHONHOME)..."
python3 - "$APP/Contents/Info.plist" "$PYHOME" <<'PY' || fallar "no pude editar el Info.plist de la app."
import plistlib, sys
ruta, pyhome = sys.argv[1], sys.argv[2]
with open(ruta, "rb") as f:
    d = plistlib.load(f)
texto = "Ojo Guard usa la ubicacion para mostrar donde esta esta computadora."
d["NSLocationWhenInUseUsageDescription"] = texto
d["NSLocationUsageDescription"] = texto
d["NSLocationAlwaysAndWhenInUseUsageDescription"] = texto
d["LSEnvironment"] = {"PYTHONHOME": pyhome}
d["LSUIElement"] = True
with open(ruta, "wb") as f:
    plistlib.dump(d, f)
PY
codesign --force --sign - "$APP" >/dev/null 2>&1 || fallar "no pude volver a firmar la app."
[ -x "$LSREGISTER" ] && "$LSREGISTER" -f "$APP" >/dev/null 2>&1
echo "  App actualizada, firmada y registrada."

echo "3) Cambiando el lanzador automatico para abrirla con open..."
[ -f "$COPIA" ] || cp "$AGENTE" "$COPIA"
launchctl unload "$AGENTE" 2>/dev/null
pkill -f ojo_guard_compu.py 2>/dev/null
cat > "$AGENTE" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>app.ojoguard.compu</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/open</string>
    <string>-W</string>
    <string>-n</string>
    <string>$APP</string>
    <string>--args</string>
    <string>$SCRIPT</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>
</dict>
</plist>
PLIST
plutil -lint "$AGENTE" >/dev/null 2>&1 || { cp "$COPIA" "$AGENTE"; reiniciar; fallar "el lanzador nuevo salio mal; dejo el anterior."; }
reiniciar
if pgrep -f ojo_guard_compu.py >/dev/null 2>&1; then
  echo "  El programa esta corriendo, abierto como app."
else
  cp "$COPIA" "$AGENTE"
  reiniciar
  fallar "el programa no arranco abierto como app; deje el lanzador anterior. Mandame esta pantalla y el final de:  tail -n 15 \"$CARPETA/log.txt\""
fi

echo ""
echo "LISTO. Ahora, con la pantalla de la Mac a la vista:"
echo "  1) Desde el celular, en el panel, toca 'Ubicar ahora' en la Mac."
echo "  2) Si aparece un cartel de ubicacion (o de camara/microfono) para OjoGuardCompu, toca Permitir."
echo "  3) Si la primera vez no llega, toca 'Ubicar ahora' otra vez."
echo "Para volver al lanzador anterior:  bash mac_ubicacion_como_app.sh --volver"
