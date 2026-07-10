import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/txa_theme.dart';
import '../services/txa_api.dart';
import '../services/txa_auth_service.dart';
import '../utils/txa_toast.dart';
import '../services/txa_language.dart';

class TxaTvConfirmScreen extends StatefulWidget {
  final String sessionId;
  final Map<String, dynamic> tvDevice;

  const TxaTvConfirmScreen({
    super.key,
    required this.sessionId,
    required this.tvDevice,
  });

  @override
  State<TxaTvConfirmScreen> createState() => _TxaTvConfirmScreenState();
}

class _TxaTvConfirmScreenState extends State<TxaTvConfirmScreen> {
  bool _isLoading = false;

  Future<void> _onConfirm() async {
    setState(() {
      _isLoading = true;
    });

    final token = TxaAuthService().token;
    final url = Uri.parse('${TxaApi.baseUrl}/api/app/tv-pair');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-TXA-API-KEY': TxaApi.apiKey,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'action': 'confirm_pair',
          'session_id': widget.sessionId,
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (body['success'] == true) {
          if (mounted) {
            TxaToast.show(context, TxaLanguage.t('pairing_success'));
            Navigator.pop(context);
          }
          return;
        }
      }
      if (mounted) {
        TxaToast.show(context, TxaLanguage.t('pairing_confirm_error'), isError: true);
      }
    } catch (e) {
      if (mounted) {
        TxaToast.show(context, TxaLanguage.t('conn_error', replace: {'error': e.toString()}), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onReject() async {
    setState(() {
      _isLoading = true;
    });

    final token = TxaAuthService().token;
    final url = Uri.parse('${TxaApi.baseUrl}/api/app/tv-pair');
    try {
      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-TXA-API-KEY': TxaApi.apiKey,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'action': 'reject_pair',
          'session_id': widget.sessionId,
        }),
      );

      if (mounted) {
        TxaToast.show(context, TxaLanguage.t('pairing_rejected'));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        TxaToast.show(context, TxaLanguage.t('conn_error', replace: {'error': e.toString()}), isError: true);
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final devName = widget.tvDevice['device_name'] ?? 'Smart TV';
    final devModel = widget.tvDevice['device_model'] ?? 'Unknown Model';
    final ipAddress = widget.tvDevice['ip_address'] ?? '127.0.0.1';
    final devOs = widget.tvDevice['device_os'] ?? 'Android TV';

    final locationInfo = widget.tvDevice['location_info'] as Map<String, dynamic>?;
    final city = locationInfo?['city'] ?? '';
    final country = locationInfo?['country'] ?? '';
    final org = locationInfo?['org'] ?? '';
    final locationStr = city.isNotEmpty ? "$city, $country" : '';

    final user = TxaAuthService().user;

    return Scaffold(
      backgroundColor: TxaTheme.primaryBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: _onReject,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              padding: const EdgeInsets.all(28.0),
              decoration: BoxDecoration(
                color: TxaTheme.secondaryBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // TV Icon
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: TxaTheme.accent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.tv_rounded, color: TxaTheme.accent, size: 36),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    TxaLanguage.t('tv_confirm_login_title'),
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  Text(
                    TxaLanguage.t('tv_confirm_login_desc'),
                    style: const TextStyle(color: TxaTheme.textSecondary, fontSize: 13, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),

                  // TV Details Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          TxaLanguage.t('tv_device_info_title'),
                          style: const TextStyle(color: TxaTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow(TxaLanguage.t('tv_device_name_label'), devName),
                        _buildDetailRow(TxaLanguage.t('tv_device_os_label'), devOs),
                        _buildDetailRow(TxaLanguage.t('tv_device_model_label'), devModel),
                        _buildDetailRow(TxaLanguage.t('tv_device_ip_label'), ipAddress),
                        if (locationStr.isNotEmpty)
                          _buildDetailRow(TxaLanguage.t('tv_device_location_label'), locationStr),
                        if (org.isNotEmpty)
                          _buildDetailRow(TxaLanguage.t('tv_device_isp_label'), org),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // User Account Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: TxaTheme.accent.withValues(alpha: 0.1),
                          backgroundImage: user?['avatar_url'] != null ? NetworkImage(user!['avatar_url']) : null,
                          child: user?['avatar_url'] == null
                              ? const Icon(Icons.person_rounded, color: TxaTheme.accent)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?['name'] ?? 'Tài khoản',
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user?['email'] ?? '',
                                style: const TextStyle(color: TxaTheme.textSecondary, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Actions
                  if (_isLoading)
                    const CircularProgressIndicator(color: TxaTheme.accent)
                  else
                    Column(
                      children: [
                        ElevatedButton(
                          onPressed: _onConfirm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TxaTheme.accent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            minimumSize: const Size(double.infinity, 0),
                          ),
                          child: Text(TxaLanguage.t('agree_login_tv'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _onReject,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            minimumSize: const Size(double.infinity, 0),
                          ),
                          child: Text(TxaLanguage.t('reject_btn'), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ],
                    )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: TxaTheme.textSecondary, fontSize: 12.5)),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

