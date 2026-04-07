// ============================================
// ADD THESE TO ai_chat_screen.dart
// ============================================

// 1. ADD IMPORT at top
import '../../providers/locale_provider.dart';
import 'package:flutter/foundation.dart';

// 2. UPDATE initState() method - ADD THESE LINES:
@override
void initState() {
  super.initState();
  
  // Set AI language to match app language
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final localeProvider = context.read<LocaleProvider>();
    _aiService.setAppLanguage(localeProvider.locale.languageCode);
    debugPrint('🌐 AI language initialized to: ${localeProvider.locale.languageCode}');
  });
  
  _initializeChat();
}

// 3. ADD THIS METHOD (after initState):
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  
  // Update AI language when app language changes
  final localeProvider = Provider.of<LocaleProvider>(context);
  _aiService.setAppLanguage(localeProvider.locale.languageCode);
}
