import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:open_file/open_file.dart';
import '../utils/txa_format.dart';
import '../utils/txa_logger.dart';
import 'txa_language.dart';

class TxaDownload {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(minutes: 5),
    headers: {
      'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    },
  ));
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool isDownloading = false;
  int downloadedBytes = 0;
  int totalBytes = 0;
  DateTime? startTime;
  DateTime? lastUpdateTime;
  CancelToken? _cancelToken;
  String? lastError;

  // For reactive speed calculation
  int _lastBytesSnapshot = 0;
  DateTime? _lastSnapshotTime;
  double _currentSpeed = 0.0;

  TxaDownload() {
    _initNotifications();
  }

  void _initNotifications() async {
    if (!Platform.isAndroid) return;
    const android = AndroidInitializationSettings('@mipmap/launcher_icon');
    await _notifications.initialize(
      settings: const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: (details) async {
        final String? payload = details.payload;
        if (payload != null && payload.isNotEmpty) {
          TxaLogger.log("Opening file from notification: $payload");
          await OpenFile.open(payload);
        }
      },
    );
  }

  /// Start direct file download
  Future<File?> startDownload(
    String url,
    String filename, {
    Function(Map<String, dynamic>)? onProgress,
    bool showNotification = true,
  }) async {
    try {
      lastError = null;
      isDownloading = true;
      startTime = DateTime.now();

      String savePath = '';
      if (Platform.isAndroid) {
        final dir = await getTemporaryDirectory();
        savePath = '${dir.path}/$filename';
      } else if (Platform.isWindows) {
        final dir = await getDownloadsDirectory() ?? await getTemporaryDirectory();
        savePath = '${dir.path}/$filename';
      } else {
        final dir = await getTemporaryDirectory();
        savePath = '${dir.path}/$filename';
      }

      if (showNotification && Platform.isAndroid) {
        await _updateNotification(0, filename, 'Bắt đầu tải...');
      }

      _cancelToken = CancelToken();

      await _dio.download(
        url,
        savePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          downloadedBytes = received;
          totalBytes = total;

          final now = DateTime.now();

          // Calculate snapshots every 1 second for reactive speed
          if (_lastSnapshotTime == null ||
              now.difference(_lastSnapshotTime!).inMilliseconds >= 1000) {
            if (_lastSnapshotTime != null) {
              final deltaBytes = received - _lastBytesSnapshot;
              final deltaTime =
                  now.difference(_lastSnapshotTime!).inMilliseconds / 1000.0;
              if (deltaTime > 0) {
                _currentSpeed = deltaBytes / deltaTime;
              }
            }
            _lastBytesSnapshot = received;
            _lastSnapshotTime = now;
          }

          final info = getProgressInfo();

          if (onProgress != null) {
            onProgress(info);
          }

          if (showNotification && total > 0 && Platform.isAndroid) {
            if (lastUpdateTime == null ||
                now.difference(lastUpdateTime!).inMilliseconds >= 1500 ||
                received == total) {
              lastUpdateTime = now;
              final speedFormatted = info['formatted']['speed'];
              final body =
                  "🚀 $speedFormatted • ⏳ ETA: ${info['formatted']['eta']}\n📦 ${info['formatted']['downloaded']} / ${info['formatted']['total']}";
              _updateNotification(received * 100 ~/ total, filename, body);
            }
          }
        },
      );

      if (showNotification && Platform.isAndroid) {
        final String title = TxaLanguage.t('download_finished');
        final String body = TxaLanguage.t('click_to_install');
        await _completeNotification(
          filename,
          '✅ $title $body',
          payload: savePath,
        );
      }

      isDownloading = false;
      return File(savePath);
    } catch (e) {
      isDownloading = false;
      if (e is DioException) {
        if (CancelToken.isCancel(e)) {
          lastError = 'Đã hủy tải 🛑';
        } else if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError) {
          lastError = TxaLanguage.t('download_failed_network');
        } else if (e.response != null) {
          lastError = TxaLanguage.t('download_failed_server');
        }
      }

      if (showNotification && Platform.isAndroid) {
        await _completeNotification(filename, '❌ $lastError');
      }
      return null;
    }
  }

  void cancelDownload() {
    _cancelToken?.cancel("User cancelled");
    isDownloading = false;
  }

  Map<String, dynamic> getProgressInfo() {
    final now = DateTime.now();

    // Average speed for overall ETA
    final durationSoFar = startTime != null
        ? now.difference(startTime!).inSeconds
        : 0;
    final avgSpeed = durationSoFar > 0 ? downloadedBytes / durationSoFar : 0.0;

    // Current reactive speed for UI
    final speed = _currentSpeed > 0 ? _currentSpeed : avgSpeed;

    final progress = totalBytes > 0
        ? (downloadedBytes / totalBytes) * 100
        : 0.0;
    final remainingBytes = totalBytes - downloadedBytes;
    final etaSeconds = speed > 0 ? (remainingBytes / speed).toInt() : 0;

    return {
      'progress': progress,
      'downloaded': downloadedBytes,
      'total': totalBytes,
      'speed': speed,
      'eta': etaSeconds,
      'formatted': {
        'downloaded': TxaFormat.formatSize(downloadedBytes)['display'],
        'total': TxaFormat.formatSize(totalBytes)['display'],
        'speed': TxaFormat.formatSpeed(speed, decimals: 2)['display'],
        'eta': TxaFormat.formatDuration(etaSeconds),
      },
    };
  }

  Future<void> _updateNotification(
    int progress,
    String title,
    String body,
  ) async {
    if (!Platform.isAndroid) return;
    final android = AndroidNotificationDetails(
      'txa_download',
      'TPhimX Tải về',
      icon: '@mipmap/launcher_icon',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.service,
      showProgress: true,
      maxProgress: 100,
      progress: progress,
      ongoing: true,
      onlyAlertOnce: true,
      actions: [
        AndroidNotificationAction(
          'cancel_download',
          TxaLanguage.t('cancel'),
          showsUserInterface: true,
        ),
      ],
    );

    // iOS doesn't support progress bars in notifications natively via this plugin
    const ios = DarwinNotificationDetails(
      presentAlert: false, // Don't buzz every 1.5s
      presentBadge: false,
      presentSound: false,
      threadIdentifier: 'download_status',
    );

    await _notifications.show(
      id: 1,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: android, iOS: ios),
    );
  }

  Future<void> _completeNotification(
    String title,
    String body, {
    String? payload,
  }) async {
    if (!Platform.isAndroid) return;
    const android = AndroidNotificationDetails(
      'txa_download',
      'TPhimX Tải về',
      icon: '@mipmap/launcher_icon',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: false,
    );
    await _notifications.show(
      id: 1,
      title: title,
      body: body,
      payload: payload,
      notificationDetails: const NotificationDetails(android: android),
    );
  }
}
