import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static late SharedPreferences _prefs;

  // Keys
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _localeKey = 'app_locale';

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Token — saved in SharedPreferences so it persists across reinstalls
  static Future<void> saveToken(String token) async {
    await _prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    return _prefs.getString(_tokenKey);
  }

  static Future<void> deleteToken() async {
    await _prefs.remove(_tokenKey);
  }

  // User Data
  static Future<void> saveUserData(String userData) async {
    await _prefs.setString(_userKey, userData);
  }

  static String? getUserData() {
    return _prefs.getString(_userKey);
  }

  static Future<void> deleteUserData() async {
    await _prefs.remove(_userKey);
  }

  // Login Status
  static Future<void> setLoggedIn(bool value) async {
    await _prefs.setBool(_isLoggedInKey, value);
  }

  static bool isLoggedIn() {
    return _prefs.getBool(_isLoggedInKey) ?? false;
  }

  static Future<void> saveLocale(String localeCode) async {
    await _prefs.setString(_localeKey, localeCode);
  }

  static String getLocale() {
    return _prefs.getString(_localeKey) ?? 'en';
  }

  // Clear All Data
  static Future<void> clearAll() async {
    await _prefs.clear();
  }
}
