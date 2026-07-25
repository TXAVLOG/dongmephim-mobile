import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../utils/txa_logger.dart';

class TxaPersistentAuthVault {
  static const String _vaultFileName = '.txa_hardware_auth_vault.json';

  /// Get unique persistent hardware device ID across reinstalls
  static Future<String> getHardwareDeviceId() async {
    if (kIsWeb) return 'web_client_device';
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        final rawId = androidInfo.id.isNotEmpty ? androidInfo.id : androidInfo.fingerprint;
        return 'AND-${androidInfo.brand}-${androidInfo.model}-$rawId'.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        final vendorId = iosInfo.identifierForVendor ?? 'ios_device';
        return 'IOS-${iosInfo.model}-$vendorId'.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      } else if (Platform.isWindows) {
        final winInfo = await deviceInfo.windowsInfo;
        return 'WIN-${winInfo.computerName}-${winInfo.numberOfCores}'.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        return 'MAC-${macInfo.computerName}-${macInfo.model}'.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      }
    } catch (e) {
      TxaLogger.log('Error getting hardware device ID: $e', type: 'auth');
    }
    return 'GENERIC_DEVICE_${Platform.operatingSystem}';
  }

  /// Get candidate vault files in system-persistent locations
  static Future<List<File>> _getVaultFiles() async {
    final List<File> files = [];
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      files.add(File('${docsDir.path}/$_vaultFileName'));

      if (!kIsWeb && Platform.isAndroid) {
        try {
          final extDir = await getExternalStorageDirectory();
          if (extDir != null) {
            files.add(File('${extDir.path}/$_vaultFileName'));
            final parent = extDir.parent.parent.parent.parent;
            files.add(File('${parent.path}/.dongmephim_vault/$_vaultFileName'));
          }
        } catch (_) {}
      }
    } catch (e) {
      TxaLogger.log('Error locating vault directory: $e', type: 'auth');
    }
    return files;
  }

  /// Save session data, user profile, and active app icon to persistent hardware vault
  static Future<void> saveSession({
    required String token,
    required Map<String, dynamic> user,
    String? activeAppIcon,
  }) async {
    try {
      final hardwareId = await getHardwareDeviceId();
      final vaultData = {
        'hardware_id': hardwareId,
        'token': token,
        'user': user,
        'active_app_icon': activeAppIcon ?? 'icon_default.png',
        'saved_at': DateTime.now().toIso8601String(),
      };
      final jsonStr = jsonEncode(vaultData);

      final files = await _getVaultFiles();
      for (final file in files) {
        try {
          if (!file.parent.existsSync()) {
            file.parent.createSync(recursive: true);
          }
          await file.writeAsString(jsonStr, flush: true);
        } catch (_) {}
      }
      TxaLogger.log('Saved persistent session to hardware vault for ${user['username'] ?? user['email']}', type: 'auth');
    } catch (e) {
      TxaLogger.log('Error saving session to persistent vault: $e', type: 'auth');
    }
  }

  /// Read saved session if hardware device ID matches
  static Future<Map<String, dynamic>?> readSavedSession() async {
    try {
      final hardwareId = await getHardwareDeviceId();
      final files = await _getVaultFiles();

      for (final file in files) {
        if (file.existsSync()) {
          try {
            final content = await file.readAsString();
            final data = jsonDecode(content) as Map<String, dynamic>?;
            if (data != null && data['token'] != null && data['hardware_id'] == hardwareId) {
              TxaLogger.log('Found valid persistent session in vault for hardware ID: $hardwareId', type: 'auth');
              return data;
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      TxaLogger.log('Error reading persistent vault session: $e', type: 'auth');
    }
    return null;
  }

  /// Clear persistent vault when user logs out or account is banned/deleted
  static Future<void> clearVault() async {
    try {
      final files = await _getVaultFiles();
      for (final file in files) {
        if (file.existsSync()) {
          try {
            await file.delete();
          } catch (_) {}
        }
      }
      TxaLogger.log('Persistent hardware vault cleared', type: 'auth');
    } catch (e) {
      TxaLogger.log('Error clearing persistent vault: $e', type: 'auth');
    }
  }
}
