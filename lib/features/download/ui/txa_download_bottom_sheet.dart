import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/txa_download_task.dart';
import '../models/txa_download_status.dart';
import '../services/txa_download_manager.dart';
import '../services/txa_storage_estimator.dart';
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
  Map<String, int> _estimatedSizes = {};
  bool _isEstimating = false;

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

  @override
  void initState() {
    super.initState();
    _estimateInitialSizes();
  }

  void _estimateInitialSizes() async {
    if (!mounted) return;
    setState(() => _isEstimating = true);

    final eps = _currentEpisodes;
    if (eps.isNotEmpty) {
      final firstEp = eps.first;
      final m3u8Url = _resolveStreamUrl(firstEp);
      if (m3u8Url != null) {
        final avgSize = await TxaStorageEstimator.estimateEpisodeSize(m3u8Url);
        if (mounted) {
          setState(() {
            _estimatedSizes = {for (var ep in eps) ep['slug']?.toString() ?? ep['name']?.toString() ?? '': avgSize};
            _isEstimating = false;
          });
        }
        return;
      }
    }

    if (mounted) setState(() => _isEstimating = false);
  }

  String? _resolveStreamUrl(Map<String, dynamic> ep) {
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
    setState(() {
      if (_selectedEpisodeIds.length == _currentEpisodes.length) {
        _selectedEpisodeIds.clear();
      } else {
        _selectedEpisodeIds.clear();
        for (final ep in _currentEpisodes) {
          final id = ep['slug']?.toString() ?? ep['name']?.toString() ?? '';
          _selectedEpisodeIds.add(id);
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
        final m3u8Url = _resolveStreamUrl(ep);
        if (m3u8Url != null && m3u8Url.isNotEmpty) {
          final epName = ep['name']?.toString() ?? 'Tập $epId';
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
      height: MediaQuery.of(context).size.height * 0.75,
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

          // Title & Select All Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        TxaLanguage.t('download_manager'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
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
                TextButton(
                  onPressed: _toggleSelectAll,
                  style: TextButton.styleFrom(
                    foregroundColor: TxaTheme.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  child: Text(
                    _selectedEpisodeIds.length == episodes.length
                        ? TxaLanguage.t('clear')
                        : TxaLanguage.t('all_episodes'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
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

          // Episode List
          Expanded(
            child: FutureBuilder<List<TxaDownloadTask>>(
              future: manager.getTasksForFilm(_filmSlug),
              builder: (context, snapshot) {
                final existingTasks = snapshot.data ?? [];
                final Map<String, TxaDownloadTask> taskMap = {};
                for (final t in existingTasks) {
                  taskMap['${t.serverName}_${t.episodeName}'] = t;
                }

                return ListView.builder(
                  itemCount: episodes.length,
                  itemBuilder: (ctx, idx) {
                    final ep = episodes[idx];
                    final epId = ep['slug']?.toString() ?? ep['name']?.toString() ?? '';
                    final epName = ep['name']?.toString() ?? 'Tập ${idx + 1}';
                    final isSelected = _selectedEpisodeIds.contains(epId);
                    final task = taskMap['${_currentServerName}_$epName'];

                    final estBytes = _estimatedSizes[epId];
                    final estSizeStr = estBytes != null ? TxaFormat.formatFileSize(estBytes) : null;

                    return TxaDownloadRow(
                      episodeName: epName,
                      estimatedSizeStr: estSizeStr,
                      isSelected: isSelected,
                      task: task,
                      onSelectedChanged: task?.status == TxaDownloadStatus.completed
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
                        '${_selectedEpisodeIds.length} ${TxaLanguage.t('episode_label', replace: {'n': ''}).trim()} ${TxaLanguage.t('downloaded').toLowerCase()}',
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
                    _selectedEpisodeIds.length == episodes.length
                        ? TxaLanguage.t('download_all_started', replace: {'n': '${episodes.length}'})
                        : TxaLanguage.t('download_completed'),
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
