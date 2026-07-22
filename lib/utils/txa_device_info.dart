import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../services/txa_version.dart';

class TxaDeviceInfo {
  static Map<String, String>? _cachedSpecs;

  /// Check if the device is Rooted (Android) or Jailbroken (iOS)
  static Future<bool> checkIsRootedOrJailbroken() async {
    if (kIsWeb) return false;

    try {
      if (Platform.isAndroid) {
        // 1. Check Android build tags for test-keys
        final deviceInfoPlugin = DeviceInfoPlugin();
        final androidInfo = await deviceInfoPlugin.androidInfo;
        if (androidInfo.tags.contains('test-keys')) return true;

        // 2. Check common Android Root SU binary locations
        final rootPaths = [
          '/system/app/Superuser.apk',
          '/sbin/su',
          '/system/bin/su',
          '/system/xbin/su',
          '/data/local/xbin/su',
          '/data/local/bin/su',
          '/system/sd/xbin/su',
          '/system/bin/failsafe/su',
          '/data/local/su',
          '/su/bin/su',
          '/magisk/.core/bin/su',
        ];
        for (final path in rootPaths) {
          if (File(path).existsSync()) return true;
        }
      } else if (Platform.isIOS) {
        // Check common iOS Jailbreak paths and apps
        final jbPaths = [
          '/Applications/Cydia.app',
          '/Library/MobileSubstrate/MobileSubstrate.dylib',
          '/bin/bash',
          '/usr/sbin/sshd',
          '/etc/apt',
          '/private/var/lib/apt',
          '/private/var/lib/cydia',
          '/private/var/mobile/Library/SBSettings/Themes',
          '/Applications/Sileo.app',
          '/Applications/Zebra.app',
          '/var/binpack',
          '/Applications/FlyJB.app',
        ];
        for (final path in jbPaths) {
          if (File(path).existsSync()) return true;
        }
      }
    } catch (_) {}

    return false;
  }

