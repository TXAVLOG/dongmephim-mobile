import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class TxaLogger {
  static String? _cachedLogPath;
  static bool _fileWriteEnabled = true; // Only write to file when app is active or transitioning

  static Future<String> get _logPath async {
    if (_cachedLogPath != null) return _cachedLogPath!;
    final docDir = await getApplicationDocumentsDirectory();
    final logDir = Directory('${docDir.path}/Logs');
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    _cachedLogPath = logDir.path;
    return _cachedLogPath!;
  }

  static void init() {
    // Catch Flutter Framework Errors
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      log(
        'FLUTTER EXCEPTION: ${details.exceptionAsString()}\n${details.stack}',
        type: 'crash',
      );
    };

    // Catch Platform Errors (Asynchronous)
    PlatformDispatcher.instance.onError = (error, stack) {
      log(
        'PLATFORM EXCEPTION: $error\n$stack',
        type: 'crash',
      );
      return true;
    };

    // App lifecycle observer for file logging control
    _AppLifecycleObserver.init();

    log('TxaLogger initialized. Global tracker active.', type: 'app');
  }

  static Future<void> log(
    String message, {
    String type = 'app', // 'app', 'api', 'downloader', 'crash'
  }) async {
    try {
      // Always print to debug console
      debugPrint('[$type] $message');

      // Only write to file when enabled (app active or lifecycle transition)
      if (!_fileWriteEnabled) return;

      final path = await _logPath;
      final now = DateTime.now();
      final timestamp = DateFormat('HH:mm:ss.SSS').format(now);
      final logLine = '[$timestamp] [${type.toUpperCase()}] $message\n';

      final date = DateFormat('yyyy-MM-dd').format(now);

      // 1. Write to specific log type file
      final typeFile = File('$path/${type}_$date.log');
      await typeFile.writeAsString(logLine, mode: FileMode.append, flush: true);

      // 2. ALSO write to "all" log file
      if (type != 'all') {
        final allFile = File('$path/all_$date.log');
        await allFile.writeAsString(logLine, mode: FileMode.append, flush: true);
      }
    } catch (e) {
      debugPrint('Failed to write log: $e');
    }
  }

  static Future<void> logApi({
    required String method,
    required String path,
    int? statusCode,
    String? responseBody,
  }) async {
    final statusStr = statusCode != null ? 'STATUS: $statusCode' : 'STATUS: ERROR';
    String message = '$method $path - $statusStr';
    if (responseBody != null && responseBody.trim().isNotEmpty) {
      String cleanBody = responseBody.trim();
      if (cleanBody.length > 500) {
        cleanBody = '${cleanBody.substring(0, 500)}... [truncated]';
      }
      message += '\n[response] $cleanBody';
    }
    await log(message, type: 'api');
  }

  static Future<String> readLogs(String type) async {
    try {
      final path = await _logPath;
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final file = File('$path/${type}_$date.log');
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (e) {
      debugPrint('Failed to read logs: $e');
    }
    return '';
  }

  static Future<void> clearLogs() async {
    try {
      final path = await _logPath;
      final dir = Directory(path);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        _cachedLogPath = null;
      }
    } catch (e) {
      debugPrint('Failed to clear logs: $e');
    }
  }

  static Future<void> shareLogs(String type) async {
    try {
      final path = await _logPath;
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final file = File('$path/${type}_$date.log');
      if (await file.exists()) {
        // ignore: deprecated_member_use
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'DongMePhim Log Files - $type',
        );
      } else {
        debugPrint('Log file not found to share');
      }
    } catch (e) {
      debugPrint('Failed to share logs: $e');
    }
  }
}

/// Lifecycle observer that controls file logging.
/// Only writes to file when user enters the app (resumed) or exits to background (paused).
/// Background processes running while user is still in-app don't write to file.
class _AppLifecycleObserver extends WidgetsBindingObserver {
  static _AppLifecycleObserver? _instance;

  static void init() {
    _instance ??= _AppLifecycleObserver();
    WidgetsBinding.instance.addObserver(_instance!);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // User enters app → enable file logging
        TxaLogger._fileWriteEnabled = true;
        TxaLogger.log('App resumed (foreground)', type: 'app');
        break;
      case AppLifecycleState.paused:
        // User exits app → log the event, then disable after short delay
        TxaLogger._fileWriteEnabled = true;
        TxaLogger.log('App paused (background)', type: 'app');
        // Disable file writing after logging the transition
        Future.delayed(const Duration(milliseconds: 500), () {
          TxaLogger._fileWriteEnabled = false;
        });
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // Other background states → disable file writing
        TxaLogger._fileWriteEnabled = false;
        break;
    }
  }
}
