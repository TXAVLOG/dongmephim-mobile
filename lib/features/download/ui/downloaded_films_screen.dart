import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/txa_local_film.dart';
import '../models/txa_download_status.dart';
import '../services/txa_download_manager.dart';
import '../services/txa_storage_estimator.dart';
import 'downloaded_episodes_screen.dart';
import 'txa_download_settings_modal.dart';
import '../../../../theme/txa_theme.dart';
import '../../../../utils/txa_format.dart';
import '../../../../services/txa_language.dart';
import '../../../../services/txa_offline_history_service.dart';

class DownloadedFilmsScreen extends StatefulWidget {
  const DownloadedFilmsScreen({super.key});

  @override
  State<DownloadedFilmsScreen> createState() => _DownloadedFilmsScreenState();
}

class _DownloadedFilmsScreenState extends State<DownloadedFilmsScreen> {
  @override
  void initState() {
    super.initState();
    TxaOfflineHistoryService.syncPendingHistory();
  }

  void _confirmCancelAll(TxaDownloadManager manager) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TxaTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          TxaLanguage.t('cancel_all'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          TxaLanguage.t('cancel_all_confirm'),
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(TxaLanguage.t('cancel'), style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await manager.cancelAll();
              if (mounted) setState(() {});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(TxaLanguage.t('confirm')),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStats(List<TxaLocalFilm> films, int totalAppBytes) {
    final totalFilms = films.length;
    final totalEpisodes = films.fold<int>(0, (sum, f) => sum + f.completedCount);
    final totalSizeStr = TxaFormat.formatFileSize(totalAppBytes);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: TxaTheme.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              icon: Icons.movie_filter_rounded,
              value: '$totalFilms',
              label: TxaLanguage.t('downloaded_movies'),
              color: TxaTheme.accent,
            ),
          ),
          Container(width: 1, height: 36, color: Colors.white10),
          Expanded(
            child: _buildStatItem(
              icon: Icons.video_library_rounded,
              value: '$totalEpisodes',
              label: TxaLanguage.t('completed_episodes_label'),
              color: Colors.greenAccent,
            ),
          ),
          Container(width: 1, height: 36, color: Colors.white10),
          Expanded(
            child: _buildStatItem(
              icon: Icons.pie_chart_outline_rounded,
              value: totalSizeStr,
              label: TxaLanguage.t('app_storage_label'),
              color: Colors.amberAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// Live Global Download Controller Card in View 1
  Widget _buildActiveDownloadControlCard(TxaDownloadManager manager, List<TxaLocalFilm> films) {
    final runningTasks = manager.runningTasks;
    final isProcessing = manager.isProcessing;

    // Check if there are paused or queued tasks
    bool hasPaused = false;
    for (final f in films) {
      if (f.tasks.any((t) => t.status == TxaDownloadStatus.paused || t.status == TxaDownloadStatus.failed)) {
        hasPaused = true;
        break;
      }
    }

    if (!isProcessing && !hasPaused) return const SizedBox.shrink();

    final isActivelyDownloading = runningTasks.isNotEmpty;
    final combinedSpeed = runningTasks.fold<double>(0.0, (sum, t) => sum + t.speed);
    final speedStr = combinedSpeed > 0 ? TxaFormat.formatSpeed(combinedSpeed)['display'] : null;
    final activeTitle = isActivelyDownloading
        ? '${runningTasks.first.filmTitle} • ${runningTasks.first.episodeName}'
        : TxaLanguage.t('paused_queue_banner', replace: {'count': '${manager.waitingInQueue}'});

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (isActivelyDownloading ? TxaTheme.accent : Colors.amber).withValues(alpha: 0.16),
            TxaTheme.cardBg,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (isActivelyDownloading ? TxaTheme.accent : Colors.amber).withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: (isActivelyDownloading ? TxaTheme.accent : Colors.amber).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isActivelyDownloading ? Icons.downloading_rounded : Icons.pause_circle_outline_rounded,
                  color: isActivelyDownloading ? TxaTheme.accent : Colors.amberAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isActivelyDownloading
                              ? '🟢 ${TxaLanguage.t('downloading_session_banner', replace: {'count': '${runningTasks.length}', 'done': '${manager.sessionCompletedCount}', 'total': '${manager.totalSessionTasks}'})}'
                              : '⏸️ ${TxaLanguage.t('paused_queue_banner', replace: {'count': '${manager.activeTasksCount}'})}',
                          style: TextStyle(
                            color: isActivelyDownloading ? TxaTheme.accent : Colors.amberAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (speedStr != null)
                          Text(
                            speedStr,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activeTitle,
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Action Buttons: Pause/Resume All & Cancel All
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (isActivelyDownloading) {
                        manager.pauseAll();
                      } else {
                        manager.resumeAll();
                      }
                    },
                    icon: Icon(
                      isActivelyDownloading ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 16,
                    ),
                    label: Text(
                      isActivelyDownloading ? TxaLanguage.t('pause_all') : TxaLanguage.t('resume_all'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isActivelyDownloading
                          ? Colors.amber.withValues(alpha: 0.2)
                          : Colors.greenAccent.withValues(alpha: 0.2),
                      foregroundColor: isActivelyDownloading ? Colors.amberAccent : Colors.greenAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmCancelAll(manager),
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: Text(
                      TxaLanguage.t('cancel_all'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
                      foregroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSystemStorageSection(int totalAppBytes) {
    return FutureBuilder<TxaStorageInfo>(
      future: TxaStorageEstimator.getStorageInfo(totalAppBytes),
      builder: (context, snap) {
        final info = snap.data ??
            TxaStorageInfo(
              totalBytes: 128 * 1024 * 1024 * 1024,
              usedBytes: 45 * 1024 * 1024 * 1024 + totalAppBytes,
              freeBytes: 83 * 1024 * 1024 * 1024 - totalAppBytes,
              appBytes: totalAppBytes,
            );

        final usedStr = TxaFormat.formatFileSize(info.usedBytes);
        final totalStr = TxaFormat.formatFileSize(info.totalBytes);
        final appStr = TxaFormat.formatFileSize(info.appBytes);
        final freeStr = TxaFormat.formatFileSize(info.freeBytes);
        final otherUsedBytes = (info.usedBytes - info.appBytes).clamp(0, info.totalBytes);
        final otherStr = TxaFormat.formatFileSize(otherUsedBytes);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: TxaTheme.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${TxaLanguage.t('storage_used')}: $usedStr / $totalStr',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${(info.usedRatio * 100).toInt()}%',
                    style: const TextStyle(
                      color: TxaTheme.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 7,
                  child: Stack(
                    children: [
                      Container(color: Colors.white10),
                      FractionallySizedBox(
                        widthFactor: info.usedRatio,
                        child: Container(color: Colors.white30),
                      ),
                      FractionallySizedBox(
                        widthFactor: info.appRatio.clamp(0.005, 1.0),
                        child: Container(color: TxaTheme.accent),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: TxaTheme.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'DongMePhim: $appStr',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${TxaLanguage.t('storage_other')}: $otherStr',
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${TxaLanguage.t('storage_free')}: $freeStr',
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<TxaDownloadManager>(context);

    return Scaffold(
      backgroundColor: TxaTheme.primaryBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          TxaLanguage.t('downloaded_movies'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: TxaTheme.accent),
            tooltip: TxaLanguage.t('download_settings'),
            onPressed: () => TxaDownloadSettingsModal.show(context),
          ),
        ],
      ),
      body: FutureBuilder<List<TxaLocalFilm>>(
        future: manager.getAllLocalFilms(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: TxaTheme.accent));
          }

          final films = snapshot.data ?? [];
          final totalAllBytes = films.fold<int>(0, (sum, f) => sum + f.totalBytes);

          if (films.isEmpty && !manager.isProcessing) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.download_for_offline_outlined, color: Colors.white24, size: 72),
                  const SizedBox(height: 16),
                  Text(
                    TxaLanguage.t('offline_no_downloads_title'),
                    style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      TxaLanguage.t('no_history_msg'),
                      style: const TextStyle(color: Colors.white38, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: films.length + 3,
            itemBuilder: (ctx, idx) {
              if (idx == 0) {
                // 1. Thống kê tóm tắt đầu view 1 (Tổng phim, tổng tập, dung lượng)
                return _buildSummaryStats(films, totalAllBytes);
              }
              if (idx == 1) {
                // 2. Banner điều khiển phiên tải đang chạy (Tạm dừng tất cả / Hủy tất cả)
                return _buildActiveDownloadControlCard(manager, films);
              }
              if (idx == 2) {
                // 3. Storage progress bar hệ thống
                return _buildSystemStorageSection(totalAllBytes);
              }

              final film = films[idx - 3];
              final totalSizeStr = TxaFormat.formatFileSize(film.totalBytes);
              final isAllCompleted = film.totalCount > 0 && film.completedCount == film.totalCount;
              final isFilmDownloading = film.tasks.any((t) =>
                  t.status == TxaDownloadStatus.downloading ||
                  t.status == TxaDownloadStatus.merging ||
                  t.status == TxaDownloadStatus.queued);
              final isFilmPaused = !isFilmDownloading && film.tasks.any((t) => t.status == TxaDownloadStatus.paused);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: TxaTheme.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isFilmDownloading
                        ? TxaTheme.accent.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DownloadedEpisodesScreen(film: film),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: film.filmPoster.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: film.filmPoster,
                                    width: 58,
                                    height: 82,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(color: Colors.white10),
                                    errorWidget: (_, __, ___) => Container(
                                      width: 58,
                                      height: 82,
                                      color: Colors.white10,
                                      child: const Icon(Icons.movie_rounded, color: Colors.white38),
                                    ),
                                  )
                                : Container(
                                    width: 58,
                                    height: 82,
                                    color: Colors.white10,
                                    child: const Icon(Icons.movie_rounded, color: Colors.white38),
                                  ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  film.filmTitle,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isFilmDownloading
                                            ? TxaTheme.accent.withValues(alpha: 0.15)
                                            : (isFilmPaused
                                                ? Colors.amber.withValues(alpha: 0.15)
                                                : (isAllCompleted
                                                    ? Colors.greenAccent.withValues(alpha: 0.15)
                                                    : Colors.white.withValues(alpha: 0.08))),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isFilmDownloading)
                                            const Padding(
                                              padding: EdgeInsets.only(right: 4),
                                              child: SizedBox(
                                                width: 10,
                                                height: 10,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: TxaTheme.accent,
                                                ),
                                              ),
                                            ),
                                          Text(
                                            isFilmDownloading
                                                ? '${TxaLanguage.t('downloading')} • ${film.completedCount}/${film.totalCount}'
                                                : (isFilmPaused
                                                    ? '${TxaLanguage.t('paused')} • ${film.completedCount}/${film.totalCount}'
                                                    : '${film.completedCount}/${film.totalCount} ${TxaLanguage.t('all_episodes')}'),
                                            style: TextStyle(
                                              color: isFilmDownloading
                                                  ? TxaTheme.accent
                                                  : (isFilmPaused
                                                      ? Colors.amberAccent
                                                      : (isAllCompleted ? Colors.greenAccent : Colors.white70)),
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.06),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        totalSizeStr,
                                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
