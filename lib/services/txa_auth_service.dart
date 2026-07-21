import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'txa_api.dart';
import 'txa_language.dart';
import '../utils/txa_logger.dart';

class TxaAuthService extends ChangeNotifier {
  static final TxaAuthService _instance = TxaAuthService._internal();
  factory TxaAuthService() => _instance;
  TxaAuthService._internal();

  String? _token;
  Map<String, dynamic>? _user;

  void _setUser(Map<String, dynamic>? user) {
    if (user != null) {
      final modifiableUser = Map<String, dynamic>.from(user);
      if (modifiableUser['avatar_url'] == null && modifiableUser['avatar'] != null) {
        modifiableUser['avatar_url'] = modifiableUser['avatar'];
      } else if (modifiableUser['avatar'] == null && modifiableUser['avatar_url'] != null) {
        modifiableUser['avatar'] = modifiableUser['avatar_url'];
      }
      _user = modifiableUser;
    } else {
      _user = null;
    }
  }

  bool get isLoggedIn => _token != null;
  String? get token => _token;
  Map<String, dynamic>? get user => _user;

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('txa_auth_token');
      final userStr = prefs.getString('txa_auth_user');
      if (userStr != null) {
        _setUser(jsonDecode(userStr) as Map<String, dynamic>?);
      }
      TxaLogger.log('TxaAuthService initialized: isLoggedIn=$isLoggedIn', type: 'auth');
      if (isLoggedIn) {
        await refreshUser();
      } else {
        notifyListeners();
      }
    } catch (e) {
      TxaLogger.log('TxaAuthService initialization error: $e', type: 'auth');
      notifyListeners();
    }
  }

  Future<void> refreshUser() async {
    if (!isLoggedIn) return;
    try {
      final profile = await TxaApi().getProfile();
      if (profile != null) {
        _setUser(profile);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('txa_auth_user', jsonEncode(_user));
        notifyListeners();
      }
    } catch (e) {
      TxaLogger.log('TxaAuthService refreshUser error: $e', type: 'auth');
    }
  }

  Future<Map<String, dynamic>> login(String identity, String password) async {
    try {
      final response = await TxaApi().login(identity, password);
      if (response != null && response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>?;
        if (data != null) {
          _token = data['access_token'] ?? data['token'];
          _setUser(data['user'] as Map<String, dynamic>?);

          if (_token != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('txa_auth_token', _token!);
            if (_user != null) {
              await prefs.setString('txa_auth_user', jsonEncode(_user));
            }
            TxaApi.clearCache();
            TxaLogger.log('Login successful for $identity', type: 'auth');
            notifyListeners();
            return {'success': true, 'message': response['message'] ?? 'Đăng nhập thành công'};
          }
        }
      }
      
      final data = response?['data'] as Map<String, dynamic>?;
      if (data != null && (data['error_code'] == 'EMAIL_NOT_VERIFIED' || data['errorType'] == 'verification')) {
        return {
          'success': false,
          'message': response?['message'] ?? 'Tài khoản chưa được xác minh email!',
          'isNotVerified': true,
          'email': data['email'] ?? '',
        };
      }

      final errorMsg = response?['message'] ?? 'Tài khoản hoặc mật khẩu không chính xác';
      return {'success': false, 'message': errorMsg};
    } catch (e) {
      TxaLogger.log('Login error: $e', type: 'auth');
      return {'success': false, 'message': 'Lỗi kết nối hoặc máy chủ: $e'};
    }
  }

  Future<Map<String, dynamic>> loginWithGoogle({String? idToken, String? accessToken}) async {
    try {
      final response = await TxaApi().googleLogin(credential: idToken, accessToken: accessToken);
      if (response != null && (response['status'] == 'success' || response['success'] == true)) {
        final data = response['data'] as Map<String, dynamic>? ?? response;
        if (data['exists'] == true && data['user'] != null) {
          final String? tokenVal = data['token'] ?? data['access_token'];
          final userData = data['user'] as Map<String, dynamic>?;
          if (tokenVal != null && userData != null) {
            await setSessionAuthData(tokenVal, userData);
            return {'success': true, 'message': TxaLanguage.t('login_success')};
          }
        } else if (data['exists'] == false) {
          return {
            'success': false,
            'isNewGoogleUser': true,
            'googleProfile': data['googleProfile'],
            'message': TxaLanguage.t('google_login_not_registered')
          };
        }
      }
      return {'success': false, 'message': response?['message'] ?? TxaLanguage.t('google_login_failed')};
    } catch (e) {
      TxaLogger.log('Google login error: $e', type: 'auth');
      return {'success': false, 'message': TxaLanguage.t('google_login_conn_error').replaceAll('%e%', '$e')};
    }
  }

  Future<void> setSessionAuthData(String authToken, Map<String, dynamic> userData) async {
    _token = authToken;
    _setUser(userData);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('txa_auth_token', _token!);
    if (_user != null) {
      await prefs.setString('txa_auth_user', jsonEncode(_user));
    }
    TxaApi.clearCache();
    TxaLogger.log('Auth session manually set for ${userData['username'] ?? userData['email']}', type: 'auth');
    notifyListeners();
  }

  /// Update a single field in the user object and persist to SharedPreferences
  void updateUserField(String key, dynamic value) {
    if (_user == null) return;
    final modifiableUser = Map<String, dynamic>.from(_user!);
    modifiableUser[key] = value;
    if (key == 'avatar_url') {
      modifiableUser['avatar'] = value;
    } else if (key == 'avatar') {
      modifiableUser['avatar_url'] = value;
    }
    _user = modifiableUser;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('txa_auth_user', jsonEncode(_user));
    });
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('txa_auth_token');
      await prefs.remove('txa_auth_user');
      _token = null;
      _user = null;
      TxaApi.clearCache();
      TxaLogger.log('Logged out successfully', type: 'auth');
      notifyListeners();
    } catch (e) {
      TxaLogger.log('Logout error: $e', type: 'auth');
    }
  }

  /// Helper to get token synchronously/asynchronously from SharedPreferences
  static Future<String?> getSavedToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('txa_auth_token');
  }
}
