import 'package:flutter/material.dart';
import '../services/txa_language.dart';
import '../theme/txa_theme.dart';
import 'txa_coachmark.dart';

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
    final bottomMargin = bottomPadding > 0 ? bottomPadding + 8.0 : 18.0;

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
        radius: 34,
        child: Container(
          key: TxaCoachKeys.bottomNavKey,
          height: 70,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.16),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 28,
                spreadRadius: -2,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: TxaTheme.accent.withValues(alpha: 0.12),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              final itemCount = items.length;
              final itemWidth = totalWidth / itemCount;

              return Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Sliding Liquid Blob Indicator
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutBack,
                    left: activeVisualIndex * itemWidth + 6,
                    top: 8,
                    bottom: 8,
                    width: itemWidth - 12,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            TxaTheme.accent.withValues(alpha: 0.35),
                            TxaTheme.purple.withValues(alpha: 0.22),
                            TxaTheme.accent.withValues(alpha: 0.28),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: TxaTheme.accent.withValues(alpha: 0.5),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: TxaTheme.accent.withValues(alpha: 0.4),
                            blurRadius: 16,
                            spreadRadius: 1,
                          ),
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

                      Key? itemKey;
                      if (index == 1) itemKey = TxaCoachKeys.searchTabKey;
                      if (index == 2) itemKey = TxaCoachKeys.scheduleTabKey;

                      return Expanded(
                        child: GestureDetector(
                          key: itemKey,
                          onTap: () => onTap(index),
                          behavior: HitTestBehavior.opaque,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedScale(
                                scale: isActive ? 1.2 : 1.0,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOutBack,
                                child: Icon(
                                  icon,
                                  color: isActive
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.45),
                                  size: 23,
                                ),
                              ),
                              const SizedBox(height: 3),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: TextStyle(
                                  color: isActive
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.45),
                                  fontSize: isActive ? 9.5 : 9.0,
                                  fontWeight: isActive ? FontWeight.w800 : FontWeight.normal,
                                  letterSpacing: isActive ? 0.3 : 0.0,
                                ),
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(height: 2),
                              // Glowing Liquid Drop Dot under active tab
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                height: 3,
                                width: isActive ? 12 : 0,
                                decoration: BoxDecoration(
                                  color: isActive ? TxaTheme.accent : Colors.transparent,
                                  borderRadius: BorderRadius.circular(2),
                                  boxShadow: isActive
                                      ? [
                                          BoxShadow(
                                            color: TxaTheme.accent.withValues(alpha: 0.9),
                                            blurRadius: 6,
                                            spreadRadius: 1,
                                          )
                                        ]
                                      : [],
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
