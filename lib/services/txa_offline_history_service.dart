import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'txa_api.dart';
import 'txa_auth_service.dart';
import '../utils/txa_logger.dart';

class TxaOfflineHistoryItem {
  final String movieId;
  final String episodeId;
  final double currentTime;
  final double duration;
  final int serverIndex;
  final String updatedAt;
  final bool synced;

  TxaOfflineHistoryItem({
    required this.movieId,
    required this.episodeId,
    required this.currentTime,
    required this.duration,
    required this.serverIndex,
    required this.updatedAt,
    this.synced = false,
  });

  Map<String, dynamic> toJson() => {
        'movieId': movieId,
        'episodeId': episodeId,
        'currentTime': currentTime,
        'duration': duration,
        'serverIndex': serverIndex,
        'updatedAt': updatedAt,
        'synced': synced,
      };

  factory TxaOfflineHistoryItem.fromJson(Map<String, dynamic> json) {
    return TxaOfflineHistoryItem(
      movieId: json['movieId']?.toString() ?? '',
      episodeId: json['episodeId']?.toString() ?? '',
      currentTime: (json['currentTime'] as num?)?.toDouble() ?? 0.0,
      duration: (json['duration'] as num?)?.toDouble() ?? 0.0,
      serverIndex: json['serverIndex'] as int? ?? 0,
      updatedAt: json['updatedAt']?.toString() ?? DateTime.now().toIso8601String(),
      synced: json['synced'] == true,
    );
  }
}

class TxaOfflineHistoryService {
  static const String _prefKey = 'txa_offline_watch_history_v2';
  static bool _isSyncing = false;

  /// Lưu tiến độ xem cục bộ (Offline & Online fallback)
  static Future<void> saveLocalProgress({
    required String movieId,
    required String episodeId,
    required double currentTime,
    required double duration,
    required int serverIndex,
    bool synced = false,
  }) async {
    if (movieId.isEmpty || episodeId.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      Map<String, dynamic> map = {};
      if (raw != null && raw.isNotEmpty) {
        try {
          map = jsonDecode(raw) as Map<String, dynamic>;
        } catch (_) {}
      }

      final key = '${movieId}_$episodeId';
      final item = TxaOfflineHistoryItem(
        movieId: movieId,
        episodeId: episodeId,
        currentTime: currentTime,
        duration: duration,
        serverIndex: serverIndex,
        updatedAt: DateTime.now().toIso8601String(),
        synced: synced,
      );

      map[key] = item.toJson();
      await prefs.setString(_prefKey, jsonEncode(map));
    } catch (e) {
      TxaLogger.log('Lỗi khi lưu offline watch history: $e', type: 'app');
    }
  }

  /// Lấy vị trí giây xem đã lưu cục bộ (dành cho phát Offline resume)
  static Future<double?> getLocalProgress(String movieId, String episodeId) async {
    if (movieId.isEmpty || episodeId.isEmpty) return null;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw == null || raw.isEmpty) return null;

      final map = jsonDecode(raw) as Map<String, dynamic>;
      final key = '${movieId}_$episodeId';
      if (map.containsKey(key)) {
        final item = TxaOfflineHistoryItem.fromJson(map[key] as Map<String, dynamic>);
        return item.currentTime;
      }
    } catch (_) {}
    return null;
  }

  /// Đồng bộ toàn bộ lịch sử xem offline lên CSDL máy chủ khi có mạng
  static Future<void> syncPendingHistory() async {
    final auth = TxaAuthService();
    if (!auth.isLoggedIn || _isSyncing) return;

    _isSyncing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw == null || raw.isEmpty) {
        _isSyncing = false;
        return;
      }

      final map = jsonDecode(raw) as Map<String, dynamic>;
      final List<String> keysToUpdate = [];
      final List<TxaOfflineHistoryItem> pendingItems = [];

      map.forEach((k, v) {
        if (v is Map<String, dynamic>) {
          final item = TxaOfflineHistoryItem.fromJson(v);
          if (!item.synced && item.currentTime > 0) {
            keysToUpdate.add(k);
            pendingItems.add(item);
          }
        }
      });

      if (pendingItems.isEmpty) {
        _isSyncing = false;
        return;
      }

      TxaLogger.log('🔄 Bắt đầu đồng bộ ${pendingItems.length} bản ghi lịch sử xem Offline lên máy chủ...', type: 'api');

      for (int i = 0; i < pendingItems.length; i++) {
        final item = pendingItems[i];
        final key = keysToUpdate[i];

        try {
          final success = await TxaApi().updateWatchHistory(
            item.movieId,
            item.episodeId,
            item.currentTime,
            item.duration,
            item.serverIndex,
          );

          if (success) {
            final updatedItem = TxaOfflineHistoryItem(
              movieId: item.movieId,
              episodeId: item.episodeId,
              currentTime: item.currentTime,
              duration: item.duration,
              serverIndex: item.serverIndex,
              updatedAt: item.updatedAt,
              synced: true,
            );
            map[key] = updatedItem.toJson();
            TxaLogger.log('✅ Đã đồng bộ lịch sử offline: ${item.movieId} - ${item.episodeId} (${item.currentTime.toInt()}s)', type: 'api');
          }
        } catch (err) {
          TxaLogger.log('❌ Lỗi khi đồng bộ item ${item.movieId}: $err', type: 'crash');
        }
      }

      await prefs.setString(_prefKey, jsonEncode(map));
    } catch (e) {
      TxaLogger.log('❌ Lỗi trong quá trình syncPendingHistory: $e', type: 'crash');
    } finally {
      _isSyncing = false;
    }
  }
}
