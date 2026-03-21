# 🎯 Quick Reference Guide - Enhanced Conversational AI Service

## 🚀 Quick Start

```dart
import 'package:smartcity_application/services/conversational_ai_service.dart';

final aiService = ConversationalAIService();

// Start conversation
final response = await aiService.processInput(
  'There is a pothole on Main Street',
  userName: 'John',
  userCity: 'Mumbai',
);
```

---

## 📋 Key Methods

### **processInput()**
Main method to process user input and get AI response.

```dart
Future<ConversationResponse> processInput(
  String userInput, {
  String? userName,
  String? userCity,
  String? language,
  Map<String, dynamic>? metadata,
})
```

**Parameters:**
- `userInput` - User's message/input
- `userName` - User's name (optional)
- `userCity` - User's city (optional)
- `language` - Language code: en, hi, ta, te, bn, mr, gu (optional)
- `metadata` - Additional metadata (optional)

**Returns:** `ConversationResponse` object

---

### **getComplaintData()**
Get current complaint data.

```dart
Map<String, dynamic> getComplaintData()
```

**Returns:**
```dart
{
  'complaint_id': 'CMP123456',
  'category': 'Road/Pothole',
  'subcategory': 'Pothole',
  'description': '...',
  'location': '...',
  'date_noticed': '...',
  'priority': 'High',
  'department': 'PWD',
  // ... more fields
}
```

---

### **getAIInsights()**
Get AI analysis and insights.

```dart
Map<String, dynamic> getAIInsights()
```

**Returns:**
```dart
{
  'sentiment': 'urgent',
  'urgency_score': 0.85,
  'urgency_level': 'High',
  'priority': 'Critical',
  'estimated_resolution': '5-7 days',
  'ai_context': {...}
}
```

---

### **getConversationStats()**
Get conversation statistics.

```dart
Map<String, dynamic> getConversationStats()
```

**Returns:**
```dart
{
  'duration_seconds': 120,
  'messages_count': 8,
  'current_step': 'problem',
  'sentiment': 'neutral',
  'urgency_score': 0.5,
  'retry_count': 0
}
```

---

### **reset()**
Reset conversation to start fresh.

```dart
void reset()
```

---

### **setSmartMode()**
Enable/disable AI smart features.

```dart
void setSmartMode(bool enabled)
```

---

## 📊 ConversationResponse Object

```dart
class ConversationResponse {
  String message;                    // AI response message
  List<String> buttons;              // Action buttons
  List<String> suggestions;          // Quick suggestions
  String step;                       // Current conversation step
  bool showInput;                    // Show input field?
  String? inputPlaceholder;          // Input placeholder text
  Map<String, dynamic>? complaintData; // Complaint data (if submitted)
  String? urgencyLevel;              // Urgency level
  String? estimatedResolutionTime;   // Estimated resolution time
  Map<String, dynamic>? aiInsights;  // AI insights
}
```

---

## 🎭 Conversation Steps

| Step | Description |
|------|-------------|
| `greeting` | Initial greeting |
| `category` | Category selection |
| `subcategory` | Subcategory selection |
| `problem` | Problem description |
| `date` | Date selection |
| `location` | Location input |
| `photo` | Photo upload |
| `summary` | Final summary |
| `confirm` | Confirmation |
| `submitted` | Success screen |

---

## 🏷️ Categories

| Key | Name | Emoji |
|-----|------|-------|
| `road` | Road/Pothole | 🛣️ |
| `water` | Water Supply | 💧 |
| `electricity` | Electricity | ⚡ |
| `garbage` | Garbage/Sanitation | 🗑️ |
| `drainage` | Drainage/Sewage | 🚰 |
| `traffic` | Traffic | 🚦 |
| `police` | Police | 👮 |
| `construction` | Construction | 🏗️ |
| `cyber` | Cyber Crime | 💻 |
| `street_light` | Street Light | 💡 |
| `public_toilet` | Public Toilet | 🚻 |
| `other` | Other | 📝 |

---

## 📈 Priority Levels

| Priority | Urgency Score | Description |
|----------|---------------|-------------|
| Critical | ≥ 0.8 | Immediate attention required |
| High | 0.6 - 0.79 | Urgent issue |
| Medium | 0.4 - 0.59 | Normal priority |
| Normal | < 0.4 | Standard processing |

---

## ⏱️ Estimated Resolution Times

