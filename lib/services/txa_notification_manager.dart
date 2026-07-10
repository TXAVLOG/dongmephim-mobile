import 'dart:async';
import 'package:flutter/material.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:url_launcher/url_launcher.dart';
import 'txa_api.dart';
import 'txa_auth_service.dart';
import 'txa_version.dart';
import '../pages/txa_movie_detail_screen.dart';
import '../tv/screens/tv_movie_detail_screen.dart';
import '../utils/txa_platform.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; // Import navigatorKey

class TxaNotificationManager {
  static final TxaNotificationManager instance = TxaNotificationManager._internal();

  TxaNotificationManager._internal();

  Timer? _timer;
  final Set<String> _shownNotifications = {};
  bool _initialized = false;

  void init() {
    if (_initialized) return;
    _initialized = true;

    // Start periodic polling every 30 seconds
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _pollNotifications();
      if (TxaPlatform.isDesktop) {
        _checkBackgroundUpdates();
      }
    });

    // Poll once immediately
    _pollNotifications();
    if (TxaPlatform.isDesktop) {
      _checkBackgroundUpdates();
    }
  }

  void dispose() {
    _timer?.cancel();
    _initialized = false;
  }

  Future<void> _checkBackgroundUpdates() async {
    if (!TxaPlatform.isDesktop) return;
    try {
      final updateInfo = await TxaApi().getCheckUpdate();
      if (updateInfo != null) {
        final latestVersion = updateInfo['app_version']?.toString() ?? '';
        if (latestVersion.isNotEmpty && latestVersion != TxaVersion.version) {
          final notifId = 'app_update_$latestVersion';
          if (!_shownNotifications.contains(notifId)) {
            _shownNotifications.add(notifId);
            
            final LocalNotification notification = LocalNotification(
              identifier: notifId,
              title: 'Cập nhật DongMePhim v$latestVersion',
              body: 'Có phiên bản ứng dụng mới. Nhấp để tải xuống và cài đặt ngay!',
              actions: [
                LocalNotificationAction(text: 'Tải ngay'),
              ],
            );

            notification.onClick = () {
              _handleOpenUpdateUrl(updateInfo['download_url'] ?? '');
            };

            notification.onClickAction = (index) {
              if (index == 0) {
                _handleOpenUpdateUrl(updateInfo['download_url'] ?? '');
              }
            };

            await notification.show();
          }
        }
      }
    } catch (_) {
      // Fail silently in background check
    }
  }

  Future<void> _handleOpenUpdateUrl(String url) async {
    if (url.isNotEmpty) {
      try {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (_) {}
    }
  }

  Future<void> _pollNotifications() async {
    final auth = TxaAuthService();
    if (!auth.isLoggedIn) return;

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
      // First start of manager: don't show old notifications, only recent ones in last 5 minutes
      lastPollTime = now.subtract(const Duration(minutes: 5));
    }

    final list = response['data'] as List? ?? [];
    for (var item in list) {
      final id = item['id']?.toString() ?? '';
      final isRead = item['is_read'] == true;
      if (id.isEmpty || isRead) continue;

      // Filter out notifications created before our last check/start time
      final createdAtStr = item['created_at'] ?? '';
      if (createdAtStr.isNotEmpty) {
        try {
          final createdAt = DateTime.parse(createdAtStr).toUtc();
          if (createdAt.isBefore(lastPollTime)) {
            continue;
          }
        } catch (_) {}
      }

      // If we haven't shown this notification in this session yet
      if (!_shownNotifications.contains(id)) {
        _shownNotifications.add(id);
        _showNativeNotification(
          id: id,
          title: item['title'] ?? 'Thông báo mới',
          body: item['body'] ?? '',
          movieSlug: item['movie_slug'] ?? '',
        );
      }
    }

    await prefs.setString('txa_last_notification_poll_time', now.toIso8601String());
  }

  Future<void> _showNativeNotification({
    required String id,
    required String title,
    required String body,
    required String movieSlug,
  }) async {
    if (!TxaPlatform.isDesktop) return;
    final LocalNotification notification = LocalNotification(
      identifier: id,
      title: title,
      body: body,
      actions: [
        LocalNotificationAction(text: 'Mở phim'),
        LocalNotificationAction(text: 'Đánh dấu đã đọc'),
      ],
    );

    notification.onClick = () {
      _handleOpenMovie(id, movieSlug);
    };

    notification.onClickAction = (index) {
      if (index == 0) {
        _handleOpenMovie(id, movieSlug);
      } else if (index == 1) {
        _handleMarkAsRead(id);
      }
    };

    await notification.show();
  }

  Future<void> _handleOpenMovie(String id, String movieSlug) async {
    // 1. Mark as read on backend
    await TxaApi().markNotificationRead(id);
    
    // 2. Open movie screen using global navigator
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

  Future<void> _handleMarkAsRead(String id) async {
    await TxaApi().markNotificationRead(id);
  }
}
