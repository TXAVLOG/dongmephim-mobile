import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../services/txa_language.dart';

enum TxaDownloadStatus {
  queued,
  downloading,
  merging,
  completed,
  paused,
  failed;

  String toDbString() => name;

  static TxaDownloadStatus fromDbString(String? val) {
    if (val == null) return TxaDownloadStatus.queued;
    for (final s in TxaDownloadStatus.values) {
      if (s.name == val) return s;
    }
    return TxaDownloadStatus.queued;
  }
}

class TxaDownloadStatusCode {
  static const int success = 2311;
  static const int networkError = 3667;
  static const int storageFull = 36;
  static const int forbidden = 403;
  static const int notFound = 404;
  static const int rateLimit = 429;
  static const int serverError = 500;
  static const int unknown = 0;

  /// Phân tích Exception sang mã lỗi chuẩn của hệ thống
  static int parseErrorCode(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          return networkError; // 3667
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          if (statusCode == 403) return forbidden;
          if (statusCode == 404) return notFound;
          if (statusCode == 429) return rateLimit;
          if (statusCode != null && statusCode >= 500) return serverError;
          return unknown;
        case DioExceptionType.cancel:
          return unknown;
        default:
          if (error.error is SocketException || error.error is HandshakeException) {
            return networkError;
          }
          return unknown;
      }
    } else if (error is FileSystemException) {
      if (error.osError?.errorCode == 28 || error.message.toLowerCase().contains('space')) {
        return storageFull; // 36
      }
      return unknown;
    }
    return unknown;
  }

  /// Trả về thông báo lỗi đa ngôn ngữ từ TxaLanguage
  static String getErrorMessage(int code) {
    return TxaLanguage.getDownloadStatusMessage(code);
  }
}
