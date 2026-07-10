import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import '../../services/txa_api.dart';

class TvDeviceService {
  static final TvDeviceService _instance = TvDeviceService._internal();
  factory TvDeviceService() => _instance;
  TvDeviceService._internal();

  String? _deviceId;
  String? _deviceName;
  String? _deviceModel;
  String? _deviceOs;
  String? _osVersion;
  String? _ipAddress;
  Map<String, dynamic>? _locationInfo;

  String? get deviceId => _deviceId;
  String? get deviceName => _deviceName;
  Map<String, dynamic>? get locationInfo => _locationInfo;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString('txa_tv_device_id');
    
    if (_deviceId == null) {
      // Generate unique device ID
      final random = Random();
      final values = List<int>.generate(16, (i) => random.nextInt(256));
      _deviceId = 'TXTV-${base64Url.encode(values).replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').substring(0, 12).toUpperCase()}';
      await prefs.setString('txa_tv_device_id', _deviceId!);
    }

    await _gatherDeviceDetails();
    await registerDevice();
  }

  Future<void> _gatherDeviceDetails() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      
      if (kIsWeb) {
        _deviceName = 'Web Client';
        _deviceModel = 'Browser';
        _deviceOs = 'Web';
        _osVersion = 'HTML5';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceName = androidInfo.model;
        _deviceModel = androidInfo.device;
        _deviceOs = 'Android TV';
        _osVersion = androidInfo.version.release;
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        _deviceName = windowsInfo.computerName;
        _deviceModel = 'PC';
        _deviceOs = 'Windows';
        _osVersion = '${windowsInfo.majorVersion}.${windowsInfo.minorVersion}';
      } else {
        _deviceName = 'Generic Device';
        _deviceModel = Platform.operatingSystem;
        _deviceOs = Platform.operatingSystem;
        _osVersion = Platform.operatingSystemVersion;
      }

      // Try gathering public IP and location details from ipinfo.io
      try {
        final ipRes = await http.get(Uri.parse('https://ipinfo.io/json')).timeout(const Duration(seconds: 4));
        if (ipRes.statusCode == 200) {
          final info = jsonDecode(ipRes.body) as Map<String, dynamic>;
          _ipAddress = info['ip'];
          _locationInfo = info;
          
          final city = info['city'] ?? '';
          final country = info['country'] ?? '';
          if (city.isNotEmpty && _deviceName != null) {
            _deviceName = "$_deviceName ($city, $country)";
          }
        }
      } catch (e) {
        debugPrint('Failed to fetch public IP/location from ipinfo.io: $e');
      }

      // Try gathering local IP Address if public IP not loaded
      if (_ipAddress == null) {
        try {
          final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
          for (var interface in interfaces) {
            for (var addr in interface.addresses) {
              if (!addr.isLoopback) {
                _ipAddress = addr.address;
                break;
              }
            }
            if (_ipAddress != null) break;
          }
        } catch (_) {
          _ipAddress = '127.0.0.1';
        }
      }
    } catch (e) {
      debugPrint('Error gathering TV device details: $e');
      _deviceName = 'DongMePhim TV';
      _deviceModel = 'Smart TV';
      _deviceOs = 'Android';
      _osVersion = '9.0';
      _ipAddress = '127.0.0.1';
    }
  }

  Future<bool> registerDevice() async {
    if (_deviceId == null) return false;

    final url = Uri.parse('${TxaApi.baseUrl}/api/app/tv-pair');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-TXA-API-KEY': TxaApi.apiKey,
        },
        body: jsonEncode({
          'action': 'register_device',
          'device_id': _deviceId,
          'device_name': _deviceName,
          'device_model': _deviceModel,
          'device_os': _deviceOs,
          'os_version': _osVersion,
          'screen_resolution': '1920x1080', // Default fallback
          'ip_address': _ipAddress,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
    } catch (e) {
      debugPrint('Failed to register TV device to Supabase: $e');
    }
    return false;
  }
}
