import 'package:flutter/material.dart';
import '../../../services/txa_ad_free_service.dart';
import '../../../services/txa_ads_service.dart';
import '../../../services/txa_language.dart';

class TxaAdFreeCard extends StatelessWidget {
  final VoidCallback? onActivated;

  const TxaAdFreeCard({super.key, this.onActivated});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: TxaAdFreeService.instance,
      builder: (context, _) {
        final adFreeService = TxaAdFreeService.instance;
        final isActive = adFreeService.isAdFreeActive;
        final watched = adFreeService.watchedCount;
        final required = adFreeService.requiredAds;
        final durationHours = TxaAdsService.instance.adFreeConfig.durationHours;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: isActive
                  ? [
                      const Color(0xFF1E1B4B).withValues(alpha: 0.85),
                      const Color(0xFF312E81).withValues(alpha: 0.65),
                    ]
                  : [
                      const Color(0xFF0F172A).withValues(alpha: 0.85),
                      const Color(0xFF1E1B4B).withValues(alpha: 0.55),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: isActive
                  ? const Color(0xFFA78BFA).withValues(alpha: 0.5)
                  : const Color(0xFFA78BFA).withValues(alpha: 0.2),
              width: isActive ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFA78BFA).withValues(alpha: isActive ? 0.15 : 0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFA78BFA).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFA78BFA).withValues(alpha: 0.3)),
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: Color(0xFFA78BFA),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          TxaLanguage.get('ad_free_title'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isActive
                              ? TxaLanguage.get('ad_free_badge_remaining', params: {'time': adFreeService.remainingTimeString})
                              : TxaLanguage.get('ad_free_desc', params: {
                                  'required': required.toString(),
                                  'hours': durationHours.toString(),
                                }),
                          style: TextStyle(
                            color: isActive ? const Color(0xFFA78BFA) : const Color(0xFF94A3B8),
                            fontSize: 12,
                            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Progress indicator & Watch Ad Button
              if (!isActive) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: required > 0 ? watched / required : 0.0,
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFA78BFA)),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () {
                      adFreeService.watchAd(
                        context: context,
                        onSuccess: () {
                          if (adFreeService.isAdFreeActive) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(TxaLanguage.get('ad_free_activated_toast')),
                                backgroundColor: const Color(0xFF7C3AED),
                              ),
                            );
                            onActivated?.call();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(TxaLanguage.get('ad_free_progress_toast', params: {
                                  'current': adFreeService.watchedCount.toString(),
                                  'required': required.toString(),
                                })),
                                backgroundColor: const Color(0xFF4F46E5),
                              ),
                            );
                          }
                        },
                        onError: (err) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(err),
                              backgroundColor: const Color(0xFFDC2626),
                            ),
                          );
                        },
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA78BFA),
                      foregroundColor: const Color(0xFF0F172A),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      TxaLanguage.get('ad_free_btn_watch', params: {
                        'current': watched.toString(),
                        'required': required.toString(),
                      }),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.2),
                    ),
                  ),
                ),
              ] else ...[
                // Khi đã kích hoạt -> Hiển thị nút gia hạn thêm
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      adFreeService.watchAd(
                        context: context,
                        onSuccess: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(TxaLanguage.get('ad_free_activated_toast')),
                              backgroundColor: const Color(0xFF7C3AED),
                            ),
                          );
                        },
                        onError: (err) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(err),
                              backgroundColor: const Color(0xFFDC2626),
                            ),
                          );
                        },
                      );
                    },
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 16, color: Color(0xFFA78BFA)),
                    label: Text(
                      '${TxaLanguage.get("ad_free_btn_active")} • Tích lũy thêm 24h',
                      style: const TextStyle(color: Color(0xFFA78BFA), fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: const Color(0xFFA78BFA).withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
