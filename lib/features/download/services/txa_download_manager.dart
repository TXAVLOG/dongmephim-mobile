import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/txa_download_status.dart';
import '../models/txa_download_task.dart';
import '../models/txa_local_film.dart';
import '../repositories/txa_download_repository.dart';
import 'txa_path_resolver.dart';
import 'txa_hls_downloader.dart';
import 'txa_merge_engine.dart';
import '../../../utils/txa_logger.dart';
import '../../../utils/txa_format.dart';
import '../../../services/txa_language.dart';
import '../../../services/txa_offline_history_service.dart';

class TxaDownloadManager extends ChangeNotifier {
  static final TxaDownloadManager _instance = TxaDownloadManager._internal();
  factory TxaDownloadManager() => _instance;
  TxaDownloadManager._internal();

  final TxaDownloadRepository _repo = TxaDownloadRepository();
  final Queue<TxaDownloadTask> _queue = Queue<TxaDownloadTask>();
  final Map<String, TxaHlsDownloader> _activeDownloaders = {};
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  TxaDownloadTask? _currentRunningTask;
  bool _isProcessingQueue = false;
  bool _isInitialized = false;
  StreamSubscription? _connectivitySub;

  TxaDownloadTask? get currentRunningTask => _currentRunningTask;
  bool get isProcessing => _isProcessingQueue;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // 1. Recover interrupted tasks from DB
    await _repo.recoverInterruptedTasks();

    // 2. Setup notifications
    _initNotifications();

