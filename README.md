# Smart City Complaint Management System

A Django-based web application for managing city complaints with email OTP authentication, GPS tracking, and department-specific dashboards.

## Features

- **Email OTP Authentication**: Secure login using one-time passwords sent to email
- **Multiple Complaint Types**: Police, Traffic, and Construction complaints
- **GPS Location Tracking**: Capture and view complaint locations on map
- **Department Dashboards**: Separate dashboards for each department to view and manage complaints
- **Complaint Status Management**: Approve or reject complaints
- **User Dashboard**: View complaint history and status

## Setup Instructions

1. Install dependencies:
   ```
   pip install -r requirements.txt
   ```

2. Run migrations (already done):
   ```
   python manage.py migrate
   ```

3. Create superuser for admin access:
   ```
   python manage.py createsuperuser
   ```

4. Run the development server:
   ```
   python manage.py runserver
   ```

5. Access the application:
   - User Portal: http://127.0.0.1:8000/
   - Admin Panel: http://127.0.0.1:8000/admin/

## Usage

### For Regular Users:
1. Go to http://127.0.0.1:8000/
2. Enter your email to receive OTP
3. Check console output for OTP (in development mode)
4. Verify OTP to login
5. Submit complaints with GPS location
6. View complaint status and history

### For Department Users:
1. Admin must create a Department entry linking user to department type
2. Login with email OTP
3. View complaints specific to your department
4. Approve or reject complaints
5. View GPS location of complaints

### Admin Setup:
1. Login to admin panel: http://127.0.0.1:8000/admin/
2. Create Department entries to assign users to departments:
   - User: Select existing user or create new
   - Department Type: Choose police, traffic, or construction
3. Manage complaints and users

## Database

- SQLite database (db.sqlite3) is used for development
- All data is stored locally

## Email Configuration

- Currently using console email backend (OTP printed in console)
- To use real email, update settings.py with SMTP configuration:
  ```python
  EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
  EMAIL_HOST = 'smtp.gmail.com'
  EMAIL_PORT = 587
  EMAIL_USE_TLS = True
  EMAIL_HOST_USER = 'your-email@gmail.com'
  EMAIL_HOST_PASSWORD = 'your-app-password'
  ```

## Google Maps API

- Replace YOUR_API_KEY in view_location.html with actual Google Maps API key
- Or use the Google Maps link provided in the template

## Project Structure

```
smart city/
├── smartcity/          # Project settings
├── complaints/         # Main app
│   ├── models.py      # Database models
│   ├── views.py       # View functions
│   ├── urls.py        # URL routing
│   └── admin.py       # Admin configuration
├── templates/          # HTML templates
├── db.sqlite3         # SQLite database
└── manage.py          # Django management script
```

## Models

- **OTP**: Stores email OTP for authentication
- **Complaint**: Stores complaint details with GPS coordinates
- **Department**: Links users to department types

## Security Notes

- Change SECRET_KEY in production
- Set DEBUG = False in production
- Configure proper email backend
- Add ALLOWED_HOSTS in production
- Use HTTPS in production
