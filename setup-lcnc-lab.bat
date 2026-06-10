@echo off
:: Keep window open if anything crashes unexpectedly
if "%1"=="RELAUNCHED" goto MAIN
cmd /k "%~f0" RELAUNCHED
exit /b
:MAIN

setlocal enabledelayedexpansion
title LCNC Lab - First Time Setup
color 1F

echo.
echo ================================================================
echo   LOW CODE / NO CODE LAB - FIRST TIME SETUP
echo   3rd Semester - CS ^& Design Engineering
echo ================================================================
echo.
echo   This setup will:
echo     [1]  Check system requirements
echo     [2]  Install Docker Desktop (if not installed)
echo     [3]  Install Git (if not installed)
echo     [4]  Create lab folder and write config files
echo     [5]  Pull all Docker images (~8-10 GB)
echo     [6]  Start PostgreSQL and wait for it to be healthy
echo     [7]  Start all remaining services
echo     [8]  Apply database extensions
echo     [9]  Pull Llama 3 AI model (~4.7 GB)
echo     [10] Install Node-RED Dashboard plugin
echo     [11] Create Desktop shortcuts
echo.
echo   IMPORTANT: Stable internet connection required.
echo   Total download: ~13-15 GB. Time: 30-60 minutes.
echo.
echo   Press any key to begin or close this window to cancel.
pause >nul

:: ================================================================
:: CONFIGURATION
:: ================================================================
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
set DOCKER_INSTALLER=%LAB_DIR%\DockerDesktopInstaller.exe
set GIT_INSTALLER=%LAB_DIR%\GitInstaller.exe

:: ================================================================
:: STEP 1: System Requirements
:: ================================================================
echo.
echo ================================================================
echo   STEP 1: Checking System Requirements
echo ================================================================
echo.

for /f "usebackq delims=" %%v in (`powershell -NoProfile -Command "(Get-WmiObject Win32_OperatingSystem).Caption"`) do set WIN_NAME=%%v
for /f "usebackq delims=" %%v in (`powershell -NoProfile -Command "[System.Environment]::OSVersion.Version.ToString()"`) do set WIN_VER=%%v
echo   Windows  : %WIN_NAME%
echo   Version  : %WIN_VER%

for /f "usebackq" %%r in (`powershell -NoProfile -Command "try{[math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory/1GB,1)}catch{'0'}"`) do set RAM_GB=%%r
for /f "usebackq" %%r in (`powershell -NoProfile -Command "try{[math]::Floor((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory/1GB)}catch{'0'}"`) do set RAM_INT=%%r
if not defined RAM_GB set RAM_GB=Unknown
if not defined RAM_INT set RAM_INT=0
echo   RAM      : %RAM_GB% GB

if "%RAM_INT%"=="0" goto DISK_CHECK
if %RAM_INT% LSS 8 (
    color 6F
    echo.
    echo   [WARNING] Less than 8 GB RAM detected. Performance may be slow.
    echo   Continuing in 5 seconds...
    echo.
    timeout /t 5 /nobreak >nul
    color 1F
)

:DISK_CHECK
:: Extract drive letter from LAB_DIR path (e.g. E:\lcnc-lab -> E)
for /f "tokens=1 delims=:\" %%d in ("%LAB_DIR%") do set DRIVE_LETTER=%%d
if not defined DRIVE_LETTER set DRIVE_LETTER=C

for /f "usebackq" %%d in (`powershell -NoProfile -Command "try{[math]::Round((Get-PSDrive %DRIVE_LETTER%).Free/1GB,1)}catch{'0'}"`) do set FREE_GB=%%d
for /f "usebackq" %%d in (`powershell -NoProfile -Command "try{[math]::Floor((Get-PSDrive %DRIVE_LETTER%).Free/1GB)}catch{'0'}"`) do set FREE_INT=%%d
if not defined FREE_GB set FREE_GB=Unknown
if not defined FREE_INT set FREE_INT=0
echo   Disk (%DRIVE_LETTER%:): %FREE_GB% GB free

if "%FREE_INT%"=="0" goto REQS_DONE
if %FREE_INT% LSS 20 (
    color 4F
    echo.
    echo   [ERROR] Need at least 20 GB free on %DRIVE_LETTER%:. Currently: %FREE_GB% GB
    echo   Please free up disk space and run this script again.
    echo.
    pause
    exit /b 1
)

:REQS_DONE
echo.
echo   System requirements OK.
echo.

:: ================================================================
:: STEP 2: Docker Desktop
:: ================================================================
echo ================================================================
echo   STEP 2: Checking Docker Desktop
echo ================================================================
echo.

set "D1=%ProgramFiles%\Docker\Docker\Docker Desktop.exe"
set "D2=%ProgramFiles(x86)%\Docker\Docker\Docker Desktop.exe"
set "D3=%LocalAppData%\Docker\Docker Desktop.exe"
set DOCKER_EXE=
if exist "%D1%" set "DOCKER_EXE=%D1%"
if exist "%D2%" set "DOCKER_EXE=%D2%"
if exist "%D3%" set "DOCKER_EXE=%D3%"

if defined DOCKER_EXE (
    echo   Docker Desktop already installed. OK
    goto START_DOCKER
)

echo   Docker Desktop not found. Downloading...
powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://desktop.docker.com/win/main/amd64/Docker%%20Desktop%%20Installer.exe' -OutFile '%DOCKER_INSTALLER%' -UseBasicParsing"

if not exist "%DOCKER_INSTALLER%" (
    color 4F
    echo   [ERROR] Download failed. Install manually from:
    echo   https://www.docker.com/products/docker-desktop/
    pause
    exit /b 1
)

