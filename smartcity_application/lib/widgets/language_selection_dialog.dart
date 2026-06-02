import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Language Selection Dialog
class LanguageSelectionDialog extends StatefulWidget {
  const LanguageSelectionDialog({super.key});

  @override
  State<LanguageSelectionDialog> createState() => _LanguageSelectionDialogState();
}

class _LanguageSelectionDialogState extends State<LanguageSelectionDialog> {
  String? _selectedLanguage;
  
  final List<Map<String, String>> _languages = [
    {'name': 'English', 'icon': '🇬🇧', 'subtitle': 'English'},
    {'name': 'Hindi', 'icon': '🇮🇳', 'subtitle': 'हिंदी'},
    {'name': 'Gujarati', 'icon': '🇮🇳', 'subtitle': 'ગુજરાતી'},
    {'name': 'Hinglish', 'icon': '🇮🇳', 'subtitle': 'Hindi + English'},
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF2F80ED).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.language_rounded,
                size: 32,
                color: Color(0xFF2F80ED),
              ),
            ),
            const SizedBox(height: 16),
            
            // Title
            Text(
              'Select Language',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0B1020),
              ),
            ),
            const SizedBox(height: 8),
            
            // Subtitle
            Text(
              'Choose your preferred language for the call',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 24),
            
            // Language options
            ...(_languages.map((lang) => _buildLanguageOption(
              lang['name']!,
              lang['icon']!,
              lang['subtitle']!,
            ))),
            
            const SizedBox(height: 20),
            
            // Continue button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedLanguage != null
                    ? () => Navigator.pop(context, _selectedLanguage)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2F80ED),
                  disabledBackgroundColor: const Color(0xFFE5E7EB),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Continue',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _selectedLanguage != null ? Colors.white : const Color(0xFF9CA3AF),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(String name, String icon, String subtitle) {
    final isSelected = _selectedLanguage == name;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedLanguage = name),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2F80ED).withOpacity(0.1) : const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF2F80ED) : const Color(0xFFE5E7EB),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF2F80ED) : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  icon,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? const Color(0xFF2F80ED) : const Color(0xFF0B1020),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            
            // Check icon
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF2F80ED),
                size: 28,
              ),
          ],
        ),
      ),
    );
  }
}

// Helper function to get locale ID
String getLocaleIdFromLanguage(String language) {
  switch (language) {
    case 'Hindi':
      return 'hi_IN';
    case 'Gujarati':
      return 'gu_IN';
    case 'Hinglish':
      return 'hi_IN'; // Use Hindi locale for Hinglish
    default:
      return 'en_IN';
  }
}
