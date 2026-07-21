import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import '../services/txa_api.dart';
import '../services/txa_version.dart';
import '../utils/txa_logger.dart';
import '../utils/txa_toast.dart';
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
        
        // Trigger Google Play In-App Update UI directly inside the app
        await InAppUpdate.performImmediateUpdate().catchError((e) async {
          TxaLogger.log('Immediate update failed, trying flexible update: $e', type: 'app');
          await InAppUpdate.startFlexibleUpdate();
          await InAppUpdate.completeFlexibleUpdate();
        });
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
        final settings = await TxaApi().getSettings();
        if (settings != null && settings['app'] != null) {
          final appInfo = settings['app'];
          final latestVersion = (appInfo['app_version'] ?? TxaVersion.version).toString().trim();

          if (_isVersionLower(TxaVersion.version, latestVersion)) {
            if (!context.mounted) return;
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => TxaDownloadDialog(
                downloadUrl: (appInfo['app_apk_url'] ?? 'https://pub-ffb3837c19c940af8cc1bc7f2682fd70.r2.dev/DongMePhim-Mobile.apk').toString(),
                sha256: (appInfo['app_apk_sha256'] ?? '').toString(),
                latestVersion: latestVersion,
              ),
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
