import 'dart:io';
import '../config/api_config.dart';
import 'api_service.dart';

class ComplaintService {
  static Future<Map<String, dynamic>> getDashboardStats() async {
    return await ApiService.get(ApiConfig.dashboardStats);
  }

  static Future<Map<String, dynamic>> getComplaints({
    String? workStatus,
    String? complaintType,
    String? search,
  }) async {
    String url = ApiConfig.complaints;
    List<String> params = [];

    if (workStatus != null) params.add('work_status=$workStatus');
    if (complaintType != null) params.add('complaint_type=$complaintType');
    if (search != null) params.add('search=$search');

    if (params.isNotEmpty) {
      url += '?${params.join('&')}';
    }

    return await ApiService.get(url);
  }

  static Future<Map<String, dynamic>> getComplaintDetail(int id) async {
    return await ApiService.get(ApiConfig.complaintDetail(id));
  }

  static Future<Map<String, dynamic>> createComplaint(
    Map<String, String> data,
    List<File> files,
  ) async {
    return await ApiService.postMultipart(
      ApiConfig.complaints,
      data,
      files,
    );
  }

  static Future<Map<String, dynamic>> rateComplaint(
    int id,
    int rating,
    String feedback,
  ) async {
    return await ApiService.post(
      ApiConfig.rateComplaint(id),
      {'rating': rating, 'feedback': feedback},
    );
  }

  static Future<Map<String, dynamic>> reopenComplaint(
    int id,
    String reason,
    File proofImage,
  ) async {
    return await ApiService.postMultipart(
      ApiConfig.reopenComplaint(id),
      {'reason': reason},
      [proofImage],
    );
  }

  static Future<Map<String, dynamic>> verifyProof(
    String categoryKey,
    List<File> files, {
    bool uploadedOnly = false,
    String? subcategory,
    String? description,
  }) async {
    final fields = <String, String>{
      'complaint_type': categoryKey,
      'uploaded_only_verification': uploadedOnly ? 'true' : 'false',
    };

    final trimmedSubcategory = subcategory?.trim();
    if (trimmedSubcategory != null && trimmedSubcategory.isNotEmpty) {
      fields['subcategory'] = trimmedSubcategory;
    }

    final trimmedDescription = description?.trim();
    if (trimmedDescription != null && trimmedDescription.isNotEmpty) {
      fields['description'] = trimmedDescription;
    }

    return await ApiService.postMultipart(
      ApiConfig.verifyProof,
      fields,
      files,
    );
  }

  static Future<Map<String, dynamic>> getCategories() async {
    return await ApiService.get(ApiConfig.categories);
  }

  static Future<Map<String, dynamic>> getSubcategories(String categoryKey) async {
    return await ApiService.get(ApiConfig.subcategories(categoryKey));
  }

  static Future<Map<String, dynamic>> getStatesCities() async {
    return await ApiService.get(ApiConfig.statesCities, includeAuth: false);
  }
}
