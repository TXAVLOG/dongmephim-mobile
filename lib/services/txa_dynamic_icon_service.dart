import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/txa_logger.dart';

class TxaDynamicIconService {
  static const MethodChannel _channel = MethodChannel('online.dongmephim/platform');
  static const String keyActiveIcon = 'txa_active_app_icon';

  /// List of 6 supported icon themes
  static const List<Map<String, String>> availableIcons = [
    {
      'key': 'icon_default.png',
      'id': 'default',
      'nameKey': 'icon_name_default',
      'descKey': 'icon_desc_default',
      'color': '#F59E0B',
    },
    {
      'key': 'icon_cyber.png',
      'id': 'cyber',
      'nameKey': 'icon_name_cyber',
      'descKey': 'icon_desc_cyber',
      'color': '#A855F7',
    },
    {
      'key': 'icon_gold.png',
      'id': 'gold',
      'nameKey': 'icon_name_gold',
      'descKey': 'icon_desc_gold',
      'color': '#EAB308',
    },
    {
      'key': 'icon_cyan.png',
      'id': 'cyan',
      'nameKey': 'icon_name_cyan',
      'descKey': 'icon_desc_cyan',
      'color': '#06B6D4',
    },
    {
      'key': 'icon_emerald.png',
      'id': 'emerald',
      'nameKey': 'icon_name_emerald',
      'descKey': 'icon_desc_emerald',
      'color': '#10B981',
    },
    {
      'key': 'icon_ruby.png',
      'id': 'ruby',
      'nameKey': 'icon_name_ruby',
      'descKey': 'icon_desc_ruby',
      'color': '#EC4899',
    },
  ];

  /// Get active saved icon key
  static Future<String> getActiveIconKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyActiveIcon) ?? 'icon_default.png';
  }

  /// Change active icon on Android/iOS native platform
  static Future<bool> setAppIcon(String iconKey) async {
    final iconItem = availableIcons.firstWhere(
      (item) => item['key'] == iconKey,
      orElse: () => availableIcons.first,
    );
    final String iconId = iconItem['id'] ?? 'default';

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyActiveIcon, iconKey);

      if (Platform.isAndroid) {
        final bool success = await _channel.invokeMethod('changeAppIcon', {
          'iconName': iconId,
        });
        return success;
      }
      return true;
    } catch (e) {
      TxaLogger.log('Error changing dynamic app icon: $e', type: 'app');
      return false;
    }
  }

  static const String keySubActive = 'txa_icon_sub_active';
  static const String keySubExpiry = 'txa_icon_sub_expiry';

  /// Save local icon subscription status (called on IAP purchase or restore)
  static Future<void> setLocalSubscriptionActive(bool active, {DateTime? expiry}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keySubActive, active);
    if (expiry != null) {
      await prefs.setString(keySubExpiry, expiry.toIso8601String());
    } else {
      // Default 30 days from now if not specified
      await prefs.setString(keySubExpiry, DateTime.now().add(const Duration(days: 30)).toIso8601String());
    }
  }

  /// Check if local subscription is active (and not expired)
  static Future<bool> isLocalSubscriptionActive() async {
    final prefs = await SharedPreferences.getInstance();
    final active = prefs.getBool(keySubActive) ?? false;
    if (!active) return false;
    final expiryStr = prefs.getString(keySubExpiry);
    if (expiryStr != null) {
      final expiry = DateTime.tryParse(expiryStr);
      if (expiry != null && expiry.isBefore(DateTime.now())) {
        // Subscription expired! Auto-revert local flag
        await prefs.setBool(keySubActive, false);
        return false;
      }
    }
    return true;
  }

  /// Get local icon subscription expiry date
  static Future<DateTime?> getLocalSubscriptionExpiry() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryStr = prefs.getString(keySubExpiry);
    if (expiryStr != null) {
      return DateTime.tryParse(expiryStr);
    }
    return null;
  }

  /// Get remaining duration of local icon subscription
  static Future<Duration?> getLocalSubscriptionRemaining() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryStr = prefs.getString(keySubExpiry);
    if (expiryStr != null) {
      final expiry = DateTime.tryParse(expiryStr);
      if (expiry != null) {
        final diff = expiry.difference(DateTime.now());
        return diff.isNegative ? Duration.zero : diff;
      }
    }
    return null;
  }
}
