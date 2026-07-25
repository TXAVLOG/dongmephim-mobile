import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'txa_api.dart';
import 'txa_language.dart';
import 'txa_persistent_auth_vault.dart';
import 'txa_dynamic_icon_service.dart';
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

  Future<void> initialize({void Function(String msg, {bool isError})? onShowToast}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('txa_auth_token');
      final userStr = prefs.getString('txa_auth_user');
      if (userStr != null) {
        _setUser(jsonDecode(userStr) as Map<String, dynamic>?);
      }

      // Khôi phục phiên đăng nhập từ Hardware Vault nếu SharedPreferences bị xóa do gỡ/cài lại app trên cùng thiết bị
      if (!isLoggedIn) {
        final vaultData = await TxaPersistentAuthVault.readSavedSession();
        if (vaultData != null) {
          final restoredToken = vaultData['token']?.toString();
          final restoredUser = vaultData['user'] as Map<String, dynamic>?;
          final restoredIcon = vaultData['active_app_icon']?.toString();

          if (restoredToken != null && restoredUser != null) {
            _token = restoredToken;
            _setUser(restoredUser);

            await prefs.setString('txa_auth_token', _token!);
            await prefs.setString('txa_auth_user', jsonEncode(_user));

            if (restoredIcon != null && restoredIcon.isNotEmpty) {
              await prefs.setString('txa_active_app_icon', restoredIcon);
              await TxaDynamicIconService.setAppIcon(restoredIcon);
            }

            TxaLogger.log('Tự động khôi phục phiên đăng nhập từ Hardware Vault cho user: ${restoredUser['username']}', type: 'auth');
            final userName = restoredUser['name'] ?? restoredUser['username'] ?? '';
            onShowToast?.call(TxaLanguage.t('session_auto_restored').replaceAll('%user%', userName));
          }
        }
      }

      TxaLogger.log('TxaAuthService initialized: isLoggedIn=$isLoggedIn', type: 'auth');
      if (isLoggedIn) {
        await refreshUser(onShowToast: onShowToast);
      } else {
        notifyListeners();
      }
    } catch (e) {
      TxaLogger.log('TxaAuthService initialization error: $e', type: 'auth');
      notifyListeners();
    }
  }

  Future<void> refreshUser({void Function(String msg, {bool isError})? onShowToast}) async {
    if (!isLoggedIn) return;
    try {
      final statusRes = await TxaApi().getProfileStatus();
      final status = statusRes['status'];

      if (status == 'success') {
        final profile = statusRes['data'] as Map<String, dynamic>?;
        if (profile != null) {
          _setUser(profile);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('txa_auth_user', jsonEncode(_user));
          
          final activeIcon = prefs.getString('txa_active_app_icon') ?? 'icon_default.png';
          await TxaPersistentAuthVault.saveSession(
            token: _token!,
            user: _user!,
            activeAppIcon: activeIcon,
          );
          notifyListeners();
        }
      } else if (status == 'banned' || status == 'deleted' || status == 'unauthorized') {
        final String reasonMsg = (status == 'banned')
            ? TxaLanguage.t('account_banned_msg')
            : ((status == 'deleted')
                ? TxaLanguage.t('account_invalid_or_deleted')
                : TxaLanguage.t('session_expired'));

        TxaLogger.log('Tài khoản không hợp lệ (Status: $status). Tự động đăng xuất!', type: 'auth');
        await logout(onShowToast: onShowToast, reasonMessage: reasonMsg);
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
              final activeIcon = prefs.getString('txa_active_app_icon') ?? 'icon_default.png';
              await TxaPersistentAuthVault.saveSession(
                token: _token!,
                user: _user!,
                activeAppIcon: activeIcon,
              );
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

  Future<Map<String, dynamic>> loginWithGoogle({
    String? idToken,
    String? accessToken,
    String? email,
    String? displayName,
  }) async {
    try {
      final response = await TxaApi().googleLogin(
        credential: idToken,
        accessToken: accessToken,
        email: email,
        displayName: displayName,
      );
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
      final activeIcon = prefs.getString('txa_active_app_icon') ?? 'icon_default.png';
      await TxaPersistentAuthVault.saveSession(
        token: _token!,
        user: _user!,
        activeAppIcon: activeIcon,
      );
    }
    TxaApi.clearCache();
    TxaLogger.log('Auth session manually set for ${userData['username'] ?? userData['email']}', type: 'auth');
    notifyListeners();
  }

  /// Update a single field in the user object and persist to SharedPreferences & Hardware Vault
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
    SharedPreferences.getInstance().then((prefs) async {
      await prefs.setString('txa_auth_user', jsonEncode(_user));
      if (_token != null && _user != null) {
        final activeIcon = prefs.getString('txa_active_app_icon') ?? 'icon_default.png';
        await TxaPersistentAuthVault.saveSession(
          token: _token!,
          user: _user!,
          activeAppIcon: activeIcon,
        );
      }
    });
    notifyListeners();
  }

  Future<void> logout({void Function(String msg, {bool isError})? onShowToast, String? reasonMessage}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('txa_auth_token');
      await prefs.remove('txa_auth_user');
      await TxaPersistentAuthVault.clearVault();
      _token = null;
      _user = null;
      TxaApi.clearCache();
      TxaLogger.log('Logged out successfully', type: 'auth');
      notifyListeners();

      if (reasonMessage != null && reasonMessage.isNotEmpty) {
        onShowToast?.call(reasonMessage, isError: true);
      }
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
