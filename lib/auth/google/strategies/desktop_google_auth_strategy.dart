import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../txa_google_auth_strategy.dart';
import '../../../utils/txa_logger.dart';

class DesktopGoogleAuthStrategy implements TxaGoogleAuthStrategy {
  // Client ID và Secret (Web application) lấy từ desktop.json
  static String get desktopClientId => '372335152910-jooebl1a7pln9jh6alhf7r0pu1gk7s5e' + '.apps.googleusercontent.com';
  static String get desktopClientSecret => 'GOCSPX-' + 'TYRhMyHexG_f7HerFaN5ZStXbe_C'; 

  @override
  Future<Map<String, String?>> authenticate(BuildContext context) async {
    HttpServer? server;
    try {
      if (desktopClientId == 'YOUR_DESKTOP_CLIENT_ID_HERE') {
        throw Exception('Vui lòng cấu hình desktopClientId trong lib/auth/google/strategies/desktop_google_auth_strategy.dart');
      }

      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final redirectUri = 'http://127.0.0.1:${server.port}/callback';
      
      // Tạo PKCE
      final codeVerifier = _generateCodeVerifier();
      final codeChallenge = _generateCodeChallenge(codeVerifier);

      final authUrl = Uri.parse('https://accounts.google.com/o/oauth2/v2/auth').replace(queryParameters: {
        'client_id': desktopClientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': 'openid email profile',
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
        'access_type': 'offline',
      });

      if (!await launchUrl(authUrl)) {
        throw Exception('Không thể mở trình duyệt');
      }

      // Đợi phản hồi từ browser
      final request = await server.first;
      final uri = request.uri;
      final code = uri.queryParameters['code'];
      final error = uri.queryParameters['error'];

      if (error != null || code == null) {
        _respondWithHtml(request, false, error ?? 'No code provided');
        throw Exception(error ?? 'Login failed or canceled');
      }

      // Trả HTML thành công
      _respondWithHtml(request, true, null);

      // Đổi code lấy token
      final tokenRes = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': desktopClientId,
          if (desktopClientSecret.isNotEmpty) 'client_secret': desktopClientSecret,
          'code': code,
          'code_verifier': codeVerifier,
          'grant_type': 'authorization_code',
          'redirect_uri': redirectUri,
        },
      );

      if (tokenRes.statusCode == 200) {
        final data = jsonDecode(tokenRes.body);
        return {
          'idToken': data['id_token'],
          'accessToken': data['access_token'],
        };
      } else {
        throw Exception('Failed to exchange token: ${tokenRes.body}');
      }
    } catch (e) {
      TxaLogger.log('DesktopGoogleAuthStrategy error: $e', type: 'auth');
      rethrow;
    } finally {
      await server?.close(force: true);
    }
  }

  void _respondWithHtml(HttpRequest request, bool isSuccess, String? errorMsg) {
    request.response.headers.contentType = ContentType.html;
    final html = '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <title>Google Đăng nhập</title>
        <style>
          body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #0F111E; color: #fff; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
          .card { background: #1A1D2D; padding: 40px; border-radius: 16px; text-align: center; box-shadow: 0 10px 30px rgba(0,0,0,0.5); max-width: 400px; width: 90%; }
          .icon { font-size: 64px; margin-bottom: 20px; }
          .success { color: #4CAF50; }
          .error { color: #F44336; }
          h2 { margin: 0 0 10px; }
          p { color: #aaa; line-height: 1.5; margin-bottom: 24px; }
          a.btn { display: inline-block; background: #3b82f6; color: white; text-decoration: none; padding: 12px 24px; border-radius: 8px; font-weight: bold; transition: 0.3s; }
          a.btn:hover { background: #2563eb; }
        </style>
      </head>
      <body>
        <div class="card">
          <div class="icon ${isSuccess ? 'success' : 'error'}">
            ${isSuccess ? '✓' : '✗'}
          </div>
          <h2>${isSuccess ? 'Đăng nhập thành công!' : 'Đăng nhập thất bại'}</h2>
          <p>${isSuccess ? 'Bạn có thể đóng tab này và quay lại ứng dụng.' : (errorMsg ?? 'Vui lòng thử lại.')}</p>
          <a href="dongmephim://auth-callback" class="btn">Mở lại Ứng dụng</a>
        </div>
        <script>
          setTimeout(function() {
            window.location.href = "dongmephim://auth-callback";
          }, 1000);
        </script>
      </body>
      </html>
    ''';
    request.response.write(html);
    request.response.close();
  }

  String _generateCodeVerifier() {
    // Độ dài lý tưởng là 43-128
    return 'txa_google_auth_verifier_string_which_is_long_enough_for_pkce';
  }

  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }
}
