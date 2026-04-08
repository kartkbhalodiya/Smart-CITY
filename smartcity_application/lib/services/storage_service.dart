import 'dart:convert';

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
    try {
      final incoming = jsonDecode(userData);
      final existingRaw = _prefs.getString(_userKey);
      final existing = existingRaw != null ? jsonDecode(existingRaw) : null;

      if (incoming is Map<String, dynamic>) {
        final normalized = _normalizeUserData(
          incoming,
          existing: existing is Map<String, dynamic> ? existing : null,
        );
        await _prefs.setString(_userKey, jsonEncode(normalized));
        return;
      }
    } catch (_) {}

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

  static Future<bool> hasActiveSession() async {
    if (!isLoggedIn()) {
      return false;
    }

    final token = await getToken();
    final refreshToken = await getRefreshToken();

    return (token?.trim().isNotEmpty ?? false) ||
        (refreshToken?.trim().isNotEmpty ?? false);
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

  static Map<String, dynamic> _normalizeUserData(
    Map<String, dynamic> raw, {
    Map<String, dynamic>? existing,
  }) {
    final sourceUser = raw['user'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(raw['user'] as Map<String, dynamic>)
        : Map<String, dynamic>.from(raw);

    final merged = <String, dynamic>{};
    if (existing != null) {
      merged.addAll(existing);
    }
    merged.addAll(sourceUser);

    String pickString(List<dynamic> values) {
      for (final value in values) {
        final text = (value ?? '').toString().trim();
        if (text.isNotEmpty && text.toLowerCase() != 'not provided') {
          return text;
        }
      }
      return '';
    }

    final firstName = pickString([
      sourceUser['first_name'],
      raw['first_name'],
      merged['first_name'],
    ]);
    final lastName = pickString([
      sourceUser['last_name'],
      raw['last_name'],
      merged['last_name'],
      raw['surname'],
    ]);
    final fullName = pickString([
      raw['full_name'],
      sourceUser['full_name'],
      '${firstName.isNotEmpty ? firstName : ''} ${lastName.isNotEmpty ? lastName : ''}'.trim(),
      raw['name'],
      merged['full_name'],
    ]);
    final mobile = pickString([
      raw['mobile_no'],
      sourceUser['mobile_no'],
      raw['mobile'],
      raw['phone'],
      merged['mobile_no'],
      merged['mobile'],
      merged['phone'],
    ]);
    final email = pickString([
      raw['email'],
      sourceUser['email'],
      merged['email'],
    ]);

    if (raw.containsKey('id')) merged['profile_id'] = raw['id'];
    if (raw.containsKey('state')) merged['state'] = raw['state'];
    if (raw.containsKey('district')) merged['district'] = raw['district'];
    if (raw.containsKey('city')) merged['city'] = raw['city'];
    if (raw.containsKey('address')) merged['address'] = raw['address'];
    if (raw.containsKey('pincode')) merged['pincode'] = raw['pincode'];
    if (raw.containsKey('aadhaar_number')) merged['aadhaar_number'] = raw['aadhaar_number'];
    if (raw.containsKey('latitude')) merged['latitude'] = raw['latitude'];
    if (raw.containsKey('longitude')) merged['longitude'] = raw['longitude'];

    merged['first_name'] = firstName;
    merged['last_name'] = lastName;
    merged['full_name'] = fullName;
    merged['name'] = fullName;
    merged['email'] = email;
    merged['mobile_no'] = mobile;
    merged['mobile'] = mobile;
    merged['phone'] = mobile;

    return merged;
  }
}
