import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/txa_api.dart';
import '../services/txa_auth_service.dart';
import '../services/txa_version.dart';
import '../utils/txa_logger.dart';

/// Result khi check device với server
class TxaDeviceCheckResult {
  final bool isBlocked;
  final String? blockReason;

  const TxaDeviceCheckResult({
    required this.isBlocked,
    this.blockReason,
  });
}

/// Thu thập device fingerprint ổn định + gửi lên server để log & kiểm tra block
class TxaDeviceFingerprintService {
  static final TxaDeviceFingerprintService _instance =
      TxaDeviceFingerprintService._internal();
  factory TxaDeviceFingerprintService() => _instance;
  TxaDeviceFingerprintService._internal();

  static const _prefsFingerprintKey = 'txa_device_fingerprint';

  String? _cachedFingerprint;
  String? get fingerprint => _cachedFingerprint;

  // ─────────────────────────────────────────────
  // PUBLIC: Gọi khi app khởi động
  // ─────────────────────────────────────────────

  /// Khởi tạo, gửi log lên server và trả về kết quả block.
  Future<TxaDeviceCheckResult> initAndCheck() async {
    try {
      final fp = await _getOrGenerateFingerprint();
      _cachedFingerprint = fp;

      final deviceData = await _collectDeviceInfo(fp);
      return await _sendToServer(deviceData);
    } catch (e) {
      TxaLogger.log('DeviceFingerprintService error: $e', type: 'app');
      return const TxaDeviceCheckResult(isBlocked: false);
    }
  }

  // ─────────────────────────────────────────────
  // FINGERPRINT: Lấy hoặc tạo mới fingerprint ổn định
  // ─────────────────────────────────────────────

