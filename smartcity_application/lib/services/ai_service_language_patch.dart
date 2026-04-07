// ============================================
// ADD THESE TO ai_service.dart
// ============================================

// 1. ADD THIS VARIABLE (after line: String _currentLanguage = 'en';)
String _appLanguage = 'en'; // Store app's selected language

// 2. ADD THIS METHOD (after reset() method)
/// Set the app's selected language for AI responses
void setAppLanguage(String languageCode) {
  if (['en', 'hi', 'gu'].contains(languageCode)) {
    _appLanguage = languageCode;
    _currentLanguage = languageCode;
    debugPrint('✅ App language set to: $languageCode');
  }
}

// 3. REPLACE THIS LINE in processUserInputAdvanced():
// OLD: _currentLanguage = _detectLanguage(input);
// NEW:
final detectedLanguage = _detectLanguage(input);
if (detectedLanguage == 'hinglish' || detectedLanguage == 'hi' || detectedLanguage == 'gu') {
  _currentLanguage = detectedLanguage;
  debugPrint('🗣️ User typed in: $detectedLanguage');
} else {
  _currentLanguage = _appLanguage;
  debugPrint('🌐 Using app language: $_appLanguage');
}
