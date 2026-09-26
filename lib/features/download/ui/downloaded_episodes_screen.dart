import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/txa_local_film.dart';
import '../models/txa_download_task.dart';
import '../models/txa_download_status.dart';
import '../services/txa_download_manager.dart';
import 'widgets/txa_download_row.dart';
import '../../../../theme/txa_theme.dart';
import '../../../../utils/txa_format.dart';
import '../../../../utils/txa_toast.dart';
import '../../../../services/txa_language.dart';
import '../../../../services/txa_offline_history_service.dart';
import '../../../../widgets/txa_video_player.dart';

class DownloadedEpisodesScreen extends StatefulWidget {
  final TxaLocalFilm film;
  final String? focusEpisodeId;

  const DownloadedEpisodesScreen({
    super.key,
    required this.film,
    this.focusEpisodeId,
  });

  @override
  State<DownloadedEpisodesScreen> createState() => _DownloadedEpisodesScreenState();
}

class _DownloadedEpisodesScreenState extends State<DownloadedEpisodesScreen> {
  String? _highlightedEpisodeId;
  final ScrollController _scrollController = ScrollController();
  Timer? _highlightTimer;
  bool _hasAutoScrolled = false;

  @override
  void initState() {
    super.initState();
    if (widget.focusEpisodeId != null) {
      _highlightedEpisodeId = widget.focusEpisodeId;
      _highlightTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _highlightedEpisodeId = null;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _playOffline(TxaDownloadTask task) async {
    if (task.localPath.isEmpty || !File(task.localPath).existsSync()) {
      TxaToast.show(context, TxaLanguage.t('local_playback_error'));
      return;
    }

    final savedProgress = await TxaOfflineHistoryService.getLocalProgress(task.filmSlug, task.episodeId);
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TxaVideoPlayer(
          url: task.localPath,
          movieName: task.filmTitle,
          episodeName: task.episodeName,
          serverName: task.serverName,
          movieId: task.filmSlug,
          currentEpisodeId: task.episodeId,
          startTime: (savedProgress ?? 0).toInt(),
        ),
      ),
    );
  }

