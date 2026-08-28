import 'txa_download_status.dart';

class TxaDownloadTask {
  final String id; // format: {filmSlug}_{serverName}_{episodeName}
  final String filmSlug;
  final String filmTitle;
  final String filmPoster;
  final String serverName;
  final String episodeId;
  final String episodeName;
  final String m3u8Url;
  int totalBytes;
  int downloadedBytes;
  int totalSegments;
  int downloadedSegments;
  TxaDownloadStatus status;
  int statusCode;
  String localPath; // final .mp4 or .ts file path
  String localBaseDir; // directory containing segments and metadata
  double speed; // bytes per second
  int eta; // seconds remaining
  String? errorMessage;
  final DateTime createdAt;
  DateTime? completedAt;

  TxaDownloadTask({
    required this.id,
    required this.filmSlug,
    required this.filmTitle,
    required this.filmPoster,
    required this.serverName,
    required this.episodeId,
    required this.episodeName,
    required this.m3u8Url,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    this.totalSegments = 0,
    this.downloadedSegments = 0,
    this.status = TxaDownloadStatus.queued,
    this.statusCode = 0,
    this.localPath = '',
    this.localBaseDir = '',
    this.speed = 0.0,
    this.eta = 0,
    this.errorMessage,
    DateTime? createdAt,
    this.completedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get progress {
    if (totalBytes > 0 && downloadedBytes > 0) {
      return (downloadedBytes / totalBytes).clamp(0.0, 1.0);
    }
    if (totalSegments > 0 && downloadedSegments > 0) {
      return (downloadedSegments / totalSegments).clamp(0.0, 1.0);
    }
    return 0.0;
  }

  bool get isCompleted => status == TxaDownloadStatus.completed || statusCode == TxaDownloadStatusCode.success;
  bool get isFailed => status == TxaDownloadStatus.failed;
  bool get isDownloading => status == TxaDownloadStatus.downloading || status == TxaDownloadStatus.merging;
  String get localFilePath => localPath;

  String get localizedStatusMessage {
    if (isCompleted) {
      return TxaDownloadStatusCode.getErrorMessage(TxaDownloadStatusCode.success);
    }
    if (isFailed) {
      return TxaDownloadStatusCode.getErrorMessage(statusCode != 0 ? statusCode : TxaDownloadStatusCode.unknown);
    }
    return '';
  }

  TxaDownloadTask copyWith({
    String? id,
    String? filmSlug,
    String? filmTitle,
    String? filmPoster,
    String? serverName,
    String? episodeId,
    String? episodeName,
    String? m3u8Url,
    int? totalBytes,
    int? downloadedBytes,
    int? totalSegments,
    int? downloadedSegments,
    TxaDownloadStatus? status,
    int? statusCode,
    String? localPath,
    String? localBaseDir,
    double? speed,
    int? eta,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return TxaDownloadTask(
      id: id ?? this.id,
      filmSlug: filmSlug ?? this.filmSlug,
      filmTitle: filmTitle ?? this.filmTitle,
      filmPoster: filmPoster ?? this.filmPoster,
      serverName: serverName ?? this.serverName,
      episodeId: episodeId ?? this.episodeId,
      episodeName: episodeName ?? this.episodeName,
      m3u8Url: m3u8Url ?? this.m3u8Url,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalSegments: totalSegments ?? this.totalSegments,
      downloadedSegments: downloadedSegments ?? this.downloadedSegments,
      status: status ?? this.status,
      statusCode: statusCode ?? this.statusCode,
      localPath: localPath ?? this.localPath,
      localBaseDir: localBaseDir ?? this.localBaseDir,
      speed: speed ?? this.speed,
      eta: eta ?? this.eta,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'filmSlug': filmSlug,
      'filmTitle': filmTitle,
      'filmPoster': filmPoster,
      'serverName': serverName,
      'episodeId': episodeId,
      'episodeName': episodeName,
      'm3u8Url': m3u8Url,
      'totalBytes': totalBytes,
      'downloadedBytes': downloadedBytes,
      'totalSegments': totalSegments,
      'downloadedSegments': downloadedSegments,
      'status': status.toDbString(),
      'statusCode': statusCode,
      'localPath': localPath,
      'localBaseDir': localBaseDir,
      'errorMessage': errorMessage,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory TxaDownloadTask.fromMap(Map<String, dynamic> map) {
    return TxaDownloadTask(
      id: map['id']?.toString() ?? '',
      filmSlug: map['filmSlug']?.toString() ?? '',
      filmTitle: map['filmTitle']?.toString() ?? '',
      filmPoster: map['filmPoster']?.toString() ?? '',
      serverName: map['serverName']?.toString() ?? '',
      episodeId: map['episodeId']?.toString() ?? '',
      episodeName: map['episodeName']?.toString() ?? '',
      m3u8Url: map['m3u8Url']?.toString() ?? '',
      totalBytes: int.tryParse(map['totalBytes']?.toString() ?? '0') ?? 0,
      downloadedBytes: int.tryParse(map['downloadedBytes']?.toString() ?? '0') ?? 0,
      totalSegments: int.tryParse(map['totalSegments']?.toString() ?? '0') ?? 0,
      downloadedSegments: int.tryParse(map['downloadedSegments']?.toString() ?? '0') ?? 0,
      status: TxaDownloadStatus.fromDbString(map['status']?.toString()),
      statusCode: int.tryParse(map['statusCode']?.toString() ?? '0') ?? 0,
      localPath: map['localPath']?.toString() ?? '',
      localBaseDir: map['localBaseDir']?.toString() ?? '',
      errorMessage: map['errorMessage']?.toString(),
      createdAt: map['createdAt'] != null ? DateTime.tryParse(map['createdAt'].toString()) : null,
      completedAt: map['completedAt'] != null ? DateTime.tryParse(map['completedAt'].toString()) : null,
    );
  }
}
