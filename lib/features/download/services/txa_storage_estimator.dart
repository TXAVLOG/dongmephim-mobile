import 'dart:async';
import 'package:dio/dio.dart';
import '../../../utils/txa_logger.dart';

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

    for (final line in lines) {
      if (line.isNotEmpty && !line.startsWith('#')) {
        if (!line.startsWith('http')) {
          final uri = Uri.parse(baseUrl);
          segmentUrls.add(uri.resolve(line).toString());
        } else {
          segmentUrls.add(line);
        }
      }
    }

    if (segmentUrls.isEmpty) return 200 * 1024 * 1024;

    // Sample 2 segments to get average segment size
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

    // Default estimate if CDN blocks probe: ~800KB per segment
    return segmentUrls.length * 800 * 1024;
  }
}
