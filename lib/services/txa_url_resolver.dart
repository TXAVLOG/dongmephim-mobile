import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class TxaUrlResolver {
  /// Resolves direct file URLs from common hosting services (Google Drive, Mediafire, GitHub)
  static Future<String> resolve(String url) async {
    final trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty) return url;

    try {
      // 1. Google Drive
      if (trimmedUrl.contains('drive.google.com')) {
        final resolved = _resolveGoogleDrive(trimmedUrl);
        if (resolved != null) {
          debugPrint('Resolved Google Drive URL: $resolved');
          return resolved;
        }
      }

      // 2. Mediafire
      if (trimmedUrl.contains('mediafire.com')) {
        final resolved = await _resolveMediafire(trimmedUrl);
        if (resolved != null) {
          debugPrint('Resolved Mediafire URL: $resolved');
          return resolved;
        }
      }

      // 3. GitHub Blob to Raw
      if (trimmedUrl.contains('github.com') && trimmedUrl.contains('/blob/')) {
        final resolved = trimmedUrl
            .replaceFirst('github.com', 'raw.githubusercontent.com')
            .replaceFirst('/blob/', '/');
        debugPrint('Resolved GitHub Blob URL to Raw: $resolved');
        return resolved;
      }
    } catch (e) {
      debugPrint('Error resolving URL ($url): $e');
    }

    return trimmedUrl;
  }

  static String? _resolveGoogleDrive(String url) {
    // Matches patterns: drive.google.com/file/d/FILE_ID/view or open?id=FILE_ID
    final RegExp regExp1 = RegExp(r'\/d\/([a-zA-Z0-9_-]{25,})');
    final RegExp regExp2 = RegExp(r'id=([a-zA-Z0-9_-]{25,})');
    
    String? fileId;
    if (regExp1.hasMatch(url)) {
      fileId = regExp1.firstMatch(url)?.group(1);
    } else if (regExp2.hasMatch(url)) {
      fileId = regExp2.firstMatch(url)?.group(1);
    }

    if (fileId != null) {
      return 'https://drive.google.com/uc?export=download&id=$fileId';
    }
    return null;
  }

  static Future<String?> _resolveMediafire(String url) async {
    try {
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      });
      if (response.statusCode == 200) {
        final body = response.body;
        // Search for the direct download link inside the HTML page
        // Format example: href="https://download123.mediafire.com/xxxx/filename.apk"
        final RegExp regExp = RegExp(r'href="https?:\/\/download[a-zA-Z0-9\-\.]+\.mediafire\.com\/[a-zA-Z0-9_\-\.\/]+"');
        if (regExp.hasMatch(body)) {
          final match = regExp.firstMatch(body)?.group(0);
          if (match != null) {
            final start = match.indexOf('http');
            final end = match.lastIndexOf('"');
            if (start != -1 && end != -1) {
              return match.substring(start, end);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to resolve Mediafire webpage: $e');
    }
    return null;
  }
}
