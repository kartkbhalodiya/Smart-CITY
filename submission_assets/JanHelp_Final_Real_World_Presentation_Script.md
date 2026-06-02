# JanHelp Final Real-World Presentation Script

Source format: Markdown script for converting into PPT/PPTX.
Suggested final PPTX filename: `JanHelp_Final_Real_World_Civic_Workflow_Deck.pptx`.
Suggested talk time: 7 to 9 minutes.
Deck structure: 15 slides.
Project: JanHelp Smart City Complaint Management System.
Live API target used by the Flutter app: `https://janhelps.in/api`.

## Production Truth From The Repo

This presentation is based on the real project implementation, not a generic idea document.

- Backend: Django and Django REST Framework in `complaints/`, deployment entrypoint in `api/index.py`.
- Mobile app: Flutter app in `smartcity_application/`.
- Complaint lifecycle: `Complaint` model supports category, subcategory, proof media, GPS coordinates, guest reporting, assigned department, work status, SLA timing, rating, and reopen fields.
- Verification: `complaints/ai_utils.py` verifies complaint proof images with Gemini and local image-quality checks.
- Duplicate control: `Complaint.check_duplicate()` blocks duplicate active complaints by category, subcategory, location radius, and optional description match.
- Assignment: `Complaint.get_nearest_department()` routes to the nearest active matching department by city/state/distance.
- Tracking: API and web templates expose guest tracking, user complaint tracking, department contact, maps, rating, and reopen flows.
- Access methods: manual form, AI chat endpoint, AI voice/chat endpoint, and Flutter-side conversational/voice services exist in the project.
- Emergency help: the app and web surfaces expose department categories, phone, email, address, coordinates, and 112 guidance for immediate danger.

---

## Slide 1 - Project Name And Final Deck Identity

**JanHelp**

AI-powered smart city complaint, verification, routing, tracking, and accountability platform.

**Team:** Team JanHelp  
**Presentation file name:** `JanHelp_Final_Real_World_Civic_Workflow_Deck.pptx`  
**One-line pitch:** JanHelp turns messy citizen reports into verified, trackable work orders for the nearest responsible city department.

**Visual direction**

- JanHelp logo.
- Mobile app screen.
- City map pin.
- Complaint lifecycle: Report -> Verify -> Assign -> Resolve -> Reopen if needed.

**Speaker script**

JanHelp is not just a complaint form. It is a complete civic service workflow. A citizen can report a real-world issue, JanHelp verifies the proof, checks whether the same issue already exists, assigns the nearest responsible department, and gives the citizen a tracking and reopen path if the work is not actually solved.

**Real project evidence**

- `README.md` describes JanHelp as a smart city complaint management system.
- `smartcity_application/lib/config/api_config.dart` points the mobile app to `https://janhelps.in/api`.

---

## Slide 2 - Current Real-World Problem

Cities do not fail only because citizens cannot submit complaints. They fail because complaint data becomes unreliable before it reaches the right worker.

**Real problems**

- Citizens do not know the correct department or category.
- Complaint photos are missing, blurred, unrelated, fake, or too weak to act on.
- The same pothole, water leak, garbage point, or drainage overflow is reported many times.
- Location data is often incomplete, so teams waste time finding the issue.
- Departments receive unclear tickets and manually decide ownership.
- Citizens lose trust because they cannot see real status, contact the department, or reopen a false resolution.

**Speaker script**

The actual problem is not a lack of forms. The problem is converting unstructured citizen input into a clean, verified, location-aware work order. If that conversion is poor, every step after it becomes slow: department assignment, field work, proof of resolution, and citizen trust.

**Real project evidence**

- `Complaint` stores category, subcategory, description, GPS, city, state, pincode, proof media, department, status, SLA, rating, and reopen data.

---

## Slide 3 - Why Existing Manual Systems Break

Traditional civic complaint flow has too many manual decision points.

**Current manual flow**

1. Citizen sees a problem.
2. Citizen searches where to complain.
3. Citizen selects a department manually or visits an office.
4. Staff asks for missing category, location, and proof.
5. Department checks if the same issue already exists.
6. Complaint is forwarded manually.
7. Citizen waits without clear tracking.
8. If work is marked solved but still exists, citizen often starts again from zero.

