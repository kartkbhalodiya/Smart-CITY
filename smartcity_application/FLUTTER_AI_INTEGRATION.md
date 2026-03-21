# 📱 Flutter AI Assistant - Complete Backend Integration Guide

## ✅ All Backend Logic Integrated

The Flutter AI Assistant now includes **ALL** backend logic:
1. ✅ **Duplicate Complaint Detection**
2. ✅ **Automatic Department Assignment**  
3. ✅ **AI Image Verification**
4. ✅ **Personal Details Confirmation**
5. ✅ **Real-time Validation**

---

## 🔄 COMPLETE INTEGRATION FLOW

```
User Opens AI Chat
    ↓
AI Greets User
    ↓
User Describes Issue
    ↓
[AI DETECTS CATEGORY with Groq API]
    ↓
AI Asks for Subcategory
    ↓
User Provides Details
    ↓
[AI VALIDATES DESCRIPTION with Groq API]
    ↓
Valid? → Continue
Invalid? → Ask for Correct Details
    ↓
AI Asks When Noticed
    ↓
User Selects Date
    ↓
AI Asks for Location
    ↓
User Shares GPS Location
    ↓
[DUPLICATE CHECK via Backend API]
    ↓
Duplicate Found?
    ↓
YES → Show Masked Ticket → Ask: Track or New?
    ↓
NO → Continue
    ↓
[DEPARTMENT ASSIGNMENT via Backend API]
    ↓
Show Department Info (Name, Phone, SLA)
    ↓
AI Asks for Photo
    ↓
User Takes/Uploads Photo
    ↓
[AI IMAGE VERIFICATION via Backend API]
    ↓
Valid Image? → Continue
Invalid Image? → Ask for Correct Photo
    ↓
[PERSONAL DETAILS CONFIRMATION]
    ↓
Profile Exists? → Show for Confirmation
No Profile? → Ask for Details
    ↓
User Confirms/Provides Details
    ↓
AI Shows Complete Summary
    ↓
User Clicks Submit
    ↓
[SUBMIT TO BACKEND]
    ↓
Success! Show Ticket & Department Info
```

---

## 🔧 IMPLEMENTATION DETAILS

### **1. Duplicate Detection Integration**

**File:** `conversational_ai_service.dart`

```dart
/// Check for duplicate complaints using backend API
Future<Map<String, dynamic>?> _checkDuplicateComplaint(
  double latitude, 
  double longitude
) async {
  try {
    final response = await http.post(
      Uri.parse('http://your-backend-url/api/ai-check-duplicate/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
        'category': _complaintData['category'],
        'subcategory': _complaintData['subcategory'],
        'description': _complaintData['description'],
      }),
    ).timeout(Duration(seconds: 10));
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
  } catch (e) {
    print('Duplicate check error: $e');
  }
  return null;
}
```

**When Duplicate Found:**

```dart
if (duplicateInfo != null && duplicateInfo['duplicate_found'] == true) {
  return ConversationResponse(
    message: '''⚠️ **Duplicate Complaint Found**

${duplicateInfo['message']}

**Existing Ticket:** ${duplicateInfo['masked_ticket']}
**Status:** ${duplicateInfo['complaint_status']}

Would you like to:
• Track the existing complaint
• Submit a different complaint''',
    buttons: ['📋 Track Existing', '➕ New Complaint', '❌ Cancel'],
  );
}
```

---

### **2. Department Assignment Integration**

**File:** `conversational_ai_service.dart`

```dart
/// Get nearest department using backend API
Future<Map<String, dynamic>?> _getNearestDepartment(
  double latitude, 
  double longitude
) async {
  try {
    final response = await http.post(
      Uri.parse('http://your-backend-url/api/ai-get-department/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
        'category': _complaintData['category'],
        'city': _userCity,
        'state': _complaintData['state'] ?? '',
      }),
    ).timeout(Duration(seconds: 10));
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
  } catch (e) {
    print('Department lookup error: $e');
  }
  return null;
}
```

**When Department Found:**

