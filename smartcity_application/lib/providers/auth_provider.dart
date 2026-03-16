import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  Future<void> loadUser() async {
    _user = await AuthService.getCurrentUser();
    notifyListeners();
  }

  Future<bool> sendOtp(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final response = await AuthService.sendOtp(email);

    _isLoading = false;
    if (response['success'] == true) {
      notifyListeners();
      return true;
    } else {
      _error = response['message'] ?? 'Failed to send OTP';
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>> loginWithPassword(String identifier, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final response = await AuthService.loginWithPassword(identifier, password);

    _isLoading = false;
    if (response['success'] == true) {
      if (response['user'] != null) _user = User.fromJson(response['user']);
      notifyListeners();
    } else {
      _error = response['message'] ?? 'Login failed';
      notifyListeners();
    }
    return response;
  }

  Future<Map<String, dynamic>> verifyOtp(String email, String otp) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final response = await AuthService.verifyOtp(email, otp);

    _isLoading = false;
    if (response['success'] == true) {
      _user = User.fromJson(response['user']);
      notifyListeners();
    } else {
      _error = response['message'] ?? 'Invalid OTP';
      notifyListeners();
    }
    return response;
  }

  Future<bool> register(Map<String, dynamic> data) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final response = await AuthService.register(data);

    _isLoading = false;
    if (response['success'] == true) {
      if (response['user'] != null) {
        _user = User.fromJson(response['user']);
      }
      notifyListeners();
      return true;
    } else {
      _error = response['message'] ?? 'Registration failed';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await AuthService.logout();
    _user = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