echo   Installing Docker Desktop (UAC prompt may appear - click Yes)...
"%DOCKER_INSTALLER%" install --quiet --accept-license
if errorlevel 1 (
    color 4F
    echo   [ERROR] Installation failed. Install manually from:
    echo   https://www.docker.com/products/docker-desktop/
    pause
    exit /b 1
)
echo   Docker Desktop installed. OK
set "D1=%ProgramFiles%\Docker\Docker\Docker Desktop.exe"
if exist "%D1%" set "DOCKER_EXE=%D1%"

:START_DOCKER
echo.
docker info >nul 2>&1
if not errorlevel 1 (
    echo   Docker already running. OK
    goto DOCKER_READY
)

echo   Starting Docker Desktop...
start "" "%DOCKER_EXE%"
echo   Waiting up to 3 minutes for Docker to become ready...
echo.

set ATTEMPTS=0
:DOCKER_WAIT_LOOP
timeout /t 5 /nobreak >nul
set /a ATTEMPTS+=1
set /a ELAPSED=ATTEMPTS*5
docker info >nul 2>&1
if not errorlevel 1 goto DOCKER_READY
if %ATTEMPTS% lss 36 (
    echo   Still waiting... [%ELAPSED%s / 180s]
    goto DOCKER_WAIT_LOOP
)
color 4F
echo   [ERROR] Docker did not start in 3 minutes.
echo   Start Docker Desktop manually then run this script again.
pause
exit /b 1

:DOCKER_READY
echo   Docker is running. OK
echo.

:: Configure Docker memory via temp PS1 file
echo   Configuring Docker resources...
set "PS_TEMP=%TEMP%\docker_cfg.ps1"
echo $f = $env:APPDATA + "\Docker\settings.json" > "%PS_TEMP%"
echo if (Test-Path $f) { >> "%PS_TEMP%"
echo     $s = Get-Content $f ^| ConvertFrom-Json >> "%PS_TEMP%"
echo     if ($s.memoryMiB -lt 6144) { $s.memoryMiB = 8192 } >> "%PS_TEMP%"
echo     if ($s.cpus -lt 4) { $s.cpus = 4 } >> "%PS_TEMP%"
echo     $s ^| ConvertTo-Json -Depth 10 ^| Set-Content $f >> "%PS_TEMP%"
echo } >> "%PS_TEMP%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_TEMP%" >nul 2>&1
del "%PS_TEMP%" >nul 2>&1
echo   Docker resources configured. OK
echo.

:: ================================================================
:: STEP 3: Git
:: ================================================================
echo ================================================================
echo   STEP 3: Checking Git
echo ================================================================
echo.

git --version >nul 2>&1
if not errorlevel 1 (
    for /f "delims=" %%v in ('git --version') do echo   %%v - already installed. OK
    goto GIT_DONE
)

echo   Downloading Git for Windows...
powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://github.com/git-for-windows/git/releases/download/v2.45.2.windows.1/Git-2.45.2-64-bit.exe' -OutFile '%GIT_INSTALLER%' -UseBasicParsing"

if not exist "%GIT_INSTALLER%" (
    echo   [WARNING] Git download failed. Install later from https://git-scm.com
    goto GIT_DONE
)
echo   Installing Git...
"%GIT_INSTALLER%" /VERYSILENT /NORESTART /NOCANCEL /SP-
echo   Git installed. OK
set PATH=%PATH%;%ProgramFiles%\Git\cmd

:GIT_DONE
echo.

:: ================================================================
:: ================================================================
:: STEP 4: Create Lab Folder and Write Config Files
:: ================================================================
echo ================================================================
echo   STEP 4: Creating Lab Folder and Writing Config Files
echo ================================================================
echo.

if not exist "%LAB_DIR%" mkdir "%LAB_DIR%"
echo   Lab folder: %LAB_DIR%
echo.

:: Write docker-compose.yml using certutil base64 decode
:: This avoids ALL batch escape/quoting issues
echo   Writing docker-compose.yml...
set "B64_TMP=%TEMP%\lcnc_yml.b64"
set "B64_TMP2=%TEMP%\lcnc_yml_clean.b64"

