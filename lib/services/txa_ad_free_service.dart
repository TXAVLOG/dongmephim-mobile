import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'txa_ads_service.dart';
import 'txa_language.dart';

class TxaAdFreeService extends ChangeNotifier {
  static final TxaAdFreeService instance = TxaAdFreeService._internal();
  TxaAdFreeService._internal();

  static const String _keyExpiry = 'txa_ad_free_expiry_ms';
  static const String _keyWatchedCount = 'txa_ad_free_watched_count';
  static const String _keyLastKnownClock = 'txa_ad_free_last_clock_ms';

  int _expiryMs = 0;
  int _watchedCount = 0;
  bool _isLoadingAd = false;
  RewardedAd? _rewardedAd;
  Timer? _countdownTimer;

  int get expiryMs => _expiryMs;
  int get watchedCount => _watchedCount;
  bool get isLoadingAd => _isLoadingAd;
  int get requiredAds => TxaAdsService.instance.adFreeConfig.requiredAds;

  /// Kiểm tra trạng thái Miễn Quảng Cáo còn hiệu lực không
  bool get isAdFreeActive {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _expiryMs > now;
  }

  /// Thời gian miễn quảng cáo còn lại (Duration)
  Duration get remainingDuration {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_expiryMs <= now) return Duration.zero;
    return Duration(milliseconds: _expiryMs - now);
  }

  /// Chuỗi hiển thị đếm ngược thời gian còn lại: 23:45:10 hoặc 1d 04:20:15
  String get remainingTimeString {
    final d = remainingDuration;
    if (d.inSeconds <= 0) return '00:00:00';

    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;

    final hStr = hours.toString().padLeft(2, '0');
    final mStr = minutes.toString().padLeft(2, '0');
    final sStr = seconds.toString().padLeft(2, '0');

    if (days > 0) {
      return '$days ${TxaLanguage.isVietnamese ? "ngày" : "d"} $hStr:$mStr:$sStr';
    }
    return '$hStr:$mStr:$sStr';
  }

  /// Khởi tạo trạng thái và lắng nghe đếm ngược
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _expiryMs = prefs.getInt(_keyExpiry) ?? 0;
    _watchedCount = prefs.getInt(_keyWatchedCount) ?? 0;
    final lastKnown = prefs.getInt(_keyLastKnownClock) ?? 0;

    final now = DateTime.now().millisecondsSinceEpoch;

    // Chống can thiệp lùi giờ thiết bị (Anti-tamper clock)
    if (lastKnown > now + 60000) {
      debugPrint('[TxaAdFreeService] Phát hiện lùi giờ hệ thống! Reset vé.');
      _expiryMs = 0;
      await prefs.setInt(_keyExpiry, 0);
    } else {
      await prefs.setInt(_keyLastKnownClock, now);
    }

    _startCountdownTimer();
    preloadAd();
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isAdFreeActive) {
        notifyListeners();
      } else if (_expiryMs > 0 && _expiryMs <= DateTime.now().millisecondsSinceEpoch) {
        _expiryMs = 0;
        notifyListeners();
      }
    });
  }

  /// Tải trước video quảng cáo Rewarded
  void preloadAd() {
    if (_rewardedAd != null || _isLoadingAd) return;

    final adUnitId = TxaAdsService.instance.rewardedAdFreeAdUnitId;
    if (adUnitId.isEmpty) return;

    _isLoadingAd = true;
    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoadingAd = false;
          debugPrint('[TxaAdFreeService] Tải trước Rewarded Ad thành công.');
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isLoadingAd = false;
          debugPrint('[TxaAdFreeService] Tải Rewarded Ad thất bại: ${error.message}');
        },
      ),
    );
  }

  /// Bắt đầu xem video quảng cáo
  Future<void> watchAd({
    required BuildContext context,
    VoidCallback? onSuccess,
    Function(String error)? onError,
  }) async {
    // 1. Kiểm tra giới hạn cộng dồn tối đa (Max Stack Hours)
    final maxStackHours = TxaAdsService.instance.adFreeConfig.maxStackHours;
    final maxStackMs = DateTime.now().millisecondsSinceEpoch + (maxStackHours * 3600 * 1000).toInt();
    if (_expiryMs >= maxStackMs) {
      final msg = TxaLanguage.get('ad_free_max_stacked', params: {'max': maxStackHours.toString()});
      onError?.call(msg);
      return;
    }

    // 2. Nếu quảng cáo chưa sẵn sàng, thử tải ngay
    if (_rewardedAd == null) {
      preloadAd();
      onError?.call(TxaLanguage.get('ad_free_loading_ad'));
      return;
    }

    final ad = _rewardedAd!;
    _rewardedAd = null;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        preloadAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        preloadAd();
        onError?.call(error.message);
      },
    );

    await ad.show(onUserEarnedReward: (adWithoutView, reward) async {
      await _handleRewardEarned(context: context, onSuccess: onSuccess);
    });
  }

  /// Xử lý khi xem hết 1 video quảng cáo
  Future<void> _handleRewardEarned({
    required BuildContext context,
    VoidCallback? onSuccess,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    _watchedCount++;

    final targetCount = requiredAds;
    if (_watchedCount >= targetCount) {
      // Đã xem đủ số lượng video -> Kích hoạt vé
      _watchedCount = 0;
      final durationHours = TxaAdsService.instance.adFreeConfig.durationHours;
      final durationMs = (durationHours * 3600 * 1000).toInt();

      final now = DateTime.now().millisecondsSinceEpoch;
      if (_expiryMs > now) {
        // Cộng dồn vào hạn hiện tại
        _expiryMs += durationMs;
      } else {
        // Tạo mới thời hạn từ bây giờ
        _expiryMs = now + durationMs;
      }

      await prefs.setInt(_keyExpiry, _expiryMs);
      await prefs.setInt(_keyWatchedCount, 0);
      await prefs.setInt(_keyLastKnownClock, now);

      notifyListeners();
      onSuccess?.call();
    } else {
      // Đã xem 1 video, còn thiếu video tiếp theo
      await prefs.setInt(_keyWatchedCount, _watchedCount);
      notifyListeners();
      onSuccess?.call();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _rewardedAd?.dispose();
    super.dispose();
  }
}
