import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/txa_api.dart';
import '../services/txa_language.dart';
import '../theme/txa_theme.dart';
import '../utils/txa_toast.dart';
import 'txa_movie_detail_screen.dart';

class TxaWatchHistoryScreen extends StatefulWidget {
  const TxaWatchHistoryScreen({super.key});

  @override
  State<TxaWatchHistoryScreen> createState() => _TxaWatchHistoryScreenState();
}

class _TxaWatchHistoryScreenState extends State<TxaWatchHistoryScreen> {
  List<dynamic> _allHistory = [];
  List<dynamic> _displayHistory = [];
  bool _loading = true;
  String? _error;
  int _displayCount = 15;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_loading &&
          _displayCount < _allHistory.length) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await TxaApi().getWatchHistory();
      setState(() {
        _allHistory = res;
        _displayCount = 15;
        _updateDisplayList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        TxaToast.show(
          context,
          TxaLanguage.t('error_loading_data'),
          isError: true,
        );
      }
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _loadMore() {
    setState(() {
      _displayCount = (_displayCount + 15).clamp(0, _allHistory.length);
      _updateDisplayList();
    });
  }

  void _updateDisplayList() {
    if (_allHistory.isEmpty) {
      _displayHistory = [];
    } else {
      final end = _displayCount.clamp(0, _allHistory.length);
      _displayHistory = _allHistory.sublist(0, end);
    }
  }

  Future<void> _handleClearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TxaTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          TxaLanguage.t('clear'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          TxaLanguage.t('history_clear_confirm'),
          style: const TextStyle(color: TxaTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(TxaLanguage.t('cancel'), style: const TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              TxaLanguage.t('clear'),
              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _loading = true);
      final success = await TxaApi().clearWatchHistory();
      if (!mounted) return;
      if (success) {
        TxaToast.show(context, TxaLanguage.t('history_cleared'));
        setState(() {
          _allHistory.clear();
          _displayHistory.clear();
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
        TxaToast.show(context, TxaLanguage.t('history_clear_failed'), isError: true);
      }
    }
  }

  String _formatTimeProgress(double current, double duration) {
    String formatSeconds(double sec) {
      final durationObj = Duration(seconds: sec.toInt());
      final hours = durationObj.inHours;
      final minutes = durationObj.inMinutes.remainder(60);
      final seconds = durationObj.inSeconds.remainder(60);

      if (hours > 0) {
        return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      } else {
        return '$minutes:${seconds.toString().padLeft(2, '0')}';
      }
    }

    return '${formatSeconds(current)} / ${formatSeconds(duration)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TxaTheme.primaryBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          TxaLanguage.t('watch_history'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_allHistory.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
              onPressed: _handleClearHistory,
              tooltip: TxaLanguage.t('clear'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: TxaTheme.accent,
        backgroundColor: TxaTheme.cardBg,
        child: _displayHistory.isEmpty && _loading
            ? const Center(
                child: CircularProgressIndicator(color: TxaTheme.accent),
              )
            : _error != null && _displayHistory.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 48,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          TxaLanguage.t('error_loading_data'),
                          style: const TextStyle(color: TxaTheme.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadData,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: Text(TxaLanguage.t('retry')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TxaTheme.accent,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  )
                : _displayHistory.isEmpty
                    ? Center(
                        child: Text(
                          TxaLanguage.t('no_history_yet'),
                          style: const TextStyle(color: TxaTheme.textSecondary, fontSize: 14),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _displayHistory.length + (_displayCount < _allHistory.length ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _displayHistory.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(child: CircularProgressIndicator(color: TxaTheme.accent)),
                            );
                          }

                          final item = _displayHistory[index];
                          final name = item['movie_name'] ?? '';
                          final epName = item['episode_name'] ?? '';
                          final thumbUrl = item['movie_thumb'] ?? '';
                          final current = double.tryParse(item['current_time']?.toString() ?? '0') ?? 0.0;
                          final duration = double.tryParse(item['duration']?.toString() ?? '0') ?? 0.0;
                          final progress = (duration > 0) ? (current / duration).clamp(0.0, 1.0) : 0.0;
                          final date = item['updated_at'] != null ? item['updated_at'].toString().split('T')[0] : '';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.02),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (ctx) => MovieDetailScreen(slug: item['movie_slug'] ?? ''),
                                      ),
                                    ).then((_) => _loadData());
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Row(
                                      children: [
                                        // Poster image with progress overlay
                                        SizedBox(
                                          width: 100,
                                          height: 60,
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                CachedNetworkImage(
                                                  imageUrl: thumbUrl,
                                                  fit: BoxFit.cover,
                                                  placeholder: (c, u) => Container(color: TxaTheme.cardBg),
                                                  errorWidget: (c, u, e) => Container(color: TxaTheme.cardBg),
                                                ),
                                                Positioned(
                                                  bottom: 0,
                                                  left: 0,
                                                  right: 0,
                                                  child: LinearProgressIndicator(
                                                    value: progress,
                                                    minHeight: 3,
                                                    backgroundColor: Colors.white24,
                                                    valueColor: const AlwaysStoppedAnimation<Color>(TxaTheme.accent),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        
                                        // Info metadata
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                epName,
                                                style: const TextStyle(color: TxaTheme.accent, fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                              const SizedBox(height: 4),
                                              if (duration > 0)
                                                Text(
                                                  _formatTimeProgress(current, duration),
                                                  style: const TextStyle(color: TxaTheme.textSecondary, fontSize: 10),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // Chevron icon & date
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 12),
                                            const SizedBox(height: 12),
                                            Text(date, style: const TextStyle(color: TxaTheme.textMuted, fontSize: 8)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