(
echo c2VydmljZXM6CgogICMg4pSA4pSAIFBvc3RncmVTUUwg4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA
echo 4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA
echo 4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA
echo 4pSA4pSA4pSA4pSA4pSA4pSA4pSACiAgIyBFYWNoIHNlcnZpY2UgZ2V0cyBpdHMgb3duIGRhdGFi
echo YXNlIC0gbm8gc2hhcmluZywgbm8gY29uZmxpY3RzCiAgcG9zdGdyZXM6CiAgICBpbWFnZTogcG9z
echo dGdyZXM6MTUtYWxwaW5lCiAgICBjb250YWluZXJfbmFtZTogbGNuY19wb3N0Z3JlcwogICAgcmVz
echo dGFydDogdW5sZXNzLXN0b3BwZWQKICAgIGVudmlyb25tZW50OgogICAgICBQT1NUR1JFU19VU0VS
echo OiBsY25jYWRtaW4KICAgICAgUE9TVEdSRVNfUEFTU1dPUkQ6IGxjbmNwYXNzMTIzCiAgICAgIFBP
echo U1RHUkVTX0RCOiBwb3N0Z3JlcwogICAgdm9sdW1lczoKICAgICAgLSBwb3N0Z3Jlc19kYXRhOi92
echo YXIvbGliL3Bvc3RncmVzcWwvZGF0YQogICAgICAtIC4vaW5pdC1kYi5zcWw6L2RvY2tlci1lbnRy
echo eXBvaW50LWluaXRkYi5kL2luaXQtZGIuc3FsCiAgICBwb3J0czoKICAgICAgLSAiNTQzMjo1NDMy
echo IgogICAgbmV0d29ya3M6CiAgICAgIC0gbGNuY19uZXR3b3JrCiAgICBoZWFsdGhjaGVjazoKICAg
echo ICAgdGVzdDogWyJDTUQtU0hFTEwiLCAicGdfaXNyZWFkeSAtVSBsY25jYWRtaW4gLWQgcG9zdGdy
echo ZXMiXQogICAgICBpbnRlcnZhbDogMTBzCiAgICAgIHRpbWVvdXQ6IDVzCiAgICAgIHJldHJpZXM6
echo IDEwCgogICMg4pSA4pSAIE5vY29EQiDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDi
echo lIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDi
echo lIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDi
echo lIDilIDilIDilIDilIDilIDilIDilIAKICAjIERhdGFiYXNlOiBub2NvZGIgKGRlZGljYXRlZCkK
echo ICAjIFVSTDogaHR0cDovL2xvY2FsaG9zdDo4MDgwCiAgbm9jb2RiOgogICAgaW1hZ2U6IG5vY29k
echo Yi9ub2NvZGI6MC4yNTguMQogICAgY29udGFpbmVyX25hbWU6IGxjbmNfbm9jb2RiCiAgICByZXN0
echo YXJ0OiB1bmxlc3Mtc3RvcHBlZAogICAgZGVwZW5kc19vbjoKICAgICAgcG9zdGdyZXM6CiAgICAg
echo ICAgY29uZGl0aW9uOiBzZXJ2aWNlX2hlYWx0aHkKICAgIGVudmlyb25tZW50OgogICAgICBOQ19E
echo QjogInBnOi8vcG9zdGdyZXM6NTQzMj91PWxjbmNhZG1pbiZwPWxjbmNwYXNzMTIzJmQ9bm9jb2Ri
echo IgogICAgICBOQ19BVVRIX0pXVF9TRUNSRVQ6ICJub2NvZGItand0LXNlY3JldC1sY25jLWxhYi0y
echo MDI0IgogICAgICBOQ19QVUJMSUNfVVJMOiAiaHR0cDovL2xvY2FsaG9zdDo4MDgwIgogICAgICBO
echo Q19ESVNBQkxFX1RFTEU6ICJ0cnVlIgogICAgcG9ydHM6CiAgICAgIC0gIjgwODA6ODA4MCIKICAg
echo IHZvbHVtZXM6CiAgICAgIC0gbm9jb2RiX2RhdGE6L3Vzci9hcHAvZGF0YQogICAgbmV0d29ya3M6
echo CiAgICAgIC0gbGNuY19uZXR3b3JrCgogICMg4pSA4pSAIEFwcHNtaXRoIOKUgOKUgOKUgOKUgOKU
echo gOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKU
echo gOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKU
echo gOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgAogICMgVXNlcyBpdHMgb3duIGlu
echo dGVybmFsIE1vbmdvREIgLSBubyBwb3N0Z3JlcyBkZXBlbmRlbmN5CiAgIyBVUkw6IGh0dHA6Ly9s
echo b2NhbGhvc3Q6ODA4MQogIGFwcHNtaXRoOgogICAgaW1hZ2U6IGluZGV4LmRvY2tlci5pby9hcHBz
echo bWl0aC9hcHBzbWl0aC1jZTpsYXRlc3QKICAgIGNvbnRhaW5lcl9uYW1lOiBsY25jX2FwcHNtaXRo
echo CiAgICByZXN0YXJ0OiB1bmxlc3Mtc3RvcHBlZAogICAgcG9ydHM6CiAgICAgIC0gIjgwODE6ODAi
echo CiAgICAgIC0gIjg0NDM6NDQzIgogICAgdm9sdW1lczoKICAgICAgLSBhcHBzbWl0aF9kYXRhOi9h
echo cHBzbWl0aC1zdGFja3MKICAgIG5ldHdvcmtzOgogICAgICAtIGxjbmNfbmV0d29yawoKICAjIOKU
echo gOKUgCBuOG4g4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA
echo 4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA
echo 4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA
echo 4pSA4pSA4pSA4pSA4pSA4pSACiAgIyBEYXRhYmFzZTogbjhuZGIgKGRlZGljYXRlZCkKICAjIFVS
echo TDogaHR0cDovL2xvY2FsaG9zdDo1Njc4ICBsb2dpbjogYWRtaW4gLyBhZG1pbjEyMwogIG44bjoK
echo ICAgIGltYWdlOiBuOG5pby9uOG46bGF0ZXN0CiAgICBjb250YWluZXJfbmFtZTogbGNuY19uOG4K
echo ICAgIHJlc3RhcnQ6IHVubGVzcy1zdG9wcGVkCiAgICBkZXBlbmRzX29uOgogICAgICBwb3N0Z3Jl
echo czoKICAgICAgICBjb25kaXRpb246IHNlcnZpY2VfaGVhbHRoeQogICAgZW52aXJvbm1lbnQ6CiAg
echo ICAgIERCX1RZUEU6IHBvc3RncmVzZGIKICAgICAgREJfUE9TVEdSRVNEQl9IT1NUOiBwb3N0Z3Jl
echo cwogICAgICBEQl9QT1NUR1JFU0RCX1BPUlQ6IDU0MzIKICAgICAgREJfUE9TVEdSRVNEQl9EQVRB
echo QkFTRTogbjhuZGIKICAgICAgREJfUE9TVEdSRVNEQl9VU0VSOiBsY25jYWRtaW4KICAgICAgREJf
echo UE9TVEdSRVNEQl9QQVNTV09SRDogbGNuY3Bhc3MxMjMKICAgICAgTjhOX0JBU0lDX0FVVEhfQUNU
echo SVZFOiAidHJ1ZSIKICAgICAgTjhOX0JBU0lDX0FVVEhfVVNFUjogImFkbWluIgogICAgICBOOE5f
echo QkFTSUNfQVVUSF9QQVNTV09SRDogImFkbWluMTIzIgogICAgICBOOE5fSE9TVDogImxvY2FsaG9z
echo dCIKICAgICAgTjhOX1BPUlQ6IDU2NzgKICAgICAgTjhOX1BST1RPQ09MOiAiaHR0cCIKICAgICAg
echo V0VCSE9PS19VUkw6ICJodHRwOi8vbG9jYWxob3N0OjU2NzgiCiAgICAgIEdFTkVSSUNfVElNRVpP
echo TkU6ICJBc2lhL0tvbGthdGEiCiAgICAgIE44Tl9FRElUT1JfQkFTRV9VUkw6ICJodHRwOi8vbG9j
echo YWxob3N0OjU2NzgiCiAgICBwb3J0czoKICAgICAgLSAiNTY3ODo1Njc4IgogICAgdm9sdW1lczoK
echo ICAgICAgLSBuOG5fZGF0YTovaG9tZS9ub2RlLy5uOG4KICAgIG5ldHdvcmtzOgogICAgICAtIGxj
echo bmNfbmV0d29yawoKICAjIOKUgOKUgCBGb3JtYnJpY2tzIOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKU
echo gOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKU
echo gOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKU
echo gOKUgOKUgOKUgOKUgOKUgOKUgOKUgAogICMgRGF0YWJhc2U6IGZvcm1icmlja3NkYiAoZGVkaWNh
echo dGVkKQogICMgVVJMOiBodHRwOi8vbG9jYWxob3N0OjMwMDAKICBmb3JtYnJpY2tzOgogICAgaW1h
echo Z2U6IGdoY3IuaW8vZm9ybWJyaWNrcy9mb3JtYnJpY2tzOnYyLjMuMQogICAgY29udGFpbmVyX25h
echo bWU6IGxjbmNfZm9ybWJyaWNrcwogICAgcmVzdGFydDogdW5sZXNzLXN0b3BwZWQKICAgIGRlcGVu
echo ZHNfb246CiAgICAgIHBvc3RncmVzOgogICAgICAgIGNvbmRpdGlvbjogc2VydmljZV9oZWFsdGh5
echo CiAgICBlbnZpcm9ubWVudDoKICAgICAgREFUQUJBU0VfVVJMOiAicG9zdGdyZXNxbDovL2xjbmNh
echo ZG1pbjpsY25jcGFzczEyM0Bwb3N0Z3Jlczo1NDMyL2Zvcm1icmlja3NkYiIKICAgICAgTkVYVEFV
echo VEhfU0VDUkVUOiAibGNuY2xhYnNlY3JldDEyMzQ1Njc4OTBhYmNkZWZnaCIKICAgICAgTkVYVEFV
echo VEhfVVJMOiAiaHR0cDovL2xvY2FsaG9zdDozMDAwIgogICAgICBFTkNSWVBUSU9OX0tFWTogIjEy
echo MzQ1Njc4OTAxMjM0NTY3ODkwMTIzNDU2Nzg5MDEyIgogICAgICBDUk9OX1NFQ1JFVDogImxjbmNs
echo YWItY3Jvbi1zZWNyZXQtMTIzNDU2Nzg5MGFiIgogICAgICBFTUFJTF9WRVJJRklDQVRJT05fRElT
echo QUJMRUQ6ICIxIgogICAgICBTSUdOVVBfRElTQUJMRUQ6ICIwIgogICAgICBURUxFTUVUUllfRElT
echo QUJMRUQ6ICIxIgogICAgcG9ydHM6CiAgICAgIC0gIjMwMDA6MzAwMCIKICAgIG5ldHdvcmtzOgog
echo ICAgICAtIGxjbmNfbmV0d29yawoKICAjIOKUgOKUgCBOb2RlLVJFRCDilIDilIDilIDilIDilIDi
echo lIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDi
echo lIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDi
echo lIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIDilIAKICAjIFVzZXMgbG9jYWwgZmlsZSBz
echo dG9yYWdlIC0gbm8gcG9zdGdyZXMgZGVwZW5kZW5jeQogICMgVVJMOiBodHRwOi8vbG9jYWxob3N0
echo OjE4ODAKICBub2RlcmVkOgogICAgaW1hZ2U6IG5vZGVyZWQvbm9kZS1yZWQ6bGF0ZXN0CiAgICBj
echo b250YWluZXJfbmFtZTogbGNuY19ub2RlcmVkCiAgICByZXN0YXJ0OiB1bmxlc3Mtc3RvcHBlZAog
echo ICAgZW52aXJvbm1lbnQ6CiAgICAgIFRaOiAiQXNpYS9Lb2xrYXRhIgogICAgcG9ydHM6CiAgICAg
echo IC0gIjE4ODA6MTg4MCIKICAgIHZvbHVtZXM6CiAgICAgIC0gbm9kZXJlZF9kYXRhOi9kYXRhCiAg
echo ICBuZXR3b3JrczoKICAgICAgLSBsY25jX25ldHdvcmsKCiAgIyDilIDilIAgTWV0YWJhc2Ug4pSA
echo 4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA
echo 4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA
echo 4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSACiAgIyBEYXRh
echo YmFzZTogbWV0YWJhc2VkYiAoZGVkaWNhdGVkKQogICMgVVJMOiBodHRwOi8vbG9jYWxob3N0OjMw
echo MDEKICBtZXRhYmFzZToKICAgIGltYWdlOiBtZXRhYmFzZS9tZXRhYmFzZTp2MC41MC4zNgogICAg
echo Y29udGFpbmVyX25hbWU6IGxjbmNfbWV0YWJhc2UKICAgIHJlc3RhcnQ6IHVubGVzcy1zdG9wcGVk
echo CiAgICBkZXBlbmRzX29uOgogICAgICBwb3N0Z3JlczoKICAgICAgICBjb25kaXRpb246IHNlcnZp
echo Y2VfaGVhbHRoeQogICAgZW52aXJvbm1lbnQ6CiAgICAgIE1CX0RCX1RZUEU6IHBvc3RncmVzCiAg
echo ICAgIE1CX0RCX0RCTkFNRTogbWV0YWJhc2VkYgogICAgICBNQl9EQl9QT1JUOiA1NDMyCiAgICAg
echo IE1CX0RCX1VTRVI6IGxjbmNhZG1pbgogICAgICBNQl9EQl9QQVNTOiBsY25jcGFzczEyMwogICAg
echo ICBNQl9EQl9IT1NUOiBwb3N0Z3JlcwogICAgICBKQVZBX1RJTUVaT05FOiAiQXNpYS9Lb2xrYXRh
echo IgogICAgcG9ydHM6CiAgICAgIC0gIjMwMDE6MzAwMCIKICAgIHZvbHVtZXM6CiAgICAgIC0gbWV0
echo YWJhc2VfZGF0YTovbWV0YWJhc2UtZGF0YQogICAgbmV0d29ya3M6CiAgICAgIC0gbGNuY19uZXR3
echo b3JrCgogICMg4pSA4pSAIEZsb3dpc2Ug4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA
echo 4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA
echo 4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA
echo 4pSA4pSA4pSA4pSA4pSA4pSA4pSACiAgIyBEYXRhYmFzZTogZmxvd2lzZWRiIChkZWRpY2F0ZWQp
echo CiAgIyBVUkw6IGh0dHA6Ly9sb2NhbGhvc3Q6MzAwMiAgbG9naW46IGFkbWluIC8gYWRtaW4xMjMK
echo ICBmbG93aXNlOgogICAgaW1hZ2U6IGZsb3dpc2VhaS9mbG93aXNlOmxhdGVzdAogICAgY29udGFp
echo bmVyX25hbWU6IGxjbmNfZmxvd2lzZQogICAgcmVzdGFydDogdW5sZXNzLXN0b3BwZWQKICAgIGRl
echo cGVuZHNfb246CiAgICAgIHBvc3RncmVzOgogICAgICAgIGNvbmRpdGlvbjogc2VydmljZV9oZWFs
echo dGh5CiAgICBlbnZpcm9ubWVudDoKICAgICAgUE9SVDogMzAwMgogICAgICBGTE9XSVNFX1VTRVJO
echo QU1FOiAiYWRtaW4iCiAgICAgIEZMT1dJU0VfUEFTU1dPUkQ6ICJhZG1pbjEyMyIKICAgICAgREFU
echo QUJBU0VfVFlQRTogcG9zdGdyZXMKICAgICAgREFUQUJBU0VfSE9TVDogcG9zdGdyZXMKICAgICAg
echo REFUQUJBU0VfUE9SVDogNTQzMgogICAgICBEQVRBQkFTRV9OQU1FOiBmbG93aXNlZGIKICAgICAg
echo REFUQUJBU0VfVVNFUjogbGNuY2FkbWluCiAgICAgIERBVEFCQVNFX1BBU1NXT1JEOiBsY25jcGFz
echo czEyMwogICAgcG9ydHM6CiAgICAgIC0gIjMwMDI6MzAwMiIKICAgIHZvbHVtZXM6CiAgICAgIC0g
echo Zmxvd2lzZV9kYXRhOi9yb290Ly5mbG93aXNlCiAgICBuZXR3b3JrczoKICAgICAgLSBsY25jX25l
echo dHdvcmsKCiAgIyDilIDilIAgT2xsYW1hIOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKU
echo gOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKU
echo gOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKU
echo gOKUgOKUgOKUgOKUgOKUgOKUgOKUgOKUgAogICMgTG9jYWwgTExNIHJ1bnRpbWUgZm9yIExhYiA4
echo CiAgIyBBUEk6IGh0dHA6Ly9sb2NhbGhvc3Q6MTE0MzQKICBvbGxhbWE6CiAgICBpbWFnZTogb2xs
echo YW1hL29sbGFtYTpsYXRlc3QKICAgIGNvbnRhaW5lcl9uYW1lOiBsY25jX29sbGFtYQogICAgcmVz
echo dGFydDogdW5sZXNzLXN0b3BwZWQKICAgIHBvcnRzOgogICAgICAtICIxMTQzNDoxMTQzNCIKICAg
echo IHZvbHVtZXM6CiAgICAgIC0gb2xsYW1hX2RhdGE6L3Jvb3QvLm9sbGFtYQogICAgbmV0d29ya3M6
echo CiAgICAgIC0gbGNuY19uZXR3b3JrCgogICMg4pSA4pSAIE1haWxwaXQg4pSA4pSA4pSA4pSA4pSA
echo 4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA
echo 4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA
echo 4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSA4pSACiAgIyBMb2NhbCBlbWFpbCB0
echo ZXN0aW5nIC0gbm8gcG9zdGdyZXMgZGVwZW5kZW5jeQogICMgSW5ib3g6IGh0dHA6Ly9sb2NhbGhv
echo c3Q6ODAyNQogIG1haWxwaXQ6CiAgICBpbWFnZTogYXhsbGVudC9tYWlscGl0OmxhdGVzdAogICAg
echo Y29udGFpbmVyX25hbWU6IGxjbmNfbWFpbHBpdAogICAgcmVzdGFydDogdW5sZXNzLXN0b3BwZWQK
echo ICAgIHBvcnRzOgogICAgICAtICIxMDI1OjEwMjUiCiAgICAgIC0gIjgwMjU6ODAyNSIKICAgIG5l
echo dHdvcmtzOgogICAgICAtIGxjbmNfbmV0d29yawoKdm9sdW1lczoKICBwb3N0Z3Jlc19kYXRhOgog
echo IG5vY29kYl9kYXRhOgogIGFwcHNtaXRoX2RhdGE6CiAgbjhuX2RhdGE6CiAgbm9kZXJlZF9kYXRh
echo OgogIG1ldGFiYXNlX2RhdGE6CiAgZmxvd2lzZV9kYXRhOgogIG9sbGFtYV9kYXRhOgoKbmV0d29y
echo a3M6CiAgbGNuY19uZXR3b3JrOgogICAgZHJpdmVyOiBicmlkZ2UK
) > "%B64_TMP%"

