#!/bin/bash
# instalar_mac_permisos.sh - Ojo Guard en la Mac: que el programa que corre solo tenga SU PROPIO permiso de camara y microfono.
#
# Problema (23/10/2026): al correr desde la Terminal la foto y el audio andan, pero el programa que arranca solo (LaunchAgent) no figura en
# Ajustes del Sistema > Privacidad > Camara / Microfono, y macOS le niega el acceso (camara_no_disponible, PortAudioError -9986).
# Solucion: se arma una "app" chica (OjoGuardCompu.app, con su nombre y sus textos de permiso) que lleva una copia del Python instalado, y el
# lanzador automatico corre ESA app. Asi macOS le pregunta permiso a "OjoGuardCompu" y lo agrega a la lista.
#
# Uso:   bash instalar_mac_permisos.sh          (instala)
#        bash instalar_mac_permisos.sh --volver (deja todo como estaba)
# No toca la clave ni la configuracion de la computadora. Si algo falla antes de cambiar el lanzador, no cambia nada.

APP="$HOME/Applications/OjoGuardCompu.app"
CARPETA="$HOME/Library/Application Support/OjoGuardCompu"
SCRIPT="$CARPETA/ojo_guard_compu.py"
AGENTE="$HOME/Library/LaunchAgents/app.ojoguard.compu.plist"
RESPALDO="$AGENTE.bak-permisos"

avisar() { echo "  $*"; }
fallar() { echo ""; echo "NO SE CAMBIO NADA IMPORTANTE: $*"; exit 1; }

if [ "$(uname -s)" != "Darwin" ]; then fallar "esto es solo para Mac."; fi

if [ "${1:-}" = "--volver" ]; then
  echo "Volviendo a como estaba..."
  launchctl unload "$AGENTE" 2>/dev/null
  if [ -f "$RESPALDO" ]; then cp "$RESPALDO" "$AGENTE" && avisar "Lanzador anterior restaurado."; fi
  pkill -f ojo_guard_compu.py 2>/dev/null
  launchctl load -w "$AGENTE" 2>/dev/null
  rm -rf "$APP"
  echo "Listo."
  exit 0
fi

echo "1) Revisando que este todo lo necesario..."
[ -f "$SCRIPT" ] || fallar "no encuentro $SCRIPT. Primero hay que instalar el programa con:  python3 ojo_guard_compu.py --instalar"
[ -f "$AGENTE" ] || fallar "no encuentro el lanzador $AGENTE. Primero corre:  python3 ojo_guard_compu.py --instalar"
command -v codesign >/dev/null 2>&1 || fallar "falta la herramienta codesign de macOS."
PYBIN="$(python3 -c 'import os,sys;print(os.path.realpath(sys.executable))' 2>/dev/null)"
PYHOME="$(python3 -c 'import sys;print(sys.prefix)' 2>/dev/null)"
[ -x "$PYBIN" ] || fallar "no encuentro Python 3."
case "$PYHOME" in
  /Library/Frameworks/Python.framework/*) ;;
  *) fallar "este Python ($PYHOME) no es el de python.org. Avisame y lo adapto." ;;
esac
avisar "Python: $PYBIN"
avisar "Prefijo: $PYHOME"

echo "2) Armando la app OjoGuardCompu..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" || fallar "no pude crear $APP"
cp "$PYBIN" "$APP/Contents/MacOS/OjoGuardCompu" || fallar "no pude copiar Python."
chmod +x "$APP/Contents/MacOS/OjoGuardCompu"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>app.ojoguard.compu</string>
  <key>CFBundleName</key><string>OjoGuardCompu</string>
  <key>CFBundleDisplayName</key><string>Ojo Guard</string>
  <key>CFBundleExecutable</key><string>OjoGuardCompu</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleShortVersionString</key><string>0.6.1</string>
  <key>LSUIElement</key><true/>
  <key>NSCameraUsageDescription</key><string>Ojo Guard usa la camara para sacar una foto cuando pedis evidencia desde el panel.</string>
  <key>NSMicrophoneUsageDescription</key><string>Ojo Guard graba unos segundos de audio cuando pedis evidencia desde el panel.</string>
  <key>NSLocationWhenInUseUsageDescription</key><string>Ojo Guard usa la ubicacion para mostrar donde esta esta computadora.</string>
</dict>
</plist>
PLIST
codesign --force --sign - "$APP" >/dev/null 2>&1 || fallar "no pude firmar la app (codesign)."
avisar "App creada y firmada: $APP"

echo "3) Probando que la app anda con tus paquetes (opencv, sounddevice, certifi)..."
PRUEBA="$(PYTHONHOME="$PYHOME" "$APP/Contents/MacOS/OjoGuardCompu" -c 'import cv2, sounddevice, certifi; print("PAQUETES_OK")' 2>&1 | tail -n 1)"
if [ "$PRUEBA" != "PAQUETES_OK" ]; then
  rm -rf "$APP"
  fallar "la app no pudo cargar los paquetes (salida: $PRUEBA). Mandame esta pantalla."
fi
avisar "La app corre y carga los paquetes."

echo "4) Cambiando el lanzador automatico..."
[ -f "$RESPALDO" ] || cp "$AGENTE" "$RESPALDO"
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
    <string>$APP/Contents/MacOS/OjoGuardCompu</string>
    <string>$SCRIPT</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict><key>PYTHONHOME</key><string>$PYHOME</string></dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>
</dict>
</plist>
PLIST
plutil -lint "$AGENTE" >/dev/null 2>&1 || { cp "$RESPALDO" "$AGENTE"; launchctl load -w "$AGENTE" 2>/dev/null; fallar "el lanzador nuevo salio mal; dejo el anterior."; }
launchctl load -w "$AGENTE" 2>&1
sleep 6
if pgrep -f ojo_guard_compu.py >/dev/null 2>&1; then
  avisar "El programa esta corriendo con la app nueva."
else
  echo ""
  echo "El programa no arranco. Dejo el lanzador anterior."
  launchctl unload "$AGENTE" 2>/dev/null
  cp "$RESPALDO" "$AGENTE"
  launchctl load -w "$AGENTE" 2>/dev/null
  echo "Mandame esta pantalla y el final de:  tail -n 15 \"$CARPETA/log.txt\""
  exit 1
fi

echo ""
echo "LISTO. Ahora, con la pantalla de la Mac a la vista:"
echo "  1) Desde el celular, en el panel, toca Evidencia en la Mac."
echo "  2) Si aparece un cartel pidiendo permiso de camara o microfono para OjoGuardCompu, toca Permitir."
echo "  3) Mira si aparece 'OjoGuardCompu' en Ajustes del Sistema > Privacidad y seguridad > Camara y Microfono."
echo "Para dejar todo como estaba:  bash instalar_mac_permisos.sh --volver"
