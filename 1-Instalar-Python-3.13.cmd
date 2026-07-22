@echo off
title Ojo GPS - Instalar requisitos Wi-Fi
color 0A
echo ==============================================
echo    OJO GPS - PREPARAR PYTHON 3.13 PARA WI-FI
echo ==============================================
echo.
echo Este proceso instala Python 3.13 y el puente del iPhone.
echo Puede demorar varios minutos.
echo.
py -3.13 -c "import sys" >nul 2>nul
if not errorlevel 1 goto INSTALAR_PUENTE

where winget >nul 2>nul
if errorlevel 1 goto SIN_WINGET

echo [1/4] Instalando Python 3.13...
winget install --id Python.Python.3.13 --exact --source winget --scope user --accept-package-agreements --accept-source-agreements
if errorlevel 1 goto ERROR_INSTALACION

:INSTALAR_PUENTE
echo.
echo [2/4] Actualizando el instalador de paquetes...
py -3.13 -m pip install --upgrade pip
if errorlevel 1 goto ERROR_INSTALACION

echo.
echo [3/4] Instalando pymobiledevice3...
echo Instalando compatibilidad LZFSE para Ojo GPS...
py -3.13 -m pip install --upgrade --no-deps "%~dp0lzfse_stub"
if errorlevel 1 goto ERROR_INSTALACION

echo Instalando el puente del iPhone...
py -3.13 -m pip install --upgrade pymobiledevice3
if errorlevel 1 goto ERROR_INSTALACION

echo.
echo [4/4] Instalando Pillow (necesario para Street View)...
py -3.13 -m pip install --upgrade pillow
if errorlevel 1 goto ERROR_INSTALACION

echo.
echo ==============================================
echo INSTALACION COMPLETA
echo Ya podes cerrar esta ventana y abrir Ojo GPS.
echo ==============================================
pause
exit /b 0

:SIN_WINGET
echo No se encontro winget.
echo Abri Microsoft Store, instala Python 3.13 y luego ejecuta nuevamente este archivo.
pause
exit /b 1

:ERROR_INSTALACION
echo.
echo La instalacion no pudo completarse.
echo Saca una foto de esta pantalla y enviala.
pause
exit /b 1
