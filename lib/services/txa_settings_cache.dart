/// Cache nhẹ cho app settings lấy từ /api/app/check-update
/// Dùng để truy cập social links trong banned/block screens mà không cần gọi API thêm
class TxaSettingsCache {
  static final TxaSettingsCache _instance = TxaSettingsCache._internal();
  factory TxaSettingsCache() => _instance;
  TxaSettingsCache._internal();

  Map<String, dynamic>? _data;

  /// Lưu toàn bộ response từ check-update vào cache
  void populate(Map<String, dynamic> checkUpdateData) {
    _data = checkUpdateData;
  }

  bool get hasData => _data != null;

  // ─── Social Links ───────────────────────────────────────────

  String get telegramUrl => (_data?['social_telegram_url'] as String? ?? '').trim();
  bool get telegramEnabled => _data?['social_telegram_enable'] == true;

  String get facebookUrl => (_data?['social_fb_url'] as String? ?? '').trim();
  bool get facebookEnabled => _data?['social_fb_enable'] == true;

  String get facebookGroupUrl => (_data?['social_fb_group_url'] as String? ?? '').trim();
  bool get facebookGroupEnabled => _data?['social_fb_group_enable'] == true;

  String get zaloUrl => (_data?['social_zalo_url'] as String? ?? '').trim();
  bool get zaloEnabled => _data?['social_zalo_enable'] == true;

  String get discordUrl => (_data?['discord_server_url'] as String? ?? '').trim();
  bool get discordEnabled => _data?['discord_server_enable'] == true;

  /// Trả về list các kênh liên hệ đang bật, ưu tiên Telegram → Facebook → Zalo → Discord
  List<({String label, String url, String icon})> get contactChannels {
    final result = <({String label, String url, String icon})>[];
    if (telegramEnabled && telegramUrl.isNotEmpty) {
      result.add((label: 'Telegram', url: telegramUrl, icon: 'send'));
    }
    if (facebookEnabled && facebookUrl.isNotEmpty) {
      result.add((label: 'Fanpage', url: facebookUrl, icon: 'public'));
    }
    if (facebookGroupEnabled && facebookGroupUrl.isNotEmpty) {
      result.add((label: 'Facebook Group', url: facebookGroupUrl, icon: 'group'));
    }
    if (zaloEnabled && zaloUrl.isNotEmpty) {
      result.add((label: 'Zalo Group', url: zaloUrl, icon: 'chat_bubble'));
    }
    if (discordEnabled && discordUrl.isNotEmpty) {
      result.add((label: 'Discord', url: discordUrl, icon: 'headset_mic'));
    }
    return result;
  }
}