```dart
if (departmentInfo != null && departmentInfo['success'] == true) {
  final dept = departmentInfo['department'];
  _complaintData['assigned_department'] = dept['name'];
  _complaintData['department_phone'] = dept['phone'];
  _complaintData['sla_hours'] = dept['sla_hours'];
  
  photoMessage = '''✅ **Location Confirmed**

📍 Your complaint will be assigned to:
🏛️ **${dept['name']}**
📞 Contact: ${dept['phone']}
⏱️ Expected resolution: ${dept['sla_hours']} hours''';
}
```

---

### **3. Location Coordinates Handling**

**File:** `ai_chat_screen.dart`

```dart
Future<void> _handleCurrentLocation() async {
  // Get GPS position
  Position position = await Geolocator.getCurrentPosition();
  
  // Show map for confirmation
  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => LocationPickerScreen(
        initialPosition: LatLng(position.latitude, position.longitude),
      ),
    ),
  );
  
  if (result != null) {
    _selectedLatLng = result['latlng'];
    _selectedLocation = result['address'];
    
    // Set coordinates in AI service
    _aiService.setLocationCoordinates(
      _selectedLatLng!.latitude,
      _selectedLatLng!.longitude,
      city: result['city'],
      state: result['state'],
    );
    
    // Send to AI (triggers duplicate check & department assignment)
    await _sendMessage(_selectedLocation!);
  }
}
```

---

### **4. Personal Details Confirmation**

**File:** `conversational_ai_service.dart`

```dart
ConversationResponse _showPersonalDetailsConfirmation() {
  if (_userProfile != null && 
      _userProfile!['fullName'] != null && 
      _userProfile!['mobile'] != null && 
      _userProfile!['email'] != null) {
    
    // Profile exists - show for confirmation
    return ConversationResponse(
      message: '''👤 **Personal Details Confirmation**

📛 **Name:** ${_userProfile!['fullName']}
📱 **Mobile:** ${_userProfile!['mobile']}
📧 **Email:** ${_userProfile!['email']}

These details will be used to contact you.''',
      buttons: ['✅ Confirm Details', '✏️ Edit Details'],
    );
  } else {
    // No profile - ask for details
    return ConversationResponse(
      message: '''👤 **Personal Details Required**

Please provide:
1️⃣ Your full name
2️⃣ Mobile number
3️⃣ Email address

Format: Name, Mobile, Email
Example: John Doe, 9876543210, john@email.com''',
      showInput: true,
    );
  }
}
```

---

## 📡 BACKEND API ENDPOINTS

### **1. Check Duplicate**

```http
POST /api/ai-check-duplicate/
Content-Type: application/json

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

### **2. Get Department**

```http
POST /api/ai-get-department/
Content-Type: application/json

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
    "phone": "+91-1234567890",
    "email": "pwd@delhi.gov.in",
    "sla_hours": 72,
    "latitude": 28.7050,
    "longitude": 77.1030
  }
}
```

### **3. AI Chat (Enhanced)**

```http
POST /api/ai-chat/
Content-Type: application/json

{
  "message": "There's a big pothole on Main Street",
  "session_id": "user123",
  "latitude": 28.7041,
  "longitude": 77.1025,
  "city": "New Delhi",
  "state": "Delhi"
}
```

**Response:**
```json
{
  "success": true,
  "response": "🛣️ Got it! This is about Road/Pothole...",
  "detected_category": "Road/Pothole",
  "duplicate_found": false,
  "assigned_department": {
    "name": "Public Works Department",
    "phone": "+91-1234567890",
    "sla_hours": 72
  }
}
```

---

## 🎯 KEY FEATURES

### **1. Smart Duplicate Prevention**
- ✅ Checks during location step
- ✅ Shows masked ticket for privacy
- ✅ Offers to track existing or file new
- ✅ Prevents redundant complaints

### **2. Automatic Department Routing**
- ✅ Finds nearest department by GPS
- ✅ Shows department contact info
- ✅ Displays expected resolution time
- ✅ Priority-based matching

### **3. AI Image Verification**
- ✅ Validates proof matches category
- ✅ Prevents wrong submissions
- ✅ Improves data quality
- ✅ Real-time feedback

### **4. Personal Details Management**
- ✅ Uses existing profile if available
- ✅ Allows editing if needed
- ✅ Validates format
- ✅ Ensures contact info accuracy

---

## 🔐 CONFIGURATION

### **Update Backend URL**

**File:** `conversational_ai_service.dart`

```dart
// Replace with your actual backend URL
static const String _backendUrl = 'http://your-backend-url';

