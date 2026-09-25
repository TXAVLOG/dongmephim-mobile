import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/txa_local_film.dart';
import '../models/txa_download_task.dart';
import '../models/txa_download_status.dart';
import '../services/txa_download_manager.dart';
import '../../../../theme/txa_theme.dart';
import '../../../../utils/txa_format.dart';
import '../../../../utils/txa_toast.dart';
import '../../../../services/txa_language.dart';
import '../../../../services/txa_offline_history_service.dart';
import '../../../../widgets/txa_video_player.dart';

class DownloadedEpisodesScreen extends StatefulWidget {
  final TxaLocalFilm film;

  const DownloadedEpisodesScreen({
    super.key,
    required this.film,
  });

  @override
  State<DownloadedEpisodesScreen> createState() => _DownloadedEpisodesScreenState();
}

class _DownloadedEpisodesScreenState extends State<DownloadedEpisodesScreen> {
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

          final completedTasks = tasks.where((t) => t.isCompleted).toList();
          final firstPlayable = completedTasks.isNotEmpty ? completedTasks.first : null;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: tasks.length + 1,
            itemBuilder: (ctx, idx) {
              if (idx == 0) {
                // Hero Banner
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
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
                              '${completedTasks.length}/${tasks.length} ${TxaLanguage.t('all_episodes')}',
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

              final task = tasks[idx - 1];
              final isCompleted = task.status == TxaDownloadStatus.completed;
              final sizeStr = TxaFormat.formatFileSize(
                task.downloadedBytes > 0 ? task.downloadedBytes : task.totalBytes,
              );

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: TxaTheme.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isCompleted
                        ? Colors.white.withValues(alpha: 0.08)
                        : TxaTheme.accent.withValues(alpha: 0.2),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: isCompleted ? () => _playOffline(task) : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? TxaTheme.accent.withValues(alpha: 0.15)
                                  : Colors.white10,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isCompleted ? Icons.play_arrow_rounded : Icons.downloading_rounded,
                              color: isCompleted ? TxaTheme.accent : Colors.white70,
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
                                    if (isCompleted) ...[
                                      const SizedBox(width: 6),
                                      const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 13),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (isCompleted)
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
