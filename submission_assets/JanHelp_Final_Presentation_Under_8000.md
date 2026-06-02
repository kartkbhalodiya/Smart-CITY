# JanHelp Final Presentation - Under 8000 Characters

PPT name: `JanHelp_Final_Real_World_Civic_Workflow_Deck.pptx`  
Format: compact 15-slide script for PPT/PPTX.  
Project: JanHelp Smart City Complaint Management System.  
Live API target: `https://janhelps.in/api`.

---

## Slide 1 - JanHelp

JanHelp is an AI-powered civic complaint platform that converts citizen problems into verified, trackable work orders for the nearest responsible city department.

Script: JanHelp is not only a complaint form. It handles intake, proof verification, duplicate control, department assignment, tracking, resolution, rating, and reopen.

---

## Slide 2 - Real-World Problem

Cities receive messy complaint data. Citizens often do not know the right department, proof is weak or fake, locations are unclear, repeated reports create duplicate work, and citizens lose trust when there is no tracking or reopen path.

Script: The real problem is not submission. The real problem is converting unstructured citizen input into a clean department-ready work order.

---

## Slide 3 - Why Manual Systems Fail

Manual flow: citizen finds where to complain, selects category, adds location, uploads proof, waits for staff review, and often gets no clear ownership or status.

Breakpoints: wrong category, missing proof, duplicate report, wrong department, no SLA visibility, false closure.

Script: Every manual handoff adds delay. JanHelp removes uncertainty at intake.

---

## Slide 4 - JanHelp Solution

JanHelp provides:

- Manual, AI chat, and voice/call-style complaint intake.
- GPS/address capture.
- Image proof verification.
- Duplicate check before repeated tickets.
- Nearest department assignment.
- User and guest tracking.
- Department workflow with status and proof.
- Rating and reopen if the issue is not solved.
- Admin dashboards and heatmaps.

Script: JanHelp covers the full lifecycle from report to accountability.

---

## Slide 5 - Complete Workflow

Citizen issue -> manual/chat/voice intake -> category, subcategory, description, contact, GPS -> proof upload -> image quality check -> Gemini verification -> duplicate check -> nearest department assignment -> department dashboard -> pending/confirmed/process/solved -> resolution proof -> rating -> reopen within 7 days if not solved.

Script: All intake methods end in one reliable complaint model and one tracking lifecycle.

---

## Slide 6 - Three Complaint Methods

Manual: best when user knows the issue.  
AI chat: best when user describes naturally and needs guided questions.  
Voice/call: best for elderly, low-literacy, or hands-free users.

Script: A city serves many kinds of citizens, so JanHelp supports multiple access paths instead of forcing one interface.

---

## Slide 7 - Manual Complaint Method

User selects category, chooses subcategory, writes title and description, shares GPS/address, uploads proof, selects contact preference, previews, and submits.

Value: fastest path, predictable form, structured data, still protected by proof check, duplicate check, and department routing.

Script: Manual mode is for speed. AI should assist, not block users who already know the issue.

---

## Slide 8 - AI Chat Method

User writes naturally, for example: "dirty water leaking near my street." JanHelp detects category, urgency, missing location, proof need, duplicate risk, and nearest department preview.

Script: Chat turns normal language into structured civic data. The citizen speaks simply, but the city receives a usable work order.

---

## Slide 9 - Voice / Call Method

Voice flow asks language, listens to the issue, extracts category, urgency, location, duplicate signals, and department preview, then creates a complaint draft for confirmation.

Emergency rule: if immediate danger is detected, JanHelp tells the user to call 112 first, then continues complaint capture for follow-up.

Script: Voice is the accessibility layer. It should feed the same backend workflow as manual and chat.

---

## Slide 10 - AI Verification And Duplicate Check

AI proof verification:

- Rejects tiny, dark, blank, or weak images before AI cost.
- Gemini checks if proof matches category, subcategory, and description.
- Uses model fallback for reliability.

Duplicate check:

- Public issues use 50 meter radius.
- Private local issues like water/electricity use 5 meter radius.
- Unique incidents like police/cyber/other skip radius duplicate check.
- Duplicate ticket ID is masked for privacy.

Script: Departments should not waste field time on fake proof or ten copies of the same issue.

---

## Slide 11 - Nearest Department And Emergency Help

Assignment logic:

1. Complaint type maps to department type.
2. System filters active departments.
3. Same city/state first.
4. Same state next.
5. Global nearest fallback.
6. Distance uses complaint GPS and department GPS.

Emergency/help visibility: users can see assigned department name, phone, email, address, map location, SLA, and 112 guidance for immediate danger.

Script: JanHelp sends work to the closest responsible department, not a generic inbox.

---

## Slide 12 - User Dashboard, Guest Tracking, Reopen

Logged-in users track complaint number, work status, assigned department, proof, map, rating, and reopen.

Guest users track by complaint ID and mobile number. Guest tracking shows complaint status, assigned department, phone, email, coordinates, and timestamps.

Reopen: only solved complaints, within 7 days, reason required, photo proof required.

Script: Trust starts after submission. JanHelp gives status, contact, and a way to challenge false closure.

---

## Slide 13 - Department Workflow

Department receives assigned cases, reviews proof and location, updates status from pending to confirmed to process to solved, uploads resolution proof, and receives reopen feedback if closure is not accepted.

Value: clear queue, less forwarding, ownership, SLA visibility, proof-based closure.

Script: JanHelp turns complaints into operational tasks for field teams.

---

## Slide 14 - City Admin Intelligence

Admins manage states, cities, departments, categories, and users. They see totals, pending cases, solved cases, reopened cases, heatmaps, department workload, issue trends, and civic hotspots.

Script: JanHelp is useful beyond one complaint. It becomes a live civic intelligence layer for city planning.

---

## Slide 15 - Missing And Advanced JanHelp 2.0

JanHelp already has core workflow, verification, duplicate check, nearest assignment, tracking, dashboards, rating, and reopen. 2.0 should list only missing advanced scope:

- WhatsApp complaint bot with media, tracking, and reopen.
- IVR phone bot for non-smartphone users.
- Official emergency handoff to police, ambulance, fire, and disaster systems.
- Field officer app with GPS check-in, offline mode, job queue, and resolution proof.
- Supervisor escalation for SLA breach and repeated reopen.
- AI priority scoring by severity, safety risk, density, reopen history, and delay.
- Advanced duplicate clustering across wards/time windows.
- Fraud and image authenticity detection.
- Worker route optimization.
- Public transparency portal with anonymized heatmaps and department scorecards.
- Municipality partner API for CRM, GIS, and control-room integration.
- Predictive civic maintenance dashboard.
- Production-ready multilingual voice.

Closing script: JanHelp is already a civic workflow engine. JanHelp 2.0 should become a civic response network across WhatsApp, phone, field teams, supervisors, emergency systems, and public dashboards.

