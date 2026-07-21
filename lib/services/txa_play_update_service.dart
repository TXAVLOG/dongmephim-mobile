import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';
import 'txa_api.dart';
import 'txa_language.dart';
import 'txa_version.dart';
import '../utils/txa_logger.dart';
import '../utils/txa_toast.dart';
import '../utils/txa_platform.dart';
import '../widgets/txa_download_dialog.dart';

class TxaPlayUpdateService {
  static const String chPlayPackageName = 'com.tphimx.tphimx_setup';

  /// Call Google Play In-App Update API directly on Splash Screen (Android Mobile)
  static Future<void> checkInAppUpdateOnSplash() async {
    if (kIsWeb || !Platform.isAndroid || TxaPlatform.isTV) return;

    try {
      TxaLogger.log('Splash: Checking Google Play In-App Update...', type: 'app');
      final updateInfo = await InAppUpdate.checkForUpdate();

      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        TxaLogger.log('Splash: Google Play Update available! Triggering immediate update...', type: 'app');
        if (updateInfo.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
        } else if (updateInfo.flexibleUpdateAllowed) {
          await InAppUpdate.startFlexibleUpdate();
          await InAppUpdate.completeFlexibleUpdate();
        }
      }
    } catch (e) {
      TxaLogger.log('Splash InAppUpdate check skipped/failed: $e', type: 'app');
    }
  }

  /// Open Google Play Store page directly
  static Future<bool> openPlayStore() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    final playStoreUri = Uri.parse('market://details?id=$chPlayPackageName');
    final webPlayStoreUri = Uri.parse('https://play.google.com/store/apps/details?id=$chPlayPackageName');

    try {
      if (await canLaunchUrl(playStoreUri)) {
        await launchUrl(playStoreUri, mode: LaunchMode.externalApplication);
        return true;
      } else if (await canLaunchUrl(webPlayStoreUri)) {
        await launchUrl(webPlayStoreUri, mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (e) {
      TxaLogger.log('Error opening Play Store: $e', type: 'app');
    }
    return false;
  }

  /// Subtle background update check when entering HomeScreen (Multiplatform)
  static Future<void> checkBackgroundUpdate(BuildContext context) async {
    if (!context.mounted) return;

    try {
      // 1. Android Mobile: Try native Google Play In-App update check first
      if (!kIsWeb && Platform.isAndroid && !TxaPlatform.isTV) {
        try {
          final updateInfo = await InAppUpdate.checkForUpdate();
          if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
            if (!context.mounted) return;
            final msg = TxaLanguage.t('update_toast_msg').replaceAll('%version%', 'Play Store');
            TxaToast.showWithAction(
              context,
              msg,
              actionLabel: TxaLanguage.t('update_chplay'),
              onAction: () async {
                try {
                  await InAppUpdate.performImmediateUpdate();
                } catch (_) {
                  await openPlayStore();
                }
              },
            );
            return;
          }
        } catch (_) {}
      }

      // 2. Multiplatform Server API check (Android, Smart TV, iOS, Windows)
      final info = await TxaApi().getCheckUpdate();
      if (info == null || !context.mounted) return;

      final serverVersion = (info['app_version'] ?? TxaVersion.version).toString().trim();
      if (_isVersionLower(TxaVersion.version, serverVersion)) {
        if (!context.mounted) return;

        final msg = TxaLanguage.t('update_toast_msg').replaceAll('%version%', serverVersion);
        final String actionLabel = (!kIsWeb && Platform.isAndroid && !TxaPlatform.isTV)
            ? TxaLanguage.t('update_chplay')
            : TxaLanguage.t('update_now');

        TxaToast.showWithAction(
          context,
          msg,
          actionLabel: actionLabel,
          durationSeconds: 8,
          onAction: () async {
            if (!context.mounted) return;
            handleMultiplatformUpdate(context, info, serverVersion);
          },
        );
      }
    } catch (e) {
      TxaLogger.log('Background update check error: $e', type: 'app');
    }
  }

  /// Handle multiplatform update trigger (Android, Smart TV, iOS, Windows)
  static Future<void> handleMultiplatformUpdate(
    BuildContext context,
    Map<String, dynamic> info,
    String version,
  ) async {
    if (kIsWeb) {
      final webUrl = (info['download_url'] ?? '').toString();
      if (webUrl.isNotEmpty) {
        _launchExternalUrl(context, webUrl);
      }
      return;
    }

    if (Platform.isAndroid) {
      if (TxaPlatform.isTV) {
        // Smart TV: Download Smart TV APK
        final tvUrl = (info['smart_tv_url'] ?? info['download_url'] ?? 'https://pub-ffb3837c19c940af8cc1bc7f2682fd70.r2.dev/DongMePhim-TV.apk').toString();
        _startFileDownload(context, tvUrl, 'DongMePhim_TV_$version.apk');
      } else {
        // Android Mobile: Try opening Play Store first to avoid signature conflicts!
        final opened = await openPlayStore();
        if (!opened && context.mounted) {
          final apkUrl = (info['apk_url'] ?? info['download_url'] ?? 'https://pub-ffb3837c19c940af8cc1bc7f2682fd70.r2.dev/DongMePhim-Mobile.apk').toString();
          _startFileDownload(context, apkUrl, 'DongMePhim_$version.apk');
        }
      }
    } else if (Platform.isIOS) {
      // iOS: Open App Store or iOS IPA link
      final iosUrl = (info['app_store_url'] ?? info['ios_download_url'] ?? info['ios_ipa_url'] ?? info['download_url'] ?? '').toString();
      if (iosUrl.isNotEmpty) {
        _launchExternalUrl(context, iosUrl);
      } else {
        TxaToast.show(context, TxaLanguage.t('cannot_find_ios_link'), isError: true);
      }
    } else if (Platform.isWindows) {
      // Windows: Download .exe setup file and run installer
      final winUrl = (info['windows_download_url'] ?? info['download_url'] ?? '').toString();
      if (winUrl.isNotEmpty) {
        _startFileDownload(context, winUrl, 'DongMePhim_v${version}_Setup.exe');
      } else {
        TxaToast.show(context, TxaLanguage.t('cannot_find_win_link'), isError: true);
      }
    } else {
      final fallbackUrl = (info['download_url'] ?? '').toString();
      if (fallbackUrl.isNotEmpty) {
        _launchExternalUrl(context, fallbackUrl);
      }
    }
  }

  /// Start direct file download & auto-open installer (Windows / Android / TV)
  static void _startFileDownload(
    BuildContext context,
    String url,
    String filename,
  ) {
    if (url.isEmpty || !context.mounted) return;

    TxaDownloadDialog.show(
      context,
      url,
      filename,
      onFinished: (path) async {
        TxaLogger.log('Download finished, opening installer: $path', type: 'app');
        try {
          final result = await OpenFile.open(path);
          if (result.type != ResultType.done && context.mounted) {
            TxaToast.show(context, "Error: ${result.message}", isError: true);
          }
        } catch (e) {
          TxaLogger.log('Error opening downloaded file: $e', type: 'app');
        }
      },
    );
  }

  /// Launch external web URL (iOS / Web / Fallbacks)
  static Future<void> _launchExternalUrl(BuildContext context, String urlString) async {
    try {
      final uri = Uri.parse(urlString);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (context.mounted) {
        TxaToast.show(context, "Lỗi mở liên kết: $urlString", isError: true);
      }
    } catch (e) {
      if (context.mounted) {
        TxaToast.show(context, "Lỗi mở liên kết: $e", isError: true);
      }
    }
  }

  /// Manual check update helper
  static Future<void> checkAndPromptUpdate(
    BuildContext context, {
    bool silentIfLatest = false,
  }) async {
    try {
      final info = await TxaApi().getCheckUpdate();
      if (info != null && context.mounted) {
        final serverVersion = (info['app_version'] ?? TxaVersion.version).toString().trim();
        if (_isVersionLower(TxaVersion.version, serverVersion)) {
          handleMultiplatformUpdate(context, info, serverVersion);
          return;
        }
      }
    } catch (_) {}

    if (!silentIfLatest && context.mounted) {
      final latestMsg = TxaLanguage.t('up_to_date').replaceAll('%version%', TxaVersion.version);
      TxaToast.show(context, latestMsg);
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
