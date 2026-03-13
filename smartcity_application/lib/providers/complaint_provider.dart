import 'package:flutter/material.dart';
import '../models/complaint.dart';
import '../services/complaint_service.dart';

class ComplaintProvider with ChangeNotifier {
  List<Complaint> _complaints = [];
  DashboardStats? _stats;
  Complaint? _selectedComplaint;
  bool _isLoading = false;
  String? _error;

  List<Complaint> get complaints => _complaints;
  DashboardStats? get stats => _stats;
  Complaint? get selectedComplaint => _selectedComplaint;
  bool get isLoading => _isLoading;
  String? get error => _error;

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
    notifyListeners();

    final response = await ComplaintService.getComplaints(
      workStatus: workStatus,
      complaintType: complaintType,
      search: search,
    );

    _isLoading = false;
    if (response['success'] == true) {
      final results = response['results'] ?? [];
      _complaints = (results as List)
          .map((json) => Complaint.fromJson(json))
          .toList();
    } else {
      _error = response['message'];
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

  Future<bool> createComplaint(
    Map<String, String> data,
    List<dynamic> files,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final response = await ComplaintService.createComplaint(data, files);

    _isLoading = false;
    if (response['success'] == true) {
      notifyListeners();
      return true;
    } else {
      _error = response['message'] ?? 'Failed to submit complaint';
      notifyListeners();
      return false;
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

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
