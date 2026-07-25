import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/txa_theme.dart';
import '../services/txa_language.dart';
import '../services/txa_version.dart';
import '../services/txa_api.dart';
import '../utils/txa_logger.dart';

class _ParsedChangelogItem {
  final String tag;
  final String content;
  final Color color;
  final IconData icon;

  _ParsedChangelogItem({
    required this.tag,
    required this.content,
    required this.color,
    required this.icon,
  });
}

class TxaUpdateChangelogModal extends StatelessWidget {
  final String version;
  final String date;
  final String title;
  final List<String> changelogLines;

  const TxaUpdateChangelogModal({
    super.key,
    required this.version,
    required this.date,
    required this.title,
    required this.changelogLines,
  });

  /// Check version from SharedPreferences and display modal only ONCE on first launch after update
  static Future<void> checkAndShow(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSeen = prefs.getString('txa_last_seen_version') ?? '';
      final currentVer = TxaVersion.version;

      if (lastSeen != currentVer) {
        String ver = currentVer;
        String date = '';
        String title = '';
        List<String> lines = [];

        // Fetch changelogs dynamically from web backend API
        try {
          final apiChangelogs = await TxaApi().getChangelog();
          if (apiChangelogs.isNotEmpty) {
            // Match the specific changelog item for this release version
            final matching = apiChangelogs.firstWhere(
              (item) => (item['version'] ?? '').toString() == currentVer,
              orElse: () => apiChangelogs.first,
            ) as Map<String, dynamic>;

            final rawDate = (matching['date'] ?? '').toString();
            if (rawDate.contains('-')) {
              final parts = rawDate.split('-');
              date = parts.length == 3 ? '${parts[2]}/${parts[1]}/${parts[0]}' : rawDate;
            } else {
              date = rawDate;
            }
            title = (matching['title'] ?? '').toString();
            final contentStr = (matching['content'] ?? '').toString();
            if (contentStr.isNotEmpty) {
              lines = contentStr
                  .split('\n')
                  .map((l) => l.trim())
                  .where((l) => l.isNotEmpty)
                  .toList();
            }
          }
        } catch (e) {
          TxaLogger.log('TxaUpdateChangelogModal API fetch fallback: $e');
        }

        if (!context.mounted) return;

        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => TxaUpdateChangelogModal(
            version: ver,
            date: date,
            title: title,
            changelogLines: lines,
          ),
        );

        // Store last seen version so it does not open again on subsequent launches
        await prefs.setString('txa_last_seen_version', currentVer);
      }
    } catch (e) {
      TxaLogger.log('TxaUpdateChangelogModal checkAndShow error: $e', type: 'app');
    }
  }

  _ParsedChangelogItem _parseLine(String rawLine) {
    String cleanLine = rawLine.replaceFirst(RegExp(r'^[-\s*•]+'), '').trim();

    // Match bracketed tags like [TỐI ƯU MÀN HÌNH TÌM KIẾM]
    final bracketMatch = RegExp(r'\[(.*?)\]').firstMatch(cleanLine);
    String extractedTag = bracketMatch != null ? bracketMatch.group(1)! : '';

    // Strip bracketed tag and emoji symbols from body
    String bodyContent = cleanLine
        .replaceFirst(RegExp(r'\[.*?\]'), '')
        .replaceAll(RegExp(r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]', unicode: true), '')
        .trim();

    if (bodyContent.isEmpty) bodyContent = cleanLine;

    // Categorize by keywords to determine custom card color & icon
    final upperTag = (extractedTag + ' ' + cleanLine).toUpperCase();

    Color cardColor;
    IconData cardIcon;
    String finalTag;

    if (upperTag.contains('TỐI ƯU') || upperTag.contains('PERF') || upperTag.contains('OPTIMIZE') || upperTag.contains('CẢI TIẾN')) {
      cardColor = const Color(0xFFF59E0B); // Amber / Yellow
      cardIcon = Icons.bolt_rounded;
      finalTag = extractedTag.isNotEmpty ? extractedTag : 'TỐI ƯU HIỆU NĂNG';
    } else if (upperTag.contains('MỚI') || upperTag.contains('NEW') || upperTag.contains('FEATURE') || upperTag.contains('THUYẾT MINH')) {
      cardColor = const Color(0xFF10B981); // Emerald Green
      cardIcon = Icons.rocket_launch_rounded;
      finalTag = extractedTag.isNotEmpty ? extractedTag : 'TÍNH NĂNG MỚI';
    } else if (upperTag.contains('SỬA LỖI') || upperTag.contains('FIX') || upperTag.contains('BUG')) {
      cardColor = const Color(0xFFF43F5E); // Rose / Red
      cardIcon = Icons.build_circle_rounded;
      finalTag = extractedTag.isNotEmpty ? extractedTag : 'SỬA LỖI';
    } else if (upperTag.contains('APP LINKS') || upperTag.contains('LINK') || upperTag.contains('HỆ THỐNG') || upperTag.contains('WORKMANAGER')) {
      cardColor = const Color(0xFF8B5CF6); // Violet / Purple
      cardIcon = Icons.link_rounded;
      finalTag = extractedTag.isNotEmpty ? extractedTag : 'CẤU HÌNH HỆ THỐNG';
    } else if (upperTag.contains('BẢO MẬT') || upperTag.contains('SECURITY') || upperTag.contains('DEEP-LINK')) {
      cardColor = const Color(0xFF3B82F6); // Blue
      cardIcon = Icons.shield_rounded;
      finalTag = extractedTag.isNotEmpty ? extractedTag : 'BẢO MẬT';
    } else if (upperTag.contains('NGÔN NGỮ') || upperTag.contains('LANG') || upperTag.contains('I18N')) {
      cardColor = const Color(0xFF06B6D4); // Cyan
      cardIcon = Icons.language_rounded;
      finalTag = extractedTag.isNotEmpty ? extractedTag : 'ĐA NGÔN NGỮ';
    } else {
      cardColor = TxaTheme.accent;
      cardIcon = Icons.auto_awesome_rounded;
      finalTag = extractedTag.isNotEmpty ? extractedTag : 'CẬP NHẬT';
    }

    return _ParsedChangelogItem(
      tag: finalTag,
      content: bodyContent,
      color: cardColor,
      icon: cardIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final parsedItems = changelogLines.map(_parseLine).toList();

    final media = MediaQuery.of(context);
    final clampedScaler = TextScaler.linear(media.textScaler.scale(1.0).clamp(0.85, 1.15));

    return MediaQuery(
      data: media.copyWith(textScaler: clampedScaler),
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: 520,
                maxHeight: media.size.height * 0.82,
              ),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF0F172A).withValues(alpha: 0.96),
                    const Color(0xFF06070A).withValues(alpha: 0.98),
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 36,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Banner
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: TxaTheme.brandGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: TxaTheme.accent.withValues(alpha: 0.4),
                              blurRadius: 16,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    TxaLanguage.t('whats_new'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      gradient: TxaTheme.brandGradient,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'v$version',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (date.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded,
                                    color: TxaTheme.textMuted, size: 12),
                                const SizedBox(width: 5),
                                Text(
                                  TxaLanguage.t('update_modal_date', replace: {'date': date}),
                                  style: const TextStyle(
                                    color: TxaTheme.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 16),

                // Categorized Changelog Cards List
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: parsedItems.map((item) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                item.color.withValues(alpha: 0.08),
                                Colors.white.withValues(alpha: 0.02),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: item.color.withValues(alpha: 0.25),
                              width: 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Badge Pill Row
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: item.color.withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: item.color.withValues(alpha: 0.4),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(item.icon, color: item.color, size: 13),
                                        const SizedBox(width: 5),
                                        Text(
                                          item.tag.toUpperCase(),
                                          style: TextStyle(
                                            color: item.color,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Content Description
                              Text(
                                item.content,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  height: 1.45,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Bottom Action Button
                GestureDetector(
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('txa_last_seen_version', version);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: TxaTheme.brandGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: TxaTheme.accent.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Text(
                      TxaLanguage.t('update_modal_btn'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                      ),
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
}
