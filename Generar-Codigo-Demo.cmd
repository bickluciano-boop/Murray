@echo off
title Ojo GPS - Generar codigo de activacion
color 0A
echo ==============================================
echo   OJO GPS - GENERAR CODIGO DE ACTIVACION
echo ==============================================
echo.
echo Este codigo se lo das a quien va a probar Ojo GPS.
echo Al ponerlo, la app le funciona esa cantidad de dias
echo a partir de ese momento (no desde hoy).
echo.
set /p DIAS="Cuantos dias de acceso le das? "
echo.
py -3.13 "%~dp0ojo_gps_app.py" --generar-codigo %DIAS%
echo.
echo Copiale ese codigo tal cual, con los guiones.
pause
