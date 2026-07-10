import 'package:flutter/material.dart';
import '../../services/txa_api.dart';
import '../../utils/txa_toast.dart';
import '../../widgets/txa_video_player.dart';
import '../../services/txa_language.dart';

class TvPlayerScreen extends StatefulWidget {
  final String movieSlug;
  final String episodeId;
  final String episodeName;
  final String movieName;

  const TvPlayerScreen({
    super.key,
    required this.movieSlug,
    required this.episodeId,
    required this.episodeName,
    required this.movieName,
  });

  @override
  State<TvPlayerScreen> createState() => _TvPlayerScreenState();
}

class _TvPlayerScreenState extends State<TvPlayerScreen> {
  bool _isLoading = true;
  String? _videoUrl;
  String _serverName = 'Nguồn VIP #1';
  Map<String, dynamic>? _adSettings; // API returns 'ads' key
  List<dynamic>? _subtitles;
  int _timeIntroStart = 0;
  int _timeIntroEnd = 0;
  int _timeOutroStart = 0;
  int _timeOutroEnd = 0;
  Map<String, dynamic>? _nextEpisode;
  Map<String, dynamic>? _prevEpisode;
  List<dynamic>? _servers;
  int _selectedServerIndex = 0;
  String _movieId = '';
  int _startTime = 0;

  @override
  void initState() {
    super.initState();
    _loadStreamUrl();
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

  Future<void> _loadStreamUrl() async {
    try {
      final res = await TxaApi().getMovie(widget.movieSlug);
      if (res != null) {
        _adSettings = res['ads'] as Map<String, dynamic>?;
        
        final servers = res['servers'] as List<dynamic>? ?? [];
        String? resolvedUrl;
        String resolvedServer = 'Nguồn VIP #1';
        Map<String, dynamic>? activeEp;
        int activeServerIdx = 0;
        int activeEpIdx = -1;
        List<dynamic> activeServerEps = [];

        for (int s = 0; s < servers.length; s++) {
          final server = servers[s];
          final serverData = server['server_data'] as List<dynamic>? ?? [];
          for (int e = 0; e < serverData.length; e++) {
            final ep = serverData[e];
            if (ep['id']?.toString() == widget.episodeId || ep['slug']?.toString() == widget.episodeId) {
              resolvedUrl = _resolveStreamUrl(ep);
              resolvedServer = server['server_name'] ?? 'Nguồn VIP #1';
              activeEp = ep;
              activeServerIdx = s;
              activeEpIdx = e;
              activeServerEps = serverData;
              break;
            }
          }
          if (resolvedUrl != null && resolvedUrl.isNotEmpty) break;
        }

        if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
          Map<String, dynamic>? nextEpMap;
          if (activeEpIdx != -1 && activeEpIdx + 1 < activeServerEps.length) {
            final nextEp = activeServerEps[activeEpIdx + 1];
            nextEpMap = {
              'id': nextEp['id']?.toString() ?? nextEp['slug']?.toString(),
              'name': nextEp['name'] ?? 'Tập tiếp theo',
              'movieName': widget.movieName,
              'thumb': res['movie']?['thumb_url'] ?? res['movie']?['poster_url'] ?? '',
            };
          }

          Map<String, dynamic>? prevEpMap;
          if (activeEpIdx > 0 && activeEpIdx < activeServerEps.length) {
            final prevEp = activeServerEps[activeEpIdx - 1];
            prevEpMap = {
              'id': prevEp['id']?.toString() ?? prevEp['slug']?.toString(),
              'name': prevEp['name'] ?? 'Tập trước',
              'movieName': widget.movieName,
              'thumb': res['movie']?['thumb_url'] ?? res['movie']?['poster_url'] ?? '',
            };
          }

          final history = res['history'];
          final movieId = res['movie']?['id']?.toString() ?? '';
          int startTime = 0;
          if (history != null && history['episode_id']?.toString() == widget.episodeId) {
            startTime = (double.tryParse(history['current_time']?.toString() ?? '0') ?? 0.0).toInt();
          }

          if (mounted) {
            setState(() {
              _videoUrl = resolvedUrl;
              _serverName = resolvedServer;
              _subtitles = activeEp?['subtitles'] ?? activeEp?['subtitles_data'];
              _timeIntroStart = int.tryParse(activeEp?['timeIntroStart']?.toString() ?? '') ?? int.tryParse(activeEp?['time_intro_start']?.toString() ?? '') ?? 0;
              _timeIntroEnd = int.tryParse(activeEp?['timeIntroEnd']?.toString() ?? '') ?? int.tryParse(activeEp?['time_intro_end']?.toString() ?? '') ?? 0;
              _timeOutroStart = int.tryParse(activeEp?['timeOutroStart']?.toString() ?? '') ?? int.tryParse(activeEp?['time_outro_start']?.toString() ?? '') ?? 0;
              _timeOutroEnd = int.tryParse(activeEp?['timeOutroEnd']?.toString() ?? '') ?? int.tryParse(activeEp?['time_outro_end']?.toString() ?? '') ?? 0;
              _nextEpisode = nextEpMap;
              _prevEpisode = prevEpMap;
              _servers = servers;
              _selectedServerIndex = activeServerIdx;
              _movieId = movieId;
              _startTime = startTime;
              _isLoading = false;
            });
          }
          return;
        }
      }

      if (mounted) {
        TxaToast.show(context, TxaLanguage.t('tv_no_stream_found'), isError: true);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        TxaToast.show(context, TxaLanguage.t('tv_conn_error'), isError: true);
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _videoUrl == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFF737DFD)),
              const SizedBox(height: 16),
              Text(
                TxaLanguage.t('tv_player_loading'),
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
              )
            ],
          ),
        ),
      );
    }

    return TxaVideoPlayer(
      url: _videoUrl!,
      movieName: widget.movieName,
      episodeName: widget.episodeName,
      serverName: _serverName,
      adSettings: _adSettings,
      subtitles: _subtitles,
      timeIntroStart: _timeIntroStart,
      timeIntroEnd: _timeIntroEnd,
      timeOutroStart: _timeOutroStart,
      timeOutroEnd: _timeOutroEnd,
      nextEpisode: _nextEpisode,
      onPlayNext: _nextEpisode != null ? () {
        Navigator.pop(context); // Close current player
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TvPlayerScreen(
              movieSlug: widget.movieSlug,
              episodeId: _nextEpisode!['id'].toString(),
              episodeName: _nextEpisode!['name'].toString(),
              movieName: widget.movieName,
            ),
          ),
        );
      } : null,
      prevEpisode: _prevEpisode,
      onPlayPrev: _prevEpisode != null ? () {
        Navigator.pop(context); // Close current player
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TvPlayerScreen(
              movieSlug: widget.movieSlug,
              episodeId: _prevEpisode!['id'].toString(),
              episodeName: _prevEpisode!['name'].toString(),
              movieName: widget.movieName,
            ),
          ),
        );
      } : null,
      servers: _servers,
      initialServerIndex: _selectedServerIndex,
      currentEpisodeId: widget.episodeId,
      onEpisodeChanged: (epId, epName, srvIdx) {
        setState(() {
          _selectedServerIndex = srvIdx;
        });
      },
      onEnded: () {
        Navigator.pop(context);
      },
      movieId: _movieId,
      startTime: _startTime,
    );
  }
}
