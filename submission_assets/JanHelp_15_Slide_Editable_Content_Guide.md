# JanHelp 15-Slide Editable Content Guide

This file gives you exact content to paste into a fully editable PowerPoint or Google Slides deck.

Design direction:
- Background: white
- Style: clean Google-inspired look
- Use editable text boxes, editable rounded rectangles, editable arrows, editable tables, and editable icons
- Main colors:
  - Blue: `#4285F4`
  - Red: `#EA4335`
  - Yellow: `#FBBC05`
  - Green: `#34A853`
  - Teal: `#0F9D8A`
  - Dark text: `#1F2937`
  - Gray text: `#6B7280`
  - Light border: `#E5E7EB`

Project details used here:
- Project Name: `JanHelp`
- Team Name: `JanHelp`
- Team Leader: `Kartik Bhalodiya`
- GitHub: `https://github.com/kartkbhalodiya/Smart-CITY`
- MVP / Prototype Link: `https://janhelp.vercel.app`

If your team name or leader name is different, replace those two fields before final submission.

---

## Slide 1 - Guidelines / Intro Overlay

### Add This Small Overlay Card
**Title:**  
JanHelp

**Subtitle:**  
AI-enabled civic complaint platform

**Small chips:**  
- Multilingual AI
- Gemini Verification
- Smart Routing
- Cloud Ready

**Small footer line:**  
Team: JanHelp | Lead: Kartik Bhalodiya

### Design Notes
- Keep original template visible
- Add one white rounded rectangle card near bottom-right or bottom-center
- Use blue title, gray subtitle, and colored chips

---

## Slide 2 - Team Details

**Team name:**  
JanHelp

**Team leader name:**  
Kartik Bhalodiya

**Problem Statement:**  
How might we help citizens report civic issues in their own language, verify proof with AI, and route complaints to the right department faster for transparent urban grievance redressal?

### Layout Notes
- Keep labels on left
- Put answer text in editable text boxes on right
- Place problem statement inside a large rounded white card with thin gray border

---

## Slide 3 - Brief About Your Solution

### Short Heading
Accessible urban grievance redressal

### Left Side Bullets
- Citizens report civic issues in English, Hindi, or Gujarati through a guided mobile app.
- Google Gemini verifies uploaded civic evidence before complaint submission.
- The backend detects duplicates, assigns the nearest responsible department, and supports live complaint tracking.

### Solution Summary Paragraph
JanHelp is an AI-enabled smart city complaint platform that combines a Flutter citizen app, a Django REST backend, and cloud deployment for fast and structured grievance redressal. Citizens can submit complaints with location and media, while the system validates evidence, reduces duplicate reports, routes each case to the nearest department, and improves transparency through tracking, notifications, and administrative analytics.

### Bottom Highlight Cards
**Citizen-first UX**  
Low-friction reporting on mobile

**AI + Governance**  
Gemini proof checks plus smart workflow routing

**Cloud-ready**  
Vercel deployment plus managed services

---

## Slide 4 - Opportunities

### Question A
How different is it from any of the other existing ideas?

**Answer:**  
Unlike static complaint forms, JanHelp combines multilingual guided intake, AI-based proof verification, duplicate detection, and geo-based department routing in one unified citizen platform.

### Question B
How will it be able to solve the problem?

**Answer:**  
It improves complaint quality, reduces wrong-category submissions, avoids repeated tickets in the same area, and sends each complaint to the correct department faster for better response time.

### Question C
USP of the proposed solution

**Answer:**  
JanHelp’s USP is a citizen-friendly mobile workflow backed by Google AI verification, nearest-department routing, SLA-aware tracking, and city-scale operational visibility.

---

## Slide 5 - List of Features Offered by the Solution

### Feature 1
**Multilingual AI Intake**  
Users describe issues in English, Hindi, or Gujarati.

### Feature 2
**OTP-Secured Onboarding**  
Email OTP login with role-aware access control.

### Feature 3
**Gemini Proof Verification**  
AI checks whether uploaded media matches the civic complaint category.

### Feature 4
**Dynamic Categories**  
Categories and subcategories load from managed backend data.

### Feature 5
**Duplicate Detection**  
Nearby repeat complaints are automatically identified and reduced.

### Feature 6
**Nearest Department Routing**  
Complaints auto-assign by type, city, state, and location distance.

### Feature 7
**Tracking, SLA, and Reopen Flow**  
Citizens monitor progress and can reopen unresolved complaints.

### Feature 8
**Analytics and Notifications**  
Departments and admins get complaint visibility, reminders, and status alerts.

---

## Slide 6 - Process Flow Diagram / Use Case Diagram

