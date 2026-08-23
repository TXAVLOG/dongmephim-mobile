import 'txa_download_task.dart';

class TxaLocalFilm {
  final String filmSlug;
  final String filmTitle;
  final String filmPoster;
  final List<TxaDownloadTask> tasks;

  TxaLocalFilm({
    required this.filmSlug,
    required this.filmTitle,
    required this.filmPoster,
    required this.tasks,
  });

  int get completedCount => tasks.where((t) => t.status.name == 'completed').length;
  int get totalCount => tasks.length;
  int get totalBytes => tasks.fold(0, (sum, t) => sum + (t.downloadedBytes > 0 ? t.downloadedBytes : t.totalBytes));
}
