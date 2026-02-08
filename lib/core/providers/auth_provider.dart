import 'package:flutter/material.dart';
import 'dart:io' show Platform, File;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  String? _token;
  String? _refreshToken;
  Map<String, dynamic>? _user;
  bool _isLoading = false;
  String? _errorMessage;
  bool _rememberMe = false;

  bool _biometricEnabled = false;

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _biometricTokenKey = 'biometric_auth_token';

  static const String _googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '1025078322603-odqc7615cg3v8dq1403jc4tpopifnha9.apps.googleusercontent.com',
  );

  static const String _googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: '',
  );

  static const String _googleMacosClientId = String.fromEnvironment(
    'GOOGLE_MACOS_CLIENT_ID',
    defaultValue: '',
  );

  // Getters
  String? get token => _token;
  String? get refreshToken => _refreshToken;
  Map<String, dynamic>? get user => _user;
  bool get rememberMe => _rememberMe;
  bool get biometricEnabled => _biometricEnabled;
  String get role => _user?['role']?.toString() ?? 'user';

  bool get isUser => role == 'user';
  bool get isDevl => role == 'devl';
  bool get isAdmin => role == 'admin';
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null;
  String? get errorMessage => _errorMessage;

  Future<bool> hasBiometricLoginConfigured() async {
    if (!_biometricEnabled) return false;
    final storedToken = await _readBiometricToken();
    return storedToken != null && storedToken.isNotEmpty;
  }

  GoogleSignIn _createGoogleSignIn() {
    if (Platform.isMacOS) {
      return GoogleSignIn(
        scopes: ['email', 'profile'],
        clientId: _googleMacosClientId.isNotEmpty ? _googleMacosClientId : null,
        serverClientId: _googleServerClientId,
      );
    }
    return GoogleSignIn(
      scopes: ['email', 'profile'],
      serverClientId: _googleServerClientId,
    );
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_token == null) {
      _setError('You must be signed in');
      return false;
    }

    _setLoading(true);
    _clearError();

    try {
      final result = await AuthService.changePassword(
        token: _token!,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      if (result['success'] == true) {
        _setLoading(false);
        return true;
      }

      _setError(result['message']?.toString() ?? 'Failed to update password');
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to update password: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  Map<String, dynamic> _normalizeUser(Map<String, dynamic> user) {
    final normalized = Map<String, dynamic>.from(user);
    final value = normalized['role'];
    final role = value?.toString().trim().toLowerCase();

    if (role == null || role.isEmpty) {
      normalized['role'] = 'user';
      return normalized;
    }

    if (role == 'dev' || role == 'developer') {
      normalized['role'] = 'devl';
      return normalized;
    }

    if (role != 'user' && role != 'devl' && role != 'admin') {
      normalized['role'] = 'user';
      return normalized;
    }

    normalized['role'] = role;
    return normalized;
  }

  // Initialize auth state from storage
  Future<void> init() async {
    await _loadAuthFromStorage();
  }

  // Load auth data from secure storage
  Future<void> _loadAuthFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Charger l'état rememberMe
      _rememberMe = prefs.getBool('remember_me') ?? false;
      _biometricEnabled = prefs.getBool(_biometricEnabledKey) ?? false;

      if (_rememberMe) {
        _token = prefs.getString('auth_token');
        _refreshToken = prefs.getString('refresh_token');
        final userString = prefs.getString('user_data');

        if (userString != null) {
          _user = _normalizeUser(
            Map<String, dynamic>.from(jsonDecode(userString)),
          );
        }
      } else {
        _token = null;
        _refreshToken = null;
        _user = null;
        await prefs.remove('auth_token');
        await prefs.remove('refresh_token');
        await prefs.remove('user_data');
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading auth from storage: $e');
    }
  }

  Future<String?> _readBiometricToken() async {
    try {
      return await _secureStorage.read(key: _biometricTokenKey);
    } catch (e) {
      debugPrint('Error reading biometric token: $e');
      return null;
    }
  }

  Future<void> _writeBiometricToken(String token) async {
    try {
      await _secureStorage.write(key: _biometricTokenKey, value: token);
    } catch (e) {
      debugPrint('Error writing biometric token: $e');
    }
  }

  Future<void> _deleteBiometricToken() async {
    try {
      await _secureStorage.delete(key: _biometricTokenKey);
    } catch (e) {
      debugPrint('Error deleting biometric token: $e');
    }
  }


  // Set remember me state
  void setRememberMe(bool value) {
    _rememberMe = value;
    _saveAuthToStorage(); // Sauvegarder immédiatement
    notifyListeners();
  }

  // Save auth data to secure storage
  Future<void> _saveAuthToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (_rememberMe) {
        if (_token != null) {
          await prefs.setString('auth_token', _token!);
        } else {
          await prefs.remove('auth_token');
        }

        if (_refreshToken != null) {
          await prefs.setString('refresh_token', _refreshToken!);
        } else {
          await prefs.remove('refresh_token');
        }

        if (_user != null) {
          // Convert user map to JSON string for storage
          final userJson = jsonEncode(_user!);
          await prefs.setString('user_data', userJson);
        } else {
          await prefs.remove('user_data');
        }
      } else {
        await prefs.remove('auth_token');
        await prefs.remove('refresh_token');
        await prefs.remove('user_data');
      }
      
      // Sauvegarder l'état rememberMe
      await prefs.setBool('remember_me', _rememberMe);
      await prefs.setBool(_biometricEnabledKey, _biometricEnabled);
    } catch (e) {
      debugPrint('Error saving auth to storage: $e');
    }
  }

  Future<bool> setBiometricEnabled(bool value) async {
    if (value) {
      if (_token == null) {
        _setError('You must be signed in to enable biometric login');
        return false;
      }

      final localAuth = LocalAuthentication();
      bool canCheck;
      try {
        canCheck = await localAuth.canCheckBiometrics || await localAuth.isDeviceSupported();
      } on PlatformException catch (e) {
        if (e.code == 'NotAvailable') {
          _setError('Biometrics not available on this device');
        } else {
          _setError('Biometrics not available');
        }
        return false;
      } catch (_) {
        _setError('Biometrics not available');
        return false;
      }

      if (!canCheck) {
        _setError('Biometrics not available');
        return false;
      }

      bool ok;
      try {
        ok = await localAuth.authenticate(
          localizedReason: 'Use biometrics to enable quick login',
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: true,
          ),
        );
      } on PlatformException catch (e) {
        if (e.code == 'NotEnrolled') {
          _setError('No Face ID / Touch ID enrolled on this device');
        } else if (e.code == 'PasscodeNotSet') {
          _setError('Set a device passcode to enable Face ID / Touch ID');
        } else if (e.code == 'NotAvailable') {
          _setError('Biometrics not available on this device');
        } else if (e.code == 'LockedOut' || e.code == 'PermanentlyLockedOut') {
          _setError('Biometrics locked. Use device passcode and try again');
        } else {
          _setError('Biometric authentication failed');
        }
        return false;
      } catch (_) {
        _setError('Biometric authentication failed');
        return false;
      }

      if (!ok) {
        _setError('Biometric authentication cancelled');
        return false;
      }

      _biometricEnabled = true;
      await _writeBiometricToken(_token!);
      await _saveAuthToStorage();
      notifyListeners();
      return true;
    }

    _biometricEnabled = false;
    await _deleteBiometricToken();
    await _saveAuthToStorage();
    notifyListeners();
    return true;
  }

  Future<bool> tryBiometricLogin() async {
    if (!_biometricEnabled) return false;

    final storedToken = await _readBiometricToken();
    if (storedToken == null || storedToken.isEmpty) return false;

    final localAuth = LocalAuthentication();
    bool supported;
    try {
      supported = await localAuth.isDeviceSupported();
    } on PlatformException catch (e) {
      if (e.code == 'NotAvailable') {
        _setError('Biometrics not available on this device');
      }
      return false;
    } catch (_) {
      return false;
    }

    if (!supported) return false;

    bool ok;
    try {
      ok = await localAuth.authenticate(
        localizedReason: 'Sign in with Face ID / Touch ID',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } on PlatformException catch (e) {
      if (e.code == 'NotEnrolled') {
        _setError('No Face ID / Touch ID enrolled on this device');
      } else if (e.code == 'PasscodeNotSet') {
        _setError('Set a device passcode to use Face ID / Touch ID');
      } else if (e.code == 'NotAvailable') {
        _setError('Biometrics not available on this device');
      } else if (e.code == 'LockedOut' || e.code == 'PermanentlyLockedOut') {
        _setError('Biometrics locked. Use device passcode and try again');
      } else {
        _setError('Biometric authentication failed');
      }
      return false;
    } catch (_) {
      return false;
    }

    if (!ok) return false;

    _setLoading(true);
    _clearError();

    try {
      final res = await AuthService.getProfile(storedToken);
      if (res['success'] == true) {
        _token = storedToken;
        final data = res['data'];
        final user = (data is Map<String, dynamic>) ? data['user'] : null;
        if (user is Map<String, dynamic>) {
          _user = _normalizeUser(Map<String, dynamic>.from(user));
        } else if (data is Map<String, dynamic>) {
          _user = _normalizeUser(Map<String, dynamic>.from(data));
        }
        _setLoading(false);
        notifyListeners();
        return true;
      }
      _setLoading(false);
      return false;
    } catch (_) {
      _setLoading(false);
      return false;
    }
  }

  // Login method
  Future<bool> login({
    required String email,
    required String password,
    bool? rememberMe,
  }) async {
    _setLoading(true);
    _clearError();
    if (rememberMe != null) {
      _rememberMe = rememberMe;
    }

    try {
      final result = await AuthService.login(email: email, password: password, rememberMe: rememberMe);
      
      if (result['success']) {
        final data = result['data'];
        _token = data['access_token'];
        _refreshToken = data['refresh_token']?.toString();
        if (data['user'] is Map<String, dynamic>) {
          _user = _normalizeUser(Map<String, dynamic>.from(data['user']));
        } else {
          _user = _normalizeUser(<String, dynamic>{});
        }
        
        await _saveAuthToStorage();
        if (_biometricEnabled && _token != null) {
          await _writeBiometricToken(_token!);
        }
        _setLoading(false);
        return true;
      } else {
        _setError(result['message'] ?? 'Login failed');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('Login failed: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> loginWithGoogle({
    bool? rememberMe,
    String? role,
  }) async {
    _setLoading(true);
    _clearError();
    if (rememberMe != null) {
      _rememberMe = rememberMe;
    }

    try {
      final googleSignIn = _createGoogleSignIn();
      final account = await googleSignIn.signIn();

      if (account == null) {
        _setError('Google sign-in was cancelled');
        _setLoading(false);
        return false;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;

      if (idToken == null) {
        _setError('Google sign-in failed: missing ID token');
        _setLoading(false);
        return false;
      }

      final result = await AuthService.googleLogin(
        idToken: idToken,
        role: role,
        rememberMe: rememberMe,
      );

      if (result['success']) {
        final data = result['data'];
        _token = data['access_token'];
        _refreshToken = data['refresh_token']?.toString();
        if (data['user'] is Map<String, dynamic>) {
          _user = _normalizeUser(Map<String, dynamic>.from(data['user']));
        } else {
          _user = _normalizeUser(<String, dynamic>{});
        }

        await _saveAuthToStorage();
        if (_biometricEnabled && _token != null) {
          await _writeBiometricToken(_token!);
        }
        _setLoading(false);
        return true;
      }

      _setError(result['message'] ?? 'Google login failed');
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Google login failed: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Register method
  Future<bool> register({
    required String username,
    required String email,
    required String password,
    String? role,
    bool? rememberMe,
  }) async {
    _setLoading(true);
    _clearError();
    if (rememberMe != null) {
      _rememberMe = rememberMe;
    }

    try {
      final result = await AuthService.register(
        username: username,
        email: email,
        password: password,
        role: role ?? 'user',
        rememberMe: rememberMe,
      );
      
      if (result['success']) {
        final data = result['data'];
        _token = data['access_token'];
        _refreshToken = data['refresh_token']?.toString();
        if (data['user'] is Map<String, dynamic>) {
          _user = _normalizeUser(Map<String, dynamic>.from(data['user']));
        } else {
          _user = _normalizeUser(<String, dynamic>{});
        }
        
        await _saveAuthToStorage();
        if (_biometricEnabled && _token != null) {
          await _writeBiometricToken(_token!);
        }
        _setLoading(false);
        return true;
      } else {
        _setError(result['message'] ?? 'Registration failed');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('Registration failed: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Update profile method
  Future<bool> updateProfile({
    String? username,
    String? avatar,
    String? fullName,
    String? bio,
    String? location,
    String? website,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await AuthService.updateProfile(
        token: _token!,
        username: username,
        avatar: avatar,
        fullName: fullName,
        bio: bio,
        location: location,
        website: website,
      );
      
      if (result['success']) {
        final data = result['data'];
        if (data['user'] is Map<String, dynamic>) {
          _user = _normalizeUser(Map<String, dynamic>.from(data['user']));
        } else {
          _user = _normalizeUser(<String, dynamic>{});
        }
        
        await _saveAuthToStorage();
        _setLoading(false);
        return true;
      } else {
        _setError(result['message'] ?? 'Profile update failed');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('Profile update failed: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updateAvatar(File avatarFile) async {
    if (_token == null) return false;

    _setLoading(true);
    _clearError();

    try {
      final result = await AuthService.uploadAvatar(
        token: _token!,
        avatarFile: avatarFile,
      );

      if (result['success']) {
        final data = result['data'];
        if (data['user'] is Map<String, dynamic>) {
          _user = _normalizeUser(Map<String, dynamic>.from(data['user']));
        } else {
          _user = _normalizeUser(<String, dynamic>{});
        }

        await _saveAuthToStorage();
        _setLoading(false);
        return true;
      } else {
        _setError(result['message'] ?? 'Avatar update failed');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('Avatar update failed: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Logout method
  Future<void> logout({BuildContext? context}) async {
    try {
      if (_token != null) {
        await AuthService.logout(_token!);
      }
    } catch (e) {
      debugPrint('Error during logout: $e');
    } finally {
      _token = null;
      _refreshToken = null;
      _user = null;
      // Ne PAS supprimer _rememberMe pour le garder sauvegardé
      await _saveAuthToStorage();
      await _deleteBiometricToken();
      notifyListeners();
    }
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Get authorization header
  String? get authHeader => _token != null ? 'Bearer $_token' : null;
}
