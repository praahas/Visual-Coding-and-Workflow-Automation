@echo off
title LCNC Lab Starter
color 1F

echo.
echo ============================================================
echo   LOW CODE / NO CODE LAB STACK
echo   3rd Semester - CS ^& Design Engineering
echo ============================================================
echo.

:: ── Change this path if your lab folder is in a different location ──
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

:: Check if the lab folder exists
if not exist "%LAB_DIR%" (
    color 4F
    echo [ERROR] Lab folder not found at: %LAB_DIR%
    echo.
    echo Please edit this batch file and update the LAB_DIR path.
    echo.
    pause
    exit /b 1
)

:: Check if docker-compose.yml exists in the folder
if not exist "%LAB_DIR%\docker-compose.yml" (
    color 4F
    echo [ERROR] docker-compose.yml not found in: %LAB_DIR%
    echo.
    echo Make sure you placed docker-compose.yml in the lab folder.
    echo.
    pause
    exit /b 1
)

:: ── Step 1: Start Docker Desktop if not already running ─────────────
echo [1/4] Checking if Docker Desktop is running...
docker info >nul 2>&1
if not errorlevel 1 (
    echo        Docker Desktop is already running. OK
    echo.
    goto APPLY_FIX
)

echo        Docker is not running. Starting Docker Desktop...
echo.

:: Use a temp variable with short path style to avoid spaces issue
set "D1=%ProgramFiles%\Docker\Docker\Docker Desktop.exe"
set "D2=%ProgramFiles(x86)%\Docker\Docker\Docker Desktop.exe"
set "D3=%LocalAppData%\Docker\Docker Desktop.exe"

if exist "%D1%" (
    start "" "%D1%"
    goto WAIT_FOR_DOCKER
)
if exist "%D2%" (
    start "" "%D2%"
    goto WAIT_FOR_DOCKER
)
if exist "%D3%" (
    start "" "%D3%"
    goto WAIT_FOR_DOCKER
)

:: Not found in any location
color 4F
echo [ERROR] Docker Desktop executable not found.
echo.
echo Please start Docker Desktop manually from the Start Menu,
echo wait for the whale icon to stop animating, then run this script again.
echo.
pause
exit /b 1

:WAIT_FOR_DOCKER
echo        Docker Desktop is launching...
echo        Waiting up to 2 minutes for it to become ready.
echo        (Watch for the whale icon in the system tray)
echo.

set ATTEMPTS=0
:WAIT_LOOP
timeout /t 5 /nobreak >nul
set /a ATTEMPTS+=1
set /a ELAPSED=ATTEMPTS*5
docker info >nul 2>&1
if not errorlevel 1 goto DOCKER_READY
if %ATTEMPTS% lss 24 (
    echo        Still waiting... [%ELAPSED%s / 120s]
    goto WAIT_LOOP
)
color 4F
echo.
echo [ERROR] Docker Desktop did not become ready within 2 minutes.
echo.
echo Please start it manually from the Start Menu and try again.
echo.
pause
exit /b 1

:DOCKER_READY
echo        Docker Desktop is ready. OK
echo.

:: ── Step 2: Apply PostgreSQL UUID fix ───────────────────────────────
:APPLY_FIX
cd /d "%LAB_DIR%"
echo [2/4] Applying PostgreSQL extension fix (uuid-ossp, pgcrypto)...
docker exec lcnc_postgres psql -U lcncadmin -d lcnclab -c "CREATE EXTENSION IF NOT EXISTS ""uuid-ossp"";" >nul 2>&1
docker exec lcnc_postgres psql -U lcncadmin -d lcnclab -c "CREATE EXTENSION IF NOT EXISTS ""pgcrypto"";" >nul 2>&1
echo        Extensions applied. OK
echo.

:: ── Step 3: Remove any stale containers then start fresh ────────────
echo [3/4] Starting all lab services...
echo        Removing any stale containers...
docker rm -f lcnc_postgres lcnc_nocodb lcnc_appsmith lcnc_n8n lcnc_formbricks lcnc_nodered lcnc_metabase lcnc_flowise lcnc_ollama lcnc_mailpit >nul 2>&1
echo        Starting all services...
echo.
docker compose up -d --remove-orphans
echo.

:: ── Step 4: Wait then show status ───────────────────────────────────
echo [4/4] Waiting 30 seconds for services to initialize...
timeout /t 30 /nobreak >nul
echo.

echo ============================================================
echo   CONTAINER STATUS
echo ============================================================
docker compose ps
echo.

echo ============================================================
echo   ACCESS YOUR TOOLS IN THE BROWSER
echo ============================================================
echo.
echo   NocoDB      (Database)       ^>^>  http://localhost:8080
echo   Appsmith    (App Builder)    ^>^>  http://localhost:8081
echo   n8n         (Automation)     ^>^>  http://localhost:5678
echo   Formbricks  (Forms)          ^>^>  http://localhost:3000
echo   Node-RED    (IoT Flows)      ^>^>  http://localhost:1880
echo   Metabase    (Analytics)      ^>^>  http://localhost:3001
echo   Flowise     (AI Chatbot)     ^>^>  http://localhost:3002
echo   Mailpit     (Test Emails)    ^>^>  http://localhost:8025
echo.
echo ============================================================
echo   n8n login    : admin / admin123
echo   Flowise login: admin / admin123
echo ============================================================
echo.
echo   To stop the lab at end of session, run: stop-lcnc-lab.bat
echo.
pause
