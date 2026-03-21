# 🤖 AI Assistant - Complete Backend Integration

## ✅ All Backend Logic Integrated into AI Assistant

The AI Assistant now includes **ALL** the backend logic for complaint booking, including:
1. ✅ **Duplicate Complaint Detection**
2. ✅ **Automatic Department Assignment**
3. ✅ **AI Image Verification** (already implemented)

---

## 🔍 1. DUPLICATE COMPLAINT DETECTION

### **How It Works:**

The AI Assistant now checks for duplicate complaints **during the conversation** using the same logic as the backend.

### **Detection Logic:**

```python
def check_duplicate_complaint(self, latitude, longitude):
    """
    Smart duplicate detection with category-specific radii:
    - Public Issues (Road, Garbage, etc.): 50m radius
    - Private Issues (Water, Electricity): 5m radius
    - Unique Issues (Police, Cyber, Other): No check
    """
```

### **Radius Mapping:**
- **Road/Pothole**: 50 meters (0.05 km)
- **Garbage**: 50 meters
- **Drainage**: 50 meters
- **Traffic**: 50 meters
- **Construction**: 50 meters
- **Illegal Activities**: 50 meters
- **Transportation**: 50 meters
- **Water Supply**: 5 meters (private connection)
- **Electricity**: 5 meters (private connection)
- **Police/Cyber/Other**: No duplicate check (unique issues)

### **When Duplicate is Found:**

```
⚠️ This issue has already been reported by another citizen in this area. 
Ticket: SC1XXXXXX

This complaint is already being handled by our team. 
You can track it using the ticket number provided.

Would you like to submit a new complaint for a different issue?
```

### **Privacy Protection:**
- Original ticket: `SC123456`
- Masked ticket: `SC1XXXXXX` (first 3 chars + XXXXXX)

---

## 🏢 2. AUTOMATIC DEPARTMENT ASSIGNMENT

### **How It Works:**

The AI Assistant automatically finds and assigns the **nearest department** based on:
1. Complaint category
2. GPS location (latitude/longitude)
3. City and State

### **Assignment Priority:**

```
Priority 1: City + State Match
  ↓
Priority 2: State Match Only
  ↓
Priority 3: Global Nearest (any city/state)
```

### **Distance Calculation:**
Uses **Haversine formula** for accurate Earth surface distance:
```python
def _distance_km(lat1, lon1, lat2, lon2):
    # Great-circle distance in kilometers
    r = 6371.0  # Earth radius
    # Calculate using Haversine formula
```

### **When Department is Found:**

```
📍 Your complaint will be assigned to: Public Works Department
📞 Contact: +91-1234567890
⏱️ Expected resolution: 72 hours
```

### **Department Info Provided:**
- Department Name
- Contact Phone
- Email Address
- Physical Address
- SLA Hours (Service Level Agreement)
- GPS Coordinates

---

## 🎯 3. AI IMAGE VERIFICATION

### **Already Implemented:**

The AI verifies uploaded images match the complaint category:

```python
from .ai_utils import verify_complaint_proof

is_valid, ai_msg = verify_complaint_proof(
    image, 
    category_label, 
    category_key=ctype
)

if not is_valid:
    return "Invalid Proof: upload right proof for {category}"
```

### **Categories Requiring Proof:**
- ✅ Road/Pothole
- ✅ Water Supply
- ✅ Electricity
- ✅ Garbage
- ✅ Drainage
- ✅ Construction
- ✅ Traffic
- ✅ Illegal Activities
- ✅ Transportation

### **Categories Skipping Verification:**
- ⏭️ Police (sensitive)
- ⏭️ Cyber Crime (digital evidence)
- ⏭️ Other (general)

---

## 📡 API ENDPOINTS

### **1. AI Chat with Integrated Logic**

```http
POST /api/ai-chat/
```

**Request:**
```json
{
  "message": "There's a big pothole on Main Street",
  "session_id": "user123",
  "user_name": "John Doe",
  "user_email": "john@example.com",
  "preferred_language": "english",
  "latitude": 28.7041,
  "longitude": 77.1025,
  "city": "New Delhi",
  "state": "Delhi"
}
```

