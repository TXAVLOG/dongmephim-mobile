class TxaMovieRanker {
  /// Tính điểm xếp hạng xu hướng cho phim
  static double calculateScore(Map<String, dynamic> movie) {
    if (movie['trendingScore'] != null) {
      return (movie['trendingScore'] as num).toDouble();
    }
    
    // Fallback Cold Start: sử dụng điểm đánh giá IMDb hoặc TMDB
    double imdbScore = 0.0;
    if (movie['imdbScore'] != null) {
      imdbScore = (movie['imdbScore'] as num).toDouble();
    } else if (movie['imdb'] != null && movie['imdb']['vote_average'] != null) {
      imdbScore = (movie['imdb']['vote_average'] as num).toDouble();
    }
    
    double tmdbScore = 0.0;
    if (movie['tmdbScore'] != null) {
      tmdbScore = (movie['tmdbScore'] as num).toDouble();
    } else if (movie['tmdb'] != null && movie['tmdb']['vote_average'] != null) {
      tmdbScore = (movie['tmdb']['vote_average'] as num).toDouble();
    }

    double finalScore = imdbScore > 0 ? imdbScore : (tmdbScore > 0 ? tmdbScore : 8.0);
    return finalScore * 10;
  }

  /// Sắp xếp danh sách phim theo điểm giảm dần.
  /// Nếu các số liệu là 0 (điểm bằng nhau hoặc bằng 0) thì ưu tiên phim mới nhất.
  static List<dynamic> sortMovies(List<dynamic> movies) {
    final sortedMovies = List<dynamic>.from(movies);
    sortedMovies.sort((a, b) {
      final movieA = a as Map<String, dynamic>;
      final movieB = b as Map<String, dynamic>;

      final scoreA = calculateScore(movieA);
      final scoreB = calculateScore(movieB);

      if (scoreA != scoreB) {
        return scoreB.compareTo(scoreA); // Giảm dần
      }

      // Fallback: ưu tiên mới nhất (updatedAt hoặc releaseYear)
      final timeA = movieA['updatedAt'] != null ? DateTime.tryParse(movieA['updatedAt'].toString())?.millisecondsSinceEpoch ?? 0 : 0;
      final timeB = movieB['updatedAt'] != null ? DateTime.tryParse(movieB['updatedAt'].toString())?.millisecondsSinceEpoch ?? 0 : 0;
      
      if (timeB != timeA) {
        return timeB.compareTo(timeA);
      }

      final yearA = int.tryParse(movieA['releaseYear']?.toString() ?? movieA['year']?.toString() ?? '0') ?? 0;
      final yearB = int.tryParse(movieB['releaseYear']?.toString() ?? movieB['year']?.toString() ?? '0') ?? 0;
      return yearB.compareTo(yearA);
    });

    return sortedMovies;
  }
}
