import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'storage_service.dart';
import 'auth_service.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  static Future<String?> getToken() async {
    return await StorageService.getToken();
  }

  static Future<Map<String, String>> _getHeaders({bool includeAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
    };

    if (includeAuth) {
      final token = await StorageService.getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  static Future<Map<String, dynamic>> get(String url, {bool includeAuth = true}) async {
    try {
      debugPrint('[ApiService GET] URL: $url');
      final headers = await _getHeaders(includeAuth: includeAuth);
      debugPrint('[ApiService GET] Headers: $headers');
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(ApiConfig.receiveTimeout);

      debugPrint('[ApiService GET] Status: ${response.statusCode}');
      debugPrint('[ApiService GET] Body length: ${response.body.length}');

      if (response.statusCode == 401 && includeAuth) {
        return await _retryWithRefresh('GET', url);
      }

      return _handleResponse(response);
    } catch (e) {
      debugPrint('[ApiService GET] ERROR: $e');
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

      if (response.statusCode == 401 && includeAuth) {
        return await _retryWithRefresh('POST', url, body: body);
      }

      return _handleResponse(response);
    } catch (e) {
      debugPrint('[ApiService POST] URL: $url | ERROR: $e');
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

      if (response.statusCode == 401 && includeAuth) {
        return await _retryWithRefresh('PUT', url, body: body);
      }

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

      if (response.statusCode == 401 && includeAuth) {
        return await _retryWithRefresh('DELETE', url);
      }

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> _retryWithRefresh(
    String method,
    String url, {
    Map<String, dynamic>? body,
  }) async {
    final refreshed = await AuthService.refreshToken();
    if (refreshed) {
      // Retry the original request
      if (method == 'GET') return await get(url);
      if (method == 'POST') return await post(url, body!);
      if (method == 'PUT') return await put(url, body!);
      if (method == 'DELETE') return await delete(url);
    }
    return {
      'success': false,
      'message': 'Unable to verify session right now. Please try again.',
      'code': 'auth_refresh_failed',
    };
  }

  static Future<Map<String, dynamic>> postMultipart(
    String url,
    Map<String, String> fields,
    List<File> files, {
    bool includeAuth = true,
  }) async {
    try {
      return await _postMultipartInternal(
        url,
        fields,
        files,
        includeAuth: includeAuth,
        allowRetry: true,
      );
    } catch (e) {
      return {'success': false, 'message': 'Upload error: $e'};
    }
  }

  static Future<Map<String, dynamic>> _postMultipartInternal(
    String url,
    Map<String, String> fields,
    List<File> files, {
    required bool includeAuth,
    required bool allowRetry,
  }) async {
    final token = includeAuth ? await StorageService.getToken() : null;
    final request = http.MultipartRequest('POST', Uri.parse(url));

    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.fields.addAll(fields);

    for (final file in files) {
      request.files.add(await http.MultipartFile.fromPath(
        'media_files',
        file.path,
      ));
    }

    final streamedResponse = await request.send().timeout(ApiConfig.receiveTimeout);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 401 && includeAuth && allowRetry) {
      debugPrint('[ApiService] 401 detected. Attempting token refresh...');
      final refreshed = await AuthService.refreshToken();
      if (refreshed) {
        debugPrint('[ApiService] Refresh succeeded. Retrying request with new token.');
        return _postMultipartInternal(
          url,
          fields,
          files,
          includeAuth: includeAuth,
          allowRetry: false,
        );
      } else {
        debugPrint('[ApiService] Refresh failed. Attempting Guest Fallback...');
        // If refresh fails, try one last time WITHOUT authentication.
        // This allows endpoints like AI complaint submission to succeed as 'guest'
        // instead of failing terminal with 401.
        return _postMultipartInternal(
          url,
          fields,
          files,
          includeAuth: false,
          allowRetry: false,
        );
      }
    }

    return _handleResponse(response);
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
