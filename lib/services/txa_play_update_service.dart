import 'dart:ui';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';
import 'txa_api.dart';
import 'txa_language.dart';
import 'txa_version.dart';
import '../theme/txa_theme.dart';
import '../utils/txa_logger.dart';
import '../utils/txa_toast.dart';
import '../utils/txa_platform.dart';
import '../utils/txa_rich_text.dart';
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

  /// Try Google Play In-App Update explicitly
  static Future<bool> tryInAppUpdate() async {
    if (kIsWeb || !Platform.isAndroid || TxaPlatform.isTV) return false;
    try {
      final updateInfo = await InAppUpdate.checkForUpdate();
      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        if (updateInfo.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
          return true;
        } else if (updateInfo.flexibleUpdateAllowed) {
          await InAppUpdate.startFlexibleUpdate();
          await InAppUpdate.completeFlexibleUpdate();
          return true;
        }
      }
    } catch (e) {
      TxaLogger.log('tryInAppUpdate error: $e', type: 'app');
    }
    return false;
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

  static bool _updateToastDismissed = false;

  /// Show beautiful update modal dialog with changelog & actions
  static void showUpdateDialog(
    BuildContext context,
    Map<String, dynamic> info,
    String serverVersion,
  ) {
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500, maxHeight: 540),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    TxaTheme.secondaryBg.withValues(alpha: 0.95),
                    TxaTheme.cardBg.withValues(alpha: 0.92),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: TxaTheme.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.system_update_rounded, color: TxaTheme.accent, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              TxaLanguage.t('update_available'),
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'v${TxaVersion.version} → v$serverVersion',
                              style: const TextStyle(color: TxaTheme.accent, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _updateToastDismissed = true;
                        },
                        icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 12),

                  // Changelog title
                  Text(
                    TxaLanguage.t('whats_new'),
                    style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  // Changelog dedicated scrollable card box
                  Flexible(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
                      ),
                      child: Scrollbar(
                        thumbVisibility: true,
                        radius: const Radius.circular(4),
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.only(right: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: TxaRichTextParser.parse(
                              (info['app_release_notes'] ?? info['changelog'] ?? '').toString(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _updateToastDismissed = true;
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            TxaLanguage.t('later'),
                            style: const TextStyle(color: TxaTheme.textSecondary, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            handleMultiplatformUpdate(context, info, serverVersion);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TxaTheme.accent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(TxaLanguage.t('update_now'), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Subtle background update check when entering HomeScreen (Multiplatform)
  static Future<void> checkBackgroundUpdate(BuildContext context) async {
    if (!context.mounted || _updateToastDismissed) return;

    try {
      // 1. Android Mobile: Try native Google Play In-App update check first
      if (!kIsWeb && Platform.isAndroid && !TxaPlatform.isTV) {
        try {
          final updateInfo = await InAppUpdate.checkForUpdate();
          if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
            if (!context.mounted || _updateToastDismissed) return;
            final msg = TxaLanguage.t('update_toast_msg').replaceAll('%version%', 'Play Store');
            TxaToast.showWithAction(
              context,
              msg,
              actionLabel: TxaLanguage.t('update_chplay'),
              onDismiss: () {
                _updateToastDismissed = true;
              },
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
      if (info == null || !context.mounted || _updateToastDismissed) return;

      final serverVersion = (info['app_version'] ?? TxaVersion.version).toString().trim();
      if (isVersionLower(TxaVersion.version, serverVersion)) {
        if (!context.mounted || _updateToastDismissed) return;

        // Display the full update dialog modal with changelog & update button directly
        showUpdateDialog(context, info, serverVersion);
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
        // Android Mobile: Use Google Play In-App Update or open Google Play Store page
        final inAppSuccess = await tryInAppUpdate();
        if (inAppSuccess) return;

        if (!context.mounted) return;
        final openedStore = await openPlayStore();
        if (!openedStore && context.mounted) {
          final apkUrl = (info['apk_url'] ?? info['download_url'] ?? '').toString();
          if (apkUrl.isNotEmpty) {
            _launchExternalUrl(context, apkUrl);
          }
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
        if (isVersionLower(TxaVersion.version, serverVersion)) {
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
  static bool isVersionLower(String current, String latest) {
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