:: certutil adds header/footer lines - strip them with findstr
findstr /v "CERTIFICATE" "%B64_TMP%" > "%B64_TMP2%"
certutil -decode "%B64_TMP2%" "%LAB_DIR%\docker-compose.yml" >nul 2>&1
del "%B64_TMP%" >nul 2>&1
del "%B64_TMP2%" >nul 2>&1
echo   docker-compose.yml written. OK
echo.

:: Write init-db.sql using certutil base64 decode
echo   Writing init-db.sql...
set "SQL_TMP=%TEMP%\lcnc_sql.b64"
set "SQL_TMP2=%TEMP%\lcnc_sql_clean.b64"

(
echo LS0gPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
echo PT09PT09PT09PQotLSBMQ05DIExhYiAtIFBvc3RncmVTUUwgSW5pdGlhbGl6YXRpb24KLS0gQ3Jl
echo YXRlcyBhIHNlcGFyYXRlIGRhdGFiYXNlIGZvciBldmVyeSBzZXJ2aWNlCi0tIFJ1bnMgYXV0b21h
echo dGljYWxseSBvbiBmaXJzdCBwb3N0Z3JlcyBjb250YWluZXIgc3RhcnQKLS0gPT09PT09PT09PT09
echo PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQoKLS0g
echo RXh0ZW5zaW9ucwpDUkVBVEUgRVhURU5TSU9OIElGIE5PVCBFWElTVFMgInV1aWQtb3NzcCI7CkNS
echo RUFURSBFWFRFTlNJT04gSUYgTk9UIEVYSVNUUyAicGdjcnlwdG8iOwoKLS0gRGVkaWNhdGVkIGRh
echo dGFiYXNlIHBlciBzZXJ2aWNlCkNSRUFURSBEQVRBQkFTRSBub2NvZGI7CkNSRUFURSBEQVRBQkFT
echo RSBuOG5kYjsKQ1JFQVRFIERBVEFCQVNFIGZvcm1icmlja3NkYjsKQ1JFQVRFIERBVEFCQVNFIG1l
echo dGFiYXNlZGI7CkNSRUFURSBEQVRBQkFTRSBmbG93aXNlZGI7CgotLSBHcmFudCBmdWxsIGFjY2Vz
echo cyB0byBsY25jYWRtaW4gb24gZXZlcnkgZGF0YWJhc2UKR1JBTlQgQUxMIFBSSVZJTEVHRVMgT04g
echo REFUQUJBU0Ugbm9jb2RiIFRPIGxjbmNhZG1pbjsKR1JBTlQgQUxMIFBSSVZJTEVHRVMgT04gREFU
echo QUJBU0UgbjhuZGIgVE8gbGNuY2FkbWluOwpHUkFOVCBBTEwgUFJJVklMRUdFUyBPTiBEQVRBQkFT
echo RSBmb3JtYnJpY2tzZGIgVE8gbGNuY2FkbWluOwpHUkFOVCBBTEwgUFJJVklMRUdFUyBPTiBEQVRB
echo QkFTRSBtZXRhYmFzZWRiIFRPIGxjbmNhZG1pbjsKR1JBTlQgQUxMIFBSSVZJTEVHRVMgT04gREFU
echo QUJBU0UgZmxvd2lzZWRiIFRPIGxjbmNhZG1pbjsK
) > "%SQL_TMP%"

