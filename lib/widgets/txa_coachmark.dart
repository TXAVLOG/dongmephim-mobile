import 'package:flutter/material.dart';
import '../services/txa_language.dart';
import '../theme/txa_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/txa_platform.dart';

class TxaCoachKeys {
  static final GlobalKey menuKey = GlobalKey(debugLabel: 'txa_coach_menu');
  static final GlobalKey heroKey = GlobalKey(debugLabel: 'txa_coach_hero');
  static final GlobalKey searchTabKey = GlobalKey(debugLabel: 'txa_coach_search');
  static final GlobalKey scheduleTabKey = GlobalKey(debugLabel: 'txa_coach_schedule');
  static final GlobalKey bottomNavKey = GlobalKey(debugLabel: 'txa_coach_nav');
}

class TxaCoachmark {
  static Future<void> show(BuildContext context, {bool force = false}) async {
    if (!TxaPlatform.isMobile) return;
    
    if (!force) {
      final prefs = await SharedPreferences.getInstance();
      final hasShown = prefs.getBool('txa_has_shown_coachmark') ?? false;
      if (hasShown) return;
      await prefs.setBool('txa_has_shown_coachmark', true);
    }

    if (!context.mounted) return;

    // Small delay to ensure all UI widgets are completely rendered and laid out
    await Future.delayed(const Duration(milliseconds: 350));
    if (!context.mounted) return;

    // Start Step 0
    _showStep(context, 0);
  }

  static Rect? _getTargetRect(GlobalKey key) {
    try {
      final context = key.currentContext;
      if (context != null) {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox != null && renderBox.hasSize && renderBox.attached) {
          final offset = renderBox.localToGlobal(Offset.zero);
          final size = renderBox.size;
          if (size.width > 0 && size.height > 0) {
            return Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height);
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static void _showStep(BuildContext context, int step) {
    final List<Map<String, dynamic>> steps = [
      {
        'title': 'coach_menu_title',
        'desc': 'coach_menu_desc',
        'key': TxaCoachKeys.menuKey,
        'fallbackRect': (Size size, double topPadding) => Rect.fromLTWH(10, topPadding + 16, 48, 48),
        'radius': 24.0,
      },
      {
        'title': 'coach_hero_title',
        'desc': 'coach_hero_desc',
        'key': TxaCoachKeys.heroKey,
        'fallbackRect': (Size size, double topPadding) => Rect.fromLTWH(16, topPadding + 80, size.width - 32, 230),
        'radius': 20.0,
      },
      {
        'title': 'coach_search_title',
        'desc': 'coach_search_desc',
        'key': TxaCoachKeys.searchTabKey,
        'fallbackRect': (Size size, double topPadding) => Rect.fromLTWH(size.width * 0.2, size.height - 80, size.width * 0.2, 56),
        'radius': 20.0,
      },
      {
        'title': 'coach_filter_title',
        'desc': 'coach_filter_desc',
        'key': TxaCoachKeys.scheduleTabKey,
        'fallbackRect': (Size size, double topPadding) => Rect.fromLTWH(size.width * 0.4, size.height - 80, size.width * 0.2, 56),
        'radius': 20.0,
      },
      {
        'title': 'coach_nav_title',
        'desc': 'coach_nav_desc',
        'key': TxaCoachKeys.bottomNavKey,
        'fallbackRect': (Size size, double topPadding) => Rect.fromLTWH(16, size.height - 88, size.width - 32, 68),
        'radius': 32.0,
      },
    ];

    if (step >= steps.length) return;
    if (!context.mounted) return;

    final current = steps[step];
    final GlobalKey targetKey = current['key'] as GlobalKey;
    final screenSize = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;

    // Get exact target bounds from key, or use fallback
    Rect? rawRect = _getTargetRect(targetKey);
    rawRect ??= (current['fallbackRect'] as Rect Function(Size, double))(screenSize, topPadding);

    // Inflate slightly for padding around element
    final double padding = step == 4 ? 4.0 : 6.0;
    final Rect targetRect = rawRect.inflate(padding);
    final double radius = (current['radius'] as double);
    final RRect spotlightRRect = RRect.fromRectAndRadius(targetRect, Radius.circular(radius));

    // Calculate Card Placement (Above or Below target)
    final bool isLowerHalf = targetRect.center.dy > screenSize.height * 0.55;
    late double cardTop;
    if (isLowerHalf) {
      cardTop = (targetRect.top - 190).clamp(topPadding + 20, screenSize.height - 220);
    } else {
      cardTop = (targetRect.bottom + 16).clamp(topPadding + 20, screenSize.height - 220);
    }

    // Center card horizontally near target
    double cardLeft = (targetRect.center.dx - 140).clamp(16.0, screenSize.width - 296.0);

    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          // Hole-punch backdrop mask
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                overlayEntry.remove();
                _showStep(context, step + 1);
              },
              child: CustomPaint(
                painter: _SpotlightPainter(
                  spotlightRRect: spotlightRRect,
                  overlayColor: Colors.black.withValues(alpha: 0.85),
                ),
              ),
            ),
          ),
          
          // Glowing border highlight over exact target location
          Positioned(
            top: spotlightRRect.top,
            left: spotlightRRect.left,
            width: spotlightRRect.width,
            height: spotlightRRect.height,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(color: TxaTheme.accent, width: 2.2),
                  boxShadow: [
                    BoxShadow(
                      color: TxaTheme.accent.withValues(alpha: 0.6),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Content Card positioned near the exact spotlight target
          Positioned(
            top: cardTop,
            left: cardLeft,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 280,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      TxaTheme.secondaryBg.withValues(alpha: 0.96),
                      TxaTheme.cardBg.withValues(alpha: 0.96),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.2),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black87,
                      blurRadius: 24,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: TxaTheme.accent.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.stars_rounded, color: TxaTheme.accent, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            TxaLanguage.t(current['title'] as String),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      TxaLanguage.t(current['desc'] as String),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${step + 1}/${steps.length}',
                            style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            overlayEntry.remove();
                            _showStep(context, step + 1);
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: TxaTheme.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            minimumSize: Size.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(
                            step == steps.length - 1 ? TxaLanguage.t('got_it') : TxaLanguage.t('next'),
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
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

class _SpotlightPainter extends CustomPainter {
  final RRect spotlightRRect;
  final Color overlayColor;

  _SpotlightPainter({
    required this.spotlightRRect,
    required this.overlayColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutPath = Path()..addRRect(spotlightRRect);
    final finalPath = Path.combine(PathOperation.difference, backgroundPath, cutoutPath);

    canvas.drawPath(finalPath, Paint()..color = overlayColor);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.spotlightRRect != spotlightRRect || oldDelegate.overlayColor != overlayColor;
  }
}
