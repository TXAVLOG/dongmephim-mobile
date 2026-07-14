import '../services/txa_language.dart';

class TxaSchedule {
  static String _t(String key, String fallback) {
    final val = TxaLanguage.t(key);
    return val == key ? fallback : val;
  }

  /// Tự động tạo nội dung thông báo lịch chiếu phim động tùy theo ngôn ngữ và phân loại phim.
  static String generateNotice(
    String? nextDate,
    String? nextTime,
    String? nextEpisode,
    String? movieType,
  ) {
    if (nextDate == null || nextDate.isEmpty) return '';

    // Định dạng ngày từ YYYY-MM-DD sang DD-MM-YYYY
    final dateParts = nextDate.split('-');
    final formattedDate = dateParts.length == 3 
        ? '${dateParts[2]}-${dateParts[1]}-${dateParts[0]}' 
        : nextDate;
    
    final timeStr = nextTime != null && nextTime.isNotEmpty ? '$nextTime ' : '';
    final fullTime = '$timeStr${_t('date_prefix', 'ngày')} $formattedDate';

    final epStr = nextEpisode != null ? nextEpisode.trim() : '';
    final type = movieType != null ? movieType.toLowerCase() : 'series';
    final isSingle = type == 'movie' || type == 'single';

    if (isSingle) {
      if (epStr.toLowerCase() == 'full') {
        return _t('broadcast_single_full', 'Trọn bộ bản đẹp sẽ phát sóng vào %time%')
            .replaceAll('%time%', fullTime);
      }
      return _t('broadcast_single_standard', 'Phim sẽ phát sóng vào %time%')
          .replaceAll('%time%', fullTime);
    } else {
      if (epStr.toLowerCase() == 'full') {
        return _t('broadcast_series_full', 'Trọn bộ sẽ phát sóng vào %time%')
            .replaceAll('%time%', fullTime);
      }
      if (epStr.toLowerCase() == 'tập cuối' || epStr.toLowerCase() == 'tap cuoi') {
        return _t('broadcast_series_final', 'Tập cuối sẽ phát sóng vào %time%')
            .replaceAll('%time%', fullTime);
      }

      // Xử lý viết hoa chữ "Tập" và chuẩn hóa
      String capitalizedEp = epStr;
      if (epStr.toLowerCase().startsWith('tập')) {
        capitalizedEp = _t('episode_prefix', 'Tập') + epStr.substring(3);
      } else if (epStr.toLowerCase().startsWith('tap')) {
        capitalizedEp = _t('episode_prefix', 'Tập') + epStr.substring(3);
      } else if (RegExp(r'^\d+$').hasMatch(epStr)) {
        capitalizedEp = '${_t('episode_prefix', 'Tập')} $epStr';
      } else if (capitalizedEp.isEmpty) {
        capitalizedEp = _t('next_episode_fallback', 'Tập tiếp theo');
      }

      return _t('broadcast_series_standard', '%episode% sẽ phát sóng vào %time%')
          .replaceAll('%episode%', capitalizedEp)
          .replaceAll('%time%', fullTime);
    }
  }

  /// Kiểm tra xem lịch phát sóng tổng có đang kích hoạt (thời điểm chiếu ở tương lai) hay không.
  static bool isScheduleActive(String? nextDate, String? nextTime) {
    if (nextDate == null || nextDate.isEmpty) return false;
    
    String targetDateTimeStr = '${nextDate}T00:00:00+07:00';
    if (nextTime != null && nextTime.isNotEmpty) {
      final parts = nextTime.split(':');
      if (parts.length == 2) {
        targetDateTimeStr = '${nextDate}T$nextTime:00+07:00';
      } else {
        targetDateTimeStr = '${nextDate}T$nextTime+07:00';
      }
    }
    
    try {
      final targetDate = DateTime.parse(targetDateTimeStr).millisecondsSinceEpoch;
      return DateTime.now().millisecondsSinceEpoch < targetDate;
    } catch (e) {
      return false;
    }
  }

  /// Xác định xem một tập phim có bị ẩn (chưa chiếu) hay không.
  static bool isEpisodeUnreleased(
    String epName,
    int epIndex,
    List<dynamic> eplist,
    Map<String, dynamic>? broadcastSchedule,
  ) {
    if (broadcastSchedule == null) return false;

    final nextDate = broadcastSchedule['nextDate'] ?? broadcastSchedule['next_date'];
    final nextTime = broadcastSchedule['nextTime'] ?? broadcastSchedule['next_time'];
    final nextEpisode = broadcastSchedule['nextEpisode'] ?? broadcastSchedule['next_episode'];

    if (nextDate == null || nextDate.toString().isEmpty) {
      return false;
    }

    // Nếu lịch tổng đã trôi qua, tức là tập đã được phát sóng
    if (!isScheduleActive(nextDate.toString(), nextTime?.toString())) {
      return false;
    }

    if (nextEpisode == null) {
      return false;
    }

    final normNextEp = nextEpisode.toString().trim().toLowerCase();

    // 1. Nếu nextEpisode chỉ định là "Full", ẩn tất cả các tập
    if (normNextEp == 'full') {
      return true;
    }

    // 2. Nếu nextEpisode là "Tập cuối", ẩn tập phim cuối cùng trong danh sách
    if ((normNextEp == 'tập cuối' || normNextEp == 'tap cuoi') && epIndex == eplist.length - 1) {
      return true;
    }

    // 3. Tìm vị trí của tập trùng khớp với nextEpisode
    final cleanNextEp = normNextEp.replaceAll(RegExp(r'^(tập|tap|ep|episode|ep-|-)+\s*'), '');
    
    int matchIndex = -1;
    for (int i = 0; i < eplist.length; i++) {
      final item = eplist[i];
      final itemName = (item['name'] ?? '').toString().trim().toLowerCase();
      final cleanItemName = itemName.replaceAll(RegExp(r'^(tập|tap|ep|episode|ep-|-)+\s*'), '');
      
      if (cleanItemName == cleanNextEp || itemName.contains(normNextEp)) {
        matchIndex = i;
        break;
      }
    }

    // Nếu tìm thấy vị trí tập tiếp theo đang chờ chiếu, ẩn mọi tập từ vị trí đó trở đi
    if (matchIndex != -1 && epIndex >= matchIndex) {
      return true;
    }

    return false;
  }
}