Use 8 editable boxes connected by arrows.

### Step 1
**Citizen Login**  
OTP login or guest access

### Step 2
**Describe Issue**  
AI assistant captures complaint context

### Step 3
**Add Proof**  
Photo, location, and issue details

### Step 4
**AI Validate**  
Gemini proof screening for category relevance

### Step 5
**Duplicate Check**  
Prevent repeated tickets in the same nearby area

### Step 6
**Route Department**  
Assign nearest responsible department

### Step 7
**Track and Notify**  
Status updates, SLA visibility, reminders

### Step 8
**Resolve or Reopen**  
Citizen feedback and reopen loop

### Bottom Banner Text
Outcome: cleaner complaints, faster routing, fewer duplicates, and better citizen trust.

---

## Slide 7 - Wireframes / Mock Diagrams

Build 3 editable phone mockups using shapes.

### Phone 1 Label
Home Dashboard

**Inside content:**  
- JanHelp top bar  
- Live Stats  
- Departments  
- Quick Report  
- 12 categories available

### Phone 2 Label
AI Assistant

**Inside content:**  
- JanHelp top bar  
- Colored chat bubbles  
- Input bar at bottom  
- Placeholder text: Describe issue in any language

### Phone 3 Label
Track Status

**Inside content:**  
- JanHelp top bar  
- SC482913  
- Assigned to Road Department  
- In Progress  
- Resolved plus reopen window

### Footer Note
These wireframes represent the implemented citizen dashboard, assistant workflow, and complaint tracking experience.

---

## Slide 8 - Architecture Diagram

Use 6 editable blocks with arrows.

### Top Block 1
**Citizen Layer**
- Flutter mobile app
- Dashboard and tracking screens
- AI chat and complaint submission

### Top Block 2
**Application Core**
- Django REST API
- Authentication, OTP, JWT
- Complaint workflow engine
- Category and department services
- Tracking, SLA, and reopen logic

### Top Block 3
**Stakeholder Layer**
- Department dashboards
- City admin analytics
- Heatmaps and complaint views
- Operational notifications

### Bottom Block 1
**AI Services**
- Google Gemini 1.5 Flash proof verification
- SmartCityAI extraction
- Duplicate heuristics
- Routing decisions

### Bottom Block 2
**Data Layer**
- Supabase PostgreSQL
- Complaint metadata
- Categories
- Departments
- Session and cache support

### Bottom Block 3
**Cloud Services**
- Vercel deployment
- Cloudinary media storage
- Email services
- Notification support

---

## Slide 9 - Technologies to Be Used

### Panel 1
**Mobile and UX**
- Flutter
- Dart
- Provider
- SharedPreferences

### Panel 2
**Backend and APIs**
- Python
- Django
- Django REST Framework
- JWT

### Panel 3
**AI and Intelligence**
- Google Gemini 1.5 Flash
- SmartCityAI
- NLP extraction
- Duplicate logic

### Panel 4
**Cloud and Data**
- Vercel / google cloud / aws / render
- Supabase PostgreSQL
- Cloudinary
- Redis or cache support

### Panel 5
**Maps and Alerts**
- Geolocation
- Map-ready services
- Email notifications
- Push-ready alerts

### Small Footer Line
Cloud deployment and Google AI are already reflected in the current stack.

---

## Slide 10 - Estimated Implementation Cost

### Small Intro Line
Illustrative pilot estimate for a small-city rollout

### Table
| Cost Head | Estimated Cost |
|---|---|
| Cloud hosting and deployment | Rs 0 - 2,000 / month |
| Database and storage | Rs 0 - 3,500 / month |
| Cloudinary media handling | Rs 0 - 2,500 / month |
| Gemini and AI usage | Rs 1,000 - 4,000 / month |
| Email, alerts, and maintenance buffer | Rs 1,500 - 3,000 / month |

### Bottom Highlight
Estimated pilot total: Approx Rs 4,500 - 15,000 / month

### Footer Note
The MVP can begin on free or low-cost tiers and scale gradually with complaint volume.

---

## Slide 11 - Snapshots of the MVP

Use 3 editable phone mockups or editable visual cards.

### Snapshot 1
**Home Dashboard**
- Live stats
- Department cards
- Quick complaint access

### Snapshot 2
**AI Assistant**
- Guided complaint intake
- Multilingual interaction
- Smart follow-up prompts

### Snapshot 3
**Tracking Flow**
- Ticket number
- Department assignment
- Progress status
- Resolution and reopen flow

### Bottom Note
Other implemented screens include OTP login, category selection, proof upload, location picker, and complaint submission.

---

## Slide 12 - Additional Details / Future Development

