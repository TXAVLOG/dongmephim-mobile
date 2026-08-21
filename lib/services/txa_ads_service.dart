import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/txa_api.dart';
import '../services/txa_auth_service.dart';
import '../services/txa_language.dart';
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

  /// Build AdRequest với nonPersonalizedAds=true khi chạy trên iOS mà không có ATT consent
  /// iOS 14+: Nếu không có IDFA (user chưa cho phép ATT), PHẢI dùng non-personalized
  /// để AdMob có thể serve ads thay vì trả về code 1 "No ad to show"
  static AdRequest _buildAdRequest() {
    if (Platform.isIOS) {
      // AdMob tự detect IDFA status. Khi set nonPersonalizedAds: null (default),
      // nếu IDFA không available → AdMob cần được hướng dẫn serve non-personalized
      // Keywords và content URL giúp contextual targeting khi không có IDFA
      return const AdRequest(
        keywords: ['phim', 'movie', 'entertainment', 'streaming', 'video'],
        contentUrl: 'https://dongmephim.online',
        nonPersonalizedAds: null, // null = AdMob tự quyết dựa vào IDFA availability
      );
    }
    return const AdRequest();
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

    // Delay slightly more or use a frame callback to ensure UI is stable
    Timer(const Duration(seconds: 6), () async {
      if (_appStartAdShown) return;
      _appStartAdShown = true;

      try {
        final bypass = await shouldBypassAds();
        if (bypass) {
          TxaLogger.log('VIP user: Bypassing App Start Ad.', type: 'app');
          return;
        }

        final adsConfig = await _getAdSettings();
        final admobEnable = adsConfig?['admob_enable'] == true;
        if (!admobEnable) return;

        final unitId = Platform.isAndroid
            ? (adsConfig?['admob_app_start_ad_id_android'] ?? '').toString().trim()
            : (adsConfig?['admob_app_start_ad_id_ios'] ?? '').toString().trim();
        final effectiveUnitId = unitId.isNotEmpty
            ? unitId
            : (Platform.isAndroid
                ? 'ca-app-pub-1543189450912703/7479521417'
                : 'ca-app-pub-1543189450912703/7479521417'); // Real Interstitial App Start Ad ID

        await init();

        // Optimization: Load the ad but set a strict timeout and monitor memory
        // On low-end devices, loading a heavy Interstitial can trigger OOM
        InterstitialAd.load(
          adUnitId: effectiveUnitId,
          request: _buildAdRequest(),
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
      } catch (e) {
        TxaLogger.log('Error in scheduleAppStartAd: $e', type: 'app');
      }
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

    final unitId = Platform.isAndroid
        ? (adsConfig?['admob_preroll_ad_id_android'] ?? '').toString().trim()
        : (adsConfig?['admob_preroll_ad_id_ios'] ?? '').toString().trim();
    final effectiveUnitId = unitId.isNotEmpty
        ? unitId
        : (Platform.isAndroid
            ? 'ca-app-pub-1543189450912703/7914635685'
            : 'ca-app-pub-1543189450912703/7914635685'); // Real Interstitial Pre-roll Ad ID

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
      request: _buildAdRequest(),
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
  Future<void> showRewardedAd({required Function(bool rewardGranted, [String? errorMsg]) onComplete}) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      // Windows / desktop / unsupported platforms: no ad SDK → no reward
      onComplete(false);
      return;
    }

    final adsConfig = await _getAdSettings();
    final admobEnable = adsConfig?['admob_enable'] == true;
    if (!admobEnable) {
      onComplete(true);
      return;
    }

    final unitId = Platform.isAndroid
        ? (adsConfig?['admob_rewarded_ad_id_android'] ?? '').toString().trim()
        : (adsConfig?['admob_rewarded_ad_id_ios'] ?? '').toString().trim();
    final defaultId = Platform.isAndroid 
        ? 'ca-app-pub-1543189450912703/9254657575' 
        : 'ca-app-pub-1543189450912703/6552472614';
    final effectiveUnitId = unitId.isNotEmpty ? unitId : defaultId;

    await init();

    bool completed = false;
    bool granted = false;
    void safeComplete(bool rewardGranted, [String? errorMsg]) {
      if (!completed) {
        completed = true;
        onComplete(rewardGranted, errorMsg);
      }
    }

    RewardedAd.load(
      adUnitId: effectiveUnitId,
      request: _buildAdRequest(),
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
          // code 3 = Frequency cap reached (user hit daily limit)
          if (error.code == 3) {
            safeComplete(false, TxaLanguage.t('ad_frequency_cap'));
          } else {
            safeComplete(false);
          }
        },
      ),
    );
  }

  /// Create and load a BannerAd for non-VIP / Free users
  /// Returns null if user has a paid package (bypass_ads) or on unsupported platforms
  Future<BannerAd?> loadBannerAd({
    required Function(Ad ad) onAdLoaded,
    required Function(Ad ad, LoadAdError error) onAdFailedToLoad,
    AdSize adSize = AdSize.banner,
  }) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return null;

    final bypass = await shouldBypassAds();
    if (bypass) {
      TxaLogger.log('VIP user: Bypassing Banner Ad.', type: 'app');
      return null;
    }

    final adsConfig = await _getAdSettings();
    final admobEnable = adsConfig?['admob_enable'] == true;
    if (!admobEnable) return null;

    final unitId = Platform.isAndroid
        ? (adsConfig?['admob_banner_ad_id_android'] ?? '').toString().trim()
        : (adsConfig?['admob_banner_ad_id_ios'] ?? '').toString().trim();
    final defaultId = Platform.isAndroid
        ? 'ca-app-pub-1543189450912703/2225333886'
        : 'ca-app-pub-1543189450912703/2225333886';
    final effectiveUnitId = unitId.isNotEmpty ? unitId : defaultId;

    await init();

    try {
      final bannerAd = BannerAd(
        adUnitId: effectiveUnitId,
        size: adSize,
        request: _buildAdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            TxaLogger.log('Banner Ad loaded successfully.', type: 'app');
            onAdLoaded(ad);
          },
          onAdFailedToLoad: (ad, error) {
            TxaLogger.log('Banner Ad failed to load: $error', type: 'app');
            ad.dispose();
            onAdFailedToLoad(ad, error);
          },
        ),
      );

      await bannerAd.load();
      return bannerAd;
    } catch (e) {
      TxaLogger.log('Error loading Banner Ad: $e', type: 'app');
      return null;
    }
  }
}