  Future<String> _getOrGenerateFingerprint() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_prefsFingerprintKey);
    if (cached != null && cached.isNotEmpty) return cached;

    final fp = await _buildHardwareFingerprint();
    await prefs.setString(_prefsFingerprintKey, fp);
    return fp;
  }

  Future<String> _buildHardwareFingerprint() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      String raw = '';

      if (kIsWeb) {
        // Web: tạo UUID ngẫu nhiên lưu localStorage (SharedPrefs)
        final prefs = await SharedPreferences.getInstance();
        var webId = prefs.getString('txa_web_browser_id');
        if (webId == null) {
          webId = _generateUUID();
          await prefs.setString('txa_web_browser_id', webId);
        }
        raw = 'web:$webId';
      } else if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        // ANDROID_ID: ổn định đến factory reset
        raw = 'android:${info.id}:${info.serialNumber}';
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        // identifierForVendor: ổn định đến khi gỡ hết app cùng vendor
        raw = 'ios:${info.identifierForVendor ?? info.name}';
      } else if (Platform.isWindows) {
        final info = await deviceInfo.windowsInfo;
        // deviceId = Machine GUID từ registry
        raw = 'windows:${info.deviceId}:${info.computerName}';
      } else if (Platform.isLinux) {
        final info = await deviceInfo.linuxInfo;
        raw = 'linux:${info.machineId ?? info.name}';
      } else {
        raw = 'other:${Platform.operatingSystem}:${_generateUUID()}';
      }

      // Hash để ẩn raw value
      final bytes = utf8.encode(raw);
      final digest = sha256.convert(bytes);
      return digest.toString().substring(0, 48);
    } catch (e) {
      // Fallback: UUID lưu prefs
      final prefs = await SharedPreferences.getInstance();
      var fallback = prefs.getString('txa_device_fallback_id');
      if (fallback == null) {
        fallback = _generateUUID();
        await prefs.setString('txa_device_fallback_id', fallback);
      }
      return 'fallback:${sha256.convert(utf8.encode(fallback)).toString().substring(0, 40)}';
    }
  }

  // ─────────────────────────────────────────────
  // COLLECT: Thu thập toàn bộ thông tin thiết bị
  // ─────────────────────────────────────────────

  Future<Map<String, dynamic>> _collectDeviceInfo(String fingerprint) async {
    final deviceInfo = DeviceInfoPlugin();
    final auth = TxaAuthService();

    String platform = 'unknown';
    String? deviceName;
    String? deviceModel;
    String? deviceBrand;
    String? osVersion;
    String? buildFp;
    String? screenRes;
    String? locale;
    int? cpuCores;
    bool isRooted = false;
    bool isPhysical = true;

    try {
      if (kIsWeb) {
        final info = await deviceInfo.webBrowserInfo;
        platform = 'web';
        deviceName = info.browserName.name;
        deviceModel = 'Browser';
        deviceBrand = info.vendor ?? '';
        osVersion = info.platform ?? '';
      } else if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        // Phân biệt TV vs Phone
        platform = _isAndroidTV(info) ? 'tv' : 'android';
        deviceName = '${info.brand} ${info.model}';
        deviceModel = info.device;
        deviceBrand = info.brand;
        osVersion = 'Android ${info.version.release} (API ${info.version.sdkInt})';
        buildFp = info.fingerprint;
        isRooted = !info.isPhysicalDevice ? false : false; // no direct root check
        isPhysical = info.isPhysicalDevice;
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        platform = 'ios';
        deviceName = info.name;
        deviceModel = info.model;
        deviceBrand = 'Apple';
        osVersion = '${info.systemName} ${info.systemVersion}';
        isPhysical = info.isPhysicalDevice;
      } else if (Platform.isWindows) {
        final info = await deviceInfo.windowsInfo;
        platform = 'windows';
        deviceName = info.computerName;
        deviceModel = 'PC/Laptop';
        deviceBrand = 'Windows';
        osVersion =
            'Windows ${info.majorVersion}.${info.minorVersion} (Build ${info.buildNumber})';
      } else if (Platform.isLinux) {
        final info = await deviceInfo.linuxInfo;
        platform = 'linux';
        deviceName = info.name;
        osVersion = info.version ?? info.versionId ?? '';
      }
    } catch (_) {}

    // IP từ ipinfo.io (best-effort)
    String? ipAddress;
    try {
      final res = await http
          .get(Uri.parse('https://ipinfo.io/json'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        ipAddress = data['ip'] as String?;
      }
    } catch (_) {}

    // Fallback local IP
    if (ipAddress == null && !kIsWeb) {
      try {
        final interfaces = await NetworkInterface.list(
            type: InternetAddressType.IPv4);
        for (final iface in interfaces) {
          for (final addr in iface.addresses) {
            if (!addr.isLoopback) {
              ipAddress = addr.address;
              break;
            }
          }
          if (ipAddress != null) break;
        }
      } catch (_) {}
    }

    return {
      'device_fingerprint': fingerprint,
      'platform': platform,
      'device_name': deviceName,
      'device_model': deviceModel,
      'device_brand': deviceBrand,
      'os_version': osVersion,
      'app_version': TxaVersion.version,
      'screen_resolution': screenRes,
      'locale': locale ?? Platform.localeName,
      'cpu_cores': cpuCores ?? Platform.numberOfProcessors,
      'is_rooted': isRooted,
      'is_physical_device': isPhysical,
      'build_fingerprint': buildFp,
      'ip_address': ipAddress,
      'user_id': auth.isLoggedIn ? auth.user?['id'] : null,
      'username': auth.isLoggedIn ? auth.user?['username'] : null,
    };
  }

  bool _isAndroidTV(AndroidDeviceInfo info) {
    final model = (info.model ?? '').toLowerCase();
    final device = (info.device ?? '').toLowerCase();
    return model.contains('atv') ||
        model.contains('tv') ||
        device.contains('tv') ||
        (info.systemFeatures.contains('android.software.leanback'));
  }

  // ─────────────────────────────────────────────
  // SEND: Gửi lên server và nhận kết quả block
  // ─────────────────────────────────────────────

  Future<TxaDeviceCheckResult> _sendToServer(
      Map<String, dynamic> data) async {
    try {
      final url = Uri.parse('${TxaApi.baseUrl}/api/app/device-log');
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'X-TXA-API-KEY': TxaApi.apiKey,
            },
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
        final payload = json['data'] as Map<String, dynamic>? ?? {};
        final isBlocked = payload['is_blocked'] == true;
        final reason = payload['block_reason'] as String?;
        TxaLogger.log(
          'DeviceLog: fingerprint reported, blocked=$isBlocked',
          type: 'app',
        );
        return TxaDeviceCheckResult(
            isBlocked: isBlocked, blockReason: reason);
      }
    } catch (e) {
      TxaLogger.log('DeviceLog send error: $e', type: 'app');
    }
    return const TxaDeviceCheckResult(isBlocked: false);
  }

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────

  String _generateUUID() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rand = List<int>.generate(
        16, (_) => DateTime.now().microsecond % 256);
    return sha256
        .convert(utf8.encode('$now-${rand.join('-')}'))
        .toString()
        .substring(0, 36);
  }
}
