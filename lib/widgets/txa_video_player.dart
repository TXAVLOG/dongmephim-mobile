import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import '../services/txa_language.dart';
import '../services/txa_auth_service.dart';
import '../services/txa_api.dart';
import '../utils/txa_platform.dart';
import '../utils/txa_toast.dart';
import '../utils/txa_logger.dart';
import '../utils/txa_format.dart';
import 'txa_player_coachmark.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';

class TxaVideoPlayer extends StatefulWidget {
  final String url;
  final String movieName;
  final String episodeName;
  final String serverName;
  final Map<String, dynamic>? adSettings;
  final VoidCallback? onEnded;
  final List<dynamic>? subtitles;
  final int timeIntroStart;
  final int timeIntroEnd;
  final int timeOutroStart;
  final int timeOutroEnd;
  final Map<String, dynamic>? nextEpisode;
  final VoidCallback? onPlayNext;
  final Map<String, dynamic>? prevEpisode;
  final VoidCallback? onPlayPrev;
  final List<dynamic>? servers;
  final int initialServerIndex;
  final String? currentEpisodeId;
  final Function(String episodeId, String episodeName, int serverIndex)? onEpisodeChanged;
  final int movieId;
  final int startTime;

  const TxaVideoPlayer({
    super.key,
    required this.url,
    required this.movieName,
    required this.episodeName,
    required this.serverName,
    this.adSettings,
    this.onEnded,
    this.subtitles,
    this.timeIntroStart = 0,
    this.timeIntroEnd = 0,
    this.timeOutroStart = 0,
    this.timeOutroEnd = 0,
    this.nextEpisode,
    this.onPlayNext,
    this.prevEpisode,
    this.onPlayPrev,
    this.servers,
    this.initialServerIndex = 0,
    this.currentEpisodeId,
    this.onEpisodeChanged,
    this.movieId = 0,
    this.startTime = 0,
  });

  @override
  State<TxaVideoPlayer> createState() => _TxaVideoPlayerState();
}

class _TxaVideoPlayerState extends State<TxaVideoPlayer> {
  // Main Player
  VideoPlayerController? _controller;
  bool _isPlayerInitialized = false;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _showControls = true;
  Timer? _hideControlsTimer;
  DateTime? _lastSavedTime;

  // Subtitles States
  String _subtitleMode = 'off'; // 'off' | 'primary' | 'bilingual'
  int _primarySubIdx = 0;
  int _secondarySubIdx = 0;
  List<TxaSubtitleCue> _primaryCues = [];
  List<TxaSubtitleCue> _secondaryCues = [];
  TxaSubtitleCue? _activePrimaryCue;
  TxaSubtitleCue? _activeSecondaryCue;

  // TV Subtitles Menu States
  bool _showTvSubtitlesMenu = false;
  int _tvMenuSelectedIndex = 0;

  // Next Episode Overlay States
  bool _showNextEpisodeOverlay = false;
  int _nextEpisodeCountdown = 5;
  Timer? _nextEpisodeTimer;

  // Pre-roll Ads
  bool _showAd = false;
  VideoPlayerController? _adController;
  Timer? _adTimer;
  int _adTimeLeft = 5;
  bool _canSkipAd = false;
  String _adType = 'video'; // 'video' | 'image'
  String? _adUrl;
  bool _adError = false;
  WebViewController? _webViewController;

  // Mobile Gestures & States
  bool _isLocked = false;
  double _volume = 1.0;
  double _brightness = 0.5;
  bool _showVolumeIndicator = false;
  bool _showBrightnessIndicator = false;
  Timer? _indicatorTimer;
  double _playbackSpeed = 1.0;
  bool _showLockButtonOnly = false;
  Timer? _lockButtonTimer;
  int _currentServerIndex = 0;
  String _currentEpisodeId = '';
  String _currentEpisodeName = '';
  String _currentUrl = '';
  String _currentServerName = '';
  bool _showPlaylistPanel = false;
  
  // TV Playlist Selection States
  int _playlistServerSelectedIndex = 0;
  int _playlistEpisodeSelectedIndex = 0;

  // Top Clock
  String _clockString = '';
  Timer? _clockTimer;

  // Battery (Mobile Only)
  int _batteryLevel = -1;
  bool _isCharging = false;
  Timer? _batteryTimer;

  // Secure Mode (DRM)
  bool _secureEnabled = false;

  // TV D-Pad Focus Nodes
  final FocusNode _tvFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    
    _currentServerIndex = widget.initialServerIndex;
    _currentEpisodeId = widget.currentEpisodeId ?? '';
    _currentEpisodeName = widget.episodeName;
    _currentUrl = widget.url;
    _currentServerName = widget.serverName;
    _playlistServerSelectedIndex = _currentServerIndex;
    
    // Lock screen orientation to landscape for video player
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Initialize subtitles if present
    if (widget.subtitles != null && widget.subtitles!.isNotEmpty) {
      _primarySubIdx = 0;
      _loadSubtitleTrack(0, true);
      if (widget.subtitles!.length > 1) {
        _secondarySubIdx = 1;
        _loadSubtitleTrack(1, false);
        _subtitleMode = 'bilingual';
      } else {
        _subtitleMode = 'primary';
      }
    } else {
      _subtitleMode = 'off';
    }

