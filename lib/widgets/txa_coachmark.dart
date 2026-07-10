import 'package:flutter/material.dart';
import '../services/txa_language.dart';
import '../theme/txa_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/txa_platform.dart';

class TxaCoachmark {
  static Future<void> show(BuildContext context) async {
    if (!TxaPlatform.isMobile) return;
    
    final prefs = await SharedPreferences.getInstance();
    final hasShown = prefs.getBool('txa_has_shown_coachmark') ?? false;
    if (hasShown) return;
    await prefs.setBool('txa_has_shown_coachmark', true);

    if (!context.mounted) return;

    // Show step 1 of coach mark
    _showStep(context, 0);
  }

  static void _showStep(BuildContext context, int step) {
    final List<Map<String, String>> steps = [
      {
        'title': 'coach_menu_title',
        'desc': 'coach_menu_desc',
        'align': 'top_left',
      },
      {
        'title': 'coach_search_title',
        'desc': 'coach_search_desc',
        'align': 'search_tab',
      },
      {
        'title': 'coach_nav_title',
        'desc': 'coach_nav_desc',
        'align': 'bottom_center',
      },
    ];

    if (step >= steps.length) return;

    final current = steps[step];
    late Alignment cardAlignment;
    late double spotlightTop;
    late double spotlightLeft;
    late double spotlightSize;

    if (current['align'] == 'top_left') {
      spotlightTop = MediaQuery.of(context).padding.top + 10;
      spotlightLeft = 14;
      spotlightSize = 56;
      cardAlignment = const Alignment(-0.8, -0.4);
    } else if (current['align'] == 'search_tab') {
      spotlightTop = MediaQuery.of(context).size.height - 65;
      spotlightSize = 64;
      spotlightLeft = (MediaQuery.of(context).size.width * 0.375) - 32;
      cardAlignment = const Alignment(0.0, 0.4);
    } else {
      spotlightTop = MediaQuery.of(context).size.height - 70;
      spotlightLeft = 16;
      spotlightSize = MediaQuery.of(context).size.width - 32;
      cardAlignment = const Alignment(0.0, 0.6);
    }

    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          // Semi-transparent backdrop
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                overlayEntry.remove();
                _showStep(context, step + 1);
              },
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.85),
                  BlendMode.srcOut,
                ),
                child: Stack(
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                        backgroundBlendMode: BlendMode.dstOut,
                      ),
                    ),
                    Positioned(
                      top: spotlightTop,
                      left: spotlightLeft,
                      child: Container(
                        width: spotlightSize,
                        height: current['align'] == 'bottom_center' ? 56 : spotlightSize,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(current['align'] == 'bottom_center' ? 28 : spotlightSize / 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Glow border around the spotlight
          Positioned(
            top: spotlightTop - 4,
            left: spotlightLeft - 4,
            child: IgnorePointer(
              child: Container(
                width: spotlightSize + 8,
                height: (current['align'] == 'bottom_center' ? 56 : spotlightSize) + 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(current['align'] == 'bottom_center' ? 32 : (spotlightSize + 8) / 2),
                  border: Border.all(color: TxaTheme.accent, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: TxaTheme.accent.withValues(alpha: 0.5),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Content Card pointing to spotlight
          Align(
            alignment: cardAlignment,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 280,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      TxaTheme.secondaryBg.withValues(alpha: 0.95),
                      TxaTheme.cardBg.withValues(alpha: 0.95),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12, width: 1.2),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.stars_rounded, color: TxaTheme.accent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            TxaLanguage.t(current['title']!),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      TxaLanguage.t(current['desc']!),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${step + 1}/${steps.length}',
                          style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () {
                            overlayEntry.remove();
                            _showStep(context, step + 1);
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: TxaTheme.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            minimumSize: Size.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(
                            step == steps.length - 1 ? TxaLanguage.t('got_it') : TxaLanguage.t('next'),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(overlayEntry);
  }
}