    // 3. Listen to connectivity
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final isOffline = results.contains(ConnectivityResult.none);
      if (isOffline) {
        if (_currentRunningTask != null && _currentRunningTask!.status == TxaDownloadStatus.downloading) {
          pauseTask(_currentRunningTask!.id);
        }
      } else {
        // Network back online -> trigger auto sync of offline watch history
        TxaOfflineHistoryService.syncPendingHistory();
      }
    });

    TxaLogger.log('TxaDownloadManager initialized.', type: 'app');
  }

  void _initNotifications() async {
    if (!Platform.isAndroid) return;
    const android = AndroidInitializationSettings('@mipmap/launcher_icon');
    await _notifications.initialize(
      settings: const InitializationSettings(android: android),
    );
  }

  /// Add a task to queue
  Future<void> enqueueTask(TxaDownloadTask task) async {
    await init();

    final existing = await _repo.getTask(task.id);
    if (existing != null && existing.status == TxaDownloadStatus.completed) {
      if (File(existing.localPath).existsSync()) {
        return; // Already downloaded
      }
    }

    task.status = TxaDownloadStatus.queued;
    await _repo.upsertTask(task);
    _queue.add(task);
    notifyListeners();

    _processNextInQueue();
  }

  /// Add batch of tasks
  Future<void> enqueueBatch(List<TxaDownloadTask> tasks) async {
    for (final task in tasks) {
      await enqueueTask(task);
    }
  }

  /// Pause task
  Future<void> pauseTask(String taskId) async {
    if (_currentRunningTask?.id == taskId) {
      _activeDownloaders[taskId]?.pause();
      _currentRunningTask!.status = TxaDownloadStatus.paused;
      await _repo.upsertTask(_currentRunningTask!);
      _updateNotificationProgress(
        _currentRunningTask!,
        TxaLanguage.t('paused'),
        isPaused: true,
      );
      _currentRunningTask = null;
      notifyListeners();
    } else {
      final task = await _repo.getTask(taskId);
      if (task != null) {
        task.status = TxaDownloadStatus.paused;
        await _repo.upsertTask(task);
        _queue.removeWhere((t) => t.id == taskId);
        notifyListeners();
      }
    }
    _processNextInQueue();
  }

  /// Resume task
  Future<void> resumeTask(String taskId) async {
    final task = await _repo.getTask(taskId);
    if (task != null) {
      task.status = TxaDownloadStatus.queued;
      task.errorMessage = null;
      await _repo.upsertTask(task);
      if (!_queue.any((t) => t.id == taskId)) {
        _queue.add(task);
      }
      notifyListeners();
      _processNextInQueue();
    }
  }

  /// Cancel task
  Future<void> cancelTask(String taskId) async {
    if (_currentRunningTask?.id == taskId) {
      _activeDownloaders[taskId]?.cancel();
      _currentRunningTask = null;
    }
    _queue.removeWhere((t) => t.id == taskId);
    await _repo.deleteTask(taskId);
    _cancelNotification();
    notifyListeners();
    _processNextInQueue();
  }

  /// Delete completed task & associated files
  Future<void> deleteTask(String taskId) async {
    final task = await _repo.getTask(taskId);
    if (task != null) {
      try {
        if (task.localBaseDir.isNotEmpty) {
          final dir = Directory(task.localBaseDir);
          if (await dir.exists()) {
            await dir.delete(recursive: true);
          }
        }
      } catch (e) {
        TxaLogger.log('Error deleting task files: $e', type: 'app');
      }
      await _repo.deleteTask(taskId);
      notifyListeners();
    }
  }

  /// Delete all downloads for a film
  Future<void> deleteFilmDownloads(String filmSlug) async {
    final tasks = await _repo.getTasksByFilm(filmSlug);
    for (final t in tasks) {
      await deleteTask(t.id);
    }
  }

  /// Get tasks for a film
  Future<List<TxaDownloadTask>> getTasksForFilm(String filmSlug) async {
    await init();
    final dbTasks = await _repo.getTasksByFilm(filmSlug);
    final Map<String, TxaDownloadTask> taskMap = {for (var t in dbTasks) t.id: t};

    // Overlay queued tasks
    for (final q in _queue) {
      if (q.filmSlug == filmSlug) {
        taskMap[q.id] = q;
      }
    }
    // Overlay currently running task with real-time progress
    if (_currentRunningTask != null && _currentRunningTask!.filmSlug == filmSlug) {
      taskMap[_currentRunningTask!.id] = _currentRunningTask!;
    }

    return taskMap.values.toList();
  }

  /// Get all downloaded films summary
  Future<List<TxaLocalFilm>> getAllLocalFilms() async {
    await init();
    final allTasks = await _repo.getAllTasks();
    final Map<String, TxaDownloadTask> taskMap = {for (var t in allTasks) t.id: t};

    // Overlay queued & running tasks
    for (final q in _queue) {
      taskMap[q.id] = q;
    }
    if (_currentRunningTask != null) {
      taskMap[_currentRunningTask!.id] = _currentRunningTask!;
    }

    final Map<String, List<TxaDownloadTask>> grouped = {};
    for (final task in taskMap.values) {
      grouped.putIfAbsent(task.filmSlug, () => []).add(task);
    }

    final List<TxaLocalFilm> result = [];
    grouped.forEach((slug, tasks) {
      if (tasks.isNotEmpty) {
        result.add(TxaLocalFilm(
          filmSlug: slug,
          filmTitle: tasks.first.filmTitle,
          filmPoster: tasks.first.filmPoster,
          tasks: tasks,
        ));
      }
    });

    return result;
  }

  /// Core Queue Processor
  Future<void> _processNextInQueue() async {
    if (_isProcessingQueue || _currentRunningTask != null) return;
    if (_queue.isEmpty) return;

    _isProcessingQueue = true;
    final task = _queue.removeFirst();
    _currentRunningTask = task;

    task.status = TxaDownloadStatus.downloading;
    task.errorMessage = null;
    await _repo.upsertTask(task);
    notifyListeners();

    try {
      final baseDir = await TxaPathResolver.getEpisodeBaseDir(
        filmTitle: task.filmTitle,
        serverName: task.serverName,
        episodeName: task.episodeName,
      );
      task.localBaseDir = baseDir.path;

      final downloader = TxaHlsDownloader();
      _activeDownloaders[task.id] = downloader;

      int lastNotifyTime = 0;
      final success = await downloader.download(
        m3u8Url: task.m3u8Url,
        baseDir: baseDir,
        onProgress: (prog) {
          task.downloadedSegments = prog.downloadedSegments;
          task.totalSegments = prog.totalSegments;
          task.downloadedBytes = prog.downloadedBytes;
          task.totalBytes = prog.totalBytes;
          task.speed = prog.speed;
          task.eta = prog.eta;

          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - lastNotifyTime >= 300 || prog.downloadedSegments == prog.totalSegments) {
            lastNotifyTime = now;
            _updateNotificationProgress(
              task,
              '${TxaFormat.formatSpeed(prog.speed)['display']} • ETA: ${TxaFormat.formatDuration(prog.eta)}',
            );
            notifyListeners();
          }
        },
      );

      _activeDownloaders.remove(task.id);

      if (success) {
        // 2. Merging phase
        task.status = TxaDownloadStatus.merging;
        await _repo.upsertTask(task);
        notifyListeners();

        _updateNotificationProgress(task, TxaLanguage.t('download_status_merging'));

        final outputFile = await TxaPathResolver.getMergedOutputFile(
          filmTitle: task.filmTitle,
          serverName: task.serverName,
          episodeName: task.episodeName,
        );

        final mergedFile = await TxaMergeEngine.merge(
          baseDir: baseDir,
          outputFile: outputFile,
        );

        if (mergedFile != null && await mergedFile.exists()) {
          task.localPath = mergedFile.path;
          task.status = TxaDownloadStatus.completed;
          task.completedAt = DateTime.now();
          await _repo.upsertTask(task);
          _completeNotification(task);
        } else {
          throw Exception('Merge failed');
        }
      } else {
        if (!downloader.isPaused && !downloader.isCancelled) {
          task.status = TxaDownloadStatus.failed;
          task.errorMessage = 'Download incomplete';
          await _repo.upsertTask(task);
        }
      }
    } catch (e) {
      task.status = TxaDownloadStatus.failed;
      task.errorMessage = e.toString();
      await _repo.upsertTask(task);
      TxaLogger.log('Download task error: $e', type: 'app');
    } finally {
      _currentRunningTask = null;
      _isProcessingQueue = false;
      notifyListeners();
      _processNextInQueue();
    }
  }

  Future<void> _updateNotificationProgress(
    TxaDownloadTask task,
    String body, {
    bool isPaused = false,
  }) async {
    if (!Platform.isAndroid) return;
    final percent = (task.progress * 100).toInt().clamp(0, 100);

    final android = AndroidNotificationDetails(
      'txa_offline_downloads',
      'TPhimX Tải phim Offline',
      icon: '@mipmap/launcher_icon',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      progress: percent,
      ongoing: !isPaused,
      onlyAlertOnce: true,
    );

    await _notifications.show(
      id: 200,
      title: '${task.filmTitle} - ${task.episodeName}',
      body: body,
      notificationDetails: NotificationDetails(android: android),
    );
  }

  Future<void> _completeNotification(TxaDownloadTask task) async {
    if (!Platform.isAndroid) return;
    const android = AndroidNotificationDetails(
      'txa_offline_downloads',
      'TPhimX Tải phim Offline',
      icon: '@mipmap/launcher_icon',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: false,
    );

    await _notifications.show(
      id: 200,
      title: TxaLanguage.t('download_completed'),
      body: '${task.filmTitle} - ${task.episodeName}',
      notificationDetails: const NotificationDetails(android: android),
    );
  }

  Future<void> _cancelNotification() async {
    if (!Platform.isAndroid) return;
    await _notifications.cancel(id: 200);
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }
}
