@echo off
echo ========================================
echo Smart City Complaint Management System
echo ========================================
echo.

echo Step 1: Creating superuser for admin access...
echo Please enter admin credentials when prompted:
python manage.py createsuperuser

echo.
echo Step 2: Starting development server...
echo.
echo Access the application at:
echo - User Portal: http://127.0.0.1:8000/
echo - Admin Panel: http://127.0.0.1:8000/admin/
echo.
echo OTP codes will be displayed in this console window.
echo.
echo Press Ctrl+C to stop the server.
echo.

python manage.py runserver
