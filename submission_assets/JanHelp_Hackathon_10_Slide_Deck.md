# JanHelp Hackathon Presentation Deck - 10 Slides

Source format: Markdown for making the final PPT/PPTX deck.  
Target talk time: 4-6 minutes.  
Suggested PPTX filename: `JanHelp_SmartCity_10_Slide_Deck.pptx`.

---

## Slide 1 - Team and Project

**Project:** JanHelp  
**Tagline:** AI-enabled smart city complaint and resolution platform  
**Team:** Team JanHelp  
**Team Lead:** Kartik Bhalodiya

JanHelp helps citizens report civic issues and helps city departments receive clean, verified, location-aware complaints that can be acted on quickly.

Visual: JanHelp logo, mobile app mockup, city map, and complaint-to-resolution path.

Speaker note: Start with the mission. JanHelp is not just a complaint form; it is an intake, verification, routing, tracking, and accountability system.

---

## Slide 2 - Real-World Problem and Manual Flow

Citizens face friction when reporting civic problems, and departments receive low-quality complaint data.

- Manual forms are long and confusing.
- Citizens often select the wrong category or department.
- Proof photos may be missing, fake, blurry, or unrelated.
- Location details are incomplete or inaccurate.
- Duplicate complaints create repeated department work.
- Citizens lose trust when there is no clear tracking or reopen path.

Traditional flow: citizen reports issue -> staff checks missing details -> duplicate check is manual -> complaint is forwarded after delay -> citizen waits without clear status.

Visual: Broken manual complaint pipeline with warning points for category, proof, location, duplicate, department, and tracking.

Speaker note: The real problem is not only complaint submission. The real problem is turning messy citizen input into a reliable work order for the correct department.

---

## Slide 3 - JanHelp Solution and End-to-End Workflow

JanHelp converts a civic issue into a verified, assigned, trackable complaint lifecycle.

Workflow:

1. Citizen reports issue from mobile app, web, chat, or voice flow.
2. JanHelp captures category, subcategory, description, GPS, address, contact, and proof.
3. AI checks image proof quality and issue match.
4. Duplicate detection reduces repeated tickets.
5. System assigns the nearest suitable department.
6. Department updates status and uploads resolution proof.
7. Citizen tracks, rates, and reopens if not actually solved.

Visual: Report -> AI verify -> duplicate check -> nearest department -> dashboard -> resolution proof -> rating/reopen.

Speaker note: This slide is the core product story. JanHelp covers the full journey from citizen report to department accountability.

---

## Slide 4 - Technology Stack and Architecture

JanHelp uses a practical full-stack architecture.

| Layer | Technology |
|---|---|
| Mobile App | Flutter for Android, iOS, and future web support |
| Backend API | Python Django and Django REST Framework |
| Authentication | OTP, password login, JWT access and refresh tokens |
| Database | PostgreSQL in production, SQLite for local development |
| Media Storage | Cloudinary for complaint and proof media |
| AI | Google Gemini for proof verification and assistant logic |
| Notifications | Email/SMS/push-ready notification paths |
| Deployment | Cloud-ready Django backend and Flutter client |

Visual: Flutter app -> Django API -> database/media storage -> Gemini AI -> department/admin dashboards.

Speaker note: Keep this slide simple. Judges should understand this is a real full-stack system, not only a UI mockup.

---

## Slide 5 - Citizen App Experience and Manual Complaint

The citizen experience focuses on fast reporting with minimum friction.

- Login with OTP or continue through guest reporting.
- Select complaint category and subcategory.
- Add title, description, GPS, address, and contact preference.
- Upload image or video proof.
- Preview and submit the complaint.
- Receive complaint number for tracking.
- Track status, see assigned department, give rating, and reopen if needed.

Manual mode is important because not every user wants AI chat. Users who know the issue can directly create a structured complaint.

Visual: Mobile screens for login, category selection, complaint form, proof upload, tracking, and feedback.

