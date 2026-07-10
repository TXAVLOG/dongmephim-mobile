import 'package:flutter/foundation.dart';

/// Singleton quản lý trạng thái yêu thích toàn ứng dụng.
/// Dùng ValueNotifier<Set<String>> để mọi widget lắng nghe thay đổi slug yêu thích
/// mà không cần Provider hay riverpod.
class TxaFavoriteManager {
  static final TxaFavoriteManager _instance = TxaFavoriteManager._internal();
  factory TxaFavoriteManager() => _instance;
  TxaFavoriteManager._internal();

  /// Tập hợp slug phim đang được yêu thích.
  final ValueNotifier<Set<String>> favorites = ValueNotifier<Set<String>>({});

  /// Kiểm tra slug có đang yêu thích không.
  bool isFavorite(String slug) => favorites.value.contains(slug);

  /// Cập nhật trạng thái yêu thích cho 1 slug.
  void setFavorite(String slug, bool isFav) {
    final current = Set<String>.from(favorites.value);
    if (isFav) {
      current.add(slug);
    } else {
      current.remove(slug);
    }
    favorites.value = current;
  }

  /// Toggle và trả về trạng thái mới.
  bool toggle(String slug) {
    final isFav = isFavorite(slug);
    setFavorite(slug, !isFav);
    return !isFav;
  }

  /// Khởi tạo danh sách yêu thích từ API response (list slugs).
  void initFromSlugs(List<String> slugs) {
    favorites.value = Set<String>.from(slugs);
  }
}
