# 🚀 Flutter Mobile App Development Guide

## ✅ Backend API Setup Complete!

I've created the complete Django REST API for your Flutter mobile app. Here's what's been added:

### 📁 New Files Created:

1. **complaints/serializers.py** - Converts Django models to JSON
2. **complaints/api_views.py** - API endpoints for Flutter
3. **complaints/api_urls.py** - API URL routing

### 🔧 Modified Files:

1. **smartcity/urls.py** - Added API routes
2. **smartcity/settings.py** - Added REST Framework configuration
3. **requirements.txt** - Added djangorestframework

---

## 📋 Setup Instructions

### Step 1: Install Dependencies

```bash
pip install djangorestframework
```

Or install all requirements:
```bash
pip install -r requirements.txt
```

### Step 2: Run Migrations

```bash
python manage.py makemigrations
python manage.py migrate
```

### Step 3: Test the API

Start your Django server:
```bash
python manage.py runserver
```

---

## 🔗 API Endpoints Available

### Base URL: `http://127.0.0.1:8000/api/`

### Authentication Endpoints:

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/send-otp/` | Send OTP to email |
| POST | `/api/auth/verify-otp/` | Verify OTP and login |
| POST | `/api/auth/register/` | Register new user |
| POST | `/api/auth/logout/` | Logout user |

### User Endpoints:

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/user/profile/` | Get user profile |
| PUT | `/api/user/profile/` | Update user profile |

### Dashboard Endpoints:

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/dashboard/stats/` | Get dashboard statistics |

### Complaint Endpoints:

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/complaints/` | List all complaints |
| POST | `/api/complaints/` | Create new complaint |
| GET | `/api/complaints/{id}/` | Get complaint details |
| PUT | `/api/complaints/{id}/` | Update complaint |
| DELETE | `/api/complaints/{id}/` | Delete complaint |
| POST | `/api/complaints/{id}/rate/` | Rate a complaint |
| POST | `/api/complaints/{id}/reopen/` | Reopen a complaint |

### Category Endpoints:

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/categories/` | Get all categories |
| GET | `/api/categories/{key}/subcategories/` | Get subcategories |

### Department Endpoints:

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/departments/` | Get all departments |

---

## 🧪 Testing API with Postman/Thunder Client

### 1. Send OTP

**POST** `http://127.0.0.1:8000/api/auth/send-otp/`

**Body (JSON):**
```json
{
  "email": "test@example.com"
}
```

**Response:**
```json
{
  "success": true,
  "message": "OTP sent successfully",
  "otp": "123456"
}
```

### 2. Verify OTP & Login

**POST** `http://127.0.0.1:8000/api/auth/verify-otp/`

**Body (JSON):**
```json
{
  "email": "test@example.com",
  "otp": "123456"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Login successful",
  "token": "abc123xyz456...",
  "user": {
    "id": 1,
    "username": "test",
    "email": "test@example.com",
    "first_name": "",
    "last_name": ""
  },
  "is_new_user": true
}
```

### 3. Get Dashboard Stats (Requires Token)

**GET** `http://127.0.0.1:8000/api/dashboard/stats/`

**Headers:**
```
Authorization: Token abc123xyz456...
```

**Response:**
```json
{
  "success": true,
  "stats": {
    "total_complaints": 10,
    "pending_complaints": 3,
    "resolved_complaints": 5,
    "reopened_complaints": 1,
    "in_progress_complaints": 1
  }
}
```

### 4. Create Complaint (Requires Token)

**POST** `http://127.0.0.1:8000/api/complaints/`

**Headers:**
```
Authorization: Token abc123xyz456...
Content-Type: multipart/form-data
```

**Body (Form Data):**
```
complaint_type: police
subcategory: Theft / Robbery
priority: high
title: Bike Stolen
description: My bike was stolen from parking
latitude: 22.3039
longitude: 70.8022
city: Jamnagar
state: Gujarat
pincode: 361001
address: Near Railway Station
media_files: [file1.jpg, file2.jpg]
```

**Response:**
```json
{
  "success": true,
  "message": "Complaint submitted successfully",
  "complaint": {
    "id": 1,
    "complaint_number": "SC123456",
    "title": "Bike Stolen",
    "status": "pending",
    ...
  }
}
```

---

## 📱 Flutter App Development

### Next Steps:

1. **Setup Google Maps API Key**
   - Go to: https://console.cloud.google.com/
   - Create project
   - Enable Maps SDK for Android/iOS
   - Get API key

2. **Setup Supabase** (for notifications & storage)
   - Go to: https://supabase.com/
   - Create project
   - Get Project URL and API keys
   - Setup storage bucket for images

3. **Flutter Project Structure**

```
janhelp_flutter/
├── lib/
│   ├── main.dart
│   ├── config/
│   │   ├── api_config.dart
│   │   ├── theme.dart
│   │   └── routes.dart
│   ├── models/
│   │   ├── user.dart
│   │   ├── complaint.dart
│   │   └── category.dart
│   ├── services/
│   │   ├── api_service.dart
│   │   ├── auth_service.dart
│   │   └── storage_service.dart
│   ├── screens/
│   │   ├── auth/
│   │   ├── dashboard/
│   │   ├── complaints/
│   │   └── profile/
│   └── widgets/
│       ├── common/
│       └── custom/
├── android/
├── ios/
└── pubspec.yaml
```

---

## 🔐 Important Notes

### Security:

1. **Remove OTP from response** in production (line 51 in api_views.py)
2. **Setup email service** for sending real OTPs
3. **Add rate limiting** for OTP requests
4. **Use HTTPS** in production

### File Upload:

- Currently using Cloudinary for media storage
- Max file size: 10MB per file
- Supported formats: JPG, PNG, MP4, PDF

### Authentication:

- Token-based authentication
- Token never expires (you can add expiry if needed)
- Store token securely in Flutter (flutter_secure_storage)

---

## 🎯 MVP Features (4 Weeks)

### Week 1: ✅ DONE
- [x] Django REST API setup
- [x] Authentication endpoints
- [x] User profile endpoints
- [x] Complaint CRUD endpoints
- [x] Category endpoints

### Week 2: Flutter Foundation
- [ ] Flutter project setup
- [ ] API integration layer
- [ ] Authentication screens
- [ ] Bottom navigation
- [ ] Dashboard UI

### Week 3: Core Features
- [ ] Category selection
- [ ] Submit complaint form
- [ ] Image picker
- [ ] GPS & Maps
- [ ] Track complaints list

### Week 4: Polish & Deploy
- [ ] Complaint details
- [ ] Push notifications
- [ ] Bug fixes
- [ ] Build APK/IPA
- [ ] Deploy backend

---

## 📞 API Support

If you encounter any issues:

1. Check Django server is running
2. Check API endpoint URL is correct
3. Check authentication token is included
4. Check request body format (JSON vs Form Data)
5. Check Django logs for errors

---

## 🚀 Ready to Build Flutter App!

Your Django backend is now ready for Flutter integration. 

**Next Action:** Start building Flutter app or let me know if you want me to create Flutter code!

Would you like me to:
1. Create Flutter project structure?
2. Create API service layer for Flutter?
3. Create authentication screens?
4. Create dashboard screen?

Let me know what you'd like me to build next! 🎯
