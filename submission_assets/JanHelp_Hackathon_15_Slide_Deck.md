# JanHelp Hackathon Presentation Deck

Source format: Markdown for making the final PPT/PPTX deck.  
Deck limit: 15 slides maximum.  
Target talk time: 5-7 minutes.  
Suggested PPTX filename: `JanHelp_SmartCity_Deck.pptx`.

---

## Slide 1 - Team and Project

**Project:** JanHelp  
**Tagline:** AI-enabled smart city complaint and resolution platform  
**Team:** Team JanHelp  
**Team Lead:** Kartik Bhalodiya  

JanHelp helps citizens report civic issues through a mobile-first experience and helps city departments receive clean, verified, location-aware complaints.

Visual: JanHelp logo, mobile app mockup, city service icons, complaint-to-resolution path.

Speaker note: Start with the mission: JanHelp is not only a complaint form. It is a complete civic issue intake, verification, routing, and resolution system.

---

## Slide 2 - Problem Statement

Citizens face friction when reporting civic problems, and departments receive low-quality complaint data.

- Manual forms are long and confusing.
- Citizens often select the wrong issue type.
- Proof photos may be missing, fake, or unrelated.
- Location details are incomplete or inaccurate.
- Duplicate complaints create repeated work.
- Departments lose time deciding who owns the complaint.

Visual: Citizen -> confusing form -> incomplete complaint -> delayed department action.

Speaker note: The real problem is not just complaint submission. The real problem is converting messy citizen input into a reliable work order for the correct department.

---

## Slide 3 - Current Manual Complaint Flow

Traditional complaint filling is slow and error-prone.

1. Citizen opens a portal or visits an office.
2. Citizen manually chooses category, location, and description.
3. Citizen may skip proof or upload the wrong photo.
4. Staff reviews the complaint and asks for missing details.
5. Department manually checks whether the same issue already exists.
6. Complaint is forwarded after delay.

Result: slow intake, low trust, duplicate tickets, and delayed city response.

Visual: Manual form with warning marks for category, proof, location, and department.

Speaker note: This slide shows why a normal digital form is not enough. A city needs guided intake, proof validation, and automatic routing.

---

## Slide 4 - JanHelp Solution Overview

JanHelp converts a civic issue into a verified, trackable complaint lifecycle.

- Citizen reports issue from mobile app or web flow.
- AI assistant helps collect correct complaint details.
- Image analysis checks whether proof matches the issue.
- Duplicate detection reduces repeated tickets.
- System assigns the nearest suitable department.
- Citizen tracks status, gives rating, and can reopen poor resolution.
- City admins monitor complaint load and department performance.

Visual: Report -> AI assist -> proof check -> duplicate check -> department -> resolution -> feedback.

Speaker note: The solution covers the full journey from the first citizen message to final department accountability.

---

## Slide 5 - Technology Stack

JanHelp uses a practical full-stack architecture.

| Layer | Technology |
|---|---|
| Mobile App | Flutter for Android, iOS, and future web support |
| Backend API | Python Django and Django REST Framework |
| Authentication | OTP, password login, JWT access and refresh tokens |
| Database | PostgreSQL in production, SQLite for local development |
| Media Storage | Cloudinary for complaint images and proof media |
| AI | Google Gemini for image proof analysis and voice/call prototype |
| Chat Intelligence | AI-assisted conversation plus rule-based fallback |
| Deployment | DigitalOcean cloud target with domain, database, and media services |

Visual: Flutter app -> Django API -> PostgreSQL -> Cloudinary -> Gemini AI -> department dashboards.

Speaker note: Keep this slide simple. Judges should understand that JanHelp is not a mockup; it has app, backend, database, storage, AI, and deployment layers.

---

## Slide 6 - Citizen App Experience

The citizen app focuses on fast reporting with minimum friction.

- Login with OTP or continue through guest reporting.
- Select complaint category and subcategory.
- Add description, address, GPS location, and contact preference.
- Upload image proof.
- Track complaint number and live status.
- Receive updates and submit feedback.
- Reopen if the issue is marked solved but still exists.

Visual: Mobile screens for login, complaint form, proof upload, tracking, and feedback.

Speaker note: Citizens should not need technical knowledge. The app guides them step by step and still produces structured data for departments.

---

## Slide 7 - Manual Complaint Filling in JanHelp

JanHelp keeps a structured manual form for users who prefer direct control.

- User selects issue type such as road, water, electricity, traffic, garbage, police, cyber, or other civic issue.
- Form changes based on category and subcategory.
- User enters description and location.
- App captures image proof and contact preference.
- System validates fields before submission.
- Complaint ID is generated after successful submission.

Use case: A citizen sees a pothole and wants to submit a quick complaint without chatting with AI.

Visual: Step-by-step form journey with category, location, proof, and submit.

Speaker note: Manual mode is important because not every user wants a chatbot. JanHelp supports both fast direct reporting and assisted reporting.

---

## Slide 8 - Chatbot Complaint Filling

The chatbot helps citizens who do not know how to structure a complaint.

