import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import '../services/txa_language.dart';
import '../services/txa_auth_service.dart';
import '../services/txa_api.dart';
import '../services/txa_ads_service.dart';
import '../utils/txa_platform.dart';
import '../utils/txa_toast.dart';
import '../utils/txa_logger.dart';
import '../utils/txa_format.dart';
import 'txa_player_coachmark.dart';
import '../services/txa_stream_policy_service.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TxaVideoPlayer extends StatefulWidget {
  final String url;
  final String movieName;
  final String episodeName;
  final String serverName;
  final Map<String, dynamic>? adSettings;
  final VoidCallback? onEnded;
  final List<dynamic>? subtitles;
  final String? storyboardUrl;
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
  final String movieId;
  final int startTime;
  final bool packageSystemEnable;
  final String userPlan;

  const TxaVideoPlayer({
    super.key,
    required this.url,
    required this.movieName,
    required this.episodeName,
    required this.serverName,
    this.adSettings,
    this.onEnded,
    this.subtitles,
    this.storyboardUrl,
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
    this.movieId = '',
    this.startTime = 0,
    this.packageSystemEnable = false,
    this.userPlan = 'free',
  });

  @override
  State<TxaVideoPlayer> createState() => _TxaVideoPlayerState();
}

class _TxaVideoPlayerState extends State<TxaVideoPlayer> with WidgetsBindingObserver {
  // Main Player
  VideoPlayerController? _controller;
  bool _isPlayerInitialized = false;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _showControls = true;
  Timer? _hideControlsTimer;
  Timer? _positionSyncTimer;
  DateTime? _lastSavedTime;

  // Desktop Focus & Fullscreen
  final FocusNode _desktopFocusNode = FocusNode();
  bool _isFullscreen = false;
  double _tempVolume = 1.0;

  // Aspect Ratio
  String _aspectRatioMode = 'fit'; // 'fit' | 'fill' | '16_9' | '4_3'

  // Hold to Speed Up 2x
  bool _isHoldingSpeedUp = false;
  double _preHoldingSpeed = 1.0;

  // Player Settings & Dragging States
  bool _autoSkipIntro = false;
  bool _autoNextEpisode = false;
  String _preferredSubLang = 'vi';
  bool _showSettingsPanel = false;
  int _settingsSelectedIndex = 0;
  bool _isDraggingSlider = false;
  bool _nextEpisodeOverlayTriggered = false;
  Map<String, dynamic>? _nextEpisodeData;
  Map<String, dynamic>? _prevEpisodeData;

  // Subtitles States
  String _subtitleMode = 'off'; // 'off' | 'primary' | 'bilingual'
  int _primarySubIdx = 0;
  int _secondarySubIdx = 0;
  List<TxaSubtitleCue> _primaryCues = [];
  List<TxaSubtitleCue> _secondaryCues = [];
  TxaSubtitleCue? _activePrimaryCue;
  TxaSubtitleCue? _activeSecondaryCue;

  // Storyboard States
  List<TxaStoryboardItem> _storyboardItems = [];
  bool _storyboardLoaded = false;
  Timer? _tvStoryboardTimer;
  bool _showTvStoryboardPreview = false;

  // Subtitle custom styling states
  double _subtitleFontSize = 16.0;
  String _subtitleColor = '#FFFFFF';
  String _subtitleBorder = 'shadow'; // 'shadow' | 'stroke' | 'none'
  double _subtitleBgOpacity = 0.0; // 0.0 to 1.0
  String _secondarySubPosition = 'top'; // 'top' | 'bottom'

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

  // Audio Effects settings states
  bool _is3dAudioEnabled = false;
  bool _isAudioOptimizerEnabled = false;
  double _audioBoostLevel = 1.0;

  // TV D-Pad Focus Nodes
  final FocusNode _tvFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _currentServerIndex = widget.initialServerIndex;
    _currentEpisodeId = widget.currentEpisodeId ?? '';
    _currentEpisodeName = widget.episodeName;
    _currentUrl = widget.url;
    _currentServerName = widget.serverName;
    _playlistServerSelectedIndex = _currentServerIndex;
    
    // Keep screen awake
    try {
      WakelockPlus.enable();
    } catch (_) {}

