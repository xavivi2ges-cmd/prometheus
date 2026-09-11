@echo off
title PROMETHEUS - MODO DEPURACION
cd /d "%~dp0"
echo [?] Lanzando Prometheus Suite v3.1...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "app.ps1"
echo.
echo [!] Si el programa se cerro, arriba veras el error en rojo.
pause
