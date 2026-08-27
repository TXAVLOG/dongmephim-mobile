import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/txa_download_status.dart';
import '../models/txa_download_task.dart';

class TxaDownloadService extends ChangeNotifier {
  static final TxaDownloadService instance = TxaDownloadService._internal();
  TxaDownloadService._internal() {
    _initDio();
  }

  late final Dio _dio;
  final Map<String, TxaDownloadTask> _tasks = {};
  final Map<String, CancelToken> _cancelTokens = {};

  Map<String, TxaDownloadTask> get tasks => _tasks;
  List<TxaDownloadTask> get taskList => _tasks.values.toList();

  void _initDio() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 45), // Tăng timeout từ 12s lên 45s
        receiveTimeout: const Duration(minutes: 5),   // Cho phép nhận stream lớn 5 phút
        sendTimeout: const Duration(seconds: 45),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
          'Referer': 'https://dongmephim.online/',
        },
      ),
    );
  }

  /// Bắt đầu tải tập phim với cơ chế tự động thử lại (Auto-Retry) và ánh xạ StatusCode
  Future<void> startDownload({
    required String filmSlug,
    required String filmTitle,
    required String filmPoster,
    required String episodeSlug,
    required String episodeName,
    required String streamUrl,
    required String saveDirectoryPath,
  }) async {
    final taskId = '${filmSlug}_$episodeSlug';
    final saveFilePath = '$saveDirectoryPath/${filmSlug}_$episodeSlug.mp4';

    var task = TxaDownloadTask(
      id: taskId,
      filmSlug: filmSlug,
      filmTitle: filmTitle,
      filmPoster: filmPoster,
      episodeSlug: episodeSlug,
      episodeName: episodeName,
      streamUrl: streamUrl,
      localFilePath: saveFilePath,
      status: TxaDownloadStatus.downloading,
      createdAt: DateTime.now(),
    );

    _tasks[taskId] = task;
    notifyListeners();

    final cancelToken = CancelToken();
    _cancelTokens[taskId] = cancelToken;

    int retryCount = 0;
    const maxRetries = 3;
    bool success = false;
    dynamic lastError;

    while (retryCount < maxRetries && !success && !cancelToken.isCancelled) {
      try {
        debugPrint('[TxaDownloadService] Đang tải task $taskId (Lần thử ${retryCount + 1}/$maxRetries)...');

        // Tạo thư mục cha nếu chưa tồn tại
        final file = File(saveFilePath);
        if (!file.parent.existsSync()) {
          file.parent.createSync(recursive: true);
        }

        await _dio.download(
          streamUrl,
          saveFilePath,
          cancelToken: cancelToken,
          deleteOnError: true,
          onReceiveProgress: (received, total) {
            if (total > 0) {
              final progress = received / total;
              _tasks[taskId] = task.copyWith(
                downloadedBytes: received,
                totalBytes: total,
                progress: progress,
                status: TxaDownloadStatus.downloading,
              );
              notifyListeners();
            }
          },
        );

        success = true;
      } catch (e) {
        lastError = e;
        if (cancelToken.isCancelled) break;

        retryCount++;
        if (retryCount < maxRetries) {
          debugPrint('[TxaDownloadService] Gặp sự cố tải, đang thử lại sau ${retryCount * 2} giây...');
          await Future.delayed(Duration(seconds: retryCount * 2));
        }
      }
    }

    _cancelTokens.remove(taskId);

    if (success) {
      _tasks[taskId] = task.copyWith(
        status: TxaDownloadStatus.completed,
        statusCode: TxaDownloadStatusCode.success,
        progress: 1.0,
        completedAt: DateTime.now(),
      );
      notifyListeners();
      debugPrint('[TxaDownloadService] Tải tập phim thành công [Code: 2311]: $taskId');
    } else if (!cancelToken.isCancelled) {
      // Phân tích lỗi sang mã StatusCode chuẩn
      final errorCode = TxaDownloadStatusCode.parseErrorCode(lastError);
      final errorMsg = TxaDownloadStatusCode.getErrorMessage(errorCode);

      _tasks[taskId] = task.copyWith(
        status: TxaDownloadStatus.failed,
        statusCode: errorCode,
        errorMessage: errorMsg,
      );
      notifyListeners();
      debugPrint('[TxaDownloadService] Tải tập phim thất bại [Code: $errorCode - $errorMsg]: $taskId');
    }
  }

  /// Tạm dừng hoặc hủy tác vụ tải
  void cancelDownload(String taskId) {
    if (_cancelTokens.containsKey(taskId)) {
      _cancelTokens[taskId]?.cancel();
      _cancelTokens.remove(taskId);
    }
    if (_tasks.containsKey(taskId)) {
      _tasks[taskId] = _tasks[taskId]!.copyWith(
        status: TxaDownloadStatus.paused,
      );
      notifyListeners();
    }
  }

  /// Xóa tác vụ và tệp đã tải
  Future<void> removeTask(String taskId) async {
    cancelDownload(taskId);
    final task = _tasks[taskId];
    if (task != null) {
      try {
        final file = File(task.localFilePath);
        if (file.existsSync()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('[TxaDownloadService] Lỗi xóa tệp: $e');
      }
      _tasks.remove(taskId);
      notifyListeners();
    }
  }
}