**What breaks**

- Data quality breaks at intake.
- Ownership breaks during routing.
- Trust breaks when status is not transparent.
- Accountability breaks when closure has no proof or reopen loop.

**Speaker script**

JanHelp is designed around the real bottleneck: every manual handoff adds delay and ambiguity. If a city wants faster resolution, the complaint must become machine-readable and department-ready at the point of submission.

**Visual direction**

Manual path with red friction points: wrong category, weak proof, duplicate report, wrong department, no tracking, false closure.

---

## Slide 4 - JanHelp Solution

JanHelp converts a civic issue into a verified and assigned service case.

**Core solution**

- Multi-channel complaint intake: manual, AI chat, and voice/call-style flow.
- GPS and address capture.
- Category and subcategory based issue structure.
- Gemini proof verification for uploaded images.
- Duplicate detection before creating repeated work.
- Nearest department assignment using category, city, state, and distance.
- User and guest tracking.
- Department dashboard for status updates and resolution proof.
- Rating, feedback, and reopen if the issue is not actually fixed.
- Admin dashboards for city-level visibility.

**Speaker script**

JanHelp is a workflow system. It starts with the citizen, but it does not stop at submission. It verifies the complaint, reduces noise, routes it to the correct department, and keeps a tracking and accountability loop open until the issue is resolved.

**Real project evidence**

- `ComplaintViewSet.create()` verifies proof, checks duplicates, saves complaint, and returns structured complaint data.
- `Complaint.save()` auto-assigns a department when location is present.

---

## Slide 5 - Real JanHelp Workflow

```text
Citizen issue
  -> Manual form OR AI chat OR voice/call intake
  -> Category, subcategory, description, contact, and GPS captured
  -> Proof upload
  -> Local image-quality check
  -> Gemini proof verification
  -> Duplicate check
  -> Nearest department assignment
  -> Department dashboard queue
  -> Status updates: pending -> confirmed -> process -> solved
  -> Resolution proof
  -> Citizen rating and feedback
  -> Reopen within 7 days if not actually solved
```

**Speaker script**

This is the end-to-end path implemented by the project. JanHelp is not only front-end reporting. The backend has the lifecycle objects, routing logic, duplicate detection, proof verification, department ownership, SLA calculation, and reopen workflow needed for real operations.

**Visual direction**

Horizontal workflow with three intake lanes merging into one verification and assignment pipeline.

---

## Slide 6 - Three Complaint Methods

JanHelp supports different citizen comfort levels.

| Method | Best for | How it works |
|---|---|---|
| Manual | Users who know the issue type | User selects category, fills form, uploads proof, submits |
| AI Chat | Users who describe issues naturally | Chat asks missing questions and converts conversation into structured complaint data |
| Voice / Call | Elderly, low-literacy, or hands-free users | User speaks the complaint; system extracts category, urgency, location, duplicate risk, and department preview |

**Speaker script**

The product decision is important: there is no single perfect intake method. A city serves people with different literacy, language, device, and urgency constraints. JanHelp keeps manual reporting for speed, chat for guided intake, and voice for accessibility.

**Real project evidence**

- API endpoints include `ai/chat/`, `ai/voice-chat/`, `ai/check-duplicate/`, and `ai/get-department/`.
- Flutter services include conversational AI, speech, Gemini audio/live call, and call conversation manager code.

---

## Slide 7 - Method 1: Manual Complaint Submission

Manual mode is the fastest path for users who already know what they want to report.

**User steps**

1. Choose complaint category.
2. Choose subcategory or issue type.
3. Enter title and description.
4. Share GPS/address details.
5. Upload proof image or media.
6. Select contact preference.
7. Preview and submit.
8. Receive complaint number for tracking.

**Value**

- Fast.
- Predictable.
- Works without AI conversation.
- Produces structured data for the backend.

**Speaker script**

