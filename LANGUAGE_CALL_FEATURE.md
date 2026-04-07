# Language Call Screen Feature

## Overview
The Language Call Screen provides an intuitive interface for users to select their preferred language before starting an AI-powered voice call with the JanHelp assistant.

## Features

### 1. Language Selection
- **4 Languages Supported:**
  - English 🇬🇧
  - Hindi (हिंदी) 🇮🇳
  - Gujarati (ગુજરાતી) 🇮🇳
  - Hinglish 🇮🇳

### 2. Call Simulation
- **Ringing Animation:** When a language is selected, the screen shows a pulsating phone icon
- **Ring Sound:** Plays a ringing sound effect for 3 seconds
- **Auto-Connect:** After 3 seconds, automatically connects to the AI voice assistant

### 3. User Flow
```
Splash Screen → Language Selection → Ring (3s) → AI Voice Call
```

## Implementation Details

### Files Created/Modified

1. **`screens/language_call_screen.dart`** (NEW)
   - Main language selection and call simulation screen
   - Handles language selection UI
   - Manages ringing animation and sound
   - Navigates to VoiceCallScreen after 3 seconds

2. **`config/routes.dart`** (MODIFIED)
   - Added `/language-call` route
   - Imported LanguageCallScreen

3. **`screens/splash_screen.dart`** (MODIFIED)
   - Updated navigation to go to language call screen instead of login

### Key Components

#### Language Selection Grid
- 2x2 grid layout
- Each card shows:
  - Flag emoji
  - Language name in native script
  - Tap to select and start call

#### Ringing Screen
- Animated phone icon (scales up/down)
- "Calling AI Assistant" text
- Selected language display
- Loading dots animation

### Audio Integration
- Uses `audioplayers` package (already in pubspec.yaml)
- Plays looping ring sound for 3 seconds
- Automatically stops when call connects
- Graceful fallback if sound files are missing

## Usage

### For Users
1. Open the app
2. Select your preferred language from the 4 options
3. Wait 3 seconds while the call rings
4. Start speaking with the AI assistant in your selected language

### For Developers

To add more languages:
```dart
final Map<String, Map<String, String>> _languages = {
  'en': {'name': 'English', 'code': 'en', 'flag': '🇬🇧'},
  'hi': {'name': 'हिंदी', 'code': 'hi', 'flag': '🇮🇳'},
  'gu': {'name': 'ગુજરાતી', 'code': 'gu', 'flag': '🇮🇳'},
  'hinglish': {'name': 'Hinglish', 'code': 'en', 'flag': '🇮🇳'},
  // Add new language here
};
```

## Optional: Adding Custom Ring Sound

1. Create `assets/sounds/` directory
2. Add `ring.mp3` file
3. Update `pubspec.yaml`:
```yaml
flutter:
  assets:
    - assets/sounds/ring.mp3
```

## Technical Notes

- **Animation Duration:** 800ms for ring scale animation
- **Call Duration:** 3 seconds before auto-connect
- **Locale Setting:** Updates app locale via LocaleProvider
- **Navigation:** Uses pushReplacement to prevent back navigation

## Future Enhancements

- [ ] Add more languages (Marathi, Tamil, Telugu, etc.)
- [ ] Custom ring tones per language
- [ ] Skip button to connect immediately
- [ ] Voice preview for each language
- [ ] Remember last selected language
