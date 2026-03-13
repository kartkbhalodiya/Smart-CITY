import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static late SharedPreferences _prefs;
  static const _storage = FlutterSecureStorage();

  // Keys
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';
  static const String _isLoggedInKey = 'is_logged_in';

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Token Management
  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  static Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
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

  // Clear All Data
  static Future<void> clearAll() async {
    await _storage.deleteAll();
    await _prefs.clear();
  }
}