findstr /v "CERTIFICATE" "%SQL_TMP%" > "%SQL_TMP2%"
certutil -decode "%SQL_TMP2%" "%LAB_DIR%\init-db.sql" >nul 2>&1
del "%SQL_TMP%" >nul 2>&1
del "%SQL_TMP2%" >nul 2>&1
echo   init-db.sql written. OK
echo.

:: STEP 5: Pull Docker Images
:: ================================================================
echo ================================================================
echo   STEP 5: Pulling Docker Images (~8-10 GB)
echo   Do not close this window. Takes 15-40 minutes.
echo ================================================================
echo.

cd /d "%LAB_DIR%"
docker compose pull
if errorlevel 1 (
    color 6F
    echo   [WARNING] Some images may have failed. Continuing...
    timeout /t 3 /nobreak >nul
    color 1F
) else (
    echo   All images pulled. OK
)
echo.

:: ================================================================
:: STEP 6: Start PostgreSQL First - Wait for Healthy
:: ================================================================
echo ================================================================
echo   STEP 6: Starting PostgreSQL
echo ================================================================
echo.

:: Stop and remove everything cleanly first
docker compose down --remove-orphans >nul 2>&1

echo   Starting PostgreSQL container...
docker compose up -d postgres

echo   Waiting for PostgreSQL to be fully healthy...
:PG_HEALTH_LOOP
timeout /t 5 /nobreak >nul
docker exec lcnc_postgres pg_isready -U lcncadmin -d postgres >nul 2>&1
if errorlevel 1 (
    echo   Still waiting for PostgreSQL...
    goto PG_HEALTH_LOOP
)
echo   PostgreSQL is healthy. OK
echo.

