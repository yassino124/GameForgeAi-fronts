import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

class ApiService {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:3000/api',
  );

  static String get baseUrl {
    if (_configuredBaseUrl != 'http://127.0.0.1:3000/api') {
      return _configuredBaseUrl;
    }
    if (kIsWeb) {
      return _configuredBaseUrl;
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000/api';
    }
    return _configuredBaseUrl;
  }
  static const Duration _timeout = Duration(seconds: 30);

  static Future<Map<String, dynamic>> multipart(
    String endpoint, {
    required String method,
    required File file,
    required String fileField,
    String? token,
    Map<String, String>? fields,
    Map<String, String>? headers,
  }) async {
    try {
      final request = http.MultipartRequest(
        method,
        Uri.parse('$baseUrl$endpoint'),
      );

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.headers['Accept'] = 'application/json';

      if (headers != null) {
        request.headers.addAll(headers);
      }

      if (fields != null) {
        request.fields.addAll(fields);
      }

      List<int>? headerBytes;
      try {
        final raf = await file.open();
        headerBytes = await raf.read(32);
        await raf.close();
      } catch (_) {
        headerBytes = null;
      }

      final detectedMime =
          lookupMimeType(file.path, headerBytes: headerBytes) ?? 'application/octet-stream';
      MediaType? mediaType;
      final parts = detectedMime.split('/');
      if (parts.length == 2) {
        mediaType = MediaType(parts[0], parts[1]);
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          fileField,
          file.path,
          contentType: mediaType,
        ),
      );

      final streamed = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamed);
      return _handleResponse(response);
    } on SocketException catch (e) {
      return _errorResponse('Connection failed: ${e.message}\nURL: $baseUrl$endpoint');
    } on HttpException {
      return _errorResponse('HTTP error occurred');
    } catch (e) {
      return _errorResponse('Network error: ${e.toString()}');
    }
  }

  // Generic GET request
  static Future<Map<String, dynamic>> get(
    String endpoint, {
    String? token,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl$endpoint'),
            headers: _buildHeaders(token: token, additionalHeaders: headers),
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } on SocketException catch (e) {
      return _errorResponse('Connection failed: ${e.message}\nURL: $baseUrl$endpoint');
    } on HttpException {
      return _errorResponse('HTTP error occurred');
    } catch (e) {
      return _errorResponse('Network error: ${e.toString()}');
    }
  }

  // Generic POST request
  static Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? data,
    String? token,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl$endpoint'),
            headers: _buildHeaders(token: token, additionalHeaders: headers),
            body: data != null ? jsonEncode(data) : null,
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } on SocketException catch (e) {
      return _errorResponse('Connection failed: ${e.message}\nURL: $baseUrl$endpoint');
    } on HttpException {
      return _errorResponse('HTTP error occurred');
    } catch (e) {
      return _errorResponse('Network error: ${e.toString()}');
    }
  }

  // Generic PUT request
  static Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? data,
    String? token,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl$endpoint'),
            headers: _buildHeaders(token: token, additionalHeaders: headers),
            body: data != null ? jsonEncode(data) : null,
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } on SocketException catch (e) {
      return _errorResponse('Connection failed: ${e.message}\nURL: $baseUrl$endpoint');
    } on HttpException {
      return _errorResponse('HTTP error occurred');
    } catch (e) {
      return _errorResponse('Network error: ${e.toString()}');
    }
  }

  // Generic DELETE request
  static Future<Map<String, dynamic>> delete(
    String endpoint, {
    String? token,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$baseUrl$endpoint'),
            headers: _buildHeaders(token: token, additionalHeaders: headers),
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } on SocketException catch (e) {
      return _errorResponse('Connection failed: ${e.message}\nURL: $baseUrl$endpoint');
    } on HttpException {
      return _errorResponse('HTTP error occurred');
    } catch (e) {
      return _errorResponse('Network error: ${e.toString()}');
    }
  }

  // Build headers for requests
  static Map<String, String> _buildHeaders({
    String? token,
    Map<String, String>? additionalHeaders,
  }) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }

    return headers;
  }

  // Handle HTTP response
  static Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      final responseData = jsonDecode(response.body);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {
          'success': true,
          'data': responseData['data'] ?? responseData,
          'statusCode': response.statusCode,
        };
      } else {
        final message = _normalizeErrorMessage(
          responseData['message'],
          fallback: responseData['error'],
          statusCode: response.statusCode,
        );
        return {
          'success': false,
          'message': message,
          'statusCode': response.statusCode,
          'data': responseData,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to parse response: ${e.toString()}',
        'statusCode': response.statusCode,
      };
    }
  }

  static String _normalizeErrorMessage(
    dynamic message, {
    dynamic fallback,
    required int statusCode,
  }) {
    if (message is String && message.trim().isNotEmpty) return message;

    if (message is List) {
      final items = message
          .where((e) => e != null)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (items.isNotEmpty) return items.join('\n');
    }

    if (fallback is String && fallback.trim().isNotEmpty) return fallback;

    if (message != null) {
      final asString = message.toString().trim();
      if (asString.isNotEmpty) return asString;
    }
    if (fallback != null) {
      final asString = fallback.toString().trim();
      if (asString.isNotEmpty) return asString;
    }

    return 'Request failed with status $statusCode';
  }

  // Create error response
  static Map<String, dynamic> _errorResponse(String message) {
    return {
      'success': false,
      'message': message,
      'statusCode': -1,
    };
  }
}
