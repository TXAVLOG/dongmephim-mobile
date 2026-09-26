import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/txa_download_manager.dart';
import '../../../../theme/txa_theme.dart';
import '../../../../services/txa_language.dart';

class TxaDownloadSettingsModal extends StatefulWidget {
  const TxaDownloadSettingsModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const TxaDownloadSettingsModal(),
    );
  }

  @override
  State<TxaDownloadSettingsModal> createState() => _TxaDownloadSettingsModalState();
}

class _TxaDownloadSettingsModalState extends State<TxaDownloadSettingsModal> {
  int _threads = 12;
  int _concurrent = 2;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final manager = Provider.of<TxaDownloadManager>(context, listen: false);
    final threads = await manager.getDownloadThreads();
    final concurrent = await manager.getMaxConcurrentDownloads();
    if (mounted) {
      setState(() {
        _threads = threads;
        _concurrent = concurrent;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<TxaDownloadManager>(context);
    final isVip = manager.hasPaidPackage;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 20),
      decoration: BoxDecoration(
        color: TxaTheme.primaryBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: TxaTheme.glassBorder),
      ),
      child: _isLoading
          ? const SizedBox(
              height: 250,
              child: Center(child: CircularProgressIndicator(color: TxaTheme.accent)),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: TxaTheme.accent.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.speed_rounded, color: TxaTheme.accent, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          TxaLanguage.t('download_settings'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white60),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // VIP Status Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isVip
                          ? [
                              const Color(0xFFD4AF37).withValues(alpha: 0.25),
                              TxaTheme.cardBg,
                            ]
                          : [
                              Colors.white.withValues(alpha: 0.05),
                              TxaTheme.cardBg,
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isVip
                          ? const Color(0xFFD4AF37).withValues(alpha: 0.4)
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isVip ? Icons.workspace_premium_rounded : Icons.info_outline_rounded,
                        color: isVip ? const Color(0xFFFFD700) : Colors.white60,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isVip
                                  ? TxaLanguage.t('vip_boost_active')
                                  : TxaLanguage.t('free_guest_account'),
                              style: TextStyle(
                                color: isVip ? const Color(0xFFFFD700) : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              isVip
                                  ? TxaLanguage.t('vip_boost_desc')
                                  : TxaLanguage.t('vip_feature_notice'),
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Setting 1: Thread Concurrency Slider
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          TxaLanguage.t('download_threads'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          TxaLanguage.t('download_threads_desc'),
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: TxaTheme.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isVip
                            ? TxaLanguage.t('threads_count', replace: {'n': '$_threads'})
                            : TxaLanguage.t('default_threads'),
                        style: const TextStyle(
                          color: TxaTheme.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: isVip ? TxaTheme.accent : Colors.white24,
                    inactiveTrackColor: Colors.white12,
                    thumbColor: isVip ? TxaTheme.accent : Colors.white38,
                    overlayColor: TxaTheme.accent.withValues(alpha: 0.15),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: isVip ? _threads.toDouble() : 4.0,
                    min: 4.0,
                    max: 20.0,
                    divisions: 8,
                    onChanged: isVip
                        ? (val) {
                            setState(() => _threads = val.round());
                            manager.setDownloadThreads(_threads);
                          }
                        : null,
                  ),
                ),
                const SizedBox(height: 12),

                // Setting 2: Concurrent Episodes
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: TxaTheme.cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  TxaLanguage.t('concurrent_downloads'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (!isVip) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'VIP',
                                      style: TextStyle(
                                        color: Color(0xFFFFD700),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isVip
                                  ? (_concurrent >= 2 ? TxaLanguage.t('concurrent_dual_desc') : TxaLanguage.t('concurrent_single_desc'))
                                  : TxaLanguage.t('free_concurrent_desc'),
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: isVip ? _concurrent >= 2 : false,
                        activeTrackColor: TxaTheme.accent,
                        activeThumbColor: Colors.black,
                        onChanged: isVip
                            ? (val) {
                                final newVal = val ? 2 : 1;
                                setState(() => _concurrent = newVal);
                                manager.setMaxConcurrentDownloads(newVal);
                              }
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Android Sandbox / Scoped storage notice
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.folder_special_rounded, color: Colors.white38, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          TxaLanguage.t('scoped_storage_notice'),
                          style: const TextStyle(color: Colors.white38, fontSize: 11, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Close Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TxaTheme.accent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: Text(
                      TxaLanguage.t('done'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
