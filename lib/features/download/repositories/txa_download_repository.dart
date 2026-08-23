import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/txa_download_status.dart';
import '../models/txa_download_task.dart';
import '../../../utils/txa_logger.dart';

class TxaDownloadRepository {
  static final TxaDownloadRepository _instance = TxaDownloadRepository._internal();
  factory TxaDownloadRepository() => _instance;
  TxaDownloadRepository._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'txa_offline_downloads.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE download_tasks (
            id TEXT PRIMARY KEY,
            filmSlug TEXT NOT NULL,
            filmTitle TEXT NOT NULL,
            filmPoster TEXT,
            serverName TEXT,
            episodeId TEXT,
            episodeName TEXT NOT NULL,
            m3u8Url TEXT NOT NULL,
            totalBytes INTEGER,
            downloadedBytes INTEGER,
            totalSegments INTEGER,
            downloadedSegments INTEGER,
            status TEXT NOT NULL,
            localPath TEXT,
            localBaseDir TEXT,
            errorMessage TEXT,
            createdAt TEXT NOT NULL,
            completedAt TEXT
          )
        ''');
        TxaLogger.log('TxaDownloadRepository database initialized.', type: 'app');
      },
    );
  }

  /// Insert or update task
  Future<void> upsertTask(TxaDownloadTask task) async {
    final db = await database;
    await db.insert(
      'download_tasks',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get single task by ID
  Future<TxaDownloadTask?> getTask(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'download_tasks',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return TxaDownloadTask.fromMap(maps.first);
    }
    return null;
  }

  /// Get all tasks ordered by createdAt DESC
  Future<List<TxaDownloadTask>> getAllTasks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'download_tasks',
      orderBy: 'createdAt DESC',
    );
    return maps.map((m) => TxaDownloadTask.fromMap(m)).toList();
  }

  /// Get tasks for a specific film
  Future<List<TxaDownloadTask>> getTasksByFilm(String filmSlug) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'download_tasks',
      where: 'filmSlug = ?',
      whereArgs: [filmSlug],
      orderBy: 'createdAt ASC',
    );
    return maps.map((m) => TxaDownloadTask.fromMap(m)).toList();
  }

  /// Delete a single task
  Future<int> deleteTask(String id) async {
    final db = await database;
    return await db.delete(
      'download_tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete all tasks for a film
  Future<int> deleteTasksByFilm(String filmSlug) async {
    final db = await database;
    return await db.delete(
      'download_tasks',
      where: 'filmSlug = ?',
      whereArgs: [filmSlug],
    );
  }

  /// Recover interrupted tasks on app start
  Future<void> recoverInterruptedTasks() async {
    final db = await database;
    await db.update(
      'download_tasks',
      {'status': TxaDownloadStatus.paused.toDbString()},
      where: 'status = ? OR status = ?',
      whereArgs: [
        TxaDownloadStatus.downloading.toDbString(),
        TxaDownloadStatus.merging.toDbString(),
      ],
    );
  }
}
