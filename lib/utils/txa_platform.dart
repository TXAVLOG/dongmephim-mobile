import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class TxaPlatform {
  static const MethodChannel _channel = MethodChannel('online.dongmephim/platform');
  
  static bool _isTV = false;
  static bool _isSamsungTV = false;
  static final ValueNotifier<bool> tvEmulationNotifier = ValueNotifier<bool>(false);

  static bool get isTV => _isTV || tvEmulationNotifier.value;
  static bool get isSamsungTV => _isSamsungTV;
  static bool get isMobile => !isTV && (Platform.isAndroid || Platform.isIOS);
  static bool get isWeb => kIsWeb;
  static bool get isDesktop => !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  static Future<void> init() async {
    if (kIsWeb) {
      _isTV = false;
      _isSamsungTV = false;
      return;
    }

    if (Platform.isAndroid) {
      try {
        final bool isAndroidTV = await _channel.invokeMethod('isAndroidTV') ?? false;
        final String deviceBrand = await _channel.invokeMethod('getDeviceBrand') ?? '';
        
        _isTV = isAndroidTV;
        // If it's a TV device and the manufacturer/brand is Samsung
        _isSamsungTV = isAndroidTV && deviceBrand.toLowerCase().contains('samsung');
      } catch (e) {
        debugPrint('TxaPlatform detection error: $e');
        _isTV = false;
        _isSamsungTV = false;
      }
    } else {
      _isTV = false;
      _isSamsungTV = false;
    }
  }

  static Future<void> setFullscreen(bool isFullscreen) async {
    if (isDesktop && Platform.isWindows) {
      try {
        await _channel.invokeMethod('setFullscreen', isFullscreen);
      } catch (e) {
        debugPrint('TxaPlatform setFullscreen error: $e');
      }
    }
  }
}
