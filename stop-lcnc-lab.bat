@echo off
title LCNC Lab - Stop
color 1F

echo.
echo ============================================================
echo   STOPPING LCNC LAB STACK
echo ============================================================
echo.

set LAB_DIR=E:\lcnc-lab

if not exist "%LAB_DIR%\docker-compose.yml" (
    color 4F
    echo [ERROR] docker-compose.yml not found in: %LAB_DIR%
    pause
    exit /b 1
)

cd /d "%LAB_DIR%"

echo Stopping all containers (your work is saved)...
echo.
docker compose stop
echo.
echo ============================================================
echo   All services stopped. Your data is preserved.
echo   Run start-lcnc-lab.bat to start again next session.
echo ============================================================
echo.
pause
