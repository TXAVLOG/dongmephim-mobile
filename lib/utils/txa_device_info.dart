import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../services/txa_version.dart';

class TxaDeviceInfo {
  static Map<String, String>? _cachedSpecs;

  /// Fetch comprehensive hardware and system diagnostic metadata
  static Future<Map<String, String>> getDiagnosticMetadata() async {
    if (_cachedSpecs != null) return _cachedSpecs!;

    final Map<String, String> specs = {};

    try {
      final deviceInfoPlugin = DeviceInfoPlugin();

      // 1. Screen resolution & pixel ratio
      try {
        final views = PlatformDispatcher.instance.views;
        if (views.isNotEmpty) {
          final view = views.first;
          final size = view.physicalSize;
          final ratio = view.devicePixelRatio;
          final dpWidth = (size.width / ratio).round();
          final dpHeight = (size.height / ratio).round();
          specs['Màn Hình'] = '${size.width.toInt()}x${size.height.toInt()} px (${dpWidth}x$dpHeight dp @${ratio.toStringAsFixed(1)}x)';
        }
      } catch (_) {}

      // 2. Timezone & Locale
      final now = DateTime.now();
      final timeZone = now.timeZoneName;
      final timeOffset = now.timeZoneOffset;
      final offsetHours = timeOffset.inHours.toString().padLeft(2, '0');
      final offsetMins = (timeOffset.inMinutes % 60).abs().toString().padLeft(2, '0');
      final sign = timeOffset.isNegative ? '-' : '+';
      specs['Múi Giờ'] = '$timeZone (UTC$sign$offsetHours:$offsetMins)';

      // 3. Platform specific details
      if (kIsWeb) {
        specs['Hệ Điều Hành'] = 'Trình Duyệt Web';
        specs['Loại Thiết Bị'] = 'Web Browser';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        final name = iosInfo.name;
        final systemName = iosInfo.systemName;
        final systemVersion = iosInfo.systemVersion;
        final model = iosInfo.model;
        final machine = iosInfo.utsname.machine;
        final sysname = iosInfo.utsname.sysname;
        final release = iosInfo.utsname.release;

        specs['Hệ Điều Hành'] = '$systemName $systemVersion';
        specs['Tên Thiết Bị'] = name.isNotEmpty ? name : 'Apple iOS Device';
        specs['Model / Mã Máy'] = '$model ($machine)';
        specs['Loại Thiết Bị'] = iosInfo.isPhysicalDevice ? 'Thiết Bị Thật (Physical Device)' : 'Máy Ảo (iOS Simulator)';
        specs['Nhân Kernel'] = '$sysname $release (${iosInfo.utsname.version.split('\n').first})';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        final brand = androidInfo.brand;
        final manufacturer = androidInfo.manufacturer;
        final model = androidInfo.model;
        final product = androidInfo.product;
        final release = androidInfo.version.release;
        final sdk = androidInfo.version.sdkInt;
        final buildId = androidInfo.id;
        final abis = androidInfo.supportedAbis.join(', ');

        specs['Hệ Điều Hành'] = 'Android $release (API $sdk)';
        specs['Tên Thiết Bị'] = '$brand $model ($manufacturer)';
        specs['Model / Mã Máy'] = '$product (Build $buildId)';
        specs['Kiến Trúc CPU'] = abis.isNotEmpty ? abis : androidInfo.hardware;
        specs['Loại Thiết Bị'] = androidInfo.isPhysicalDevice ? 'Thiết Bị Thật (Physical Device)' : 'Giả Lập (Android Emulator)';
        specs['Bo Mạch / Hardware'] = '${androidInfo.board} / ${androidInfo.hardware}';
      } else if (Platform.isWindows) {
        final winInfo = await deviceInfoPlugin.windowsInfo;
        specs['Hệ Điều Hành'] = 'Windows ${winInfo.majorVersion}.${winInfo.minorVersion} (Build ${winInfo.buildNumber})';
        specs['Máy Tính'] = winInfo.computerName;
        specs['Số Nhân CPU'] = '${winInfo.numberOfCores} Cores';
        specs['Bộ Nhớ RAM'] = '${(winInfo.systemMemoryInMegabytes / 1024).toStringAsFixed(1)} GB';
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfoPlugin.macOsInfo;
        specs['Hệ Điều Hành'] = 'macOS ${macInfo.osRelease} (${macInfo.kernelVersion})';
        specs['Model'] = macInfo.model;
        specs['Máy Tính'] = macInfo.computerName;
        specs['CPU Cores'] = '${macInfo.activeCPUs} Cores';
        specs['RAM'] = '${(macInfo.memorySize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfoPlugin.linuxInfo;
        specs['Hệ Điều Hành'] = 'Linux ${linuxInfo.name} (${linuxInfo.versionId})';
        specs['Tên Máy'] = linuxInfo.prettyName;
      } else {
        specs['Hệ Điều Hành'] = '${Platform.operatingSystem} (${Platform.operatingSystemVersion})';
      }

      _cachedSpecs = specs;
      return _cachedSpecs!;
    } catch (e) {
      specs['Hệ Điều Hành'] = '${Platform.operatingSystem} (${Platform.operatingSystemVersion})';
      return specs;
    }
  }

  /// Generates a rich, highly detailed system debug log header
  static Future<String> getFormattedHeader({
    required String logType,
    required String timestamp,
    String status = 'SUCCESS',
  }) async {
    final Map<String, String> specs = await getDiagnosticMetadata();
    final nowStr = DateTime.now().toString().split('.').first;

    final StringBuffer sb = StringBuffer();
    sb.writeln('=================================================================');
    sb.writeln('                 DONGMEPHIM SYSTEM DIAGNOSTIC REPORT             ');
    sb.writeln('=================================================================');
    sb.writeln('📱 THÔNG TIN THIẾT BỊ & PHẦN CỨNG:');
    
    specs.forEach((key, val) {
      sb.writeln('• ${key.padRight(22)}: $val');
    });

    sb.writeln('\n📦 THÔNG TIN ỨNG DỤNG & MÔI TRƯỜNG:');
    sb.writeln('• ${'Tên Ứng Dụng'.padRight(22)}: DongMePhim Mobile Premium');
    sb.writeln('• ${'Phiên Bản App'.padRight(22)}: ${TxaVersion.version} (Build 533)');
    sb.writeln('• ${'Dart / Flutter Runtime'.padRight(22)}: ${Platform.version.split(' ').first}');

    sb.writeln('\n📊 CHI TIẾT NHẬT KÝ (LOG METADATA):');
    sb.writeln('• ${'Thời Gian Sao Chép'.padRight(22)}: $nowStr');
    sb.writeln('• ${'Loại Nhật Ký'.padRight(22)}: $logType');
    sb.writeln('• ${'Mốc Thời Gian Log'.padRight(22)}: $timestamp');
    sb.writeln('• ${'Trạng Thái Hệ Thống'.padRight(22)}: $status');
    sb.writeln('=================================================================');

    return sb.toString();
  }
}
