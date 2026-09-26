import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'txa_path_resolver.dart';
import '../../../utils/txa_logger.dart';

class TxaStorageInfo {
  final int totalBytes;
  final int usedBytes;
  final int freeBytes;
  final int appBytes;

  TxaStorageInfo({
    required this.totalBytes,
    required this.usedBytes,
    required this.freeBytes,
    required this.appBytes,
  });

  double get usedRatio => totalBytes > 0 ? (usedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;
  double get appRatio => totalBytes > 0 ? (appBytes / totalBytes).clamp(0.0, 1.0) : 0.0;
}

class TxaStorageEstimator {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 12; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      },
    ),
  );

  /// Lấy thông tin dung lượng hệ thống và dung lượng tải thực tế của ứng dụng
  static Future<TxaStorageInfo> getStorageInfo(int appBytes) async {
    int totalBytes = 128 * 1024 * 1024 * 1024; // 128 GB fallback
    int freeBytes = 64 * 1024 * 1024 * 1024;   // 64 GB fallback

    try {
      if (Platform.isAndroid || Platform.isLinux || Platform.isMacOS) {
        final rootDir = await TxaPathResolver.getDownloadsRootDir();
        final res = await Process.run('df', ['-k', rootDir.path]);
        if (res.exitCode == 0) {
          final lines = res.stdout.toString().trim().split('\n');
          if (lines.length > 1) {
            final parts = lines.last.split(RegExp(r'\s+'));
            if (parts.length >= 4) {
              final totalK = int.tryParse(parts[1]) ?? 0;
              final freeK = int.tryParse(parts[3]) ?? 0;
              if (totalK > 0) {
                totalBytes = totalK * 1024;
                freeBytes = freeK * 1024;
              }
            }
          }
        }
      } else if (Platform.isWindows) {
        final res = await Process.run('powershell', [
          '-NoProfile',
          '-Command',
          'Get-PSDrive -PSProvider FileSystem | Select-Object -First 1 Used,Free | ConvertTo-Json',
        ]);
        if (res.exitCode == 0) {
          final data = jsonDecode(res.stdout.toString());
          final used = (data['Used'] as num?)?.toInt() ?? 0;
          final free = (data['Free'] as num?)?.toInt() ?? 0;
          if (used + free > 0) {
            totalBytes = used + free;
            freeBytes = free;
          }
        }
      }
    } catch (_) {}

    int usedBytes = totalBytes - freeBytes;
    if (usedBytes < appBytes) usedBytes = appBytes;

    return TxaStorageInfo(
      totalBytes: totalBytes,
      usedBytes: usedBytes,
      freeBytes: freeBytes,
      appBytes: appBytes,
    );
  }

  /// Estimates the size of an HLS episode in bytes
  static Future<int> estimateEpisodeSize(String m3u8Url) async {
    try {
      final response = await _dio.get(m3u8Url);
      final content = response.data.toString();
      final lines = content.split('\n').map((l) => l.trim()).toList();

      // 1. Check if master playlist
      String targetPlaylistUrl = m3u8Url;
      if (content.contains('#EXT-X-STREAM-INF')) {
        String? variantUrl;
        int maxBandwidth = 0;

        for (int i = 0; i < lines.length; i++) {
          if (lines[i].startsWith('#EXT-X-STREAM-INF')) {
            final bwMatch = RegExp(r'BANDWIDTH=(\d+)').firstMatch(lines[i]);
            final bw = bwMatch != null ? int.tryParse(bwMatch.group(1)!) ?? 0 : 0;
            if (i + 1 < lines.length && !lines[i + 1].startsWith('#')) {
              if (bw >= maxBandwidth) {
                maxBandwidth = bw;
                variantUrl = lines[i + 1];
              }
            }
          }
        }

        if (variantUrl != null) {
          if (!variantUrl.startsWith('http')) {
            final uri = Uri.parse(m3u8Url);
            targetPlaylistUrl = uri.resolve(variantUrl).toString();
          } else {
            targetPlaylistUrl = variantUrl;
          }
          final variantRes = await _dio.get(targetPlaylistUrl);
          return await _parseAndEstimateSegments(targetPlaylistUrl, variantRes.data.toString());
        }
      }

      return await _parseAndEstimateSegments(targetPlaylistUrl, content);
    } catch (e) {
      TxaLogger.log('Estimate episode size error: $e', type: 'app');
      // Fallback default ~ 250 MB
      return 250 * 1024 * 1024;
    }
  }

  static Future<int> _parseAndEstimateSegments(String baseUrl, String playlistContent) async {
    final lines = playlistContent.split('\n').map((l) => l.trim()).toList();
    final List<String> segmentUrls = [];
    double totalDurationSec = 0.0;

    for (final line in lines) {
      if (line.startsWith('#EXTINF:')) {
        final durPart = line.substring(8).split(',').first.trim();
        final d = double.tryParse(durPart) ?? 0.0;
        totalDurationSec += d;
      } else if (line.isNotEmpty && !line.startsWith('#')) {
        if (!line.startsWith('http')) {
          final uri = Uri.parse(baseUrl);
          segmentUrls.add(uri.resolve(line).toString());
        } else {
          segmentUrls.add(line);
        }
      }
    }

    if (segmentUrls.isEmpty) return 250 * 1024 * 1024;

    // Sample 2 segments to get average segment size if CDN allows probe
    int sampledBytes = 0;
    int sampledCount = 0;
    final samples = segmentUrls.take(2).toList();

    for (final url in samples) {
      try {
        final headRes = await _dio.head(url);
        final lenStr = headRes.headers.value('content-length');
        if (lenStr != null) {
          final len = int.tryParse(lenStr) ?? 0;
          if (len > 0) {
            sampledBytes += len;
            sampledCount++;
            continue;
          }
        }

        // Fallback: Range request 0-0
        final rangeRes = await _dio.get(
          url,
          options: Options(headers: {'Range': 'bytes=0-0'}),
        );
        final cr = rangeRes.headers.value('content-range');
        if (cr != null) {
          final match = RegExp(r'/(\d+)').firstMatch(cr);
          if (match != null) {
            final len = int.tryParse(match.group(1)!) ?? 0;
            if (len > 0) {
              sampledBytes += len;
              sampledCount++;
            }
          }
        }
      } catch (_) {}
    }

    if (sampledCount > 0) {
      final avgSegmentBytes = (sampledBytes / sampledCount).round();
      return avgSegmentBytes * segmentUrls.length;
    }

    // Estimate based on true video duration at ~1850 kbps
    if (totalDurationSec > 0) {
      return ((1850 * 1000 / 8) * totalDurationSec).round();
    }

    // Fallback: estimate based on segment count (~1.2MB per segment average for 1080p/720p)
    return segmentUrls.length * 1250 * 1024;
  }
}
