import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../txa_google_auth_strategy.dart';
import '../../../services/txa_language.dart';
import '../../../utils/txa_logger.dart';

class MobileGoogleAuthStrategy implements TxaGoogleAuthStrategy {
  // Web Client ID dùng để Backend xác thực idToken từ Mobile (Android & iOS)
  static String get _webClientId => ['372335152910-jooebl1a7pln9jh6alhf7r0pu1gk7s5e', 'apps.googleusercontent.com'].join('.');

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: _webClientId,
    scopes: ['email', 'profile'],
  );

  @override
  Future<Map<String, String?>> authenticate(BuildContext context) async {
    try {
      // Bắt buộc signOut để luôn hiện dialog chọn tài khoản
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }

      final GoogleSignInAccount? account = await _googleSignIn.signIn();

      if (account == null) {
        throw Exception(TxaLanguage.t('google_login_canceled'));
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      final idToken = auth.idToken;
      final accessToken = auth.accessToken;

      TxaLogger.log('Mobile Google Auth: email=${account.email}, hasIdToken=${idToken != null && idToken.isNotEmpty}', type: 'auth');

      return {
        'idToken': idToken,
        'accessToken': accessToken,
        'email': account.email,
        'displayName': account.displayName,
        'photoUrl': account.photoUrl,
      };
    } catch (e) {
      TxaLogger.log('MobileGoogleAuthStrategy error: $e', type: 'auth');
      final errorStr = e.toString();
      if (errorStr.contains('10:') || errorStr.contains('DEVELOPER_ERROR')) {
        throw Exception(TxaLanguage.t('google_sha1_missing_err'));
      }
      rethrow;
    }
  }
}
