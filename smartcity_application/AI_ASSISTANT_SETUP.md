# AI Voice Assistant Setup Guide

## Features Implemented

1. **AI Call Screen** - Real calling interface with:
   - Animated logo during call
   - Call duration timer
   - Speaker, Mute, Bluetooth controls
   - Chat overlay
   - End call button

2. **Bottom Navigation** - Floating call button in center

3. **AI Service** - Gemini API integration with:
   - Multilingual support (Hindi, English, Gujarati, Hinglish)
   - Automatic category detection
   - Conversational flow
   - 10000+ keyword training data

4. **Speech Service** - Voice recognition and text-to-speech

## Setup Steps

### 1. Install Dependencies
```bash
cd smartcity_application
flutter pub get
```

### 2. Add Gemini API Key
Edit `lib/services/ai_service.dart`:
```dart
static const String _apiKey = 'YOUR_GEMINI_API_KEY_HERE';
```

Get API key from: https://makersuite.google.com/app/apikey

### 3. Android Permissions
Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.BLUETOOTH"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
```

### 4. iOS Permissions
Add to `ios/Runner/Info.plist`:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Need microphone access for voice complaints</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>Need speech recognition for AI assistant</string>
```

### 5. Run App
```bash
flutter run
```

## How It Works

1. User clicks floating phone button in bottom nav
2. AI call screen opens with animated interface
3. User speaks complaint in any language
4. AI detects category from keywords
5. AI asks relevant follow-up questions
6. User can switch to chat mode anytime
7. Complaint data collected and ready to submit

## AI Training Data

Located in `lib/config/ai_training_data.dart`:
- 8 major categories
- 30+ subcategories
- 1000+ keywords across 4 languages
- Expandable to 10000+ lines

## Customization

### Add More Categories
Edit `ai_training_data.dart`:
```dart
"New Category": {
  "Subcategory": {
    "keywords": {
      "en": ["keyword1", "keyword2"],
      "hi": ["कीवर्ड"],
      "hinglish": ["keyword"],
      "guj": ["કીવર્ડ"]
    }
  }
}
```

### Modify AI Behavior
Edit `aiSystemPrompt` in `ai_training_data.dart`

### Change UI Colors
Edit `ai_call_screen.dart` color values

## Testing

1. Test voice recognition: Speak clearly
2. Test multilingual: Try Hindi/English/Hinglish
3. Test chat: Click chat button during call
4. Test controls: Speaker, mute, bluetooth
5. Test end call: Red button

## Troubleshooting

**Voice not working?**
- Check microphone permissions
- Test on real device (not emulator)

**AI not responding?**
- Verify Gemini API key
- Check internet connection

**Categories not detected?**
- Add more keywords in training data
- Use fuzzy matching

## Next Steps

1. Connect AI to actual complaint submission
2. Add voice feedback animations
3. Implement duplicate detection
4. Add complaint preview before submit
5. Store conversation history
