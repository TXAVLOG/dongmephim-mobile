import 'dart:io';
import 'package:flutter/foundation.dart';
import 'txa_google_auth_strategy.dart';
import 'strategies/mobile_google_auth_strategy.dart';
import 'strategies/desktop_google_auth_strategy.dart';
import 'strategies/tv_google_auth_strategy.dart';
import '../../utils/txa_platform.dart';

class TxaGoogleAuthFactory {
  static TxaGoogleAuthStrategy create() {
    if (kIsWeb) {
      // Fallback cho Web nếu cần, tạm thời dùng Desktop loopback hoặc Mobile (nếu hỗ trợ web)
      // google_sign_in có hỗ trợ web.
      return MobileGoogleAuthStrategy();
    }
    
    if (TxaPlatform.isTV) {
      return TvGoogleAuthStrategy();
    }

    if (Platform.isAndroid || Platform.isIOS) {
      return MobileGoogleAuthStrategy();
    }

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return DesktopGoogleAuthStrategy();
    }

    // Fallback an toàn nhất
    return DesktopGoogleAuthStrategy();
  }
}
