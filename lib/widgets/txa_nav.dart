import 'package:flutter/material.dart';
import '../services/txa_language.dart';
import '../theme/txa_theme.dart';

class TxaNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const TxaNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    const horizontalMargin = 16.0;
    final bottomMargin = bottomPadding > 0 ? bottomPadding + 10.0 : 20.0;

    final List<Map<String, dynamic>> items = [
      {'index': 0, 'icon': Icons.home_rounded, 'label': TxaLanguage.t('home')},
      {'index': 1, 'icon': Icons.search_rounded, 'label': TxaLanguage.t('search')},
      {'index': 2, 'icon': Icons.calendar_month_rounded, 'label': TxaLanguage.t('schedule')},
      {'index': 3, 'icon': Icons.terminal_rounded, 'label': TxaLanguage.t('logs')},
      {'index': 4, 'icon': Icons.person_rounded, 'label': TxaLanguage.t('profile')},
    ];

    int activeVisualIndex = items.indexWhere((item) => item['index'] == currentIndex);
    if (activeVisualIndex == -1) activeVisualIndex = 0;

    return Padding(
      padding: EdgeInsets.only(
        left: horizontalMargin,
        right: horizontalMargin,
        bottom: bottomMargin,
      ),
      child: TxaTheme.liquidGlassPill(
        radius: 32,
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 24,
                spreadRadius: -2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              final itemCount = items.length;
              final itemWidth = totalWidth / itemCount;

              return Stack(
                children: [
                  // Sliding Liquid Pill Indicator
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutBack,
                    left: activeVisualIndex * itemWidth + 8,
                    top: 10,
                    bottom: 10,
                    width: itemWidth - 16,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            TxaTheme.accent.withValues(alpha: 0.28),
                            TxaTheme.purple.withValues(alpha: 0.18),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: TxaTheme.accent.withValues(alpha: 0.35),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: TxaTheme.accent.withValues(alpha: 0.25),
                            blurRadius: 12,
                            spreadRadius: 1,
                          )
                        ],
                      ),
                    ),
                  ),

                  // Nav Bar Items Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: items.map((item) {
                      final index = item['index'] as int;
                      final icon = item['icon'] as IconData;
                      final label = item['label'] as String;
                      final isActive = index == currentIndex;

                      return Expanded(
                        child: GestureDetector(
                          onTap: () => onTap(index),
                          behavior: HitTestBehavior.opaque,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                icon,
                                color: isActive
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.45),
                                size: 24,
                              ),
                              const SizedBox(height: 4),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: TextStyle(
                                  color: isActive
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.45),
                                  fontSize: 9,
                                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                ),
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
