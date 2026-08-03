import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/txa_api.dart';
import '../services/txa_auth_service.dart';
import '../utils/txa_logger.dart';

class TxaAdsService {
  static final TxaAdsService _instance = TxaAdsService._internal();
  factory TxaAdsService() => _instance;
  TxaAdsService._internal();

  bool _initialized = false;
  bool _appStartAdShown = false;
  Map<String, dynamic>? _adSettings;

  /// Initialize MobileAds SDK once (Android & iOS)
  Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

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
      final info = await TxaApi().getCheckUpdate();
      if (info != null && info['ads'] != null) {
        _adSettings = info['ads'] as Map<String, dynamic>;
        return _adSettings;
      }
    } catch (e) {
      debugPrint('Failed to load ad settings: $e');
    }
    return null;
  }

  /// Trigger App Start Ad after 5 seconds delay (Android & iOS)
  void scheduleAppStartAd() {
    if (_appStartAdShown) return;
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

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
          : (Platform.isAndroid 
              ? 'ca-app-pub-3940256099942544/1033173712' 
              : 'ca-app-pub-3940256099942544/5135179831'); // Test Interstitial Ad ID

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

  /// Show Pre-Roll Ad before playing video (Android & iOS)
  Future<void> showPreRollAd({required Function onComplete}) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
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
        : (Platform.isAndroid
            ? 'ca-app-pub-3940256099942544/1033173712'
            : 'ca-app-pub-3940256099942544/5135179831'); // Test Interstitial Ad ID

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

  /// Show Rewarded Ad to unlock premium items (Android & iOS)
  Future<void> showRewardedAd({required Function(bool rewardGranted) onComplete}) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      onComplete(true);
      return;
    }

    final adsConfig = await _getAdSettings();
    final admobEnable = adsConfig?['admob_enable'] == true;
    if (!admobEnable) {
      onComplete(true);
      return;
    }

    final unitId = (adsConfig?['admob_rewarded_ad_id'] ?? '').toString().trim();
    final testId = Platform.isAndroid 
        ? 'ca-app-pub-3940256099942544/5224354917' 
        : 'ca-app-pub-3940256099942544/1712485313';
    final effectiveUnitId = unitId.isNotEmpty ? unitId : testId;

    await init();

    bool completed = false;
    bool granted = false;
    void safeComplete(bool rewardGranted) {
      if (!completed) {
        completed = true;
        onComplete(rewardGranted);
      }
    }

    RewardedAd.load(
      adUnitId: effectiveUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              Timer(const Duration(milliseconds: 500), () {
                safeComplete(granted);
              });
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              safeComplete(false);
            },
          );

          ad.show(onUserEarnedReward: (AdWithoutView adView, RewardItem reward) {
            TxaLogger.log('User earned reward: ${reward.amount} ${reward.type}', type: 'app');
            granted = true;
          });
        },
        onAdFailedToLoad: (error) {
          TxaLogger.log('Rewarded Ad failed to load: $error', type: 'app');
          safeComplete(false);
        },
      ),
    );
  }
}