- Citizen writes naturally: "There is dirty water leaking near my street."
- Chatbot detects likely category and urgency.
- It asks only missing questions: location, proof, contact, and extra details.
- It confirms the complaint summary before final submission.
- The final output becomes the same structured complaint record used by departments.

Use case: A citizen describes the problem in normal language instead of understanding government categories.

Visual: Chat conversation becoming a structured complaint card.

Speaker note: This is where AI improves data quality. The citizen speaks naturally, but the city receives a clean complaint.

---

## Slide 9 - AI Call Complaint Filling

JanHelp includes voice-call complaint logic as an advanced accessibility feature.

- Citizen selects a language and starts a call-style complaint flow.
- AI listens to the user's spoken issue.
- The call flow asks follow-up questions for missing details.
- Voice transcript is converted into category, location, proof need, and complaint summary.
- The complaint draft can be submitted to the backend after confirmation.

Use case: Elderly users, low-literacy users, or citizens who prefer speaking instead of typing can still report issues.

Current status: Voice/call logic exists as a prototype and should be demoed only if final screen and provider wiring are ready.

Visual: Language select -> AI call -> transcript -> complaint summary -> submit.

Speaker note: Present this honestly. It is a powerful future differentiator, but the live demo should only claim what is working end to end.

---

## Slide 10 - AI Image Proof Analysis

Image analysis improves trust before a complaint reaches the department.

- Citizen uploads photo proof.
- System checks image quality before spending AI cost.
- AI verifies whether the photo matches the selected complaint type.
- Invalid, blank, too dark, unrelated, or weak proof can be rejected.
- Valid proof is attached to the complaint record.

Use case: If someone reports garbage but uploads an unrelated image, the system can stop weak complaints early.

Visual: Upload image -> quality check -> Gemini analysis -> accepted or rejected proof.

Speaker note: This reduces fake complaints and helps departments focus on real civic work.

---

## Slide 11 - Automatic Nearest Department Assignment

After validation, JanHelp routes complaints automatically.

- Complaint category decides the department type.
- City and state are used to find the correct local department.
- Location distance is used to choose the nearest suitable department.
- Duplicate checks compare nearby active complaints.
- Department receives a cleaner case with proof, location, category, and citizen details.

Use case: A water leak should go to the nearest active water department, not a generic admin inbox.

Visual: Map with citizen issue pin, duplicate cluster, and nearest department route.

Speaker note: This is the operational core. JanHelp reduces manual forwarding and makes complaint ownership clearer.

---

## Slide 12 - Department Dashboard

Each department gets a focused operational dashboard.

- View assigned complaints.
- Filter by status, category, city, and priority.
- Check location and proof before sending staff.
- Update progress stages.
- Upload resolution proof.
- Mark complaint resolved after work completion.

Use case: A road department can see all active pothole complaints and prioritize the most urgent or repeated locations.

Visual: Department dashboard with queue, status filters, map, and proof panel.

Speaker note: Department users need speed and clarity. The dashboard should behave like a work queue, not a static report page.

---

## Slide 13 - City Admin Dashboard

City admins need visibility across the full system.

- Monitor total complaints, pending complaints, resolved complaints, and overdue work.
- Manage categories, subcategories, cities, and departments.
- Track department workload.
- Review complaint trends by area and issue type.
- Identify repeated civic hotspots.
- Improve planning using complaint data.

Use case: A city admin sees that one ward has repeated garbage complaints and assigns extra collection capacity.

Visual: City dashboard with metrics, heatmap, department workload, and category trends.

Speaker note: This makes JanHelp useful beyond individual complaints. It becomes a civic intelligence layer for city planning.

---

## Slide 14 - Rating, Reopen, and Accountability Flow

JanHelp keeps accountability after a complaint is marked resolved.

- Department uploads resolution proof.
- Citizen reviews the work.
- Citizen gives rating and feedback.
- If the issue is not actually solved, citizen can reopen within the allowed window.
- Reopen proof and reason are stored with the complaint history.

Use case: If a pothole is marked fixed but still dangerous, the citizen can reopen the same complaint instead of starting from zero.

Visual: Resolve -> proof -> citizen rating -> satisfied or reopen -> department action.

Speaker note: This closes the trust gap. Citizens get a voice after closure, and departments get measurable service quality.

---

## Slide 15 - Use Cases, Impact, and Demo Flow

Primary use cases:

- Road damage and potholes.
- Water leakage and drainage overflow.
- Garbage collection issues.
- Electricity and streetlight complaints.
- Traffic and construction problems.
- Police, cyber, and safety reports.

Expected impact:

- Faster complaint intake.
- Better proof quality.
- Fewer duplicate tickets.
- Faster department assignment.
- Higher citizen trust.
- Better city planning through complaint analytics.

Demo flow: report issue -> AI proof check -> duplicate check -> nearest department assignment -> department dashboard -> status update -> citizen rating or reopen.

Visual: One complete lifecycle from citizen report to city resolution.

Speaker note: End by showing that JanHelp is practical: it reduces citizen friction and gives city teams cleaner, actionable work.
