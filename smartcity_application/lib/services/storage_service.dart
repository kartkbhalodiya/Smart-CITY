import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static late SharedPreferences _prefs;
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  // Keys
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userKey = 'user_data';
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _chatSessionsKey = 'ai_chat_sessions';
  static const String _localeKey = 'app_locale';

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Tokens — saved in FlutterSecureStorage for encrypted security
  static Future<void> saveToken(String token) async {
    await _secureStorage.write(key: _tokenKey, value: token);
  }

  static Future<String?> getToken() async {
    return await _secureStorage.read(key: _tokenKey);
  }

  static Future<void> deleteToken() async {
    await _secureStorage.delete(key: _tokenKey);
  }

  // Refresh Token
  static Future<void> saveRefreshToken(String token) async {
    await _secureStorage.write(key: _refreshTokenKey, value: token);
  }

  static Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: _refreshTokenKey);
  }

  static Future<void> deleteRefreshToken() async {
    await _secureStorage.delete(key: _refreshTokenKey);
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

  static Future<void> saveChatSessions(String json) async {
    await _prefs.setString(_chatSessionsKey, json);
  }

  static String? getChatSessions() {
    return _prefs.getString(_chatSessionsKey);
  }

  // Clear All Data
  static Future<void> clearAll() async {
    await _prefs.clear();
    await _secureStorage.deleteAll();
  }
}
