@echo off
echo ========================================
echo  JanHelp - Flutter API Setup
echo ========================================
echo.

echo [1/4] Installing Django REST Framework...
pip install djangorestframework

echo.
echo [2/4] Running migrations...
python manage.py makemigrations
python manage.py migrate

echo.
echo [3/4] Creating auth token table...
python manage.py migrate authtoken

echo.
echo [4/4] Starting Django server...
echo.
echo ========================================
echo  API is ready at: http://127.0.0.1:8000/api/
echo ========================================
echo.
echo Available endpoints:
echo - POST /api/auth/send-otp/
echo - POST /api/auth/verify-otp/
echo - GET  /api/dashboard/stats/
echo - GET  /api/complaints/
echo - POST /api/complaints/
echo.
echo Press Ctrl+C to stop the server
echo ========================================
echo.

python manage.py runserver
