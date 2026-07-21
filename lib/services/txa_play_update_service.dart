import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import '../services/txa_api.dart';
import '../services/txa_version.dart';
import '../utils/txa_logger.dart';
import '../utils/txa_toast.dart';
import '../utils/txa_platform.dart';
import '../widgets/txa_download_dialog.dart';

class TxaPlayUpdateService {
  /// Check and perform update
  /// If installed via Google Play: Uses native Google Play In-App Update API
  /// If sideloaded or error: Falls back to direct APK download
  static Future<void> checkAndPromptUpdate(
    BuildContext context, {
    bool silentIfLatest = false,
  }) async {
    if (!Platform.isAndroid) return;

    bool playUpdateTriggered = false;

    try {
      TxaLogger.log('Checking for Google Play In-App Update...', type: 'app');
      final updateInfo = await InAppUpdate.checkForUpdate();

      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        playUpdateTriggered = true;
        TxaLogger.log('Google Play Update available! Triggering immediate update UI...', type: 'app');
        
        try {
          await InAppUpdate.performImmediateUpdate();
        } catch (e) {
          TxaLogger.log('Immediate update failed, trying flexible update: $e', type: 'app');
          try {
            await InAppUpdate.startFlexibleUpdate();
            await InAppUpdate.completeFlexibleUpdate();
          } catch (_) {}
        }
        return;
      } else {
        TxaLogger.log('Google Play reports app is up to date.', type: 'app');
      }
    } catch (e) {
      TxaLogger.log('InAppUpdate check skipped/failed (likely sideloaded APK): $e', type: 'app');
    }

    // Fallback: Check Supabase settings version for sideloaded APK downloads
    if (!playUpdateTriggered) {
      try {
        final info = await TxaApi().getCheckUpdate();
        if (info != null) {
          final latestVersion = (info['app_version'] ?? TxaVersion.version).toString().trim();

          if (_isVersionLower(TxaVersion.version, latestVersion)) {
            if (!context.mounted) return;
            final isTV = TxaPlatform.isTV;
            final downloadUrl = isTV
                ? (info['smart_tv_url'] ?? info['download_url'] ?? 'https://pub-ffb3837c19c940af8cc1bc7f2682fd70.r2.dev/DongMePhim-TV.apk').toString()
                : (info['apk_url'] ?? info['download_url'] ?? 'https://pub-ffb3837c19c940af8cc1bc7f2682fd70.r2.dev/DongMePhim-Mobile.apk').toString();
            final filename = isTV ? 'DongMePhim_TV_$latestVersion.apk' : 'DongMePhim_$latestVersion.apk';

            TxaDownloadDialog.show(
              context,
              downloadUrl,
              filename,
            );
            return;
          }
        }
      } catch (e) {
        TxaLogger.log('Error checking update fallback: $e', type: 'app');
      }

      if (!silentIfLatest && context.mounted) {
        TxaToast.show(context, 'Bạn đang sử dụng phiên bản mới nhất! (v${TxaVersion.version})');
      }
    }
  }

  /// Version comparison helper (e.g. 5.1.4 < 5.1.5)
  static bool _isVersionLower(String current, String latest) {
    try {
      final cParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final lParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < cParts.length && i < lParts.length; i++) {
        if (cParts[i] < lParts[i]) return true;
        if (cParts[i] > lParts[i]) return false;
      }
      return lParts.length > cParts.length;
    } catch (_) {
      return current != latest;
    }
  }
}
