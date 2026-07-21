import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'txa_api.dart';
import 'txa_auth_service.dart';
import 'txa_version.dart';
import '../pages/txa_movie_detail_screen.dart';
import '../tv/screens/tv_movie_detail_screen.dart';
import '../utils/txa_platform.dart';
import '../utils/txa_logger.dart';
import '../main.dart';

class TxaNotificationManager {
  static final TxaNotificationManager instance = TxaNotificationManager._internal();

  TxaNotificationManager._internal();

  Timer? _timer;
  final Set<String> _shownNotifications = {};
  bool _initialized = false;
  final FlutterLocalNotificationsPlugin _localNotif = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Initialize cross-platform local notifications (Android, Smart TV, iOS, Desktop)
    await _initLocalNotifications();

    // Start periodic polling every 30 seconds
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _pollNotifications();
      _checkBackgroundUpdates();
    });

    // Run checks immediately on start
    _pollNotifications();
    _checkBackgroundUpdates();
  }

  Future<void> _initLocalNotifications() async {
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );

      await _localNotif.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            _handleNotificationPayload(payload);
          }
        },
      );

      // Create Android & Smart TV notification channel
      if (Platform.isAndroid) {
        const channel = AndroidNotificationChannel(
          'txa_notifications',
          'Thông báo DongMePhim',
          description: 'Thông báo phim mới, cập nhật ứng dụng và hệ thống',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        );

        final androidImpl = _localNotif
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        
        if (androidImpl != null) {
          await androidImpl.createNotificationChannel(channel);
          await androidImpl.requestNotificationsPermission();
        }
      }
    } catch (e) {
      TxaLogger.log('Notification initialization error: $e');
    }
  }

  void dispose() {
    _timer?.cancel();
    _initialized = false;
  }

  Future<void> _checkBackgroundUpdates() async {
    try {
      final updateInfo = await TxaApi().getCheckUpdate();
      if (updateInfo != null) {
        final latestVersion = updateInfo['app_version']?.toString() ?? '';
        if (latestVersion.isNotEmpty && latestVersion != TxaVersion.version) {
          final notifId = 'app_update_$latestVersion';
          if (!_shownNotifications.contains(notifId)) {
            _shownNotifications.add(notifId);
            
            final downloadUrl = Platform.isWindows
                ? (updateInfo['windows_download_url'] ?? updateInfo['download_url'] ?? '')
                : (updateInfo['download_url'] ?? updateInfo['apk_download_url'] ?? '');

            await _showNativeNotification(
              id: notifId,
              title: '🚀 Cập nhật DongMePhim v$latestVersion',
              body: 'Đã có phiên bản mới với nhiều cải tiến. Nhấp để tải xuống và cài đặt ngay!',
              payload: 'update:$downloadUrl',
            );
          }
        }
      }
    } catch (e) {
      TxaLogger.log('Background update check error: $e');
    }
  }

  Future<void> _pollNotifications() async {
    final auth = TxaAuthService();
    if (!auth.isLoggedIn) return;

    try {
      final response = await TxaApi().getNotifications();
      if (response == null || response['success'] != true) return;

      final prefs = await SharedPreferences.getInstance();
      final lastPollTimeStr = prefs.getString('txa_last_notification_poll_time');
      final now = DateTime.now().toUtc();
      
      DateTime lastPollTime;
      if (lastPollTimeStr != null) {
        try {
          lastPollTime = DateTime.parse(lastPollTimeStr).toUtc();
        } catch (_) {
          lastPollTime = now.subtract(const Duration(minutes: 5));
        }
      } else {
        lastPollTime = now.subtract(const Duration(minutes: 5));
      }

      final list = response['data'] as List? ?? [];
      for (var item in list) {
        final id = item['id']?.toString() ?? '';
        final isRead = item['is_read'] == true;
        if (id.isEmpty || isRead) continue;

        final createdAtStr = item['created_at'] ?? '';
        if (createdAtStr.isNotEmpty) {
          try {
            final createdAt = DateTime.parse(createdAtStr).toUtc();
            if (createdAt.isBefore(lastPollTime)) {
              continue;
            }
          } catch (_) {}
        }

        if (!_shownNotifications.contains(id)) {
          _shownNotifications.add(id);
          final movieSlug = item['movie_slug'] ?? '';
          final payload = movieSlug.isNotEmpty ? 'movie:$movieSlug:$id' : 'notif:$id';
          
          await _showNativeNotification(
            id: id,
            title: item['title'] ?? 'Thông báo mới',
            body: item['body'] ?? '',
            payload: payload,
          );
        }
      }

      await prefs.setString('txa_last_notification_poll_time', now.toIso8601String());
    } catch (e) {
      TxaLogger.log('Poll notifications error: $e');
    }
  }

  Future<void> _showNativeNotification({
    required String id,
    required String title,
    required String body,
    required String payload,
  }) async {
    final int numericId = id.hashCode & 0x7FFFFFFF;

    if (TxaPlatform.isDesktop) {
      try {
        final LocalNotification notification = LocalNotification(
          identifier: id,
          title: title,
          body: body,
          actions: [
            LocalNotificationAction(text: 'Mở ngay'),
          ],
        );
        notification.onClick = () {
          _handleNotificationPayload(payload);
        };
        notification.onClickAction = (index) {
          if (index == 0) {
            _handleNotificationPayload(payload);
          }
        };
        await notification.show();
        return;
      } catch (_) {
        // Fallback to flutter_local_notifications on desktop if localNotifier fails
      }
    }

    // Android, Smart TV, iOS, and fallback Desktop
    const androidDetails = AndroidNotificationDetails(
      'txa_notifications',
      'Thông báo DongMePhim',
      channelDescription: 'Thông báo phim mới, cập nhật ứng dụng và hệ thống',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    await _localNotif.show(
      id: numericId,
      title: title,
      body: body,
      payload: payload,
      notificationDetails: details,
    );
  }

  void _handleNotificationPayload(String payload) {
    if (payload.startsWith('update:')) {
      final url = payload.substring(7);
      _handleOpenUpdateUrl(url);
    } else if (payload.startsWith('movie:')) {
      final parts = payload.substring(6).split(':');
      final slug = parts.isNotEmpty ? parts[0] : '';
      final notifId = parts.length > 1 ? parts[1] : '';
      if (notifId.isNotEmpty) {
        TxaApi().markNotificationRead(notifId);
      }
      _handleOpenMovie(slug);
    } else if (payload.startsWith('notif:')) {
      final notifId = payload.substring(6);
      TxaApi().markNotificationRead(notifId);
    } else if (payload.startsWith('http://') || payload.startsWith('https://')) {
      _handleOpenUpdateUrl(payload);
    }
  }

  Future<void> _handleOpenUpdateUrl(String url) async {
    if (url.isNotEmpty) {
      try {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        TxaLogger.log('Open update URL error: $e');
      }
    }
  }

  Future<void> _handleOpenMovie(String movieSlug) async {
    if (movieSlug.isNotEmpty) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => TxaPlatform.isTV
              ? TvMovieDetailScreen(slug: movieSlug)
              : MovieDetailScreen(slug: movieSlug),
        ),
      );
    }
  }
}