:: Apply extensions immediately after postgres is healthy
echo   Applying database extensions...
docker exec lcnc_postgres psql -U lcncadmin -d postgres -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";" >nul 2>&1
docker exec lcnc_postgres psql -U lcncadmin -d postgres -c "CREATE EXTENSION IF NOT EXISTS \"pgcrypto\";" >nul 2>&1
echo   Extensions applied. OK
echo.

:: ================================================================
:: STEP 7: Start All Remaining Services
:: ================================================================
echo ================================================================
echo   STEP 7: Starting All Lab Services
echo ================================================================
echo.

docker compose up -d
echo.
echo   All services started.
echo   Waiting 3 minutes for services to initialize...
echo   (Metabase takes the longest - it is a Java application)
echo.
timeout /t 60 /nobreak >nul
echo   1 minute done...
timeout /t 60 /nobreak >nul
echo   2 minutes done...
timeout /t 60 /nobreak >nul
echo   3 minutes done.
echo.

:: ================================================================
:: ================================================================
:: STEP 8: Load Sample Data into nocodb database
:: ================================================================
echo ================================================================
echo   STEP 8: Loading Sample Data for Lab 6 (Metabase)
echo ================================================================
echo.

set "DATA_TMP=%TEMP%\lcnc_data.b64"
set "DATA_TMP2=%TEMP%\lcnc_data_clean.b64"
set "DATA_SQL=%TEMP%\lcnc_orders.sql"

