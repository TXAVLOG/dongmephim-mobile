import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/txa_auth_service.dart';
import '../services/txa_language.dart';
import '../services/txa_settings_cache.dart';
import '../utils/txa_navigator.dart';
import '../utils/txa_toast.dart';

/// Màn hình chặn toàn bộ khi tài khoản bị admin ban/khóa.
/// Hiển thị 2 nút: Đăng Xuất và Thoát Ứng Dụng + nút liên hệ từ social settings admin.
class TxaAccountBannedScreen extends StatelessWidget {
  const TxaAccountBannedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final contacts = TxaSettingsCache().contactChannels;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0F),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon khóa
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        const Color(0xFFFF9500).withOpacity(0.25),
                        const Color(0xFFFF9500).withOpacity(0.05),
                      ]),
                      border: Border.all(
                        color: const Color(0xFFFF9500).withOpacity(0.6),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.lock_person_rounded,
                      color: Color(0xFFFF9500),
                      size: 50,
                    ),
                  ),

                  const SizedBox(height: 28),

                  Text(
                    TxaLanguage.t('account_banned_screen_title'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 12),

                  Text(
                    TxaLanguage.t('account_banned_screen_desc'),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 14,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 28),

                  // Nút liên hệ từ social settings
                  if (contacts.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9500).withOpacity(0.07),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFFF9500).withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.support_agent_rounded,
                                  color: const Color(0xFFFF9500).withOpacity(0.8),
                                  size: 18),
                              const SizedBox(width: 8),
                              Text(
                                TxaLanguage.t('account_banned_screen_contact'),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: contacts.map((c) => _ContactChip(
                              label: c.label,
                              iconName: c.icon,
                              url: c.url,
                            )).toList(),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Fallback nếu chưa có social settings
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9500).withOpacity(0.07),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFFF9500).withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.support_agent_rounded,
                              color: const Color(0xFFFF9500).withOpacity(0.8),
                              size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              TxaLanguage.t('account_banned_screen_contact'),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // Nút Đăng Xuất
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _doLogout(context),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: Text(TxaLanguage.t('account_banned_screen_logout')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF9500),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Nút Thoát App
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _exitApp,
                      icon: Icon(Icons.exit_to_app_rounded,
                          size: 18, color: Colors.white.withOpacity(0.6)),
                      label: Text(
                        TxaLanguage.t('account_banned_screen_exit'),
                        style: TextStyle(color: Colors.white.withOpacity(0.6)),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide(color: Colors.white.withOpacity(0.15)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _doLogout(BuildContext context) async {
    await TxaAuthService().logout(
      onShowToast: (msg, {bool isError = false}) {
        final ctx = navigatorKey.currentContext;
        if (ctx != null) TxaToast.show(ctx, msg, isError: isError);
      },
    );
    final ctx = navigatorKey.currentContext;
    if (ctx != null) {
      Navigator.of(ctx).pushNamedAndRemoveUntil('/', (_) => false);
    }
  }

  void _exitApp() {
    try {
      if (Platform.isAndroid) {
        SystemNavigator.pop();
      } else {
        exit(0);
      }
    } catch (_) {
      SystemNavigator.pop();
    }
  }
}

/// Chip nhỏ hiển thị kênh liên hệ với icon và tên
class _ContactChip extends StatelessWidget {
  final String label;
  final String iconName;
  final String url;

  const _ContactChip({
    required this.label,
    required this.iconName,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.tryParse(url);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconData(iconName), size: 15, color: const Color(0xFFFF9500)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconData(String name) {
    switch (name) {
      case 'send': return Icons.send_rounded;
      case 'public': return Icons.public_rounded;
      case 'group': return Icons.group_rounded;
      case 'chat_bubble': return Icons.chat_bubble_rounded;
      case 'headset_mic': return Icons.headset_mic_rounded;
      default: return Icons.open_in_new_rounded;
    }
  }
}
