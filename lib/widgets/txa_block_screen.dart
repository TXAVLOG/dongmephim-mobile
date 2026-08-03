import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/txa_language.dart';
import '../services/txa_settings_cache.dart';

/// Màn hình chặn toàn bộ khi device bị admin block.
/// Hiển thị lý do block + nút liên hệ thực từ social settings admin.
class TxaBlockScreen extends StatelessWidget {
  final String? reason;

  const TxaBlockScreen({super.key, this.reason});

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
                  // Icon cảnh báo
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        const Color(0xFFFF3B30).withOpacity(0.25),
                        const Color(0xFFFF3B30).withOpacity(0.05),
                      ]),
                      border: Border.all(
                        color: const Color(0xFFFF3B30).withOpacity(0.6),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.block_rounded,
                      color: Color(0xFFFF3B30),
                      size: 48,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Tiêu đề
                  Text(
                    TxaLanguage.t('device_blocked_title'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 12),

                  // Mô tả chung
                  Text(
                    TxaLanguage.t('device_blocked_desc'),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 14,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  // Lý do block (nếu có)
                  if (reason != null && reason!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFFF3B30).withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded,
                              color: const Color(0xFFFF3B30).withOpacity(0.7),
                              size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              reason!,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 13,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // Nút liên hệ từ social settings
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.support_agent_rounded,
                                size: 16, color: Colors.white.withOpacity(0.5)),
                            const SizedBox(width: 6),
                            Text(
                              TxaLanguage.t('device_blocked_contact'),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                        if (contacts.isNotEmpty) ...[
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
                      ],
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
}

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
            Icon(_iconData(iconName), size: 15, color: const Color(0xFFFF3B30)),
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