Manual mode is still necessary because AI should not block users who know exactly what happened. The system keeps strong validation, proof checks, duplicate checks, and department assignment after the user submits.

**Real project evidence**

- `submit_complaint.html`, `preview_complaint.html`, and Flutter dashboard category screens support direct complaint submission.
- Categories include police, traffic, construction, water, electricity, garbage, road, drainage, illegal activity, transportation, cyber, and other.

---

## Slide 8 - Method 2: AI Chat Complaint Filing

AI chat is for citizens who do not know how to structure the complaint.

**Example**

Citizen says: "There is dirty water leaking near my street."

JanHelp detects:

- Likely category: water or drainage.
- Missing information: exact location, landmark, photo proof, contact preference.
- Urgency level.
- Whether emergency guidance is needed.
- Whether a duplicate complaint already exists after location is known.
- Nearest department preview.

**Speaker script**

The value of chat is not only conversation. The value is that a natural-language report becomes a structured civic work order. The city receives clean fields while the citizen uses normal language.

**Real project evidence**

- `complaints/conversational_ai.py` handles multilingual complaint analysis, emergency signals, duplicate check, and nearest department lookup.
- Flutter `conversational_ai_service.dart` calls duplicate and department APIs during the guided flow.

---

## Slide 9 - Method 3: Voice And Call-Style Complaint Filing

Voice is the accessibility layer for users who prefer speaking.

**Voice workflow**

1. User starts voice/call intake.
2. Assistant asks the language and complaint context.
3. User speaks the issue.
4. System extracts complaint type, location, urgency, duplicate signals, and department preview.
5. User confirms the draft.
6. Complaint is submitted through the same backend pipeline.

**Emergency behavior**

- If immediate danger is detected, the assistant tells the citizen to call 112 first.
- JanHelp can still capture the complaint for department follow-up after safety guidance.

**Speaker script**

Voice is not a separate product. It feeds the same complaint pipeline. That matters because all methods must end in one reliable data model, one tracking ID, and one department workflow.

**Production honesty**

Manual and chat should be treated as core demo paths. Voice/call support exists in services and endpoints, but the live demo should only claim what is wired and configured in the running environment.

**Real project evidence**

- Backend exposes `ai/voice-chat/`.
- Flutter has `speech_service.dart`, `gemini_audio_call_service.dart`, `gemini_live_call_service.dart`, and `call_conversation_manager.dart`.

---

## Slide 10 - AI Verification And Duplicate Check

JanHelp reduces fake, weak, and repeated complaints before the department receives them.

**AI proof verification**

- Local image-quality checks reject tiny, dark, blank, or single-color images before AI cost.
- Gemini checks whether proof matches the selected category, subcategory, and description.
- Category-specific guidance handles police, cyber, electricity, water, and other issue types differently.
- Model fallback is implemented: Gemini 2.5 Flash -> Gemini 2.0 Flash -> Gemini 2.0 Flash 001.

**Duplicate check**

- Active public issues such as road, garbage, drainage, traffic, construction, illegal activity, and transportation use a 50 meter duplicate radius.
- Private/local issues such as water and electricity use a 5 meter radius.
- Police, cyber, and other categories skip the radius duplicate check because they are usually unique incidents.
- Similar exact descriptions within 100 meters can also be treated as duplicates.

**Speaker script**

This is where JanHelp saves department time. A city department should not spend field time on fake proof or ten copies of the same pothole. The platform blocks weak evidence and redirects users to the existing ticket when the same active issue is already being handled.

**Real project evidence**

- `complaints/ai_utils.py` performs local image checks and Gemini proof verification.
- `Complaint.check_duplicate()` defines duplicate radii and skips unique incident categories.
- `ai_check_duplicate()` returns masked duplicate ticket IDs for privacy.

---

## Slide 11 - Nearest Department Assignment And Emergency Help

After verification, JanHelp assigns the complaint to the nearest responsible department.

**Assignment logic**

1. Complaint type maps to a department type.
2. System filters active departments of that type.
3. First preference: same city and state.
4. Second preference: same state.
5. Final fallback: nearest active matching department globally.
6. Distance is calculated using great-circle distance from complaint GPS to department GPS.

