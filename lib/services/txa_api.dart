import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/txa_logger.dart';
import 'txa_language.dart';
import 'txa_version.dart';

class TxaApi {
  static const String baseUrl = 'https://dongmephim.online';
  static const String apiKey = 'tphimx-mobile-2026-secure';
  static const String appVersion = TxaVersion.version;

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('txa_auth_token');
    
    final Map<String, String> headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Requested-With': 'XMLHttpRequest',
      'X-TXC-Client': 'TPhimX-App',
      'X-TXA-API-KEY': apiKey,
      'User-Agent': 'TPhimX-App/$appVersion (Android)',
    };
    
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // --- Authentication ---

  Future<Map<String, dynamic>?> login(String identity, String password) async {
    final url = Uri.parse('$baseUrl/api/auth/login');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'identity': identity,
          'password': password,
        }),
      );

      TxaLogger.logApi(
        method: 'POST',
        path: url.toString(),
        statusCode: response.statusCode,
        responseBody: utf8.decode(response.bodyBytes),
      );

      if (response.statusCode == 200 || response.statusCode == 400 || response.statusCode == 401) {
        return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>?;
      }
    } catch (e) {
      TxaLogger.log('TxaApi login error: $e', type: 'api');
    }
    return null;
  }

  Future<Map<String, dynamic>?> googleLogin({String? credential, String? accessToken}) async {
    final url = Uri.parse('$baseUrl/api/auth/google-login');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          if (credential != null) 'credential': credential,
          if (accessToken != null) 'accessToken': accessToken,
        }),
      );

      TxaLogger.logApi(
        method: 'POST',
        path: url.toString(),
        statusCode: response.statusCode,
        responseBody: utf8.decode(response.bodyBytes),
      );

      if (response.statusCode == 200 || response.statusCode == 400) {
        return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>?;
      }
    } catch (e) {
      TxaLogger.log('TxaApi googleLogin error: $e', type: 'api');
    }
    return null;
  }

  Future<Map<String, dynamic>?> googleRegister({
    String? credential,
    String? accessToken,
    required String gender,
    required String province,
    required String ward,
    required String phone,
  }) async {
    final url = Uri.parse('$baseUrl/api/auth/google-register');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          if (credential != null) 'credential': credential,
          if (accessToken != null) 'accessToken': accessToken,
          'gender': gender,
          'province': province,
          'ward': ward,
          'phone': phone,
        }),
      );

      TxaLogger.logApi(
        method: 'POST',
        path: url.toString(),
        statusCode: response.statusCode,
        responseBody: utf8.decode(response.bodyBytes),
      );

      if (response.statusCode == 200 || response.statusCode == 400) {
        return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>?;
      }
    } catch (e) {
      TxaLogger.log('TxaApi googleRegister error: $e', type: 'api');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getProfile() async {
    final url = Uri.parse('$baseUrl/api/auth/me');
    try {
      final response = await http.get(
        url,
        headers: await _getHeaders(),
      );
      TxaLogger.logApi(
        method: 'GET',
        path: url.toString(),
        statusCode: response.statusCode,
        responseBody: utf8.decode(response.bodyBytes),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          return decoded['data'] as Map<String, dynamic>?;
        }
      }
    } catch (e) {
      TxaLogger.log('TxaApi getProfile error: $e', type: 'api');
    }
    return null;
  }

  Future<Map<String, dynamic>?> updateAvatar(String base64Image, {String? userId}) async {
    final url = Uri.parse('$baseUrl/api/user/update-avatar');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'avatar': base64Image,
          if (userId != null) 'userId': userId,
        }),
      );
      TxaLogger.logApi(
        method: 'POST',
        path: url.toString(),
        statusCode: response.statusCode,
        responseBody: utf8.decode(response.bodyBytes),
      );
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>?;
    } catch (e) {
      TxaLogger.log('TxaApi updateAvatar error: $e', type: 'api');
    }
    return null;
  }

  // --- Home and Movie Details ---

  Future<Map<String, dynamic>?> getHome() async {
    final url = Uri.parse('$baseUrl/api/app/home');
    try {
      final response = await http.get(
        url,
        headers: await _getHeaders(),
      );

      TxaLogger.logApi(
        method: 'GET',
        path: url.toString(),
        statusCode: response.statusCode,
        responseBody: utf8.decode(response.bodyBytes),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          return decoded['data'] as Map<String, dynamic>?;
        }
      }
    } catch (e) {
      TxaLogger.log('TxaApi getHome error: $e', type: 'api');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getMovie(String slug) async {
    final url = Uri.parse('$baseUrl/api/app/movie/$slug');
    try {
      final response = await http.get(
        url,
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        // Chỉ hiện ở console logs, không lưu file logs/tab logs
        // ignore: avoid_print
        print('[API Console Only] GET ${url.path} - STATUS: 200\nResponse: ${utf8.decode(response.bodyBytes)}');
      } else {
        // Có lỗi -> ghi vào file log và hiển thị trong tab logs
        TxaLogger.logApi(
          method: 'GET',
          path: url.toString(),
          statusCode: response.statusCode,
          responseBody: utf8.decode(response.bodyBytes),
        );
      }
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          return decoded['data'] as Map<String, dynamic>?;
        }
      }
    } catch (e) {
      TxaLogger.log('TxaApi getMovie error: $e', type: 'api');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getCategory(String slug, {int page = 1}) async {
    final url = Uri.parse('$baseUrl/api/app/category/$slug?page=$page');
    try {
      final response = await http.get(
        url,
        headers: await _getHeaders(),
      );
      TxaLogger.logApi(
        method: 'GET',
        path: url.toString(),
        statusCode: response.statusCode,
        responseBody: utf8.decode(response.bodyBytes),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          return decoded['data'] as Map<String, dynamic>?;
        }
      }
    } catch (e) {
      TxaLogger.log('TxaApi getCategory error: $e', type: 'api');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getType(String type, {int page = 1}) async {
    final url = Uri.parse('$baseUrl/api/app/type/$type?page=$page');
    try {
      final response = await http.get(
        url,
        headers: await _getHeaders(),
      );
      TxaLogger.logApi(
        method: 'GET',
        path: url.toString(),
        statusCode: response.statusCode,
        responseBody: utf8.decode(response.bodyBytes),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          return decoded['data'] as Map<String, dynamic>?;
        }
      }
    } catch (e) {
      TxaLogger.log('TxaApi getType error: $e', type: 'api');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getNotifications() async {
    final url = Uri.parse('$baseUrl/api/app/notifications');
    try {
      final response = await http.get(
        url,
        headers: await _getHeaders(),
      );
      TxaLogger.logApi(
        method: 'GET',
        path: url.toString(),
        statusCode: response.statusCode,
        responseBody: utf8.decode(response.bodyBytes),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          return decoded;
        }
      }
    } catch (e) {
      TxaLogger.log('TxaApi getNotifications error: $e', type: 'api');
    }
    return null;
  }

  Future<bool> markNotificationRead(String id) async {
    final url = Uri.parse('$baseUrl/api/app/notifications/read');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({'id': id}),
      );
      TxaLogger.logApi(
        method: 'POST',
        path: url.toString(),
        statusCode: response.statusCode,
        responseBody: utf8.decode(response.bodyBytes),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return decoded['success'] == true;
      }
    } catch (e) {
      TxaLogger.log('TxaApi markNotificationRead error: $e', type: 'api');
    }
    return false;
  }

  Future<bool> markAllNotificationsRead() async {
    final url = Uri.parse('$baseUrl/api/app/notifications/read-all');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
      );
      TxaLogger.logApi(
        method: 'POST',
        path: url.toString(),
        statusCode: response.statusCode,
        responseBody: utf8.decode(response.bodyBytes),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return decoded['success'] == true;
      }
    } catch (e) {
      TxaLogger.log('TxaApi markAllNotificationsRead error: $e', type: 'api');
    }
    return false;
  }

  Future<bool> clearNotifications() async {
    final url = Uri.parse('$baseUrl/api/app/notifications/clear');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
      );
      TxaLogger.logApi(
        method: 'POST',
        path: url.toString(),
        statusCode: response.statusCode,
        responseBody: utf8.decode(response.bodyBytes),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return decoded['success'] == true;
      }
    } catch (e) {
      TxaLogger.log('TxaApi clearNotifications error: $e', type: 'api');
    }
    return false;
  }

  Future<Map<String, dynamic>?> submitMovieRequest({
    required String name,
    String? originName,
    String? publishYear,
    String? link,
    String? author,
  }) async {
    final url = Uri.parse('$baseUrl/api/app/movie-requests');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'name': name,
          'origin_name': originName,
          'publish_year': publishYear,
          'link': link,
          'author': author,
          'source': 'app',
        }),
      );
      TxaLogger.logApi(
        method: 'POST',
        path: url.toString(),
        statusCode: response.statusCode,
        responseBody: utf8.decode(response.bodyBytes),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          return decoded;
        }
      } else {
        try {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          return decoded;
        } catch (_) {}
      }
    } catch (e) {
      TxaLogger.log('TxaApi submitMovieRequest error: $e', type: 'api');
    }
    return null;
  }

  Future<List<dynamic>> getChangelog() async {
    final url = Uri.parse('$baseUrl/api/app/changelog');
    try {
      final response = await http.get(
        url,
        headers: await _getHeaders(),
      );
      TxaLogger.logApi(
        method: 'GET',
        path: url.toString(),
        statusCode: response.statusCode,
        responseBody: utf8.decode(response.bodyBytes),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          return decoded['data'] as List<dynamic>? ?? [];
        }
      }
    } catch (e) {
      TxaLogger.log('TxaApi getChangelog error: $e', type: 'api');
    }
    return [];
  }

  Future<Map<String, dynamic>?> getCheckUpdate() async {
    final url = Uri.parse('$baseUrl/api/app/check-update');
    try {
      final response = await http.get(
        url,
        headers: await _getHeaders(),
      );
      TxaLogger.logApi(
        method: 'GET',
        path: url.toString(),
        statusCode: response.statusCode,
        responseBody: utf8.decode(response.bodyBytes),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) {
          final Map<String, dynamic> dataMap = (decoded['success'] == true)
              ? (decoded['data'] as Map<String, dynamic>? ?? decoded)
              : decoded;

          final nestedData = dataMap['data'] as Map<String, dynamic>? ?? dataMap;
          
          final isMaintenance = (decoded['maintenance_mode'] == true ||
              dataMap['maintenance_mode'] == true ||
              nestedData['maintenance_mode'] == true ||
              decoded['maintenance_mode']?.toString() == 'true' ||
              dataMap['maintenance_mode']?.toString() == 'true' ||
              nestedData['maintenance_mode']?.toString() == 'true');

          final maintenanceMsg = (decoded['maintenance_message'] ??
              dataMap['maintenance_message'] ??
              nestedData['maintenance_message'])?.toString() ?? '';

          return {
            ...nestedData,
            'app_version': (nestedData['latest_version'] ?? nestedData['app_version'] ?? '4.7.5').toString(),
            'app_release_notes': (nestedData['changelog'] ?? nestedData['app_release_notes'] ?? '').toString(),
            'download_url': (nestedData['download_url'] ?? nestedData['apk_url'] ?? '').toString(),
            'maintenance_mode': isMaintenance,
            'maintenance_message': maintenanceMsg,
          };
        }
      }
    } catch (e) {
      TxaLogger.log('TxaApi getCheckUpdate error: $e', type: 'api');
    }
    return null;
  }

  Future<Map<String, dynamic>?> searchMovies(
    String query, {
    int page = 1,
    String? category,
    String? region,
    String? year,
    String? type,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': '20',
    };
    if (query.isNotEmpty) {
      queryParams['q'] = query;
    }
    if (category != null && category.isNotEmpty) {
      queryParams['category'] = category;
    }
    if (region != null && region.isNotEmpty) {
      queryParams['region'] = region;
    }
    if (year != null && year.isNotEmpty) {
      queryParams['year'] = year;
    }
    if (type != null && type.isNotEmpty) {
      queryParams['type'] = type;
    }

    final uri = Uri.parse('$baseUrl/api/app/search').replace(queryParameters: queryParams);
    
    try {
      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );
      TxaLogger.logApi(
        method: 'GET',
        path: uri.toString(),
        statusCode: response.statusCode,
        responseBody: utf8.decode(response.bodyBytes),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          return decoded['data'] as Map<String, dynamic>?;
        }
      }
    } catch (e) {
      TxaLogger.log('TxaApi searchMovies error: $e', type: 'api');
    }
    return null;
  }

  Future<List<dynamic>> getHotSearches({int limit = 10}) async {
    final url = Uri.parse('$baseUrl/api/app/hot-search?limit=$limit');
    try {
      final response = await http.get(
        url,
        headers: await _getHeaders(),
      );
      TxaLogger.logApi(
        method: 'GET',
        path: url.toString(),
        statusCode: response.statusCode,
        responseBody: utf8.decode(response.bodyBytes),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          return decoded['data'] as List<dynamic>? ?? [];
        }
      }
    } catch (e) {
      TxaLogger.log('TxaApi getHotSearches error: $e', type: 'api');
    }
    return [];
  }

  Future<Map<String, dynamic>?> getFilters() async {
    final url = Uri.parse('$baseUrl/api/app/filters');
    try {
      final response = await http.get(
        url,
        headers: await _getHeaders(),
      );
      TxaLogger.logApi(
        method: 'GET',
        path: url.toString(),
        statusCode: response.statusCode,
        responseBody: utf8.decode(response.bodyBytes),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          return decoded['data'] as Map<String, dynamic>?;
        }
      }
    } catch (e) {
      TxaLogger.log('TxaApi getFilters error: $e', type: 'api');
    }
    return null;
  }

  Future<bool> registerSearchClick(String key, {int? movieId}) async {
    final url = Uri.parse('$baseUrl/api/app/search-click');
    final body = <String, dynamic>{
      'keyword': key,
    };
    if (movieId != null) {
      body['movie_id'] = movieId;
    }
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode(body),
      );
      TxaLogger.logApi(
        method: 'POST',
        path: url.toString(),
        statusCode: response.statusCode,
        responseBody: utf8.decode(response.bodyBytes),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          return true;
        }
      }
    } catch (e) {
      TxaLogger.log('TxaApi registerSearchClick error: $e', type: 'api');
    }
    return false;
  }

  // --- Watch History ---

  Future<List<dynamic>> getWatchHistory() async {
    final url = Uri.parse('$baseUrl/api/app/watch-history');
    try {
      final response = await http.get(
        url,
        headers: await _getHeaders(),
      );
      TxaLogger.logApi(
        method: 'GET',
        path: url.toString(),
        statusCode: response.statusCode,
        responseBody: utf8.decode(response.bodyBytes),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          return decoded['data'] as List<dynamic>? ?? [];
        }
      }
    } catch (e) {
      TxaLogger.log('TxaApi getWatchHistory error: $e', type: 'api');
    }
    return [];
  }

  Future<bool> updateWatchHistory(
    dynamic movieId,
    String episodeId,
    double currentTime,
    double duration,
    int serverIndex,
  ) async {
    final url = Uri.parse('$baseUrl/api/app/watch-history/update');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'movie_id': movieId.toString(),
          'episode_id': episodeId,
          'current_time': currentTime,
          'duration': duration,
          'server_index': serverIndex,
        }),
      );
      TxaLogger.logApi(
        method: 'POST',
        path: url.toString(),
        statusCode: response.statusCode,
        responseBody: utf8.decode(response.bodyBytes),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return decoded != null && decoded['success'] == true;
      }
    } catch (e) {
      TxaLogger.log('TxaApi updateWatchHistory error: $e', type: 'api');
    }
    return false;
  }

  Future<bool> clearWatchHistory() async {
    final url = Uri.parse('$baseUrl/api/app/watch-history/clear');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
      );
      TxaLogger.logApi(
        method: 'POST',
        path: url.toString(),
        statusCode: response.statusCode,
        responseBody: utf8.decode(response.bodyBytes),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return decoded != null && decoded['success'] == true;
      }
    } catch (e) {
      TxaLogger.log('TxaApi clearWatchHistory error: $e', type: 'api');
    }
    return false;
  }

  // --- Favorites ---

  Future<Map<String, dynamic>?> getFavorites({int page = 1, int limit = 20}) async {
    final url = Uri.parse('$baseUrl/api/app/favorites?page=$page&limit=$limit');
    try {
      final response = await http.get(
        url,
        headers: await _getHeaders(),
      );
      TxaLogger.logApi(
        method: 'GET',
        path: url.toString(),
        statusCode: response.statusCode,
        responseBody: utf8.decode(response.bodyBytes),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          return decoded['data'] as Map<String, dynamic>?;
        }
      }
    } catch (e) {
      TxaLogger.log('TxaApi getFavorites error: $e', type: 'api');
    }
    return null;
  }

  Future<Map<String, dynamic>?> toggleFavorite(String slug) async {
    final url = Uri.parse('$baseUrl/api/app/favorites/toggle');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({'slug': slug}),
      );
      TxaLogger.logApi(
        method: 'POST',
        path: url.toString(),
        statusCode: response.statusCode,
        responseBody: utf8.decode(response.bodyBytes),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          return (decoded['data'] as Map<String, dynamic>?) ?? decoded;
        }
      }
    } catch (e) {
      TxaLogger.log('TxaApi toggleFavorite error: $e', type: 'api');
    }
    return null;
  }

  // --- Ratings ---

  Future<Map<String, dynamic>?> getRating(String slug) async {
    final url = Uri.parse('$baseUrl/api/app/rating?slug=$slug');
    try {
      final response = await http.get(
        url,
        headers: await _getHeaders(),
      );
      TxaLogger.logApi(
        method: 'GET',
        path: url.toString(),
        statusCode: response.statusCode,
        responseBody: utf8.decode(response.bodyBytes),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          return decoded['data'] as Map<String, dynamic>?;
        }
      }
    } catch (e) {
      TxaLogger.log('TxaApi getRating error: $e', type: 'api');
    }
    return null;
  }

  Future<Map<String, dynamic>?> postRating(String slug, int rating) async {
    final url = Uri.parse('$baseUrl/api/app/rating');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'slug': slug,
          'rating': rating,
        }),
      );
      TxaLogger.logApi(
        method: 'POST',
        path: url.toString(),
        statusCode: response.statusCode,
        responseBody: utf8.decode(response.bodyBytes),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          return decoded['data'] as Map<String, dynamic>?;
        }
      }
    } catch (e) {
      TxaLogger.log('TxaApi postRating error: $e', type: 'api');
    }
    return null;
  }

  // --- Comments ---

  Future<List<dynamic>> getComments(String slug) async {
    final url = Uri.parse('$baseUrl/api/comments?slug=$slug');
    try {
      final response = await http.get(
        url,
        headers: await _getHeaders(),
      );
      TxaLogger.logApi(
        method: 'GET',
        path: url.toString(),
        statusCode: response.statusCode,
        responseBody: utf8.decode(response.bodyBytes),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          return decoded['data'] as List<dynamic>? ?? [];
        }
      }
    } catch (e) {
      TxaLogger.log('TxaApi getComments error: $e', type: 'api');
    }
    return [];
  }

  Future<Map<String, dynamic>?> postComment(
    String slug,
    String content, {
    String? author,
    String? episodeName,
    String? serverName,
    bool isSpoiler = false,
  }) async {
    final url = Uri.parse('$baseUrl/api/comments');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'slug': slug,
          'content': content,
          'author': author ?? 'Guest',
          'episodeName': episodeName,
          'serverName': serverName,
          'isSpoiler': isSpoiler,
        }),
      );
      TxaLogger.logApi(
        method: 'POST',
        path: url.toString(),
        statusCode: response.statusCode,
        responseBody: utf8.decode(response.bodyBytes),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          return decoded['data'] as Map<String, dynamic>?;
        }
      }
    } catch (e) {
      TxaLogger.log('TxaApi postComment error: $e', type: 'api');
    }
    return null;
  }

  Future<Map<String, dynamic>?> likeComment(String commentId) async {
    final url = Uri.parse('$baseUrl/api/comments');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'action': 'like',
          'commentId': commentId,
        }),
      );
      TxaLogger.logApi(
        method: 'POST',
        path: url.toString(),
        statusCode: response.statusCode,
        responseBody: utf8.decode(response.bodyBytes),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          return decoded['data'] as Map<String, dynamic>?;
        }
      }
    } catch (e) {
      TxaLogger.log('TxaApi likeComment error: $e', type: 'api');
    }
    return null;
  }

  Future<Map<String, dynamic>?> replyComment(
    String commentId,
    String replyContent, {
    String? replyAuthor,
  }) async {
    final url = Uri.parse('$baseUrl/api/comments');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'action': 'reply',
          'commentId': commentId,
          'replyContent': replyContent,
          'replyAuthor': replyAuthor ?? 'Guest',
        }),
      );
      TxaLogger.logApi(
        method: 'POST',
        path: url.toString(),
        statusCode: response.statusCode,
        responseBody: utf8.decode(response.bodyBytes),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          return decoded['data'] as Map<String, dynamic>?;
        }
      }
    } catch (e) {
      TxaLogger.log('TxaApi replyComment error: $e', type: 'api');
    }
    return null;
  }

  Future<bool> deleteComment(String commentId) async {
    final url = Uri.parse('$baseUrl/api/comments');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'action': 'delete',
          'commentId': commentId,
        }),
      );
      TxaLogger.logApi(
        method: 'POST',
        path: url.toString(),
        statusCode: response.statusCode,
        responseBody: utf8.decode(response.bodyBytes),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return decoded != null && decoded['success'] == true;
      }
    } catch (e) {
      TxaLogger.log('TxaApi deleteComment error: $e', type: 'api');
    }
    return false;
  }

  static Map<String, dynamic>? _cachedPackages;

  static void clearCache() {
    _cachedPackages = null;
  }

  Future<Map<String, dynamic>?> getPackages() async {
    if (_cachedPackages != null) {
      return _cachedPackages;
    }
    final url = Uri.parse('$baseUrl/api/app/packages');
    try {
      final response = await http.get(
        url,
        headers: await _getHeaders(),
      );
      TxaLogger.logApi(
        method: 'GET',
        path: url.toString(),
        statusCode: response.statusCode,
        responseBody: utf8.decode(response.bodyBytes),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          _cachedPackages = decoded['data'] as Map<String, dynamic>?;
          return _cachedPackages;
        }
      }
    } catch (e) {
      TxaLogger.log('TxaApi getPackages error: $e', type: 'api');
    }
    return null;
  }

  Future<List<dynamic>> getActivePromos() async {
    final url = Uri.parse('$baseUrl/api/app/promos');
    try {
      final response = await http.get(
        url,
        headers: await _getHeaders(),
      );
      TxaLogger.logApi(
        method: 'GET',
        path: url.toString(),
        statusCode: response.statusCode,
        responseBody: utf8.decode(response.bodyBytes),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          return decoded['data'] as List<dynamic>? ?? [];
        }
      }
    } catch (e) {
      TxaLogger.log('TxaApi getActivePromos error: $e', type: 'api');
    }
    return [];
  }

  Future<List<dynamic>> getPayments() async {
    final url = Uri.parse('$baseUrl/api/user/payments');
    try {
      final response = await http.get(
        url,
        headers: await _getHeaders(),
      );
      TxaLogger.logApi(
        method: 'GET',
        path: url.toString(),
        statusCode: response.statusCode,
        responseBody: utf8.decode(response.bodyBytes),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          return decoded['data'] as List<dynamic>? ?? [];
        }
      }
    } catch (e) {
      TxaLogger.log('TxaApi getPayments error: $e', type: 'api');
    }
    return [];
  }

  Future<Map<String, dynamic>?> verifyPromo(
    String code,
    String packageTitle,
    String username,
    double currentPrice,
  ) async {
    final url = Uri.parse('$baseUrl/api/user/verify-promo');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'code': code,
          'packageTitle': packageTitle,
          'username': username,
          'currentPrice': currentPrice,
        }),
      );
      TxaLogger.logApi(
        method: 'POST',
        path: url.toString(),
        statusCode: response.statusCode,
        responseBody: utf8.decode(response.bodyBytes),
      );
      if (response.statusCode == 200 || response.statusCode == 400) {
        return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>?;
      }
    } catch (e) {
      TxaLogger.log('TxaApi verifyPromo error: $e', type: 'api');
    }
    return null;
  }

  Future<Map<String, dynamic>?> sepayInit(
    String txid,
    int totalAmount,
    String packageTitle,
    String cycle,
    String packageId,
  ) async {
    final url = Uri.parse('$baseUrl/api/payment/sepay-init');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'txid': txid,
          'totalAmount': totalAmount,
          'packageTitle': packageTitle,
          'cycle': cycle,
          'packageId': packageId,
        }),
      );
      TxaLogger.logApi(
        method: 'POST',
        path: url.toString(),
        statusCode: response.statusCode,
        responseBody: utf8.decode(response.bodyBytes),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          return decoded['data'] as Map<String, dynamic>?;
        }
      }
    } catch (e) {
      TxaLogger.log('TxaApi sepayInit error: $e', type: 'api');
    }
    return null;
  }

  Future<bool> postPaymentLog(Map<String, dynamic> paymentLog) async {
    final url = Uri.parse('$baseUrl/api/user/payments');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode(paymentLog),
      );
      TxaLogger.logApi(
        method: 'POST',
        path: url.toString(),
        statusCode: response.statusCode,
        responseBody: utf8.decode(response.bodyBytes),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return decoded != null && decoded['success'] == true;
      }
    } catch (e) {
      TxaLogger.log('TxaApi postPaymentLog error: $e', type: 'api');
    }
    return false;
  }

  Future<bool> sendCrashReport(String crashLog, {String? deviceInfo}) async {
    final url = Uri.parse('$baseUrl/api/app/crash-report');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'crash_log': crashLog,
          'device_info': deviceInfo ?? 'DongMePhim Mobile App',
          'platform': Platform.operatingSystem,
          'os_version': Platform.operatingSystemVersion,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
      TxaLogger.logApi(
        method: 'POST',
        path: url.toString(),
        statusCode: response.statusCode,
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error sending crash report to server: $e');
    }
    return false;
  }

  static Future<Map<String, dynamic>> submitIapPayment({
    required String txid,
    required String packageTitle,
    required double price,
    String cycle = 'custom_1',
    String method = 'google_play',
    String status = 'approved',
    String? clientInfo,
  }) async {
    final url = Uri.parse('$baseUrl/api/user/payments');
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('txa_auth_token');
      final username = prefs.getString('txa_user_name') ?? 'mobile_user';
      final email = prefs.getString('txa_user_email') ?? '';

      final Map<String, String> headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
        'X-TXC-Client': 'TPhimX-App',
        'X-TXA-API-KEY': apiKey,
        'User-Agent': 'TPhimX-App/$appVersion (Android)',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final body = {
        'txid': txid,
        'username': username,
        'email': email,
        'packageTitle': packageTitle,
        'price': price,
        'cycle': cycle,
        'method': method,
        'status': status,
        'clientInfo': clientInfo ?? 'Google Play Billing In-App Purchase',
      };

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      TxaLogger.logApi(
        method: 'POST',
        path: url.toString(),
        statusCode: response.statusCode,
        responseBody: utf8.decode(response.bodyBytes),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) {
          return {
            'success': decoded['status'] == 'success' || decoded['success'] == true,
            'message': decoded['message'] ?? 'Thành công',
            'keyCode': decoded['data']?['keyCode'] ?? decoded['keyCode'],
          };
        }
      }
    } catch (e) {
      TxaLogger.log('TxaApi submitIapPayment error: $e', type: 'api');
    }
    return {
      'success': false,
      'message': 'Không thể kết nối máy chủ xác thực hóa đơn.',
    };
  }

  // --- Scan Action ---

  Future<ScanResult> scanMovie(String slug) async {
    try {
      var sourceUrl = Uri.parse('https://phimapi.com/phim/$slug');
      var response = await http.get(sourceUrl);
      var source = 'kkphim';

      if (response.statusCode != 200) {
        sourceUrl = Uri.parse('https://vsmov.com/api/phim/$slug');
        response = await http.get(sourceUrl);
        source = 'vsmov';
      }

      if (response.statusCode != 200) {
        return ScanResult(
          success: false,
          message: 'Không tìm thấy phim trên các nguồn API gốc (phimapi, vsmov).',
        );
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic> || decoded['movie'] == null) {
        return ScanResult(
          success: false,
          message: 'Dữ liệu trả về từ nguồn API gốc không hợp lệ hoặc thiếu thông tin.',
        );
      }

      final m = decoded['movie'] as Map<String, dynamic>;
      final defaultCdn = source == 'vsmov' ? 'https://vsmov.com' : 'https://phimimg.com';
      final cdnDomain = decoded['pathImage'] ?? decoded['APP_DOMAIN_CDN_IMAGE'] ?? defaultCdn;

      String posterUrl = m['poster_url'] ?? '';
      if (posterUrl.isNotEmpty && !posterUrl.startsWith('http')) {
        final cleanPath = posterUrl.replaceFirst(RegExp(r'^\/?uploads\/movies\/'), '');
        posterUrl = '$cdnDomain/uploads/movies/$cleanPath';
      }

      String bannerUrl = m['thumb_url'] ?? m['poster_url'] ?? '';
      if (bannerUrl.isNotEmpty && !bannerUrl.startsWith('http')) {
        final cleanPath = bannerUrl.replaceFirst(RegExp(r'^\/?uploads\/movies\/'), '');
        bannerUrl = '$cdnDomain/uploads/movies/$cleanPath';
      }

      final genresList = m['category'] as List? ?? [];
      final genres = genresList.map((c) => (c['name'] ?? '').toString()).toList();

      String category = "Khác";
      final countryList = m['country'] as List? ?? [];
      if (countryList.isNotEmpty) {
        category = countryList[0]['name'] ?? 'Khác';
      }

      String type = 'series';
      if (m['type'] == 'single') {
        type = 'movie';
      } else if (m['type'] == 'hoathinh') {
        type = 'hoathinh';
      } else if (m['type'] == 'tvshows') {
        type = 'tvshows';
      }

      final rawEpisodes = decoded['episodes'] as List? ?? [];
      final episodes = rawEpisodes.map((server) {
        final serverMap = server as Map<String, dynamic>;
        final serverDataList = serverMap['server_data'] as List? ?? [];

        final serverData = serverDataList.map((ep) {
          final epMap = ep as Map<String, dynamic>;
          String epName = epMap['name'] ?? '';
          if (RegExp(r'^\d+$').hasMatch(epName.trim())) {
            epName = 'Tập ${epName.trim().padLeft(2, '0')}';
          }

          return {
            'name': epName,
            'slug': epMap['slug'] ?? 'tap-${epMap['name']}',
            'filename': epMap['filename'] ?? '${m['name']} - Tap ${epMap['name']}',
            'linkEmbed': epMap['link_embed'] ?? '',
            'linkM3u8': epMap['link_m3u8'] ?? '',
            'subtitles': epMap['subtitles'] ?? epMap['subtitles_data'] ?? [],
            'timeIntroStart': epMap['timeIntroStart'] ?? epMap['time_intro_start'] ?? 0,
            'timeIntroEnd': epMap['timeIntroEnd'] ?? epMap['time_intro_end'] ?? 0,
            'timeOutroStart': epMap['timeOutroStart'] ?? epMap['time_outro_start'] ?? 0,
            'timeOutroEnd': epMap['timeOutroEnd'] ?? epMap['time_outro_end'] ?? 0,
          };
        }).toList();

        return {
          'serverName': serverMap['server_name'] ?? 'Server VIP',
          'serverData': serverData,
        };
      }).toList();

      final movieDetailObj = {
        'id': m['_id'] ?? m['id'] ?? 'kk-${m['slug']}',
        'title': m['name'],
        'originalTitle': m['origin_name'],
        'slug': m['slug'],
        'description': m['content'] != null ? m['content'].toString().replaceAll(RegExp(r'<[^>]*>'), '') : '',
        'posterUrl': posterUrl,
        'bannerUrl': bannerUrl,
        'releaseYear': int.tryParse(m['year']?.toString() ?? '') ?? 2025,
        'durationMinutes': m['time'] ?? (type == 'movie' ? '120 phút' : '45 phút/tập'),
        'type': type,
        'status': m['status'] == 'completed' ? 'completed' : 'ongoing',
        'episodeCurrent': m['episode_current'] ?? (type == 'movie' ? 'Full' : '1'),
        'episodeTotal': m['episode_total'] ?? '1',
        'quality': m['quality'] ?? 'FHD',
        'lang': m['lang'] ?? 'Vietsub',
        'imdbScore': 8.0,
        'category': category,
        'ageRating': type == 'movie' ? 'T16' : 'T13',
        'genres': genres,
        'seasons': type == 'movie' ? 'Bản Điện Ảnh' : 'Phần 1',
        'actors': m['actor'] is List ? (m['actor'] as List).where((a) => a != null).toList() : [],
        'directors': m['director'] is List ? (m['director'] as List).where((a) => a != null).toList() : [],
        'trailerUrl': m['trailer_url'] ?? '',
        'episodes': episodes,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      final saveUrl = Uri.parse('$baseUrl/api/admin/movie-action');
      final saveResponse = await http.post(
        saveUrl,
        headers: await _getHeaders(),
        body: jsonEncode({
          'action': 'save',
          'slug': slug,
          'movieData': movieDetailObj,
          'isStatic': false,
        }),
      );

      TxaLogger.logApi(
        method: 'POST',
        path: saveUrl.toString(),
        statusCode: saveResponse.statusCode,
        responseBody: utf8.decode(saveResponse.bodyBytes),
      );

      if (saveResponse.statusCode == 200) {
        final saveDecoded = jsonDecode(utf8.decode(saveResponse.bodyBytes));
        if (saveDecoded is Map<String, dynamic> && saveDecoded['success'] == true) {
          int count = 0;
          if (episodes.isNotEmpty) {
            count = (episodes[0]['serverData'] as List? ?? []).length;
          }
          return ScanResult(
            success: true,
            message: TxaLanguage.t('sync_success'),
            totalEpisodes: count,
          );
        } else {
          String errorMsg = 'Lỗi lưu dữ liệu máy chủ.';
          if (saveDecoded is Map && saveDecoded['message'] != null) {
            errorMsg = saveDecoded['message'].toString();
          }
          return ScanResult(success: false, message: errorMsg);
        }
      } else {
        String errorMsg = 'Lỗi máy chủ: status ${saveResponse.statusCode}';
        try {
          final body = jsonDecode(utf8.decode(saveResponse.bodyBytes));
          if (body is Map && body['message'] != null) {
            errorMsg = body['message'].toString();
          }
        } catch (_) {}
        return ScanResult(success: false, message: errorMsg);
      }
    } catch (e) {
      TxaLogger.log('TxaApi scanMovie error: $e', type: 'api');
      return ScanResult(success: false, message: TxaLanguage.t('sync_unexpected_error', replace: {'error': e.toString()}));
    }
  }

  Future<List<dynamic>> getSchedule({String? date}) async {
    final url = Uri.parse(date != null ? '$baseUrl/api/app/schedule?date=$date' : '$baseUrl/api/app/schedule');
    try {
      final response = await http.get(
        url,
        headers: await _getHeaders(),
      );
      TxaLogger.logApi(
        method: 'GET',
        path: url.toString(),
        statusCode: response.statusCode,
        responseBody: utf8.decode(response.bodyBytes),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          return decoded['data'] as List<dynamic>? ?? [];
        }
      }
    } catch (e) {
      TxaLogger.log('TxaApi getSchedule error: $e', type: 'api');
    }
    return [];
  }
}

class ScanResult {
  final bool success;
  final String message;
  final int totalEpisodes;

  ScanResult({
    required this.success,
    required this.message,
    this.totalEpisodes = 0,
  });
}