**Response (with duplicate found):**
```json
{
  "success": true,
  "response": "⚠️ This issue has already been reported by another citizen in this area. Ticket: SC1XXXXXX\n\nThis complaint is already being handled by our team...",
  "detected_category": "Road/Pothole",
  "urgency": "high",
  "duplicate_found": true,
  "duplicate_ticket": "SC1XXXXXX",
  "assigned_department": {
    "id": 5,
    "name": "Public Works Department",
    "phone": "+91-1234567890",
    "sla_hours": 72
  }
}
```

### **2. Check Duplicate (Standalone)**

```http
POST /api/ai-check-duplicate/
```

**Request:**
```json
{
  "latitude": 28.7041,
  "longitude": 77.1025,
  "category": "Road/Pothole",
  "subcategory": "Pothole",
  "description": "Large pothole causing accidents"
}
```

**Response:**
```json
{
  "success": true,
  "duplicate_found": true,
  "masked_ticket": "SC1XXXXXX",
  "original_ticket": "SC123456",
  "message": "This issue has already been reported...",
  "complaint_status": "Process",
  "created_at": "2024-01-15 10:30"
}
```

### **3. Get Nearest Department (Standalone)**

```http
POST /api/ai-get-department/
```

**Request:**
```json
{
  "latitude": 28.7041,
  "longitude": 77.1025,
  "category": "Road/Pothole",
  "city": "New Delhi",
  "state": "Delhi"
}
```

**Response:**
```json
{
  "success": true,
  "department": {
    "id": 5,
    "name": "Public Works Department",
    "type": "Road/Pothole Department",
    "email": "pwd@delhi.gov.in",
    "phone": "+91-1234567890",
    "address": "Sector 5, New Delhi, Delhi",
    "sla_hours": 72,
    "latitude": 28.7050,
    "longitude": 77.1030
  },
  "message": "Your complaint will be assigned to Public Works Department"
}
```

---

## 🔄 COMPLETE AI CONVERSATION FLOW

```
1. User: "There's a big pothole on Main Street"
   AI: 🛣️ Got it! This is about Road/Pothole
       📍 Please share your exact location

2. User: [Shares GPS location]
   AI: ✅ Location received
       🔍 Checking for similar complaints in your area...
       
   [DUPLICATE CHECK RUNS]
   
   Case A: Duplicate Found
   AI: ⚠️ This issue already reported (Ticket: SC1XXXXXX)
       Would you like to submit a different complaint?
   
   Case B: No Duplicate
   AI: ✅ No duplicate found
       📍 Your complaint will be assigned to: Public Works Dept
       📞 Contact: +91-1234567890
       ⏱️ Expected resolution: 72 hours
       
       Please describe the issue in detail

3. User: "Large pothole, 2 feet deep, causing accidents"
   AI: ✅ Description recorded
       📷 Please upload a photo of the pothole

4. User: [Uploads photo]
   AI: [AI IMAGE VERIFICATION RUNS]
   
   Case A: Valid Image
   AI: ✅ Photo verified
       📋 Ready to submit complaint
       
   Case B: Invalid Image
   AI: ❌ Invalid Proof: Please upload a photo of the road issue
       
5. User: "Submit"
   AI: ✅ Complaint submitted successfully!
       🎫 Ticket: SC123456
       📍 Assigned to: Public Works Department
       ⏱️ Expected resolution: 72 hours
```

---

## 🎯 KEY BENEFITS

### **1. Prevents Duplicate Complaints**
- ✅ Reduces redundant work for departments
- ✅ Saves citizen time
- ✅ Shows existing ticket for tracking
- ✅ Privacy-protected (masked IDs)

### **2. Smart Department Assignment**
- ✅ Automatic nearest department selection
- ✅ Priority-based matching (City → State → Global)
- ✅ Accurate distance calculation
- ✅ Shows department contact info upfront