  /// Fetch comprehensive hardware, system, root status and diagnostic metadata
  static Future<Map<String, String>> getDiagnosticMetadata() async {
    if (_cachedSpecs != null) return _cachedSpecs!;

    final Map<String, String> specs = {};

    try {
      final deviceInfoPlugin = DeviceInfoPlugin();

      // 1. Check Root / Jailbreak Status
      final isRooted = await checkIsRootedOrJailbroken();
      specs['Trạng Thái Root / JB'] = isRooted
          ? '⚠️ CẢNH BÁO: ĐÃ ROOT / JAILBREAK (Rooted / Jailbroken Device)'
          : '🛡️ AN TOÀN: CHƯA ROOT / CHƯA JAILBREAK (Original System)';

      // 2. Screen resolution & pixel ratio
      try {
        final views = PlatformDispatcher.instance.views;
        if (views.isNotEmpty) {
          final view = views.first;
          final size = view.physicalSize;
          final ratio = view.devicePixelRatio;
          final dpWidth = (size.width / ratio).round();
          final dpHeight = (size.height / ratio).round();
          specs['Màn Hình'] = '${size.width.toInt()}x${size.height.toInt()} px (${dpWidth}x$dpHeight dp @${ratio.toStringAsFixed(1)}x Density)';
        }
      } catch (_) {}

      // 3. Timezone, Locale & Processors
      final now = DateTime.now();
      final timeZone = now.timeZoneName;
      final timeOffset = now.timeZoneOffset;
      final offsetHours = timeOffset.inHours.toString().padLeft(2, '0');
      final offsetMins = (timeOffset.inMinutes % 60).abs().toString().padLeft(2, '0');
      final sign = timeOffset.isNegative ? '-' : '+';
      specs['Múi Giờ Hệ Thống'] = '$timeZone (UTC$sign$offsetHours:$offsetMins)';
      specs['Ngôn Ngữ Locale'] = Platform.localeName;
      specs['Số Nhân CPU Cores'] = '${Platform.numberOfProcessors} CPU Cores';

      // 4. Detailed Platform specific attributes
      if (kIsWeb) {
        specs['Hệ Điều Hành'] = 'Trình Duyệt Web Browser';
        specs['Loại Thiết Bị'] = 'Web Client';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        specs['Hệ Điều Hành'] = '${iosInfo.systemName} ${iosInfo.systemVersion}';
        specs['Tên Thiết Bị'] = iosInfo.name.isNotEmpty ? iosInfo.name : 'Apple iOS Device';
        specs['Model / Mã Máy'] = '${iosInfo.model} (${iosInfo.utsname.machine})';
        specs['Localized Model'] = iosInfo.localizedModel;
        specs['Loại Thiết Bị'] = iosInfo.isPhysicalDevice ? 'Thiết Bị Thật (Physical Device)' : 'Máy Ảo (iOS Simulator)';
        specs['Vendor Identifier'] = iosInfo.identifierForVendor ?? 'N/A';
        specs['Nhân Kernel'] = '${iosInfo.utsname.sysname} ${iosInfo.utsname.release} (${iosInfo.utsname.version.split('\n').first})';
        specs['Node Name'] = iosInfo.utsname.nodename;
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        specs['Hệ Điều Hành'] = 'Android ${androidInfo.version.release} (API ${androidInfo.version.sdkInt})';
        specs['Bản Vá Security'] = androidInfo.version.securityPatch ?? 'N/A';
        specs['Tên Thiết Bị'] = '${androidInfo.brand} ${androidInfo.model} (${androidInfo.manufacturer})';
        specs['Model / Sản Phẩm'] = '${androidInfo.product} (Device: ${androidInfo.device})';
        specs['Build Fingerprint'] = androidInfo.fingerprint;
        specs['Build ID / Type'] = '${androidInfo.id} (${androidInfo.type})';
        specs['Bootloader / Host'] = '${androidInfo.bootloader} / ${androidInfo.host}';
        specs['Kiến Trúc CPU (ABIs)'] = androidInfo.supportedAbis.join(', ');
        specs['Loại Thiết Bị'] = androidInfo.isPhysicalDevice ? 'Thiết Bị Thật (Physical Device)' : 'Giả Lập (Android Emulator)';
        specs['Bo Mạch / Hardware'] = '${androidInfo.board} / ${androidInfo.hardware}';
        specs['Tags Hệ Thống'] = androidInfo.tags;
      } else if (Platform.isWindows) {
        final winInfo = await deviceInfoPlugin.windowsInfo;
        specs['Hệ Điều Hành'] = 'Windows ${winInfo.majorVersion}.${winInfo.minorVersion} (Build ${winInfo.buildNumber})';
        specs['Tên Máy Tính'] = winInfo.computerName;
        specs['Số Nhân CPU'] = '${winInfo.numberOfCores} Cores';
        specs['Bộ Nhớ RAM System'] = '${(winInfo.systemMemoryInMegabytes / 1024).toStringAsFixed(2)} GB';
        specs['Product Name'] = winInfo.productName;
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfoPlugin.macOsInfo;
        specs['Hệ Điều Hành'] = 'macOS ${macInfo.osRelease} (${macInfo.kernelVersion})';
        specs['Model Máy'] = macInfo.model;
        specs['Tên Máy Tính'] = macInfo.computerName;
        specs['CPU Cores / RAM'] = '${macInfo.activeCPUs} Cores / ${(macInfo.memorySize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfoPlugin.linuxInfo;
        specs['Hệ Điều Hành'] = 'Linux ${linuxInfo.name} (${linuxInfo.versionId})';
        specs['Pretty Name'] = linuxInfo.prettyName;
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
    sb.writeln('📱 THÔNG TIN THIẾT BỊ & PHẦN CỨNG (SYSTEM & HARDWARE):');
    
    specs.forEach((key, val) {
      sb.writeln('• ${key.padRight(24)}: $val');
    });

    sb.writeln('\n📦 THÔNG TIN ỨNG DỤNG & MÔI TRƯỜNG (APP & RUNTIME):');
    sb.writeln('• ${'Tên Ứng Dụng'.padRight(24)}: DongMePhim Mobile Premium');
    sb.writeln('• ${'Phiên Bản App'.padRight(24)}: ${TxaVersion.version} (Build 533)');
    sb.writeln('• ${'Dart / Flutter Runtime'.padRight(24)}: ${Platform.version.split(' ').first}');
    sb.writeln('• ${'Nền Tảng HĐH'.padRight(24)}: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');

    sb.writeln('\n📊 CHI TIẾT NHẬT KÝ (LOG METADATA):');
    sb.writeln('• ${'Thời Gian Sao Chép'.padRight(24)}: $nowStr');
    sb.writeln('• ${'Loại Nhật Ký'.padRight(24)}: $logType');
    sb.writeln('• ${'Mốc Thời Gian Log'.padRight(24)}: $timestamp');
    sb.writeln('• ${'Trạng Thái Hệ Thống'.padRight(24)}: $status');
    sb.writeln('=================================================================');

    return sb.toString();
  }
}
