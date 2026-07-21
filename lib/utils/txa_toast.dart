import 'package:flutter/material.dart';
import '../theme/txa_theme.dart';

class TxaToast {
  static final List<OverlayEntry> _entries = [];

  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    final overlay = Overlay.of(context);
    final topInset = MediaQuery.of(context).padding.top;
    final bgColor = isError
        ? const Color(0xFFD74A4A).withValues(alpha: 0.9)
        : TxaTheme.accent.withValues(alpha: 0.88);
    final icon = isError
        ? Icons.error_outline_rounded
        : Icons.check_circle_rounded;
    final borderColor = isError
        ? const Color(0xFFFFB4B4).withValues(alpha: 0.45)
        : Colors.white.withValues(alpha: 0.25);

    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: topInset + 14,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, -16 * (1 - value)),
                child: Opacity(opacity: value, child: child),
              );
            },
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [bgColor, bgColor.withValues(alpha: 0.72)],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.32),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    _entries.add(overlayEntry);
    overlay.insert(overlayEntry);
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (_entries.contains(overlayEntry)) {
        _entries.remove(overlayEntry);
        overlayEntry.remove();
      }
    });
  }

  static void showWithAction(
    BuildContext context,
    String message, {
    required String actionLabel,
    required VoidCallback onAction,
    int durationSeconds = 6,
  }) {
    final overlay = Overlay.of(context);
    final topInset = MediaQuery.of(context).padding.top;

    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: topInset + 14,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, -16 * (1 - value)),
                child: Opacity(opacity: value, child: child),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    TxaTheme.secondaryBg.withValues(alpha: 0.96),
                    TxaTheme.cardBg.withValues(alpha: 0.96),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: TxaTheme.accent, width: 1.4),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black87,
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: TxaTheme.accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.system_update_rounded, color: TxaTheme.accent, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      if (_entries.contains(overlayEntry)) {
                        _entries.remove(overlayEntry);
                        overlayEntry.remove();
                      }
                      onAction();
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: TxaTheme.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      actionLabel,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    _entries.add(overlayEntry);
    overlay.insert(overlayEntry);
    Future.delayed(Duration(seconds: durationSeconds), () {
      if (_entries.contains(overlayEntry)) {
        _entries.remove(overlayEntry);
        overlayEntry.remove();
      }
    });
  }
}
