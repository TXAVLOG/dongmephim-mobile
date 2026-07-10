import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class TvCacheService {
  static final TvCacheService _instance = TvCacheService._internal();
  factory TvCacheService() => _instance;
  TvCacheService._internal();

  final Map<String, dynamic> _memoryCache = {};
  final Map<String, DateTime> _expiryTimes = {};

  static const Duration _cacheTtl = Duration(minutes: 30);

  /// Saves data to memory cache and local SharedPreferences
  Future<void> write(String key, dynamic value) async {
    final expiry = DateTime.now().add(_cacheTtl);
    _memoryCache[key] = value;
    _expiryTimes[key] = expiry;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('tv_cache_$key', jsonEncode({
        'value': value,
        'expires_at': expiry.toIso8601String(),
      }));
    } catch (_) {}
  }

  /// Reads cached data. Returns null if expired or not found.
  Future<dynamic> read(String key) async {
    // 1. Try memory cache first
    if (_memoryCache.containsKey(key)) {
      final expiry = _expiryTimes[key];
      if (expiry != null && DateTime.now().isBefore(expiry)) {
        return _memoryCache[key];
      } else {
        // Expired in memory
        _memoryCache.remove(key);
        _expiryTimes.remove(key);
      }
    }

    // 2. Fallback to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataStr = prefs.getString('tv_cache_$key');
      if (dataStr != null) {
        final decoded = jsonDecode(dataStr) as Map<String, dynamic>;
        final expiresAt = DateTime.parse(decoded['expires_at']);
        
        if (DateTime.now().isBefore(expiresAt)) {
          // Repopulate memory cache
          _memoryCache[key] = decoded['value'];
          _expiryTimes[key] = expiresAt;
          return decoded['value'];
        } else {
          // Expired in disk
          await prefs.remove('tv_cache_$key');
        }
      }
    } catch (_) {}

    return null;
  }

  /// Clears cache
  Future<void> clear() async {
    _memoryCache.clear();
    _expiryTimes.clear();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('tv_cache_')).toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (_) {}
  }
}
