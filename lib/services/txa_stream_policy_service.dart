import 'dart:async';
import 'package:http/http.dart' as http;
import '../utils/txa_logger.dart';

class TxaStreamPolicyService {
  /// Resolves the final stream URL based on package policies.
  /// If packageSystemEnable is true and userPlan is 'free', it will attempt to
  /// parse the HLS master playlist and return the track with the lowest bandwidth.
  /// Otherwise, it returns the original URL.
  static Future<String> resolveStreamUrl(
    String originalUrl, {
    required bool packageSystemEnable,
    required String userPlan,
  }) async {
    // 1. Điều kiện áp dụng
    if (!packageSystemEnable || userPlan.toLowerCase() != 'free') {
      return originalUrl;
    }

    // Chỉ hỗ trợ HLS m3u8
    if (!originalUrl.toLowerCase().contains('.m3u8')) {
      return originalUrl;
    }

    try {
      TxaLogger.log('TxaStreamPolicyService: Bắt đầu ép chất lượng cho tài khoản Free ($originalUrl)', type: 'policy');

      // 2. Fetch master playlist
      final uri = Uri.parse(originalUrl);
      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        TxaLogger.log('TxaStreamPolicyService: Lỗi tải playlist (HTTP ${response.statusCode})', type: 'policy');
        return originalUrl;
      }

      final body = response.body;

      // Check if it's a valid master playlist
      if (!body.contains('#EXTM3U')) {
        return originalUrl;
      }

      final lines = body.split('\n');
      int lowestBandwidth = -1;
      String? lowestUrl;

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.startsWith('#EXT-X-STREAM-INF:')) {
          // Extract BANDWIDTH attribute
          final bwMatch = RegExp(r'BANDWIDTH=(\d+)').firstMatch(line);
          if (bwMatch != null) {
            final bw = int.tryParse(bwMatch.group(1) ?? '0') ?? 0;
            
            // The next non-empty, non-comment line should be the URL
            String? trackUrl;
            for (int j = i + 1; j < lines.length; j++) {
              final nextLine = lines[j].trim();
              if (nextLine.isNotEmpty && !nextLine.startsWith('#')) {
                trackUrl = nextLine;
                break;
              }
            }

            if (trackUrl != null && trackUrl.isNotEmpty) {
              if (lowestBandwidth == -1 || bw < lowestBandwidth) {
                lowestBandwidth = bw;
                lowestUrl = trackUrl;
              }
            }
          }
        }
      }

      if (lowestUrl != null) {
        // Resolve to absolute URL
        String absoluteUrl;
        if (lowestUrl.startsWith('http://') || lowestUrl.startsWith('https://')) {
          absoluteUrl = lowestUrl;
        } else if (lowestUrl.startsWith('/')) {
          absoluteUrl = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}$lowestUrl';
        } else {
          // Relative path
          final pathSegments = uri.pathSegments.toList();
          if (pathSegments.isNotEmpty) {
            pathSegments.removeLast(); // Remove the last segment (e.g., master.m3u8)
          }
          final basePath = pathSegments.join('/');
          final separator = basePath.isNotEmpty ? '/' : '';
          absoluteUrl = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}/$basePath$separator$lowestUrl';
        }

        TxaLogger.log('TxaStreamPolicyService: Chọn track $lowestBandwidth bps -> $absoluteUrl', type: 'policy');
        return absoluteUrl;
      }

      TxaLogger.log('TxaStreamPolicyService: Không tìm thấy track đa bitrate', type: 'policy');
      return originalUrl;
    } catch (e) {
      // 3. Fallback bắt buộc: nếu lỗi thì không throw, return URL gốc
      TxaLogger.log('TxaStreamPolicyService: Lỗi xử lý policy: $e', type: 'crash');
      return originalUrl;
    }
  }
}
