import 'dart:io';
import 'txa_download_manager.dart';

class TxaDownload {
  bool get isDownloading => TxaDownloadManager().isDownloading;
  int get downloadedBytes => TxaDownloadManager().downloadedBytes;
  int get totalBytes => TxaDownloadManager().totalBytes;

  Future<File?> startDownload(
    String url,
    String filename, {
    Function(Map<String, dynamic>)? onProgress,
    bool showNotification = true,
  }) {
    return TxaDownloadManager().startDownload(
      url,
      filename,
      onProgress: onProgress,
      showNotification: showNotification,
    );
  }

  void cancelDownload() {
    TxaDownloadManager().cancelDownload();
  }

  Map<String, dynamic> getProgressInfo() {
    return TxaDownloadManager().getProgressInfo();
  }
}
