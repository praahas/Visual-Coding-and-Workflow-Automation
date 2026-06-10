@echo off
title LCNC Lab - Stop
color 1F

echo.
echo ============================================================
echo   STOPPING LCNC LAB STACK
echo ============================================================
echo.

set "LAB_DIR=%USERPROFILE%\Documents\lcnc-lab"

echo   Default lab folder: %USERPROFILE%\Documents\lcnc-lab
echo.
set /p "CUSTOM_DIR=   Press Enter to use default, or type a custom path and press Enter: "
if not "%CUSTOM_DIR%"=="" set "LAB_DIR=%CUSTOM_DIR%"

:: Strip trailing backslash
if "%LAB_DIR:~-1%"=="\" set "LAB_DIR=%LAB_DIR:~0,-1%"

echo.
echo   Using lab folder: %LAB_DIR%
echo.

if not exist "%LAB_DIR%\docker-compose.yml" (
    color 4F
    echo [ERROR] docker-compose.yml not found in: %LAB_DIR%
    echo Please check the path and try again.
    echo.
    pause
    exit /b 1
)

cd /d "%LAB_DIR%"

echo   Stopping all containers (your work is saved)...
echo.
docker compose stop
echo.
echo ============================================================
echo   All services stopped. Your data is preserved.
echo   Run start-lcnc-lab.bat to start again next session.
echo ============================================================
echo.
pause
