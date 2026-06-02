import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../providers/live_call_provider.dart';
import '../providers/auth_provider.dart';
import '../config/routes.dart';
import 'ai_assistant/voice_call_screen.dart';

class LanguageCallScreen extends StatefulWidget {
  const LanguageCallScreen({super.key});

  @override
  State<LanguageCallScreen> createState() => _LanguageCallScreenState();
}

class _LanguageCallScreenState extends State<LanguageCallScreen> {
  final Map<String, Map<String, String>> _languages = {
    'en': {'name': 'English', 'code': 'en', 'flag': '🇬🇧'},
    'hi': {'name': 'Hindi', 'code': 'hi', 'flag': '🇮🇳'},
    'gu': {'name': 'Gujarati', 'code': 'gu', 'flag': '🇮🇳'},
    'hinglish': {'name': 'Hinglish', 'code': 'en', 'flag': '🇮🇳'},
  };

  void _startCall(String langKey) async {
    // Set app locale for UI
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final langCode = _languages[langKey]!['code']!;
    localeProvider.setLocale(langCode);

    // Configure and start live call in provider with selected language
    final callProvider = Provider.of<LiveCallProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    // Map short key to full locale id expected by speech engine
    String localeId;
    String languageName;
    switch (langKey) {
      case 'hi':
        localeId = 'hi_IN';
        languageName = 'hindi';
        break;
      case 'gu':
        localeId = 'gu_IN';
        languageName = 'gujarati';
        break;
      case 'hinglish':
        localeId = 'hi_IN';
        languageName = 'hinglish';
        break;
      default:
        localeId = 'en_IN';
        languageName = 'english';
    }

    await callProvider.setSpeechLocaleId(localeId,
        languageLabel: _languages[langKey]!['name']!);

    // Set language in draft and skip greeting stage
    await callProvider.setLanguageAndSkipGreeting(languageName);

    await callProvider.startCall(userName: user?.fullName ?? 'User');

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => VoiceCallScreen(
          preSelectedLanguage: _languages[langKey]!['name']!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8F9FA), Color(0xFFFFFFFF)],
          ),
        ),
        child: SafeArea(
          child: _buildLanguageSelection(),
        ),
      ),
    );
  }

  Widget _buildLanguageSelection() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(
            Icons.phone_in_talk_rounded,
            size: 80,
            color: const Color(0xFFFF6B35),
          ),
          const SizedBox(height: 24),
          Text(
            'Select Your Language',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a language to start AI call',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 48),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
              ),
              itemCount: _languages.length,
              itemBuilder: (context, index) {
                final key = _languages.keys.elementAt(index);
                final lang = _languages[key]!;
                return _buildLanguageCard(key, lang);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageCard(String key, Map<String, String> lang) {
    return GestureDetector(
      onTap: () => _startCall(key),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              lang['flag']!,
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 12),
            Text(
              lang['name']!,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