    _updateNextPrevEpisodeData();
    _loadPlayerSettings();

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
    if (widget.storyboardUrl != null && widget.storyboardUrl!.isNotEmpty) {
      _loadStoryboard(widget.storyboardUrl!);
    }
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed || state == AppLifecycleState.inactive) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      if (mounted) {
        setState(() {
          _isHoldingSpeedUp = false;
          _isDraggingSlider = false;
          _showLockButtonOnly = false;
          _showControls = true;
          _isLocked = false;
        });
        _stopSpeedUp2x();
        _resetHideControlsTimer();
        if (TxaPlatform.isTV) {
          _tvFocusNode.requestFocus();
        } else if (TxaPlatform.isDesktop) {
          _desktopFocusNode.requestFocus();
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Reset wake lock
    try {
      WakelockPlus.disable();
    } catch (_) {}

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

    if (TxaPlatform.isDesktop) {
      _desktopFocusNode.dispose();
      TxaPlatform.setFullscreen(false);
    }

    _controller?.dispose();
    _adController?.dispose();
    _adTimer?.cancel();
    _positionSyncTimer?.cancel();
    _hideControlsTimer?.cancel();
    _clockTimer?.cancel();
    _batteryTimer?.cancel();
    _indicatorTimer?.cancel();
    _nextEpisodeTimer?.cancel();
    _lockButtonTimer?.cancel();
    _tvStoryboardTimer?.cancel();
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
    if (TxaPlatform.isWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      await _platformChannel.invokeMethod('enableSecureMode');
      _secureEnabled = true;
    } catch (e) {
      TxaLogger.log('Failed to enable secure mode: $e', type: 'app');
    }
  }

  void _disableSecureMode() async {
    if (TxaPlatform.isWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
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
    // 1. Check VIP bypass_ads status
    final bypass = await TxaAdsService().shouldBypassAds();
    if (bypass) {
      TxaLogger.log('VIP user detected: Bypassing all pre-roll ads.', type: 'app');
      _initMainPlayer();
      return;
    }

    final adSettings = widget.adSettings;
    final bool admobEnable = adSettings?['admob_enable'] == true;

    // 2. Try Google AdMob Pre-Roll first if enabled
    if (admobEnable && (TxaPlatform.isMobile || TxaPlatform.isTV)) {
      bool admobFinished = false;
      await TxaAdsService().showPreRollAd(
        onComplete: () {
          admobFinished = true;
        },
      );
      if (admobFinished && !mounted) return;
    }

    // 3. Fallback to custom web video/embed pre-roll ad if configured
    bool adEnabled = adSettings?['pre_roll_enable'] == true;
    final String? rawAdUrl = adSettings?['pre_roll_url'];

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
      // No custom web ads or finished AdMob
      _initMainPlayer();
    }
  }

  void _initAdPlayer() async {
    if (_adUrl == null) return;
    final bool bypassAdHeaders = _adUrl!.contains('google') ||
        _adUrl!.contains('github') ||
        _adUrl!.contains('mediafire') ||
        _adUrl!.contains('dropbox');

    final headers = (TxaPlatform.isDesktop || TxaPlatform.isWeb || bypassAdHeaders)
        ? const <String, String>{}
        : const {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Referer': '${TxaApi.baseUrl}/',
          };
    _adController = VideoPlayerController.networkUrl(
      Uri.parse(_adUrl!),
      httpHeaders: headers,
      formatHint: _adUrl!.contains('.m3u8') ? VideoFormat.hls : null,
    );
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
    TxaLogger.log('Bắt đầu khởi tạo Main Player. URL: $_currentUrl', type: 'app');

    // 1. Resolve policy URL
    final String resolvedUrl = await TxaStreamPolicyService.resolveStreamUrl(
      _currentUrl,
      packageSystemEnable: widget.packageSystemEnable,
      userPlan: widget.userPlan,
    );

    if (!mounted) return;

    final bool bypassHeaders = resolvedUrl.contains('google') ||
        resolvedUrl.contains('github') ||
        resolvedUrl.contains('mediafire') ||
        resolvedUrl.contains('dropbox');

    final headers = (TxaPlatform.isWeb || bypassHeaders)
        ? const <String, String>{}
        : const {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Referer': '${TxaApi.baseUrl}/',
          };
    TxaLogger.log('Headers cấu hình: $headers', type: 'app');
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(resolvedUrl),
      httpHeaders: headers,
      formatHint: resolvedUrl.contains('.m3u8') ? VideoFormat.hls : null,
    );
    
    try {
      await _controller!.initialize();
      if (!mounted) return;
      TxaLogger.log('Khởi tạo Player thành công. Kích thước: ${_controller!.value.size}, Thời lượng: ${_controller!.value.duration}', type: 'app');

      // Restore volume and playback speed settings
      await _controller!.setVolume(_volume);
      await _controller!.setPlaybackSpeed(_playbackSpeed);
      
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
          if (mounted) {
            TxaToast.show(context, TxaLanguage.t('player_error_stream'), isError: true);
            setState(() {
              _isPlaying = false;
            });
          }
          return;
        }
        
        final dur = _controller!.value.duration;
        if (dur != _duration) {
          setState(() {
            _duration = dur;
          });
        }

        final pos = _controller!.value.position;
        _updateActiveCues(pos);

        final sec = pos.inSeconds;

        // Auto skip intro if enabled
        final hasIntro = widget.timeIntroEnd > widget.timeIntroStart && widget.timeIntroEnd > 0;
        if (_autoSkipIntro && hasIntro && sec >= widget.timeIntroStart && sec < widget.timeIntroEnd) {
          _controller!.seekTo(Duration(seconds: widget.timeIntroEnd));
          TxaToast.show(context, TxaLanguage.t('intro_skipped'));
          return;
        }

        // Trigger next episode overlay 5 seconds before outro start (or video end) if enabled
        if (_autoNextEpisode && _nextEpisodeData != null && !_nextEpisodeOverlayTriggered) {
          final outroStart = widget.timeOutroStart;
          final hasOutro = widget.timeOutroEnd > widget.timeOutroStart && widget.timeOutroEnd > 0;
          final triggerTime = hasOutro ? outroStart - 5 : _duration.inSeconds - 5;
          if (triggerTime > 0 && sec >= triggerTime) {
            _nextEpisodeOverlayTriggered = true;
            setState(() {
              _showNextEpisodeOverlay = true;
              _nextEpisodeCountdown = 5;
            });
            _startNextEpisodeCountdown();
          }
        }

        if (!_isDraggingSlider) {
          setState(() {
            _position = pos;
            if (_controller!.value.position >= dur &&
                dur > Duration.zero &&
                _isPlaying) {
              _isPlaying = false;
              _handleVideoEnded();
            }
          });
        } else {
          if (_controller!.value.position >= dur &&
              dur > Duration.zero &&
              _isPlaying) {
            setState(() {
              _isPlaying = false;
              _handleVideoEnded();
            });
          }
        }

        // Save progress dynamically every 10 seconds
        final now = DateTime.now();
        if (_lastSavedTime == null || now.difference(_lastSavedTime!).inSeconds >= 10) {
          _lastSavedTime = now;
          _saveWatchProgress();
        }
      });

      // Start periodic position & duration sync timer (crucial for Desktop/Windows MediaKit sync)
      _positionSyncTimer?.cancel();
      _positionSyncTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
        if (!mounted || _controller == null || !_isPlayerInitialized) return;

        final val = _controller!.value;
        final dur = val.duration;
        final pos = val.position;

        bool needStateUpdate = false;

        if (dur > Duration.zero && dur != _duration) {
          _duration = dur;
          needStateUpdate = true;
        }

        if (!_isDraggingSlider && pos != _position) {
          _position = pos;
          _updateActiveCues(pos);
          needStateUpdate = true;
        }

        if (needStateUpdate && mounted) {
          setState(() {});
        }
      });

      _resetHideControlsTimer();
      if (TxaPlatform.isTV) {
        _tvFocusNode.requestFocus();
      }
    } catch (e) {
      TxaLogger.log('Main player initialize error: $e. URL: $_currentUrl', type: 'crash');
      if (mounted) {
        TxaToast.show(context, TxaLanguage.t('player_error_stream'), isError: true);
      }
    }
  }

  void _saveWatchProgress() async {
    final auth = TxaAuthService();
    if (!auth.isLoggedIn || widget.movieId.isEmpty) return;

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

  // --- PLAYER SETTINGS & EPISODE HELPERS ---
  Future<void> _loadPlayerSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _autoSkipIntro = prefs.getBool('auto_skip_intro') ?? false;
        _autoNextEpisode = prefs.getBool('auto_next_episode') ?? false;
        _preferredSubLang = prefs.getString('preferred_sub_lang') ?? 'vi';
        _subtitleFontSize = prefs.getDouble('subtitle_font_size') ?? 16.0;
        _subtitleColor = prefs.getString('subtitle_color') ?? '#FFFFFF';
        _subtitleBorder = prefs.getString('subtitle_border') ?? 'shadow';
        _subtitleBgOpacity = prefs.getDouble('subtitle_bg_opacity') ?? 0.0;
        _secondarySubPosition = prefs.getString('secondary_sub_position') ?? 'top';
        
        // Load audio effects settings
        _is3dAudioEnabled = prefs.getBool('audio_3d_enabled') ?? false;
        _isAudioOptimizerEnabled = prefs.getBool('audio_optimize_enabled') ?? false;
        _audioBoostLevel = prefs.getDouble('audio_boost_level') ?? 1.0;
      });
      _applyPreferredSubtitle();
      _applyAudioEffects();
    } catch (_) {}
  }

  void _applyAudioEffects() async {
    if (TxaPlatform.isMobile) {
      try {
        await _platformChannel.invokeMethod('set3DAudioEnabled', {'enabled': _is3dAudioEnabled});
        await _platformChannel.invokeMethod('setAudioOptimizeEnabled', {'enabled': _isAudioOptimizerEnabled});
        await _platformChannel.invokeMethod('setAudioBoostLevel', {'level': _audioBoostLevel});
      } catch (e) {
        TxaLogger.log('Failed to apply native audio effects: $e', type: 'app');
      }
    }
  }

  Future<void> _setPlayerSetting(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      }
      await _loadPlayerSettings();
    } catch (_) {}
  }

  void _applyPreferredSubtitle() {
    final subs = widget.subtitles ?? [];
    if (subs.isEmpty) return;
    
    int targetIndex = -1;
    for (int i = 0; i < subs.length; i++) {
      final sub = subs[i];
      final label = (sub['label'] ?? '').toString().toLowerCase();
      final fileUrl = (sub['file'] ?? '').toString().toLowerCase();
      
      if (_preferredSubLang == 'vi' && (label.contains('việt') || label.contains('viet') || fileUrl.contains('/vie') || fileUrl.contains('/vi'))) {
        targetIndex = i;
        break;
      } else if (_preferredSubLang == 'en' && (label.contains('anh') || label.contains('english') || label.contains('engsub') || fileUrl.contains('/eng') || fileUrl.contains('/en'))) {
        targetIndex = i;
        break;
      } else if (_preferredSubLang == 'zh' && (label.contains('trung') || label.contains('china') || label.contains('chinese') || fileUrl.contains('/chi') || fileUrl.contains('/zh'))) {
        targetIndex = i;
        break;
      }
    }
    
    if (targetIndex != -1) {
      setState(() {
        _primarySubIdx = targetIndex;
        _subtitleMode = 'primary';
        _secondaryCues = [];
        _activeSecondaryCue = null;
      });
      _loadSubtitleTrack(targetIndex, true);
    }
  }

  Map<String, dynamic>? _getNextEpisode() {
    if (widget.servers == null || widget.servers!.isEmpty) return null;
    if (_currentServerIndex >= widget.servers!.length) return null;
    
    final server = widget.servers![_currentServerIndex];
    final rawEps = server['server_data'] as List? ?? [];
    final eps = rawEps.where((ep) => ep['is_unreleased'] != true).toList();
    
    int currentIdx = eps.indexWhere((ep) => ep['id']?.toString() == _currentEpisodeId || ep['slug']?.toString() == _currentEpisodeId);
    if (currentIdx != -1 && currentIdx + 1 < eps.length) {
      final nextEp = eps[currentIdx + 1];
      return {
        'id': nextEp['id']?.toString() ?? nextEp['slug']?.toString(),
        'name': nextEp['name'] ?? 'Tập tiếp theo',
        'movieName': widget.movieName,
        'thumb': nextEp['thumb'] ?? nextEp['still_path'] ?? nextEp['thumb_url'] ?? '',
        'ep': nextEp
      };
    }
    return null;
  }

  Map<String, dynamic>? _getPrevEpisode() {
    if (widget.servers == null || widget.servers!.isEmpty) return null;
    if (_currentServerIndex >= widget.servers!.length) return null;
    
    final server = widget.servers![_currentServerIndex];
    final rawEps = server['server_data'] as List? ?? [];
    final eps = rawEps.where((ep) => ep['is_unreleased'] != true).toList();
    
    int currentIdx = eps.indexWhere((ep) => ep['id']?.toString() == _currentEpisodeId || ep['slug']?.toString() == _currentEpisodeId);
    if (currentIdx > 0 && currentIdx < eps.length) {
      final prevEp = eps[currentIdx - 1];
      return {
        'id': prevEp['id']?.toString() ?? prevEp['slug']?.toString(),
        'name': prevEp['name'] ?? 'Tập trước',
        'movieName': widget.movieName,
        'thumb': prevEp['thumb'] ?? prevEp['still_path'] ?? prevEp['thumb_url'] ?? '',
        'ep': prevEp
      };
    }
    return null;
  }

  void _updateNextPrevEpisodeData() {
    setState(() {
      _nextEpisodeData = _getNextEpisode();
      _prevEpisodeData = _getPrevEpisode();
    });
  }

  void _playNextEpisode() {
    _nextEpisodeTimer?.cancel();
    final next = _getNextEpisode();
    if (next != null && next['ep'] != null) {
      _playNewEpisodeInternally(_currentServerIndex, next['ep']);
    } else if (widget.onPlayNext != null) {
      widget.onPlayNext!();
    }
  }

  void _playPrevEpisode() {
    final prev = _getPrevEpisode();
    if (prev != null && prev['ep'] != null) {
      _playNewEpisodeInternally(_currentServerIndex, prev['ep']);
    } else if (widget.onPlayPrev != null) {
      widget.onPlayPrev!();
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

  Future<void> _loadStoryboard(String url) async {
    if (url.isEmpty) return;
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final text = utf8.decode(response.bodyBytes, allowMalformed: true);
        final lines = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
        final List<TxaStoryboardItem> items = [];
        final timeRegex = RegExp(
          r'(\d{2}):(\d{2}):(\d{2})[.,](\d{3})\s*-->\s*(\d{2}):(\d{2}):(\d{2})[.,](\d{3})'
        );
        final timeRegexShort = RegExp(
          r'(\d{2}):(\d{2})[.,](\d{3})\s*-->\s*(\d{2}):(\d{2})[.,](\d{3})'
        );

        for (int i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.contains('-->')) {
            double startTime = 0;
            double endTime = 0;
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
            } else {
              final matchShort = timeRegexShort.firstMatch(line);
              if (matchShort != null) {
                startTime = double.parse(matchShort.group(1)!) * 60 +
                    double.parse(matchShort.group(2)!) +
                    double.parse(matchShort.group(3)!) / 1000.0;
                endTime = double.parse(matchShort.group(4)!) * 60 +
                    double.parse(matchShort.group(5)!) +
                    double.parse(matchShort.group(6)!) / 1000.0;
              }
            }

            if (i + 1 < lines.length) {
              final nextLine = lines[i + 1].trim();
              if (nextLine.isNotEmpty) {
                final hashIdx = nextLine.indexOf('#');
                if (hashIdx != -1) {
                  final imgPath = nextLine.substring(0, hashIdx);
                  final xywhStr = nextLine.substring(hashIdx + 1).replaceAll('xywh=', '');
                  final coords = xywhStr.split(',').map((c) {
                    final cleanC = c.trim();
                    return int.tryParse(cleanC) ?? 0;
                  }).toList();
                  if (coords.length == 4) {
                    String imgUrl = imgPath;
                    if (!imgPath.startsWith('http') && !imgPath.startsWith('/')) {
                      final baseUri = Uri.parse(url);
                      imgUrl = baseUri.resolve(imgPath).toString();
                    }
                    items.add(TxaStoryboardItem(
                      startTime: startTime,
                      endTime: endTime,
                      imgUrl: imgUrl,
                      x: coords[0],
                      y: coords[1],
                      w: coords[2],
                      h: coords[3],
                    ));
                  }
                }
              }
            }
          }
        }

        if (mounted) {
          setState(() {
            _storyboardItems = items;
            _storyboardLoaded = true;
          });
        }
      }
    } catch (e) {
      TxaLogger.log("Lỗi tải storyboard: $e", type: 'crash');
    }
  }

  TxaStoryboardItem? _getStoryboardItem(double time) {
    if (_storyboardItems.isEmpty) return null;
    int low = 0;
    int high = _storyboardItems.length - 1;
    while (low <= high) {
      int mid = (low + high) >> 1;
      final item = _storyboardItems[mid];
      if (time >= item.startTime && time <= item.endTime) {
        return item;
      } else if (time < item.startTime) {
        high = mid - 1;
      } else {
        low = mid + 1;
      }
    }
    return null;
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

    // Aspect Ratio section for TV settings menu
    items.add({
      'type': 'section',
      'label': TxaLanguage.currentLang == 'vi' ? 'TỈ LỆ KHUNG HÌNH' : 'ASPECT RATIO',
    });
    final aspectModes = [
      {'id': 'fit', 'label': TxaLanguage.currentLang == 'vi' ? 'Bản gốc (Fit)' : 'Original (Fit)'},
      {'id': 'fill', 'label': TxaLanguage.currentLang == 'vi' ? 'Tràn màn hình (Fill)' : 'Stretch (Fill)'},
      {'id': '16_9', 'label': '16:9'},
      {'id': '4_3', 'label': '4:3'},
    ];
    for (final m in aspectModes) {
      final isSelected = _aspectRatioMode == m['id'];
      items.add({
        'type': 'aspect_ratio_mode',
        'value': m['id'],
        'label': "${m['label']}${isSelected ? TxaLanguage.t('currently_selected') : ''}",
        'selected': isSelected,
      });
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
    if (_prevEpisodeData != null || _nextEpisodeData != null) {
      items.add({
        'type': 'section',
        'label': TxaLanguage.t('switch_episode'),
      });
      if (_prevEpisodeData != null) {
        items.add({
          'type': 'play_prev',
          'label': TxaLanguage.t('prev_episode_label', replace: {'name': _prevEpisodeData!['name'] ?? ''}),
        });
      }
      if (_nextEpisodeData != null) {
        items.add({
          'type': 'play_next',
          'label': TxaLanguage.t('next_episode_label', replace: {'name': _nextEpisodeData!['name'] ?? ''}),
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
      case 'aspect_ratio_mode':
        setState(() {
          _aspectRatioMode = item['value'];
        });
        break;
      case 'speed_rate':
        _setPlaybackSpeed(item['value']);
        break;
      case 'play_prev':
        _playPrevEpisode();
        break;
      case 'play_next':
        _playNextEpisode();
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
    if (_nextEpisodeData != null) {
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
          _showNextEpisodeOverlay = false;
          _playNextEpisode();
        }
      });
    });
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
      _nextEpisodeOverlayTriggered = false;
      
      _primaryCues = [];
      _secondaryCues = [];
      _activePrimaryCue = null;
      _activeSecondaryCue = null;
      _storyboardItems = [];
      _storyboardLoaded = false;
      _showTvStoryboardPreview = false;
      _tvStoryboardTimer?.cancel();
    });
    
    final storyboard = ep['storyboardUrl'] ?? ep['storyboard_url'];
    if (storyboard != null && storyboard.toString().isNotEmpty) {
      _loadStoryboard(storyboard.toString());
    }

    _updateNextPrevEpisodeData();

    final subs = ep['subtitles'] ?? ep['subtitles_data'];
    if (subs != null && subs is List && subs.isNotEmpty) {
      int targetIndex = -1;
      for (int i = 0; i < subs.length; i++) {
        final sub = subs[i];
        final label = (sub['label'] ?? '').toString().toLowerCase();
        final fileUrl = (sub['file'] ?? '').toString().toLowerCase();
        
        if (_preferredSubLang == 'vi' && (label.contains('việt') || label.contains('viet') || fileUrl.contains('/vie') || fileUrl.contains('/vi'))) {
          targetIndex = i;
          break;
        } else if (_preferredSubLang == 'en' && (label.contains('anh') || label.contains('english') || label.contains('engsub') || fileUrl.contains('/eng') || fileUrl.contains('/en'))) {
          targetIndex = i;
          break;
        } else if (_preferredSubLang == 'zh' && (label.contains('trung') || label.contains('china') || label.contains('chinese') || fileUrl.contains('/chi') || fileUrl.contains('/zh'))) {
          targetIndex = i;
          break;
        }
      }

      if (targetIndex == -1) targetIndex = 0;

      setState(() {
        _primarySubIdx = targetIndex;
        _subtitleMode = 'primary';
      });
      _loadSubtitleTrack(targetIndex, true);
    } else {
      setState(() {
        _subtitleMode = 'off';
      });
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

  Widget _buildSettingsToggleItem({
    required int index,
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isFocused = TxaPlatform.isTV && _settingsSelectedIndex == index;
    return InkWell(
      onTap: () {
        onChanged(!value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isFocused ? const Color(0xFF737DFD).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isFocused ? const Color(0xFF737DFD) : Colors.white12,
            width: isFocused ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: isFocused ? const Color(0xFF737DFD) : Colors.white70, size: 18),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    color: isFocused ? const Color(0xFF737DFD) : Colors.white,
                    fontSize: 12,
                    fontWeight: isFocused ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
            Switch(
              value: value,
              activeThumbColor: const Color(0xFF737DFD),
              activeTrackColor: const Color(0xFF737DFD).withValues(alpha: 0.5),
              inactiveThumbColor: Colors.grey,
              inactiveTrackColor: Colors.white24,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsRadioItem({
    required int index,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isFocused = TxaPlatform.isTV && _settingsSelectedIndex == index;
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isFocused
              ? const Color(0xFF737DFD).withValues(alpha: 0.15)
              : (isSelected ? const Color(0xFF737DFD).withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.02)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isFocused
                ? const Color(0xFF737DFD)
                : (isSelected ? const Color(0xFF737DFD).withValues(alpha: 0.3) : Colors.white12),
            width: isFocused ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                color: isSelected ? const Color(0xFF737DFD) : Colors.white,
                fontSize: 12,
                fontWeight: isSelected || isFocused ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (isSelected)
              const Icon(Icons.radio_button_checked_rounded, color: Color(0xFF737DFD), size: 18)
            else
              const Icon(Icons.radio_button_off_rounded, color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }

  // --- Subtitle customization options lists ---
  final List<double> _fontSizes = const [12.0, 14.0, 16.0, 18.0, 20.0, 22.0, 24.0];
  final List<Map<String, String>> _colors = const [
    {'name': 'sub_color_white', 'value': '#FFFFFF'},
    {'name': 'sub_color_yellow', 'value': '#FFFF00'},
    {'name': 'sub_color_green', 'value': '#00FF00'},
    {'name': 'sub_color_blue', 'value': '#00FFFF'}
  ];
  final List<Map<String, String>> _borders = const [
    {'name': 'sub_border_shadow', 'value': 'shadow'},
    {'name': 'sub_border_stroke', 'value': 'stroke'},
    {'name': 'sub_border_none', 'value': 'none'}
  ];
  final List<Map<String, dynamic>> _bgOpacities = const [
    {'name': '0%', 'value': 0.0},
    {'name': '25%', 'value': 0.25},
    {'name': '50%', 'value': 0.50},
    {'name': '75%', 'value': 0.75}
  ];
  final List<Map<String, String>> _positions = const [
    {'name': 'sub_pos_top', 'value': 'top'},
    {'name': 'sub_pos_bottom', 'value': 'bottom'}
  ];

  void _cycleSettingsOption(bool forward) {
    if (_settingsSelectedIndex == 5) {
      final currentIdx = _fontSizes.indexOf(_subtitleFontSize);
      if (currentIdx != -1) {
        final nextIdx = (currentIdx + (forward ? 1 : -1)) % _fontSizes.length;
        _setPlayerSetting('subtitle_font_size', _fontSizes[nextIdx]);
      }
    } else if (_settingsSelectedIndex == 6) {
      final currentIdx = _colors.indexWhere((c) => c['value'] == _subtitleColor);
      if (currentIdx != -1) {
        final nextIdx = (currentIdx + (forward ? 1 : -1)) % _colors.length;
        _setPlayerSetting('subtitle_color', _colors[nextIdx]['value']!);
      }
    } else if (_settingsSelectedIndex == 7) {
      final currentIdx = _borders.indexWhere((b) => b['value'] == _subtitleBorder);
      if (currentIdx != -1) {
        final nextIdx = (currentIdx + (forward ? 1 : -1)) % _borders.length;
        _setPlayerSetting('subtitle_border', _borders[nextIdx]['value']!);
      }
    } else if (_settingsSelectedIndex == 8) {
      final currentIdx = _bgOpacities.indexWhere((b) => b['value'] == _subtitleBgOpacity);
      if (currentIdx != -1) {
        final nextIdx = (currentIdx + (forward ? 1 : -1)) % _bgOpacities.length;
        _setPlayerSetting('subtitle_bg_opacity', _bgOpacities[nextIdx]['value'] as double);
      }
    } else if (_settingsSelectedIndex == 9) {
      final currentIdx = _positions.indexWhere((p) => p['value'] == _secondarySubPosition);
      if (currentIdx != -1) {
        final nextIdx = (currentIdx + (forward ? 1 : -1)) % _positions.length;
        _setPlayerSetting('secondary_sub_position', _positions[nextIdx]['value']!);
      }
    } else if (_settingsSelectedIndex == 12) {
      final list = [1.0, 1.5, 2.0, 2.5, 3.0];
      final currentIdx = list.indexOf(_audioBoostLevel);
      if (currentIdx != -1) {
        final nextIdx = (currentIdx + (forward ? 1 : -1)) % list.length;
        _setPlayerSetting('audio_boost_level', list[nextIdx]);
        _applyAudioEffects();
      }
    }
  }

  Widget _buildSettingsHorizontalOptionsRow({
    required int index,
    required String title,
    required List<Widget> items,
  }) {
    final isFocused = TxaPlatform.isTV && _settingsSelectedIndex == index;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isFocused
            ? const Color(0xFF737DFD).withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.01),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isFocused ? const Color(0xFF737DFD) : Colors.white12,
          width: isFocused ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isFocused ? const Color(0xFF737DFD) : Colors.white60,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: items,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionBtn<T>({
    required String label,
    required T value,
    required T currentValue,
    required ValueChanged<T> onTap,
  }) {
    final isSelected = value == currentValue;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF737DFD) : Colors.white12,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.bold,
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

    final currentPos = _controller!.value.position > Duration.zero ? _controller!.value.position : _position;
    final currentDur = _controller!.value.duration > Duration.zero ? _controller!.value.duration : _duration;

    final newPos = currentPos + Duration(seconds: seconds);
    Duration clamped = newPos < Duration.zero ? Duration.zero : newPos;

    if (currentDur > Duration.zero && clamped > currentDur) {
      clamped = currentDur;
    }

    _controller!.seekTo(clamped);
    setState(() {
      _position = clamped;
      if (currentDur > Duration.zero) {
        _duration = currentDur;
      }
    });
    _resetHideControlsTimer();
    _triggerTvStoryboardPreview();
  }

  void _triggerTvStoryboardPreview() {
    if (_storyboardItems.isEmpty) return;
    _tvStoryboardTimer?.cancel();
    setState(() {
      _showTvStoryboardPreview = true;
    });
    _tvStoryboardTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _showTvStoryboardPreview = false;
        });
      }
    });
  }

  void _resetHideControlsTimer({int durationMs = 2500}) {
    _hideControlsTimer?.cancel();
    if (!mounted) return;

    if (!_showControls) {
      setState(() {
        _showControls = true;
      });
    }

    if (_isPlaying && !_showSettingsPanel && !_showPlaylistPanel && !_showTvSubtitlesMenu && !_isDraggingSlider) {
      _hideControlsTimer = Timer(Duration(milliseconds: durationMs), () {
        if (mounted &&
            _isPlaying &&
            !_showSettingsPanel &&
            !_showPlaylistPanel &&
            !_showTvSubtitlesMenu &&
            !_isDraggingSlider) {
          setState(() {
            _showControls = false;
          });
        }
      });
    }
  }

  void _toggleControls() {
    if (_isLocked) {
      _showLockButtonTemporarily();
      return;
    }

    if (_showControls) {
      _hideControlsTimer?.cancel();
      setState(() {
        _showSettingsPanel = false;
        _showPlaylistPanel = false;
        _showTvSubtitlesMenu = false;
        _showControls = false;
      });
    } else {
      _resetHideControlsTimer(durationMs: 2500);
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

  // --- Desktop Fullscreen & Keyboard Handlers ---
  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
    TxaPlatform.setFullscreen(_isFullscreen);
  }

  void _startSpeedUp2x() {
    if (_controller == null || !_isPlayerInitialized) return;
    setState(() {
      _preHoldingSpeed = _playbackSpeed;
      _playbackSpeed = 2.0;
      _isHoldingSpeedUp = true;
    });
    _controller!.setPlaybackSpeed(2.0);
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  void _stopSpeedUp2x() {
    if (!_isHoldingSpeedUp) return;
    if (_controller == null || !_isPlayerInitialized) return;
    setState(() {
      _playbackSpeed = _preHoldingSpeed;
      _isHoldingSpeedUp = false;
    });
    _controller!.setPlaybackSpeed(_preHoldingSpeed);
  }

  void _toggleMute() {
    if (_controller == null || !_isPlayerInitialized) return;
    if (_volume > 0.0) {
      _tempVolume = _volume;
      _volume = 0.0;
      _controller!.setVolume(0.0);
      TxaToast.show(context, TxaLanguage.currentLang == 'vi' ? 'Đã tắt tiếng' : 'Muted');
    } else {
      _volume = _tempVolume > 0.0 ? _tempVolume : 1.0;
      _controller!.setVolume(_volume);
      TxaToast.show(context, "${TxaLanguage.currentLang == 'vi' ? 'Âm lượng' : 'Volume'}: ${(_volume * 100).toInt()}%");
    }
    setState(() {});
  }

  void _handleDesktopKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    _resetHideControlsTimer();

    final logicalKey = event.logicalKey;

    if (logicalKey == LogicalKeyboardKey.space || logicalKey == LogicalKeyboardKey.enter) {
      if (_isSkipVisible()) {
        _handleSkipIntroOutro();
      } else {
        _togglePlayPause();
      }
    } else if (logicalKey == LogicalKeyboardKey.arrowRight) {
      _seek(10);
    } else if (logicalKey == LogicalKeyboardKey.arrowLeft) {
      _seek(-10);
    } else if (logicalKey == LogicalKeyboardKey.arrowUp) {
      _adjustVolume(0.05);
    } else if (logicalKey == LogicalKeyboardKey.arrowDown) {
      _adjustVolume(-0.05);
    } else if (logicalKey == LogicalKeyboardKey.keyF) {
      _toggleFullscreen();
    } else if (logicalKey == LogicalKeyboardKey.keyM) {
      _toggleMute();
    } else if (logicalKey == LogicalKeyboardKey.escape) {
      if (_showSettingsPanel) {
        setState(() {
          _showSettingsPanel = false;
        });
      } else if (_showPlaylistPanel) {
        _closePlaylistPanel();
      }
    }
  }

  // --- Aspect Ratio selection bottom sheet ---
  void _showMobileAspectRatioPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final modes = [
          {'id': 'fit', 'label': TxaLanguage.currentLang == 'vi' ? 'Bản gốc (Fit)' : 'Original (Fit)'},
          {'id': 'fill', 'label': TxaLanguage.currentLang == 'vi' ? 'Tràn màn hình (Fill)' : 'Stretch (Fill)'},
          {'id': '16_9', 'label': '16:9'},
          {'id': '4_3', 'label': '4:3'},
        ];
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  TxaLanguage.currentLang == 'vi' ? 'Tỉ lệ khung hình' : 'Aspect Ratio',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: modes.length,
                  itemBuilder: (c, idx) {
                    final m = modes[idx];
                    final isSelected = _aspectRatioMode == m['id'];
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _aspectRatioMode = m['id']!;
                        });
                        Navigator.pop(ctx);
                        TxaToast.show(context, "${TxaLanguage.currentLang == 'vi' ? 'Tỉ lệ' : 'Aspect ratio'}: ${m['label']}");
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              m['label']!,
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

  // --- Smart TV Key Handler ---
  void _handleTvKeyEvent(KeyEvent event) {
    _resetHideControlsTimer();
    
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final logicalKey = event.logicalKey;
      
      if (_showSettingsPanel) {
        if (logicalKey == LogicalKeyboardKey.arrowUp) {
          setState(() {
            if (_settingsSelectedIndex > 0) {
              _settingsSelectedIndex--;
            }
          });
        } else if (logicalKey == LogicalKeyboardKey.arrowDown) {
          setState(() {
            if (_settingsSelectedIndex < 9) {
              _settingsSelectedIndex++;
            }
          });
        } else if (logicalKey == LogicalKeyboardKey.arrowLeft) {
          _cycleSettingsOption(false);
        } else if (logicalKey == LogicalKeyboardKey.arrowRight) {
          _cycleSettingsOption(true);
        } else if (logicalKey == LogicalKeyboardKey.select ||
                   logicalKey == LogicalKeyboardKey.enter ||
                   logicalKey == LogicalKeyboardKey.gameButtonSelect) {
          if (_settingsSelectedIndex == 0) {
            _setPlayerSetting('auto_skip_intro', !_autoSkipIntro);
          } else if (_settingsSelectedIndex == 1) {
            _setPlayerSetting('auto_next_episode', !_autoNextEpisode);
          } else if (_settingsSelectedIndex == 2) {
            _setPlayerSetting('preferred_sub_lang', 'vi');
          } else if (_settingsSelectedIndex == 3) {
            _setPlayerSetting('preferred_sub_lang', 'en');
          } else if (_settingsSelectedIndex == 4) {
            _setPlayerSetting('preferred_sub_lang', 'zh');
          }
        } else if (logicalKey == LogicalKeyboardKey.escape ||
                   logicalKey == LogicalKeyboardKey.goBack) {
          setState(() {
            _showSettingsPanel = false;
          });
        }
        return;
      }

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

  Widget _buildVideoWidget() {
    if (!_isPlayerInitialized || _controller == null) {
      return const SizedBox.shrink();
    }

    Widget video = VideoPlayer(_controller!);

    switch (_aspectRatioMode) {
      case 'fill':
        return FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(
            width: _controller!.value.size.width > 0 ? _controller!.value.size.width : 1920,
            height: _controller!.value.size.height > 0 ? _controller!.value.size.height : 1080,
            child: video,
          ),
        );
      case '16_9':
        return Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: video,
          ),
        );
      case '4_3':
        return Center(
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: video,
          ),
        );
      case 'fit':
      default:
        return Center(
          child: AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: video,
          ),
        );
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
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleControls,
                onLongPressStart: (_) => _startSpeedUp2x(),
                onLongPressEnd: (_) => _stopSpeedUp2x(),
                child: _buildVideoWidget(),
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

          // Speed Up HUD feedback notification
          if (_isHoldingSpeedUp)
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF737DFD).withValues(alpha: 0.5), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.fast_forward_rounded, color: Color(0xFF737DFD), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          TxaLanguage.t('player_fast_forward_2x'),
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
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
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _toggleControls,
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
                          if (_prevEpisodeData != null) ...[
                            IconButton(
                              icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 32),
                              onPressed: _playPrevEpisode,
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
                          if (_nextEpisodeData != null) ...[
                            const SizedBox(width: 16),
                            IconButton(
                              icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 32),
                              onPressed: _playNextEpisode,
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
                                          final percent = _duration > Duration.zero ? (_position.inSeconds / _duration.inSeconds).clamp(0.0, 1.0) : 0.0;
                                          final thumbX = 24 + percent * (sliderWidth - 48);
                                          final previewItem = _storyboardLoaded && (_isDraggingSlider || _showTvStoryboardPreview)
                                              ? _getStoryboardItem(_position.inSeconds.toDouble())
                                              : null;

                                          return Stack(
                                            clipBehavior: Clip.none,
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
                                                   value: _duration > Duration.zero ? _position.inSeconds.toDouble().clamp(0.0, _duration.inSeconds.toDouble()) : 0.0,
                                                   max: _duration > Duration.zero ? _duration.inSeconds.toDouble() : 1.0,
                                                   onChangeStart: (val) {
                                                     setState(() {
                                                       _isDraggingSlider = true;
                                                     });
                                                   },
                                                   onChanged: (val) {
                                                     setState(() {
                                                       _position = Duration(seconds: val.toInt());
                                                     });
                                                   },
                                                   onChangeEnd: (val) {
                                                     if (_controller != null) {
                                                       _controller!.seekTo(Duration(seconds: val.toInt()));
                                                     }
                                                     setState(() {
                                                       _isDraggingSlider = false;
                                                     });
                                                   },
                                                 ),
                                              ),
                                              // Storyboard Preview
                                              if (previewItem != null)
                                                Positioned(
                                                  bottom: 24,
                                                  left: (thumbX - 80).clamp(0.0, sliderWidth - 160),
                                                  child: Container(
                                                    width: 160,
                                                    height: 110,
                                                    decoration: BoxDecoration(
                                                      color: Colors.black.withValues(alpha: 0.95),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: const Color(0xFF737DFD), width: 1.5),
                                                      boxShadow: const [
                                                        BoxShadow(color: Colors.black54, blurRadius: 8)
                                                      ],
                                                    ),
                                                    child: Column(
                                                      children: [
                                                        ClipRRect(
                                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                                          child: Container(
                                                            width: 160,
                                                            height: 90,
                                                            clipBehavior: Clip.hardEdge,
                                                            decoration: const BoxDecoration(color: Colors.black),
                                                            child: Stack(
                                                              children: [
                                                                Positioned(
                                                                  left: -previewItem.x.toDouble(),
                                                                  top: -previewItem.y.toDouble(),
                                                                  child: Image.network(
                                                                    previewItem.imgUrl,
                                                                    fit: BoxFit.none,
                                                                    alignment: Alignment.topLeft,
                                                                    errorBuilder: (c, e, s) => Container(
                                                                      width: 160,
                                                                      height: 90,
                                                                      color: Colors.black,
                                                                      child: const Icon(Icons.broken_image, color: Colors.white24, size: 24),
                                                                    ),
                                                                  ),
                                                                )
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                        Container(
                                                          height: 17,
                                                          alignment: Alignment.center,
                                                          child: Text(
                                                            _formatDuration(_position),
                                                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
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
                                      SizedBox(width: 8 * scale),
                                      IconButton(
                                        icon: Icon(Icons.aspect_ratio_rounded, color: Colors.white, size: iconSize - 2),
                                        onPressed: () => _showMobileAspectRatioPanel(context),
                                        tooltip: TxaLanguage.currentLang == 'vi' ? 'Tỉ lệ khung hình' : 'Aspect Ratio',
                                      ),
                                      if (widget.servers != null && widget.servers!.isNotEmpty) ...[
                                        SizedBox(width: 8 * scale),
                                        IconButton(
                                          icon: Icon(Icons.playlist_play_rounded, color: Colors.white, size: iconSize),
                                          onPressed: _openPlaylistPanel,
                                          tooltip: TxaLanguage.t('episode_list'),
                                        ),
                                      ],
                                      SizedBox(width: 8 * scale),
                                      IconButton(
                                        icon: Icon(Icons.settings_rounded, color: Colors.white, size: iconSize - 2),
                                        onPressed: () {
                                          setState(() {
                                            _showSettingsPanel = !_showSettingsPanel;
                                            _showPlaylistPanel = false;
                                          });
                                        },
                                        tooltip: TxaLanguage.t('settings'),
                                      ),
                                    ],
                                  ),
                                ],

                                // TV / Desktop: full play controls row (existing layout)
                                if (!TxaPlatform.isMobile) ...[
                                  SizedBox(height: 8 * scale),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                       if (_prevEpisodeData != null) ...[
                                        IconButton(
                                          icon: Icon(Icons.skip_previous_rounded, color: Colors.white, size: iconSize + 2),
                                          onPressed: _playPrevEpisode,
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
                                      if (_nextEpisodeData != null) ...[
                                        SizedBox(width: 8 * scale),
                                        IconButton(
                                          icon: Icon(Icons.skip_next_rounded, color: Colors.white, size: iconSize + 2),
                                          onPressed: _playNextEpisode,
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
                                      SizedBox(width: 12 * scale),
                                      IconButton(
                                        icon: Icon(Icons.aspect_ratio_rounded, color: Colors.white, size: iconSize - 2),
                                        onPressed: () => _showMobileAspectRatioPanel(context),
                                        tooltip: TxaLanguage.currentLang == 'vi' ? 'Tỉ lệ khung hình' : 'Aspect Ratio',
                                      ),
                                      if (TxaPlatform.isDesktop) ...[
                                        SizedBox(width: 12 * scale),
                                        IconButton(
                                          icon: Icon(_isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded, color: Colors.white, size: iconSize),
                                          onPressed: _toggleFullscreen,
                                          tooltip: TxaLanguage.currentLang == 'vi' ? 'Toàn màn hình' : 'Fullscreen',
                                        ),
                                      ],
                                      if (widget.servers != null && widget.servers!.isNotEmpty) ...[
                                        SizedBox(width: 12 * scale),
                                        IconButton(
                                          icon: Icon(Icons.playlist_play_rounded, color: Colors.white, size: iconSize),
                                          onPressed: _openPlaylistPanel,
                                          tooltip: TxaLanguage.t('episode_list'),
                                        ),
                                      ],
                                      SizedBox(width: 12 * scale),
                                      IconButton(
                                        icon: Icon(Icons.settings_rounded, color: Colors.white, size: iconSize - 2),
                                        onPressed: () {
                                          setState(() {
                                            _showSettingsPanel = !_showSettingsPanel;
                                            _showPlaylistPanel = false;
                                          });
                                        },
                                        tooltip: TxaLanguage.t('settings'),
                                      ),
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
        if (_subtitleMode != 'off' && !_showAd && (_activePrimaryCue != null || _activeSecondaryCue != null)) ...[
          if (_activePrimaryCue != null || (_subtitleMode == 'bilingual' && _activeSecondaryCue != null && _secondarySubPosition == 'bottom'))
            Positioned(
              bottom: _showControls ? 110 : 40,
              left: 40,
              right: 40,
              child: IgnorePointer(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_subtitleMode == 'bilingual' && _activeSecondaryCue != null && _secondarySubPosition == 'bottom') ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: _subtitleBgOpacity),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _activeSecondaryCue!.text,
                            style: TextStyle(
                              color: Colors.amberAccent,
                              fontSize: _subtitleFontSize * 0.9,
                              fontWeight: FontWeight.bold,
                              shadows: _getSubtitleShadows(_subtitleBorder),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      if (_activePrimaryCue != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: _subtitleBgOpacity),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _activePrimaryCue!.text,
                            style: TextStyle(
                              color: _parseHexColor(_subtitleColor),
                              fontSize: _subtitleFontSize,
                              fontWeight: FontWeight.bold,
                              shadows: _getSubtitleShadows(_subtitleBorder),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          if (_subtitleMode == 'bilingual' && _activeSecondaryCue != null && _secondarySubPosition == 'top')
            Positioned(
              top: _showControls ? 110 : 50,
              left: 40,
              right: 40,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: _subtitleBgOpacity),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _activeSecondaryCue!.text,
                      style: TextStyle(
                        color: Colors.amberAccent,
                        fontSize: _subtitleFontSize * 0.9,
                        fontWeight: FontWeight.bold,
                        shadows: _getSubtitleShadows(_subtitleBorder),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
        ],

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
        if (_showNextEpisodeOverlay && _nextEpisodeData != null)
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
                                child: _nextEpisodeData!['thumb'] != null && _nextEpisodeData!['thumb'].toString().isNotEmpty
                                    ? Image.network(
                                        _nextEpisodeData!['thumb'],
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
                                      _nextEpisodeData!['name'] ?? '',
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
                                    _nextEpisodeData!['movieName'] ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _nextEpisodeData!['name'] ?? '',
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
                  widthFactor: _duration > Duration.zero ? (_position.inSeconds / _duration.inSeconds).clamp(0.0, 1.0) : 0.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF737DFD),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),

          // 14. SETTINGS SIDE PANEL DRAWER (Mobile & TV)
          if (_showSettingsPanel)
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.settings_rounded, color: Color(0xFF737DFD), size: 20),
                            const SizedBox(width: 8),
                            Text(
                              TxaLanguage.t('settings').toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                          onPressed: () {
                            setState(() {
                              _showSettingsPanel = false;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: ListView(
                        children: [
                          _buildSettingsToggleItem(
                            index: 0,
                            icon: Icons.fast_forward_rounded,
                            title: 'Tự động bỏ qua Intro',
                            value: _autoSkipIntro,
                            onChanged: (val) {
                              _setPlayerSetting('auto_skip_intro', val);
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildSettingsToggleItem(
                            index: 1,
                            icon: Icons.skip_next_rounded,
                            title: 'Tự động chuyển tập',
                            value: _autoNextEpisode,
                            onChanged: (val) {
                              _setPlayerSetting('auto_next_episode', val);
                            },
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'NGÔN NGỮ PHỤ ĐỀ ƯU TIÊN',
                            style: TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 8),
                          _buildSettingsRadioItem(
                            index: 2,
                            title: 'Tiếng Việt',
                            isSelected: _preferredSubLang == 'vi',
                            onTap: () {
                              _setPlayerSetting('preferred_sub_lang', 'vi');
                            },
                          ),
                          _buildSettingsRadioItem(
                            index: 3,
                            title: 'English',
                            isSelected: _preferredSubLang == 'en',
                            onTap: () {
                              _setPlayerSetting('preferred_sub_lang', 'en');
                            },
                          ),
                          _buildSettingsRadioItem(
                            index: 4,
                            title: 'Tiếng Trung',
                            isSelected: _preferredSubLang == 'zh',
                            onTap: () {
                              _setPlayerSetting('preferred_sub_lang', 'zh');
                            },
                          ),
                          const SizedBox(height: 20),
                          Text(
                            TxaLanguage.t('sub_style_title'),
                            style: const TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 12),
                          _buildSettingsHorizontalOptionsRow(
                            index: 5,
                            title: TxaLanguage.t('sub_font_size'),
                            items: _fontSizes.map((size) {
                              return _buildOptionBtn(
                                label: '${size.toInt()}px',
                                value: size,
                                currentValue: _subtitleFontSize,
                                onTap: (val) {
                                  _setPlayerSetting('subtitle_font_size', val);
                                },
                              );
                            }).toList(),
                          ),
                          _buildSettingsHorizontalOptionsRow(
                            index: 6,
                            title: TxaLanguage.t('sub_color'),
                            items: _colors.map((c) {
                              return _buildOptionBtn(
                                label: TxaLanguage.t(c['name']!),
                                value: c['value']!,
                                currentValue: _subtitleColor,
                                onTap: (val) {
                                  _setPlayerSetting('subtitle_color', val);
                                },
                              );
                            }).toList(),
                          ),
                          _buildSettingsHorizontalOptionsRow(
                            index: 7,
                            title: TxaLanguage.t('sub_border'),
                            items: _borders.map((b) {
                              return _buildOptionBtn(
                                label: TxaLanguage.t(b['name']!),
                                value: b['value']!,
                                currentValue: _subtitleBorder,
                                onTap: (val) {
                                  _setPlayerSetting('subtitle_border', val);
                                },
                              );
                            }).toList(),
                          ),
                          _buildSettingsHorizontalOptionsRow(
                            index: 8,
                            title: TxaLanguage.t('sub_opacity'),
                            items: _bgOpacities.map((o) {
                              return _buildOptionBtn(
                                label: o['name']!,
                                value: o['value'] as double,
                                currentValue: _subtitleBgOpacity,
                                onTap: (val) {
                                  _setPlayerSetting('subtitle_bg_opacity', val);
                                },
                              );
                            }).toList(),
                          ),
                          _buildSettingsHorizontalOptionsRow(
                            index: 9,
                            title: TxaLanguage.t('sub_pos'),
                            items: _positions.map((p) {
                              return _buildOptionBtn(
                                label: TxaLanguage.t(p['name']!),
                                value: p['value']!,
                                currentValue: _secondarySubPosition,
                                onTap: (val) {
                                  _setPlayerSetting('secondary_sub_position', val);
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'CẤU HÌNH ÂM THANH NÂNG CAO',
                            style: TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 12),
                          _buildSettingsToggleItem(
                            index: 10,
                            icon: Icons.surround_sound_rounded,
                            title: 'Âm thanh vòm 3D',
                            value: _is3dAudioEnabled,
                            onChanged: (val) {
                              _setPlayerSetting('audio_3d_enabled', val);
                              _applyAudioEffects();
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildSettingsToggleItem(
                            index: 11,
                            icon: Icons.equalizer_rounded,
                            title: 'Tối ưu EQ (Giọng nói/Bass)',
                            value: _isAudioOptimizerEnabled,
                            onChanged: (val) {
                              _setPlayerSetting('audio_optimize_enabled', val);
                              _applyAudioEffects();
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildSettingsHorizontalOptionsRow(
                            index: 12,
                            title: 'KHUẾCH ĐẠI ÂM LƯỢNG (BOOST)',
                            items: [1.0, 1.5, 2.0, 2.5, 3.0].map((level) {
                              return _buildOptionBtn(
                                label: '${(level * 100).toInt()}%',
                                value: level,
                                currentValue: _audioBoostLevel,
                                onTap: (val) {
                                  _setPlayerSetting('audio_boost_level', val);
                                  _applyAudioEffects();
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
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
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _toggleControls();
        },
        child: Focus(
          focusNode: _tvFocusNode,
          autofocus: true,
          onKeyEvent: (node, event) {
            _handleTvKeyEvent(event);
            return KeyEventResult.handled;
          },
          child: playerView,
        ),
      );
    } else if (TxaPlatform.isDesktop) {
      // Desktop: keyboard shortcuts, double click to fullscreen, click to toggle controls
      return Focus(
        focusNode: _desktopFocusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          _handleDesktopKeyEvent(event);
          return KeyEventResult.handled;
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _desktopFocusNode.requestFocus();
            _toggleControls();
          },
          onDoubleTap: () {
            _toggleFullscreen();
          },
          onLongPressStart: (details) {
            final screenWidth = MediaQuery.of(context).size.width;
            final pressX = details.globalPosition.dx;
            if (pressX > screenWidth * 0.5) {
              _startSpeedUp2x();
            }
          },
          onLongPressEnd: (details) {
            _stopSpeedUp2x();
          },
          child: playerView,
        ),
      );
    } else {
      // Mobile touch gestures
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!_isLocked) {
            _toggleControls();
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
        onLongPressStart: (details) {
          if (_isLocked) return;
          final screenWidth = MediaQuery.of(context).size.width;
          final pressX = details.globalPosition.dx;
          if (pressX > screenWidth * 0.5) {
            _startSpeedUp2x();
          }
        },
        onLongPressEnd: (details) {
          _stopSpeedUp2x();
        },
        onVerticalDragUpdate: (details) {
          if (_isLocked) return;
          final size = MediaQuery.of(context).size;
          final screenWidth = size.width;
          final screenHeight = size.height;
          final dragX = details.globalPosition.dx;
          final dragY = details.globalPosition.dy;
          
          // Only active within middle vertical area
          if (dragY < screenHeight * 0.15 || dragY > screenHeight * 0.80) {
            return;
          }
          
          final delta = -details.delta.dy / 300.0;
          if (dragX < screenWidth * 0.3) {
            _adjustBrightness(delta);
          } else if (dragX > screenWidth * 0.7) {
            _adjustVolume(delta);
          }
        },
        onTapCancel: () {},
        onLongPressCancel: () {
          _stopSpeedUp2x();
        },
        onVerticalDragCancel: () {},
        child: playerView,
      );
    }
  }

  Color _parseHexColor(String hex) {
    try {
      String cleanHex = hex.toUpperCase().replaceAll('#', '');
      if (cleanHex.length == 6) {
        cleanHex = 'FF$cleanHex';
      }
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return Colors.white;
    }
  }

  List<Shadow> _getSubtitleShadows(String style) {
    if (style == 'shadow') {
      return const [
        Shadow(color: Colors.black, blurRadius: 4, offset: Offset(2, 2)),
      ];
    } else if (style == 'stroke') {
      return const [
        Shadow(color: Colors.black, blurRadius: 1, offset: Offset(1, 1)),
        Shadow(color: Colors.black, blurRadius: 1, offset: Offset(-1, 1)),
        Shadow(color: Colors.black, blurRadius: 1, offset: Offset(1, -1)),
        Shadow(color: Colors.black, blurRadius: 1, offset: Offset(-1, -1)),
      ];
    }
    return const [];
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

class TxaStoryboardItem {
  final double startTime; // in seconds
  final double endTime;   // in seconds
  final String imgUrl;
  final int x;
  final int y;
  final int w;
  final int h;

  TxaStoryboardItem({
    required this.startTime,
    required this.endTime,
    required this.imgUrl,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });
}