| Category | Time |
|----------|------|
| Police/Cyber | 24-48 hours |
| Electricity/Water | 2-3 days |
| Garbage | 1-2 days |
| Road/Drainage | 5-7 days |
| Others | 3-5 days |

---

## 🏛️ Department Mapping

| Category | Department |
|----------|------------|
| Road | Public Works Department (PWD) |
| Water | Water Supply Department |
| Electricity | Electricity Board |
| Garbage | Sanitation Department |
| Drainage | Drainage & Sewage Department |
| Traffic | Traffic Police Department |
| Police | Police Department |
| Construction | Municipal Corporation |
| Cyber | Cyber Crime Cell |
| Street Light | Electricity Department |
| Public Toilet | Sanitation Department |

---

## 🎨 Sentiment Types

- `positive` - Positive sentiment
- `neutral` - Neutral sentiment
- `negative` - Negative sentiment
- `urgent` - Urgent/critical sentiment

---

## 🌍 Supported Languages

- `en` - English
- `hi` - Hindi
- `ta` - Tamil
- `te` - Telugu
- `bn` - Bengali
- `mr` - Marathi
- `gu` - Gujarati

---

## 💡 Best Practices

### ✅ DO:
- Provide user name and city for personalization
- Use natural language input
- Check AI insights for better understanding
- Reset conversation when starting new complaint
- Handle response buttons and suggestions in UI

### ❌ DON'T:
- Don't call processInput without handling response
- Don't ignore urgency levels
- Don't skip validation of complaint data
- Don't forget to reset after submission

---

## 🔥 Common Patterns

### Pattern 1: Quick Complaint
```dart
// User describes everything at once
final response = await aiService.processInput(
  'Pothole on Main St near hospital, been there 2 weeks, very dangerous',
  userName: 'User',
  userCity: 'City',
);
// AI extracts: category, location, duration, urgency
```

### Pattern 2: Step-by-Step
```dart
// User goes through each step
await aiService.processInput('Hello');
await aiService.processInput('Water problem');
await aiService.processInput('No water supply');
// ... continue steps
```

### Pattern 3: Error Recovery
```dart
var response = await aiService.processInput('xyz');
// AI provides helpful guidance
if (response.buttons.isNotEmpty) {
  // Show buttons to user
}
```

---

## 🐛 Debugging

### Check Current State
```dart
print('Step: ${aiService.getConversationStats()['current_step']}');
print('Messages: ${aiService.getConversationStats()['messages_count']}');
```

### Check AI Analysis
```dart
final insights = aiService.getAIInsights();
print('Sentiment: ${insights['sentiment']}');
print('Urgency: ${insights['urgency_score']}');
```

### Check Complaint Data
```dart
final data = aiService.getComplaintData();
print('Category: ${data['category']}');
print('Location: ${data['location']}');
```

---

## ⚡ Performance Tips

1. **Reuse Instance**: Use singleton pattern
2. **Reset After Submit**: Clear data for new complaint
3. **Handle Timeouts**: API calls timeout after 10s
4. **Cache Responses**: Store responses for offline mode
5. **Batch Operations**: Process multiple inputs efficiently

---

## 🔒 Security Notes

- API key is embedded (move to secure storage in production)
- Sanitize user input before processing
- Validate complaint data before submission
- Implement rate limiting for API calls
- Use HTTPS for all communications

---

## 📞 Error Codes

| Code | Description | Solution |
|------|-------------|----------|
| API_TIMEOUT | API call timeout | Retry with fallback |
| INVALID_INPUT | Invalid user input | Show helpful message |
| CATEGORY_NOT_FOUND | Category detection failed | Show all categories |
| NETWORK_ERROR | Network issue | Check connectivity |

---

## 🎯 Testing Checklist

- [ ] Test all 12 categories
- [ ] Test urgent keywords
- [ ] Test location extraction
- [ ] Test date parsing
- [ ] Test multi-language (if enabled)
- [ ] Test error scenarios
- [ ] Test reset functionality
- [ ] Test conversation flow
- [ ] Test AI insights accuracy
- [ ] Test priority calculation

---

## 📚 Additional Resources

- Full Documentation: `AI_SERVICE_FEATURES.md`
- Usage Examples: `ai_service_examples.dart`
- Source Code: `conversational_ai_service.dart`

---

**Version**: 2.0 Enhanced  
**Last Updated**: 2024  
**Status**: Production Ready ✅
