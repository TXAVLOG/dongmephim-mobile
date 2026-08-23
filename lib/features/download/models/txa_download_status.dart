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
