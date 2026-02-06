import 'dart:io';

import 'api_service.dart';

class AuthService {
  // Register user
  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    String? role,
    bool? rememberMe,
  }) async {
    final data = <String, dynamic>{
      'username': username.trim(),
      'email': email.trim(),
      'password': password,
    };
    if (role != null) data['role'] = role;
    if (rememberMe != null) data['rememberMe'] = rememberMe;
    return await ApiService.post('/auth/register', data: data);
  }

  // Login user
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    bool? rememberMe,
  }) async {
    final data = <String, dynamic>{
      'email': email.trim(),
      'password': password,
    };
    if (rememberMe != null) data['rememberMe'] = rememberMe;
    return await ApiService.post('/auth/login', data: data);
  }

  // Google login with ID token (mobile)
  static Future<Map<String, dynamic>> googleLogin({
    required String idToken,
    String? role,
    bool? rememberMe,
  }) async {
    final data = <String, dynamic>{
      'idToken': idToken,
    };
    if (role != null) data['role'] = role;
    if (rememberMe != null) data['rememberMe'] = rememberMe;
    return await ApiService.post('/auth/google/mobile', data: data);
  }

  // Get user profile
  static Future<Map<String, dynamic>> getProfile(String token) async {
    return await ApiService.get(
      '/auth/profile',
      token: token,
    );
  }

  // Update user profile
  static Future<Map<String, dynamic>> updateProfile({
    required String token,
    String? username,
    String? avatar,
    String? fullName,
    String? bio,
    String? location,
    String? website,
  }) async {
    final data = <String, dynamic>{};
    if (username != null) data['username'] = username.trim();
    if (avatar != null) data['avatar'] = avatar;
    if (fullName != null) data['fullName'] = fullName.trim();
    if (bio != null) data['bio'] = bio.trim();
    if (location != null) data['location'] = location.trim();
    if (website != null) data['website'] = website.trim();

    return await ApiService.put(
      '/auth/profile',
      data: data,
      token: token,
    );
  }

  static Future<Map<String, dynamic>> uploadAvatar({
    required String token,
    required File avatarFile,
  }) async {
    return await ApiService.multipart(
      '/auth/profile/avatar',
      method: 'PATCH',
      token: token,
      file: avatarFile,
      fileField: 'avatar',
    );
  }

  // Logout (if backend supports it)
  static Future<Map<String, dynamic>> logout(String token) async {
    return await ApiService.post(
      '/auth/logout',
      token: token,
    );
  }

  // Refresh token (if backend supports it)
  static Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    return await ApiService.post(
      '/auth/refresh-token',
      data: {'refreshToken': refreshToken},
    );
  }

  // Forgot password
  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    return await ApiService.post(
      '/auth/forgot-password',
      data: {'email': email.trim()},
    );
  }

  // Reset password
  static Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    return await ApiService.post(
      '/auth/reset-password',
      data: {
        'token': token,
        'newPassword': newPassword,
      },
    );
  }

  // Change password (logged-in)
  static Future<Map<String, dynamic>> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  }) async {
    return await ApiService.post(
      '/auth/change-password',
      token: token,
      data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
  }

  // Verify email
  static Future<Map<String, dynamic>> verifyEmail(String token) async {
    return await ApiService.get(
      '/auth/verify-email/$token',
    );
  }
}
