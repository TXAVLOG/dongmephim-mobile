import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../services/txa_api.dart';
import '../services/txa_language.dart';
import '../services/txa_auth_service.dart';
import '../services/txa_favorite_manager.dart';
import '../theme/txa_theme.dart';
import '../utils/txa_toast.dart';
import '../utils/txa_platform.dart';
import '../widgets/txa_video_player.dart';
import '../utils/txa_schedule.dart';
import 'txa_profile_screen.dart';

class MovieDetailScreen extends StatefulWidget {
  final String slug;
  const MovieDetailScreen({super.key, required this.slug});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  bool _descExpanded = false;
  late TabController _tabController;
  int _selectedServerIndex = 0;
  bool _isFavorite = false;
  int _activeTabIndex = 0;
  bool get _isAdmin {
    final auth = Provider.of<TxaAuthService>(context, listen: false);
    return auth.isLoggedIn && auth.user?['role'] == 'admin';
  }
  bool _scanning = false; // Scan loading status
  int _activeEpisodePage = 0; // Current active episodes pagination page
  bool _isCompact = true; // Toggle between compact text buttons and thumbnail-based grid

  // Comments & Ratings States
  List<dynamic> _comments = [];
  bool _commentsLoading = true;
  final _commentController = TextEditingController();
  bool _commentSubmitting = false;
  bool _isSpoilerComment = false;

  int _userRating = 0;
  double _averageRating = 0.0;
  int _totalRatings = 0;

