import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'storage_service.dart';

class ApiService {
  static Future<Map<String, String>> _getHeaders({bool includeAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
    };

    if (includeAuth) {
      final token = await StorageService.getToken();
      if (token != null) {
        headers['Authorization'] = 'Token $token';
      }
    }

    return headers;
  }

  static Future<Map<String, dynamic>> get(String url, {bool includeAuth = true}) async {
    try {
      final headers = await _getHeaders(includeAuth: includeAuth);
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(ApiConfig.receiveTimeout);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> post(
    String url,
    Map<String, dynamic> body, {
    bool includeAuth = true,
  }) async {
    try {
      final headers = await _getHeaders(includeAuth: includeAuth);
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(ApiConfig.receiveTimeout);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> put(
    String url,
    Map<String, dynamic> body, {
    bool includeAuth = true,
  }) async {
    try {
      final headers = await _getHeaders(includeAuth: includeAuth);
      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(ApiConfig.receiveTimeout);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> delete(String url, {bool includeAuth = true}) async {
    try {
      final headers = await _getHeaders(includeAuth: includeAuth);
      final response = await http.delete(
        Uri.parse(url),
        headers: headers,
      ).timeout(ApiConfig.receiveTimeout);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> postMultipart(
    String url,
    Map<String, String> fields,
    List<File> files, {
    bool includeAuth = true,
  }) async {
    try {
      final token = includeAuth ? await StorageService.getToken() : null;
      final request = http.MultipartRequest('POST', Uri.parse(url));

      if (token != null) {
        request.headers['Authorization'] = 'Token $token';
      }

      // Add fields
      request.fields.addAll(fields);

      // Add files
      for (var file in files) {
        request.files.add(await http.MultipartFile.fromPath(
          'media_files',
          file.path,
        ));
      }

      final streamedResponse = await request.send().timeout(ApiConfig.receiveTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Upload error: $e'};
    }
  }

  static Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      final data = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data is Map<String, dynamic> ? data : {'success': true, 'data': data};
      } else {
        String msg = data['message'] ?? 'Request failed';
        if (data['errors'] != null && data['errors'] is Map) {
          final errors = data['errors'] as Map;
          if (errors.isNotEmpty) {
            final firstError = errors.values.first;
            if (firstError is List && firstError.isNotEmpty) {
              msg = firstError.first.toString();
            } else {
              msg = firstError.toString();
            }
          }
        } else if (data is Map && data.containsKey('detail')) {
          msg = data['detail'];
        }
        
        return {
          'success': false,
          'message': msg,
          'errors': data['errors'],
        };
      }
    } catch (e) {
      // Body is not JSON (e.g. HTML error page) — return clean message
      final code = response.statusCode;
      String msg;
      if (code == 404) {
        msg = 'No department account found with this email';
      } else if (code == 403) {
        msg = 'This email is not linked to any department account';
      } else if (code == 500) {
        msg = 'Server error. Please try again later';
      } else {
        msg = 'Something went wrong (error $code). Please try again';
      }
      return {'success': false, 'message': msg};
    }
  }
}
