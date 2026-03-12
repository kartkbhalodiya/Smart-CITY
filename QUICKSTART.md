# QUICK START GUIDE

## Your Smart City Complaint System is Ready!

### What's Been Set Up:
✓ Django project with SQLite database
✓ Email OTP authentication system
✓ Complaint management (Police, Traffic, Construction)
✓ GPS location tracking
✓ Department dashboards
✓ Sample department users created

### How to Run:

**Option 1: Use the start script**
```
start.bat
```

**Option 2: Manual start**
```
python manage.py runserver
```

### Access the Application:

1. **User Portal**: http://127.0.0.1:8000/
   - Login with any email
   - OTP will be shown in console
   - Submit complaints with GPS location

2. **Department Dashboards**: 
   Login with these pre-created accounts:
   - police@dept.com (Police Department)
   - traffic@dept.com (Traffic Department)  
   - construction@dept.com (Construction Department)
   
   OTP will be shown in console for these too.

3. **Admin Panel**: http://127.0.0.1:8000/admin/
   - Create superuser first: `python manage.py createsuperuser`
   - Manage all users, departments, and complaints

### Testing Flow:

1. **As a Citizen:**
   - Go to http://127.0.0.1:8000/
   - Enter email (e.g., citizen@test.com)
   - Check console for OTP
   - Enter OTP to login
   - Click "Submit Complaint"
   - Choose complaint type
   - Fill details
   - Click "Get Current Location" (allow browser location access)
   - Submit complaint

2. **As a Department:**
   - Go to http://127.0.0.1:8000/
   - Login with police@dept.com (or traffic/construction)
   - Check console for OTP
   - View complaints for your department
   - Click "View GPS" to see location
   - Click "Approve" or "Reject" to update status

### Important Notes:

- **OTP Display**: In development mode, OTP codes are printed in the console window where you run the server
- **GPS Location**: Browser will ask for location permission when submitting complaints
- **Google Maps**: To see maps, add your Google Maps API key in templates/view_location.html
- **Email**: Currently using console backend. For real emails, configure SMTP in settings.py

### File Structure:
```
smart city/
├── complaints/         # Main app with models, views, urls
├── templates/          # HTML templates
├── smartcity/         # Project settings
├── db.sqlite3         # Database
└── manage.py          # Django management
```

### Need Help?

Check README.md for detailed documentation.

Enjoy your Smart City Complaint Management System!