(
echo XFxjIG5vY29kYgpDUkVBVEUgVEFCTEUgSUYgTk9UIEVYSVNUUyBvcmRlcnMgKAogICAgaWQgU0VS
echo SUFMIFBSSU1BUlkgS0VZLAogICAgb3JkZXJfZGF0ZSBEQVRFIE5PVCBOVUxMLAogICAgY3VzdG9t
echo ZXJfbmFtZSBWQVJDSEFSKDEwMCksCiAgICBwcm9kdWN0X25hbWUgVkFSQ0hBUigxMDApLAogICAg
echo Y2F0ZWdvcnkgVkFSQ0hBUig1MCksCiAgICByZWdpb24gVkFSQ0hBUig1MCksCiAgICBxdWFudGl0
echo eSBJTlRFR0VSLAogICAgdW5pdF9wcmljZSBOVU1FUklDKDEwLDIpLAogICAgdG90YWxfYW1vdW50
echo IE5VTUVSSUMoMTAsMiksCiAgICBwYXltZW50X21ldGhvZCBWQVJDSEFSKDMwKSwKICAgIGlzX3Jl
echo dHVybmVkIEJPT0xFQU4gREVGQVVMVCBGQUxTRQopOwpJTlNFUlQgSU5UTyBvcmRlcnMgKG9yZGVy
echo X2RhdGUsY3VzdG9tZXJfbmFtZSxwcm9kdWN0X25hbWUsY2F0ZWdvcnkscmVnaW9uLHF1YW50aXR5
echo LHVuaXRfcHJpY2UsdG90YWxfYW1vdW50LHBheW1lbnRfbWV0aG9kLGlzX3JldHVybmVkKQpTRUxF
echo Q1QKICAgIENVUlJFTlRfREFURSAtIChmbG9vcihyYW5kb20oKSozNjUpKTo6SU5ULAogICAgQ0FT
echo RSBmbG9vcihyYW5kb20oKSoxMCk6OklOVCBXSEVOIDAgVEhFTiAnQW1pdCBLdW1hcicgV0hFTiAx
echo IFRIRU4gJ1ByaXlhIFNoYXJtYScgV0hFTiAyIFRIRU4gJ1JhdmkgUGF0ZWwnIFdIRU4gMyBUSEVO
echo ICdTbmVoYSBOYWlyJyBXSEVOIDQgVEhFTiAnS2lyYW4gUmVkZHknIFdIRU4gNSBUSEVOICdEZWVw
echo YSBNZW5vbicgV0hFTiA2IFRIRU4gJ1JhaHVsIFNpbmdoJyBXSEVOIDcgVEhFTiAnQW5pdGEgRGVz
echo YWknIFdIRU4gOCBUSEVOICdWaWpheSBJeWVyJyBFTFNFICdQb29qYSBCaGF0JyBFTkQsCiAgICBD
echo QVNFIGZsb29yKHJhbmRvbSgpKjEwKTo6SU5UIFdIRU4gMCBUSEVOICdXaXJlbGVzcyBNb3VzZScg
echo V0hFTiAxIFRIRU4gJ1VTQiBIdWInIFdIRU4gMiBUSEVOICdLZXlib2FyZCcgV0hFTiAzIFRIRU4g
echo J1dlYmNhbScgV0hFTiA0IFRIRU4gJ0xhcHRvcCBTdGFuZCcgV0hFTiA1IFRIRU4gJ01vbml0b3Ig
echo MjRpbicgV0hFTiA2IFRIRU4gJ0hlYWRwaG9uZXMnIFdIRU4gNyBUSEVOICdEZXNrIExhbXAnIFdI
echo RU4gOCBUSEVOICdQb3dlciBCYW5rJyBFTFNFICdDYWJsZSBLaXQnIEVORCwKICAgIENBU0UgZmxv
echo b3IocmFuZG9tKCkqNSk6OklOVCBXSEVOIDAgVEhFTiAnUGVyaXBoZXJhbHMnIFdIRU4gMSBUSEVO
echo ICdBY2Nlc3NvcmllcycgV0hFTiAyIFRIRU4gJ0F1ZGlvJyBXSEVOIDMgVEhFTiAnRGlzcGxheScg
echo RUxTRSAnUG93ZXInIEVORCwKICAgIENBU0UgZmxvb3IocmFuZG9tKCkqNSk6OklOVCBXSEVOIDAg
echo VEhFTiAnTm9ydGgnIFdIRU4gMSBUSEVOICdTb3V0aCcgV0hFTiAyIFRIRU4gJ0Vhc3QnIFdIRU4g
echo MyBUSEVOICdXZXN0JyBFTFNFICdDZW50cmFsJyBFTkQsCiAgICAoZmxvb3IocmFuZG9tKCkqNSkr
echo MSk6OklOVCwKICAgIHJvdW5kKChyYW5kb20oKSo0OTAwKzEwMCk6Ok5VTUVSSUMsMiksCiAgICAw
echo LAogICAgQ0FTRSBmbG9vcihyYW5kb20oKSo1KTo6SU5UIFdIRU4gMCBUSEVOICdVUEknIFdIRU4g
echo MSBUSEVOICdDcmVkaXQgQ2FyZCcgV0hFTiAyIFRIRU4gJ0RlYml0IENhcmQnIFdIRU4gMyBUSEVO
echo ICdOZXQgQmFua2luZycgRUxTRSAnQ2FzaCBvbiBEZWxpdmVyeScgRU5ELAogICAgKHJhbmRvbSgp
echo ID4gMC44NSkKRlJPTSBnZW5lcmF0ZV9zZXJpZXMoMSw1MDApOwpVUERBVEUgb3JkZXJzIFNFVCB0
echo b3RhbF9hbW91bnQgPSBxdWFudGl0eSAqIHVuaXRfcHJpY2U7CkNSRUFURSBUQUJMRSBJRiBOT1Qg
echo RVhJU1RTIGF1dG9tYXRpb25fbG9ncyAoCiAgICBpZCBTRVJJQUwgUFJJTUFSWSBLRVksCiAgICBl
echo dmVudF90eXBlIFZBUkNIQVIoMTAwKSwKICAgIHRyaWdnZXJlZF9hdCBUSU1FU1RBTVAgREVGQVVM
echo VCBOT1coKSwKICAgIHN0YXR1cyBWQVJDSEFSKDIwKSwKICAgIG1lc3NhZ2UgVEVYVCwKICAgIHBh
echo eWxvYWQgSlNPTkIKKTsK
) > "%DATA_TMP%"
findstr /v "CERTIFICATE" "%DATA_TMP%" > "%DATA_TMP2%"
certutil -decode "%DATA_TMP2%" "%DATA_SQL%" >nul 2>&1
del "%DATA_TMP%" >nul 2>&1
del "%DATA_TMP2%" >nul 2>&1