Future<Map<String, dynamic>?> _checkDuplicateComplaint(...) async {
  final response = await http.post(
    Uri.parse('$_backendUrl/api/ai-check-duplicate/'),
    ...
  );
}

Future<Map<String, dynamic>?> _getNearestDepartment(...) async {
  final response = await http.post(
    Uri.parse('$_backendUrl/api/ai-get-department/'),
    ...
  );
}
```

### **Add HTTP Package**

**File:** `pubspec.yaml`

```yaml
dependencies:
  http: ^1.1.0
  geolocator: ^10.1.0
  flutter_map: ^6.0.0
  latlong2: ^0.9.0
```

---

## 🧪 TESTING CHECKLIST

### **Duplicate Detection**
- [ ] Test with same location (should find duplicate)
- [ ] Test with different location (should not find duplicate)
- [ ] Test "Track Existing" button
- [ ] Test "New Complaint" button
- [ ] Verify masked ticket display

### **Department Assignment**
- [ ] Test in same city (should find local dept)
- [ ] Test in different city (should find nearest)
- [ ] Verify department info display
- [ ] Check SLA hours display
- [ ] Test with no department available

### **Location Handling**
- [ ] Test GPS location
- [ ] Test map marker adjustment
- [ ] Verify coordinates passed to backend
- [ ] Test location permission denied
- [ ] Test offline scenario

### **Personal Details**
- [ ] Test with existing profile
- [ ] Test without profile
- [ ] Test "Confirm Details" button
- [ ] Test "Edit Details" button
- [ ] Verify format validation

### **Complete Flow**
- [ ] Test full flow: greeting → category → location → duplicate → department → photo → details → submit
- [ ] Test with duplicate found
- [ ] Test with no duplicate
- [ ] Test with invalid image
- [ ] Test with valid image

---

## 📊 USER EXPERIENCE

### **Before Integration:**
```
User: "Pothole on Main Street"
AI: "Got it! Describe the issue"
User: [Provides details]
AI: "Share location"
User: [Shares location]
AI: "Upload photo"
User: [Uploads photo]
AI: "Submit?"
User: "Yes"
AI: "Submitted!"
```

### **After Integration:**
```
User: "Pothole on Main Street"
AI: "Got it! Describe the issue"
User: [Provides details]
AI: "Share location"
User: [Shares location]
AI: "🔍 Checking for similar complaints..."
AI: "⚠️ Duplicate found! Ticket: SC1XXXXXX
     Already being handled. Track or file new?"
User: "New complaint"
AI: "📍 Assigned to: Public Works Dept
     📞 +91-1234567890
     ⏱️ Resolution: 72 hours
     Upload photo?"
User: [Uploads photo]
AI: "✅ Photo verified! Confirm details?"
User: "Confirm"
AI: "🎉 Submitted! Ticket: SC789012"
```

---

## 🚀 DEPLOYMENT

### **1. Update Backend URL**
```dart
static const String _backendUrl = 'https://your-production-url.com';
```

### **2. Test All Endpoints**
```bash
# Test duplicate check
curl -X POST https://your-backend-url/api/ai-check-duplicate/ \
  -H "Content-Type: application/json" \
  -d '{"latitude": 28.7041, "longitude": 77.1025, ...}'

# Test department lookup
curl -X POST https://your-backend-url/api/ai-get-department/ \
  -H "Content-Type: application/json" \
  -d '{"latitude": 28.7041, "longitude": 77.1025, ...}'
```

### **3. Build & Deploy**
```bash
flutter build apk --release
flutter build ios --release
```

---

## ✅ RESULT

The Flutter AI Assistant is now a **complete intelligent complaint system** with:
- ✅ Smart duplicate prevention
- ✅ Automatic department routing
- ✅ AI-powered validation
- ✅ Real-time feedback
- ✅ Natural conversation
- ✅ Privacy protection
- ✅ Seamless backend integration

**Zero manual intervention needed!** 🎉
