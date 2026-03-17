import 'dart:io';
import 'package:flutter/material.dart';
import '../models/complaint.dart';
import '../services/complaint_service.dart';

class ComplaintProvider with ChangeNotifier {
  List<Complaint> _complaints = [];
  DashboardStats? _stats;
  Complaint? _selectedComplaint;
  bool _isLoading = false;
  String? _error;

  // Cache for states and cities
  List<String> _states = [];
  Map<String, List<String>> _citiesByState = {};
  bool _isStatesLoading = false;

  // Cache for subcategories
  final Map<String, Map<String, dynamic>> _subcategoryCache = {};

  List<Complaint> get complaints => _complaints;
  DashboardStats? get stats => _stats;
  Complaint? get selectedComplaint => _selectedComplaint;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<String> get states => _states;
  Map<String, List<String>> get citiesByState => _citiesByState;
  bool get isStatesLoading => _isStatesLoading;

  Future<void> loadStatesCities() async {
    if (_states.isNotEmpty) return; // Already loaded
    
    _isStatesLoading = true;
    notifyListeners();

    try {
      final response = await ComplaintService.getStatesCities();
      if (response['success'] == true) {
        _states = List<String>.from(response['states'] ?? []);
        final rawCities = response['cities_by_state'] as Map<String, dynamic>? ?? {};
        _citiesByState = rawCities.map((k, v) => MapEntry(k, List<String>.from(v)));
      }
    } catch (e) {
      debugPrint('Error loading states/cities: $e');
    }

    _isStatesLoading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> getSubcategories(String categoryKey) async {
    if (_subcategoryCache.containsKey(categoryKey)) {
      return _subcategoryCache[categoryKey]!;
    }

    final response = await ComplaintService.getSubcategories(categoryKey);
    if (response['success'] == true) {
      _subcategoryCache[categoryKey] = response;
    }
    return response;
  }

  Future<void> loadDashboardStats() async {
    _isLoading = true;
    notifyListeners();

    final response = await ComplaintService.getDashboardStats();

    _isLoading = false;
    if (response['success'] == true) {
      _stats = DashboardStats.fromJson(response['stats']);
    } else {
      _error = response['message'];
    }
    notifyListeners();
  }

  Future<void> loadComplaints({
    String? workStatus,
    String? complaintType,
    String? search,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ComplaintService.getComplaints(
        workStatus: workStatus,
        complaintType: complaintType,
        search: search,
      );

      _isLoading = false;
      
      // Handle both success format and direct data format
      if (response['success'] == true) {
        // Success format
        final results = response['results'] ?? [];
        _complaints = (results as List)
            .map((json) => Complaint.fromJson(json))
            .toList();
      } else if (response.containsKey('results')) {
        // Direct data format (like your API)
        final results = response['results'] ?? [];
        _complaints = (results as List)
            .map((json) => Complaint.fromJson(json))
            .toList();
        debugPrint('Loaded ${_complaints.length} complaints directly from API');
      } else if (response['success'] == false) {
        // Error format
        _error = response['message'] ?? 'Failed to load complaints';
      } else {
        // Unknown format
        _error = 'Unexpected API response format';
        debugPrint('Unknown API response: $response');
      }
    } catch (e) {
      _isLoading = false;
      _error = 'Error loading complaints: $e';
      debugPrint('Exception in loadComplaints: $e');
    }
    
    notifyListeners();
  }

  Future<void> loadComplaintDetail(int id) async {
    _isLoading = true;
    notifyListeners();

    final response = await ComplaintService.getComplaintDetail(id);

    _isLoading = false;
    if (response['success'] == true) {
      _selectedComplaint = Complaint.fromJson(response);
    } else {
      _error = response['message'];
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>?> createComplaint(
    Map<String, String> data,
    List<File> files,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final response = await ComplaintService.createComplaint(data, files);

    _isLoading = false;
    if (response['success'] == true) {
      notifyListeners();
      return response;
    } else {
      _error = response['message'] ?? 'Failed to submit complaint';
      notifyListeners();
      
      // If duplicate found, return the response so UI can show the specific dialog
      if (response['duplicate_found'] == true) {
        return response;
      }
      return null;
    }
  }

  Future<bool> rateComplaint(int id, int rating, String feedback) async {
    final response = await ComplaintService.rateComplaint(id, rating, feedback);
    if (response['success'] == true) {
      await loadComplaintDetail(id);
      return true;
    }
    return false;
  }

  Future<bool> reopenComplaint(int id, String reason, dynamic proofImage) async {
    final response = await ComplaintService.reopenComplaint(id, reason, proofImage);
    if (response['success'] == true) {
      await loadComplaintDetail(id);
      return true;
    }
    return false;
  }

  Future<void> refresh() async {
    await Future.wait([loadDashboardStats(), loadComplaints()]);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