docker exec -i lcnc_postgres psql -U lcncadmin < "%DATA_SQL%" >nul 2>&1
del "%DATA_SQL%" >nul 2>&1
echo   Sample data loaded. OK
echo.

:: STEP 9: Pull Llama 3 AI Model
:: ================================================================
echo ================================================================
echo   STEP 9: Downloading Llama 3 AI Model (~4.7 GB)
echo   Required for Lab 8. Takes 10-20 minutes.
echo ================================================================
echo.

docker exec lcnc_ollama ollama pull llama3
echo.
docker exec lcnc_ollama ollama pull nomic-embed-text
echo.
docker exec lcnc_ollama ollama list
echo.

:: ================================================================
:: STEP 10: Install Node-RED Dashboard Plugin
:: ================================================================
echo ================================================================
echo   STEP 10: Installing Node-RED Dashboard Plugin
echo ================================================================
echo.

docker exec lcnc_nodered npm install --prefix /data node-red-dashboard >nul 2>&1
docker compose restart nodered >nul 2>&1
timeout /t 15 /nobreak >nul
echo   Node-RED Dashboard plugin installed. OK
echo.

:: ================================================================
:: FINAL STATUS
:: ================================================================
echo ================================================================
echo   FINAL STATUS - All Containers
echo ================================================================
echo.
docker compose ps
echo.

:: ================================================================
:: STEP 11: Create Desktop Shortcuts
:: ================================================================
echo   Creating Desktop shortcuts...

powershell -NoProfile -Command "$WS=New-Object -ComObject WScript.Shell; $S=$WS.CreateShortcut([Environment]::GetFolderPath('Desktop')+'\Start LCNC Lab.lnk'); $S.TargetPath='%LAB_DIR%\start-lcnc-lab.bat'; $S.WorkingDirectory='%LAB_DIR%'; $S.Save()"
powershell -NoProfile -Command "$WS=New-Object -ComObject WScript.Shell; $S=$WS.CreateShortcut([Environment]::GetFolderPath('Desktop')+'\Stop LCNC Lab.lnk'); $S.TargetPath='%LAB_DIR%\stop-lcnc-lab.bat'; $S.WorkingDirectory='%LAB_DIR%'; $S.Save()"
powershell -NoProfile -Command "$WS=New-Object -ComObject WScript.Shell; $S=$WS.CreateShortcut([Environment]::GetFolderPath('Desktop')+'\Fresh Start LCNC Lab.lnk'); $S.TargetPath='%LAB_DIR%\fresh-start.bat'; $S.WorkingDirectory='%LAB_DIR%'; $S.Save()"

echo   Desktop shortcuts created:
echo     - Start LCNC Lab     (use at beginning of every session)
echo     - Stop LCNC Lab      (use at end of every session)
echo     - Fresh Start LCNC Lab (use only if stack is broken)
echo.

:: ================================================================
:: DONE
:: ================================================================
echo ================================================================
echo   SETUP COMPLETE!
echo ================================================================
echo.
echo   Access your tools at:
echo.
echo   NocoDB      ^>^>  http://localhost:8080
echo   Appsmith    ^>^>  http://localhost:8081
echo   n8n         ^>^>  http://localhost:5678   (admin / admin123)
echo   Formbricks  ^>^>  http://localhost:3000
echo   Node-RED    ^>^>  http://localhost:1880
echo   Metabase    ^>^>  http://localhost:3001   (setup wizard on first visit)
echo   Flowise     ^>^>  http://localhost:3002   (admin / admin123)
echo   Mailpit     ^>^>  http://localhost:8025
echo.
echo   NOTE: If Metabase shows a loading screen, wait 2 more minutes.
echo         It is a Java app and takes the longest to start.
echo.
echo   Three shortcuts have been placed on your Desktop.
echo   Use "Start LCNC Lab" at the beginning of every session.
echo.
pause
