import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class TxaPathResolver {
  /// Sanitize a string to be a safe directory/file name across all OSes
  static String sanitize(String input) {
    var safe = input.trim();
    // Replace forbidden characters with underscore
    safe = safe.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    // Remove consecutive underscores or spaces
    safe = safe.replaceAll(RegExp(r'[\s_]+'), '_');
    // Trim underscores from edges
    safe = safe.replaceAll(RegExp(r'^_+|_+$'), '');
    if (safe.isEmpty) return 'untitled';
    // Limit length to 64 chars
    if (safe.length > 64) {
      safe = safe.substring(0, 64);
    }
    return safe;
  }

  /// Get the root download directory for DongMePhim
  static Future<Directory> getDownloadsRootDir() async {
    Directory baseDir;

    if (Platform.isAndroid) {
      // Prefer external storage app directory on Android
      final ext = await getExternalStorageDirectory();
      baseDir = ext ?? await getApplicationDocumentsDirectory();
    } else if (Platform.isWindows) {
      final winDownloads = await getDownloadsDirectory();
      baseDir = winDownloads ?? await getApplicationDocumentsDirectory();
    } else {
      // iOS / macOS / Linux
      baseDir = await getApplicationDocumentsDirectory();
    }

    final rootDir = Directory(p.join(baseDir.path, 'DongMePhim_Downloads'));
    if (!await rootDir.exists()) {
      await rootDir.create(recursive: true);
    }
    return rootDir;
  }

  /// Build base directory for a specific episode download
  static Future<Directory> getEpisodeBaseDir({
    required String filmTitle,
    required String serverName,
    required String episodeName,
  }) async {
    final root = await getDownloadsRootDir();
    final safeFilm = sanitize(filmTitle);
    final safeServer = sanitize(serverName);
    final safeEpisode = sanitize(episodeName);

    final dir = Directory(p.join(root.path, safeFilm, safeServer, safeEpisode));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Build destination merged video file path (.mp4 or .ts)
  static Future<File> getMergedOutputFile({
    required String filmTitle,
    required String serverName,
    required String episodeName,
    String extension = 'mp4',
  }) async {
    final episodeDir = await getEpisodeBaseDir(
      filmTitle: filmTitle,
      serverName: serverName,
      episodeName: episodeName,
    );
    final safeEpisode = sanitize(episodeName);
    return File(p.join(episodeDir.path, '$safeEpisode.$extension'));
  }
}
