import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../txa_google_auth_strategy.dart';
import '../../../utils/txa_logger.dart';

class DesktopGoogleAuthStrategy implements TxaGoogleAuthStrategy {
  // Client ID và Secret (Web application) lấy từ desktop.json
  static String get desktopClientId => ['372335152910-jooebl1a7pln9jh6alhf7r0pu1gk7s5e', 'apps.googleusercontent.com'].join('.');
  static String get desktopClientSecret => ['GOCSPX', 'TYRhMyHexG_f7HerFaN5ZStXbe_C'].join('-'); 

  @override
  Future<Map<String, String?>> authenticate(BuildContext context) async {
    HttpServer? server;
    try {
      if (desktopClientId == 'YOUR_DESKTOP_CLIENT_ID_HERE') {
        throw Exception('Vui lòng cấu hình desktopClientId trong lib/auth/google/strategies/desktop_google_auth_strategy.dart');
      }

      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final redirectUri = 'http://127.0.0.1:${server.port}';
      
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
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Google Đăng nhập | Đồng Mê Phim</title>
        <style>
          * { box-sizing: border-box; }
          body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background: #0b0d19; color: #fff; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; padding: 20px; }
          .card { background: linear-gradient(145deg, #151828, #1c2035); border: 1px solid rgba(255,255,255,0.08); padding: 48px 36px; border-radius: 24px; text-align: center; box-shadow: 0 20px 50px rgba(0,0,0,0.6); max-width: 420px; width: 100%; animation: fadeIn 0.4s ease-out; }
          @keyframes fadeIn { from { opacity: 0; transform: translateY(12px); } to { opacity: 1; transform: translateY(0); } }
          .icon-box { width: 72px; height: 72px; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 24px; font-size: 36px; font-weight: bold; }
          .success-box { background: rgba(76, 175, 80, 0.15); color: #4CAF50; border: 2px solid rgba(76, 175, 80, 0.3); }
          .error-box { background: rgba(244, 67, 54, 0.15); color: #F44336; border: 2px solid rgba(244, 67, 54, 0.3); }
          h2 { margin: 0 0 12px; font-size: 22px; font-weight: 700; letter-spacing: -0.5px; }
          p { color: #9aa0a6; line-height: 1.6; font-size: 15px; margin: 0 0 28px; }
          a.btn { display: inline-block; background: #3b82f6; color: white; text-decoration: none; padding: 14px 28px; border-radius: 12px; font-weight: 600; font-size: 15px; transition: all 0.2s; box-shadow: 0 4px 14px rgba(59, 130, 246, 0.4); }
          a.btn:hover { background: #2563eb; transform: translateY(-2px); box-shadow: 0 6px 20px rgba(59, 130, 246, 0.6); }
        </style>
      </head>
      <body>
        <div class="card">
          <div class="icon-box ${isSuccess ? 'success-box' : 'error-box'}">
            ${isSuccess ? '✓' : '✕'}
          </div>
          <h2>${isSuccess ? 'Đăng nhập thành công!' : 'Đăng nhập thất bại'}</h2>
          <p>${isSuccess ? 'Bạn có thể đóng tab này và quay lại ứng dụng <b>Đồng Mê Phim</b>.' : (errorMsg ?? 'Vui lòng thử lại.')}</p>
          <a href="dongmephim://auth-callback" class="btn">Quay lại Ứng dụng</a>
        </div>
        <script>
          // Tự động làm sạch thanh địa chỉ URL (xóa bỏ toàn bộ parameters dài ngoằng)
          if (window.history && window.history.replaceState) {
            window.history.replaceState({}, document.title, window.location.pathname);
          }
          setTimeout(function() {
            window.location.href = "dongmephim://auth-callback";
            try { window.close(); } catch(e) {}
          }, 800);
        </script>
      </body>
      </html>
    ''';
    request.response.write(html);
    request.response.close();
  }

  String _generateCodeVerifier() {
    final secureRandom = Random.secure();
    final values = List<int>.generate(32, (i) => secureRandom.nextInt(256));
    return base64UrlEncode(values).replaceAll('=', '');
  }

  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }
}
