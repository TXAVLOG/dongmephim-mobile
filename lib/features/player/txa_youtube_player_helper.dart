import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class TxaYoutubePlayerHelper {
  /// Trích xuất Video ID từ mọi định dạng URL YouTube
  static String? extractYoutubeVideoId(String url) {
    if (url.isEmpty) return null;
    final cleanUrl = url.trim();

    // 1. Dạng youtu.be/ID
    final shortRegex = RegExp(r'youtu\.be\/([a-zA-Z0-9_\-]{11})');
    final shortMatch = shortRegex.firstMatch(cleanUrl);
    if (shortMatch != null) return shortMatch.group(1);

    // 2. Dạng youtube.com/watch?v=ID hoặc youtube.com/shorts/ID hoặc youtube.com/embed/ID
    final standardRegex = RegExp(r'(?:v=|\/embed\/|\/shorts\/)([a-zA-Z0-9_\-]{11})');
    final standardMatch = standardRegex.firstMatch(cleanUrl);
    if (standardMatch != null) return standardMatch.group(1);

    return null;
  }

  /// Tạo mã HTML nhúng YouTube an toàn chống lỗi 152-4 / 150
  static String buildSafeYoutubeEmbedHtml({
    required String videoId,
    String origin = 'https://dongmephim.online',
    bool autoPlay = true,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; background-color: #000; overflow: hidden; }
    #player-container { width: 100%; height: 100%; display: flex; align-items: center; justify-content: center; }
    iframe { width: 100%; height: 100%; border: 0; }
  </style>
</head>
<body>
  <div id="player-container">
    <div id="player"></div>
  </div>

  <script src="https://www.youtube.com/iframe_api"></script>
  <script>
    var player;
    function onYouTubeIframeAPIReady() {
      player = new YT.Player('player', {
        height: '100%',
        width: '100%',
        videoId: '$videoId',
        playerVars: {
          'autoplay': ${autoPlay ? 1 : 0},
          'playsinline': 1,
          'controls': 1,
          'rel': 0,
          'modestbranding': 1,
          'enablejsapi': 1,
          'origin': '$origin',
          'widget_referrer': '$origin'
        },
        events: {
          'onReady': onPlayerReady,
          'onStateChange': onPlayerStateChange,
          'onError': onPlayerError
        }
      });
    }

    function onPlayerReady(event) {
      if (${autoPlay ? 1 : 0}) {
        event.target.playVideo();
      }
      try {
        TxaYoutubeChannel.postMessage(JSON.stringify({ event: 'ready' }));
      } catch(e) {}
    }

    function onPlayerStateChange(event) {
      try {
        // YT.PlayerState.ENDED = 0
        if (event.data === 0) {
          TxaYoutubeChannel.postMessage(JSON.stringify({ event: 'ended' }));
        }
      } catch(e) {}
    }

    // Fix lỗi 152-4 / 150 / 101 / 2: Tự động phát hiện lỗi và báo cho Flutter auto-skip
    function onPlayerError(event) {
      console.warn('[TxaPlayer] YouTube Player Error Code:', event.data);
      try {
        TxaYoutubeChannel.postMessage(JSON.stringify({
          event: 'error',
          code: event.data,
          message: 'Lỗi phát video YouTube (' + event.data + ')'
        }));
      } catch(e) {}
    }
  </script>
</body>
</html>
''';
  }

  /// Cấu hình WebViewController chuẩn chống lỗi 152-4
  static WebViewController createConfiguredController({
    required String videoId,
    required VoidCallback onEnded,
    required VoidCallback onAutoSkip,
    String origin = 'https://dongmephim.online',
  }) {
    final controller = WebViewController();

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent("Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36")
      ..setBackgroundColor(const Color(0xFF000000))
      ..addJavaScriptChannel(
        'TxaYoutubeChannel',
        onMessageReceived: (JavaScriptMessage message) {
          try {
            final data = jsonDecode(message.message);
            final event = data['event'];
            if (event == 'ended') {
              onEnded();
            } else if (event == 'error') {
              debugPrint('[TxaPlayer] Bắt lỗi YouTube 152-4/150 -> Tự động Auto-Skip vào phim.');
              onAutoSkip();
            }
          } catch (e) {
            debugPrint('[TxaPlayer] Lỗi parse JS Channel message: $e');
          }
        },
      );

    final html = buildSafeYoutubeEmbedHtml(videoId: videoId, origin: origin);
    controller.loadHtmlString(html, baseUrl: origin);

    return controller;
  }
}
