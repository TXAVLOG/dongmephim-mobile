import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import '../../../utils/txa_logger.dart';

class TxaHlsDownloadProgress {
  final int downloadedSegments;
  final int totalSegments;
  final int downloadedBytes;
  final int totalBytes;
  final double speed; // bytes/sec
  final int eta; // seconds
  final double percent; // 0.0 -> 1.0

  TxaHlsDownloadProgress({
    required this.downloadedSegments,
    required this.totalSegments,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.speed,
    required this.eta,
    required this.percent,
  });
}

class TxaHlsDownloader {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 25),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 12; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      },
    ),
  );

  bool _isPaused = false;
  bool _isCancelled = false;
  CancelToken? _cancelToken;

  bool get isPaused => _isPaused;
  bool get isCancelled => _isCancelled;

  void pause() {
    _isPaused = true;
    _cancelToken?.cancel('PAUSED');
  }

  void cancel() {
    _isCancelled = true;
    _cancelToken?.cancel('CANCELLED');
  }

  /// Download an HLS episode with high concurrency (8-12 parallel segments)
  Future<bool> download({
    required String m3u8Url,
    required Directory baseDir,
    required Function(TxaHlsDownloadProgress progress) onProgress,
    int concurrency = 10,
  }) async {
    _isPaused = false;
    _isCancelled = false;
    _cancelToken = CancelToken();

    try {
      if (!await baseDir.exists()) {
        await baseDir.create(recursive: true);
      }

      // 1. Fetch m3u8 playlist
      final response = await _dio.get(m3u8Url, cancelToken: _cancelToken);
      var content = response.data.toString();
      var targetPlaylistUrl = m3u8Url;

      // 2. Handle master playlist
      if (content.contains('#EXT-X-STREAM-INF')) {
        final lines = content.split('\n').map((l) => l.trim()).toList();
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
          final variantRes = await _dio.get(targetPlaylistUrl, cancelToken: _cancelToken);
          content = variantRes.data.toString();
        }
      }

      // 3. Parse segments
      final lines = content.split('\n');
      final List<String> segmentUrls = [];
      final List<String> rewrittenLines = [];
      int segmentCounter = 0;

      for (var rawLine in lines) {
        final line = rawLine.trim();
        if (line.isNotEmpty && !line.startsWith('#')) {
          String fullSegmentUrl = line;
          if (!line.startsWith('http')) {
            final uri = Uri.parse(targetPlaylistUrl);
            fullSegmentUrl = uri.resolve(line).toString();
          }
          segmentUrls.add(fullSegmentUrl);

          final localSegName = 'seg_${segmentCounter.toString().padLeft(5, '0')}.ts';
          rewrittenLines.add(localSegName);
          segmentCounter++;
        } else {
          rewrittenLines.add(rawLine);
        }
      }

      if (segmentUrls.isEmpty) {
        throw Exception('No video segments found in playlist');
      }

      // 4. Save local playlist.m3u8
      final localPlaylistFile = File(p.join(baseDir.path, 'playlist.m3u8'));
      await localPlaylistFile.writeAsString(rewrittenLines.join('\n'));

      // 5. Check existing completed segments
      final totalSegments = segmentUrls.length;
      int completedSegments = 0;
      int downloadedBytes = 0;

      final List<int> pendingIndices = [];
      for (int i = 0; i < totalSegments; i++) {
        final segFileName = 'seg_${i.toString().padLeft(5, '0')}.ts';
        final segFile = File(p.join(baseDir.path, segFileName));
        if (await segFile.exists() && (await segFile.length()) > 500) {
          completedSegments++;
          downloadedBytes += await segFile.length();
        } else {
          pendingIndices.add(i);
        }
      }

      // Speed & ETA tracking
      int lastBytes = downloadedBytes;
      DateTime lastTime = DateTime.now();
      double currentSpeed = 0.0;

      // 6. Download pending segments with parallel worker pool
      int activeWorkers = 0;
      int nextPendingIndex = 0;
      final completer = Completer<bool>();
      Object? downloadError;

      void updateAndEmitProgress() {
        final now = DateTime.now();
        final deltaMs = now.difference(lastTime).inMilliseconds;
        if (deltaMs >= 800) {
          final deltaBytes = downloadedBytes - lastBytes;
          if (deltaMs > 0) {
            currentSpeed = (deltaBytes / (deltaMs / 1000.0)).clamp(0.0, 100 * 1024 * 1024);
          }
          lastBytes = downloadedBytes;
          lastTime = now;
        }

        // Estimate total bytes
        final estimatedTotalBytes = completedSegments > 0
            ? (downloadedBytes / completedSegments * totalSegments).round()
            : totalSegments * 800 * 1024;
        final remainingBytes = (estimatedTotalBytes - downloadedBytes).clamp(0, estimatedTotalBytes);
        final eta = currentSpeed > 0 ? (remainingBytes / currentSpeed).round() : 0;
        final percent = totalSegments > 0 ? (completedSegments / totalSegments).clamp(0.0, 1.0) : 0.0;

        onProgress(TxaHlsDownloadProgress(
          downloadedSegments: completedSegments,
          totalSegments: totalSegments,
          downloadedBytes: downloadedBytes,
          totalBytes: estimatedTotalBytes,
          speed: currentSpeed,
          eta: eta,
          percent: percent,
        ));
      }

      // Initial progress snapshot
      updateAndEmitProgress();

      Future<void> launchNext() async {
        if (_isPaused || _isCancelled || downloadError != null) return;
        if (nextPendingIndex >= pendingIndices.length) {
          if (activeWorkers == 0 && !completer.isCompleted) {
            completer.complete(true);
          }
          return;
        }

        final segIdx = pendingIndices[nextPendingIndex++];
        final segUrl = segmentUrls[segIdx];
        final segFileName = 'seg_${segIdx.toString().padLeft(5, '0')}.ts';
        final segFile = File(p.join(baseDir.path, segFileName));
        final tempSegFile = File(p.join(baseDir.path, '$segFileName.tmp'));

        activeWorkers++;

        try {
          final res = await _dio.download(
            segUrl,
            tempSegFile.path,
            cancelToken: _cancelToken,
            onReceiveProgress: (rec, tot) {
              // incremental progress
            },
          );

          if (res.statusCode == 200 && await tempSegFile.exists()) {
            final segLen = await tempSegFile.length();
            if (segLen > 0) {
              await tempSegFile.rename(segFile.path);
              completedSegments++;
              downloadedBytes += segLen;
              updateAndEmitProgress();
            }
          }
        } catch (e) {
          if (_isPaused || _isCancelled) {
            // normal pause/cancel, clean temp file
            if (await tempSegFile.exists()) await tempSegFile.delete();
            return;
          }
          // Retry segment once
          try {
            await Future.delayed(const Duration(milliseconds: 500));
            final retryRes = await _dio.download(
              segUrl,
              tempSegFile.path,
              cancelToken: _cancelToken,
            );
            if (retryRes.statusCode == 200 && await tempSegFile.exists()) {
              final segLen = await tempSegFile.length();
              await tempSegFile.rename(segFile.path);
              completedSegments++;
              downloadedBytes += segLen;
              updateAndEmitProgress();
            }
          } catch (retryError) {
            if (!_isPaused && !_isCancelled) {
              downloadError = retryError;
            }
          }
        } finally {
          activeWorkers--;
          if (downloadError != null && !completer.isCompleted) {
            completer.completeError(downloadError!);
          } else {
            launchNext();
          }
        }
      }

      // Spawn initial concurrency workers
      final initialWorkers = concurrency.clamp(4, 16);
      for (int i = 0; i < initialWorkers; i++) {
        launchNext();
      }

      final success = await completer.future;
      return success && completedSegments == totalSegments;
    } catch (e) {
      if (_isPaused || _isCancelled) {
        return false;
      }
      TxaLogger.log('HLS Downloader error: $e', type: 'app');
      rethrow;
    }
  }
}
