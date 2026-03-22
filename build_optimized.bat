@echo off
echo ========================================
echo Flutter App Optimization Builder
echo ========================================
echo.

cd smartcity_application

echo Step 1: Cleaning previous builds...
flutter clean

echo.
echo Step 2: Getting dependencies...
flutter pub get

echo.
echo Step 3: Building optimized release APK...
echo This will create smaller APKs for different devices
flutter build apk --release --split-per-abi --shrink

echo.
echo ========================================
echo Build Complete!
echo ========================================
echo.
echo APKs created in: smartcity_application\build\app\outputs\flutter-apk\
echo.
echo Files:
echo - app-armeabi-v7a-release.apk (for older phones)
echo - app-arm64-v8a-release.apk (for newer phones)
echo.
echo Install the correct one for your device!
echo.
pause
