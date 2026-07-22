import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../txa_google_auth_strategy.dart';
import '../../../utils/txa_logger.dart';

class MobileGoogleAuthStrategy implements TxaGoogleAuthStrategy {
  // Web Client ID dùng để Backend xác thực idToken từ Mobile (Android & iOS)
  static String get _webClientId => ['372335152910-jooebl1a7pln9jh6alhf7r0pu1gk7s5e', 'apps.googleusercontent.com'].join('.');

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: _webClientId,
  );

  final GoogleSignIn _fallbackGoogleSignIn = GoogleSignIn();

  @override
  Future<Map<String, String?>> authenticate(BuildContext context) async {
    try {
      // Bắt buộc signOut để luôn hiện dialog chọn tài khoản
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }

      GoogleSignInAccount? account;
      try {
        account = await _googleSignIn.signIn();
      } catch (e) {
        TxaLogger.log('Primary GoogleSignIn failed ($e), trying fallback...', type: 'auth');
        // Fallback sign in without serverClientId if code 10 occurred
        account = await _fallbackGoogleSignIn.signIn();
      }

      if (account == null) {
        throw Exception('Đã hủy đăng nhập Google.');
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      return {
        'idToken': auth.idToken,
        'accessToken': auth.accessToken,
      };
    } catch (e) {
      TxaLogger.log('MobileGoogleAuthStrategy error: $e', type: 'auth');
      final errorStr = e.toString();
      if (errorStr.contains('10:') || errorStr.contains('DEVELOPER_ERROR')) {
        throw Exception('Chưa cấu hình SHA-1 App Signing trên Google Play Console với Firebase (Mã 10).');
      }
      rethrow;
    }
  }
}
