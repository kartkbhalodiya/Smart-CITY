<div align="center">

<img src="submission_assets/preview/screen-01.png" alt="JanHelp Banner" width="100%"/>

# 🏙️ JanHelp — Smart City Complaint Management System

**AI-powered civic complaint platform connecting citizens to city departments — instantly, intelligently, and in their language.**

[![Live Demo](https://img.shields.io/badge/🌐_Live_Demo-janhelps.in-blue?style=for-the-badge)](https://janhelps.in)
[![Flutter App](https://img.shields.io/badge/📱_Flutter-Mobile_App-02569B?style=for-the-badge&logo=flutter)](https://flutter.dev)
[![Django](https://img.shields.io/badge/⚙️_Backend-Django_5.2-092E20?style=for-the-badge&logo=django)](https://djangoproject.com)
[![Gemini AI](https://img.shields.io/badge/🤖_AI-Gemini_2.5_Flash-4285F4?style=for-the-badge&logo=google)](https://ai.google.dev)
[![Google Solution Challenge](https://img.shields.io/badge/🏆_Google-Solution_Challenge_2026-EA4335?style=for-the-badge&logo=google)](https://developers.google.com/community/gdsc-solution-challenge)

</div>

---

## 📸 Screenshots

<table>
  <tr>
    <td align="center"><img src="submission_assets/preview/screen-01.png" width="100%"/></td>
    <td align="center"><img src="submission_assets/preview/screen-02.png" width="100%"/></td>
    <td align="center"><img src="submission_assets/preview/screen-03.png" width="100%"/></td>
  </tr>
  <tr>
    <td align="center"><img src="submission_assets/preview/screen-04.png" width="100%"/></td>
    <td align="center"><img src="submission_assets/preview/screen-05.png" width="100%"/></td>
    <td align="center"><img src="submission_assets/preview/screen-06.png" width="100%"/></td>
  </tr>
  <tr>
    <td align="center" colspan="3"><img src="submission_assets/preview/screen-07.png" width="34%"/></td>
  </tr>
</table>

---

## 🌟 What is JanHelp?

JanHelp is a full-stack **Smart City Complaint Management System** that empowers citizens to report civic issues — potholes, water leaks, power outages, cyber fraud, and more — through a web portal or Flutter mobile app. Complaints are automatically routed to the nearest responsible department using geo-distance logic, verified by **Google Gemini AI**, and tracked end-to-end with real-time status updates.

> **"Jan" means "People" in Hindi. JanHelp = Help for the People.**

---

## 🏗️ Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         CITIZEN LAYER                               │
│  ┌──────────────────┐          ┌──────────────────────────────────┐ │
│  │  Flutter Mobile  │          │     Web Portal (Django + HTML)   │ │
│  │  App (iOS/Android│          │     janhelps.in                  │ │
│  └────────┬─────────┘          └──────────────┬───────────────────┘ │
└───────────┼──────────────────────────────────┼─────────────────────┘
            │  REST API (JWT Auth)              │  Django Views
            ▼                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      DJANGO BACKEND (Python)                        │
│                                                                     │
│  ┌─────────────────┐  ┌──────────────────┐  ┌───────────────────┐  │
│  │  Complaint API  │  │  Auth & OTP Flow │  │  Admin Dashboards │  │
│  │  (DRF + JWT)    │  │  (Email/Session) │  │  Super/City/Dept  │  │
│  └────────┬────────┘  └────────┬─────────┘  └─────────┬─────────┘  │
│           │                   │                       │             │
│  ┌────────▼───────────────────▼───────────────────────▼──────────┐  │
│  │                    CORE SERVICES                               │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐ │  │
│  │  │ Geo-Distance │  │  Duplicate   │  │  SLA Tracking &      │ │  │
│  │  │ Dept Routing │  │  Detection   │  │  Reopen Window       │ │  │
│  │  └──────────────┘  └──────────────┘  └──────────────────────┘ │  │
│  └────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
            ┌──────────────────┼──────────────────────┐
            ▼                  ▼                      ▼
┌───────────────────┐ ┌─────────────────┐ ┌──────────────────────┐
│   GOOGLE AI LAYER │ │  DATA LAYER     │ │  NOTIFICATION LAYER  │
│                   │ │                 │ │                      │
│  ┌─────────────┐  │ │  PostgreSQL     │ │  Resend Email API    │
│  │ Gemini 2.5  │  │ │  (Production)  │ │  SMS (Twilio)        │
│  │ Flash       │  │ │                 │ │  Push Notifications  │
│  │ Proof Verify│  │ │  SQLite         │ │  (Supabase)          │
│  └─────────────┘  │ │  (Development) │ │                      │
│  ┌─────────────┐  │ │                 │ │                      │
│  │ Gemini AI   │  │ │  Cloudinary     │ │                      │
│  │ Chat Bot    │  │ │  (Media Files)  │ │                      │
│  └─────────────┘  │ │                 │ │                      │
│  ┌─────────────┐  │ │  Redis Cache    │ │                      │
│  │ Google Fonts│  │ │  (Optional)     │ │                      │
│  └─────────────┘  │ └─────────────────┘ └──────────────────────┘
└───────────────────┘
```

### User Role Flow

```
Citizen ──► Submit Complaint ──► AI Proof Verify (Gemini) ──► Duplicate Check
                                                                      │
                                                              ┌───────▼────────┐
                                                              │ Geo-Route to   │
                                                              │ Nearest Dept   │
                                                              └───────┬────────┘
                                                                      │
Department ◄── Email/SMS Alert ◄──────────────────────────────────────┘
    │
    ▼
Update Status: Pending → Confirmed → In Progress → Solved
    │
    ▼
Citizen ◄── Email/SMS Notification ◄── Rating & Feedback
    │
    └──► Reopen (within 7 days with proof) if unsatisfied
```

---

## 🤖 Google Technology Usage

### 1. Google Gemini AI — Proof Verification (`complaints/ai_utils.py`)

Every complaint submission with a photo is verified by **Gemini 2.5 Flash** before it reaches the department. The AI:

- Analyzes the uploaded image against the selected complaint category and subcategory
- Rejects blurry, blank, or unrelated images automatically
- Applies category-specific logic (e.g., screenshots accepted for Cyber Crime, physical scene required for Road/Pothole)
- Falls back gracefully through model versions: `gemini-2.5-flash` → `gemini-2.0-flash` → `gemini-2.0-flash-001`

```python
# From complaints/ai_utils.py
prompt = f"""
You are a municipal complaint proof verifier.
Selected complaint:
- Category: {category_label}
- Subcategory / issue: {selected_issue}
- Citizen description: {complaint_description}
...
Return ONLY valid JSON: {{"match":"YES" or "NO","reason":"short reason",...}}
"""
result_text, used_model = _generate_with_model_fallback(
    api_key=api_key,
    preferred_model="gemini-2.5-flash",
    prompt=prompt,
    image_data=image_data,
    mime_type=mime_type,
)
```

### 2. Google Gemini AI — Conversational Complaint Assistant (`complaints/conversational_ai.py`)

A full-featured AI chatbot (`SmartCityAI`) that:

- Guides citizens step-by-step through complaint filing in **English, Hindi, Gujarati, and Marathi**
- Detects complaint category, subcategory, urgency, and emergency signals from natural language
- Maintains session state across 8-hour conversation windows
- Provides time-aware greetings (Good morning / Good afternoon / Good evening)
- Escalates to emergency helpline (112) for critical situations

```python
# SmartCityAI supports 12 complaint categories × 10 subcategories each
# with full multilingual taxonomy and Gemini-powered response generation
```

### 3. Google Fonts (`smartcity_application/pubspec.yaml`)

The Flutter mobile app uses `google_fonts: ^6.1.0` for consistent, beautiful typography across all screens.

### 4. Google Solution Challenge 2026

This project is submitted to the **Google Developer Student Clubs Solution Challenge 2026**, addressing **UN SDG 11: Sustainable Cities and Communities**.

---

## ✨ Key Features

### For Citizens
- 🗺️ **GPS-based complaint submission** with auto-detected city, state, and pincode
- 🤖 **AI chatbot** for guided complaint filing in 4 languages
- 📸 **AI proof verification** — Gemini validates your photo before submission
- 🔍 **Duplicate detection** — prevents re-reporting the same issue (50m radius for public, 5m for private)
- 📊 **Real-time tracking** with complaint number and status timeline
- ⭐ **Rate & feedback** after resolution
- 🔄 **Reopen complaints** within 7 days if issue persists
- 👤 **Guest mode** — no registration required for basic complaints

### For Departments
- 📋 **Auto-assigned complaints** based on geo-distance and department type
- 🔄 **Structured workflow**: Pending → Confirmed → In Progress → Solved
- 📎 **Resolution proof upload** required before marking solved
- 📧 **Automated email/SMS** notifications on every status change
- ⏱️ **SLA tracking** with overdue alerts

### For City Admins & Super Admins
- 🗺️ **Interactive heatmap** of complaints and departments (Leaflet.js)
- 📈 **Analytics dashboard** with solve ratios, average ratings, SLA breach %
- 🏢 **Department management** with OTP-verified creation
- 👥 **Citizen management** and complaint oversight
- 🏷️ **Dynamic complaint categories** — fully configurable from admin panel
- 🌍 **Multi-city, multi-state** support with managed state/city registry

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| Backend | Django 5.2, Django REST Framework, SimpleJWT |
| Mobile | Flutter 3.x (iOS, Android, Web) |
| AI | Google Gemini 2.5 Flash |
| Database | PostgreSQL (prod), SQLite (dev) |
| Media Storage | Cloudinary |
| Static Files | Whitenoise |
| Email | Resend API / SMTP |
| SMS | Twilio |
| Push Notifications | Supabase |
| Cache | Redis / LocMemCache |
| Maps | Leaflet.js, OpenStreetMap Nominatim |
| Deployment | Vercel (web), Render (API) |
| Fonts | Google Fonts |

---

## 🚀 Quick Start

### Prerequisites
- Python 3.11+
- Flutter 3.x SDK
- PostgreSQL (or SQLite for dev)

### Backend Setup

```bash
# Clone the repository
git clone https://github.com/yourusername/Smart-CITY.git
cd "Smart CITY"

# Create virtual environment
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Configure environment
cp .env.example .env
# Edit .env with your credentials (see Environment Variables section)

# Run migrations
python manage.py migrate

# Create superuser
python manage.py createsuperuser

# Start development server
python manage.py runserver
```

### Flutter App Setup

```bash
cd smartcity_application

# Install dependencies
flutter pub get

# Configure API endpoint
# Edit lib/config/api_config.dart with your backend URL

# Run on device/emulator
flutter run
```

---

## ⚙️ Environment Variables

Create a `.env` file in the project root:

```env
# Django
SECRET_KEY=your-secret-key
DEBUG=False
ALLOWED_HOSTS=yourdomain.com,localhost

# Database
DATABASE_URL=postgresql://user:password@host:5432/dbname

# Google Gemini AI
GEMINI_API_KEY=your-gemini-api-key
GEMINI_MODEL=gemini-2.5-flash

# Cloudinary (Media Storage)
CLOUDINARY_CLOUD_NAME=your-cloud-name
CLOUDINARY_API_KEY=your-api-key
CLOUDINARY_API_SECRET=your-api-secret

# Email (Resend)
RESEND_API_KEY=your-resend-api-key
DEFAULT_FROM_EMAIL=noreply@yourdomain.com

# SMS (Twilio) - Optional
TWILIO_ACCOUNT_SID=your-sid
TWILIO_AUTH_TOKEN=your-token
TWILIO_FROM_NUMBER=+1234567890

# Redis Cache - Optional
REDIS_URL=redis://localhost:6379/0

# App Base URL
BASE_URL=https://yourdomain.com
```

---

## 📁 Project Structure

```
Smart CITY/
├── smartcity/                  # Django project settings
│   ├── settings.py
│   └── urls.py
├── complaints/                 # Core Django app
│   ├── models.py               # Complaint, Department, CitizenProfile, etc.
│   ├── views.py                # All web views
│   ├── api_views.py            # REST API endpoints
│   ├── ai_utils.py             # Gemini proof verification
│   ├── conversational_ai.py    # SmartCityAI chatbot
│   ├── email_utils.py          # Email templates & sending
│   ├── sms_utils.py            # SMS notifications
│   └── serializers.py          # DRF serializers
├── smartcity_application/      # Flutter mobile app
│   └── lib/
│       ├── screens/            # UI screens
│       ├── services/           # API service layer
│       ├── models/             # Data models
│       └── providers/          # State management
├── templates/                  # Django HTML templates
├── static/                     # CSS, JS assets
├── config.json                 # Model training config
└── README.md
```

---

## 🗺️ API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/login/` | JWT login |
| POST | `/api/auth/register/` | Citizen registration |
| GET/POST | `/api/complaints/` | List / create complaints |
| GET | `/api/complaints/{id}/` | Complaint detail |
| POST | `/api/ai/chat/` | AI chatbot message |
| GET | `/api/departments/` | List departments |
| GET | `/api/categories/` | Complaint categories |

---

## 🏆 Google Solution Challenge 2026

JanHelp addresses **UN Sustainable Development Goal 11: Sustainable Cities and Communities** by:

- Making civic complaint filing accessible to all citizens regardless of literacy or language
- Reducing complaint resolution time through intelligent auto-routing
- Providing data-driven insights to city administrators for better urban planning
- Preventing duplicate complaints to reduce administrative overhead
- Enabling accountability through transparent status tracking and citizen ratings

---

## 👥 User Roles

| Role | Access |
|------|--------|
| **Citizen** | Submit complaints, track status, rate resolutions, reopen |
| **Guest** | Submit complaints without registration |
| **Department Officer** | View assigned complaints, update status, upload proof |
| **City Admin** | Manage city departments, view city analytics and heatmap |
| **Super Admin** | Full system access, manage all cities/states/departments |

---

## 📄 License

This project is built for the Google Solution Challenge 2026. All rights reserved.

---

<div align="center">

**Built with ❤️ for citizens, powered by Google AI**

[🌐 Live Demo](https://janhelps.in) · [📱 Download App](#) · [📖 Docs](docs/)

</div>
