import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/txa_download_status.dart';
import '../models/txa_download_task.dart';
import '../services/txa_download_manager.dart';
import '../services/txa_storage_estimator.dart';
import 'txa_download_settings_modal.dart';
import 'widgets/txa_download_row.dart';
import '../../../../theme/txa_theme.dart';
import '../../../../utils/txa_format.dart';
import '../../../../utils/txa_toast.dart';
import '../../../../services/txa_language.dart';

class TxaDownloadBottomSheet extends StatefulWidget {
  final Map<String, dynamic> movieData;

  const TxaDownloadBottomSheet({
    super.key,
    required this.movieData,
  });

  static Future<void> show(BuildContext context, Map<String, dynamic> movieData) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TxaDownloadBottomSheet(movieData: movieData),
    );
  }

  @override
  State<TxaDownloadBottomSheet> createState() => _TxaDownloadBottomSheetState();
}

class _TxaDownloadBottomSheetState extends State<TxaDownloadBottomSheet> {
  int _selectedServerIndex = 0;
  final Set<String> _selectedEpisodeIds = {};
  Set<String> _completedEpisodeIds = {};
  Map<String, int> _estimatedSizes = {};
  bool _isEstimating = false;
  final ScrollController _scrollController = ScrollController();

  String get _filmSlug => widget.movieData['movie']?['slug']?.toString() ?? '';
  String get _filmTitle => widget.movieData['movie']?['name']?.toString() ?? 'Phim';
  String get _filmPoster => widget.movieData['movie']?['poster_url']?.toString() ?? '';

  List<dynamic> get _servers => (widget.movieData['servers'] as List?) ?? [];
  List<dynamic> get _currentEpisodes {
    if (_servers.isEmpty) return [];
    final server = _servers[_selectedServerIndex.clamp(0, _servers.length - 1)];
    return (server['server_data'] as List?) ?? [];
  }

  String get _currentServerName {
    if (_servers.isEmpty) return 'Default';
    return _servers[_selectedServerIndex.clamp(0, _servers.length - 1)]['server_name']?.toString() ?? 'Default';
  }