**Emergency and help visibility**

- Users can see department name, address, phone, email, and map location.
- Guest and logged-in users can track assigned department contact details.
- Emergency wording tells users to call 112 first when there is immediate danger.
- Department category screens expose police, traffic, water, electricity, garbage, road, drainage, cyber, and other contacts.

**Speaker script**

The routing principle is simple: a complaint should not go to a generic inbox if the system already knows the issue type and location. JanHelp uses category and geo-distance to produce a direct assignment, while still showing citizens how to contact nearby help.

**Real project evidence**

- `Complaint.get_nearest_department()` implements city/state/distance fallback.
- `Department` stores phone, email, address, latitude, longitude, city, state, SLA hours, and active status.
- Guest tracking API returns assigned department contact and coordinates.
- Department list screens expose emergency contact navigation.

---

## Slide 12 - User Dashboard, Guest Tracking, Rating, And Reopen

Citizen trust depends on visibility after submission.

**Logged-in user dashboard**

- View complaint number.
- Track current work status.
- See assigned department.
- View location and proof details.
- Rate solved complaints.
- Reopen within 7 days if the work is not actually resolved.

**Guest tracking**

- Guest users can submit complaints without account friction.
- Guest tracking uses complaint number and mobile number.
- Guest response includes assigned department name, phone, email, map coordinates, complaint status, and timestamps.

**Reopen logic**

- Only solved complaints can be reopened.
- Reopen must be within 7 days.
- Reopen requires reason and photo proof.
- Reopened complaint status returns to review/workflow instead of forcing a new complaint.

**Speaker script**

This is the accountability layer. A complaint system is not trustworthy if it stops at "submitted." JanHelp gives users a status trail, department contact, and a reopen path when closure is not real.

**Real project evidence**

- `Complaint.REOPEN_WINDOW_DAYS = 7`.
- `Complaint.can_reopen` checks solved status and deadline.
- `reopen_complaint()` requires reason and image proof.
- `track_guest_complaint_api()` returns department contact and coordinates.

---

## Slide 13 - Department Dashboard And Field Workflow

Departments need a work queue, not a static inbox.

**Department workflow**

1. Department receives assigned complaints.
2. Officer reviews proof, location, category, and citizen details.
3. Work status moves through pending, confirmed, process, solved, or rejected.
4. Department uploads resolution proof.
5. Citizen receives updates.
6. Citizen rating and reopen decide whether the closure was acceptable.

**Operational value**

- Faster triage.
- Less manual forwarding.
- Clear ownership.
- SLA visibility.
- Resolution proof for accountability.

**Speaker script**

JanHelp makes every complaint a service task. The department sees what it owns, where it is, what proof exists, and what status must be updated. That is how the platform moves from complaint registration to actual service delivery.

**Real project evidence**

- Department templates include dashboard, assigned cases, solved/problem views, heatmap, and department detail views.
- `ComplaintResolutionProof` stores department proof after work completion.
- `estimated_completion_time`, `time_remaining`, and `is_overdue` support SLA visibility.

---

## Slide 14 - City Admin Dashboard And Civic Intelligence

City admins need the system view.

**Admin capabilities**

- Manage states, cities, city admins, departments, categories, and subcategories.
- See total complaints, pending work, solved work, reopened work, and problem cases.
- View complaint heatmaps.
- Inspect department workload and solve status.
- Review category trends and repeated hotspots.
- Use complaint data for planning and resource allocation.

**Impact**

- Citizens get a simpler reporting path.
- Departments get cleaner work orders.
- City admins get operational intelligence.
- Duplicate reports become signals instead of noise.
- Reopen and rating data reveal whether the city is solving the issue or only closing tickets.

**Speaker script**

JanHelp becomes valuable at two levels. At the citizen level, it improves reporting and tracking. At the city level, it creates a live map of service demand and department performance.

**Real project evidence**

- Templates include super admin, city admin, department dashboards, review pages, heatmaps, and analytics pages.
- Models support managed states, managed cities, city admins, categories, departments, and department users.

---

