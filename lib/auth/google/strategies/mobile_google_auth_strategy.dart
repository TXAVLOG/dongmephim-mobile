import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../txa_google_auth_strategy.dart';
import '../../../utils/txa_logger.dart';

class MobileGoogleAuthStrategy implements TxaGoogleAuthStrategy {
  // Web Client ID dùng để Backend xác thực idToken từ Mobile (Android & iOS)
  static final String _webClientId = '372335152910-jooebl1a7pln9jh6alhf7r0pu1gk7s5e' + '.apps.googleusercontent.com';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: _webClientId,
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
        throw Exception('User canceled the login flow.');
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      return {
        'idToken': auth.idToken,
        'accessToken': auth.accessToken,
      };
    } catch (e) {
      TxaLogger.log('MobileGoogleAuthStrategy error: $e', type: 'auth');
      rethrow;
    }
  }
}