### **3. AI Image Verification**
- ✅ Ensures proof matches category
- ✅ Prevents wrong submissions
- ✅ Improves data quality
- ✅ Helps departments respond correctly

### **4. Seamless Integration**
- ✅ All checks happen during conversation
- ✅ No extra steps for users
- ✅ Real-time feedback
- ✅ Natural conversation flow

---

## 📊 DATA FLOW

```
User Message
    ↓
AI Detects Category & Subcategory
    ↓
User Shares Location
    ↓
[DUPLICATE CHECK]
    ↓
Duplicate Found? → Show Ticket → Ask for New Complaint
    ↓
No Duplicate
    ↓
[DEPARTMENT ASSIGNMENT]
    ↓
Show Department Info
    ↓
User Provides Description
    ↓
User Uploads Photo
    ↓
[AI IMAGE VERIFICATION]
    ↓
Valid Image? → Continue
    ↓
Invalid Image? → Ask for Correct Photo
    ↓
Generate Summary
    ↓
User Confirms
    ↓
Submit to Backend
    ↓
Success! Show Ticket
```

---

## 🔧 TECHNICAL IMPLEMENTATION

### **Backend Models Used:**
- `Complaint.check_duplicate()` - Duplicate detection
- `Complaint.get_nearest_department()` - Department assignment
- `verify_complaint_proof()` - Image verification

### **AI Assistant Methods:**
- `check_duplicate_complaint()` - Wrapper for duplicate check
- `get_nearest_department()` - Wrapper for department lookup
- `extract_complaint_info()` - Enhanced with location data

### **Session Data Stored:**
```python
complaint_data = {
    "category": "Road/Pothole",
    "subcategory": "Pothole",
    "location_hint": "Main Street",
    "latitude": 28.7041,
    "longitude": 77.1025,
    "city": "New Delhi",
    "state": "Delhi",
    "duplicate_check_done": True,
    "department_assigned": {...},
    "image_verified": True,
}
```

---

## 🚀 USAGE IN FLUTTER APP

### **1. Send Location with Message:**

```dart
final response = await http.post(
  Uri.parse('$baseUrl/api/ai-chat/'),
  body: jsonEncode({
    'message': userMessage,
    'session_id': sessionId,
    'latitude': currentPosition.latitude,
    'longitude': currentPosition.longitude,
    'city': currentCity,
    'state': currentState,
  }),
);
```

### **2. Handle Duplicate Response:**

```dart
if (response['duplicate_found'] == true) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('⚠️ Duplicate Found'),
      content: Text(
        'This issue is already reported.\n'
        'Ticket: ${response['duplicate_ticket']}\n\n'
        'Would you like to submit a different complaint?'
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Track Existing'),
        ),
        TextButton(
          onPressed: () {
            // Reset session and start new complaint
            Navigator.pop(context);
          },
          child: Text('New Complaint'),
        ),
      ],
    ),
  );
}
```

### **3. Show Department Info:**

```dart
if (response['assigned_department'] != null) {
  final dept = response['assigned_department'];
  showSnackBar(
    '📍 Assigned to: ${dept['name']}\n'
    '📞 ${dept['phone']}\n'
    '⏱️ Resolution: ${dept['sla_hours']} hours'
  );
}
```

---

## ✅ TESTING CHECKLIST

- [ ] Test duplicate detection with same location
- [ ] Test duplicate detection with different locations
- [ ] Test department assignment in same city
- [ ] Test department assignment in different city
- [ ] Test department assignment in different state
- [ ] Test AI image verification with valid image
- [ ] Test AI image verification with invalid image
- [ ] Test complete flow: duplicate → department → image
- [ ] Test privacy (masked ticket IDs)
- [ ] Test error handling (no department found)

---

## 🎉 RESULT

The AI Assistant is now a **complete complaint booking system** with:
- ✅ Smart duplicate prevention
- ✅ Automatic department routing
- ✅ AI-powered image verification
- ✅ Real-time feedback
- ✅ Natural conversation flow
- ✅ Privacy protection
- ✅ Seamless backend integration

**No manual intervention needed!** 🚀
