import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../services/txa_version.dart';

class TxaDeviceInfo {
  static String? _cachedDeviceInfoString;

  static Future<String> getDetailedDeviceInfo() async {
    if (_cachedDeviceInfoString != null) return _cachedDeviceInfoString!;

    try {
      final deviceInfoPlugin = DeviceInfoPlugin();
      final StringBuffer sb = StringBuffer();

      if (kIsWeb) {
        sb.write('Web Browser');
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        final name = iosInfo.name;
        final systemName = iosInfo.systemName;
        final systemVersion = iosInfo.systemVersion;
        final model = iosInfo.model;
        final utsm = iosInfo.utsname.machine;
        sb.write('$systemName (Version $systemVersion)');
        if (name.isNotEmpty) sb.write(' • Tên: $name');
        if (model.isNotEmpty || utsm.isNotEmpty) sb.write(' • Model: $model ($utsm)');
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        final brand = androidInfo.brand;
        final model = androidInfo.model;
        final release = androidInfo.version.release;
        final sdk = androidInfo.version.sdkInt;
        final display = androidInfo.display;
        sb.write('Android $release (API $sdk)');
        sb.write(' • $brand $model');
        if (display.isNotEmpty) sb.write(' • Display: $display');
      } else if (Platform.isWindows) {
        final winInfo = await deviceInfoPlugin.windowsInfo;
        sb.write('Windows ${winInfo.majorVersion}.${winInfo.minorVersion} (Build ${winInfo.buildNumber})');
        sb.write(' • PC: ${winInfo.computerName}');
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfoPlugin.macOsInfo;
        sb.write('macOS ${macInfo.osRelease}');
        sb.write(' • Model: ${macInfo.model}');
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfoPlugin.linuxInfo;
        sb.write('Linux ${linuxInfo.name} (${linuxInfo.versionId})');
      } else {
        sb.write('${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
      }

      _cachedDeviceInfoString = sb.toString();
      return _cachedDeviceInfoString!;
    } catch (e) {
      return '${Platform.operatingSystem} (${Platform.operatingSystemVersion})';
    }
  }

  static Future<String> getFormattedHeader({
    required String logType,
    required String timestamp,
    String status = 'SUCCESS',
  }) async {
    final deviceString = await getDetailedDeviceInfo();
    final nowStr = DateTime.now().toString().split('.').first;

    return '''=========================================
      DONGMEPHIM SYSTEM DEBUG LOG
=========================================
• Thời Gian: $nowStr
• Thiết Bị: $deviceString
• Phiên Bản App: ${TxaVersion.version}
• Loại Nhật Ký: $logType
• Mốc Log: $timestamp
• Trạng Thái: $status
''';
  }
}
