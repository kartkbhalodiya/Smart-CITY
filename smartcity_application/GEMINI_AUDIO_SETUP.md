# AI Voice Assistant - Gemini 2.0 Flash Native Audio

## ✅ Configured Features

### 1. Gemini 2.0 Flash Model
- **Model**: `gemini-2.0-flash-exp`
- **API Key**: Configured (AIzaSyAim_9cK7zrtRe0UfNnf3b_wiwugHlOIjc)
- **Native Audio**: Supports direct audio input processing
- **Multilingual**: Hindi, English, Gujarati, Hinglish

### 2. AI Capabilities
- Real-time voice conversation
- Automatic category detection from speech
- Context-aware follow-up questions
- 1000+ keyword training across 4 languages
- Fuzzy matching for typos and variations

### 3. UI Features
- Real calling interface with animations
- Call duration timer
- Speaker/Mute/Bluetooth controls
- Live chat overlay during call
- Floating call button in bottom nav

## 🚀 Quick Start

### Step 1: Install Dependencies
```bash
cd smartcity_application
flutter pub get
```

### Step 2: Android Permissions
File: `android/app/src/main/AndroidManifest.xml`
```xml
<manifest>
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
    <uses-permission android:name="android.permission.BLUETOOTH"/>
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
</manifest>
```

### Step 3: iOS Permissions
File: `ios/Runner/Info.plist`
```xml
<dict>
    <key>NSMicrophoneUsageDescription</key>
    <string>We need microphone access for voice complaints</string>
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>We need speech recognition for AI assistant</string>
    <key>UIBackgroundModes</key>
    <array>
        <string>audio</string>
    </array>
</dict>
```

### Step 4: Run
```bash
flutter run
```

## 📱 How to Use

1. **Login** to the app
2. **Click** floating phone button (center of bottom nav)
3. **Speak** your complaint in any language:
   - "Road pe bada gadda hai"
   - "बिजली नहीं आ रही"
   - "રસ્તા પર પાણી ભરાયું છે"
4. **AI responds** and asks follow-up questions
5. **Switch to chat** anytime using chat button
6. **End call** when done

## 🎯 Supported Complaint Types

### 1. Road/Pothole
- Keywords: gadda, pothole, road broken, सड़क टूटी, ખાડો
- Questions: Size? Dangerous? Location?

### 2. Drainage/Sewage
- Keywords: nali jam, drain blocked, नाली बंद, નાળી બંધ
- Questions: Overflowing? How long?

### 3. Garbage/Sanitation
- Keywords: kachra, garbage, कचरा, કચરો
- Questions: How many days? Health issues?

### 4. Electricity
- Keywords: light nahi, power cut, बिजली नहीं, લાઇટ નથી
- Questions: How long? Whole area?

### 5. Water Supply
- Keywords: pani nahi, water leak, पानी नहीं, પાણી નથી
- Questions: Days without water? Leakage?

### 6. Traffic
- Keywords: wrong parking, signal broken, गलत पार्किंग
- Questions: Vehicle number? Location?

### 7. Cyber Crime
- Keywords: fraud, scam, धोखा, છેતરપિંડી
- Questions: When? Money lost? Transaction ID?

### 8. Construction
- Keywords: illegal construction, malba, अवैध निर्माण
- Questions: Permission? How long?

## 🧠 AI Intelligence

### Automatic Detection
```
User: "road pe bada gadda hai aur pani bhi bhara hai"
AI: Detects → Road/Pothole + Water Logging
AI: "Aap 2 problems report karna chahte hain. Pehle konsi?"
```

### Multilingual Support
```
User: "મારા વિસ્તારમાં લાઇટ નથી" (Gujarati)
AI: Responds in Gujarati
AI: "તમે વીજળી કટની ફરિયાદ કરી રહ્યા છો. સાચું?"
```

### Smart Confirmation
```
User: "bijli nahi aa rahi"
AI: "You are reporting Power Outage. Correct?"
User: "nahi, street light ki baat kar raha hun"
AI: "Oh, Street Light issue. Got it!"
```

## 🔧 Advanced Configuration

### Add More Keywords
Edit: `lib/config/ai_training_data.dart`
```dart
"New Category": {
  "Subcategory": {
    "keywords": {
      "en": ["keyword1", "keyword2"],
      "hi": ["कीवर्ड"],
      "hinglish": ["keyword"],
      "guj": ["કીવર્ડ"]
    },
    "questions": ["Question 1?", "Question 2?"]
  }
}
```

### Modify AI Behavior
Edit: `aiSystemPrompt` in `ai_training_data.dart`
```dart
const String aiSystemPrompt = '''
Your custom instructions here...
''';
```

### Change Voice Settings
Edit: `lib/services/speech_service.dart`
```dart
await _tts.setSpeechRate(0.5); // Speed: 0.1 to 1.0
await _tts.setPitch(1.0);      // Pitch: 0.5 to 2.0
await _tts.setVolume(1.0);     // Volume: 0.0 to 1.0
```

## 🎨 UI Customization

### Call Screen Colors
Edit: `lib/screens/ai_assistant/ai_call_screen.dart`
```dart
backgroundColor: Color(0xFF1a1a2e),  // Dark background
Color(0xFF1E66F5),                   // Primary blue
Colors.red,                          // End call button
```

### Bottom Nav Button
Edit: `lib/screens/dashboard/user_dashboard_screen.dart`
```dart
gradient: LinearGradient(
  colors: [Color(0xFF1E66F5), Color(0xFF154ec7)],
),
```

## 🐛 Troubleshooting

### Voice Not Working
- ✅ Check microphone permissions
- ✅ Test on real device (emulator has issues)
- ✅ Ensure internet connection
- ✅ Check Android/iOS permissions added

### AI Not Responding
- ✅ Verify API key is correct
- ✅ Check internet connection
- ✅ Look at console for errors
- ✅ Test with simple English first

### Categories Not Detected
- ✅ Speak clearly and slowly
- ✅ Use keywords from training data
- ✅ Add more keywords if needed
- ✅ Check language detection

### Audio Quality Issues
- ✅ Use in quiet environment
- ✅ Speak 6-12 inches from mic
- ✅ Avoid background noise
- ✅ Check device microphone

## 📊 Performance Tips

1. **First Call**: May take 2-3 seconds (model loading)
2. **Subsequent Calls**: < 1 second response
3. **Audio Processing**: 1-2 seconds for transcription
4. **Best Practice**: Speak in 5-10 second chunks

## 🔐 Security Notes

- API key is embedded (for development only)
- For production: Use environment variables
- Store API key in backend
- Implement rate limiting
- Add user authentication

## 📈 Next Steps

1. ✅ Connect AI to complaint submission API
2. ✅ Add voice waveform animation
3. ✅ Implement duplicate detection
4. ✅ Add complaint preview screen
5. ✅ Store conversation history
6. ✅ Add feedback mechanism
7. ✅ Implement analytics

## 🎓 Testing Scenarios

### Test 1: Simple Complaint
```
User: "road pe gadda hai"
Expected: AI detects Pothole, asks size/danger
```

### Test 2: Multilingual
```
User: "बिजली नहीं है"
Expected: AI responds in Hindi, detects Power Outage
```

### Test 3: Multiple Issues
```
User: "road broken and garbage also"
Expected: AI asks which to report first
```

### Test 4: Unclear Input
```
User: "problem hai"
Expected: AI asks "What kind of problem?"
```

## 📞 Support

Issues? Check:
1. Console logs for errors
2. API response in network tab
3. Permissions granted
4. Internet connection active

## 🎉 Success!

Your AI assistant is ready! Click the phone button and start talking!
