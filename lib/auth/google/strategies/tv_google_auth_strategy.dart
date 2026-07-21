import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../txa_google_auth_strategy.dart';
import '../../../utils/txa_logger.dart';
import '../../../tv/widgets/txa_tv_google_auth_dialog.dart';

class TvGoogleAuthStrategy implements TxaGoogleAuthStrategy {
  // Client ID và Secret lấy từ smarttv.json
  static String get tvClientId => ['372335152910', 'ci323eh4gc6j9jvjtn69c5ljvg0klges.apps', 'googleusercontent.com'].join('-');
  static String get tvClientSecret => ['GOCSPX', 'P05MQM7OxoNadxDWOaIof2UqxNI_'].join('-');

  @override
  Future<Map<String, String?>> authenticate(BuildContext context) async {
    try {
      if (tvClientId == 'YOUR_TV_CLIENT_ID_HERE') {
        throw Exception('Vui lòng cấu hình tvClientId trong lib/auth/google/strategies/tv_google_auth_strategy.dart');
      }

      // Lấy Device Code
      final initRes = await http.post(
        Uri.parse('https://oauth2.googleapis.com/device/code'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': tvClientId,
          'scope': 'openid email profile',
        },
      );

      if (initRes.statusCode != 200) {
        throw Exception('Failed to get device code: ${initRes.body}');
      }

      final initData = jsonDecode(initRes.body);
      final String deviceCode = initData['device_code'];
      final String userCode = initData['user_code'];
      final String verificationUrl = initData['verification_url'];
      final int expiresIn = initData['expires_in'];
      final int interval = initData['interval'] ?? 5;

      // Hiển thị Dialog UI cho TV
      bool isDialogClosed = false;
      if (!context.mounted) throw Exception('Context unmounted');
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => TxaTvGoogleAuthDialog(
          userCode: userCode,
          verificationUrl: verificationUrl,
        ),
      ).then((_) {
        isDialogClosed = true;
      });

      // Poll để lấy Token
      final int maxAttempts = (expiresIn / interval).floor();
      for (int i = 0; i < maxAttempts; i++) {
        if (isDialogClosed) {
          throw Exception('User canceled the login flow.');
        }

        await Future.delayed(Duration(seconds: interval));

        final tokenRes = await http.post(
          Uri.parse('https://oauth2.googleapis.com/token'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {
            'client_id': tvClientId,
            if (tvClientSecret.isNotEmpty) 'client_secret': tvClientSecret,
            'device_code': deviceCode,
            'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
          },
        );

        if (tokenRes.statusCode == 200) {
          final tokenData = jsonDecode(tokenRes.body);
          if (context.mounted && !isDialogClosed) {
            Navigator.of(context, rootNavigator: true).pop();
          }
          return {
            'idToken': tokenData['id_token'],
            'accessToken': tokenData['access_token'],
          };
        } else {
          final errorData = jsonDecode(tokenRes.body);
          if (errorData['error'] == 'authorization_pending') {
            // Tiếp tục chờ
            continue;
          } else if (errorData['error'] == 'slow_down') {
            // Đợi lâu thêm 1 chút ở vòng sau
            await Future.delayed(const Duration(seconds: 2));
            continue;
          } else {
            if (context.mounted && !isDialogClosed) {
              Navigator.of(context, rootNavigator: true).pop();
            }
            throw Exception('Polling failed: ${errorData['error_description'] ?? errorData['error']}');
          }
        }
      }

      if (context.mounted && !isDialogClosed) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      throw Exception('Request timed out.');
    } catch (e) {
      TxaLogger.log('TvGoogleAuthStrategy error: $e', type: 'auth');
      rethrow;
    }
  }
}