  void _confirmDeleteTask(TxaDownloadTask task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TxaTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          TxaLanguage.t('delete_movie_confirm'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          '${task.filmTitle} - ${task.episodeName}',
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
              final manager = Provider.of<TxaDownloadManager>(context, listen: false);
              await manager.deleteTask(task.id);
              if (mounted) setState(() {});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(TxaLanguage.t('delete')),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TxaTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          TxaLanguage.t('delete_all_confirm'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          TxaLanguage.t('delete_all_episodes_msg'),
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
              final manager = Provider.of<TxaDownloadManager>(context, listen: false);
              await manager.deleteFilmDownloads(widget.film.filmSlug);
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(TxaLanguage.t('delete')),
          ),
        ],
      ),
    );
  }

  Widget _buildFilmBulkToolbar(TxaDownloadManager manager, List<TxaDownloadTask> tasks) {
    final hasActive = tasks.any((t) =>
        t.status == TxaDownloadStatus.downloading ||
        t.status == TxaDownloadStatus.merging ||
        t.status == TxaDownloadStatus.queued);
    final hasPaused = tasks.any((t) =>
        t.status == TxaDownloadStatus.paused ||
        t.status == TxaDownloadStatus.failed);

    if (!hasActive && !hasPaused) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: TxaTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                hasActive ? Icons.downloading_rounded : Icons.pause_circle_outline_rounded,
                color: hasActive ? TxaTheme.accent : Colors.amberAccent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                hasActive
                    ? '🟢 ${TxaLanguage.t('downloading_progress_status', replace: {'done': '${tasks.where((t) => t.isCompleted).length}', 'total': '${tasks.length}'})}'
                    : '⏸️ ${TxaLanguage.t('paused_progress_status', replace: {'done': '${tasks.where((t) => t.isCompleted).length}', 'total': '${tasks.length}'})}',
                style: TextStyle(
                  color: hasActive ? TxaTheme.accent : Colors.amberAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Row(
            children: [
              if (hasActive)
                TextButton.icon(
                  onPressed: () => manager.pauseFilmDownloads(widget.film.filmSlug),
                  icon: const Icon(Icons.pause_rounded, size: 16, color: Colors.amberAccent),
                  label: Text(
                    TxaLanguage.t('pause_all'),
                    style: const TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    backgroundColor: Colors.amber.withValues(alpha: 0.12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                )
              else if (hasPaused)
                TextButton.icon(
                  onPressed: () => manager.resumeFilmDownloads(widget.film.filmSlug),
                  icon: const Icon(Icons.play_arrow_rounded, size: 16, color: Colors.greenAccent),
                  label: Text(
                    TxaLanguage.t('resume_all'),
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    backgroundColor: Colors.green.withValues(alpha: 0.12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => manager.cancelFilmDownloads(widget.film.filmSlug),
                icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.redAccent),
                label: Text(
                  TxaLanguage.t('cancel_all'),
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  backgroundColor: Colors.red.withValues(alpha: 0.12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
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
          widget.film.filmTitle,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white70),
            onPressed: _confirmDeleteAll,
            tooltip: TxaLanguage.t('delete_all_confirm'),
          ),
        ],
      ),
      body: FutureBuilder<List<TxaDownloadTask>>(
        future: manager.getTasksForFilm(widget.film.filmSlug),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: TxaTheme.accent));
          }

          final tasks = snapshot.data ?? [];
          if (tasks.isEmpty) {
            return Center(
              child: Text(
                TxaLanguage.t('no_movies'),
                style: const TextStyle(color: Colors.white54),
              ),
            );
          }

          // Auto-scroll to highlighted episode if opened via notification or shortcut
          if (!_hasAutoScrolled && _highlightedEpisodeId != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || !_scrollController.hasClients) return;
              final targetIdx = tasks.indexWhere((t) =>
                  t.episodeId == _highlightedEpisodeId ||
                  t.episodeName == _highlightedEpisodeId ||
                  t.id.contains(_highlightedEpisodeId!));
              if (targetIdx >= 0) {
                _hasAutoScrolled = true;
                _scrollController.animateTo(
                  (targetIdx * 72.0).clamp(0.0, _scrollController.position.maxScrollExtent),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                );
              }
            });
          }

          final completedTasks = tasks.where((t) => t.isCompleted).toList();
          final firstPlayable = completedTasks.isNotEmpty ? completedTasks.first : null;
          final filmTotalBytes = tasks.fold<int>(0, (sum, t) => sum + (t.downloadedBytes > 0 ? t.downloadedBytes : t.totalBytes));

          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: tasks.length + 2,
            itemBuilder: (ctx, idx) {
              if (idx == 0) {
                // Hero Banner
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        TxaTheme.cardBg,
                        TxaTheme.cardBg.withValues(alpha: 0.8),
                        TxaTheme.accent.withValues(alpha: 0.12),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: TxaTheme.accent.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: widget.film.filmPoster.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: widget.film.filmPoster,
                                width: 56,
                                height: 78,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(color: Colors.white10),
                                errorWidget: (_, __, ___) => Container(
                                  width: 56,
                                  height: 78,
                                  color: Colors.white10,
                                  child: const Icon(Icons.movie_rounded, color: Colors.white38),
                                ),
                              )
                            : Container(
                                width: 56,
                                height: 78,
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
                              widget.film.filmTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${completedTasks.length}/${tasks.length} ${TxaLanguage.t('all_episodes')} • ${TxaFormat.formatFileSize(filmTotalBytes)}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            if (firstPlayable != null)
                              SizedBox(
                                height: 34,
                                child: ElevatedButton.icon(
                                  onPressed: () => _playOffline(firstPlayable),
                                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                                  label: Text(
                                    TxaLanguage.t('play_now'),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: TxaTheme.accent,
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (idx == 1) {
                // Bulk Toolbar for this film: Pause All / Resume All / Cancel All
                return _buildFilmBulkToolbar(manager, tasks);
              }

              final task = tasks[idx - 2];
              final isCompleted = task.status == TxaDownloadStatus.completed;
              final isHighlighted = _highlightedEpisodeId != null &&
                  (task.episodeId == _highlightedEpisodeId ||
                   task.episodeName == _highlightedEpisodeId ||
                   task.id.contains(_highlightedEpisodeId!));

              // Use TxaDownloadRow for rich details on in-progress / paused / queued tasks
              if (!isCompleted) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  margin: const EdgeInsets.only(bottom: 8.0),
                  decoration: BoxDecoration(
                    color: isHighlighted ? TxaTheme.accent.withValues(alpha: 0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: isHighlighted
                        ? Border.all(color: TxaTheme.accent, width: 1.8)
                        : null,
                    boxShadow: isHighlighted
                        ? [
                            BoxShadow(
                              color: TxaTheme.accent.withValues(alpha: 0.35),
                              blurRadius: 16,
                              spreadRadius: 2,
                            )
                          ]
                        : null,
                  ),
                  child: TxaDownloadRow(
                    episodeName: task.episodeName,
                    task: task,
                    onPause: () => manager.pauseTask(task.id),
                    onResume: () => manager.resumeTask(task.id),
                    onCancel: () => manager.cancelTask(task.id),
                  ),
                );
              }

              final sizeStr = TxaFormat.formatFileSize(
                task.downloadedBytes > 0 ? task.downloadedBytes : task.totalBytes,
              );

              return AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isHighlighted
                      ? TxaTheme.accent.withValues(alpha: 0.18)
                      : TxaTheme.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isHighlighted
                        ? TxaTheme.accent
                        : Colors.white.withValues(alpha: 0.08),
                    width: isHighlighted ? 1.8 : 1.0,
                  ),
                  boxShadow: isHighlighted
                      ? [
                          BoxShadow(
                            color: TxaTheme.accent.withValues(alpha: 0.4),
                            blurRadius: 16,
                            spreadRadius: 2,
                          )
                        ]
                      : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _playOffline(task),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: TxaTheme.accent.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: TxaTheme.accent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  TxaFormat.formatEpisodeName(task.episodeName),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Text(
                                      '${task.serverName} • $sizeStr',
                                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 13),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.play_circle_fill_rounded, color: TxaTheme.accent, size: 30),
                            onPressed: () => _playOffline(task),
                            tooltip: TxaLanguage.t('play_now'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.white38, size: 20),
                            onPressed: () => _confirmDeleteTask(task),
                            tooltip: TxaLanguage.t('delete'),
                          ),
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
