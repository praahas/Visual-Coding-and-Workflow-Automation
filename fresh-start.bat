@echo off
title LCNC Lab - Fresh Start
color 1F

echo.
echo ================================================================
echo   LCNC LAB - COMPLETE FRESH START
echo   This will wipe all data and rebuild from scratch.
echo ================================================================
echo.
echo   WARNING: All existing data will be deleted.
echo   Press any key to continue or close this window to cancel.
pause >nul

set "LAB_DIR=%USERPROFILE%\Documents\lcnc-lab"

:: Allow user to provide a custom path
echo   Default lab folder: %USERPROFILE%\Documents\lcnc-lab
echo.
set /p "CUSTOM_DIR=   Press Enter to use default, or type a custom path and press Enter: "
if not "%CUSTOM_DIR%"=="" set "LAB_DIR=%CUSTOM_DIR%"

:: Strip trailing backslash if user added one
if "%LAB_DIR:~-1%"=="\" set "LAB_DIR=%LAB_DIR:~0,-1%"

echo.
echo   Using lab folder: %LAB_DIR%
echo.

cd /d "%LAB_DIR%"

echo.
echo [1/6] Stopping and removing all containers and volumes...
docker compose down -v --remove-orphans
echo      Done.
echo.

echo [2/6] Starting PostgreSQL first and waiting for it to be healthy...
docker compose up -d postgres
echo      Waiting 30 seconds for PostgreSQL to initialize...
timeout /t 30 /nobreak >nul

:WAIT_PG
docker exec lcnc_postgres pg_isready -U lcncadmin -d postgres >nul 2>&1
if errorlevel 1 (
    echo      Still waiting for PostgreSQL...
    timeout /t 5 /nobreak >nul
    goto WAIT_PG
)
echo      PostgreSQL is healthy. OK
echo.

echo [3/6] Applying UUID extensions...
docker exec lcnc_postgres psql -U lcncadmin -d postgres -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";" >nul 2>&1
docker exec lcnc_postgres psql -U lcncadmin -d postgres -c "CREATE EXTENSION IF NOT EXISTS \"pgcrypto\";" >nul 2>&1
echo      Extensions applied. OK
echo.

echo [4/6] Starting all remaining services...
docker compose up -d --remove-orphans
echo      All services started.
echo.

echo [5/6] Waiting 3 minutes for all services to initialize...
echo      (Metabase needs the most time - please be patient)
timeout /t 60 /nobreak >nul
echo      1 minute done...
timeout /t 60 /nobreak >nul
echo      2 minutes done...
timeout /t 60 /nobreak >nul
echo      3 minutes done.
echo.

echo [6/6] Container status:
echo.
docker compose ps
echo.

echo ================================================================
echo   ACCESS YOUR TOOLS
echo ================================================================
echo.
echo   NocoDB      ^>^> http://localhost:8080
echo   Appsmith    ^>^> http://localhost:8081
echo   n8n         ^>^> http://localhost:5678   (admin / admin123)
echo   Formbricks  ^>^> http://localhost:3000
echo   Node-RED    ^>^> http://localhost:1880
echo   Metabase    ^>^> http://localhost:3001   (setup wizard on first visit)
echo   Flowise     ^>^> http://localhost:3002   (admin / admin123)
echo   Mailpit     ^>^> http://localhost:8025
echo.
echo   NOTE: If Metabase still shows loading, wait 2 more minutes.
echo         It is a Java application and takes the longest to start.
echo.
pause
