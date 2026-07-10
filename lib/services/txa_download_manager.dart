import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'txa_url_resolver.dart';
import '../utils/txa_format.dart';

class TxaDownloadManager extends ChangeNotifier {
  static final TxaDownloadManager _instance = TxaDownloadManager._internal();
  factory TxaDownloadManager() => _instance;
  TxaDownloadManager._internal();

  bool _isDownloading = false;
  bool _isPaused = false;
  int _downloadedBytes = 0;
  int _totalBytes = 0;
  double _speed = 0.0; // bytes/sec
  int _eta = 0; // seconds

  http.Client? _client;
  IOSink? _fileSink;
  File? _tempFile;

  bool get isDownloading => _isDownloading;
  bool get isPaused => _isPaused;
  int get downloadedBytes => _downloadedBytes;
  int get totalBytes => _totalBytes;
  double get speed => _speed;
  int get eta => _eta;

  double get progress => _totalBytes > 0 ? _downloadedBytes / _totalBytes : 0.0;

  /// Starts downloading a file, with automatic resumption support if a partial file already exists.
  Future<File?> startDownload(
    String url,
    String filename, {
    Function(Map<String, dynamic>)? onProgress,
    bool showNotification = true,
  }) async {
    if (_isDownloading && !_isPaused) {
      debugPrint('A download is already in progress.');
      return null;
    }

    _isDownloading = true;
    _isPaused = false;
    _speed = 0.0;
    _eta = 0;
    notifyListeners();

    try {
      // 1. Resolve URL (Google Drive, Mediafire, GitHub)
      final resolvedUrl = await TxaUrlResolver.resolve(url);
      
      // 2. Get temp directory path
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/$filename';
      _tempFile = File(filePath);

      // 3. Check existing bytes for resumption
      int existingLength = 0;
      if (await _tempFile!.exists()) {
        existingLength = await _tempFile!.length();
        debugPrint('Found partially downloaded file size: $existingLength bytes');
      }

      // 4. Initialize HTTP request
      _client = http.Client();
      final request = http.Request('GET', Uri.parse(resolvedUrl));
      
      if (existingLength > 0) {
        request.headers['Range'] = 'bytes=$existingLength-';
      }

      // 5. Send request
      final response = await _client!.send(request);
      
      // 6. Handle response status codes
      if (response.statusCode == 206) {
        _totalBytes = existingLength + (response.contentLength ?? 0);
        _fileSink = _tempFile!.openWrite(mode: FileMode.writeOnlyAppend);
        debugPrint('Server accepted Range request. Resuming download...');
      } else if (response.statusCode == 200) {
        existingLength = 0;
        _totalBytes = response.contentLength ?? 0;
        _fileSink = _tempFile!.openWrite(mode: FileMode.write);
        debugPrint('Server returned full content (200). Starting fresh...');
      } else {
        throw HttpException('Server returned status code ${response.statusCode}');
      }

      _downloadedBytes = existingLength;
      notifyListeners();

      // 7. Track speed and ETA
      final stopwatch = Stopwatch()..start();
      int lastDownloaded = _downloadedBytes;
      int lastTimeMs = stopwatch.elapsedMilliseconds;

      // 8. Write stream chunks to file
      await for (final chunk in response.stream) {
        if (!_isDownloading || _isPaused) {
          debugPrint('Download stream interrupted. isDownloading=$_isDownloading, isPaused=$_isPaused');
          break;
        }

        _fileSink!.add(chunk);
        _downloadedBytes += chunk.length;

        // Calculate speed & ETA every 500ms
        final nowMs = stopwatch.elapsedMilliseconds;
        if (nowMs - lastTimeMs >= 500) {
          final double timeDiffSec = (nowMs - lastTimeMs) / 1000.0;
          final int bytesDiff = _downloadedBytes - lastDownloaded;
          
          if (timeDiffSec > 0) {
            _speed = bytesDiff / timeDiffSec;
            final remainingBytes = _totalBytes - _downloadedBytes;
            _eta = _speed > 0 ? (remainingBytes / _speed).ceil() : 0;
          }

          lastDownloaded = _downloadedBytes;
          lastTimeMs = nowMs;
          notifyListeners();
        }

        // Invoke progress callback
        if (onProgress != null) {
          onProgress(getProgressInfo());
        }
      }

      // 9. Close file sink and HTTP client
      await _fileSink!.flush();
      await _fileSink!.close();
      _fileSink = null;
      _client!.close();
      _client = null;

      if (_isPaused) {
        debugPrint('Download paused successfully at $_downloadedBytes bytes.');
        return null;
      }

      if (!_isDownloading) {
        // Download was canceled, delete partial file
        if (await _tempFile!.exists()) {
          await _tempFile!.delete();
        }
        debugPrint('Download canceled and file deleted.');
        return null;
      }

      // Validate download completion
      if (_downloadedBytes == _totalBytes && _totalBytes > 0) {
        debugPrint('Download completed successfully. Saved to: ${_tempFile!.path}');
        _isDownloading = false;
        notifyListeners();
        return _tempFile;
      } else {
        throw HttpException('Download connection ended prematurely. Got $_downloadedBytes of $_totalBytes bytes.');
      }
    } catch (e) {
      debugPrint('Download manager error: $e');
      _cleanUp();
      rethrow;
    }
  }

  /// Pauses the active download, preserving the partially downloaded file content.
  void pauseDownload() {
    if (_isDownloading && !_isPaused) {
      _isPaused = true;
      notifyListeners();
    }
  }

  /// Cancels the active download and deletes any temporary file parts.
  void cancelDownload() {
    _isDownloading = false;
    _isPaused = false;
    _cleanUp();
    notifyListeners();
  }

  /// Cleans up resources.
  void _cleanUp() {
    try {
      _fileSink?.close();
      _fileSink = null;
      _client?.close();
      _client = null;
      
      if (_tempFile != null && _tempFile!.existsSync()) {
        _tempFile!.deleteSync();
      }
    } catch (e) {
      debugPrint('Error during cleanUp: $e');
    }
  }

  /// Gets structured progress data for UI updates.
  Map<String, dynamic> getProgressInfo() {
    final speedInfo = TxaFormat.formatSpeed(_speed);
    final downloadedStr = TxaFormat.formatDataSize(_downloadedBytes);
    final totalStr = TxaFormat.formatDataSize(_totalBytes);
    final etaStr = _eta > 0 ? '${_eta}s' : '0s';

    return {
      'progress': progress,
      'downloaded': _downloadedBytes,
      'total': _totalBytes,
      'speed': _speed,
      'eta': _eta,
      'isPaused': _isPaused,
      'formatted': {
        'downloaded': downloadedStr,
        'total': totalStr,
        'speed': speedInfo['display'],
        'eta': etaStr,
      },
    };
  }
}
