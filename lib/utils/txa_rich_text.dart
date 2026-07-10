import 'package:flutter/material.dart';
import '../theme/txa_theme.dart';

/// Simple markdown + HTML rich text parser for changelog/release notes content.
/// Supports: **bold**, *italic*, `code`, headers (#, ##, ###), lists (-, *, •),
/// and basic HTML tags (<b>, <i>, <br>, <p>, <ul>, <li>, <h1>-<h6>, <strong>, <em>).
class TxaRichTextParser {
  static List<Widget> parse(String text, {Color? textColor, double? baseFontSize}) {
    if (text.isEmpty) return [const SizedBox.shrink()];

    final color = textColor ?? Colors.white.withValues(alpha: 0.75);
    final fontSize = baseFontSize ?? 13.0;
    final widgets = <Widget>[];

    // Normalize HTML line breaks and block elements
    String normalized = text
        .replaceAll('<br>', '\n')
        .replaceAll('<br/>', '\n')
        .replaceAll('<br />', '\n')
        .replaceAll('</p>', '\n')
        .replaceAll('<p>', '')
        .replaceAll('</li>', '\n')
        .replaceAll('</ul>', '\n')
        .replaceAll('</ol>', '\n')
        .replaceAll('<ul>', '')
        .replaceAll('<ol>', '')
        .replaceAll('<li>', '• ')
        .replaceAll(RegExp(r'<strong>(.*?)</strong>'), '**\$1**')
        .replaceAll(RegExp(r'<b>(.*?)</b>'), '**\$1**')
        .replaceAll(RegExp(r'<em>(.*?)</em>'), '*\$1*')
        .replaceAll(RegExp(r'<i>(.*?)</i>'), '*\$1*')
        .replaceAll(RegExp(r'<code>(.*?)</code>'), '`\$1`')
        .replaceAll(RegExp(r'<h[1-6][^>]*>'), '\n## ')
        .replaceAll(RegExp(r'</h[1-6]>'), '\n');

    // Remove remaining HTML tags
    normalized = normalized.replaceAll(RegExp(r'<[^>]*>'), '');

    // Decode common HTML entities
    normalized = normalized
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ');

    final lines = normalized.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Detect markdown headers
      if (trimmed.startsWith('### ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Text(
            trimmed.substring(4),
            style: TextStyle(color: Colors.white, fontSize: fontSize + 1, fontWeight: FontWeight.w800),
          ),
        ));
      } else if (trimmed.startsWith('## ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(
            trimmed.substring(3),
            style: TextStyle(color: TxaTheme.accent, fontSize: fontSize + 2, fontWeight: FontWeight.w900),
          ),
        ));
      } else if (trimmed.startsWith('# ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(
            trimmed.substring(2),
            style: TextStyle(color: TxaTheme.accent, fontSize: fontSize + 3, fontWeight: FontWeight.w900),
          ),
        ));
      } else if (trimmed.startsWith('• ') || trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        final content = trimmed.substring(2);
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('  •  ', style: TextStyle(color: TxaTheme.accent, fontSize: fontSize, fontWeight: FontWeight.bold)),
              Expanded(child: _buildRichLine(content, color: color, fontSize: fontSize)),
            ],
          ),
        ));
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: _buildRichLine(trimmed, color: color, fontSize: fontSize),
        ));
      }
    }

    return widgets.isNotEmpty ? widgets : [const SizedBox.shrink()];
  }

  static Widget _buildRichLine(String text, {required Color color, required double fontSize}) {
    final spans = <InlineSpan>[];
    // Parse **bold**, *italic*, `code`, __bold__, _italic_
    final regex = RegExp(r'(\*\*(.+?)\*\*|__(.+?)__|\*(.+?)\*|_(.+?)_|`(.+?)`)');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      if (match.group(2) != null || match.group(3) != null) {
        // Bold
        spans.add(TextSpan(
          text: match.group(2) ?? match.group(3),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ));
      } else if (match.group(4) != null || match.group(5) != null) {
        // Italic
        spans.add(TextSpan(
          text: match.group(4) ?? match.group(5),
          style: const TextStyle(fontStyle: FontStyle.italic),
        ));
      } else if (match.group(6) != null) {
        // Code
        spans.add(WidgetSpan(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              match.group(6)!,
              style: TextStyle(color: TxaTheme.accent, fontSize: fontSize - 1, fontFamily: 'monospace'),
            ),
          ),
        ));
      }
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return Text.rich(
      TextSpan(
        children: spans,
        style: TextStyle(color: color, fontSize: fontSize, height: 1.5),
      ),
    );
  }
}
