@echo off
title Ojo GPS - Puente Wi-Fi
color 0A
echo ==============================================
echo        OJO GPS - PUENTE WI-FI
echo ==============================================
echo.
echo Deja esta ventana abierta mientras uses Ojo GPS.
echo La PC y el iPhone deben estar en la misma red Wi-Fi.
echo Cuando termines, podes cerrar esta ventana.
echo.
py -3.13 -m pymobiledevice3 remote tunneld --protocol tcp --no-usb --no-usbmux --no-mobdev2 --wifi
echo.
echo El puente se detuvo. Presiona una tecla para cerrar.
pause >nul
