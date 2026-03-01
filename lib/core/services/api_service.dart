import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Callback invoked when user is force logged out (banned/suspended)
typedef OnForceLogoutCallback = void Function();

class ApiService {
  /// Set this to handle force logouts due to banned/suspended status
  static OnForceLogoutCallback? onForceLogout;
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

  static Duration _resolveTimeout(Duration? timeout) => timeout ?? _timeout;

  static Future<Map<String, dynamic>> multipartFields(
    String endpoint, {
    required String method,
    Map<String, File>? files,
    Map<String, List<File>>? fileLists,
    String? token,
    Map<String, String>? fields,
    Map<String, String>? headers,
    Duration? timeout,
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

      Future<void> addFile(String field, File f) async {
        List<int>? headerBytes;
        try {
          final raf = await f.open();
          headerBytes = await raf.read(32);
          await raf.close();
        } catch (_) {
          headerBytes = null;
        }

        final detectedMime =
            lookupMimeType(f.path, headerBytes: headerBytes) ?? 'application/octet-stream';
        MediaType? mediaType;
        final parts = detectedMime.split('/');
        if (parts.length == 2) {
          mediaType = MediaType(parts[0], parts[1]);
        }

        request.files.add(
          await http.MultipartFile.fromPath(
            field,
            f.path,
            contentType: mediaType,
          ),
        );
      }

      if (files != null) {
        for (final entry in files.entries) {
          await addFile(entry.key, entry.value);
        }
      }
      if (fileLists != null) {
        for (final entry in fileLists.entries) {
          for (final f in entry.value) {
            await addFile(entry.key, f);
          }
        }
      }

      final streamed = await request.send().timeout(_resolveTimeout(timeout));
      final response = await http.Response.fromStream(streamed);
      return await _handleResponse(response);
    } on SocketException catch (e) {
      return _errorResponse('Connection failed: ${e.message}\nURL: $baseUrl$endpoint');
    } on HttpException {
      return _errorResponse('HTTP error occurred');
    } catch (e) {
      return _errorResponse('Network error: ${e.toString()}');
    }
  }