Speaker note: Manual reporting remains the fastest path, but it still benefits from AI proof verification, duplicate checking, and auto department assignment.

---

## Slide 6 - AI Chat and Voice Complaint Filling

JanHelp supports assisted complaint intake for users who do not know how to structure a complaint.

**AI chat flow**

- Citizen writes naturally, such as "dirty water is leaking near my street."
- AI detects likely category, urgency, missing details, and proof need.
- AI asks only missing questions.
- Final output becomes the same structured complaint record used by departments.

**Voice/call flow**

- Citizen speaks the issue in a call-style flow.
- System converts speech into complaint draft details.
- Useful for elderly users, low-literacy users, or citizens who prefer speaking.
- If immediate danger is detected, JanHelp gives emergency guidance first.

Visual: Chat and voice inputs transforming into a structured complaint card.

Speaker note: AI improves accessibility and data quality. Citizens can speak naturally, while the city receives structured civic data.

---

## Slide 7 - AI Proof Verification and Duplicate Detection

JanHelp improves trust before a complaint reaches the department.

**AI proof verification**

- Citizen uploads proof image.
- System rejects tiny, dark, blank, or weak images before AI cost.
- Gemini checks whether proof matches the selected issue.
- Invalid or unrelated evidence can be rejected.

**Duplicate detection**

- Nearby active complaints are checked before creating repeated work.
- Public civic issues use location-radius logic.
- Duplicate ticket IDs are masked for privacy.
- Citizens can be guided to track the existing complaint instead of creating noise.

Visual: Upload proof -> quality check -> Gemini verification -> duplicate scan -> accept/reject/track existing.

Speaker note: Departments should not waste field time on fake proof or ten copies of the same pothole. JanHelp reduces noise before routing.

---

## Slide 8 - Automatic Nearest Department Assignment

After validation, JanHelp routes complaints automatically.

- Complaint category decides department type.
- City and state help find the correct local department.
- GPS distance chooses the nearest suitable active department.
- Fallback logic can use state-level or global nearest department when needed.
- Department receives a cleaner case with proof, location, category, citizen contact, and status.
- Users can see department name, phone, email, address, and map location when available.

Use case: A water leak should go to the nearest active water department, not a generic admin inbox.

Visual: Map with issue pin, duplicate cluster, and route to nearest department.

Speaker note: This is the operational core. JanHelp reduces manual forwarding and makes ownership clear.

---

## Slide 9 - Department and City Admin Dashboards

JanHelp gives each role the right operational view.

**Department dashboard**

- View assigned complaints.
- Filter by status, category, city, and priority.
- Check proof and location before field action.
- Update status from pending to confirmed to in progress to solved.
- Upload resolution proof.

**City admin dashboard**

- Monitor total, pending, solved, overdue, and reopened complaints.
- Manage departments, categories, subcategories, cities, and users.
- Review heatmaps, workload, solve ratio, and issue trends.
- Identify repeated civic hotspots for planning.

Visual: Department work queue plus city admin metrics/heatmap dashboard.

Speaker note: JanHelp becomes useful beyond individual complaints. It becomes a civic intelligence layer for city planning.

---

## Slide 10 - Accountability, Impact, and Demo Flow

JanHelp keeps accountability after a complaint is marked solved.

- Department uploads resolution proof.
- Citizen reviews the work.
- Citizen gives rating and feedback.
- If the issue is not actually solved, citizen can reopen within the allowed window.
- Reopen reason and proof are stored in the complaint history.

Expected impact:

- Faster complaint intake.
- Better proof quality.
- Fewer duplicate tickets.
- Faster department assignment.
- Higher citizen trust.
- Better planning through complaint analytics.

Demo flow: report issue -> AI proof check -> duplicate check -> nearest department assignment -> department dashboard -> status update -> resolution proof -> citizen rating or reopen.

Visual: Complete lifecycle from citizen report to verified city resolution.

Speaker note: End by showing the practical value: JanHelp reduces citizen friction and gives city teams cleaner, actionable work.