  List<dynamic> get _selectableEpisodes {
    return _currentEpisodes.where((ep) {
      final epId = ep['slug']?.toString() ?? ep['name']?.toString() ?? '';
      final epName = ep['name']?.toString() ?? '';
      return !_completedEpisodeIds.contains(epId) &&
          !_completedEpisodeIds.contains(epName) &&
          !_completedEpisodeIds.contains('${_currentServerName}_$epId') &&
          !_completedEpisodeIds.contains('${_currentServerName}_$epName');
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _autoFocusActiveDownloadingTask();
    _estimateInitialSizes();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Tự động nhảy đến đúng server và cuộn tới vị trí tập đang tải khi mở lại modal
  void _autoFocusActiveDownloadingTask() async {
    final manager = Provider.of<TxaDownloadManager>(context, listen: false);
    final filmTasks = await manager.getTasksForFilm(_filmSlug);
    if (!mounted || filmTasks.isEmpty) return;

    TxaDownloadTask? activeTask;
    for (final t in filmTasks) {
      if (t.status == TxaDownloadStatus.downloading ||
          t.status == TxaDownloadStatus.merging ||
          t.status == TxaDownloadStatus.paused ||
          t.status == TxaDownloadStatus.queued) {
        activeTask = t;
        break;
      }
    }

    if (activeTask != null) {
      // 1. Chuyển sang đúng tab Server đang tải
      final serverIdx = _servers.indexWhere((s) {
        final sName = s['server_name']?.toString() ?? '';
        return sName.toLowerCase().trim() == activeTask!.serverName.toLowerCase().trim();
      });

      if (serverIdx != -1 && serverIdx != _selectedServerIndex) {
        if (mounted) {
          setState(() {
            _selectedServerIndex = serverIdx;
          });
        }
      }

      // 2. Tự động cuộn đến vị trí tập đang tải
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        final eps = _currentEpisodes;
        final epIdx = eps.indexWhere((ep) {
          final epName = ep['name']?.toString() ?? '';
          final epSlug = ep['slug']?.toString() ?? '';
          return epName == activeTask!.episodeName ||
              epSlug == activeTask.episodeId ||
              epName == activeTask.episodeId;
        });

        if (epIdx > 0) {
          final targetOffset = (epIdx * 64.0).clamp(
            0.0,
            _scrollController.position.maxScrollExtent,
          );
          _scrollController.animateTo(
            targetOffset,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  void _estimateInitialSizes() async {
    if (!mounted) return;
    setState(() => _isEstimating = true);

    final eps = _currentEpisodes;
    if (eps.isNotEmpty) {
      final firstEp = eps.first;
      final m3u8Url = _resolveStreamUrl(firstEp);
      if (m3u8Url != null) {
        final baseEst = await TxaStorageEstimator.estimateEpisodeSize(m3u8Url);
        if (mounted) {
          setState(() {
            _estimatedSizes = {
              for (int i = 0; i < eps.length; i++)
                eps[i]['slug']?.toString() ?? eps[i]['name']?.toString() ?? '': baseEst
            };
            _isEstimating = false;
          });
        }
        return;
      }
    }

    if (mounted) setState(() => _isEstimating = false);
  }

  String? _resolveStreamUrl(Map ep) {
    for (final key in ['link_m3u8', 'stream_m3u8', 'stream_v6']) {
      final val = ep[key]?.toString();
      if (val != null && val.trim().isNotEmpty) {
        return val.trim();
      }
    }
    for (final key in ['link_embed', 'stream_embed']) {
      final val = ep[key]?.toString();
      if (val != null && val.trim().isNotEmpty) {
        final cleanUrl = val.trim();
        final uriParam = Uri.tryParse(cleanUrl)?.queryParameters['url'];
        if (uriParam != null && uriParam.isNotEmpty) {
          return uriParam;
        }
        final regExp = RegExp(r'https?://([^/]+)/video/([a-zA-Z0-9_-]+)');
        final match = regExp.firstMatch(cleanUrl);
        if (match != null) {
          final domain = match.group(1);
          final hash = match.group(2);
          return 'https://$domain/stream/$hash/master.m3u8';
        }
      }
    }
    return null;
  }

  void _toggleSelectAll() {
    final selectable = _selectableEpisodes;
    if (selectable.isEmpty) return;

    setState(() {
      final isAllSelected = selectable.every((ep) {
        final id = ep['slug']?.toString() ?? ep['name']?.toString() ?? '';
        return _selectedEpisodeIds.contains(id);
      });

      if (isAllSelected) {
        _selectedEpisodeIds.clear();
      } else {
        _selectedEpisodeIds.clear();
        for (final ep in selectable) {
          final id = ep['slug']?.toString() ?? ep['name']?.toString() ?? '';
          _selectedEpisodeIds.add(id);
        }
      }
    });
  }

  /// Chọn tiếp 5 tập: tính từ tập đang chọn forward.
  /// Nếu trong phạm vi đã chọn thì nhảy tiếp. Hết danh sách thì quay vòng về đầu (cyclically).
  void _selectNextN(int count) {
    final selectable = _selectableEpisodes;
    if (selectable.isEmpty) return;

    int highestIdx = -1;
    for (int i = 0; i < selectable.length; i++) {
      final id = selectable[i]['slug']?.toString() ?? selectable[i]['name']?.toString() ?? '';
      if (_selectedEpisodeIds.contains(id)) {
        highestIdx = i;
      }
    }

    int startIdx = (highestIdx + 1) % selectable.length;
    int added = 0;
    setState(() {
      for (int step = 0; step < selectable.length; step++) {
        final idx = (startIdx + step) % selectable.length;
        final id = selectable[idx]['slug']?.toString() ?? selectable[idx]['name']?.toString() ?? '';
        if (!_selectedEpisodeIds.contains(id)) {
          _selectedEpisodeIds.add(id);
          added++;
          if (added >= count) break;
        }
      }
    });
  }

  void _startDownloadSelected() async {
    final manager = Provider.of<TxaDownloadManager>(context, listen: false);
    final List<TxaDownloadTask> newTasks = [];

    for (final ep in _currentEpisodes) {
      final epId = ep['slug']?.toString() ?? ep['name']?.toString() ?? '';
      if (_selectedEpisodeIds.contains(epId)) {
        if (_completedEpisodeIds.contains(epId)) continue;

        final m3u8Url = _resolveStreamUrl(ep);
        if (m3u8Url != null && m3u8Url.isNotEmpty) {
          final epName = ep['name']?.toString() ?? '${TxaLanguage.t('episode')} $epId';
          final taskId = '${_filmSlug}_${_currentServerName}_$epName';
          final estimatedBytes = _estimatedSizes[epId] ?? (250 * 1024 * 1024);

          newTasks.add(TxaDownloadTask(
            id: taskId,
            filmSlug: _filmSlug,
            filmTitle: _filmTitle,
            filmPoster: _filmPoster,
            serverName: _currentServerName,
            episodeId: epId,
            episodeName: epName,
            m3u8Url: m3u8Url,
            totalBytes: estimatedBytes,
          ));
        }
      }
    }

    if (newTasks.isEmpty) {
      TxaToast.show(context, TxaLanguage.t('download_link_not_found'));
      return;
    }

    await manager.enqueueBatch(newTasks);

    if (mounted) {
      TxaToast.show(
        context,
        TxaLanguage.t('download_all_started', replace: {'n': '${newTasks.length}'}),
        isError: false,
      );
      setState(() {
        _selectedEpisodeIds.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<TxaDownloadManager>(context);
    final episodes = _currentEpisodes;
    final totalSelectedSize = _selectedEpisodeIds.fold<int>(
      0,
      (sum, id) => sum + (_estimatedSizes[id] ?? 250 * 1024 * 1024),
    );

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: BoxDecoration(
        color: TxaTheme.primaryBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: TxaTheme.glassBorder),
      ),
      child: Column(
        children: [
          // Header Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title & Select All Header (Single source of Select All button)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            TxaLanguage.t('download_manager'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Speed & Concurrency Settings Trigger
                          InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => TxaDownloadSettingsModal.show(context),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: TxaTheme.accent.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.speed_rounded, size: 16, color: TxaTheme.accent),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$_filmTitle • ${episodes.length} ${TxaLanguage.t('all_episodes')}',
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Builder(
                  builder: (context) {
                    final selectable = _selectableEpisodes;
                    final isAllSelected = selectable.isNotEmpty && selectable.every((ep) {
                      final id = ep['slug']?.toString() ?? ep['name']?.toString() ?? '';
                      return _selectedEpisodeIds.contains(id);
                    });

                    return TextButton(
                      onPressed: selectable.isEmpty ? null : _toggleSelectAll,
                      style: TextButton.styleFrom(
                        foregroundColor: TxaTheme.accent,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      child: Text(
                        isAllSelected
                            ? TxaLanguage.t('deselect_all')
                            : TxaLanguage.t('select_all'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Quick selection toolbar (Duplicate Select All removed!)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                // +5 tập tiếp button
                Builder(
                  builder: (context) {
                    final selectable = _selectableEpisodes;
                    final unselected = selectable.where((ep) {
                      final id = ep['slug']?.toString() ?? ep['name']?.toString() ?? '';
                      return !_selectedEpisodeIds.contains(id);
                    }).toList();

                    return ActionChip(
                      avatar: Icon(
                        Icons.playlist_add_rounded,
                        size: 16,
                        color: unselected.isEmpty ? Colors.white24 : TxaTheme.accent,
                      ),
                      label: Text(TxaLanguage.t('select_next_5')),
                      onPressed: unselected.isEmpty ? null : () => _selectNextN(5),
                      backgroundColor: TxaTheme.cardBg,
                      labelStyle: TextStyle(
                        color: unselected.isEmpty ? Colors.white24 : Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    );
                  },
                ),
                const SizedBox(width: 8),

                // Bulk controls for this film: Pause / Resume / Cancel All if active
                FutureBuilder<List<TxaDownloadTask>>(
                  future: manager.getTasksForFilm(_filmSlug),
                  builder: (context, snap) {
                    final tasks = snap.data ?? [];
                    final hasActive = tasks.any((t) =>
                        t.status == TxaDownloadStatus.downloading ||
                        t.status == TxaDownloadStatus.merging ||
                        t.status == TxaDownloadStatus.queued);
                    final hasPaused = tasks.any((t) =>
                        t.status == TxaDownloadStatus.paused ||
                        t.status == TxaDownloadStatus.failed);

                    if (!hasActive && !hasPaused) return const SizedBox.shrink();

                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasActive)
                          ActionChip(
                            avatar: const Icon(Icons.pause_rounded, size: 15, color: Colors.amberAccent),
                            label: Text(TxaLanguage.t('pause_all')),
                            onPressed: () => manager.pauseFilmDownloads(_filmSlug),
                            backgroundColor: Colors.amber.withValues(alpha: 0.12),
                            labelStyle: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: Colors.amber.withValues(alpha: 0.3)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                          )
                        else if (hasPaused)
                          ActionChip(
                            avatar: const Icon(Icons.play_arrow_rounded, size: 15, color: Colors.greenAccent),
                            label: Text(TxaLanguage.t('resume_all')),
                            onPressed: () => manager.resumeFilmDownloads(_filmSlug),
                            backgroundColor: Colors.green.withValues(alpha: 0.12),
                            labelStyle: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: Colors.green.withValues(alpha: 0.3)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                          ),
                        const SizedBox(width: 6),
                        ActionChip(
                          avatar: const Icon(Icons.cancel_outlined, size: 15, color: Colors.redAccent),
                          label: Text(TxaLanguage.t('cancel_all')),
                          onPressed: () => manager.cancelFilmDownloads(_filmSlug),
                          backgroundColor: Colors.red.withValues(alpha: 0.12),
                          labelStyle: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                        ),
                      ],
                    );
                  },
                ),

                const Spacer(),
                Text(
                  '${_selectedEpisodeIds.length}/${_selectableEpisodes.length}',
                  style: const TextStyle(
                    color: TxaTheme.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Server selector chips if multiple servers
          if (_servers.length > 1)
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _servers.length,
                itemBuilder: (ctx, idx) {
                  final isSelected = _selectedServerIndex == idx;
                  final sName = _servers[idx]['server_name']?.toString() ?? 'Server ${idx + 1}';
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(sName),
                      selected: isSelected,
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            _selectedServerIndex = idx;
                            _selectedEpisodeIds.clear();
                          });
                          _estimateInitialSizes();
                        }
                      },
                      selectedColor: TxaTheme.accent,
                      backgroundColor: TxaTheme.cardBg,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.black : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      side: BorderSide.none,
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 8),

          // Episode List with ScrollController
          Expanded(
            child: FutureBuilder<List<TxaDownloadTask>>(
              future: manager.getTasksForFilm(_filmSlug),
              builder: (context, snapshot) {
                final existingTasks = snapshot.data ?? [];
                final Map<String, TxaDownloadTask> taskMap = {};
                final Set<String> completedIds = {};

                for (final t in existingTasks) {
                  taskMap['${t.serverName}_${t.episodeName}'] = t;
                  taskMap['${t.serverName}_${t.episodeId}'] = t;
                  taskMap[t.episodeId] = t;
                  taskMap[t.episodeName] = t;
                  if (t.isCompleted) {
                    completedIds.add(t.episodeId);
                    completedIds.add(t.episodeName);
                    completedIds.add('${t.serverName}_${t.episodeId}');
                    completedIds.add('${t.serverName}_${t.episodeName}');
                  }
                }

                if (_completedEpisodeIds.length != completedIds.length || !_completedEpisodeIds.containsAll(completedIds)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _completedEpisodeIds = completedIds;
                        _selectedEpisodeIds.removeWhere((id) => completedIds.contains(id));
                      });
                    }
                  });
                }

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: episodes.length,
                  itemBuilder: (ctx, idx) {
                    final ep = episodes[idx];
                    final epId = ep['slug']?.toString() ?? ep['name']?.toString() ?? '';
                    final epName = ep['name']?.toString() ?? '${TxaLanguage.t('episode')} ${idx + 1}';
                    final isSelected = _selectedEpisodeIds.contains(epId);
                    final task = taskMap['${_currentServerName}_$epName'] ??
                        taskMap['${_currentServerName}_$epId'] ??
                        taskMap[epId] ??
                        taskMap[epName];

                    final estBytes = _estimatedSizes[epId];
                    final estSizeStr = estBytes != null ? TxaFormat.formatFileSize(estBytes) : null;

                    return TxaDownloadRow(
                      episodeName: epName,
                      estimatedSizeStr: estSizeStr,
                      isSelected: isSelected,
                      task: task,
                      onSelectedChanged: (task?.isCompleted ?? false)
                          ? null
                          : (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedEpisodeIds.add(epId);
                                } else {
                                  _selectedEpisodeIds.remove(epId);
                                }
                              });
                            },
                      onPause: () => manager.pauseTask(task!.id),
                      onResume: () => manager.resumeTask(task!.id),
                      onCancel: () => manager.cancelTask(task!.id),
                    );
                  },
                );
              },
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
            decoration: BoxDecoration(
              color: TxaTheme.cardBg,
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedEpisodeIds.isEmpty
                            ? TxaLanguage.t('no_episode_selected')
                            : TxaLanguage.t('episodes_selected', replace: {'n': '${_selectedEpisodeIds.length}'}),
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        _isEstimating
                            ? TxaLanguage.t('preparing')
                            : (totalSelectedSize > 0
                                ? '~${TxaFormat.formatFileSize(totalSelectedSize)}'
                                : '0 B'),
                        style: const TextStyle(
                          color: TxaTheme.accent,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _selectedEpisodeIds.isEmpty ? null : _startDownloadSelected,
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: Text(
                    _selectedEpisodeIds.isEmpty
                        ? TxaLanguage.t('download')
                        : (_selectableEpisodes.isNotEmpty && _selectedEpisodeIds.length == _selectableEpisodes.length
                            ? TxaLanguage.t('download_all_episodes', replace: {'n': '${_selectedEpisodeIds.length}'})
                            : TxaLanguage.t('download_selected_episodes', replace: {'n': '${_selectedEpisodeIds.length}'})),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TxaTheme.accent,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: Colors.white12,
                    disabledForegroundColor: Colors.white30,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
