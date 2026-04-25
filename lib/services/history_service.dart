import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import '../models/reading_history.dart';
import 'database_helper.dart';

class HistoryService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _uuid = const Uuid();

  Future<List<ReadingHistory>> getAllHistory() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableReadingHistory,
      orderBy: 'openedAt DESC',
    );
    return maps.map((map) => ReadingHistory.fromMap(map)).toList();
  }

  Future<List<ReadingHistory>> getHistoryForPdf(String pdfId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableReadingHistory,
      where: 'pdfId = ?',
      whereArgs: [pdfId],
      orderBy: 'openedAt DESC',
    );
    return maps.map((map) => ReadingHistory.fromMap(map)).toList();
  }

  Future<ReadingHistory> logPdfOpened({
    required String pdfId,
    required int pageNumber,
    required int totalPages,
  }) async {
    final db = await _dbHelper.database;
    final history = ReadingHistory(
      id: _uuid.v4(),
      pdfId: pdfId,
      pageNumber: pageNumber > 0 ? pageNumber : 1,
      totalPages: totalPages > 0 ? totalPages : 1,
      openedAt: DateTime.now(),
    );

    await db.insert(
      DatabaseHelper.tableReadingHistory,
      history.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return history;
  }

  Future<void> deleteHistoryEntry(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      DatabaseHelper.tableReadingHistory,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteAllHistoryForPdf(String pdfId) async {
    final db = await _dbHelper.database;
    await db.delete(
      DatabaseHelper.tableReadingHistory,
      where: 'pdfId = ?',
      whereArgs: [pdfId],
    );
  }

  Future<void> clearAllHistory() async {
    final db = await _dbHelper.database;
    await db.delete(DatabaseHelper.tableReadingHistory);
  }

  Future<List<ReadingHistory>> getHistoryForDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableReadingHistory,
      where: 'openedAt >= ? AND openedAt <= ?',
      whereArgs: [
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ],
      orderBy: 'openedAt DESC',
    );
    return maps.map((map) => ReadingHistory.fromMap(map)).toList();
  }

  Future<List<ReadingHistory>> getTodayHistory() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return getHistoryForDateRange(start, end);
  }

  Future<List<ReadingHistory>> getYesterdayHistory() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    final end = start.add(const Duration(days: 1));
    return getHistoryForDateRange(start, end);
  }

  Future<List<ReadingHistory>> getLast7DaysHistory() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
    final end = DateTime(now.year, now.month, now.day);
    return getHistoryForDateRange(start, end);
  }

  Future<void> deleteHistoryForPdf(String pdfId) async {
    final db = await _dbHelper.database;
    await db.delete(
      DatabaseHelper.tableReadingHistory,
      where: 'pdfId = ?',
      whereArgs: [pdfId],
    );
  }
}
