# Quick Reference Card

## 🚀 Quick Start

### Run App
```bash
flutter pub get
flutter run
```

### Test Features
1. Open AI Assistant
2. Type: "maru bag chorai gyu chhe"
3. Should detect: Police → Theft
4. Click "New Chat" → Old chat saved
5. Click "History" → See all chats

---

## 🔑 API Keys

### Groq AI
```
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
```
Location: `lib/services/conversational_ai_service.dart`

### Cloudinary
```
Cloud Name: dk1q50evg
Upload Preset: smartcity_complaints (create this!)
```

---

## 📱 UI Buttons

### AppBar (Top Right)
- **History Icon** → View all past chats
- **New Chat Icon** → Start fresh conversation

### Chat Actions
- **✅ Submit** → Submit complaint
- **📷 Take Photo** → Camera
- **🖼️ Gallery** → Choose image
- **📍 Use Current Location** → GPS

---

## 💬 Multilingual Examples

### Gujarati
```
"maru bag chorai gyu chhe" → Police/Theft
"road ma khado chhe" → Road/Pothole
"pani nathi avtu" → Water/No Supply
"light nathi" → Electricity/Power Cut
```

### Hindi
```
"sadak me gadda hai" → Road/Pothole
"paani nahi aa raha" → Water/No Supply
"bijli nahi hai" → Electricity/Power Cut
"chori ho gayi" → Police/Theft
```

### English
```
"big pothole on street" → Road/Pothole
"no water supply" → Water/No Supply
"power cut" → Electricity/Power Cut
"bag stolen" → Police/Theft
```

---

## 🎨 Bold Text Format

### In Code
```dart
message: '**Bold Text** normal text **More Bold**'
```

### Renders As
**Bold Text** normal text **More Bold**

---

## 📂 Key Files

### Services
- `lib/services/conversational_ai_service.dart` - Main AI
- `lib/services/chat_history_service.dart` - History
- `lib/services/groq_ai_service.dart` - Groq AI

### Screens
- `lib/screens/ai_assistant/ai_chat_screen.dart` - Main chat
- `lib/screens/ai_assistant/chat_history_screen.dart` - History

### Config
- `lib/config/api_config.dart` - API endpoints

---

## 🔧 Common Fixes

### Chat Not Saving
```dart
// Check console
print('Session ID: $_currentSessionId');
print('Messages: ${_messages.length}');
```

### Groq AI Not Working
```dart
// Check API key
static const String _groqApiKey = 'gsk_MI1L7vQJ...';
```

### Upload Failing
1. Create Cloudinary preset
2. Name: `smartcity_complaints`
3. Mode: Unsigned

### Bold Text Not Showing
Already fixed! Uses custom parser.

---

## 📊 Debug Commands

### Check Logs
```bash
flutter logs
```

### Clear Cache
```bash
flutter clean
flutter pub get
```

### Rebuild
```bash
flutter run --release
```

---

## ✅ Testing Checklist

Quick test (5 minutes):
- [ ] Open AI Assistant
- [ ] Send message
- [ ] Close & reopen app
- [ ] Chat restored?
- [ ] Click "New Chat"
- [ ] Click "History"
- [ ] Try Gujarati input
- [ ] Take photo
- [ ] Submit complaint

---

## 🎯 Success Indicators

✅ Chat history saves  
✅ New Chat works  
✅ History shows all chats  
✅ Multilingual detection works  
✅ Bold text renders  
✅ Image uploads  
✅ Real department shown  

---

## 📞 Quick Help

### Error: Package not found
```bash
flutter pub get
```

### Error: Build failed
```bash
flutter clean
flutter pub get
flutter run
```

### Error: Upload 401
Create Cloudinary preset!

---

**Keep this card handy! 📌**
