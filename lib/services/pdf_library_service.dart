import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '../models/pdf_document.dart';
import 'database_helper.dart';

class PdfLibraryService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _uuid = const Uuid();

  Future<List<PdfDocument>> getAllDocuments() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tablePdfDocuments,
      orderBy: 'lastOpenedAt DESC',
    );
    return maps.map((map) => PdfDocument.fromMap(map)).toList();
  }

  Future<List<PdfDocument>> getRecentlyOpened({int limit = 10}) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tablePdfDocuments,
      orderBy: 'lastOpenedAt DESC',
      limit: limit,
    );
    return maps.map((map) => PdfDocument.fromMap(map)).toList();
  }

  Future<List<PdfDocument>> getInProgressDocuments() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tablePdfDocuments,
      where: 'readingProgress > 0 AND readingProgress < 1',
      orderBy: 'lastOpenedAt DESC',
    );
    return maps.map((map) => PdfDocument.fromMap(map)).toList();
  }

  Future<PdfDocument?> getDocument(String id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tablePdfDocuments,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return PdfDocument.fromMap(maps.first);
    }
    return null;
  }

  Future<PdfDocument> addDocument({
    required String filePath,
    required String fileName,
    required int fileSize,
    required int totalPages,
  }) async {
    final db = await _dbHelper.database;
    final document = PdfDocument(
      id: _uuid.v4(),
      filePath: filePath,
      fileName: fileName,
      fileSize: fileSize,
      totalPages: totalPages,
      lastOpenedAt: DateTime.now(),
    );

    await db.insert(
      DatabaseHelper.tablePdfDocuments,
      document.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return document;
  }

  Future<void> updateDocument(PdfDocument document) async {
    final db = await _dbHelper.database;
    await db.update(
      DatabaseHelper.tablePdfDocuments,
      document.toMap(),
      where: 'id = ?',
      whereArgs: [document.id],
    );
  }

  Future<void> deleteDocument(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      DatabaseHelper.tablePdfDocuments,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateReadingProgress(
    String id,
    int currentPage,
    int totalPages,
  ) async {
    final progress = totalPages > 0 ? currentPage / totalPages : 0.0;
    final db = await _dbHelper.database;
    await db.update(
      DatabaseHelper.tablePdfDocuments,
      {
        'lastOpenedPage': currentPage,
        'readingProgress': progress,
        'lastOpenedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateCoverThumbnail(String id, String thumbnailPath) async {
    final db = await _dbHelper.database;
    await db.update(
      DatabaseHelper.tablePdfDocuments,
      {'coverThumbnailPath': thumbnailPath},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<String> getThumbnailsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final thumbnailsDir = Directory(path.join(appDir.path, 'thumbnails'));
    if (!await thumbnailsDir.exists()) {
      await thumbnailsDir.create(recursive: true);
    }
    return thumbnailsDir.path;
  }

  Future<bool> documentExists(String filePath) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tablePdfDocuments,
      where: 'filePath = ?',
      whereArgs: [filePath],
    );
    return maps.isNotEmpty;
  }

  Future<void> updateFilePath(String id, String newFilePath) async {
    final db = await _dbHelper.database;
    await db.update(
      DatabaseHelper.tablePdfDocuments,
      {'filePath': newFilePath},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
