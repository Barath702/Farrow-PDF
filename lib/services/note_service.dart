import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';
import 'database_helper.dart';

class NoteService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _uuid = const Uuid();

  Future<List<Note>> getAllNotes() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableNotes,
      orderBy: 'updatedAt DESC',
    );
    return maps.map((map) => Note.fromMap(map)).toList();
  }

  Future<List<Note>> getNotesForPdf(String pdfId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableNotes,
      where: 'pdfId = ?',
      whereArgs: [pdfId],
      orderBy: 'pageNumber ASC, updatedAt DESC',
    );
    return maps.map((map) => Note.fromMap(map)).toList();
  }

  Future<List<Note>> getNotesForPage(String pdfId, int pageNumber) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableNotes,
      where: 'pdfId = ? AND pageNumber = ?',
      whereArgs: [pdfId, pageNumber],
      orderBy: 'createdAt DESC',
    );
    return maps.map((map) => Note.fromMap(map)).toList();
  }

  Future<Note?> getNote(String id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableNotes,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Note.fromMap(maps.first);
    }
    return null;
  }

  Future<Note> addNote({
    required String pdfId,
    required int pageNumber,
    required String noteText,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final note = Note(
      id: _uuid.v4(),
      pdfId: pdfId,
      pageNumber: pageNumber,
      noteText: noteText,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert(
      DatabaseHelper.tableNotes,
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return note;
  }

  Future<void> updateNote(String id, String noteText) async {
    final db = await _dbHelper.database;
    await db.update(
      DatabaseHelper.tableNotes,
      {
        'noteText': noteText,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteNote(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      DatabaseHelper.tableNotes,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteAllNotesForPdf(String pdfId) async {
    final db = await _dbHelper.database;
    await db.delete(
      DatabaseHelper.tableNotes,
      where: 'pdfId = ?',
      whereArgs: [pdfId],
    );
  }

  Future<void> deleteNotesForPage(String pdfId, int pageNumber) async {
    final db = await _dbHelper.database;
    await db.delete(
      DatabaseHelper.tableNotes,
      where: 'pdfId = ? AND pageNumber = ?',
      whereArgs: [pdfId, pageNumber],
    );
  }

  Future<int> getNoteCount(String pdfId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseHelper.tableNotes} WHERE pdfId = ?',
      [pdfId],
    );
    return result.first['count'] as int;
  }
}
