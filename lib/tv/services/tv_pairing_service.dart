import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../services/txa_api.dart';
import '../../services/txa_auth_service.dart';
import 'tv_device_service.dart';

class TvPairingService {
  static final TvPairingService _instance = TvPairingService._internal();
  factory TvPairingService() => _instance;
  TvPairingService._internal();

  Timer? _pollTimer;

  /// Generates code pairing session
  Future<Map<String, dynamic>?> generateCode() async {
    final deviceId = TvDeviceService().deviceId;
    if (deviceId == null) return null;

    final url = Uri.parse('${TxaApi.baseUrl}/api/app/tv-pair');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-TXA-API-KEY': TxaApi.apiKey,
        },
        body: jsonEncode({
          'action': 'generate_code',
          'device_id': deviceId,
          'location_info': TvDeviceService().locationInfo,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          return data['data'] as Map<String, dynamic>?;
        }
      }
    } catch (e) {
      debugPrint('Error generating pairing code: $e');
    }
    return null;
  }

  /// Generates QR pairing session
  Future<Map<String, dynamic>?> generateQr() async {
    final deviceId = TvDeviceService().deviceId;
    if (deviceId == null) return null;

    final url = Uri.parse('${TxaApi.baseUrl}/api/app/tv-pair');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-TXA-API-KEY': TxaApi.apiKey,
        },
        body: jsonEncode({
          'action': 'generate_qr',
          'device_id': deviceId,
          'location_info': TvDeviceService().locationInfo,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          return data['data'] as Map<String, dynamic>?;
        }
      }
    } catch (e) {
      debugPrint('Error generating QR pairing session: $e');
    }
    return null;
  }

  /// Start polling status of pairing sessions every 3s
  void startPolling({
    required List<String> sessionIds,
    required Function(Map<String, dynamic> session) onUpdate,
    required Function() onConfirmed,
    required Function(String reason) onFailed,
  }) {
    _pollTimer?.cancel();
    
    final activeSessionIds = List<String>.from(sessionIds);
    
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      final sessionsToCheck = List<String>.from(activeSessionIds);
      if (sessionsToCheck.isEmpty) {
        timer.cancel();
        _pollTimer = null;
        return;
      }

      for (final sessionId in sessionsToCheck) {
        if (_pollTimer == null || !timer.isActive) return;
        if (!activeSessionIds.contains(sessionId)) continue;

        final url = Uri.parse('${TxaApi.baseUrl}/api/app/tv-pair?action=check_status&session_id=$sessionId');
        try {
          final response = await http.get(
            url,
            headers: {
              'X-TXA-API-KEY': TxaApi.apiKey,
            },
          );

          if (response.statusCode == 200) {
            final body = jsonDecode(utf8.decode(response.bodyBytes));
            if (body['success'] == true) {
              final session = body['data'] as Map<String, dynamic>;
              onUpdate(session);

              final status = session['status'];
              if (status == 'confirmed') {
                timer.cancel();
                _pollTimer = null;
                
                // Handle login state in TxaAuthService
                final userInfo = session['user_info'] as Map<String, dynamic>;
                final token = userInfo['access_token'] as String;

                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('txa_auth_token', token);
                await prefs.setString('txa_auth_user', jsonEncode(userInfo));

                // Re-initialize local Auth Service
                await TxaAuthService().initialize();
                onConfirmed();
                break;
              } else if (status == 'rejected') {
                activeSessionIds.remove(sessionId);
                if (activeSessionIds.isEmpty) {
                  timer.cancel();
                  _pollTimer = null;
                  onFailed('Yêu cầu kết nối bị từ chối từ điện thoại!');
                }
                break;
              } else if (status == 'expired') {
                activeSessionIds.remove(sessionId);
                debugPrint('Session $sessionId expired on backend, stopped polling.');
                break;
              }
            }
          }
        } catch (e) {
          debugPrint('Polling pairing session error: $e');
        }
      }
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Unpair TV from user account
  Future<bool> unpair() async {
    final deviceId = TvDeviceService().deviceId;
    if (deviceId == null) return false;

    final url = Uri.parse('${TxaApi.baseUrl}/api/app/tv-pair');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-TXA-API-KEY': TxaApi.apiKey,
        },
        body: jsonEncode({
          'action': 'unpair',
          'device_id': deviceId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          await TxaAuthService().logout();
          return true;
        }
      }
    } catch (e) {
      debugPrint('Error unpairing TV: $e');
    }
    return false;
  }
}

