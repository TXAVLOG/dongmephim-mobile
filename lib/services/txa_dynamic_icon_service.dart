import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/txa_logger.dart';
import 'txa_auth_service.dart';

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

      if (Platform.isAndroid || Platform.isIOS || Platform.isWindows) {
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

  static const String prefixAdUnlockExpiry = 'txa_ad_unlocked_expiry_';

  /// Returns a user-scoped prefix so that ad unlocks are isolated per account.
  /// Uses user ID (stable) + username fallback. Guests get 'guest_' prefix.
  static String _userScopePrefix() {
    final auth = TxaAuthService();
    final userId = auth.user?['id'] as String? ?? auth.user?['username'] as String?;
    return (userId != null && userId.isNotEmpty) ? '${userId}_' : 'guest_';
  }

  /// Save ad unlock status for 3 days — scoped to current logged-in user
  static Future<void> saveAdUnlock(String iconKey) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$prefixAdUnlockExpiry${_userScopePrefix()}$iconKey';
    final expiry = DateTime.now().add(const Duration(days: 3));
    await prefs.setString(key, expiry.toIso8601String());
  }

  /// Check if icon is currently unlocked via ad (and not expired) — scoped to current user
  static Future<bool> isAdUnlocked(String iconKey) async {
    if (iconKey == 'icon_default.png') return true;
    final expiry = await getAdUnlockExpiry(iconKey);
    if (expiry == null) return false;
    return expiry.isAfter(DateTime.now());
  }

  /// Get ad unlock expiry date — scoped to current user
  static Future<DateTime?> getAdUnlockExpiry(String iconKey) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$prefixAdUnlockExpiry${_userScopePrefix()}$iconKey';
    final expiryStr = prefs.getString(key);
    if (expiryStr != null) {
      return DateTime.tryParse(expiryStr);
    }
    return null;
  }

  /// Get remaining duration of ad unlock — scoped to current user
  static Future<Duration?> getAdUnlockRemaining(String iconKey) async {
    final expiry = await getAdUnlockExpiry(iconKey);
    if (expiry != null) {
      final diff = expiry.difference(DateTime.now());
      return diff.isNegative ? Duration.zero : diff;
    }
    return null;
  }

  /// Helper to check subscription permission based on user map
  static bool hasSubscriptionPermission(Map<String, dynamic>? user) {
    if (user == null) return false;
    final role = (user['role'] ?? 'user').toString().toLowerCase();
    if (role == 'admin' || role == 'superadmin') return true;

    if (user['custom_app_icon'] == true || user['allow_custom_icon'] == true) return true;
    final perms = user['permissions'] as Map<String, dynamic>?;
    if (perms != null && (perms['custom_app_icon'] == true || perms['custom_icon'] == true || perms['allow_custom_icon'] == true)) {
      return true;
    }
    final pkg = (user['package'] ?? 'free').toString().toLowerCase();
    if (pkg == 'custom_icon' || pkg.contains('icon') || pkg == 'vip' || pkg == 'dongphims') {
      final expiryStr = user['expiry_date'] ?? user['expiryDate'];
      if (expiryStr != null && expiryStr.toString().isNotEmpty) {
        final dt = DateTime.tryParse(expiryStr.toString());
        if (dt != null && dt.isBefore(DateTime.now())) {
          return false;
        }
      }
      return true;
    }
    return false;
  }

  /// Check active icon permission, if expired/unlicensed reset to default
  /// Returns true if the icon was reset to default.
  static Future<bool> checkAndRevertExpiredOrUnlicensedIcon(Map<String, dynamic>? currentUser) async {
    final activeIcon = await getActiveIconKey();
    if (activeIcon == 'icon_default.png') return false;

    // Check if user has subscription permission
    final hasSub = hasSubscriptionPermission(currentUser);
    if (hasSub) return false;

    // Check if current active icon is unlocked via ads
    final adsUnlocked = await isAdUnlocked(activeIcon);
    if (adsUnlocked) return false;

    // Not subscribed, and not ads-unlocked (or ads-unlocked expired). Revert to default.
    TxaLogger.log('Active app icon ($activeIcon) is no longer licensed or has expired. Reverting to default Neon Default.', type: 'app');
    await setAppIcon('icon_default.png');
    return true;
  }

  static const String keySubActive = 'txa_icon_sub_active';
  static const String keySubExpiry = 'txa_icon_sub_expiry';
  static const String keySubIsTrial = 'txa_icon_sub_is_trial';

  /// Build user-scoped key for local subscription fields
  static String _subKey(String base) => '${base}_${_userScopePrefix()}';

  /// Save local icon subscription status — scoped to current user
  static Future<void> setLocalSubscriptionActive(bool active, {DateTime? expiry, bool isTrial = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_subKey(keySubActive), active);
    await prefs.setBool(_subKey(keySubIsTrial), isTrial);
    if (expiry != null) {
      await prefs.setString(_subKey(keySubExpiry), expiry.toIso8601String());
    } else {
      final duration = isTrial ? const Duration(days: 7) : const Duration(days: 30);
      await prefs.setString(_subKey(keySubExpiry), DateTime.now().add(duration).toIso8601String());
    }
  }

  /// Check if local subscription is trial — scoped to current user
  static Future<bool> isLocalSubscriptionTrial() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_subKey(keySubIsTrial)) ?? false;
  }

  /// Check if local subscription is active (and not expired) — scoped to current user
  static Future<bool> isLocalSubscriptionActive() async {
    final prefs = await SharedPreferences.getInstance();
    final active = prefs.getBool(_subKey(keySubActive)) ?? false;
    if (!active) return false;
    final expiryStr = prefs.getString(_subKey(keySubExpiry));
    if (expiryStr != null) {
      final expiry = DateTime.tryParse(expiryStr);
      if (expiry != null && expiry.isBefore(DateTime.now())) {
        await prefs.setBool(_subKey(keySubActive), false);
        return false;
      }
    }
    return true;
  }

  /// Get local icon subscription expiry date — scoped to current user
  static Future<DateTime?> getLocalSubscriptionExpiry() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryStr = prefs.getString(_subKey(keySubExpiry));
    if (expiryStr != null) {
      return DateTime.tryParse(expiryStr);
    }
    return null;
  }

  /// Get remaining duration of local icon subscription — scoped to current user
  static Future<Duration?> getLocalSubscriptionRemaining() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryStr = prefs.getString(_subKey(keySubExpiry));
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