    if (TxaPlatform.isTV) {
      _tvFocusNode.addListener(_onTvFocusChange);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _tvFocusNode.requestFocus();
        }
      });
    }

    _startClockTimer();
    _checkAndInitAdFlow();

    // Battery monitoring & system brightness/volume (mobile only)
    if (TxaPlatform.isMobile) {
      _startBatteryTimer();
      _initMobileSystemControls();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            TxaPlayerCoachmark.show(context);
          }
        });
      });
    }

    // Enable DRM secure mode
    _enableSecureMode();
  }

  @override
  void dispose() {
    // Reset screen orientation on exit
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);

    if (TxaPlatform.isTV) {
      _tvFocusNode.removeListener(_onTvFocusChange);
    }

    _controller?.dispose();
    _adController?.dispose();
    _adTimer?.cancel();
    _hideControlsTimer?.cancel();
    _clockTimer?.cancel();
    _batteryTimer?.cancel();
    _indicatorTimer?.cancel();
    _nextEpisodeTimer?.cancel();
    _lockButtonTimer?.cancel();
    _tvFocusNode.dispose();

    // Reset brightness on mobile
    if (TxaPlatform.isMobile) {
      try {
        ScreenBrightness().resetScreenBrightness();
      } catch (_) {}
    }

    // Disable DRM secure mode on exit
    _disableSecureMode();

    super.dispose();
  }

  // --- Clock Timer ---
  void _startClockTimer() {
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) _updateClock();
    });
  }

  void _updateClock() {
    final now = DateTime.now();
    setState(() {
      _clockString = TxaFormat.formatDate(now, pattern: 'HH:mm:ss  dd/MM/yyyy');
    });
  }

  // --- Battery Timer (Mobile Only) ---
  static const MethodChannel _platformChannel = MethodChannel('online.dongmephim/platform');

  void _startBatteryTimer() {
    _updateBattery();
    _batteryTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) _updateBattery();
    });
  }

  void _updateBattery() async {
    try {
      final result = await _platformChannel.invokeMethod('getBatteryInfo');
      if (mounted && result is Map) {
        setState(() {
          _batteryLevel = (result['level'] as int?) ?? -1;
          _isCharging = (result['isCharging'] as bool?) ?? false;
        });
      }
    } catch (e) {
      TxaLogger.log('Failed to get battery info: $e', type: 'app');
    }
  }

  // --- DRM Secure Mode ---
  void _enableSecureMode() async {
    try {
      await _platformChannel.invokeMethod('enableSecureMode');
      _secureEnabled = true;
    } catch (e) {
      TxaLogger.log('Failed to enable secure mode: $e', type: 'app');
    }
  }

  void _disableSecureMode() async {
    if (!_secureEnabled) return;
    try {
      await _platformChannel.invokeMethod('disableSecureMode');
      _secureEnabled = false;
    } catch (e) {
      TxaLogger.log('Failed to disable secure mode: $e', type: 'app');
    }
  }

  void _onTvFocusChange() {
    if (TxaPlatform.isTV && !_tvFocusNode.hasFocus && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_tvFocusNode.hasFocus) {
          _tvFocusNode.requestFocus();
        }
      });
    }
  }

  // --- Ads Flow (synced with web TXAPlayer) ---
  // NOTE: VIP bypass is already handled server-side in the API response.
  // If user is VIP, the API returns ads.pre_roll_enable = false.
  // We do NOT check VIP client-side — just trust the API response.
  String? _getYouTubeEmbedUrl(String url) {
    if (!url.contains('youtube.com') && !url.contains('youtu.be')) {
      return null;
    }
    try {
      final uri = Uri.parse(url.trim());
      String? videoId;
      if (url.contains('youtu.be')) {
        videoId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      } else if (url.contains('youtube.com')) {
        videoId = uri.queryParameters['v'];
        if (videoId == null && uri.pathSegments.contains('embed')) {
          videoId = uri.pathSegments.last;
        } else if (videoId == null && uri.pathSegments.contains('shorts')) {
          videoId = uri.pathSegments.last;
        }
      }
      if (videoId != null && videoId.isNotEmpty) {
        return 'https://www.youtube-nocookie.com/embed/$videoId?autoplay=1&mute=0&controls=1&enablejsapi=1&origin=https://www.youtube.com';
      }
    } catch (_) {}
    return null;
  }

  void _initAdWebView(String embedUrl) {
    if (!TxaPlatform.isMobile) {
      _startAdCountdown();
      return;
    }
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
            if (mounted) {
              _adTimer?.cancel();
              setState(() {
                _adError = true;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(embedUrl), headers: const {'Referer': 'https://www.youtube.com'});
  }

  Future<void> _checkAndInitAdFlow() async {
    final adSettings = widget.adSettings;
    bool adEnabled = adSettings?['pre_roll_enable'] == true;
    final String? rawAdUrl = adSettings?['pre_roll_url'];

    // Check dynamic bypass_ads permission from user package
    final auth = TxaAuthService();
    final user = auth.user;
    if (auth.isLoggedIn && user != null) {
      final userPkgId = (user['package'] ?? 'free').toString().toLowerCase();
      if (userPkgId != 'free') {
        try {
          final pkgsRes = await TxaApi().getPackages();
          if (pkgsRes != null && pkgsRes['packages'] != null) {
            final packages = pkgsRes['packages'] as List<dynamic>;
            final userPkg = packages.firstWhere(
              (p) => (p['id'] ?? '').toString().toLowerCase() == userPkgId ||
                     (p['title'] ?? '').toString().toLowerCase() == userPkgId,
              orElse: () => null,
            );
            if (userPkg != null && userPkg['permissions'] != null) {
              final bypass = userPkg['permissions']['bypass_ads'] == true;
              if (bypass) {
                adEnabled = false;
              }
            }
          }
        } catch (e) {
          debugPrint('Error checking bypass_ads permission: $e');
        }
      }
    }

    if (adEnabled && rawAdUrl != null && rawAdUrl.isNotEmpty) {
      // Support multiple ad URLs separated by newlines (pick random, like web)
      final urls = rawAdUrl
          .split(RegExp(r'\n+'))
          .map((u) => u.trim())
          .where((u) => u.isNotEmpty)
          .toList();

      if (urls.isEmpty) {
        _initMainPlayer();
        return;
      }

      String randomUrl = urls[urls.length == 1 ? 0 : (DateTime.now().millisecondsSinceEpoch % urls.length)];
      String adType = adSettings?['pre_roll_type']?.toString() ?? 'video';

      // Auto-detect YouTube URL
      final youtubeEmbedUrl = _getYouTubeEmbedUrl(randomUrl);
      if (youtubeEmbedUrl != null) {
        adType = 'embed';
        _adUrl = youtubeEmbedUrl;
      } else {
        // Auto-detect direct video files (mp4, webm, ogg)
        if (RegExp(r'\.(mp4|webm|ogg)(\?.*)?$', caseSensitive: false).hasMatch(randomUrl)) {
          adType = 'video';
        }
        _adUrl = randomUrl;
      }

      _adType = adType;
      _adTimeLeft = int.tryParse(adSettings?['pre_roll_skip_seconds']?.toString() ?? '5') ?? 5;

      setState(() {
        _showAd = true;
      });

      if (_adType == 'video') {
        _initAdPlayer();
      } else if (_adType == 'embed') {
        if (youtubeEmbedUrl != null && TxaPlatform.isMobile) {
          _initAdWebView(youtubeEmbedUrl);
        }
        _startAdCountdown();
      } else {
        _startAdCountdown();
      }
    } else {
      // No ads configured or VIP user (API returned disabled)
      _initMainPlayer();
    }
  }

  void _initAdPlayer() async {
    if (_adUrl == null) return;
    _adController = VideoPlayerController.networkUrl(Uri.parse(_adUrl!));
    try {
      await _adController!.initialize();
      if (!mounted) return;
      setState(() {});
      _adController!.play();
      _startAdCountdown();

      _adController!.addListener(() {
        if (!mounted || _adController == null) return;
        
        // Handle ad errors during playback
        if (_adController!.value.hasError) {
          _adTimer?.cancel();
          setState(() {
            _adError = true;
          });
          return;
        }

        // Track ad progress like web's onTimeUpdate
        final adDuration = _adController!.value.duration;
        if (adDuration.inMilliseconds > 0) {
          // progress available if needed for a future progress bar
          setState(() {});
        }
        // Auto-skip when ad video finishes
        if (_adController!.value.position >= _adController!.value.duration &&
            _adController!.value.duration > Duration.zero) {
          _skipAd();
        }
      });
    } catch (e) {
      debugPrint('Ad player initialization error: $e');
      _adTimer?.cancel();
      setState(() {
        _adError = true;
      });
    }
  }

  void _startAdCountdown() {
    _adTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_adTimeLeft > 0) {
          _adTimeLeft--;
        } else {
          _canSkipAd = true;
          timer.cancel();
        }
      });
    });
  }

  void _skipAd() {
    _adTimer?.cancel();
    _adController?.pause();
    _adController?.dispose();
    _adController = null;
    _webViewController = null;

    setState(() {
      _showAd = false;
      _adError = false;
    });

    _initMainPlayer();
    if (TxaPlatform.isTV) {
      _tvFocusNode.requestFocus();
    }
  }

  // --- Main Player Flow ---
  void _initMainPlayer({Duration? startFrom}) async {
    _controller = VideoPlayerController.networkUrl(Uri.parse(_currentUrl));
    
    try {
      await _controller!.initialize();
      if (!mounted) return;
      
      setState(() {
        _duration = _controller!.value.duration;
        _isPlayerInitialized = true;
      });

      Duration? targetStart = startFrom;
      if (targetStart == null && _currentEpisodeId == widget.currentEpisodeId && widget.startTime > 0) {
        targetStart = Duration(seconds: widget.startTime);
      }

      if (targetStart != null) {
        await _controller!.seekTo(targetStart);
      }

      _controller!.play();
      setState(() {
        _isPlaying = true;
      });

      _controller!.addListener(() {
        if (!mounted || _controller == null) return;
        if (_controller!.value.hasError) {
          final errorDescription = _controller!.value.errorDescription;
          TxaLogger.log('Main player playback error: $errorDescription', type: 'crash');
          return;
        }
        
        final pos = _controller!.value.position;
        _updateActiveCues(pos);

        setState(() {
          _position = pos;
          if (_controller!.value.position >= _controller!.value.duration &&
              _controller!.value.duration > Duration.zero &&
              _isPlaying) {
            _isPlaying = false;
            _handleVideoEnded();
          }
        });

        // Save progress dynamically every 5 seconds
        final now = DateTime.now();
        if (_lastSavedTime == null || now.difference(_lastSavedTime!).inSeconds >= 5) {
          _lastSavedTime = now;
          _saveWatchProgress();
        }
      });

      _resetHideControlsTimer();
      if (TxaPlatform.isTV) {
        _tvFocusNode.requestFocus();
      }
    } catch (e) {
      TxaLogger.log('Main player initialize error: $e. URL: ${widget.url}', type: 'crash');
      if (mounted) {
        TxaToast.show(context, TxaLanguage.t('player_error_stream'), isError: true);
      }
    }
  }

  void _saveWatchProgress() async {
    final auth = TxaAuthService();
    if (!auth.isLoggedIn || widget.movieId == 0) return;

    final pos = _position.inSeconds.toDouble();
    final dur = _duration.inSeconds.toDouble();
    if (pos > 0 && dur > 0) {
      await TxaApi().updateWatchHistory(
        widget.movieId,
        _currentEpisodeId,
        pos,
        dur,
        _currentServerIndex,
      );
    }
  }

  // --- SUBTITLE PARSING & PROCESSING ---
  List<TxaSubtitleCue> parseSubtitles(String text) {
    final List<TxaSubtitleCue> cues = [];
    final lines = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    final timeRegex = RegExp(
      r'(\d{2}):(\d{2}):(\d{2})[,.](\d{3})\s*-->\s*(\d{2}):(\d{2}):(\d{2})[,.](\d{3})'
    );
    final timeRegexShort = RegExp(
      r'(\d{2}):(\d{2})[,.](\d{3})\s*-->\s*(\d{2}):(\d{2})[,.](\d{3})'
    );

    String currentId = '';
    double? startTime;
    double? endTime;
    List<String> textBuffer = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        if (startTime != null && endTime != null && textBuffer.isNotEmpty) {
          cues.add(TxaSubtitleCue(
            id: currentId.isNotEmpty ? currentId : (cues.length + 1).toString(),
            startTime: startTime,
            endTime: endTime,
            text: textBuffer.join('\n').replaceAll(RegExp(r'\{[^\}]*\}|<[^>]*>'), '').trim(),
          ));
          startTime = null;
          endTime = null;
          textBuffer.clear();
          currentId = '';
        }
        continue;
      }

      final match = timeRegex.firstMatch(line);
      if (match != null) {
        startTime = double.parse(match.group(1)!) * 3600 +
            double.parse(match.group(2)!) * 60 +
            double.parse(match.group(3)!) +
            double.parse(match.group(4)!) / 1000.0;
        endTime = double.parse(match.group(5)!) * 3600 +
            double.parse(match.group(6)!) * 60 +
            double.parse(match.group(7)!) +
            double.parse(match.group(8)!) / 1000.0;
        continue;
      }

      final matchShort = timeRegexShort.firstMatch(line);
      if (matchShort != null) {
        startTime = double.parse(matchShort.group(1)!) * 60 +
            double.parse(matchShort.group(2)!) +
            double.parse(matchShort.group(3)!) / 1000.0;
        endTime = double.parse(matchShort.group(4)!) * 60 +
            double.parse(matchShort.group(5)!) +
            double.parse(matchShort.group(6)!) / 1000.0;
        continue;
      }

      if (startTime == null) {
        currentId = line;
      } else {
        textBuffer.add(line);
      }
    }

    if (startTime != null && endTime != null && textBuffer.isNotEmpty) {
      cues.add(TxaSubtitleCue(
        id: currentId.isNotEmpty ? currentId : (cues.length + 1).toString(),
        startTime: startTime,
        endTime: endTime,
        text: textBuffer.join('\n').replaceAll(RegExp(r'\{[^\}]*\}|<[^>]*>'), '').trim(),
      ));
    }

    return cues;
  }

  Future<void> _loadSubtitleTrack(int index, bool isPrimary) async {
    if (widget.subtitles == null || index < 0 || index >= widget.subtitles!.length) return;
    final sub = widget.subtitles![index];
    final fileUrl = sub['file']?.toString() ?? sub['url']?.toString();
    if (fileUrl == null || fileUrl.isEmpty) return;

    try {
      final response = await http.get(Uri.parse(fileUrl));
      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes, allowMalformed: true);
        final parsed = parseSubtitles(decodedBody);
        if (mounted) {
          setState(() {
            if (isPrimary) {
              _primaryCues = parsed;
            } else {
              _secondaryCues = parsed;
            }
          });
        }
      }
    } catch (e) {
      TxaLogger.log("Lỗi tải phụ đề index $index: $e", type: 'crash');
    }
  }

  void _updateActiveCues(Duration position) {
    final sec = position.inMilliseconds / 1000.0;
    
    TxaSubtitleCue? activePrimary;
    if (_subtitleMode != 'off' && _primaryCues.isNotEmpty) {
      for (final cue in _primaryCues) {
        if (sec >= cue.startTime && sec <= cue.endTime) {
          activePrimary = cue;
          break;
        }
      }
    }

    TxaSubtitleCue? activeSecondary;
    if (_subtitleMode == 'bilingual' && _secondaryCues.isNotEmpty) {
      for (final cue in _secondaryCues) {
        if (sec >= cue.startTime && sec <= cue.endTime) {
          activeSecondary = cue;
          break;
        }
      }
    }

    if (activePrimary != _activePrimaryCue || activeSecondary != _activeSecondaryCue) {
      setState(() {
        _activePrimaryCue = activePrimary;
        _activeSecondaryCue = activeSecondary;
      });
    }
  }

  void _cycleMode() {
    setState(() {
      if (_subtitleMode == 'off') {
        _subtitleMode = 'primary';
      } else if (_subtitleMode == 'primary') {
        if (widget.subtitles != null && widget.subtitles!.length > 1) {
          _subtitleMode = 'bilingual';
        } else {
          _subtitleMode = 'off';
        }
      } else {
        _subtitleMode = 'off';
      }
    });
  }

  void _selectPrimaryTrack(int idx) {
    setState(() {
      _primarySubIdx = idx;
      if (_secondarySubIdx == _primarySubIdx) {
        _secondarySubIdx = (idx + 1) % (widget.subtitles?.length ?? 1);
      }
    });
    _loadSubtitleTrack(idx, true);
  }

  void _selectSecondaryTrack(int idx) {
    setState(() {
      _secondarySubIdx = idx;
    });
    _loadSubtitleTrack(idx, false);
  }

  // --- TV REMOTE SUBTITLES MENU ---
  List<Map<String, dynamic>> _getTvMenuItems() {
    final List<Map<String, dynamic>> items = [];
    
    String modeLabel = TxaLanguage.t('sub_mode_off');
    if (_subtitleMode == 'primary') modeLabel = TxaLanguage.t('sub_mode_primary');
    if (_subtitleMode == 'bilingual') modeLabel = TxaLanguage.t('sub_mode_bilingual');
    items.add({
      'type': 'mode',
      'label': TxaLanguage.t('sub_mode_label', replace: {'mode': modeLabel}),
    });

    if (_subtitleMode != 'off' && widget.subtitles != null) {
      items.add({
        'type': 'section',
        'label': TxaLanguage.t('select_primary_sub'),
      });
      for (int i = 0; i < widget.subtitles!.length; i++) {
        final track = widget.subtitles![i];
        final isSelected = _primarySubIdx == i;
        items.add({
          'type': 'primary_track',
          'index': i,
          'label': "${track['label'] ?? 'Track $i'}${isSelected ? TxaLanguage.t('currently_selected') : ''}",
          'selected': isSelected,
        });
      }
    }

    if (_subtitleMode == 'bilingual' && widget.subtitles != null && widget.subtitles!.length > 1) {
      items.add({
        'type': 'section',
        'label': TxaLanguage.t('select_secondary_sub'),
      });
      for (int i = 0; i < widget.subtitles!.length; i++) {
        if (_primarySubIdx == i) continue;
        final track = widget.subtitles![i];
        final isSelected = _secondarySubIdx == i;
        items.add({
          'type': 'secondary_track',
          'index': i,
          'label': "${track['label'] ?? 'Track $i'}${isSelected ? TxaLanguage.t('currently_selected') : ''}",
          'selected': isSelected,
        });
      }
    }
    // Playback Speed section for TV settings menu
    items.add({
      'type': 'section',
      'label': TxaLanguage.t('select_speed'),
    });
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    for (final s in speeds) {
      final isSelected = _playbackSpeed == s;
      items.add({
        'type': 'speed_rate',
        'value': s,
        'label': "${s == 1.0 ? TxaLanguage.t('speed_normal') : '${s}x'}${isSelected ? TxaLanguage.t('currently_selected') : ''}",
        'selected': isSelected,
      });
    }

    // Episode Navigation section for TV settings menu
    if (widget.prevEpisode != null || widget.nextEpisode != null) {
      items.add({
        'type': 'section',
        'label': TxaLanguage.t('switch_episode'),
      });
      if (widget.prevEpisode != null) {
        items.add({
          'type': 'play_prev',
          'label': TxaLanguage.t('prev_episode_label', replace: {'name': widget.prevEpisode!['name'] ?? ''}),
        });
      }
      if (widget.nextEpisode != null) {
        items.add({
          'type': 'play_next',
          'label': TxaLanguage.t('next_episode_label', replace: {'name': widget.nextEpisode!['name'] ?? ''}),
        });
      }
    }

    // TV Servers selection list in TV settings menu
    if (widget.servers != null && widget.servers!.length > 1) {
      items.add({
        'type': 'section',
        'label': TxaLanguage.t('tv_select_server_section'),
      });
      for (int i = 0; i < widget.servers!.length; i++) {
        final server = widget.servers![i];
        final isSelected = _currentServerIndex == i;
        items.add({
          'type': 'tv_server',
          'index': i,
          'label': "${server['server_name'] ?? 'Source $i'}${isSelected ? TxaLanguage.t('currently_selected') : ''}",
          'selected': isSelected,
        });
      }
    }

    if (widget.servers != null && widget.servers!.isNotEmpty) {
      items.add({
        'type': 'open_playlist',
        'label': TxaLanguage.t('episode_list_playlist'),
      });
    }

    items.add({
      'type': 'close',
      'label': TxaLanguage.t('close_settings'),
    });

    return items;
  }

  void _navigateTvMenu(int offset) {
    final menuItems = _getTvMenuItems();
    if (menuItems.isEmpty) return;
    
    int index = _tvMenuSelectedIndex + offset;
    while (index >= 0 && index < menuItems.length) {
      if (menuItems[index]['type'] == 'section') {
        index += offset;
      } else {
        setState(() {
          _tvMenuSelectedIndex = index;
        });
        return;
      }
    }
  }

  void _triggerTvMenuAction() {
    final menuItems = _getTvMenuItems();
    if (_tvMenuSelectedIndex < 0 || _tvMenuSelectedIndex >= menuItems.length) return;
    
    final item = menuItems[_tvMenuSelectedIndex];
    switch (item['type']) {
      case 'mode':
        _cycleMode();
        break;
      case 'primary_track':
        _selectPrimaryTrack(item['index']);
        break;
      case 'secondary_track':
        _selectSecondaryTrack(item['index']);
        break;
      case 'speed_rate':
        _setPlaybackSpeed(item['value']);
        break;
      case 'play_prev':
        if (widget.onPlayPrev != null) widget.onPlayPrev!();
        break;
      case 'play_next':
        if (widget.onPlayNext != null) widget.onPlayNext!();
        break;
      case 'tv_server':
        final server = widget.servers![item['index']];
        final eps = server['server_data'] as List? ?? [];
        Map<String, dynamic>? matchEp;
        for (var ep in eps) {
          if (ep['id']?.toString() == _currentEpisodeId || ep['slug']?.toString() == _currentEpisodeId) {
            matchEp = ep;
            break;
          }
        }
        if (matchEp != null) {
          final url = _resolveAdStreamUrl(matchEp);
          if (url != null) {
            _changeServer(item['index'], server['server_name'] ?? 'Nguồn phát', url);
            setState(() {
              _showTvSubtitlesMenu = false;
            });
          } else {
            TxaToast.show(context, TxaLanguage.t('server_no_stream'), isError: true);
          }
        } else {
          TxaToast.show(context, TxaLanguage.t('ep_not_updated_on_server'), isError: true);
        }
        break;
      case 'open_playlist':
        setState(() {
          _showTvSubtitlesMenu = false;
        });
        _openPlaylistPanel();
        break;
      case 'close':
        setState(() {
          _showTvSubtitlesMenu = false;
        });
        break;
    }
  }

  // --- NEXT EPISODE COUNTDOWN FLOW ---
  void _handleVideoEnded() {
    if (!TxaPlatform.isTV && widget.nextEpisode != null && widget.onPlayNext != null) {
      setState(() {
        _showNextEpisodeOverlay = true;
        _nextEpisodeCountdown = 5;
      });
      _startNextEpisodeCountdown();
    } else {
      if (widget.onEnded != null) widget.onEnded!();
    }
  }

  void _startNextEpisodeCountdown() {
    _nextEpisodeTimer?.cancel();
    _nextEpisodeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_nextEpisodeCountdown > 1) {
          _nextEpisodeCountdown--;
        } else {
          timer.cancel();
          _playNextEpisode();
        }
      });
    });
  }

  void _playNextEpisode() {
    _nextEpisodeTimer?.cancel();
    if (widget.onPlayNext != null) {
      widget.onPlayNext!();
    }
  }

  void _cancelNextEpisode() {
    _nextEpisodeTimer?.cancel();
    setState(() {
      _showNextEpisodeOverlay = false;
    });
    if (widget.onEnded != null) widget.onEnded!();
  }

  // --- SKIP INTRO/OUTRO ACTION ---
  bool _isSkipVisible() {
    final sec = _position.inSeconds;
    final hasIntro = widget.timeIntroEnd > widget.timeIntroStart && widget.timeIntroEnd > 0;
    final hasOutro = widget.timeOutroEnd > widget.timeOutroStart && widget.timeOutroEnd > 0;
    
    final inIntro = hasIntro && sec >= widget.timeIntroStart && sec <= widget.timeIntroEnd;
    final inOutro = hasOutro && sec >= widget.timeOutroStart && sec <= widget.timeOutroEnd;
    
    return inIntro || inOutro;
  }

  void _handleSkipIntroOutro() {
    if (_position.inSeconds >= widget.timeIntroStart && _position.inSeconds <= widget.timeIntroEnd) {
      _controller?.seekTo(Duration(seconds: widget.timeIntroEnd));
      TxaToast.show(context, TxaLanguage.t('intro_skipped'));
    } else if (_position.inSeconds >= widget.timeOutroStart && _position.inSeconds <= widget.timeOutroEnd) {
      _controller?.seekTo(Duration(seconds: widget.timeOutroEnd));
      TxaToast.show(context, TxaLanguage.t('outro_skipped'));
    }
  }

  // --- MOBILE SUBTITLES PANEL ---
  void _showMobileSubtitlesPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final hasMultiple = widget.subtitles != null && widget.subtitles!.length > 1;
            
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          TxaLanguage.t('subtitle_settings'),
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.all(2),
                          child: Row(
                            children: [
                              _buildSegmentBtn("primary", TxaLanguage.t('sub_on'), setSheetState),
                              if (hasMultiple)
                                _buildSegmentBtn("bilingual", TxaLanguage.t('sub_mode_bilingual'), setSheetState),
                              _buildSegmentBtn("off", TxaLanguage.t('sub_mode_off'), setSheetState),
                            ],
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    if (_subtitleMode != 'off' && widget.subtitles != null) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(TxaLanguage.t('primary_sub_label'), style: const TextStyle(color: Colors.white30, fontSize: 11, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 150,
                                    child: ListView.builder(
                                      itemCount: widget.subtitles!.length,
                                      itemBuilder: (c, idx) {
                                        final isSelected = _primarySubIdx == idx;
                                        return InkWell(
                                          onTap: () {
                                            _selectPrimaryTrack(idx);
                                            setSheetState(() {});
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  widget.subtitles![idx]['label'] ?? 'Track $idx',
                                                  style: TextStyle(
                                                    color: isSelected ? Colors.amberAccent : Colors.white,
                                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                if (isSelected)
                                                  const Icon(Icons.check, color: Colors.amberAccent, size: 16),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Opacity(
                              opacity: _subtitleMode == 'bilingual' ? 1.0 : 0.35,
                              child: AbsorbPointer(
                                absorbing: _subtitleMode != 'bilingual',
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.03),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(TxaLanguage.t('secondary_sub_label'), style: const TextStyle(color: Colors.white30, fontSize: 11, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        height: 150,
                                        child: ListView.builder(
                                          itemCount: widget.subtitles!.length,
                                          itemBuilder: (c, idx) {
                                            if (_primarySubIdx == idx) return const SizedBox.shrink();
                                            final isSelected = _secondarySubIdx == idx;
                                            return InkWell(
                                              onTap: () {
                                                _selectSecondaryTrack(idx);
                                                setSheetState(() {});
                                              },
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(
                                                      widget.subtitles![idx]['label'] ?? 'Track $idx',
                                                      style: TextStyle(
                                                        color: isSelected ? Colors.amberAccent : Colors.white,
                                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                    if (isSelected)
                                                      const Icon(Icons.check, color: Colors.amberAccent, size: 16),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showMobileSpeedPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  TxaLanguage.t('playback_speed'),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: speeds.length,
                  itemBuilder: (c, idx) {
                    final s = speeds[idx];
                    final isSelected = _playbackSpeed == s;
                    return InkWell(
                      onTap: () {
                        _setPlaybackSpeed(s);
                        Navigator.pop(ctx);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              s == 1.0 ? TxaLanguage.t('speed_normal') : "${s}x",
                              style: TextStyle(
                                color: isSelected ? const Color(0xFF737DFD) : Colors.white,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check, color: Color(0xFF737DFD), size: 18),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String? _resolveAdStreamUrl(Map<String, dynamic> ep) {
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

  void _changeServer(int serverIndex, String serverName, String streamUrl) async {
    if (_controller == null) return;
    final savedPosition = _position;
    
    _controller!.removeListener(() {});
    await _controller!.pause();
    await _controller!.dispose();
    
    setState(() {
      _isPlayerInitialized = false;
      _currentUrl = streamUrl;
      _currentServerName = serverName;
      _currentServerIndex = serverIndex;
    });

    _initMainPlayer(startFrom: savedPosition);
    
    if (widget.onEpisodeChanged != null) {
      widget.onEpisodeChanged!(_currentEpisodeId, _currentEpisodeName, serverIndex);
    }
  }

  void _playNewEpisodeInternally(int serverIndex, Map<String, dynamic> ep) async {
    final url = _resolveAdStreamUrl(ep);
    if (url == null) {
      TxaToast.show(context, TxaLanguage.t('player_no_stream'), isError: true);
      return;
    }
    
    _controller?.removeListener(() {});
    await _controller?.pause();
    await _controller?.dispose();
    _controller = null;
    
    setState(() {
      _isPlayerInitialized = false;
      _currentServerIndex = serverIndex;
      _currentEpisodeId = ep['id']?.toString() ?? ep['slug']?.toString() ?? '';
      _currentEpisodeName = ep['name'] ?? '';
      _currentUrl = url;
      _showPlaylistPanel = false;
      
      _primaryCues = [];
      _secondaryCues = [];
      _activePrimaryCue = null;
      _activeSecondaryCue = null;
    });
    
    final subs = ep['subtitles'] ?? ep['subtitles_data'];
    if (subs != null && subs is List && subs.isNotEmpty) {
      _primarySubIdx = 0;
      _loadSubtitleTrack(0, true);
      if (subs.length > 1) {
        _secondarySubIdx = 1;
        _loadSubtitleTrack(1, false);
        _subtitleMode = 'bilingual';
      } else {
        _subtitleMode = 'primary';
      }
    } else {
      _subtitleMode = 'off';
    }
    
    _initMainPlayer();
    
    if (widget.onEpisodeChanged != null) {
      widget.onEpisodeChanged!(_currentEpisodeId, _currentEpisodeName, serverIndex);
    }
  }

  void _openPlaylistPanel() {
    _controller?.pause();
    setState(() {
      _isPlaying = false;
      _showPlaylistPanel = true;
      _playlistServerSelectedIndex = _currentServerIndex;
      
      final server = widget.servers?[_playlistServerSelectedIndex];
      final rawEps = server?['server_data'] as List? ?? [];
      final eps = rawEps.where((ep) => ep['is_unreleased'] != true).toList();
      _playlistEpisodeSelectedIndex = 0;
      for (int i = 0; i < eps.length; i++) {
        if (eps[i]['id']?.toString() == _currentEpisodeId || eps[i]['slug']?.toString() == _currentEpisodeId) {
          _playlistEpisodeSelectedIndex = i;
          break;
        }
      }
    });
  }

  void _closePlaylistPanel() {
    setState(() {
      _showPlaylistPanel = false;
    });
    _controller?.play();
    setState(() {
      _isPlaying = true;
    });
  }

  void _showMobileServerPanel(BuildContext context) {
    if (widget.servers == null || widget.servers!.isEmpty) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Chọn nguồn phát (Server)",
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.servers!.length,
                itemBuilder: (c, idx) {
                  final server = widget.servers![idx];
                  final isSelected = _currentServerIndex == idx;
                  return InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      final eps = server['server_data'] as List? ?? [];
                      Map<String, dynamic>? matchEp;
                      for (var ep in eps) {
                        if (ep['id']?.toString() == _currentEpisodeId || ep['slug']?.toString() == _currentEpisodeId) {
                          matchEp = ep;
                          break;
                        }
                      }
                      if (matchEp != null) {
                        final url = _resolveAdStreamUrl(matchEp);
                        if (url != null) {
                          _changeServer(idx, server['server_name'] ?? 'Nguồn phát', url);
                        } else {
                          TxaToast.show(context, TxaLanguage.t('server_no_stream'), isError: true);
                        }
                      } else {
                        TxaToast.show(context, TxaLanguage.t('ep_not_updated_on_server'), isError: true);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            server['server_name'] ?? 'Nguồn phát',
                            style: TextStyle(
                              color: isSelected ? const Color(0xFF737DFD) : Colors.white,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check, color: Color(0xFF737DFD), size: 18),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatPlaylistEpisodeName(String name) {
    final clean = name.replaceAll(RegExp(r'(tập|tap|episode|ep|ep-)\s*', caseSensitive: false), '').trim();
    if (clean.toLowerCase() == 'full') return 'Full/FULL';
    return '$clean/FULL';
  }

  Widget _buildSegmentBtn(String mode, String label, StateSetter setSheetState) {
    final isActive = _subtitleMode == mode;
    return GestureDetector(
      onTap: () {
        setSheetState(() {
          _subtitleMode = mode;
        });
        setState(() {
          _subtitleMode = mode;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  void _togglePlayPause() {
    if (_isLocked) return;
    if (_controller == null || !_isPlayerInitialized) return;

    setState(() {
      if (_isPlaying) {
        _controller!.pause();
        _isPlaying = false;
      } else {
        _controller!.play();
        _isPlaying = true;
      }
    });
    _resetHideControlsTimer();
  }

  void _seek(int seconds) {
    if (_isLocked) return;
    if (_controller == null || !_isPlayerInitialized) return;

    final newPos = _position + Duration(seconds: seconds);
    final clamped = newPos < Duration.zero
        ? Duration.zero
        : (newPos > _duration ? _duration : newPos);
    _controller!.seekTo(clamped);
    _resetHideControlsTimer();
  }

  void _resetHideControlsTimer() {
    _hideControlsTimer?.cancel();
    setState(() {
      _showControls = true;
    });
    
    if (_isPlaying) {
      _hideControlsTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && _isPlaying) {
          setState(() {
            _showControls = false;
          });
        }
      });
    }
  }

  void _showLockButtonTemporarily() {
    _lockButtonTimer?.cancel();
    setState(() {
      _showLockButtonOnly = true;
    });
    _lockButtonTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showLockButtonOnly = false;
        });
      }
    });
  }

  void _setPlaybackSpeed(double speed) {
    if (_controller == null || !_isPlayerInitialized) return;
    setState(() {
      _playbackSpeed = speed;
    });
    _controller!.setPlaybackSpeed(speed);
    TxaToast.show(context, TxaLanguage.t('play_speed_toast', replace: {'speed': speed.toString()}));
  }

  // --- Adjust Volume & Brightness (REAL system-level on mobile) ---
  void _adjustVolume(double delta) {
    setState(() {
      _volume = (_volume + delta).clamp(0.0, 1.0);
      _controller?.setVolume(_volume);
      _showVolumeIndicator = true;
      _showBrightnessIndicator = false;
    });
    if (TxaPlatform.isMobile) {
      try {
        VolumeController().setVolume(_volume, showSystemUI: false);
      } catch (_) {}
    }
    _resetIndicatorTimer();
  }

  void _adjustBrightness(double delta) {
    setState(() {
      _brightness = (_brightness + delta).clamp(0.0, 1.0);
      _showBrightnessIndicator = true;
      _showVolumeIndicator = false;
    });
    if (TxaPlatform.isMobile) {
      try {
        ScreenBrightness().setScreenBrightness(_brightness);
      } catch (_) {}
    }
    _resetIndicatorTimer();
  }

  Future<void> _initMobileSystemControls() async {
    try {
      _brightness = await ScreenBrightness().current;
    } catch (_) {
      _brightness = 0.5;
    }
    try {
      VolumeController().showSystemUI = false;
      _volume = await VolumeController().getVolume();
    } catch (_) {
      _volume = 1.0;
    }
    if (mounted) setState(() {});
  }

  void _resetIndicatorTimer() {
    _indicatorTimer?.cancel();
    _indicatorTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showVolumeIndicator = false;
          _showBrightnessIndicator = false;
        });
      }
    });
  }

  // --- Helpers ---
  String _formatDuration(Duration duration) {
    if (duration.inHours >= 1) {
      final hours = duration.inHours;
      final mins = duration.inMinutes % 60;
      final secs = duration.inSeconds % 60;
      return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      final mins = duration.inMinutes;
      final secs = duration.inSeconds % 60;
      return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
  }

  String _cleanEpisodeName(String name) {
    // Keep only numbers or clean string
    return name.replaceAll(RegExp(r'(tập|tap|episode|ep|ep-)\s*', caseSensitive: false), '').trim();
  }

  // --- Smart TV Key Handler ---
  void _handleTvKeyEvent(KeyEvent event) {
    _resetHideControlsTimer();
    
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final logicalKey = event.logicalKey;
      
      if (_showPlaylistPanel) {
        final server = widget.servers?[_playlistServerSelectedIndex];
        final rawEps = server?['server_data'] as List? ?? [];
        final eps = rawEps.where((ep) => ep['is_unreleased'] != true).toList();
        
        if (logicalKey == LogicalKeyboardKey.arrowUp) {
          setState(() {
            if (_playlistEpisodeSelectedIndex >= 4) {
              _playlistEpisodeSelectedIndex -= 4;
            }
          });
        } else if (logicalKey == LogicalKeyboardKey.arrowDown) {
          setState(() {
            if (_playlistEpisodeSelectedIndex + 4 < eps.length) {
              _playlistEpisodeSelectedIndex += 4;
            }
          });
        } else if (logicalKey == LogicalKeyboardKey.arrowLeft) {
          setState(() {
            if (_playlistEpisodeSelectedIndex % 4 > 0) {
              _playlistEpisodeSelectedIndex--;
            } else if (_playlistServerSelectedIndex > 0) {
              _playlistServerSelectedIndex--;
              _playlistEpisodeSelectedIndex = 0;
            }
          });
        } else if (logicalKey == LogicalKeyboardKey.arrowRight) {
          setState(() {
            if (_playlistEpisodeSelectedIndex % 4 < 3 && _playlistEpisodeSelectedIndex + 1 < eps.length) {
              _playlistEpisodeSelectedIndex++;
            } else if (_playlistServerSelectedIndex + 1 < (widget.servers?.length ?? 0)) {
              _playlistServerSelectedIndex++;
              _playlistEpisodeSelectedIndex = 0;
            }
          });
        } else if (logicalKey == LogicalKeyboardKey.select ||
                   logicalKey == LogicalKeyboardKey.enter ||
                   logicalKey == LogicalKeyboardKey.gameButtonSelect) {
          if (eps.isNotEmpty && _playlistEpisodeSelectedIndex >= 0 && _playlistEpisodeSelectedIndex < eps.length) {
            _playNewEpisodeInternally(_playlistServerSelectedIndex, eps[_playlistEpisodeSelectedIndex]);
          }
        } else if (logicalKey == LogicalKeyboardKey.escape ||
                   logicalKey == LogicalKeyboardKey.goBack) {
          _closePlaylistPanel();
        }
        return;
      }

      if (_showTvSubtitlesMenu) {
        if (logicalKey == LogicalKeyboardKey.arrowUp) {
          _navigateTvMenu(-1);
        } else if (logicalKey == LogicalKeyboardKey.arrowDown) {
          _navigateTvMenu(1);
        } else if (logicalKey == LogicalKeyboardKey.select ||
                   logicalKey == LogicalKeyboardKey.enter ||
                   logicalKey == LogicalKeyboardKey.gameButtonSelect) {
          _triggerTvMenuAction();
        } else if (logicalKey == LogicalKeyboardKey.arrowLeft ||
                   logicalKey == LogicalKeyboardKey.arrowRight ||
                   logicalKey == LogicalKeyboardKey.escape ||
                   logicalKey == LogicalKeyboardKey.goBack) {
          setState(() {
            _showTvSubtitlesMenu = false;
          });
        }
        return;
      }
      
      if (logicalKey == LogicalKeyboardKey.select ||
          logicalKey == LogicalKeyboardKey.enter ||
          logicalKey == LogicalKeyboardKey.gameButtonSelect) {
        if (_isSkipVisible()) {
          _handleSkipIntroOutro();
        } else {
          _togglePlayPause();
        }
      } else if (logicalKey == LogicalKeyboardKey.arrowRight) {
        _seek(15);
      } else if (logicalKey == LogicalKeyboardKey.arrowLeft) {
        _seek(-15);
      } else if (logicalKey == LogicalKeyboardKey.arrowUp) {
        _adjustVolume(0.1);
      } else if (logicalKey == LogicalKeyboardKey.arrowDown) {
        if (_showControls && widget.subtitles != null && widget.subtitles!.isNotEmpty) {
          setState(() {
            _showTvSubtitlesMenu = true;
            _tvMenuSelectedIndex = 0;
          });
        } else {
          _adjustVolume(-0.1);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine screen layout content
    if (_showAd) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Ad Display
            if (_adError)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      TxaLanguage.t('ad_load_failed'),
                      style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )
            else if (_adType == 'video' && _adController != null && _adController!.value.isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: _adController!.value.aspectRatio,
                  child: VideoPlayer(_adController!),
                ),
              )
            else if (_adType == 'image' && _adUrl != null)
              Center(
                child: Image.network(
                  _adUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(
                    color: Colors.black,
                    child: const Center(
                      child: Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                    ),
                  ),
                ),
              )
            else if (_adType == 'embed')
              Positioned.fill(
                child: TxaPlatform.isMobile && _webViewController != null
                    ? WebViewWidget(controller: _webViewController!)
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.ondemand_video_rounded, color: Color(0xFF737DFD), size: 48),
                            const SizedBox(height: 12),
                            Text(
                              TxaLanguage.t('ad_loading_yt'),
                              style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
              )
            else
              const Center(
                child: CircularProgressIndicator(color: Color(0xFF737DFD)),
              ),

            // Top Header: "Quảng Cáo" label
            Positioned(
              top: 32,
              left: 32,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _adType == 'video' ? TxaLanguage.t('ad_label') : TxaLanguage.t('sponsored_link'),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            // VIP Hint
            Positioned(
              top: 32,
              right: 32,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      TxaLanguage.t('ad_vip_hint'),
                      style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom skip button
            Positioned(
              bottom: 32,
              right: 32,
              child: _adError
                  ? TextButton(
                      onPressed: _skipAd,
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Row(
                        children: [
                          Text(TxaLanguage.t('ad_error_skip'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(width: 6),
                          const Icon(Icons.skip_next_rounded, size: 18),
                        ],
                      ),
                    )
                  : _canSkipAd
                      ? TextButton(
                          onPressed: _skipAd,
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Row(
                            children: [
                              Text(TxaLanguage.t('ad_skip'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(width: 4),
                              const Icon(Icons.skip_next_rounded, size: 18),
                            ],
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            TxaLanguage.t('ad_countdown', replace: {'seconds': _adTimeLeft.toString()}),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
            ),
          ],
        ),
      );
    }

    Widget playerView = Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. VIDEO PLAYER
          if (_isPlayerInitialized) ...[
            Positioned.fill(
              child: Center(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
              ),
            ),
            if (_controller!.value.isBuffering)
              Positioned.fill(
                child: Container(
                  color: Colors.black45,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: Color(0xFF737DFD)),
                        const SizedBox(height: 16),
                        Text(
                          TxaLanguage.t('loading_video'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(blurRadius: 8, color: Colors.black87),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ] else
            Positioned.fill(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF737DFD)),
                    const SizedBox(height: 16),
                    Text(
                      TxaLanguage.t('player_preparing'),
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                    )
                  ],
                ),
              ),
            ),

          // Exclude Focus for Overlay UI on TV to prevent controls from stealing focus from root _tvFocusNode
          Positioned.fill(
            child: ExcludeFocus(
              excluding: TxaPlatform.isTV,
              child: Stack(
                children: [
                  // 2. BACKDROP SHADOW COVER (For Controls)
                  if (_showControls && !_isLocked)
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.black87, Colors.transparent, Colors.black87],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),

                  // 3. TOP OVERLAY BAR (always visible, interactive elements hidden when locked)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.fromLTRB(
                        MediaQuery.of(context).size.width * 0.03,
                        MediaQuery.of(context).size.height * 0.03,
                        MediaQuery.of(context).size.width * 0.03,
                        8,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                        ),
                      ),
                      child: SizedBox(
                        height: 48,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (_showControls && !_isLocked)
                              Positioned(
                                left: 0,
                                child: IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                                ),
                              ),
                            // Battery Indicator (Mobile Only) - always visible
                            if (TxaPlatform.isMobile && _batteryLevel >= 0)
                              Positioned(
                                left: (_showControls && !_isLocked) ? 48 : 0,
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 250),
                                  opacity: _showControls ? 1.0 : 0.7,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _getBatteryIcon(),
                                        color: _getBatteryColor(),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        '$_batteryLevel%',
                                        style: TextStyle(
                                          color: _getBatteryColor(),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: (_showControls && !_isLocked) ? 80 : 56,
                              ),
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 250),
                                opacity: _showControls ? 1.0 : 0.8,
                                child: Text(
                                  "${widget.movieName} - ${(TxaLanguage.currentLang == 'vi' ? 'Tập' : 'EP')} ${_cleanEpisodeName(_currentEpisodeName)} | $_currentServerName",
                                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 250),
                                opacity: _showControls ? 1.0 : 0.7,
                                child: Text(
                                  _clockString,
                                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 4. WATERMARK LOGO OVERLAY (always visible, shifted up when controls show)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    bottom: _showControls 
                        ? (MediaQuery.of(context).size.height * 0.18) 
                        : (MediaQuery.of(context).size.height * 0.03),
                    right: MediaQuery.of(context).size.width * 0.03,
                    child: Opacity(
                      opacity: _showControls ? 0.7 : 0.45,
                      child: Image.asset(
                        'assets/logo.png',
                        width: MediaQuery.of(context).size.shortestSide * 0.06,
                        height: MediaQuery.of(context).size.shortestSide * 0.06,
                      ),
                    ),
                  ),

                  // 5. SLIDER ADJUSTMENT INDICATORS (Mobile Only)
                  if (!TxaPlatform.isTV) ...[
                    if (_showVolumeIndicator)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.volume_up_rounded, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text('${(_volume * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    if (_showBrightnessIndicator)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.brightness_medium_rounded, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text('${(_brightness * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                  ],

                  // 5.5 MOBILE CENTER PLAYBACK CONTROLS (Play/Pause, ±10s, Prev/Next)
                  if (TxaPlatform.isMobile && _showControls && _isPlayerInitialized && !_isLocked)
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (widget.prevEpisode != null) ...[
                            IconButton(
                              icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 32),
                              onPressed: widget.onPlayPrev,
                            ),
                            const SizedBox(width: 16),
                          ],
                          IconButton(
                            icon: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 36),
                            onPressed: () => _seek(-10),
                          ),
                          const SizedBox(width: 20),
                          GestureDetector(
                            onTap: _togglePlayPause,
                            child: CircleAvatar(
                              radius: 30,
                              backgroundColor: const Color(0xFF737DFD),
                              child: Icon(
                                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: Colors.black,
                                size: 34,
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          IconButton(
                            icon: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 36),
                            onPressed: () => _seek(10),
                          ),
                          if (widget.nextEpisode != null) ...[
                            const SizedBox(width: 16),
                            IconButton(
                              icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 32),
                              onPressed: widget.onPlayNext,
                            ),
                          ],
                        ],
                      ),
                    ),

                  // 6. BOTTOM CONTROLS & TIMELINE
                  if (_showControls && _isPlayerInitialized && !_isLocked)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final screenWidth = constraints.maxWidth;
                          final screenHeight = MediaQuery.of(context).size.height;
                          final scale = (screenWidth / 800).clamp(0.7, 1.5);
                          final hPad = screenWidth * 0.03;
                          final fontSize = (11.0 * scale).clamp(9.0, 14.0);
                          final iconSize = (26.0 * scale).clamp(20.0, 34.0);
                          final playBtnRadius = (24.0 * scale).clamp(18.0, 32.0);
                          final thumbRadius = (6.0 * scale).clamp(4.0, 10.0);
                          final trackH = (3.5 * scale).clamp(2.0, 5.0);

                          return Container(
                            padding: EdgeInsets.fromLTRB(hPad, 8, hPad, screenHeight * 0.025),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Progress Timeline: time left | slider | time right
                                Row(
                                  children: [
                                    Text(_formatDuration(_position), style: TextStyle(color: Colors.white70, fontSize: fontSize, fontFamily: 'monospace')),
                                    Expanded(
                                      child: LayoutBuilder(
                                        builder: (context, sliderConstraints) {
                                          final sliderWidth = sliderConstraints.maxWidth;
                                          return Stack(
                                            alignment: Alignment.centerLeft,
                                            children: [
                                              // Track Markers (behind the Slider)
                                              if (_duration > Duration.zero) ...[
                                                if (widget.timeIntroEnd > widget.timeIntroStart && widget.timeIntroEnd <= _duration.inSeconds)
                                                  Positioned(
                                                    left: 24 + (widget.timeIntroStart / _duration.inSeconds) * (sliderWidth - 48),
                                                    width: ((widget.timeIntroEnd - widget.timeIntroStart) / _duration.inSeconds) * (sliderWidth - 48),
                                                    child: Container(
                                                      height: trackH,
                                                      color: Colors.amber.withValues(alpha: 0.6),
                                                    ),
                                                  ),
                                                if (widget.timeOutroStart > widget.timeIntroEnd && widget.timeOutroStart <= _duration.inSeconds)
                                                  Positioned(
                                                    left: 24 + (widget.timeOutroStart / _duration.inSeconds) * (sliderWidth - 48),
                                                    width: ((widget.timeOutroEnd - widget.timeOutroStart) / _duration.inSeconds).clamp(0.0, 1.0) * (sliderWidth - 48),
                                                    child: Container(
                                                      height: trackH,
                                                      color: Colors.green.withValues(alpha: 0.6),
                                                    ),
                                                  ),
                                              ],
                                              // The Slider
                                              SliderTheme(
                                                data: SliderTheme.of(context).copyWith(
                                                  thumbColor: const Color(0xFF737DFD),
                                                  activeTrackColor: const Color(0xFF737DFD),
                                                  inactiveTrackColor: Colors.white24,
                                                  trackHeight: trackH,
                                                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: thumbRadius),
                                                ),
                                                child: Slider(
                                                  value: _position.inSeconds.toDouble(),
                                                  max: _duration.inSeconds.toDouble(),
                                                  onChanged: (val) {
                                                    _seek(val.toInt() - _position.inSeconds);
                                                  },
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                    Text(_formatDuration(_duration), style: TextStyle(color: Colors.white70, fontSize: fontSize, fontFamily: 'monospace')),
                                  ],
                                ),

                                // Mobile: icon row only (no play/pause here)
                                if (TxaPlatform.isMobile) ...[
                                  SizedBox(height: 4 * scale),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (widget.subtitles != null && widget.subtitles!.isNotEmpty) ...[
                                        IconButton(
                                          icon: Icon(Icons.subtitles_rounded, color: Colors.white, size: iconSize - 2),
                                          onPressed: () => _showMobileSubtitlesPanel(context),
                                          tooltip: TxaLanguage.t('subtitle_settings'),
                                        ),
                                        SizedBox(width: 8 * scale),
                                      ],
                                      if (widget.servers != null && widget.servers!.length > 1) ...[
                                        IconButton(
                                          icon: Icon(Icons.dns_rounded, color: Colors.white, size: iconSize - 2),
                                          onPressed: () => _showMobileServerPanel(context),
                                          tooltip: TxaLanguage.t('server'),
                                        ),
                                        SizedBox(width: 8 * scale),
                                      ],
                                      IconButton(
                                        icon: Icon(Icons.speed_rounded, color: Colors.white, size: iconSize - 2),
                                        onPressed: () => _showMobileSpeedPanel(context),
                                        tooltip: TxaLanguage.t('play_speed'),
                                      ),
                                      if (widget.servers != null && widget.servers!.isNotEmpty) ...[
                                        SizedBox(width: 8 * scale),
                                        IconButton(
                                          icon: Icon(Icons.playlist_play_rounded, color: Colors.white, size: iconSize),
                                          onPressed: _openPlaylistPanel,
                                          tooltip: TxaLanguage.t('episode_list'),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],

                                // TV / Desktop: full play controls row (existing layout)
                                if (!TxaPlatform.isMobile) ...[
                                  SizedBox(height: 8 * scale),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (widget.prevEpisode != null) ...[
                                        IconButton(
                                          icon: Icon(Icons.skip_previous_rounded, color: Colors.white, size: iconSize + 2),
                                          onPressed: widget.onPlayPrev,
                                        ),
                                        SizedBox(width: 8 * scale),
                                      ],
                                      IconButton(
                                        icon: Icon(Icons.replay_10_rounded, color: Colors.white, size: iconSize),
                                        onPressed: () => _seek(-10),
                                      ),
                                      SizedBox(width: 12 * scale),
                                      GestureDetector(
                                        onTap: _togglePlayPause,
                                        child: CircleAvatar(
                                          radius: playBtnRadius,
                                          backgroundColor: const Color(0xFF737DFD),
                                          child: Icon(
                                            _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                            color: Colors.black,
                                            size: playBtnRadius + 2,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 12 * scale),
                                      IconButton(
                                        icon: Icon(Icons.forward_10_rounded, color: Colors.white, size: iconSize),
                                        onPressed: () => _seek(10),
                                      ),
                                      if (widget.nextEpisode != null) ...[
                                        SizedBox(width: 8 * scale),
                                        IconButton(
                                          icon: Icon(Icons.skip_next_rounded, color: Colors.white, size: iconSize + 2),
                                          onPressed: widget.onPlayNext,
                                        ),
                                      ],
                                      // Desktop Volume Control
                                      if (TxaPlatform.isDesktop) ...[
                                        SizedBox(width: 12 * scale),
                                        _buildDesktopVolumeControl(),
                                      ],
                                      if (widget.subtitles != null && widget.subtitles!.isNotEmpty) ...[
                                        SizedBox(width: 12 * scale),
                                        IconButton(
                                          icon: Icon(Icons.subtitles_rounded, color: Colors.white, size: iconSize - 2),
                                          onPressed: () => _showMobileSubtitlesPanel(context),
                                          tooltip: TxaLanguage.t('subtitle_settings'),
                                        ),
                                      ],
                                      if (widget.servers != null && widget.servers!.length > 1) ...[
                                        SizedBox(width: 12 * scale),
                                        IconButton(
                                          icon: Icon(Icons.dns_rounded, color: Colors.white, size: iconSize - 2),
                                          onPressed: () => _showMobileServerPanel(context),
                                          tooltip: TxaLanguage.t('server'),
                                        ),
                                      ],
                                      SizedBox(width: 12 * scale),
                                      IconButton(
                                        icon: Icon(Icons.speed_rounded, color: Colors.white, size: iconSize - 2),
                                        onPressed: () => _showMobileSpeedPanel(context),
                                        tooltip: TxaLanguage.t('play_speed'),
                                      ),
                                      if (widget.servers != null && widget.servers!.isNotEmpty) ...[
                                        SizedBox(width: 12 * scale),
                                        IconButton(
                                          icon: Icon(Icons.playlist_play_rounded, color: Colors.white, size: iconSize),
                                          onPressed: _openPlaylistPanel,
                                          tooltip: TxaLanguage.t('episode_list'),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],

                                // TV Help Guideline Hints
                                if (TxaPlatform.isTV) ...[
                                  SizedBox(height: 8 * scale),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildTvKeyHint('\u25c4 \u25ba', TxaLanguage.t('tv_hint_seek')),
                                      const SizedBox(width: 16),
                                      _buildTvKeyHint('\u25b2 \u25bc', TxaLanguage.t('tv_hint_volume')),
                                      const SizedBox(width: 16),
                                      _buildTvKeyHint('OK', TxaLanguage.t('tv_hint_ok')),
                                    ],
                                  ),
                                ]
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                  // 7. FLOATING LOCK BUTTON (Mobile Only)
                  if (!TxaPlatform.isTV && (_showControls || (_isLocked && _showLockButtonOnly)))
                    Positioned(
                      left: 24,
                      top: MediaQuery.of(context).size.height / 2 - 24,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isLocked = !_isLocked;
                            if (!_isLocked) {
                              _showLockButtonOnly = false;
                              _resetHideControlsTimer();
                            } else {
                              _showControls = false;
                              _showLockButtonTemporarily();
                            }
                          });
                          TxaToast.show(context, _isLocked ? TxaLanguage.t('player_locked') : TxaLanguage.t('player_unlocked'));
                        },
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.black54,
                          child: Icon(
                            _isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                            color: _isLocked ? Colors.redAccent : Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

        // 9. SUBTITLES DISPLAY OVERLAY
        // Primary Subtitle (always at bottom)
        if (_subtitleMode != 'off' && _activePrimaryCue != null && !_showAd)
          Positioned(
            bottom: _showControls ? 110 : 40,
            left: 40,
            right: 40,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _activePrimaryCue!.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1)),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),

        // Secondary Subtitle (always at top center, below the top title overlay)
        if (_subtitleMode == 'bilingual' && _activeSecondaryCue != null && !_showAd)
          Positioned(
            top: _showControls ? 110 : 50,
            left: 40,
            right: 40,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _activeSecondaryCue!.text,
                    style: const TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1)),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),

        // 10. SKIP INTRO/OUTRO BUTTON OVERLAY
        if (_isSkipVisible() && !_showAd)
          Positioned(
            bottom: 80,
            right: 100,
            child: GestureDetector(
              onTap: _handleSkipIntroOutro,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF737DFD),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF737DFD).withValues(alpha: 0.4),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.skip_next_rounded, color: Colors.black, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      _position.inSeconds >= widget.timeIntroStart && _position.inSeconds <= widget.timeIntroEnd
                          ? TxaLanguage.t('skip_intro')
                          : TxaLanguage.t('skip_outro'),
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    if (TxaPlatform.isTV) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          "OK",
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

        // 11. TV SUBTITLES MENU OVERLAY
        if (TxaPlatform.isTV && _showTvSubtitlesMenu)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 300,
            child: Container(
              color: Colors.black.withValues(alpha: 0.95),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    TxaLanguage.t('subtitle_settings').toUpperCase(),
                    style: const TextStyle(color: Color(0xFF737DFD), fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _getTvMenuItems().length,
                      itemBuilder: (context, index) {
                        final item = _getTvMenuItems()[index];
                        final isFocused = _tvMenuSelectedIndex == index;
                        final isSection = item['type'] == 'section';

                        if (isSection) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              item['label'],
                              style: const TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          );
                        }

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isFocused ? const Color(0xFF737DFD) : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item['label'],
                            style: TextStyle(
                              color: isFocused ? Colors.black : Colors.white,
                              fontWeight: isFocused ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

        // 12. NEXT EPISODE COUNTDOWN OVERLAY (Mobile Only)
        if (_showNextEpisodeOverlay && widget.nextEpisode != null)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.90),
              child: Center(
                child: Container(
                  width: 480,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2937),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        TxaLanguage.t('next_video_countdown', replace: {'seconds': _nextEpisodeCountdown.toString()}),
                        style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: widget.nextEpisode!['thumb'] != null && widget.nextEpisode!['thumb'].toString().isNotEmpty
                                    ? Image.network(
                                        widget.nextEpisode!['thumb'],
                                        width: 160,
                                        height: 90,
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) => Container(width: 160, height: 90, color: Colors.white10),
                                      )
                                    : Container(width: 160, height: 90, color: Colors.white10),
                              ),
                              Positioned(
                                top: 6,
                                  left: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFFF007F), Color(0xFF7928CA)],
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      widget.nextEpisode!['name'] ?? '',
                                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.nextEpisode!['movieName'] ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    widget.nextEpisode!['name'] ?? '',
                                    style: const TextStyle(color: Color(0xFF737DFD), fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _cancelNextEpisode,
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.white12,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              child: Text(
                                TxaLanguage.t('cancel').toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: _playNextEpisode,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF737DFD),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              child: Text(
                                TxaLanguage.t('play_now').toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 8. MINI BOTTOM PROGRESS BAR (Shown only when controls are hidden)
          if (!_showControls && _isPlayerInitialized && _duration > Duration.zero)
            Positioned(
              left: 10,
              right: 10,
              bottom: 8,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: (_position.inSeconds / _duration.inSeconds).clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF737DFD),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),

          // 13. PLAYLIST SIDE PANEL DRAWER (Mobile & TV)
          if (_showPlaylistPanel && widget.servers != null && widget.servers!.isNotEmpty)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: TxaPlatform.isTV ? 360 : 320,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.98),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 20,
                      spreadRadius: 2,
                    )
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          TxaLanguage.t('playlist_drawer_title'),
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                          onPressed: _closePlaylistPanel,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Server/Source selector if multiple servers exist
                    if (widget.servers!.length > 1) ...[
                      Text(
                        "${TxaLanguage.t('select_server')}:",
                        style: const TextStyle(color: Colors.white30, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 38,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: widget.servers!.length,
                          itemBuilder: (context, idx) {
                            final server = widget.servers![idx];
                            final isSelected = _playlistServerSelectedIndex == idx;
                            return Container(
                              margin: const EdgeInsets.only(right: 8),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _playlistServerSelectedIndex = idx;
                                    _playlistEpisodeSelectedIndex = 0;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFF737DFD) : Colors.white10,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      server['server_name'] ?? 'Server ${idx + 1}',
                                      style: TextStyle(
                                        color: isSelected ? Colors.black : Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
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

                    // Episodes Grid List
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final server = widget.servers![_playlistServerSelectedIndex];
                          final rawEps = server['server_data'] as List? ?? [];
                          final eps = rawEps.where((ep) => ep['is_unreleased'] != true).toList();
                          
                          return GridView.builder(
                            padding: EdgeInsets.zero,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 1.6,
                            ),
                            itemCount: eps.length,
                            itemBuilder: (context, idx) {
                              final ep = eps[idx];
                              final isCurrentPlaying = ep['id']?.toString() == _currentEpisodeId || ep['slug']?.toString() == _currentEpisodeId;
                              final isTvFocused = TxaPlatform.isTV && _playlistEpisodeSelectedIndex == idx;
                              
                              Color bgColor = Colors.white.withValues(alpha: 0.05);
                              Color textColor = Colors.white70;
                              Border? border;

                              if (isCurrentPlaying) {
                                bgColor = const Color(0xFF737DFD).withValues(alpha: 0.2);
                                border = Border.all(color: const Color(0xFF737DFD), width: 1.5);
                                textColor = const Color(0xFF737DFD);
                              }

                              if (isTvFocused) {
                                bgColor = const Color(0xFF737DFD);
                                textColor = Colors.black;
                                border = Border.all(color: Colors.white, width: 2.0);
                              }

                              return InkWell(
                                onTap: () {
                                  _playNewEpisodeInternally(_playlistServerSelectedIndex, ep);
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: bgColor,
                                    borderRadius: BorderRadius.circular(10),
                                    border: border,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    _formatPlaylistEpisodeName(ep['name'] ?? ''),
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );

    // Apply Gestures Listener wrapper for mobile vs keyboard for TV
    if (TxaPlatform.isTV) {
      return Focus(
        focusNode: _tvFocusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          _handleTvKeyEvent(event);
          return KeyEventResult.handled;
        },
        child: playerView,
      );
    } else if (TxaPlatform.isDesktop) {
      // Desktop: click only, no swipe/drag gestures
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _resetHideControlsTimer();
        },
        child: playerView,
      );
    } else {
      // Mobile touch gestures
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!_isLocked) {
            _resetHideControlsTimer();
          } else {
            _showLockButtonTemporarily();
          }
        },
        onDoubleTapDown: (details) {
          if (_isLocked) return;
          final screenWidth = MediaQuery.of(context).size.width;
          final tapX = details.globalPosition.dx;
          if (tapX < screenWidth * 0.35) {
            _seek(-10);
          } else if (tapX > screenWidth * 0.65) {
            _seek(10);
          }
        },
        onVerticalDragUpdate: (details) {
          if (_isLocked) return;
          final screenWidth = MediaQuery.of(context).size.width;
          final dragX = details.globalPosition.dx;
          final delta = -details.delta.dy / 300.0;
          if (dragX < screenWidth * 0.45) {
            _adjustBrightness(delta);
          } else if (dragX > screenWidth * 0.55) {
            _adjustVolume(delta);
          }
        },
        child: playerView,
      );
    }
  }

  // --- Battery Helpers ---
  IconData _getBatteryIcon() {
    if (_isCharging) {
      return Icons.battery_charging_full_rounded;
    }
    if (_batteryLevel >= 95) return Icons.battery_full_rounded;
    if (_batteryLevel >= 80) return Icons.battery_6_bar_rounded;
    if (_batteryLevel >= 65) return Icons.battery_5_bar_rounded;
    if (_batteryLevel >= 50) return Icons.battery_4_bar_rounded;
    if (_batteryLevel >= 35) return Icons.battery_3_bar_rounded;
    if (_batteryLevel >= 20) return Icons.battery_2_bar_rounded;
    if (_batteryLevel >= 10) return Icons.battery_1_bar_rounded;
    return Icons.battery_0_bar_rounded;
  }

  Color _getBatteryColor() {
    if (_isCharging) return const Color(0xFF4CAF50); // Green when charging
    if (_batteryLevel <= 10) return Colors.redAccent;
    if (_batteryLevel <= 20) return Colors.orangeAccent;
    return Colors.white70;
  }

  // --- Desktop Volume Helpers ---
  IconData _getVolumeIcon() {
    if (_volume <= 0) return Icons.volume_off_rounded;
    if (_volume < 0.33) return Icons.volume_mute_rounded;
    if (_volume < 0.66) return Icons.volume_down_rounded;
    return Icons.volume_up_rounded;
  }

  bool _showDesktopVolumeSlider = false;

  Widget _buildDesktopVolumeControl() {
    return MouseRegion(
      onEnter: (_) => setState(() => _showDesktopVolumeSlider = true),
      onExit: (_) => setState(() => _showDesktopVolumeSlider = false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                if (_volume > 0) {
                  _volume = 0;
                } else {
                  _volume = 1.0;
                }
                _controller?.setVolume(_volume);
              });
            },
            child: Icon(_getVolumeIcon(), color: Colors.white, size: 24),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _showDesktopVolumeSlider ? 120 : 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _showDesktopVolumeSlider ? 1.0 : 0.0,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  thumbColor: const Color(0xFF737DFD),
                  activeTrackColor: const Color(0xFF737DFD),
                  inactiveTrackColor: Colors.white24,
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  showValueIndicator: ShowValueIndicator.onDrag,
                ),
                child: Slider(
                  value: _volume,
                  min: 0,
                  max: 1,
                  label: '${(_volume * 100).toInt()}%',
                  onChanged: (val) {
                    setState(() {
                      _volume = val;
                      _controller?.setVolume(_volume);
                    });
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTvKeyHint(String keys, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(keys, style: const TextStyle(color: Color(0xFF737DFD), fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }
}

class TxaSubtitleCue {
  final String id;
  final double startTime; // in seconds
  final double endTime;   // in seconds
  final String text;

  TxaSubtitleCue({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.text,
  });
}
