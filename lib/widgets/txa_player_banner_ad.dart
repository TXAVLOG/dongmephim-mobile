import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/txa_ads_service.dart';
import '../utils/txa_platform.dart';
import '../utils/txa_logger.dart';

/// Dedicated, isolated Banner Ad widget for TXAPlayer.
/// Manages its own BannerAd lifecycle independently from player control state rebuilds.
class TxaPlayerBannerAd extends StatefulWidget {
  final bool showControls;
  final bool hasPaidPackage;
  final bool isInPiPMode;
  final Map<String, dynamic>? adSettings;

  const TxaPlayerBannerAd({
    super.key,
    required this.showControls,
    required this.hasPaidPackage,
    required this.isInPiPMode,
    this.adSettings,
  });

  @override
  State<TxaPlayerBannerAd> createState() => _TxaPlayerBannerAdState();
}

class _TxaPlayerBannerAdState extends State<TxaPlayerBannerAd> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  bool _isLoading = false;
  bool _isDismissed = false;
  int _retryAttempts = 0;
  Timer? _retryTimer;

  static const int _maxRetryAttempts = 3;

  @override
  void initState() {
    super.initState();
    _checkAndLoadAd();
  }

  @override
  void didUpdateWidget(covariant TxaPlayerBannerAd oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasPaidPackage && _bannerAd != null) {
      _disposeCurrentAd();
    } else if (!widget.hasPaidPackage && _bannerAd == null && !_isAdLoaded && !_isLoading && !_isDismissed) {
      _checkAndLoadAd();
    }
  }

  void _disposeCurrentAd() {
    _retryTimer?.cancel();
    _retryTimer = null;
    final adToDispose = _bannerAd;
    _bannerAd = null;
    _isAdLoaded = false;
    _isLoading = false;
    try {
      adToDispose?.dispose();
    } catch (e) {
      debugPrint('Error disposing BannerAd: $e');
    }
  }

  Future<void> _checkAndLoadAd() async {
    if (kIsWeb || !TxaPlatform.isMobile) return;
    if (widget.hasPaidPackage || _isDismissed || _isLoading || _bannerAd != null) return;

    _isLoading = true;

    try {
      final ad = await TxaAdsService.instance.loadBannerAd(
        adSize: AdSize.banner,
        adSettings: widget.adSettings,
        onAdLoaded: (loadedAd) {
          if (!mounted) {
            try {
              loadedAd.dispose();
            } catch (_) {}
            return;
          }
          setState(() {
            _bannerAd = loadedAd as BannerAd;
            _isAdLoaded = true;
            _isLoading = false;
            _retryAttempts = 0;
          });
        },
        onAdFailedToLoad: (failedAd, error) {
          if (!mounted) return;
          TxaLogger.log('Player Banner Ad failed to load (${error.code}): ${error.message}', type: 'app');
          setState(() {
            _bannerAd = null;
            _isAdLoaded = false;
            _isLoading = false;
          });
          _scheduleRetry();
        },
      );

      if (ad == null && mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      TxaLogger.log('Error initializing player banner ad: $e', type: 'app');
      if (mounted) {
        setState(() {
          _bannerAd = null;
          _isAdLoaded = false;
          _isLoading = false;
        });
        _scheduleRetry();
      }
    }
  }

  void _scheduleRetry() {
    if (_retryAttempts >= _maxRetryAttempts || _isDismissed || !mounted || widget.hasPaidPackage) return;
    _retryTimer?.cancel();
    _retryAttempts++;
    final delaySeconds = _retryAttempts * 20; // 20s, 40s, 60s
    _retryTimer = Timer(Duration(seconds: delaySeconds), () {
      if (mounted && !_isAdLoaded && !_isLoading && !_isDismissed) {
        _checkAndLoadAd();
      }
    });
  }

  void _dismissBanner() {
    setState(() {
      _isDismissed = true;
    });
    _disposeCurrentAd();
  }

  @override
  void dispose() {
    _disposeCurrentAd();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !TxaPlatform.isMobile || widget.hasPaidPackage || widget.isInPiPMode || _isDismissed || !_isAdLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    final bannerWidth = _bannerAd!.size.width.toDouble();
    final bannerHeight = _bannerAd!.size.height.toDouble();

    // Smoothly transition vertical offset when controls toggle without recreating the AdWidget
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      bottom: widget.showControls ? 82 : 16,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          width: bannerWidth,
          height: bannerHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24, width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: bannerWidth,
                  height: bannerHeight,
                  child: _SafeAdWidget(ad: _bannerAd!),
                ),
              ),
              // Optional subtle close button at top-right
              Positioned(
                top: -8,
                right: -8,
                child: GestureDetector(
                  onTap: _dismissBanner,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2235),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white30, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 13,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A safe wrapper around AdWidget to prevent any uncaught native or binding exceptions
/// from breaking the player or triggering the global error widget.
class _SafeAdWidget extends StatelessWidget {
  final BannerAd ad;

  const _SafeAdWidget({required this.ad});

  @override
  Widget build(BuildContext context) {
    try {
      return AdWidget(ad: ad);
    } catch (e) {
      TxaLogger.log('SafeAdWidget build exception: $e', type: 'app');
      return const SizedBox.shrink();
    }
  }
}
