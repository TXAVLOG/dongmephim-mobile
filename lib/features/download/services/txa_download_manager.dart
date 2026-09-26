import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/txa_download_status.dart';
import '../models/txa_download_task.dart';
import '../models/txa_local_film.dart';
import '../repositories/txa_download_repository.dart';
import '../ui/downloaded_episodes_screen.dart';
import 'txa_path_resolver.dart';
import 'txa_hls_downloader.dart';
import 'txa_merge_engine.dart';
import '../../../utils/txa_logger.dart';
import '../../../utils/txa_format.dart';
import '../../../utils/txa_navigator.dart';
import '../../../services/txa_language.dart';
import '../../../services/txa_auth_service.dart';
import '../../../services/txa_offline_history_service.dart';

class TxaDownloadManager extends ChangeNotifier {
  static final TxaDownloadManager _instance = TxaDownloadManager._internal();
  factory TxaDownloadManager() => _instance;
  TxaDownloadManager._internal();

  final TxaDownloadRepository _repo = TxaDownloadRepository();
  final Queue<TxaDownloadTask> _queue = Queue<TxaDownloadTask>();
  final Map<String, TxaHlsDownloader> _activeDownloaders = {};
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  final Map<String, TxaDownloadTask> _runningTasks = {};
  bool _isInitialized = false;
  StreamSubscription? _connectivitySub;

  TxaDownloadTask? get currentRunningTask =>
      _runningTasks.values.isNotEmpty ? _runningTasks.values.first : null;
  List<TxaDownloadTask> get runningTasks => _runningTasks.values.toList();
  int get runningTasksCount => _runningTasks.length;
  int get queuedTasksCount => _queue.length;
  int get activeTasksCount => _runningTasks.length + _queue.length;
  bool get isProcessing => _runningTasks.isNotEmpty || _queue.isNotEmpty;

  /// Check VIP status: Non-free or logged in with active package
  bool get hasPaidPackage {
    final user = TxaAuthService().user;
    if (user == null) return false;
    final pkg = (user['package'] ?? 'free').toString().toLowerCase();
    return pkg != 'free';
  }

