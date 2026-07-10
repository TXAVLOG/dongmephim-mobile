import 'package:flutter/material.dart';
import 'dart:ui';

class TxaTheme {
  // Brand Colors
  static const Color primaryBg = Color(0xFF0A0E17);
  static const Color secondaryBg = Color(0xFF111827);
  static const Color cardBg = Color(0xFF1A1F2E);
  static const Color accent = Color(0xFF737DFD);
  static const Color purple = Color(0xFFA855F7);
  static const Color pink = Color(0xFFEC4899);

  static const Gradient brandGradient = LinearGradient(
    colors: [accent, purple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  static const Color primaryColor = accent;
  static const Color secondaryColor = purple;

  static const TextStyle headingStyle = TextStyle(
    color: Colors.white,
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  static const Color glassBg = Color(0x990F172A);
  static const double glassBlur = 24.0;
  static const Color glassBorder = Color(0x14FFFFFF);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: primaryBg,
      primaryColor: accent,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: purple,
        surface: cardBg,
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
    );
  }

  // Premium Liquid Glass Pill helper for Floating Navbar & Dialogs
  static Widget liquidGlassPill({
    required Widget child,
    double radius = 999.0,
    EdgeInsets padding = EdgeInsets.zero,
    Color? borderGlowColor,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30.0, sigmaY: 30.0),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: borderGlowColor ?? Colors.white.withValues(alpha: 0.12),
              width: 1.0,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.01),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