  // Generic PATCH request
  static Future<Map<String, dynamic>> patch(
    String endpoint, {
    Map<String, dynamic>? data,
    String? token,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    try {
      http.Response response = await http
          .patch(
            Uri.parse('$baseUrl$endpoint'),
            headers: _buildHeaders(token: token, additionalHeaders: headers),
            body: data != null ? jsonEncode(data) : null,
          )
          .timeout(_resolveTimeout(timeout));

      if (response.statusCode == 401 && token != null) {
        final newToken = await _refreshAccessToken();
        if (newToken != null) {
          response = await http
              .patch(
                Uri.parse('$baseUrl$endpoint'),
                headers: _buildHeaders(token: newToken, additionalHeaders: headers),
                body: data != null ? jsonEncode(data) : null,
              )
              .timeout(_resolveTimeout(timeout));
        }
      }

      return await _handleResponse(response);
    } on SocketException catch (e) {
      return _errorResponse('Connection failed: ${e.message}\nURL: $baseUrl$endpoint');
    } on HttpException {
      return _errorResponse('HTTP error occurred');
    } catch (e) {
      return _errorResponse('Network error: ${e.toString()}');
    }
  }

  static Future<String?> _refreshAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refresh_token');
    if (refreshToken == null || refreshToken.trim().isEmpty) return null;

    final response = await http
        .post(
          Uri.parse('$baseUrl/auth/refresh-token'),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'refreshToken': refreshToken}),
        )
        .timeout(_timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final decoded = jsonDecode(response.body);
    final data = decoded is Map ? decoded['data'] : null;
    if (data is! Map) return null;

    final newAccessToken = data['access_token']?.toString();
    final newRefreshToken = data['refresh_token']?.toString();

    if (newAccessToken == null || newAccessToken.trim().isEmpty) return null;

    await prefs.setString('auth_token', newAccessToken);
    if (newRefreshToken != null && newRefreshToken.trim().isNotEmpty) {
      await prefs.setString('refresh_token', newRefreshToken);
    }

    return newAccessToken;
  }

  /// Clear all stored auth tokens and data
  static Future<void> _clearAuthSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_data');
    await prefs.remove('remember_me');
    
    // Invoke callback to notify app to redirect to login
    onForceLogout?.call();
  }

  /// Check if error message indicates banned/suspended account
  static bool _isBanOrSuspendError(String message) {
    final lowerMessage = message.toLowerCase();
    return lowerMessage.contains('banned') ||
        lowerMessage.contains('suspended') ||
        lowerMessage.contains('cannot be restored');
  }

  static Future<Map<String, dynamic>> multipart(
    String endpoint, {
    required String method,
    required File file,
    required String fileField,
    String? token,
    Map<String, String>? fields,
    Map<String, String>? headers,
    Duration? timeout,
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
      return await _handleResponse(response);
    } on SocketException catch (e) {
      return _errorResponse('Connection failed: ${e.message}\nURL: $baseUrl$endpoint');
    } on HttpException {
      return _errorResponse('HTTP error occurred');
    } catch (e) {
      return _errorResponse('Network error: ${e.toString()}');
    }
  }

  /// Multipart request with bytes (for web and other platforms)
  static Future<Map<String, dynamic>> multipartBytes(
    String endpoint, {
    required String method,
    required String fileName,
    required List<int> bytes,
    required String fileField,
    String? token,
    Map<String, String>? fields,
    Map<String, String>? headers,
    Duration? timeout,
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

      // Detect MIME type from bytes and filename
      final detectedMime = lookupMimeType(fileName) ?? 'application/octet-stream';
      MediaType? mediaType;
      final parts = detectedMime.split('/');
      if (parts.length == 2) {
        mediaType = MediaType(parts[0], parts[1]);
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          fileField,
          bytes,
          filename: fileName,
          contentType: mediaType,
        ),
      );

      final streamed = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamed);
      return await _handleResponse(response);
    } on SocketException catch (e) {
      return _errorResponse('Connection failed: ${e.message}\nURL: $baseUrl$endpoint');
    } on HttpException {
      return _errorResponse('HTTP error occurred');
    } catch (e) {
      return _errorResponse('Network error: ${e.toString()}');
    }
  }

  /// GET request that returns raw body (for non-JSON like CSV).
  static Future<Map<String, dynamic>> getRaw(
    String endpoint, {
    String? token,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    try {
      http.Response response = await http
          .get(
            Uri.parse('$baseUrl$endpoint'),
            headers: _buildHeaders(token: token, additionalHeaders: headers),
          )
          .timeout(_resolveTimeout(timeout));

      if (response.statusCode == 401 && token != null) {
        final newToken = await _refreshAccessToken();
        if (newToken != null) {
          response = await http
              .get(
                Uri.parse('$baseUrl$endpoint'),
                headers: _buildHeaders(token: newToken, additionalHeaders: headers),
              )
              .timeout(_resolveTimeout(timeout));
        }
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {
          'success': true,
          'data': response.body,
          'statusCode': response.statusCode,
        };
      }
      return {
        'success': false,
        'message': 'Request failed with status ${response.statusCode}',
        'statusCode': response.statusCode,
      };
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
    Duration? timeout,
  }) async {
    try {
      http.Response response = await http
          .get(
            Uri.parse('$baseUrl$endpoint'),
            headers: _buildHeaders(token: token, additionalHeaders: headers),
          )
          .timeout(_resolveTimeout(timeout));

      if (response.statusCode == 401 && token != null) {
        final newToken = await _refreshAccessToken();
        if (newToken != null) {
          response = await http
              .get(
                Uri.parse('$baseUrl$endpoint'),
                headers: _buildHeaders(token: newToken, additionalHeaders: headers),
              )
              .timeout(_resolveTimeout(timeout));
        }
      }

      return await _handleResponse(response);
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
    Duration? timeout,
  }) async {
    try {
      http.Response response = await http
          .post(
            Uri.parse('$baseUrl$endpoint'),
            headers: _buildHeaders(token: token, additionalHeaders: headers),
            body: data != null ? jsonEncode(data) : null,
          )
          .timeout(_resolveTimeout(timeout));

      if (response.statusCode == 401 && token != null) {
        final newToken = await _refreshAccessToken();
        if (newToken != null) {
          response = await http
              .post(
                Uri.parse('$baseUrl$endpoint'),
                headers: _buildHeaders(token: newToken, additionalHeaders: headers),
                body: data != null ? jsonEncode(data) : null,
              )
              .timeout(_resolveTimeout(timeout));
        }
      }

      return await _handleResponse(response);
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
    Duration? timeout,
  }) async {
    try {
      http.Response response = await http
          .put(
            Uri.parse('$baseUrl$endpoint'),
            headers: _buildHeaders(token: token, additionalHeaders: headers),
            body: data != null ? jsonEncode(data) : null,
          )
          .timeout(_resolveTimeout(timeout));

      if (response.statusCode == 401 && token != null) {
        final newToken = await _refreshAccessToken();
        if (newToken != null) {
          response = await http
              .put(
                Uri.parse('$baseUrl$endpoint'),
                headers: _buildHeaders(token: newToken, additionalHeaders: headers),
                body: data != null ? jsonEncode(data) : null,
              )
              .timeout(_resolveTimeout(timeout));
        }
      }

      return await _handleResponse(response);
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
    Duration? timeout,
  }) async {
    try {
      http.Response response = await http
          .delete(
            Uri.parse('$baseUrl$endpoint'),
            headers: _buildHeaders(token: token, additionalHeaders: headers),
          )
          .timeout(_resolveTimeout(timeout));

      if (response.statusCode == 401 && token != null) {
        final newToken = await _refreshAccessToken();
        if (newToken != null) {
          response = await http
              .delete(
                Uri.parse('$baseUrl$endpoint'),
                headers: _buildHeaders(token: newToken, additionalHeaders: headers),
              )
              .timeout(_resolveTimeout(timeout));
        }
      }

      return await _handleResponse(response);
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
  static Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
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

        // If user is banned/suspended, force logout
        if (response.statusCode == 401 && _isBanOrSuspendError(message)) {
          await _clearAuthSession();
        }

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
