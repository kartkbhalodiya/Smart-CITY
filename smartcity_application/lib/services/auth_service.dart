import 'dart:convert';
import '../config/api_config.dart';
import '../models/user.dart';
import 'api_service.dart';
import 'storage_service.dart';

class AuthService {
  static Future<Map<String, dynamic>> sendOtp(String email) async {
    return await ApiService.post(
      ApiConfig.sendOtp,
      {'email': email},
      includeAuth: false,
    );
  }

  static Future<Map<String, dynamic>> verifyOtp(String email, String otp) async {
    final response = await ApiService.post(
      ApiConfig.verifyOtp,
      {'email': email, 'otp': otp},
      includeAuth: false,
    );

    if (response['success'] == true) {
      // Save token and user data
      final token = response['token'];
      final userData = response['user'];

      await StorageService.saveToken(token);
      await StorageService.saveUserData(jsonEncode(userData));
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
      final token = response['token'];
      final userData = response['user'];

      if (token != null) {
        await StorageService.saveToken(token);
        await StorageService.setLoggedIn(true);
      }
      if (userData != null) {
        await StorageService.saveUserData(jsonEncode(userData));
      }
    }

    return response;
  }

  static Future<Map<String, dynamic>> logout() async {
    final response = await ApiService.post(ApiConfig.logout, {});
    await StorageService.clearAll();
    return response;
  }

  static Future<User?> getCurrentUser() async {
    final userData = StorageService.getUserData();
    if (userData != null) {
      return User.fromJson(jsonDecode(userData));
    }
    return null;
  }

  static Future<bool> isAuthenticated() async {
    final token = await StorageService.getToken();
    return token != null && StorageService.isLoggedIn();
  }
}
