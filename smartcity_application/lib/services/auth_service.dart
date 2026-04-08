import 'dart:convert';
import '../config/api_config.dart';
import '../models/user.dart';
import 'api_service.dart';
import 'storage_service.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static Future<Map<String, dynamic>> sendOtp(String email) async {
    return await ApiService.post(
      ApiConfig.sendOtp,
      {'email': email},
      includeAuth: false,
    );
  }

  static Future<Map<String, dynamic>> loginWithPassword(String identifier, String password) async {
    final response = await ApiService.post(
      ApiConfig.login,
      {'identifier': identifier, 'password': password},
      includeAuth: false,
    );
    if (response['success'] == true) {
      final token = response['access'] ?? response['token'];
      final refreshToken = response['refresh'];
      final userData = response['user'];
      
      if (token != null) await StorageService.saveToken(token);
      if (refreshToken != null) await StorageService.saveRefreshToken(refreshToken);
      if (userData != null) await StorageService.saveUserData(jsonEncode(userData));
      await StorageService.setLoggedIn(true);
    }
    return response;
  }

  static Future<Map<String, dynamic>> verifyOtp(String email, String otp) async {
    final response = await ApiService.post(
      ApiConfig.verifyOtp,
      {'email': email, 'otp': otp},
      includeAuth: false,
    );

    if (response['success'] == true) {
      // Save token and user data
      final token = response['access'] ?? response['token'];
      final refreshToken = response['refresh'];
      final userData = response['user'];

      if (token != null) await StorageService.saveToken(token);
      if (refreshToken != null) await StorageService.saveRefreshToken(refreshToken);
      if (userData != null) await StorageService.saveUserData(jsonEncode(userData));
      await StorageService.setLoggedIn(true);
    }

    return response;
  }

  static Future<Map<String, dynamic>> register(Map<String, dynamic> data) async {
    final response = await ApiService.post(
      ApiConfig.register,
      data,
      includeAuth: false,
    );

    if (response['success'] == true) {
      final token = response['access'] ?? response['token'];
      final refreshToken = response['refresh'];
      final userData = response['user'];

      if (token != null) {
        await StorageService.saveToken(token);
        await StorageService.setLoggedIn(true);
      }
      if (refreshToken != null) {
        await StorageService.saveRefreshToken(refreshToken);
      }
      if (userData != null) {
        await StorageService.saveUserData(jsonEncode(userData));
      }
    }

    return response;
  }

  static Future<Map<String, dynamic>> logout() async {
    Map<String, dynamic> response = {'success': true};
    try {
      response = await ApiService.post(ApiConfig.logout, {});
    } catch (e) {
      debugPrint('Logout API failed: $e');
      response = {
        'success': false,
        'message': 'Logout request failed, but local session was cleared.',
      };
    } finally {
      await StorageService.clearAll();
    }
    return response;
  }

  static Future<bool> refreshToken() async {
    final refreshToken = await StorageService.getRefreshToken();
    if (refreshToken == null) return false;

    try {
      final response = await ApiService.post(
        '${ApiConfig.baseUrl}/auth/token/refresh/',
        {'refresh': refreshToken},
        includeAuth: false,
      );

      if (response['access'] != null) {
        await StorageService.saveToken(response['access']);
        return true;
      }
    } catch (e) {
      debugPrint('Token refresh failed: $e');
    }

    // Don't force logout on refresh failure (network/transient issues).
    // Let the app keep current session data unless user explicitly logs out.
    return false;
  }

  static Future<User?> getCurrentUser() async {
    try {
      final userData = StorageService.getUserData();
      if (userData != null && userData.trim().isNotEmpty) {
        return User.fromJson(jsonDecode(userData));
      }
    } catch (e) {
      debugPrint('Failed to parse cached user: $e');
    }
    return null;
  }

  static Future<User?> fetchCurrentUserProfile() async {
    try {
      final response = await ApiService.get(ApiConfig.userProfile);
      if (response['success'] != true) {
        return null;
      }

      final payload = response['data'] is Map<String, dynamic>
          ? response['data'] as Map<String, dynamic>
          : response;
      final profile = payload['profile'];
      if (profile is! Map<String, dynamic>) {
        return null;
      }

      await StorageService.saveUserData(jsonEncode(profile));
      await StorageService.setLoggedIn(true);
      return User.fromJson(profile);
    } catch (e) {
      debugPrint('Failed to fetch current user profile: $e');
      return null;
    }
  }

  static Future<User?> restoreSession() async {
    final hasSession = await StorageService.hasActiveSession();
    if (!hasSession) {
      return null;
    }

    final cachedUser = await getCurrentUser();
    final token = await StorageService.getToken();
    final hasToken = token != null && token.trim().isNotEmpty;

    if (!hasToken) {
      final refreshed = await refreshToken();
      if (!refreshed) {
        return cachedUser;
      }
    }

    final serverUser = await fetchCurrentUserProfile();
    return serverUser ?? cachedUser;
  }

  static Future<bool> isAuthenticated() async {
    return await StorageService.hasActiveSession();
  }
}
