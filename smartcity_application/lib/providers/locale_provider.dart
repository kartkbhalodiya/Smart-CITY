import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  void loadLocale() {
    final savedLocale = StorageService.getLocale();
    _locale = Locale(savedLocale);
    notifyListeners();
  }

  Future<void> setLocale(String languageCode) async {
    if (!['en', 'hi', 'gu'].contains(languageCode)) {
      return;
    }
    if (_locale.languageCode == languageCode) {
      return;
    }
    _locale = Locale(languageCode);
    await StorageService.saveLocale(languageCode);
    notifyListeners();
  }
}