### Left Card Title
Near-Term Development

### Left Card Bullets
- Voice-first complaint filing using speech-to-text for low-literacy users
- Support for more Indian languages and localized assistant prompts
- Faster department escalation when SLA breaches are predicted
- Expanded post-resolution feedback loop with citizen quality scoring

### Right Card Title
City-Scale Vision

### Right Card Bullets
- Heatmap-based hotspot detection for ward-level planning
- Cross-department orchestration for multi-issue complaints
- Citizen-to-admin insights dashboard for service prioritization
- API integration with municipal ERP, helpline, WhatsApp, and IVR channels

### Bottom Banner
JanHelp is designed to start as an MVP and scale into a city operations platform.

---

## Slide 13 - Provide Links

### Link 1
**GitHub Public Repository**  
https://github.com/kartkbhalodiya/Smart-CITY

### Link 2
**Demo Video Link (3 Minutes)**  
Add your 3-minute YouTube or Drive demo link here

### Link 3
**MVP Link**  
https://janhelp.vercel.app

### Link 4
**Working Prototype Link**  
https://janhelp.vercel.app

### Design Note
- Use 4 stacked rounded cards
- Add numbered colored circles:
  - 1 blue
  - 2 yellow
  - 3 green
  - 4 purple

---

## Slide 14 - Pilot Readiness and Expected Impact

### Top Heading
Pilot Readiness and Expected Impact

### Top Card 1
**24/7 Access**  
Citizens can report civic issues anytime through multilingual guided intake.

### Top Card 2
**Cleaner Data**  
AI proof verification and duplicate suppression improve complaint quality.

### Top Card 3
**Faster Routing**  
Nearest-department assignment reduces manual triage and operational delay.

### Bottom Left Section
**Why JanHelp is Deployment-Ready Now**
- Cloud deployment already defined in the backend stack
- Google Gemini already integrated into proof verification flow
- Citizen, department, and admin workflows already modeled

### Bottom Right Section
**Suggested Pilot KPIs**
- Complaint submission time reduced
- Duplicate complaints reduced
- Routing accuracy improved
- Citizen satisfaction improved

---

## Slide 15 - Final Branding / Closing Slide

### Main Title
JanHelp

### Subtitle
AI-enabled civic complaint platform

### Supporting Line
Citizen-first | AI-assisted | Cloud-ready

### Team Line
Team: JanHelp  
Lead: Kartik Bhalodiya

### Optional Chips
- Multilingual AI
- Gemini Verification
- Smart Routing
- Transparent Tracking

### Closing Message
Smarter complaint reporting for more responsive cities.

---

## Quick Paste Version

If you want to copy slide-by-slide very fast:

### Slide 2
- Team name: JanHelp
- Team leader name: Kartik Bhalodiya
- Problem statement: How might we help citizens report civic issues in their own language, verify proof with AI, and route complaints to the right department faster for transparent urban grievance redressal?

### Slide 3
- Accessible urban grievance redressal
- Citizens report issues in English, Hindi, or Gujarati through a guided mobile app.
- Google Gemini verifies uploaded civic evidence before complaint submission.
- The backend detects duplicates, assigns the nearest responsible department, and supports live complaint tracking.

### Slide 4
- Different: multilingual guided intake + AI proof verification + duplicate detection + geo-routing
- Solves problem: better complaint quality + less duplication + faster routing
- USP: citizen-friendly flow + Google AI + SLA tracking + transparency

### Slide 5
- Multilingual AI Intake
- OTP-Secured Onboarding
- Gemini Proof Verification
- Dynamic Categories
- Duplicate Detection
- Nearest Department Routing
- Tracking, SLA, and Reopen
- Analytics and Notifications

### Slide 6
- Citizen Login
- Describe Issue
- Add Proof
- AI Validate
- Duplicate Check
- Route Department
- Track and Notify
- Resolve or Reopen

### Slide 8
- Citizen Layer
- Application Core
- Stakeholder Layer
- AI Services
- Data Layer
- Cloud Services

### Slide 9
- Flutter, Dart, Provider, SharedPreferences
- Python, Django, DRF, JWT
- Google Gemini 1.5 Flash, SmartCityAI
- Vercel, Supabase, Cloudinary

### Slide 10
- Estimated pilot total: Approx Rs 4,500 - 15,000 / month

### Slide 12
- Voice-first filing
- More language support
- Faster escalation
- City-scale analytics and integration

### Slide 13
- GitHub: https://github.com/kartkbhalodiya/Smart-CITY
- Demo: add your link
- MVP: https://janhelp.vercel.app
- Prototype: https://janhelp.vercel.app

