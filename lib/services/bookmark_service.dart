import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/bookmark.dart';
import 'database_helper.dart';

class BookmarkService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _uuid = const Uuid();

  Future<List<Bookmark>> getAllBookmarks() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableBookmarks,
      orderBy: 'createdAt DESC',
    );
    return maps.map((map) => Bookmark.fromMap(map)).toList();
  }

  Future<List<Bookmark>> getBookmarksForPdf(String pdfId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableBookmarks,
      where: 'pdfId = ?',
      whereArgs: [pdfId],
      orderBy: 'pageNumber ASC',
    );
    return maps.map((map) => Bookmark.fromMap(map)).toList();
  }

  Future<Bookmark?> getBookmark(String pdfId, int pageNumber) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableBookmarks,
      where: 'pdfId = ? AND pageNumber = ?',
      whereArgs: [pdfId, pageNumber],
    );
    if (maps.isNotEmpty) {
      return Bookmark.fromMap(maps.first);
    }
    return null;
  }

  Future<bool> isPageBookmarked(String pdfId, int pageNumber) async {
    final bookmark = await getBookmark(pdfId, pageNumber);
    return bookmark != null;
  }

  Future<Bookmark> addBookmark({
    required String pdfId,
    required int pageNumber,
    String? pageTitle,
    String? thumbnailPath,
  }) async {
    final db = await _dbHelper.database;
    final bookmark = Bookmark(
      id: _uuid.v4(),
      pdfId: pdfId,
      pageNumber: pageNumber,
      pageTitle: pageTitle,
      thumbnailPath: thumbnailPath,
    );

    await db.insert(
      DatabaseHelper.tableBookmarks,
      bookmark.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return bookmark;
  }

  Future<void> removeBookmark(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      DatabaseHelper.tableBookmarks,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> removeBookmarkByPage(String pdfId, int pageNumber) async {
    final db = await _dbHelper.database;
    await db.delete(
      DatabaseHelper.tableBookmarks,
      where: 'pdfId = ? AND pageNumber = ?',
      whereArgs: [pdfId, pageNumber],
    );
  }

  Future<void> toggleBookmark({
    required String pdfId,
    required int pageNumber,
    String? pageTitle,
    String? thumbnailPath,
  }) async {
    final existing = await getBookmark(pdfId, pageNumber);
    if (existing != null) {
      await removeBookmark(existing.id);
    } else {
      await addBookmark(
        pdfId: pdfId,
        pageNumber: pageNumber,
        pageTitle: pageTitle,
        thumbnailPath: thumbnailPath,
      );
    }
  }

  Future<void> updateBookmarkThumbnail(String id, String thumbnailPath) async {
    final db = await _dbHelper.database;
    await db.update(
      DatabaseHelper.tableBookmarks,
      {'thumbnailPath': thumbnailPath},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> getBookmarkCount(String pdfId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseHelper.tableBookmarks} WHERE pdfId = ?',
      [pdfId],
    );
    return result.first['count'] as int;
  }

  Future<void> deleteAllBookmarksForPdf(String pdfId) async {
    final db = await _dbHelper.database;
    await db.delete(
      DatabaseHelper.tableBookmarks,
      where: 'pdfId = ?',
      whereArgs: [pdfId],
    );
  }
}
