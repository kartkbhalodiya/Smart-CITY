@echo off
echo ========================================
echo Flutter Installation Script
echo ========================================
echo.

REM Check if Flutter already exists
if exist "C:\src\flutter" (
    echo Flutter already installed at C:\src\flutter
    goto :setup_path
)

echo Step 1: Creating directory...
mkdir C:\src 2>nul

echo Step 2: Downloading Flutter SDK (this may take 5-10 minutes)...
echo Please wait...

REM Download Flutter SDK using PowerShell
powershell -Command "& {Invoke-WebRequest -Uri 'https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.24.5-stable.zip' -OutFile 'C:\src\flutter_sdk.zip'}"

if not exist "C:\src\flutter_sdk.zip" (
    echo ERROR: Download failed. Please check your internet connection.
    pause
    exit /b 1
)

echo Step 3: Extracting Flutter SDK...
powershell -Command "& {Expand-Archive -Path 'C:\src\flutter_sdk.zip' -DestinationPath 'C:\src' -Force}"

echo Step 4: Cleaning up...
del C:\src\flutter_sdk.zip

:setup_path
echo.
echo Step 5: Adding Flutter to PATH...
powershell -Command "& {[Environment]::SetEnvironmentVariable('Path', [Environment]::GetEnvironmentVariable('Path', 'User') + ';C:\src\flutter\bin', 'User')}"

echo.
echo ========================================
echo Installation Complete!
echo ========================================
echo.
echo IMPORTANT: Close this window and open a NEW Command Prompt
echo Then run: flutter doctor
echo.
pause