## Slide 15 - Missing And Advanced JanHelp 2.0 Scope

JanHelp already has the core complaint workflow: manual complaint, AI proof verification, duplicate check, nearest department assignment, tracking, department contact visibility, dashboards, rating, and reopen. The 2.0 roadmap should mention only what is still missing or advanced beyond the current system.

**Missing and advanced 2.0 features only**

- WhatsApp complaint bot with media upload, complaint draft confirmation, tracking, reopen request, and language selection.
- IVR phone bot for citizens without smartphones or internet access.
- Official emergency handoff integration with police, ambulance, fire, and disaster-response systems instead of guidance-only 112 messaging.
- Field officer mobile app with assigned job queue, geofenced site check-in, live field status, offline mode, and resolution proof upload.
- Supervisor escalation engine for SLA breaches, repeated reopen cases, and high-risk unresolved complaints.
- AI priority scoring using severity, public safety risk, location density, reopen history, and department delay history.
- Advanced duplicate clustering that groups related complaints across streets, wards, and time windows instead of only radius-based matching.
- Fraud and abuse detection for fake reports, repeated false submissions, recycled images, and suspicious complaint patterns.
- Image authenticity checks for duplicate/reused photos, AI-generated images, metadata mismatch, and timestamp/location inconsistency.
- Worker route optimization for field teams handling multiple nearby complaints in one trip.
- Public transparency portal with anonymized issue heatmaps, ward-level trends, SLA performance, and department scorecards.
- Citizen notification automation over WhatsApp/SMS/email with secure tracking and reopen links.
- Municipality partner API for integrating JanHelp with existing city CRMs, GIS systems, and emergency control rooms.
- Predictive civic maintenance dashboard that flags roads, drainage zones, garbage points, and streetlights likely to fail again.
- Accessibility layer with fully production-ready multilingual voice in Hindi, Gujarati, Marathi, English, and Hinglish.

**Speaker script**

The next version should not repeat features JanHelp already has. Version 2.0 should focus on missing channels, official integrations, field execution, advanced AI risk scoring, fraud prevention, and public accountability. That is how JanHelp moves from complaint management into full civic response orchestration.

**Closing line**

JanHelp is already a civic workflow engine. JanHelp 2.0 should make it a civic response network across WhatsApp, phone, field teams, supervisors, emergency systems, and public dashboards.

---

## 60-Second Short Pitch

JanHelp solves the real failure in civic complaint systems: messy citizen reports do not become clean department work orders. A citizen can submit a complaint manually, through AI chat, or through a voice-style flow. JanHelp captures location, category, description, contact, and proof. Gemini verifies whether the proof matches the selected issue. The backend checks for duplicates so repeated reports do not waste field time. Then the system assigns the nearest responsible department using department type, city, state, and distance.

After submission, users and guests can track status with a complaint ID, see assigned department contact details, and reopen a complaint within 7 days if it was marked solved but the issue still exists. Departments get a work queue, status workflow, SLA visibility, and resolution proof. City admins get dashboards and heatmaps for planning. JanHelp 2.0 should add only the missing advanced layer: WhatsApp, IVR, official emergency handoff, field officer app, supervisor escalation, fraud detection, predictive maintenance, and public transparency.

## Demo Flow To Show

1. Open JanHelp mobile app or web portal.
2. Submit a road/pothole or garbage complaint.
3. Add GPS and proof image.
4. Show AI proof verification.
5. Show duplicate warning if same nearby issue exists.
6. Show nearest department assignment with contact details.
7. Open user or guest tracking.
8. Show department dashboard status update.
9. Mark solved with proof.
10. Show rating and reopen flow if citizen is not satisfied.

## Claims To Avoid In A Live Pitch

- Do not claim official emergency dispatch integration unless it is connected to real government emergency systems. Current safe claim: emergency guidance and nearest department contact visibility.
- Do not claim voice is fully production-ready unless the running build, provider keys, microphone permissions, and backend endpoints are verified immediately before demo.
- Do not claim every city department is live. Current safe claim: the platform supports multi-city, multi-state departments and active department records.
