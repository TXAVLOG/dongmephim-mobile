import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'txa_api.dart';
import '../utils/txa_logger.dart';

class TxaAuthService extends ChangeNotifier {
  static final TxaAuthService _instance = TxaAuthService._internal();
  factory TxaAuthService() => _instance;
  TxaAuthService._internal();

  String? _token;
  Map<String, dynamic>? _user;

  bool get isLoggedIn => _token != null;
  String? get token => _token;
  Map<String, dynamic>? get user => _user;

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('txa_auth_token');
      final userStr = prefs.getString('txa_auth_user');
      if (userStr != null) {
        _user = jsonDecode(userStr) as Map<String, dynamic>?;
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
        _user = profile;
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
          _user = data['user'] as Map<String, dynamic>?;

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
