import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/txa_api.dart';
import '../services/txa_auth.dart';
import '../utils/txa_platform.dart';
import '../utils/txa_logger.dart';

class TxaAdsService {
  static final TxaAdsService _instance = TxaAdsService._internal();
  factory TxaAdsService() => _instance;
  TxaAdsService._internal();

  bool _initialized = false;
  bool _appStartAdShown = false;
  Map<String, dynamic>? _adSettings;

  /// Initialize MobileAds SDK once
  Future<void> init() async {
    if (_initialized) return;
    if (TxaPlatform.isWeb || TxaPlatform.isDesktop) return;

    try {
      await MobileAds.instance.initialize();
      _initialized = true;
      TxaLogger.log('Google MobileAds initialized successfully.', type: 'app');
    } catch (e) {
      TxaLogger.log('Google MobileAds initialization error: $e', type: 'app');
    }
  }

  /// Check if the current logged-in user should bypass ads (VIP subscriber with bypass_ads permission)
  Future<bool> shouldBypassAds() async {
    final auth = TxaAuthService();
    if (!auth.isLoggedIn || auth.user == null) return false;

    final user = auth.user!;
    final userPkgId = (user['package'] ?? 'free').toString().toLowerCase();
    if (userPkgId == 'free') return false;

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
          return userPkg['permissions']['bypass_ads'] == true;
        }
      }
    } catch (e) {
      debugPrint('Error checking user bypass_ads status: $e');
    }
    return false;
  }

  /// Load AdMob settings from Supabase API
  Future<Map<String, dynamic>?> _getAdSettings() async {
    if (_adSettings != null) return _adSettings;
    try {
      final settings = await TxaApi().getSettings();
      if (settings != null && settings['ads'] != null) {
        _adSettings = settings['ads'] as Map<String, dynamic>;
        return _adSettings;
      }
    } catch (e) {
      debugPrint('Failed to load ad settings: $e');
    }
    return null;
  }

  /// Trigger App Start Ad after 5 seconds delay
  void scheduleAppStartAd() {
    if (_appStartAdShown) return;
    if (TxaPlatform.isWeb || TxaPlatform.isDesktop) return;

    Timer(const Duration(seconds: 5), () async {
      if (_appStartAdShown) return;
      _appStartAdShown = true;

      final bypass = await shouldBypassAds();
      if (bypass) {
        TxaLogger.log('VIP user: Bypassing App Start Ad.', type: 'app');
        return;
      }

      final adsConfig = await _getAdSettings();
      final admobEnable = adsConfig?['admob_enable'] == true;
      if (!admobEnable) return;

      final unitId = (adsConfig?['admob_app_start_ad_id'] ?? '').toString().trim();
      final effectiveUnitId = unitId.isNotEmpty
          ? unitId
          : 'ca-app-pub-3940256099942544/1033173712'; // Test Interstitial Ad ID

      await init();

      InterstitialAd.load(
        adUnitId: effectiveUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            TxaLogger.log('App Start Interstitial Ad loaded, showing now...', type: 'app');
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                ad.dispose();
              },
            );
            ad.show();
          },
          onAdFailedToLoad: (error) {
            TxaLogger.log('App Start Ad failed to load: $error', type: 'app');
          },
        ),
      );
    });
  }

  /// Show Pre-Roll Ad before playing video
  Future<void> showPreRollAd({required Function onComplete}) async {
    if (TxaPlatform.isWeb || TxaPlatform.isDesktop) {
      onComplete();
      return;
    }

    final bypass = await shouldBypassAds();
    if (bypass) {
      TxaLogger.log('VIP user: Bypassing Pre-Roll Ad.', type: 'app');
      onComplete();
      return;
    }

    final adsConfig = await _getAdSettings();
    final admobEnable = adsConfig?['admob_enable'] == true;
    if (!admobEnable) {
      onComplete();
      return;
    }

    final unitId = (adsConfig?['admob_preroll_ad_id'] ?? '').toString().trim();
    final effectiveUnitId = unitId.isNotEmpty
        ? unitId
        : 'ca-app-pub-3940256099942544/1033173712'; // Test Interstitial Ad ID

    await init();

    bool completed = false;
    void safeComplete() {
      if (!completed) {
        completed = true;
        onComplete();
      }
    }

    // Timeout safety of 6 seconds for ad loading
    final timer = Timer(const Duration(seconds: 6), () {
      safeComplete();
    });

    InterstitialAd.load(
      adUnitId: effectiveUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          timer.cancel();
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              safeComplete();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              safeComplete();
            },
          );
          ad.show();
        },
        onAdFailedToLoad: (error) {
          timer.cancel();
          TxaLogger.log('Pre-roll AdMob failed to load: $error', type: 'app');
          safeComplete();
        },
      ),
    );
  }
}
