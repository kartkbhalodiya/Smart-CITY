import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  bool _isAuthenticated = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _isAuthenticated;

  Future<void> loadUser() async {
    _user = await AuthService.restoreSession();
    _isAuthenticated = await AuthService.isAuthenticated();
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
      _isAuthenticated = true;
      notifyListeners();
    } else {
      _error = response['message'] ?? 'Login failed';
      _isAuthenticated = false;
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
      _isAuthenticated = true;
      notifyListeners();
    } else {
      _error = response['message'] ?? 'Invalid OTP';
      _isAuthenticated = false;
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
      _isAuthenticated = true;
      notifyListeners();
      return true;
    } else {
      _error = response['message'] ?? 'Registration failed';
      _isAuthenticated = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await AuthService.logout();
    _user = null;
    _isAuthenticated = false;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