  /// Get max concurrent tasks: 2 for VIP, 1 for Free
  Future<int> getMaxConcurrentDownloads() async {
    if (!hasPaidPackage) return 1;
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt('txa_concurrent_downloads') ?? 2).clamp(1, 2);
  }

  Future<void> setMaxConcurrentDownloads(int count) async {
    if (!hasPaidPackage) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('txa_concurrent_downloads', count.clamp(1, 2));
    notifyListeners();
    _processNextInQueue();
  }

  /// Get download chunk worker threads: VIP (4-20, default 12), Free (default 4)
  Future<int> getDownloadThreads() async {
    if (!hasPaidPackage) return 4;
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt('txa_download_threads') ?? 12).clamp(4, 20);
  }

  Future<void> setDownloadThreads(int count) async {
    if (!hasPaidPackage) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('txa_download_threads', count.clamp(4, 20));
    notifyListeners();
  }

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // 1. Recover interrupted tasks from DB
    await _repo.recoverInterruptedTasks();

    // 2. Setup notifications with action buttons and deep focus tap listener
    _initNotifications();

    // 3. Listen to connectivity
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final isOffline = results.contains(ConnectivityResult.none);
      if (isOffline) {
        if (_runningTasks.isNotEmpty) {
          pauseAll();
        }
      } else {
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
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleNotificationResponse(response);
      },
    );

    // Xử lý trường hợp người dùng mở app từ thông báo khi app đã bị đóng (cold start)
    final launchDetails = await _notifications.getNotificationAppLaunchDetails();
    if (launchDetails != null && launchDetails.didNotificationLaunchApp && launchDetails.notificationResponse != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleNotificationResponse(launchDetails.notificationResponse!);
      });
    }
  }

  /// Xử lý sự kiện nhấn vào thông báo hoặc các nút Action (Tạm dừng, Tải tập tiếp, Hủy)
  void _handleNotificationResponse(NotificationResponse response) async {
    final actionId = response.actionId;
    final payload = response.payload;
    Map<String, dynamic>? data;
    if (payload != null && payload.isNotEmpty) {
      try {
        data = jsonDecode(payload) as Map<String, dynamic>?;
      } catch (_) {}
    }

    final taskId = data?['taskId']?.toString();
    final filmSlug = data?['filmSlug']?.toString();
    final episodeId = data?['episodeId']?.toString();

    // 1. Action: Tạm dừng
    if (actionId == 'action_pause' && taskId != null) {
      await pauseTask(taskId);
      return;
    }
    // 2. Action: Tiếp tục
    else if (actionId == 'action_resume' && taskId != null) {
      await resumeTask(taskId);
      return;
    }
    // 3. Action: Tải tập tiếp (bỏ qua tập dở hiện tại, dồn xuống cuối hàng đợi)
    else if (actionId == 'action_skip_next' && taskId != null) {
      await skipToNextTask(taskId);
      return;
    }
    // 4. Action: Hủy
    else if (actionId == 'action_cancel' && taskId != null) {
      await cancelTask(taskId);
      return;
    }

    // 5. Bấm vào thân thông báo -> Mở thẳng View 2 phim và Focus vào tập đang tải
    if (filmSlug != null && filmSlug.isNotEmpty) {
      final allFilms = await getAllLocalFilms();
      final film = allFilms.firstWhere(
        (f) => f.filmSlug == filmSlug,
        orElse: () => TxaLocalFilm(
          filmSlug: filmSlug,
          filmTitle: data?['filmTitle']?.toString() ?? 'Phim',
          filmPoster: data?['filmPoster']?.toString() ?? '',
          tasks: [],
        ),
      );

      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => DownloadedEpisodesScreen(
            film: film,
            focusEpisodeId: episodeId,
          ),
        ),
      );
    }
  }

  /// Tải tập tiếp theo: Tạm dừng tập dở hiện tại, đẩy xuống cuối hàng đợi
  /// Khi các tập khác trong hàng đợi tải xong thì mới quay lại tải tiếp phần dở của nó
  Future<void> skipToNextTask(String currentTaskId) async {
    if (_runningTasks.containsKey(currentTaskId)) {
      final currentTask = _runningTasks[currentTaskId]!;
      _activeDownloaders[currentTaskId]?.pause();
      currentTask.status = TxaDownloadStatus.queued;
      await _repo.upsertTask(currentTask);
      _runningTasks.remove(currentTaskId);

      // Đẩy xuống cuối hàng đợi
      _queue.addLast(currentTask);

      // Nếu còn tập khác phía trước hàng đợi thì lấy tải ngay
      if (_queue.isNotEmpty) {
        final nextTask = _queue.removeFirst();
        _startTask(nextTask);
      } else {
        _startTask(currentTask);
      }
      notifyListeners();
    }
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

  /// Pause single task
  Future<void> pauseTask(String taskId) async {
    if (_runningTasks.containsKey(taskId)) {
      final task = _runningTasks[taskId]!;
      _activeDownloaders[taskId]?.pause();
      task.status = TxaDownloadStatus.paused;
      await _repo.upsertTask(task);
      _updateNotificationProgress(
        task,
        TxaLanguage.t('paused'),
        isPaused: true,
      );
      _runningTasks.remove(taskId);
      if (_runningTasks.isEmpty) {
        WakelockPlus.disable();
      }
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

  /// Resume single task
  Future<void> resumeTask(String taskId) async {
    final task = await _repo.getTask(taskId);
    if (task != null) {
      task.status = TxaDownloadStatus.queued;
      task.errorMessage = null;
      await _repo.upsertTask(task);
      if (!_queue.any((t) => t.id == taskId) && !_runningTasks.containsKey(taskId)) {
        _queue.add(task);
      }
      notifyListeners();
      _processNextInQueue();
    }
  }

  /// Cancel single task
  Future<void> cancelTask(String taskId) async {
    if (_runningTasks.containsKey(taskId)) {
      _activeDownloaders[taskId]?.cancel();
      _runningTasks.remove(taskId);
    }
    _queue.removeWhere((t) => t.id == taskId);
    await _repo.deleteTask(taskId);
    if (_runningTasks.isEmpty) {
      _cancelNotification();
      WakelockPlus.disable();
    }
    notifyListeners();
    _processNextInQueue();
  }

  /// Pause all active & queued tasks
  Future<void> pauseAll() async {
    for (final task in _runningTasks.values.toList()) {
      _activeDownloaders[task.id]?.pause();
      task.status = TxaDownloadStatus.paused;
      await _repo.upsertTask(task);
    }
    _runningTasks.clear();

    while (_queue.isNotEmpty) {
      final qTask = _queue.removeFirst();
      qTask.status = TxaDownloadStatus.paused;
      await _repo.upsertTask(qTask);
    }

    _cancelNotification();
    WakelockPlus.disable();
    notifyListeners();
  }

  /// Resume all paused tasks
  Future<void> resumeAll() async {
    final allTasks = await _repo.getAllTasks();
    for (final t in allTasks) {
      if (t.status == TxaDownloadStatus.paused || t.status == TxaDownloadStatus.failed) {
        t.status = TxaDownloadStatus.queued;
        t.errorMessage = null;
        await _repo.upsertTask(t);
        if (!_queue.any((q) => q.id == t.id) && !_runningTasks.containsKey(t.id)) {
          _queue.add(t);
        }
      }
    }
    notifyListeners();
    _processNextInQueue();
  }

  /// Cancel all active, queued, and paused tasks
  Future<void> cancelAll() async {
    for (final task in _runningTasks.values.toList()) {
      _activeDownloaders[task.id]?.cancel();
    }
    _runningTasks.clear();
    _queue.clear();
    _cancelNotification();
    WakelockPlus.disable();

    final allTasks = await _repo.getAllTasks();
    for (final t in allTasks) {
      if (!t.isCompleted) {
        await deleteTask(t.id);
      }
    }
    notifyListeners();
  }

  /// Pause all downloads for a specific film
  Future<void> pauseFilmDownloads(String filmSlug) async {
    for (final task in _runningTasks.values.toList()) {
      if (task.filmSlug == filmSlug) {
        await pauseTask(task.id);
      }
    }
    final queuedFilmTasks = _queue.where((t) => t.filmSlug == filmSlug).toList();
    for (final t in queuedFilmTasks) {
      await pauseTask(t.id);
    }
    notifyListeners();
  }

  /// Resume all paused downloads for a specific film
  Future<void> resumeFilmDownloads(String filmSlug) async {
    final tasks = await _repo.getTasksByFilm(filmSlug);
    for (final t in tasks) {
      if (t.status == TxaDownloadStatus.paused || t.status == TxaDownloadStatus.failed) {
        await resumeTask(t.id);
      }
    }
  }

  /// Cancel all unfinished downloads for a specific film
  Future<void> cancelFilmDownloads(String filmSlug) async {
    final tasks = await _repo.getTasksByFilm(filmSlug);
    for (final t in tasks) {
      if (!t.isCompleted) {
        await cancelTask(t.id);
      }
    }
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

    for (final q in _queue) {
      if (q.filmSlug == filmSlug) {
        taskMap[q.id] = q;
      }
    }
    for (final r in _runningTasks.values) {
      if (r.filmSlug == filmSlug) {
        taskMap[r.id] = r;
      }
    }

    return taskMap.values.toList();
  }

  /// Get all downloaded films summary
  Future<List<TxaLocalFilm>> getAllLocalFilms() async {
    await init();
    final allTasks = await _repo.getAllTasks();
    final Map<String, TxaDownloadTask> taskMap = {for (var t in allTasks) t.id: t};

    for (final q in _queue) {
      taskMap[q.id] = q;
    }
    for (final r in _runningTasks.values) {
      taskMap[r.id] = r;
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
    final maxConcurrent = await getMaxConcurrentDownloads();
    while (_runningTasks.length < maxConcurrent && _queue.isNotEmpty) {
      final task = _queue.removeFirst();
      _startTask(task);
    }
  }

  Future<void> _startTask(TxaDownloadTask task) async {
    _runningTasks[task.id] = task;
    task.status = TxaDownloadStatus.downloading;
    task.errorMessage = null;
    await _repo.upsertTask(task);
    WakelockPlus.enable(); // Giữ CPU chạy nền khi tải phim
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

      final threads = await getDownloadThreads();
      int lastNotifyTime = 0;
      final success = await downloader.download(
        m3u8Url: task.m3u8Url,
        baseDir: baseDir,
        concurrency: threads,
        onProgress: (prog) {
          task.downloadedSegments = prog.downloadedSegments;
          task.totalSegments = prog.totalSegments;
          task.downloadedBytes = prog.downloadedBytes;
          task.totalBytes = prog.totalBytes;
          task.speed = prog.speed;
          task.eta = prog.eta;

          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - lastNotifyTime >= 400 || prog.downloadedSegments == prog.totalSegments) {
            lastNotifyTime = now;
            _updateNotificationProgress(task, '');
            notifyListeners();
          }
        },
      );

      _activeDownloaders.remove(task.id);

      if (success) {
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
      _runningTasks.remove(task.id);
      if (_runningTasks.isEmpty) {
        WakelockPlus.disable();
      }
      notifyListeners();
      _processNextInQueue();
    }
  }

  int _sessionCompletedCount = 0;
  int get sessionCompletedCount => _sessionCompletedCount;
  int get totalSessionTasks => _sessionCompletedCount + _runningTasks.length + _queue.length;

  /// Cập nhật tiến độ thông báo thời gian thực với 3 nút action tiện lợi và trạng thái rõ ràng
  Future<void> _updateNotificationProgress(
    TxaDownloadTask task,
    String customBody, {
    bool isPaused = false,
  }) async {
    if (!Platform.isAndroid) return;
    final percent = (task.progress * 100).toInt().clamp(0, 100);

    final payload = jsonEncode({
      'type': 'download_focus',
      'taskId': task.id,
      'filmSlug': task.filmSlug,
      'filmTitle': task.filmTitle,
      'filmPoster': task.filmPoster,
      'episodeId': task.episodeId,
      'episodeName': task.episodeName,
    });

    final dlSizeStr = TxaFormat.formatFileSize(task.downloadedBytes);
    final totSizeStr = TxaFormat.formatFileSize(task.totalBytes);
    final speedMap = TxaFormat.formatSpeed(task.speed);
    final speedStr = task.speed > 0 ? speedMap['display'] : '';
    final etaStr = task.eta > 0 ? 'ETA: ${TxaFormat.formatDuration(task.eta)}' : '';

    final totalTasks = (_sessionCompletedCount + _runningTasks.length + _queue.length).clamp(1, 9999);
    final currentIdx = (_sessionCompletedCount + 1).clamp(1, totalTasks);
    final waitingInQueue = _queue.length;
    final effectivePaused = isPaused || task.status == TxaDownloadStatus.paused;

    String statePrefix;
    if (task.status == TxaDownloadStatus.merging) {
      statePrefix = '🔄 [${TxaLanguage.t('download_notif_merging').toUpperCase()} $currentIdx/$totalTasks]';
    } else if (effectivePaused) {
      statePrefix = '⏸️ [${TxaLanguage.t('download_notif_paused').toUpperCase()} $currentIdx/$totalTasks]';
    } else {
      statePrefix = '🟢 [${TxaLanguage.t('download_notif_downloading').toUpperCase()} $currentIdx/$totalTasks]';
    }

    final notifTitle = '$statePrefix ${task.filmTitle} - ${task.episodeName}';

    String bodyText;
    if (customBody.isNotEmpty) {
      bodyText = '$customBody • ${TxaLanguage.t('download_notif_queue_summary', replace: {'done': '$_sessionCompletedCount', 'total': '$totalTasks', 'wait': '$waitingInQueue'})}';
    } else if (effectivePaused) {
      bodyText = '${TxaLanguage.t('download_notif_paused')} @ $percent% ($dlSizeStr/$totSizeStr) • ${TxaLanguage.t('download_notif_remaining_queue', replace: {'n': '$waitingInQueue'})}';
    } else {
      bodyText = '$percent% ($dlSizeStr/$totSizeStr)${speedStr.isNotEmpty ? ' • $speedStr' : ''}${etaStr.isNotEmpty ? ' • $etaStr' : ''} • $waitingInQueue ${TxaLanguage.t('download_notif_waiting')}';
    }

    final android = AndroidNotificationDetails(
      'txa_offline_downloads',
      TxaLanguage.t('download_channel_name'),
      channelDescription: TxaLanguage.t('download_channel_desc'),
      icon: '@mipmap/launcher_icon',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      progress: percent,
      ongoing: !effectivePaused,
      autoCancel: false,
      onlyAlertOnce: true,
      actions: [
        AndroidNotificationAction(
          effectivePaused ? 'action_resume' : 'action_pause',
          effectivePaused ? '▶️ ${TxaLanguage.t('resume')}' : '⏸️ ${TxaLanguage.t('pause')}',
          showsUserInterface: false,
          cancelNotification: false,
        ),
        AndroidNotificationAction(
          'action_skip_next',
          '⏭️ ${TxaLanguage.t('download_notif_skip_next')}',
          showsUserInterface: false,
          cancelNotification: false,
        ),
        AndroidNotificationAction(
          'action_cancel',
          '⏹️ ${TxaLanguage.t('cancel')}',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    await _notifications.show(
      id: 200,
      title: notifTitle,
      body: bodyText,
      payload: payload,
      notificationDetails: NotificationDetails(android: android),
    );
  }

  Future<void> _completeNotification(TxaDownloadTask task) async {
    _sessionCompletedCount++;
    if (!Platform.isAndroid) return;
    final android = AndroidNotificationDetails(
      'txa_offline_downloads',
      TxaLanguage.t('download_channel_name'),
      channelDescription: TxaLanguage.t('download_channel_desc'),
      icon: '@mipmap/launcher_icon',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: false,
    );

    await _notifications.show(
      id: 200,
      title: '✅ ${TxaLanguage.t('download_completed')} ($_sessionCompletedCount ${TxaLanguage.t('episode')})',
      body: '${task.filmTitle} - ${task.episodeName}',
      notificationDetails: NotificationDetails(android: android),
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