  // Active reply fields
  String? _replyingToCommentId;
  final _replyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    TxaLanguage().addListener(_onLanguageChanged);
    TxaFavoriteManager().favorites.addListener(_onFavoritesChanged);
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _activeTabIndex = _tabController.index;
        });
      }
    });
    _loadDetail();
    _loadComments();
    _loadRating();
  }

  void _onFavoritesChanged() {
    if (!mounted) return;
    final isFav = TxaFavoriteManager().isFavorite(widget.slug);
    if (isFav != _isFavorite) {
      setState(() => _isFavorite = isFav);
    }
  }

  @override
  void dispose() {
    TxaLanguage().removeListener(_onLanguageChanged);
    TxaFavoriteManager().favorites.removeListener(_onFavoritesChanged);
    _tabController.dispose();
    _commentController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  void _onLanguageChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  String _cleanEpisodeName(String name) {
    String cleaned = name.trim();
    cleaned = cleaned.replaceAll(RegExp(r'^(tập|tap|ep|episode|ep-|-)+\s*', caseSensitive: false), '');
    return cleaned.isEmpty ? name : cleaned;
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await TxaApi().getMovie(widget.slug);
      if (res != null) {
        final isFav = res['movie']?['is_favorite'] == true;
        // Sync with global manager
        TxaFavoriteManager().setFavorite(widget.slug, isFav);

        // Sắp xếp các server có nhiều tập lên đầu tiên
        if (res['servers'] != null) {
          final List<dynamic> sortedServers = List.from(res['servers']);
          sortedServers.sort((a, b) {
            final aLen = (a['server_data'] as List? ?? []).length;
            final bLen = (b['server_data'] as List? ?? []).length;
            return bLen.compareTo(aLen); // Sắp xếp giảm dần theo số tập
          });
          res['servers'] = sortedServers;
        }

        setState(() {
          _data = res;
          _isFavorite = isFav;
          _selectedServerIndex = 0;
          _activeEpisodePage = 0;
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load movie details';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadComments() async {
    setState(() {
      _commentsLoading = true;
    });
    try {
      final res = await TxaApi().getComments(widget.slug);
      if (mounted) {
        setState(() {
          _comments = res;
          _commentsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _commentsLoading = false;
        });
      }
    }
  }

  Future<void> _loadRating() async {
    try {
      final res = await TxaApi().getRating(widget.slug);
      if (res != null && mounted) {
        setState(() {
          _userRating = int.tryParse(res['userRating']?.toString() ?? '0') ?? 0;
          _averageRating = double.tryParse(res['averageRating']?.toString() ?? '0.0') ?? 0.0;
          _totalRatings = int.tryParse(res['totalRatings']?.toString() ?? '0') ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _handleScan() async {
    setState(() => _scanning = true);
    TxaToast.show(context, TxaLanguage.t('admin_scanning'));
    try {
      final oldServers = _data?['servers'] as List? ?? [];
      final oldEpisodesCount = oldServers.isNotEmpty ? (oldServers[0]['server_data'] as List? ?? []).length : 0;

      final result = await TxaApi().scanMovie(widget.slug);
      if (!mounted) return;
      if (result.success) {
        final newCount = result.totalEpisodes;
        if (newCount > oldEpisodesCount) {
          final added = newCount - oldEpisodesCount;
          TxaToast.show(
            context,
            TxaLanguage.t('admin_scan_success_added', replace: {'count': added.toString()}),
            isError: false,
          );
        } else {
          TxaToast.show(
            context,
            TxaLanguage.t('admin_scan_up_to_date'),
            isError: false,
          );
        }
        _loadDetail();
      } else {
        TxaToast.show(context, result.message, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      TxaToast.show(
        context,
        TxaLanguage.t('admin_scan_error', replace: {'error': e.toString()}),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _scanning = false);
      }
    }
  }

  void _toggleFavorite() async {
    final auth = Provider.of<TxaAuthService>(context, listen: false);
    if (!auth.isLoggedIn) {
      TxaToast.show(context, TxaLanguage.t('login_required_favorites'));
      return;
    }

    // Optimistic UI update
    final newFav = !_isFavorite;
    setState(() => _isFavorite = newFav);
    TxaFavoriteManager().setFavorite(widget.slug, newFav);

    final res = await TxaApi().toggleFavorite(widget.slug);
    if (res != null) {
      if (mounted) {
        final confirmed = res['is_favorite'] == true;
        setState(() => _isFavorite = confirmed);
        TxaFavoriteManager().setFavorite(widget.slug, confirmed);
        TxaToast.show(
          context,
          confirmed
              ? TxaLanguage.t('favorite_added')
              : TxaLanguage.t('favorite_removed'),
        );
      }
    } else {
      // Revert on error
      if (mounted) {
        setState(() => _isFavorite = !newFav);
        TxaFavoriteManager().setFavorite(widget.slug, !newFav);
        TxaToast.show(context, TxaLanguage.t('error_connection'), isError: true);
      }
    }
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TxaTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          TxaLanguage.t('login_required_watch_title'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          TxaLanguage.t('login_required_watch_desc'),
          style: const TextStyle(color: TxaTheme.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              TxaLanguage.t('cancel'),
              style: const TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (ctx) => const TxaProfileScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: TxaTheme.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(TxaLanguage.t('login_now')),
          ),
        ],
      ),
    );
  }

  String? _resolveStreamUrl(Map<String, dynamic> ep) {
    // On Windows, HLS (m3u8) streams from R2 are not supported by WMF.
    // Skip m3u8 on Windows and fall through to embed streams.
    if (!TxaPlatform.isDesktop || !Platform.isWindows) {
      for (final key in ['link_m3u8', 'stream_m3u8', 'stream_v6']) {
        final val = ep[key]?.toString();
        if (val != null && val.trim().isNotEmpty) {
          return val.trim();
        }
      }
    }

    for (final key in ['link_embed', 'stream_embed']) {
      final val = ep[key]?.toString();
      if (val != null && val.trim().isNotEmpty) {
        final cleanUrl = val.trim();
        final regExp = RegExp(r'https?://([^/]+)/video/([a-zA-Z0-9_-]+)');
        final match = regExp.firstMatch(cleanUrl);
        if (match != null) {
          final domain = match.group(1);
          final hash = match.group(2);
          return 'https://$domain/stream/$hash/master.m3u8';
        }
        // On Windows, also try returning raw embed URL for webview
        if (TxaPlatform.isDesktop && Platform.isWindows) {
          return cleanUrl;
        }
      }
    }

    // Windows fallback: try m3u8 anyway as last resort
    if (TxaPlatform.isDesktop && Platform.isWindows) {
      for (final key in ['link_m3u8', 'stream_m3u8', 'stream_v6']) {
        final val = ep[key]?.toString();
        if (val != null && val.trim().isNotEmpty) {
          return val.trim();
        }
      }
    }

    return null;
  }

  void _watchMovie(String episodeId, String episodeName, {int startTime = 0}) async {
    final auth = Provider.of<TxaAuthService>(context, listen: false);
    final isRequireLogin = _data?['movie']?['require_login'] == true;
    if (isRequireLogin && !auth.isLoggedIn) {
      _showLoginRequiredDialog();
      return;
    }

    final servers = _data?['servers'] as List? ?? [];
    String? resolvedUrl;
    String resolvedServer = TxaLanguage.t('default_server');
    Map<String, dynamic>? activeEp;

    // Ưu tiên tìm trong server được chọn trước
    if (servers.length > _selectedServerIndex) {
      final selectedServer = servers[_selectedServerIndex];
      final serverData = selectedServer['server_data'] as List? ?? [];
      for (var ep in serverData) {
        if (ep['id']?.toString() == episodeId || ep['slug']?.toString() == episodeId) {
          resolvedUrl = _resolveStreamUrl(ep);
          if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
            resolvedServer = selectedServer['server_name'] ?? TxaLanguage.t('default_server');
            activeEp = ep;
            break;
          }
        }
      }
    }

    // Nếu không tìm thấy, duyệt qua các server khác để fallback
    if (resolvedUrl == null || resolvedUrl.isEmpty) {
      for (int i = 0; i < servers.length; i++) {
        if (i == _selectedServerIndex) continue;
        final server = servers[i];
        final serverData = server['server_data'] as List? ?? [];
        for (var ep in serverData) {
          if (ep['id']?.toString() == episodeId || ep['slug']?.toString() == episodeId) {
            resolvedUrl = _resolveStreamUrl(ep);
            if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
              resolvedServer = server['server_name'] ?? TxaLanguage.t('default_server');
              activeEp = ep;
              _selectedServerIndex = i; // Cập nhật lại index đã tìm thấy
              break;
            }
          }
        }
        if (resolvedUrl != null && resolvedUrl.isNotEmpty) break;
      }
    }

    if (resolvedUrl == null || resolvedUrl.isEmpty) {
      TxaToast.show(context, TxaLanguage.t('no_stream_found'), isError: true);
      return;
    }

    final movieId = _data?['movie']?['id']?.toString() ?? '';

    if (auth.isLoggedIn && _data?['movie'] != null) {
      await TxaApi().updateWatchHistory(
        movieId,
        episodeId,
        startTime > 0 ? startTime.toDouble() : 120.0,
        1440.0, // mock duration
        _selectedServerIndex,
      );
    }

    // Resolve next episode
    List<dynamic> serverEps = [];
    if (servers.isNotEmpty) {
      serverEps = servers[_selectedServerIndex]['server_data'] as List? ?? [];
    }
    int currentEpIdx = -1;
    for (int i = 0; i < serverEps.length; i++) {
      if (serverEps[i]['id']?.toString() == episodeId || serverEps[i]['slug']?.toString() == episodeId) {
        currentEpIdx = i;
        break;
      }
    }

    Map<String, dynamic>? nextEpMap;
    if (currentEpIdx != -1 && currentEpIdx + 1 < serverEps.length) {
      final nextEp = serverEps[currentEpIdx + 1];
      nextEpMap = {
        'id': nextEp['id']?.toString() ?? nextEp['slug']?.toString(),
        'name': nextEp['name'] ?? 'Tập tiếp theo',
        'movieName': _data?['movie']?['name'] ?? 'Phim',
        'thumb': _data?['movie']?['thumb_url'] ?? _data?['movie']?['poster_url'] ?? '',
      };
    }

    Map<String, dynamic>? prevEpMap;
    if (currentEpIdx > 0 && currentEpIdx < serverEps.length) {
      final prevEp = serverEps[currentEpIdx - 1];
      prevEpMap = {
        'id': prevEp['id']?.toString() ?? prevEp['slug']?.toString(),
        'name': prevEp['name'] ?? 'Tập trước',
        'movieName': _data?['movie']?['name'] ?? 'Phim',
        'thumb': _data?['movie']?['thumb_url'] ?? _data?['movie']?['poster_url'] ?? '',
      };
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TxaVideoPlayer(
            url: resolvedUrl!,
            movieName: _data?['movie']?['name'] ?? 'Phim',
            episodeName: episodeName,
            serverName: resolvedServer,
            adSettings: _data?['ads'] as Map<String, dynamic>?,
            subtitles: activeEp?['subtitles'] ?? activeEp?['subtitles_data'],
            storyboardUrl: activeEp?['storyboardUrl'] ?? activeEp?['storyboard_url'],
            timeIntroStart: int.tryParse(activeEp?['timeIntroStart']?.toString() ?? '') ?? int.tryParse(activeEp?['time_intro_start']?.toString() ?? '') ?? 0,
            timeIntroEnd: int.tryParse(activeEp?['timeIntroEnd']?.toString() ?? '') ?? int.tryParse(activeEp?['time_intro_end']?.toString() ?? '') ?? 0,
            timeOutroStart: int.tryParse(activeEp?['timeOutroStart']?.toString() ?? '') ?? int.tryParse(activeEp?['time_outro_start']?.toString() ?? '') ?? 0,
            timeOutroEnd: int.tryParse(activeEp?['timeOutroEnd']?.toString() ?? '') ?? int.tryParse(activeEp?['time_outro_end']?.toString() ?? '') ?? 0,
            nextEpisode: nextEpMap,
            onPlayNext: nextEpMap != null ? () {
              Navigator.pop(context); // Close current player
              _watchMovie(nextEpMap!['id'].toString(), nextEpMap['name'].toString());
            } : null,
            prevEpisode: prevEpMap,
            onPlayPrev: prevEpMap != null ? () {
              Navigator.pop(context); // Close current player
              _watchMovie(prevEpMap!['id'].toString(), prevEpMap['name'].toString());
            } : null,
            servers: servers,
            initialServerIndex: _selectedServerIndex,
            currentEpisodeId: episodeId,
            onEpisodeChanged: (epId, epName, srvIdx) {
              setState(() {
                _selectedServerIndex = srvIdx;
              });
            },
            onEnded: () {
              Navigator.pop(context);
            },
            movieId: movieId,
            startTime: startTime,
          ),
        ),
      ).then((_) {
        _loadDetail();
      });
    }
  }

  void _shareMovie() {
    final movie = _data?['movie'];
    if (movie == null) return;
    final shareText =
        'Xem phim : ${movie['name']} tại https://dongmephim.online/phim/${widget.slug} ngay nào bạn ơi!';
    // ignore: deprecated_member_use
    Share.share(shareText, subject: movie['name']);
  }

  void _showRatingDialog() {
    final auth = Provider.of<TxaAuthService>(context, listen: false);
    if (!auth.isLoggedIn) {
      TxaToast.show(context, TxaLanguage.t('login_to_rate'), isError: true);
      return;
    }

    if (_userRating > 0) {
      TxaToast.show(context, TxaLanguage.t('already_rated'), isError: true);
      return;
    }

    int tempRating = 8;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TxaTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          TxaLanguage.t('rating_title'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  TxaLanguage.t('give_stars'),
                  style: const TextStyle(color: TxaTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                
                // 10 Stars wrap
                Wrap(
                  spacing: 4,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: List.generate(10, (index) {
                    final starVal = index + 1;
                    final isHighlighted = starVal <= tempRating;
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          tempRating = starVal;
                        });
                      },
                      child: Icon(
                        isHighlighted ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: isHighlighted ? Colors.amber : TxaTheme.textMuted,
                        size: 32,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                Text(
                  TxaLanguage.t('rating_val_label', replace: {'n': tempRating.toString()}),
                  style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(TxaLanguage.t('close'), style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              TxaToast.show(context, TxaLanguage.t('rating_submitting'));
              final res = await TxaApi().postRating(widget.slug, tempRating);
              if (!mounted) return;
              if (res != null) {
                setState(() {
                  _userRating = tempRating;
                  _averageRating = double.tryParse(res['averageRating']?.toString() ?? '0.0') ?? 0.0;
                  _totalRatings = int.tryParse(res['totalRatings']?.toString() ?? '0') ?? 0;
                });
                TxaToast.show(context, TxaLanguage.t('rating_success'));
              } else {
                TxaToast.show(context, TxaLanguage.t('rating_failed'), isError: true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: TxaTheme.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(TxaLanguage.t('rating_submit')),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePostComment() async {
    final auth = Provider.of<TxaAuthService>(context, listen: false);
    if (!auth.isLoggedIn) {
      TxaToast.show(context, TxaLanguage.t('login_required'));
      return;
    }

    final text = _commentController.text.trim();
    if (text.isEmpty) {
      TxaToast.show(context, TxaLanguage.t('comment_empty'), isError: true);
      return;
    }

    setState(() {
      _commentSubmitting = true;
    });

    final res = await TxaApi().postComment(
      widget.slug,
      text,
      author: auth.user!['name'] ?? auth.user!['username'],
      isSpoiler: _isSpoilerComment,
    );

    if (mounted) {
      setState(() {
        _commentSubmitting = false;
      });

      if (res != null) {
        _commentController.clear();
        _isSpoilerComment = false;
        TxaToast.show(context, TxaLanguage.t('comment_success'));
        _loadComments();
      } else {
        TxaToast.show(context, TxaLanguage.t('comment_failed'), isError: true);
      }
    }
  }

  Future<void> _handlePostReply(String commentId) async {
    final auth = Provider.of<TxaAuthService>(context, listen: false);
    if (!auth.isLoggedIn) {
      TxaToast.show(context, TxaLanguage.t('login_required'));
      return;
    }

    final text = _replyController.text.trim();
    if (text.isEmpty) {
      TxaToast.show(context, TxaLanguage.t('reply_empty'), isError: true);
      return;
    }

    TxaToast.show(context, TxaLanguage.t('reply_submitting'));
    final res = await TxaApi().replyComment(
      commentId,
      text,
      replyAuthor: auth.user!['name'] ?? auth.user!['username'],
    );

    if (!mounted) return;
    if (res != null) {
      _replyController.clear();
      setState(() {
        _replyingToCommentId = null;
      });
      TxaToast.show(context, TxaLanguage.t('reply_success'));
      _loadComments();
    } else {
      TxaToast.show(context, TxaLanguage.t('reply_failed'), isError: true);
    }
  }

  Future<void> _handleLikeComment(String commentId) async {
    final res = await TxaApi().likeComment(commentId);
    if (!mounted) return;
    if (res != null) {
      TxaToast.show(context, TxaLanguage.t('comment_liked'));
      _loadComments();
    }
  }

  Future<void> _handleDeleteComment(String commentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TxaTheme.cardBg,
        title: Text(TxaLanguage.t('comment_delete_title'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(TxaLanguage.t('comment_delete_confirm'), style: const TextStyle(color: TxaTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(TxaLanguage.t('cancel'), style: const TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(TxaLanguage.t('delete'), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await TxaApi().deleteComment(commentId);
      if (!mounted) return;
      if (success) {
        TxaToast.show(context, TxaLanguage.t('comment_deleted'));
        _loadComments();
      }
    }
  }

  // --- Main Build ---

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: TxaTheme.primaryBg,
        body: Center(
          child: CircularProgressIndicator(color: TxaTheme.accent),
        ),
      );
    }

    if (_error != null || _data == null || _data!['movie'] == null) {
      return Scaffold(
        backgroundColor: TxaTheme.primaryBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              Text(
                TxaLanguage.t('error_loading_data'),
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadDetail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: TxaTheme.accent,
                  foregroundColor: Colors.white,
                ),
                child: Text(TxaLanguage.t('retry')),
              ),
            ],
          ),
        ),
      );
    }

    final movie = _data!['movie'];
    final servers = _data!['servers'] as List? ?? [];
    final related = _data!['related'] as List? ?? [];

    final bannerUrl = movie['poster_url'] ?? movie['thumb_url'] ?? '';
    final name = movie['name'] ?? '';
    final originName = movie['origin_name'] ?? '';
    final content = movie['content'] ?? '';
    final year = movie['year']?.toString() ?? '';
    final quality = movie['quality']?.toString() ?? '';
    final time = movie['time']?.toString() ?? '';
    final categories = movie['categories'] as List? ?? [];

    return Scaffold(
      backgroundColor: TxaTheme.primaryBg,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Banner area
                SliverToBoxAdapter(
                  child: Stack(
                    children: [
                      SizedBox(
                        height: 260,
                        width: double.infinity,
                        child: CachedNetworkImage(
                          imageUrl: bannerUrl,
                          fit: BoxFit.cover,
                          placeholder: (ctx, url) => Container(color: TxaTheme.cardBg),
                          errorWidget: (ctx, url, err) => Container(color: TxaTheme.cardBg),
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.4),
                                Colors.transparent,
                                TxaTheme.primaryBg,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Details details card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        if (originName.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            originName,
                            style: const TextStyle(fontSize: 14, color: TxaTheme.textSecondary),
                          ),
                        ],
                        const SizedBox(height: 12),

                        // Badges Row
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (year.isNotEmpty) _SimpleBadge(text: year),
                            if (quality.isNotEmpty) _SimpleBadge(text: quality),
                            if (time.isNotEmpty) _SimpleBadge(text: time),
                            if (_averageRating > 0)
                              _SimpleBadge(
                                text: '⭐ $_averageRating ($_totalRatings)',
                                color: Colors.amber,
                              )
                            else if (movie['imdb_score'] != null &&
                                double.tryParse(movie['imdb_score'].toString()) != null &&
                                double.parse(movie['imdb_score'].toString()) > 0)
                              _SimpleBadge(
                                text: 'IMDb ${movie['imdb_score']}',
                                color: Colors.amber,
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Action Buttons Row (Play, Favorite, Rate, Download, Share)
                        (() {
                          final history = _data?['history'];
                          final movie = _data?['movie'] ?? {};
                          final schedule = movie['broadcast_schedule'] as Map<String, dynamic>?;
                          String watchButtonLabel = TxaLanguage.t('watch_now');

                          // Helper: check if an episode is unreleased
                          bool epIsUnreleased(Map<String, dynamic> ep, List<dynamic> allEps) {
                            final idx = allEps.indexOf(ep);
                            return TxaSchedule.isEpisodeUnreleased(
                              ep['name']?.toString() ?? '',
                              idx < 0 ? 0 : idx,
                              allEps,
                              schedule,
                            );
                          }

                          // Check history episode validity (not unreleased)
                          bool historyValid = false;
                          String? historyEpId;
                          int historyServerIdx = 0;
                          double historyTime = 0;
                          String historyEpName = '';

                          if (history != null && history['episode_id'] != null) {
                            historyEpId = history['episode_id'].toString();
                            historyServerIdx = int.tryParse(history['server_index'].toString()) ?? 0;
                            historyTime = double.tryParse(history['current_time'].toString()) ?? 0.0;
                            if (servers.length > historyServerIdx) {
                              final serverEps = servers[historyServerIdx]['server_data'] as List? ?? [];
                              final foundEp = serverEps.firstWhere(
                                (e) => e['id']?.toString() == historyEpId || e['slug']?.toString() == historyEpId,
                                orElse: () => null,
                              );
                              if (foundEp != null && !epIsUnreleased(foundEp as Map<String, dynamic>, serverEps)) {
                                historyValid = true;
                                historyEpName = foundEp['name']?.toString() ?? 'Tập tiếp theo';
                              }
                            }
                          }

                          if (historyValid && historyEpName.isNotEmpty) {
                            watchButtonLabel = TxaLanguage.t('watch_resume', replace: {'ep': historyEpName});
                          }

                          return _HeroActionButton(
                            label: watchButtonLabel,
                            icon: Icons.play_arrow_rounded,
                            color: TxaTheme.accent,
                            onTap: () {
                              if (historyValid && historyEpId != null) {
                                setState(() {
                                  _selectedServerIndex = historyServerIdx;
                                });
                                _watchMovie(historyEpId, historyEpName, startTime: historyTime.toInt());
                              } else {
                                // Play first available (released) episode
                                if (servers.isNotEmpty) {
                                  final epList = servers[_selectedServerIndex]['server_data'] as List? ?? [];
                                  // Skip unreleased episodes to find first watchable
                                  final firstReleasedEp = epList.firstWhere(
                                    (ep) => !epIsUnreleased(ep as Map<String, dynamic>, epList),
                                    orElse: () => null,
                                  );
                                  if (firstReleasedEp != null) {
                                    _watchMovie(
                                      firstReleasedEp['id']?.toString() ?? firstReleasedEp['slug'] ?? 'full',
                                      firstReleasedEp['name'] ?? 'Full',
                                    );
                                    return;
                                  }
                                }
                                _watchMovie('full', 'Full');
                              }
                            },
                          );
                        })(),
                        const SizedBox(height: 16),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _IconBtn(
                              icon: _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              label: TxaLanguage.t('add_favorite'),
                              color: _isFavorite ? Colors.redAccent : Colors.white,
                              onTap: _toggleFavorite,
                            ),
                            _IconBtn(
                              icon: _userRating > 0 ? Icons.star_rounded : Icons.star_border_rounded,
                              label: _userRating > 0 ? '$_userRating/10' : TxaLanguage.t('rate_label'),
                              color: Colors.amberAccent,
                              onTap: _showRatingDialog,
                            ),
                            _IconBtn(
                              icon: Icons.download_rounded,
                              label: TxaLanguage.t('download'),
                              color: Colors.white,
                              onTap: () {
                                TxaToast.show(context, TxaLanguage.t('coming_soon'));
                              },
                            ),
                            _IconBtn(
                              icon: Icons.share_rounded,
                              label: TxaLanguage.t('share'),
                              color: Colors.white,
                              onTap: _shareMovie,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Category Tags
                        if (categories.isNotEmpty) ...[
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: categories.map((cat) => _CatText(text: cat['name'] ?? '')).toList(),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Seasons List Selector
                        if (movie['seasons'] != null && (movie['seasons'] as List).length > 1) ...[
                          Text(
                            TxaLanguage.t('select_season_hint'),
                            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 38,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: (movie['seasons'] as List).length,
                              itemBuilder: (context, idx) {
                                final part = movie['seasons'][idx];
                                final isSelected = part['slug'] == widget.slug;
                                return GestureDetector(
                                  onTap: () {
                                    if (!isSelected) {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(builder: (ctx) => MovieDetailScreen(slug: part['slug'])),
                                      );
                                    }
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected ? TxaTheme.accent : Colors.white.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected ? TxaTheme.accent : Colors.white10,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        part['season_name'] ?? part['name'] ?? '',
                                        style: TextStyle(
                                          color: isSelected ? Colors.white : TxaTheme.textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Movie Content Description
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              content.replaceAll(RegExp(r'<[^>]*>'), '').trim(),
                              maxLines: _descExpanded ? null : 3,
                              overflow: _descExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                              style: const TextStyle(color: TxaTheme.textSecondary, fontSize: 13.5, height: 1.6),
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () => setState(() => _descExpanded = !_descExpanded),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _descExpanded ? TxaLanguage.t('collapse') : TxaLanguage.t('show_more'),
                                    style: const TextStyle(color: TxaTheme.accent, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    _descExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                    color: TxaTheme.accent,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                // Tab persistent Header
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      controller: _tabController,
                      indicatorColor: TxaTheme.accent,
                      labelColor: TxaTheme.accent,
                      unselectedLabelColor: TxaTheme.textSecondary,
                      indicatorSize: TabBarIndicatorSize.label,
                      onTap: (index) {
                        setState(() {
                          _activeTabIndex = index;
                        });
                      },
                      tabs: [
                        Tab(text: TxaLanguage.t('episodes')),
                        Tab(text: TxaLanguage.t('comments')),
                        Tab(text: TxaLanguage.t('actors')),
                        Tab(text: TxaLanguage.t('recommendation')),
                      ],
                    ),
                  ),
                ),

                // Render Tab Sliver
                if (_activeTabIndex == 0)
                  _buildEpisodesSliver(servers)
                else if (_activeTabIndex == 1)
                  _buildCommentsSliver()
                else if (_activeTabIndex == 2)
                  _buildActorsSliver(movie['actors'] as List? ?? [])
                else
                  _buildRelatedSliver(related),
              ],
            ),
          ),

          // Custom Floating Back Button
          Positioned(
            left: 16,
            top: MediaQuery.of(context).padding.top + 8,
            child: SafeArea(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodesSliver(List servers) {
    if (servers.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(32),
          alignment: Alignment.center,
          child: Text(
            TxaLanguage.t('no_episodes'),
            style: const TextStyle(color: TxaTheme.textSecondary),
          ),
        ),
      );
    }

    final currentServer = servers[_selectedServerIndex];
    final isLocked = currentServer['is_locked'] == true;
    final rawEpisodes = currentServer['server_data'] as List? ?? [];
    final movie = _data?['movie'] ?? {};
    final schedule = movie['broadcast_schedule'] as Map<String, dynamic>?;
    
    // Hide unreleased episodes dynamically using TxaSchedule
    final List<dynamic> episodes = [];
    for (int i = 0; i < rawEpisodes.length; i++) {
      final ep = rawEpisodes[i];
      final epName = (ep['name'] ?? '').toString();
      final isUnreleased = TxaSchedule.isEpisodeUnreleased(epName, i, rawEpisodes, schedule);
      if (!isUnreleased) {
        episodes.add(ep);
      }
    }

    // Check if there is any unreleased episode in ANY server
    bool hasUnreleased = false;
    for (var srv in servers) {
      final eps = srv['server_data'] as List? ?? [];
      for (int i = 0; i < eps.length; i++) {
        final ep = eps[i];
        final epName = (ep['name'] ?? '').toString();
        if (TxaSchedule.isEpisodeUnreleased(epName, i, eps, schedule)) {
          hasUnreleased = true;
          break;
        }
      }
      if (hasUnreleased) break;
    }

    String broadcastNotice = '';
    if (schedule != null) {
      final nextDate = schedule['next_date']?.toString() ?? schedule['nextDate']?.toString() ?? '';
      final nextTime = schedule['next_time']?.toString() ?? schedule['nextTime']?.toString() ?? '';
      final nextEpisode = schedule['next_episode']?.toString() ?? schedule['nextEpisode']?.toString() ?? '';
      final movieType = movie['type']?.toString() ?? 'series';
      
      broadcastNotice = TxaSchedule.generateNotice(nextDate, nextTime, nextEpisode, movieType);
    }

    final totalEps = episodes.length;
    final epsPerPage = totalEps > 100 ? 100 : 25;
    final totalPages = (totalEps / epsPerPage).ceil();
    final safePage = _activeEpisodePage.clamp(0, totalPages > 0 ? totalPages - 1 : 0);
    final startIdx = totalEps > 0 ? (safePage * epsPerPage).clamp(0, totalEps - 1) : 0;
    final endIdx = totalEps > 0 ? ((safePage + 1) * epsPerPage).clamp(0, totalEps) : 0;
    final pagedEpisodes = totalEps > 0 ? episodes.sublist(startIdx, endIdx) : [];

    return SliverPadding(
      padding: const EdgeInsets.all(16.0),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          if (broadcastNotice.isNotEmpty && hasUnreleased) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.alarm_on_rounded, color: Colors.amber, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                TxaLanguage.t('unreleased_warning_title'),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                broadcastNotice,
                                style: const TextStyle(color: TxaTheme.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (schedule != null)
                    TxaBroadcastCountdown(
                      nextDate: schedule['next_date']?.toString() ?? schedule['nextDate']?.toString() ?? '',
                      nextTime: schedule['next_time']?.toString() ?? schedule['nextTime']?.toString() ?? '',
                    ),
                ],
              ),
            ),
          ],
          if (_isAdmin || servers.length > 1) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_isAdmin)
                  ElevatedButton.icon(
                    onPressed: _scanning ? null : _handleScan,
                    icon: _scanning
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: TxaTheme.accent),
                          )
                        : const Icon(Icons.sync_rounded, size: 16),
                    label: Text(
                      _scanning ? TxaLanguage.t('admin_scanning_btn') : TxaLanguage.t('admin_scan_btn'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TxaTheme.accent.withValues(alpha: 0.15),
                      foregroundColor: TxaTheme.accent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: TxaTheme.accent.withValues(alpha: 0.25)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                  )
                else
                  const SizedBox.shrink(),
                if (servers.length > 1)
                  DropdownButton<int>(
                    value: _selectedServerIndex,
                    dropdownColor: TxaTheme.cardBg,
                    underline: const SizedBox.shrink(),
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                    items: List.generate(
                      servers.length,
                      (idx) => DropdownMenuItem(
                        value: idx,
                        child: Text(
                          servers[idx]['server_name'] ?? 'Server ${idx + 1}',
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ),
                    onChanged: (idx) {
                      if (idx != null) {
                        setState(() {
                          _selectedServerIndex = idx;
                          _activeEpisodePage = 0;
                        });
                      }
                    },
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
            const SizedBox(height: 12),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                TxaLanguage.t('compact_mode'),
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              Switch.adaptive(
                value: _isCompact,
                activeThumbColor: TxaTheme.accent,
                activeTrackColor: TxaTheme.accent.withValues(alpha: 0.5),
                onChanged: (val) {
                  setState(() {
                    _isCompact = val;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (isLocked)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              decoration: BoxDecoration(
                color: TxaTheme.secondaryBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.lock_outline_rounded, color: Colors.amber, size: 40),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    TxaLanguage.t('vip_server_locked_title'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    TxaLanguage.t('vip_server_locked_desc'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: TxaTheme.textSecondary, fontSize: 12.5, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      // Navigate to Profile Tab to buy VIP
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => const TxaProfileScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    ),
                    child: Text(TxaLanguage.t('upgrade_vip_btn'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            )
          else if (episodes.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Text(TxaLanguage.t('no_episodes'), style: const TextStyle(color: TxaTheme.textSecondary)),
            )
          else ...[
            if (totalPages > 1) ...[
              SizedBox(
                height: 36,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: totalPages,
                  itemBuilder: (context, index) {
                    final currentStartIdx = index * epsPerPage;
                    final currentEndIdx = ((index + 1) * epsPerPage).clamp(1, totalEps) - 1;
                    final startName = _cleanEpisodeName(episodes[currentStartIdx]['name'].toString());
                    final endName = _cleanEpisodeName(episodes[currentEndIdx]['name'].toString());
                    final label = '$startName - $endName';
                    final isSelected = index == safePage;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                        selected: isSelected,
                        selectedColor: TxaTheme.accent,
                        backgroundColor: TxaTheme.secondaryBg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: isSelected ? TxaTheme.accent : Colors.white10),
                        ),
                        showCheckmark: false,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _activeEpisodePage = index;
                            });
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],

            Builder(builder: (context) {
              final screenWidth = MediaQuery.of(context).size.width;
              final compactCrossAxisCount = (screenWidth / 45).floor().clamp(8, 16);
              final thumbCrossAxisCount = (screenWidth / 130).floor().clamp(3, 8);

              if (_isCompact) {
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: compactCrossAxisCount,
                    childAspectRatio: 1.6,
                    crossAxisSpacing: 5,
                    mainAxisSpacing: 5,
                  ),
                  itemCount: pagedEpisodes.length,
                  itemBuilder: (context, index) {
                    final ep = pagedEpisodes[index];
                    final displayName = _cleanEpisodeName(ep['name'].toString());

                    return GestureDetector(
                      onTap: () => _watchMovie(ep['id']?.toString() ?? ep['slug'] ?? 'tap-1', ep['name'] ?? 'Tập 1'),
                      child: Container(
                        decoration: BoxDecoration(
                          color: TxaTheme.secondaryBg,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          displayName,
                          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 10),
                        ),
                      ),
                    );
                  },
                );
              } else {
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: thumbCrossAxisCount,
                    childAspectRatio: 1.35,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: pagedEpisodes.length,
                  itemBuilder: (context, index) {
                    final ep = pagedEpisodes[index];
                    final movie = _data?['movie'] ?? {};
                    final posterUrl = movie['poster_url'] ?? movie['thumb_url'] ?? '';
                    final epThumb = ep['thumb_url'] ?? ep['thumb'] ?? '';
                    final thumbUrl = (epThumb.toString().isNotEmpty) ? epThumb.toString() : posterUrl;

                    return GestureDetector(
                      onTap: () => _watchMovie(ep['id']?.toString() ?? ep['slug'] ?? 'tap-1', ep['name'] ?? 'Tập 1'),
                      child: Container(
                        decoration: BoxDecoration(
                          color: TxaTheme.secondaryBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: CachedNetworkImage(
                                  imageUrl: thumbUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (c, u) => Container(color: TxaTheme.cardBg),
                                  errorWidget: (c, u, e) => Container(color: TxaTheme.cardBg),
                                ),
                              ),
                              Positioned.fill(
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.black87, Colors.transparent],
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 6,
                                left: 6,
                                right: 6,
                                child: Text(
                                  ep['name'] ?? 'Tập $index',
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              }
            }),
            const SizedBox(height: 80),
          ],
        ]),
      ),
    );
  }

  Widget _buildCommentsSliver() {
    final auth = Provider.of<TxaAuthService>(context, listen: false);

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // Submit Comment Section
          if (!auth.isLoggedIn)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  Text(TxaLanguage.t('login_to_comment'), style: const TextStyle(color: TxaTheme.textSecondary, fontSize: 13)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => const TxaProfileScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TxaTheme.accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(TxaLanguage.t('login')),
                  ),
                ],
              ),
            )
          else ...[
            TxaTheme.liquidGlassPill(
              radius: 16,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: TxaTheme.accent, width: 1.5),
                        ),
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: TxaTheme.secondaryBg,
                          child: Text(
                            auth.user!['name'] != null && auth.user!['name'].toString().isNotEmpty
                                ? auth.user!['name'].toString()[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        auth.user!['name'] ?? auth.user!['username'] ?? 'User',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _commentController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: TxaLanguage.t('write_comment'),
                      hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                      fillColor: Colors.black26,
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _isSpoilerComment,
                              activeColor: TxaTheme.accent,
                              side: const BorderSide(color: Colors.white30, width: 1.5),
                              onChanged: (val) {
                                setState(() {
                                  _isSpoilerComment = val ?? false;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text('Tiết lộ nội dung (Spoiler)', style: TextStyle(color: TxaTheme.textSecondary, fontSize: 11)),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: _commentSubmitting ? null : _handlePostComment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TxaTheme.accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _commentSubmitting
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(TxaLanguage.t('post'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),

          // Comments List
          if (_commentsLoading)
            const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator(color: TxaTheme.accent)))
          else if (_comments.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Text(TxaLanguage.t('no_comments'), style: const TextStyle(color: TxaTheme.textSecondary)),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: _comments.length,
              itemBuilder: (context, index) {
                final comment = _comments[index];
                final author = comment['author'] ?? TxaLanguage.t('anonymous');
                final isVIP = (comment['package'] ?? 'Free').toString().toLowerCase() != 'free';
                final gender = (comment['gender'] ?? 'other').toString().toLowerCase();
                final likes = comment['likes'] ?? 0;
                final replies = comment['replies'] as List? ?? [];
                final date = comment['createdAt'] != null ? comment['createdAt'].toString().split('T')[0] : '';
                final isAuthor = auth.isLoggedIn && (auth.user!['name'] == author || auth.user!['username'] == author);

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Metadata
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isVIP ? Colors.amber : TxaTheme.accent.withValues(alpha: 0.3),
                                    width: 1.5,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: isVIP ? Colors.amber : TxaTheme.secondaryBg,
                                  child: Text(
                                    author.isNotEmpty ? author[0].toUpperCase() : 'U',
                                    style: TextStyle(color: isVIP ? Colors.black : Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(author, style: TextStyle(color: isVIP ? Colors.amber : Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 6),
                              
                              // Gender Icon
                              if (gender == 'male')
                                const Icon(Icons.male_rounded, color: Colors.blueAccent, size: 14)
                              else if (gender == 'female')
                                const Icon(Icons.female_rounded, color: Colors.pinkAccent, size: 14),

                              if (isVIP) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3), width: 0.5),
                                  ),
                                  child: const Text('VIP', style: TextStyle(color: Colors.amber, fontSize: 8, fontWeight: FontWeight.w900)),
                                ),
                              ],
                            ],
                          ),
                          Text(date, style: const TextStyle(color: TxaTheme.textMuted, fontSize: 10)),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Comment content
                      if (comment['isSpoiler'] == true)
                        _buildSpoilerText(comment['content'] ?? '')
                      else
                        Text(
                          comment['content'] ?? '',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),

                      const SizedBox(height: 12),
                      
                      // Action Row (Like, Reply, Delete)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => _handleLikeComment(comment['id']?.toString() ?? ''),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 13),
                                      const SizedBox(width: 4),
                                      Text('$likes', style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _replyingToCommentId = _replyingToCommentId == comment['id']?.toString() ? null : comment['id']?.toString();
                                    _replyController.clear();
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: TxaTheme.accent.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.chat_bubble_outline_rounded, color: TxaTheme.accent, size: 12),
                                      SizedBox(width: 4),
                                      Text('Trả lời', style: TextStyle(color: TxaTheme.accent, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (isAuthor)
                            GestureDetector(
                              onTap: () => _handleDeleteComment(comment['id']?.toString() ?? ''),
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withValues(alpha: 0.05),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 15),
                              ),
                            ),
                        ],
                      ),

                      // Nested Replies
                      if (replies.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.only(left: 12.0),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(left: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1.5)),
                            ),
                            padding: const EdgeInsets.only(left: 12),
                            child: Column(
                              children: replies.map((rep) {
                                final repAuthor = rep['author'] ?? TxaLanguage.t('anonymous');
                                final repDate = rep['createdAt'] != null ? rep['createdAt'].toString().split('T')[0] : '';
                                final repVIP = (rep['package'] ?? 'Free').toString().toLowerCase() != 'free';

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                repAuthor,
                                                style: TextStyle(
                                                  color: repVIP ? Colors.amber : Colors.white70,
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              if (repVIP) ...[
                                                const SizedBox(width: 4),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: Colors.amber.withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(3),
                                                  ),
                                                  child: const Text('VIP', style: TextStyle(color: Colors.amber, fontSize: 7, fontWeight: FontWeight.bold)),
                                                ),
                                              ],
                                            ],
                                          ),
                                          Text(repDate, style: const TextStyle(color: TxaTheme.textMuted, fontSize: 9)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        rep['content'] ?? '',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.75),
                                          fontSize: 12,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],

                      // Reply Form input field
                      if (_replyingToCommentId == comment['id']?.toString()) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _replyController,
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                decoration: InputDecoration(
                                  hintText: 'Nhập câu trả lời...',
                                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                                  fillColor: Colors.black26,
                                  filled: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => _handlePostReply(comment['id']?.toString() ?? ''),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: TxaTheme.accent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Gửi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 80),
        ]),
      ),
    );
  }

  Widget _buildSpoilerText(String content) {
    bool revealed = false;
    return StatefulBuilder(
      builder: (context, setSpoilerState) {
        if (revealed) {
          return Text(content, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4));
        }

        return GestureDetector(
          onTap: () {
            setSpoilerState(() {
              revealed = true;
            });
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 14),
                SizedBox(width: 6),
                Text('Nội dung tiết lộ cốt truyện! Bấm để xem.', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActorsSliver(List actors) {
    if (actors.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(32),
          alignment: Alignment.center,
          child: Text(
            TxaLanguage.t('no_actors'),
            style: const TextStyle(color: TxaTheme.textSecondary),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16.0),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 0.72,
              crossAxisSpacing: 10,
              mainAxisSpacing: 16,
            ),
            itemCount: actors.length,
            itemBuilder: (context, index) {
              final actor = actors[index];
              String actorName = '';
              String actorThumb = '';

              if (actor is Map) {
                actorName = actor['name']?.toString() ?? '';
                actorThumb = actor['image']?.toString() ?? actor['thumb_url']?.toString() ?? '';
              } else if (actor is String) {
                actorName = actor.trim();
              }

              final int nameHash = actorName.hashCode;
              final List<Color> gradients = [
                [Colors.blue, Colors.teal],
                [Colors.purple, Colors.pink],
                [Colors.orange, Colors.red],
                [Colors.indigo, Colors.blueAccent],
                [Colors.teal, Colors.green],
              ][nameHash.abs() % 5];

              final initials = actorName.isNotEmpty ? actorName[0].toUpperCase() : '?';

              return Column(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 6,
                            offset: Offset(0, 3),
                          )
                        ],
                        border: Border.all(color: TxaTheme.accent.withValues(alpha: 0.3), width: 1.5),
                      ),
                      child: ClipOval(
                        child: actorThumb.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: actorThumb,
                                fit: BoxFit.cover,
                                placeholder: (ctx, url) => Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: gradients, begin: Alignment.topLeft, end: Alignment.bottomRight),
                                  ),
                                  child: Center(child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                                ),
                                errorWidget: (ctx, url, err) => Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: gradients, begin: Alignment.topLeft, end: Alignment.bottomRight),
                                  ),
                                  child: Center(child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                                ),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: gradients, begin: Alignment.topLeft, end: Alignment.bottomRight),
                                ),
                                child: Center(
                                  child: Text(
                                    initials,
                                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    actorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 80),
        ]),
      ),
    );
  }

  Widget _buildRelatedSliver(List related) {
    if (related.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(32),
          alignment: Alignment.center,
          child: Text(
            TxaLanguage.t('no_movies'),
            style: const TextStyle(color: TxaTheme.textSecondary),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.64,
              crossAxisSpacing: 10,
              mainAxisSpacing: 12,
            ),
            itemCount: related.length,
            itemBuilder: (context, index) {
              final m = related[index];
              final name = m['name'] ?? '';
              final posterUrl = m['poster_url'] ?? m['thumb_url'] ?? '';

              return GestureDetector(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => MovieDetailScreen(slug: m['slug'] ?? ''),
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TxaTheme.liquidGlassPill(
                        radius: 12,
                        child: CachedNetworkImage(
                          imageUrl: posterUrl,
                          fit: BoxFit.cover,
                          placeholder: (ctx, url) => Container(color: TxaTheme.secondaryBg),
                          errorWidget: (ctx, url, err) => Container(color: TxaTheme.secondaryBg),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 80),
        ]),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: TxaTheme.primaryBg,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

class _SimpleBadge extends StatelessWidget {
  final String text;
  final Color? color;
  const _SimpleBadge({required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color ?? Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color != null ? Colors.white : TxaTheme.textSecondary,
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _CatText extends StatelessWidget {
  final String text;
  const _CatText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: TxaTheme.secondaryBg,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.label,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color ?? Colors.white, size: 24),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: TxaTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _HeroActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: color == Colors.white ? Colors.black : Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
    );
  }
}

class TxaBroadcastCountdown extends StatefulWidget {
  final String nextDate;
  final String nextTime;

  const TxaBroadcastCountdown({
    super.key,
    required this.nextDate,
    required this.nextTime,
  });

  @override
  State<TxaBroadcastCountdown> createState() => _TxaBroadcastCountdownState();
}

class _TxaBroadcastCountdownState extends State<TxaBroadcastCountdown> {
  Timer? _timer;
  String _countdownText = '';

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _updateCountdown();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _updateCountdown();
      }
    });
  }

  void _updateCountdown() {
    String targetStr = '${widget.nextDate}T00:00:00+07:00';
    if (widget.nextTime.isNotEmpty) {
      final parts = widget.nextTime.split(':');
      if (parts.length == 2) {
        targetStr = '${widget.nextDate}T${widget.nextTime}:00+07:00';
      } else {
        targetStr = '${widget.nextDate}T${widget.nextTime}+07:00';
      }
    }

    try {
      final targetDate = DateTime.parse(targetStr);
      final now = DateTime.now();
      final diff = targetDate.difference(now);

      if (diff.isNegative) {
        setState(() {
          _countdownText = TxaLanguage.t('countdown_unreleased');
        });
        _timer?.cancel();
        return;
      }

      final days = diff.inDays;
      final hours = diff.inHours % 24;
      final minutes = diff.inMinutes % 60;
      final seconds = diff.inSeconds % 60;

      String text = '';
      if (days > 0) {
        text += '$days${TxaLanguage.t('countdown_days')} ';
      }
      text += '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

      setState(() {
        _countdownText = text;
      });
    } catch (_) {
      setState(() {
        _countdownText = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_countdownText.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            TxaLanguage.t('broadcast_countdown_label'),
            style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            _countdownText,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}
